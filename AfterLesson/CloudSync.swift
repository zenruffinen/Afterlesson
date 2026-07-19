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

// MARK: - Paket-Format (reist als JSON in packages.payload)

struct CloudLessonShare: Codable {
    var lesson: Lesson
    var contentItems: [ContentItem]
    var mediaFilenames: [String]
    var teacherName: String
    var note: String
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
                        if let data = try? Data(contentsOf: url) {
                            try await cloud.uploadMedia(data, filename: filename)
                        }
                    }
                    let payload = CloudLessonShare(
                        lesson: lesson,
                        contentItems: items,
                        mediaFilenames: Array(media),
                        teacherName: teacherName,
                        note: delivery.note
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
        var newPoolItems = package.payload.contentItems.filter { item in
            !contentPool.contains(where: { $0.id == item.id })
        }
        // Hans' Regel: Empfangenes zieht in die Bibliothek des Schülers ein —
        // als eigene Lektionsgruppe "Lektion vom <Datum> – <Pro>", damit auf
        // einen Blick klar ist, was von wem kam.
        // Auch bereits vorhandene, aber unsortierte Inhalte aus diesem Paket
        // sollen in die Absender-Gruppe einziehen (z. B. nach erneutem Senden).
        let existingUnsortedIDs = package.payload.contentItems.map(\.id).filter { id in
            contentPool.contains(where: { $0.id == id && $0.classID == nil })
        }

        if !newPoolItems.isEmpty || !existingUnsortedIDs.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            let dateStr = formatter.string(from: package.created_at)
            let teacher = package.payload.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
            let groupTitle = teacher.isEmpty
                ? String(format: String(localized: "cloud.received_group"), dateStr)
                : String(format: String(localized: "cloud.received_group_named"), dateStr, teacher)

            let groupID: UUID
            if let existing = contentClasses.first(where: { $0.title == groupTitle }) {
                groupID = existing.id
            } else {
                var group = ContentClass(title: groupTitle)
                group.icon = "tray.and.arrow.down.fill"
                group.colorHex = "C9A227"
                group.sortIndex = (contentClasses.map(\.sortIndex).max() ?? 0) + 1
                contentClasses.append(group)
                groupID = group.id
            }
            for i in newPoolItems.indices {
                newPoolItems[i].classID = groupID
            }
            if !newPoolItems.isEmpty {
                contentPool.insert(contentsOf: newPoolItems, at: 0)
            }
            for id in existingUnsortedIDs {
                if let idx = contentPool.firstIndex(where: { $0.id == id }) {
                    contentPool[idx].classID = groupID
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
