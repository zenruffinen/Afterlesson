//
//  CloudSync.swift
//  Grünbuch — Cloud (Supabase)
//
//  Der Versand- und Empfangsweg über die Drehscheibe:
//  Der Pro schickt Composer-Pakete in die packages-Tabelle
//  (Mediendateien in den Storage), der Schüler holt sie ab und
//  registriert sie exakt wie einen AirDrop-Import — dieselben
//  Lektionen, derselbe "Neues vom Pro"-Banner, dieselbe Ansicht.
//

import Foundation
import AVFoundation

// MARK: - Paket-Format (reist als JSON in packages.payload)

struct CloudLessonShare: Codable {
    var lesson: Lesson
    var contentItems: [ContentItem]
    var mediaFilenames: [String]
    var teacherName: String
    var note: String
    // Die Lektionsgruppen des Pros reisen mit, damit "Putten" beim
    // Schüler auch "Putten" heißt. Optional → ältere Pakete ohne
    // dieses Feld laden weiterhin sauber (Decodable-Regel!).
    var contentClasses: [ContentClass]? = nil
}

struct IncomingCloudPackage: Codable, Identifiable {
    let id: UUID
    let pro_id: UUID
    let title: String
    let payload: CloudLessonShare
    let created_at: Date
}

// MARK: - AppStore: Senden (Pro) und Empfangen (Schüler)

extension AppStore {

