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

    /// Netzfehler erkennen: nur die wandern in den Postausgang —
    /// echte Fehler (z.B. Berechtigungen) sollen sichtbar bleiben.
    static func istNetzFehler(_ error: Error) -> Bool {
        if error is URLError { return true }
        return (error as NSError).domain == NSURLErrorDomain
    }

    /// Der Lieferkern: EINE Lektion an EINEN Schüler (Medien hochladen,
    /// Paket einstellen). Wird vom Composer und vom Postausgang genutzt.
    @MainActor
    func liefereLektion(_ lesson: Lesson, an cloudID: UUID, note: String) async throws {
        let cloud = CloudService.shared
        let items = contentItems(for: lesson)
        var media = Set(lesson.imageFilenames)
        if let video = lesson.videoFilename { media.insert(video) }
        for item in items {
            media.insert(item.filename)
            if let thumb = item.thumbnailFilename { media.insert(thumb) }
        }
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
            note: note,
            contentClasses: contentClasses.filter { usedClassIDs.contains($0.id) }
        )
        try await cloud.insertPackage(title: lesson.title, payload: payload, to: cloudID)
    }

    /// Pro: Composer-Paket über die Cloud an verbundene Schüler senden.
    /// Im Funkloch wandert die Sendung in den Postausgang und wird
    /// automatisch nachgeliefert: Senden gelingt immer (23.07.).
    @MainActor
    func sendComposerPackageViaCloud(
        to studentIDs: Set<UUID>,
        lessonIDs: Set<UUID>,
        contentItemIDs: Set<UUID>,
        note: String,
        date: Date
    ) async -> (sent: Int, wartend: Int, withoutCloud: [String]) {
        let cloud = CloudService.shared
        let delivery = prepareComposerDelivery(
            to: studentIDs, lessonIDs: lessonIDs,
            contentItemIDs: contentItemIDs, note: note, date: date
        )
        var sent = 0
        var wartend = 0
        var withoutCloud: [String] = []

        for student in delivery.targets {
            guard let cloudID = student.cloudUserID else {
                withoutCloud.append(student.name)
                continue
            }
            for lesson in delivery.lessons {
                // Funkloch? Gar nicht erst versuchen — direkt einreihen.
                if !netzVerbunden {
                    ausgang.append(AusgangsSendung(art: .lernpaket,
                                                   studentIDs: [student.id],
                                                   lessonID: lesson.id,
                                                   text: delivery.note))
                    wartend += 1
                    continue
                }
                do {
                    try await liefereLektion(lesson, an: cloudID, note: delivery.note)
                    sent += 1
                } catch {
                    if Self.istNetzFehler(error) {
                        ausgang.append(AusgangsSendung(art: .lernpaket,
                                                       studentIDs: [student.id],
                                                       lessonID: lesson.id,
                                                       text: delivery.note))
                        wartend += 1
                    } else {
                        cloud.lastErrorMessage = error.localizedDescription
                    }
                }
            }
        }
        return (sent, wartend, withoutCloud)
    }

    /// Der Postausgang wird geleert, sobald Netz da ist — vom
    /// Netzwächter, beim App-Öffnen und im Minutentakt aufgerufen.
    @MainActor
    func flushAusgang() async {
        guard !ausgang.isEmpty, netzVerbunden, CloudService.shared.isSignedIn else { return }
        let sendungen = ausgang
        for sendung in sendungen {
            var erledigt = false
            switch sendung.art {
            case .lernpaket:
                guard let studentID = sendung.studentIDs.first,
                      let student = students.first(where: { $0.id == studentID }),
                      let cloudID = student.cloudUserID,
                      let lesson = lessons.first(where: { $0.id == sendung.lessonID })
                else { erledigt = true; break }   // Ziel existiert nicht mehr → verwerfen
                do {
                    try await liefereLektion(lesson, an: cloudID, note: sendung.text)
                    erledigt = true
                } catch {
                    if !Self.istNetzFehler(error) { erledigt = true }  // echter Fehler: nicht ewig hängen
                }
            case .mitteilung:
                let ergebnis = await sendeMitteilungJetzt(sendung.text, an: sendung.studentIDs)
                erledigt = !ergebnis.netzProblem
            case .antwort:
                let ergebnis = await sendeAntwortJetzt(sendung.text)
                erledigt = !ergebnis.netzProblem
            }
            if erledigt {
                ausgang.removeAll { $0.id == sendung.id }
            }
        }
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

    /// Mitteilungs-Kern ohne Warteschlange (nutzt Composer & Postausgang).
    @MainActor
    func sendeMitteilungJetzt(_ body: String, an ids: [UUID]) async -> (sent: Int, withoutCloud: [String], netzProblem: Bool) {
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
        guard !targets.isEmpty else { return (0, withoutCloud, false) }

        do {
            let inserted = try await cloud.sendMessage(body, to: targets.map(\.cloud))
            for row in inserted {
                let localID = targets.first(where: { $0.cloud == row.student_id })?.local
                proMessages.insert(
                    ProMessage(id: row.id, localStudentID: localID, body: row.body, date: row.created_at),
                    at: 0
                )
            }
            return (inserted.count, withoutCloud, false)
        } catch {
            if Self.istNetzFehler(error) { return (0, withoutCloud, true) }
            cloud.lastErrorMessage = error.localizedDescription
            return (0, withoutCloud, false)
        }
    }

    /// Pro: Mitteilung senden — im Funkloch wandert sie in den Postausgang.
    @MainActor
    func sendProMessage(_ body: String, toLocalStudentIDs ids: [UUID]) async -> (sent: Int, wartend: Bool, withoutCloud: [String]) {
        if !netzVerbunden {
            ausgang.append(AusgangsSendung(art: .mitteilung, studentIDs: ids, text: body))
            return (0, true, [])
        }
        let ergebnis = await sendeMitteilungJetzt(body, an: ids)
        if ergebnis.netzProblem {
            ausgang.append(AusgangsSendung(art: .mitteilung, studentIDs: ids, text: body))
            return (0, true, ergebnis.withoutCloud)
        }
        return (ergebnis.sent, false, ergebnis.withoutCloud)
    }

    /// Antwort-Kern ohne Warteschlange.
    @MainActor
    func sendeAntwortJetzt(_ text: String) async -> (ok: Bool, netzProblem: Bool) {
        do {
            try await CloudService.shared.sendeAntwortKern(text)
            return (true, false)
        } catch {
            if Self.istNetzFehler(error) { return (false, true) }
            CloudService.shared.lastErrorMessage = error.localizedDescription
            return (false, false)
        }
    }

    /// Schüler: Schnellantwort senden — im Funkloch in den Postausgang.
    @MainActor
    func sendeAntwort(_ text: String) async -> (ok: Bool, wartend: Bool) {
        if !netzVerbunden {
            ausgang.append(AusgangsSendung(art: .antwort, text: text))
            return (false, true)
        }
        let ergebnis = await sendeAntwortJetzt(text)
        if ergebnis.netzProblem {
            ausgang.append(AusgangsSendung(art: .antwort, text: text))
            return (false, true)
        }
        return (ergebnis.ok, false)
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
        // Den Namen des Pros einmalig aus dem Cloud-Profil holen
        if proName.isEmpty, let name = await CloudService.shared.linkedProName() {
            proName = name
        }
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
        // 1. Mitgesendete Lektionsgruppen des Pros einpassen:
        //    gleiche ID → schon da; gleicher NAME → verschmelzen (die
        //    frische Schüler-App bringt vorgefertigte Golf-Gruppen mit
        //    eigenen IDs mit — ohne Verschmelzen gäbe es "Chippen"
        //    doppelt); sonst neu anlegen. classIDMap übersetzt die
        //    Gruppen-Kennungen des Pros auf die lokalen.
        func normalized(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        var classIDMap: [UUID: UUID] = [:]
        for sentClass in package.payload.contentClasses ?? [] {
            if contentClasses.contains(where: { $0.id == sentClass.id }) {
                classIDMap[sentClass.id] = sentClass.id
            } else if let local = contentClasses.first(where: { normalized($0.title) == normalized(sentClass.title) }) {
                classIDMap[sentClass.id] = local.id
            } else {
                var copy = sentClass
                copy.sortIndex = (contentClasses.map(\.sortIndex).max() ?? 0) + 1
                contentClasses.append(copy)
                classIDMap[sentClass.id] = copy.id
            }
        }
        // Hierarchie nachziehen: verschmolzene Eltern-Kennungen übersetzen
        for i in contentClasses.indices {
            if let parent = contentClasses[i].parentID,
               let mapped = classIDMap[parent], mapped != parent {
                contentClasses[i].parentID = mapped
            }
        }
        let localClassIDs = Set(contentClasses.map(\.id))
        // Die Gruppe eines Inhalts in lokaler Übersetzung (nil = unbekannt)
        func localClassID(for sentID: UUID?) -> UUID? {
            guard let sentID else { return nil }
            if let mapped = classIDMap[sentID] { return mapped }
            return localClassIDs.contains(sentID) ? sentID : nil
        }

        var newPoolItems = package.payload.contentItems.filter { item in
            !contentPool.contains(where: { $0.id == item.id })
        }
        // Herkunfts-Gruppe je Inhalt (aus Sicht des Pros)
        let sentClassOf: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: package.payload.contentItems.compactMap { item in
                item.classID.map { (item.id, $0) }
            }
        )
        // Bereits vorhandene Inhalte aus diesem Paket: "Senden IST
        // Zuweisen" (Hans, 21.07.) — die Gruppe des Pros gilt auch beim
        // erneuten Senden. Nur wo der Pro selbst keine Gruppe vergeben
        // hat, bleibt die Ordnung des Schülers unangetastet.
        let existingIDs = package.payload.contentItems.map(\.id).filter { id in
            contentPool.contains(where: { $0.id == id })
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

        // 3. Neue Inhalte: Original-Gruppe (lokal übersetzt) wenn bekannt,
        //    sonst Auffang-Gruppe. Alles aus einem Paket trägt das
        //    Pro-Siegel (goldener Punkt in der Bibliothek).
        for i in newPoolItems.indices {
            newPoolItems[i].vomPro = true
            if let local = localClassID(for: newPoolItems[i].classID) {
                newPoolItems[i].classID = local
            } else {
                newPoolItems[i].classID = fallbackGroupID()
            }
        }
        if !newPoolItems.isEmpty {
            contentPool.insert(contentsOf: newPoolItems, at: 0)
        }
        for id in existingIDs {
            if let idx = contentPool.firstIndex(where: { $0.id == id }) {
                contentPool[idx].vomPro = true
                if let local = localClassID(for: sentClassOf[id]) {
                    contentPool[idx].classID = local
                } else if contentPool[idx].classID == nil {
                    contentPool[idx].classID = fallbackGroupID()
                }
            }
        }

        var newLesson = package.payload.lesson
        newLesson.id = UUID()
        newLesson.origin = .receivedFromPro
        newLesson.receivedFromPro = package.payload.teacherName
        // Der Paket-Absender ist unser Pro — Name für die Oberfläche merken
        let senderName = package.payload.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !senderName.isEmpty { proName = senderName }
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
