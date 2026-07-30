import Foundation
import CryptoKit
import AppleArchive
import System

extension AppStore {

    // MARK: - Export / Import (verschlüsseltes Apple-Archiv)

    /// AppleArchive verlangt lange Passwörter — aus dem Nutzer-Passwort
    /// wird deshalb erst ein 32-Byte-Schlüssel abgeleitet (wie in Arca).
    /// Ohne diese Ableitung wirft setPassword bei kurzen Passwörtern
    /// "invalidValue" und der Export scheitert kommentarlos (22.07. gefunden).
    private func aeaPassword(from userPassword: String) -> String {
        guard let passwordData = userPassword.data(using: .utf8) else { return userPassword }
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: Data("GruenbuchBackupSalt_v1".utf8),
            info: Data("AEA".utf8),
            outputByteCount: 32)
        return key.withUnsafeBytes { Data($0) }.base64EncodedString()
    }

    func exportData(password: String) -> URL? {
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("GrünbuchExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }
        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let backup = GrünbuchBackup(
                folders: folders,
                lessons: lessons,
                progress: progress,
                students: students,
                groups: groups,
                proNotes: proNotes,
                contentPool: contentPool,
                contentClasses: contentClasses,
                sessions: sessions,
                studentCaptures: studentCaptures,
                settings: GrünbuchBackupSettings(
                    teacherName: teacherName,
                    teacherTitle: teacherTitle,
                    pinnedNoteID: pinnedNoteID,
                    rolle: appMode
                ),
                exportDate: Date()
            )
            let manifest = try JSONEncoder().encode(backup)
            try manifest.write(to: stage.appendingPathComponent("manifest.json"))
            for filename in allReferencedFilenames() {
                let src = imageURL(for: filename)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(filename)
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch { return nil }

        let rollenWort = appMode == AppMode.teacher.rawValue ? "Pro" : "Schüler"
        let wer = teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").first ?? ""
        let filename = "Grünbuch_\(rollenWort)\(wer.isEmpty ? "" : "_" + wer)_\(Date().formatted(date: .abbreviated, time: .omitted)).gruenbuchbackup"
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard archiveDirectory(stage, to: url, password: aeaPassword(from: password)),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    func importData(from url: URL, password: String, merge: Bool = false) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let extracted = extractArchive(url, password: aeaPassword(from: password)) else { return false }
        defer { try? FileManager.default.removeItem(at: extracted) }
        guard let manifestData = try? Data(contentsOf: extracted.appendingPathComponent("manifest.json")),
              let backup = try? JSONDecoder().decode(GrünbuchBackup.self, from: manifestData) else { return false }

        let extractedFiles = extracted.appendingPathComponent("files")
        if let files = try? FileManager.default.contentsOfDirectory(
            at: extractedFiles, includingPropertiesForKeys: nil) {
            for f in files {
                let dest = imageURL(for: f.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: f, to: dest)
            }
        }
        applyBackup(backup, merge: merge)
        return true
    }

    private func applyBackup(_ backup: GrünbuchBackup, merge: Bool) {
        if merge {
            let existingFolderIDs = Set(folders.map(\.id))
            let existingLessonIDs = Set(lessons.map(\.id))
            let existingProgressIDs = Set(progress.map(\.id))
            let existingStudentIDs = Set(students.map(\.id))
            let existingGroupIDs = Set(groups.map(\.id))
            let existingNoteIDs = Set(proNotes.map(\.id))
            let existingPoolIDs = Set(contentPool.map(\.id))
            let existingClassIDs = Set(contentClasses.map(\.id))
            let existingSessionIDs = Set(sessions.map(\.id))
            let existingCaptureIDs = Set(studentCaptures.map(\.id))

            folders += backup.folders.filter { !existingFolderIDs.contains($0.id) }
            lessons += backup.lessons.filter { !existingLessonIDs.contains($0.id) }
            progress += backup.progress.filter { !existingProgressIDs.contains($0.id) }
            students += backup.students.filter { !existingStudentIDs.contains($0.id) }
            groups += backup.groups.filter { !existingGroupIDs.contains($0.id) }
            proNotes += backup.proNotes.filter { !existingNoteIDs.contains($0.id) }
            contentPool += backup.contentPool.filter { !existingPoolIDs.contains($0.id) }
            contentClasses += backup.contentClasses.filter { !existingClassIDs.contains($0.id) }
            sessions += backup.sessions.filter { !existingSessionIDs.contains($0.id) }
            studentCaptures += backup.studentCaptures.filter { !existingCaptureIDs.contains($0.id) }
        } else {
            folders = backup.folders
            lessons = backup.lessons
            progress = backup.progress
            students = backup.students
            groups = backup.groups
            proNotes = backup.proNotes
            contentPool = backup.contentPool
            contentClasses = backup.contentClasses
            sessions = backup.sessions
            studentCaptures = backup.studentCaptures
            teacherName = backup.settings.teacherName
            teacherTitle = backup.settings.teacherTitle
            pinnedNoteID = backup.settings.pinnedNoteID
            // Die Rolle reist mit: Ein Pro-Backup macht das Gerät zum Pro,
            // ein Schüler-Backup zum Schüler (Geräteumzug in einem Schritt).
            if let rolle = backup.settings.rolle {
                appMode = rolle
            }
        }
    }

    private func allReferencedFilenames() -> Set<String> {
        var names = Set<String>()
        for lesson in lessons {
            names.formUnion(lesson.imageFilenames)
            if let video = lesson.videoFilename { names.insert(video) }
        }
        for item in contentPool {
            names.insert(item.filename)
            if let thumb = item.thumbnailFilename { names.insert(thumb) }
        }
        for student in students {
            if let photo = student.photoFilename { names.insert(photo) }
        }
        for note in proNotes {
            if let audio = note.audioFilename { names.insert(audio) }
        }
        for capture in studentCaptures {
            if let file = capture.filename { names.insert(file) }
            if let thumb = capture.thumbnailFilename { names.insert(thumb) }
        }
        return names
    }

    // MARK: - Apple-Archiv-Helfer

    private func archiveDirectory(_ dir: URL, to dest: URL, password: String?) -> Bool {
        try? FileManager.default.removeItem(at: dest)
        do {
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(dest.path), mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)) else { return false }
            defer { try? fileStream.close() }

            var targetStream = fileStream
            var encryptionStream: ArchiveByteStream? = nil
            if let password {
                let ctx = ArchiveEncryptionContext(
                    profile: .hkdf_sha256_aesctr_hmac__scrypt__none,
                    compressionAlgorithm: .lzfse)
                try ctx.setPassword(password)
                guard let es = ArchiveByteStream.encryptionStream(
                    writingTo: fileStream, encryptionContext: ctx) else { return false }
                encryptionStream = es
                targetStream = es
            }
            defer { if let s = encryptionStream { try? s.close() } }

            guard let encoder = ArchiveStream.encodeStream(writingTo: targetStream) else { return false }
            defer { try? encoder.close() }

            try encoder.writeDirectoryContents(
                archiveFrom: FilePath(dir.path), keySet: .defaultForArchive)

            try encoder.close()
            if let s = encryptionStream { try? s.close() }
            try fileStream.close()
            return true
        } catch {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
    }

    private func extractArchive(_ url: URL, password: String?) -> URL? {
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GrünbuchExtract_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(url.path), mode: .readOnly,
                options: [], permissions: FilePermissions(rawValue: 0o644)) else { return nil }
            defer { try? fileStream.close() }

            var sourceStream = fileStream
            var decryptionStream: ArchiveByteStream? = nil
            if let password {
                guard let ctx = ArchiveEncryptionContext(from: fileStream) else { return nil }
                try ctx.setPassword(password)
                guard let ds = ArchiveByteStream.decryptionStream(
                    readingFrom: fileStream, encryptionContext: ctx) else { return nil }
                decryptionStream = ds
                sourceStream = ds
            }
            defer { if let s = decryptionStream { try? s.close() } }

            guard let decoder = ArchiveStream.decodeStream(readingFrom: sourceStream) else { return nil }
            defer { try? decoder.close() }
            guard let extractor = ArchiveStream.extractStream(
                extractingTo: FilePath(outDir.path),
                flags: [.ignoreOperationNotPermitted]) else { return nil }
            defer { try? extractor.close() }

            _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
            return outDir
        } catch {
            try? FileManager.default.removeItem(at: outDir)
            return nil
        }
    }
}