    /// Merkliste bereits importierter Cloud-Pakete — verhindert Doppel-Importe.
    private var importedCloudPackageIDs: Set<UUID> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "al_cloud_imported"),
                  let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else { return [] }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "al_cloud_imported")
            }
        }
    }

    /// Pro: Composer-Paket über die Cloud an verbundene Schüler senden.
    /// Zuweisung und Verlauf laufen über denselben Kern wie AirDrop.
    @MainActor
    func sendComposerPackageViaCloud(
        to studentIDs: Set<UUID>,
        lessonIDs: Set<UUID>,
        contentItemIDs: Set<UUID>,
        note: String,
        date: Date
    ) async -> (sent: Int, withoutCloud: [String]) {
        let cloud = CloudService.shared
        let delivery = prepareComposerDelivery(
            to: studentIDs, lessonIDs: lessonIDs,
            contentItemIDs: contentItemIDs, note: note, date: date
        )
        var sent = 0
        var withoutCloud: [String] = []

        for student in delivery.targets {
            guard let cloudID = student.cloudUserID else {
                withoutCloud.append(student.name)
                continue
            }
            for lesson in delivery.lessons {
                let items = contentItems(for: lesson)
                var media = Set(lesson.imageFilenames)
                if let video = lesson.videoFilename { media.insert(video) }
                for item in items {
                    media.insert(item.filename)
                    if let thumb = item.thumbnailFilename { media.insert(thumb) }
                }
                do {
                    for filename in media {
                        let url = imageURL(for: filename)
                        // Videos vor dem Upload auf 720p verdichten — schont
                        // Speicher und das Datenvolumen des Schülers am Platz.
                        if Self.isVideoFile(filename),
                           let compressed = await Self.compressedVideoData(at: url) {
                            try await cloud.uploadMedia(compressed, filename: filename)
                        } else if let data = try? Data(contentsOf: url) {
                            try await cloud.uploadMedia(data, filename: filename)
                        }
                    }
                    // Obergruppen reisen mit: Wer "Putten" (in "Kurzes Spiel")
                    // sendet, schickt auch "Kurzes Spiel" mit — sonst hinge die
                    // Untergruppe beim Schüler in der Luft.
                    var usedClassIDs = Set(items.compactMap(\.classID))
                    for c in contentClasses where usedClassIDs.contains(c.id) {
                        if let parent = c.parentID { usedClassIDs.insert(parent) }
                    }
                    let payload = CloudLessonShare(
                        lesson: lesson,
                        contentItems: items,
                        mediaFilenames: Array(media),
                        teacherName: teacherName,
                        note: delivery.note,
                        contentClasses: contentClasses.filter { usedClassIDs.contains($0.id) }
                    )
                    try await cloud.insertPackage(title: lesson.title, payload: payload, to: cloudID)
                    sent += 1
                } catch {
                    cloud.lastErrorMessage = error.localizedDescription
                }
            }
        }
        return (sent, withoutCloud)
    }

    // MARK: Rückkanal — Pro holt Schüler-Antworten ab

    private var importedCloudResponseIDs: Set<UUID> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "al_cloud_responses"),
                  let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else { return [] }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "al_cloud_responses")
            }
        }
    }

    /// Pro: neue Antworten abholen und in die Rückmelde-Chronik der
    /// jeweiligen Schüler-Kartei einsortieren (bestehende UI zeigt sie).
    @MainActor
    func importCloudResponses() async -> Int {
        let cloud = CloudService.shared
        guard cloud.isSignedIn, appMode == AppMode.teacher.rawValue else { return 0 }

        var imported = importedCloudResponseIDs
        let incoming = await cloud.fetchResponses().filter { !imported.contains($0.id) }
        var count = 0

        for response in incoming {
            guard let idx = students.firstIndex(where: { $0.cloudUserID == response.student_id }) else {
                continue // Schüler (noch) nicht zuordenbar — nächstes Mal erneut
            }
            var entry = StudentFeedbackEntry(kind: .custom, message: response.message)
            entry.date = response.created_at
            students[idx].feedbackHistory.insert(entry, at: 0)
            students[idx].remarks = response.message
            imported.insert(response.id)
            count += 1
        }

        importedCloudResponseIDs = imported
        return count
    }

    // MARK: Mitteilungen („Zettel vom Pro")

    /// Pro: Mitteilung an gewählte Karteien senden.
    /// Liefert (Anzahl gesendet, Namen ohne Cloud-Verbindung).
    @MainActor
    func sendProMessage(_ body: String, toLocalStudentIDs ids: [UUID]) async -> (sent: Int, withoutCloud: [String]) {
        let cloud = CloudService.shared
        var withoutCloud: [String] = []
        var targets: [(local: UUID, cloud: UUID)] = []
        for id in ids {
            guard let student = students.first(where: { $0.id == id }) else { continue }
            if let cid = student.cloudUserID {
                targets.append((id, cid))
            } else {
                withoutCloud.append(student.name)
            }
        }
        guard !targets.isEmpty else { return (0, withoutCloud) }

        let inserted = await cloud.sendMessage(body, to: targets.map(\.cloud))
        for row in inserted {
            let localID = targets.first(where: { $0.cloud == row.student_id })?.local
            proMessages.insert(
                ProMessage(id: row.id, localStudentID: localID, body: row.body, date: row.created_at),
                at: 0
            )
        }
        return (inserted.count, withoutCloud)
    }

    /// Pro: Gelesen-Häkchen aus der Cloud nachführen (und Mitteilungen
    /// ergänzen, die z.B. von einem anderen Gerät gesendet wurden).
    @MainActor
    func refreshProMessages() async {
        guard appMode == AppMode.teacher.rawValue, CloudService.shared.isSignedIn else { return }
        let rows = await CloudService.shared.fetchCloudMessages()
        guard !rows.isEmpty else { return }
        for row in rows {
            if let idx = proMessages.firstIndex(where: { $0.id == row.id }) {
                if proMessages[idx].readDate != row.read_at {
                    proMessages[idx].readDate = row.read_at
                }
            } else {
                let localID = students.first(where: { $0.cloudUserID == row.student_id })?.id
                proMessages.append(ProMessage(id: row.id, localStudentID: localID,
                                              body: row.body, date: row.created_at,
                                              readDate: row.read_at))
            }
        }
        proMessages.sort { $0.date > $1.date }
    }

    /// Vom Schüler gelöschte Mitteilungen — Merkliste, damit sie beim
    /// nächsten Cloud-Abruf nicht wieder auftauchen.
    private var deletedMessageIDs: Set<UUID> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "al_deleted_messages"),
                  let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else { return [] }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "al_deleted_messages")
            }
        }
    }

    /// Schüler: neue Mitteilungen abholen. Liefert die Zahl neuer.
    @MainActor
    func importCloudMessages() async -> Int {
        guard appMode == AppMode.student.rawValue, CloudService.shared.isSignedIn else { return 0 }
        let deleted = deletedMessageIDs
        let rows = await CloudService.shared.fetchCloudMessages()
        var newCount = 0
        for row in rows {
            if deleted.contains(row.id) { continue }
            if proMessages.contains(where: { $0.id == row.id }) { continue }
            proMessages.append(ProMessage(id: row.id, localStudentID: nil,
                                          body: row.body, date: row.created_at,
                                          readDate: row.read_at))
            newCount += 1
        }
        if newCount > 0 { proMessages.sort { $0.date > $1.date } }
        return newCount
    }

    /// Schüler: Mitteilung als gelesen markieren (lokal sofort, Cloud im Hintergrund).
    @MainActor
    func markProMessageRead(_ message: ProMessage) {
        guard message.readDate == nil else { return }
        if let idx = proMessages.firstIndex(where: { $0.id == message.id }) {
            proMessages[idx].readDate = Date()
        }
        Task { await CloudService.shared.markMessageRead(message.id) }
    }

    /// Schüler: Mitteilung ins Archiv legen (oder mit archived=false zurückholen).
    @MainActor
    func archiveProMessage(_ message: ProMessage, archived: Bool = true) {
        if let idx = proMessages.firstIndex(where: { $0.id == message.id }) {
            proMessages[idx].archivedDate = archived ? Date() : nil
        }
    }

    /// Schüler: Mitteilung endgültig löschen — kommt dank Merkliste
    /// auch nicht aus der Cloud zurück.
    @MainActor
    func deleteProMessage(_ message: ProMessage) {
        proMessages.removeAll { $0.id == message.id }
        var ids = deletedMessageIDs
        ids.insert(message.id)
        deletedMessageIDs = ids
    }

    // MARK: Video-Kompression (720p, H.264/mp4)

    static func isVideoFile(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mov", "mp4", "m4v"].contains(ext)
    }

    /// Verdichtet ein Video auf 720p. Liefert nil, wenn das Original
    /// fehlt, der Export scheitert oder nichts gespart würde — dann
    /// geht das Original in die Cloud.
    static func compressedVideoData(at url: URL) async -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return nil
        }
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        export.outputURL = target
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { done.resume() }
        }
        defer { try? FileManager.default.removeItem(at: target) }

        guard export.status == .completed,
              let compressed = try? Data(contentsOf: target),
              let original = try? Data(contentsOf: url),
              compressed.count < original.count
        else { return nil }
        return compressed
    }

    /// Schüler: neue Cloud-Pakete abholen, Medien laden und wie einen
    /// AirDrop-Import registrieren. Liefert die Zahl neuer Lektionen.
    @MainActor
    func importCloudPackages() async -> Int {
        let cloud = CloudService.shared
        guard cloud.isSignedIn, appMode == AppMode.student.rawValue else { return 0 }

        var imported = importedCloudPackageIDs
        let incoming = await cloud.fetchIncomingPackages().filter { !imported.contains($0.id) }
        var count = 0

        for package in incoming {
            do {
                for filename in Set(package.payload.mediaFilenames) {
                    let target = imageURL(for: filename)
                    if !FileManager.default.fileExists(atPath: target.path) {
                        let data = try await cloud.downloadMedia(proID: package.pro_id, filename: filename)
                        saveImage(data, filename: filename)
                    }
                }
                registerCloudLesson(from: package)
                imported.insert(package.id)
                count += 1
            } catch {
                // Paket bleibt offen und wird beim nächsten Abruf erneut versucht
                // (z. B. Funkloch mitten im Video-Download).
            }
        }

        importedCloudPackageIDs = imported
        return count
    }

    /// Spiegelt die Registrierung aus importLesson(from:) — gleiche Regeln,
    /// nur ohne Datei: Pool-Inhalte deduplizieren, fremde classID lösen,
    /// Lektion als "vom Pro empfangen" einreihen.
    @MainActor
    private func registerCloudLesson(from package: IncomingCloudPackage) {
        // 1. Mitgesendete Lektionsgruppen des Pros lokal nachbauen — mit
        //    denselben IDs, damit wiederholte Sendungen in derselben Gruppe
        //    landen: "Putten" heißt beim Schüler auch "Putten".
        for sentClass in package.payload.contentClasses ?? [] {
            if !contentClasses.contains(where: { $0.id == sentClass.id }) {
                var copy = sentClass
                copy.sortIndex = (contentClasses.map(\.sortIndex).max() ?? 0) + 1
                contentClasses.append(copy)
            }
        }
        let knownClassIDs = Set(contentClasses.map(\.id))

        var newPoolItems = package.payload.contentItems.filter { item in
            !contentPool.contains(where: { $0.id == item.id })
        }
        // Herkunfts-Gruppe je Inhalt (aus Sicht des Pros)
        let sentClassOf: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: package.payload.contentItems.compactMap { item in
                item.classID.map { (item.id, $0) }
            }
        )
        // Auch bereits vorhandene, aber unsortierte Inhalte aus diesem
        // Paket werden einsortiert (z. B. nach erneutem Senden).
        let existingUnsortedIDs = package.payload.contentItems.map(\.id).filter { id in
            contentPool.contains(where: { $0.id == id && $0.classID == nil })
        }

        // 2. Auffang-Gruppe "Lektion vom <Datum> – <Pro>" — nur noch für
        //    Inhalte, die beim Pro in keiner Gruppe lagen.
        func fallbackGroupID() -> UUID {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            let dateStr = formatter.string(from: package.created_at)
            let teacher = package.payload.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
            let groupTitle = teacher.isEmpty
                ? String(format: String(localized: "cloud.received_group"), dateStr)
                : String(format: String(localized: "cloud.received_group_named"), dateStr, teacher)
            if let existing = contentClasses.first(where: { $0.title == groupTitle }) {
                return existing.id
            }
            var group = ContentClass(title: groupTitle)
            group.icon = "tray.and.arrow.down.fill"
            group.colorHex = "C9A227"
            group.sortIndex = (contentClasses.map(\.sortIndex).max() ?? 0) + 1
            contentClasses.append(group)
            return group.id
        }

        // 3. Neue Inhalte: Original-Gruppe wenn bekannt, sonst Auffang-Gruppe
        for i in newPoolItems.indices {
            if let cid = newPoolItems[i].classID, knownClassIDs.contains(cid) {
                continue
            }
            newPoolItems[i].classID = fallbackGroupID()
        }
        if !newPoolItems.isEmpty {
            contentPool.insert(contentsOf: newPoolItems, at: 0)
        }
        for id in existingUnsortedIDs {
            if let idx = contentPool.firstIndex(where: { $0.id == id }) {
                if let cid = sentClassOf[id], knownClassIDs.contains(cid) {
                    contentPool[idx].classID = cid
                } else {
                    contentPool[idx].classID = fallbackGroupID()
                }
            }
        }

        var newLesson = package.payload.lesson
        newLesson.id = UUID()
        newLesson.origin = .receivedFromPro
        newLesson.receivedFromPro = package.payload.teacherName
        newLesson.openedDate = nil
        newLesson.dateCreated = package.created_at
        newLesson.cloudPackageID = package.id
        // Notiz des Pros sichtbar machen: wandert in die Beschreibung
        if !package.payload.note.isEmpty {
            newLesson.description = newLesson.description.isEmpty
                ? package.payload.note
                : "\(newLesson.description)\n\n\(package.payload.note)"
        }
        if !folders.contains(where: { $0.id == newLesson.folderID }) {
            newLesson.folderID = folders.first?.id ?? UUID()
        }
        lessons.insert(newLesson, at: 0)
    }
}
