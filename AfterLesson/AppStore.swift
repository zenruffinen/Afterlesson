import SwiftUI
import Combine
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

final class AppStore: ObservableObject {

    // MARK: - Published State

    @Published var folders: [LessonFolder] = [] {
        didSet { saveFolders() }
    }
    @Published var lessons: [Lesson] = [] {
        didSet { saveLessons() }
    }
    @Published var progress: [StudentProgress] = [] {
        didSet { saveProgress() }
    }
    @Published var students: [Student] = [] {
        didSet { saveStudents() }
    }
    @Published var groups: [TeachingGroup] = [] {
        didSet { saveGroups() }
    }
    @Published var proNotes: [ProNote] = [] {
        didSet { saveProNotes() }
    }
    @Published var contentPool: [ContentItem] = [] {
        didSet { saveContentPool() }
    }
    @Published var contentClasses: [ContentClass] = [] {
        didSet { saveContentClasses() }
    }
    @Published var sessions: [TrainingSession] = [] {
        didSet { saveSessions() }
    }
    @Published var studentCaptures: [StudentCapture] = [] {
        didSet { saveStudentCaptures() }
    }
    @AppStorage("appMode") var appMode: String = AppMode.teacher.rawValue
    @AppStorage("teacherName") var teacherName: String = ""
    @AppStorage("teacherTitle") var teacherTitle: String = "PGA Teaching Professional"
    @AppStorage("isLocked") var isLocked: Bool = false
    @AppStorage("lockEnabled") var lockEnabled: Bool = false
    @AppStorage("pinnedNoteID") var pinnedNoteID: String = ""

    var pinnedNote: ProNote? {
        guard !pinnedNoteID.isEmpty,
              let uuid = UUID(uuidString: pinnedNoteID) else { return nil }
        return proNotes.first(where: { $0.id == uuid })
    }

    // MARK: - Init

    init() {
        load()
        if folders.isEmpty {
            createDefaultFolders()
        }
        // Standard-Golfklassen einmalig ERGÄNZEN (nicht nur bei leerem Bestand):
        // Bereits selbst angelegte Klassen (z.B. "Abschlag") bleiben unberührt,
        // nur fehlende Standards kommen dazu. Wichtig: didSet/Speichern feuert
        // im Init nicht automatisch — deshalb explizit sichern.
        if !UserDefaults.standard.bool(forKey: "al_defaultclasses_v1") {
            seedDefaultContentClasses()
            saveContentClasses()
            UserDefaults.standard.set(true, forKey: "al_defaultclasses_v1")
        }
    }

    // MARK: - Default Content Classes (Golf-Klassen im Datenpool)

    private func seedDefaultContentClasses() {
        let defaults: [(String, String, String)] = [
            ("Putten",       "flag.circle.fill", "1565C0"),
            ("Chippen",      "arrow.up.right",   "4A148C"),
            ("Pitchen",      "target",           "006064"),
            ("Bunker",       "sun.max.fill",     "E65100"),
            ("Langes Spiel", "figure.golf",      "1B5E20"),
        ]
        let existing = Set(contentClasses.map { $0.title.lowercased() })
        var nextIndex = (contentClasses.map(\.sortIndex).max() ?? -1) + 1
        for d in defaults where !existing.contains(d.0.lowercased()) {
            contentClasses.append(ContentClass(title: d.0, icon: d.1, colorHex: d.2, sortIndex: nextIndex))
            nextIndex += 1
        }
    }

    // MARK: - Default Folders (Golf-Themen)

    private func createDefaultFolders() {
        let defaults: [(String, String, String, String)] = [
            ("Abschlag", "Drive & Aufstellung", "figure.golf", "1B5E20"),
            ("Putten", "Präzision auf dem Green", "circle.fill", "1565C0"),
            ("Chippen", "Kurzes Spiel", "arrow.up.right", "4A148C"),
            ("Bunker", "Sand-Techniken", "sun.max.fill", "E65100"),
            ("Mentales Spiel", "Fokus & Strategie", "brain.head.profile", "37474F"),
            ("Setup & Haltung", "Grundlagen", "figure.stand", "2E7D32"),
        ]
        folders = defaults.enumerated().map { i, d in
            LessonFolder(title: d.0, subtitle: d.1, colorHex: d.3, icon: d.2, sortIndex: i)
        }
    }

    // MARK: - Folders

    func addFolder(title: String, subtitle: String = "", icon: String = "folder.fill", colorHex: String = "2C5F2D") {
        let f = LessonFolder(title: title, subtitle: subtitle, colorHex: colorHex, icon: icon, sortIndex: folders.count)
        folders.append(f)
    }

    func updateFolder(_ folder: LessonFolder) {
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx] = folder
        }
    }

    func deleteFolder(_ folder: LessonFolder) {
        lessons.removeAll { $0.folderID == folder.id }
        folders.removeAll { $0.id == folder.id }
    }

    // MARK: - Lessons

    func lessonsIn(_ folder: LessonFolder) -> [Lesson] {
        lessons.filter { $0.folderID == folder.id }
            .sorted { $0.dateCreated < $1.dateCreated }
    }

    func addLesson(title: String, folderID: UUID) {
        let lesson = Lesson(folderID: folderID, title: title)
        lessons.append(lesson)
    }

    func updateLesson(_ lesson: Lesson) {
        if let idx = lessons.firstIndex(where: { $0.id == lesson.id }) {
            lessons[idx] = lesson
        }
    }

    func duplicateLesson(_ lesson: Lesson) {
        var copy = lesson
        copy.id = UUID()
        copy.title = lesson.title + " (Kopie)"
        copy.dateCreated = Date()
        lessons.append(copy)
    }

    func deleteLesson(_ lesson: Lesson) {
        for filename in lesson.imageFilenames {
            try? FileManager.default.removeItem(at: imageURL(for: filename))
        }
        if let video = lesson.videoFilename {
            try? FileManager.default.removeItem(at: imageURL(for: video))
        }
        lessons.removeAll { $0.id == lesson.id }
    }

    // MARK: - Students (Schüler)

    func addStudent(name: String, notes: String = "") {
        let colors = ["1B5E20", "1565C0", "4A148C", "E65100", "37474F", "880E4F", "006064", "BF360C"]
        let color = colors[students.count % colors.count]
        let s = Student(name: name, notes: notes, avatarColor: color)
        students.append(s)
    }

    func updateStudent(_ student: Student) {
        if let idx = students.firstIndex(where: { $0.id == student.id }) {
            students[idx] = student
        }
    }

    func deleteStudent(_ student: Student) {
        // Zuweisungen aus Ordnern entfernen
        for i in folders.indices {
            folders[i].studentIDs.removeAll { $0 == student.id }
        }
        for capture in studentCaptures where capture.studentID == student.id {
            deleteStudentCapture(capture)
        }
        sessions.removeAll { $0.studentID == student.id }
        students.removeAll { $0.id == student.id }
    }

    // MARK: - Folder ↔ Student Zuweisung

    func assign(folder: LessonFolder, to student: Student) {
        if let fi = folders.firstIndex(where: { $0.id == folder.id }) {
            if !folders[fi].studentIDs.contains(student.id) {
                folders[fi].studentIDs.append(student.id)
            }
        }
        if let si = students.firstIndex(where: { $0.id == student.id }) {
            if !students[si].assignedFolderIDs.contains(folder.id) {
                students[si].assignedFolderIDs.append(folder.id)
            }
        }
    }

    func unassign(folder: LessonFolder, from student: Student) {
        if let fi = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[fi].studentIDs.removeAll { $0 == student.id }
        }
        if let si = students.firstIndex(where: { $0.id == student.id }) {
            students[si].assignedFolderIDs.removeAll { $0 == folder.id }
        }
    }

    func isAssigned(folder: LessonFolder, to student: Student) -> Bool {
        folder.studentIDs.contains(student.id)
    }

    func foldersFor(_ student: Student) -> [LessonFolder] {
        folders.filter { student.assignedFolderIDs.contains($0.id) }
    }

    func studentsFor(_ folder: LessonFolder) -> [Student] {
        students.filter { folder.studentIDs.contains($0.id) }
    }

    func currentStudent(_ student: Student) -> Student? {
        students.first(where: { $0.id == student.id })
    }

    func toggleLessonForStudent(_ lesson: Lesson, student: Student) {
        guard let si = students.firstIndex(where: { $0.id == student.id }) else { return }
        if students[si].assignedLessonIDs.contains(lesson.id) {
            students[si].assignedLessonIDs.removeAll { $0 == lesson.id }
        } else {
            students[si].assignedLessonIDs.append(lesson.id)
        }
    }

    func assignedLessonsFor(_ student: Student) -> [Lesson] {
        lessons.filter { student.assignedLessonIDs.contains($0.id) }
    }

    func toggleLessonViewed(_ lesson: Lesson, for student: Student) {
        guard let si = students.firstIndex(where: { $0.id == student.id }) else { return }
        if students[si].viewedLessonIDs.contains(lesson.id) {
            students[si].viewedLessonIDs.removeAll { $0 == lesson.id }
        } else {
            students[si].viewedLessonIDs.append(lesson.id)
            students[si].lastActiveDate = Date()
        }
    }

    func progressFor(_ student: Student) -> (viewed: Int, total: Int) {
        let assigned = student.assignedLessonIDs
        let viewed = student.viewedLessonIDs.filter { assigned.contains($0) }.count
        return (viewed, assigned.count)
    }

    func markLastActive(student: Student) {
        guard let si = students.firstIndex(where: { $0.id == student.id }) else { return }
        students[si].lastActiveDate = Date()
    }

    func recordSent(to student: Student, lessons: [Lesson], note: String, date: Date = Date()) {
        guard let si = students.firstIndex(where: { $0.id == student.id }) else { return }
        let pkg = SentPackage(
            date: date,
            lessonTitles: lessons.map(\.title),
            note: note
        )
        students[si].sentHistory.insert(pkg, at: 0)
        students[si].lastActiveDate = date
    }

    /// Composer: Schülern Lektionen und Bibliothek-Inhalte zuweisen und Share-Items vorbereiten.
    func deliverComposerPackage(
        to studentIDs: Set<UUID>,
        lessonIDs: Set<UUID>,
        contentItemIDs: Set<UUID>,
        note: String,
        date: Date
    ) -> [Any] {
        let targets = students.filter { studentIDs.contains($0.id) }
        guard !targets.isEmpty else { return [] }

        var lessonsToDeliver = lessons.filter { lessonIDs.contains($0.id) }

        if !contentItemIDs.isEmpty {
            let folderID = folders.first?.id ?? UUID()
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            let dateStr = formatter.string(from: date)
            var composerLesson = Lesson(
                folderID: folderID,
                title: "Lernpaket \(dateStr)",
                description: "Zusammengestellt im Composer",
                icon: "square.and.pencil",
                contentItemIDs: Array(contentItemIDs)
            )
            composerLesson.dateCreated = date
            lessons.append(composerLesson)
            lessonsToDeliver.append(composerLesson)
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var shareItems: [Any] = [Self.composerShareHint]

        if !trimmedNote.isEmpty {
            let dateStr = date.formatted(date: .long, time: .omitted)
            let names = targets.map(\.name).joined(separator: ", ")
            shareItems.append("Grünbuch · Composer · \(names) · \(dateStr)\n\n\(trimmedNote)")
        }

        for lesson in lessonsToDeliver {
            if let url = exportLesson(lesson) {
                shareItems.append(url)
            }
        }

        for student in targets {
            for lesson in lessonsToDeliver {
                if let si = students.firstIndex(where: { $0.id == student.id }),
                   !students[si].assignedLessonIDs.contains(lesson.id) {
                    students[si].assignedLessonIDs.append(lesson.id)
                }
            }
            recordSent(to: student, lessons: lessonsToDeliver, note: trimmedNote, date: date)
        }

        return shareItems
    }

    // MARK: - Pro Notes

    func addNote(title: String = "", text: String = "", audioFilename: String? = nil,
                 studentID: UUID? = nil, groupID: UUID? = nil) {
        let color = ALNoteStyle.palette[proNotes.count % ALNoteStyle.palette.count]
        let note = ProNote(title: title, text: text, audioFilename: audioFilename,
                           assignedStudentID: studentID, assignedGroupID: groupID,
                           colorHex: color)
        proNotes.insert(note, at: 0)
    }

    func updateNote(_ note: ProNote) {
        if let idx = proNotes.firstIndex(where: { $0.id == note.id }) {
            proNotes[idx] = note
        }
    }

    func deleteNote(_ note: ProNote) {
        if let audio = note.audioFilename {
            try? FileManager.default.removeItem(at: imageURL(for: audio))
        }
        proNotes.removeAll { $0.id == note.id }
    }

    func notesFor(student: Student) -> [ProNote] {
        proNotes.filter { $0.assignedStudentID == student.id }
    }

    func notesFor(group: TeachingGroup) -> [ProNote] {
        proNotes.filter { $0.assignedGroupID == group.id }
    }

    // MARK: - File URLs

    func imageURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func saveImage(_ data: Data, filename: String) {
        try? data.write(to: imageURL(for: filename))
    }

    // MARK: - Content Pool (Datenpool)

    func addContentItem(_ item: ContentItem) {
        contentPool.insert(item, at: 0)
    }

    func updateContentItem(_ item: ContentItem) {
        if let idx = contentPool.firstIndex(where: { $0.id == item.id }) {
            contentPool[idx] = item
        }
    }

    func deleteContentItem(_ item: ContentItem) {
        try? FileManager.default.removeItem(at: imageURL(for: item.filename))
        if let thumb = item.thumbnailFilename {
            try? FileManager.default.removeItem(at: imageURL(for: thumb))
        }
        contentPool.removeAll { $0.id == item.id }
    }

    /// Löst die im Datenpool referenzierten Inhalte einer Lektion auf — in der
    /// Reihenfolge, in der sie der Lektion zugeordnet wurden.
    func contentItems(for lesson: Lesson) -> [ContentItem] {
        guard !lesson.contentItemIDs.isEmpty else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: contentPool.map { ($0.id, $0) })
        return lesson.contentItemIDs.compactMap { lookup[$0] }
    }

    /// Hängt einen Datenpool-Inhalt an eine bestehende Lektion an ("nachliefern"),
    /// ohne die Lektion sonst zu verändern. Verhindert doppelte Verknüpfung.
    func addContentItem(_ item: ContentItem, toLesson lesson: Lesson) {
        guard let idx = lessons.firstIndex(where: { $0.id == lesson.id }) else { return }
        guard !lessons[idx].contentItemIDs.contains(item.id) else { return }
        lessons[idx].contentItemIDs.append(item.id)
    }

    private func saveContentPool() {
        if let data = try? JSONEncoder().encode(contentPool) {
            UserDefaults.standard.set(data, forKey: "al_contentpool")
        }
    }

    // MARK: - Content Classes (Klassen im Datenpool)

    func addContentClass(title: String, icon: String = "folder.fill", colorHex: String = "2C5F2D") {
        let c = ContentClass(title: title, icon: icon, colorHex: colorHex, sortIndex: contentClasses.count)
        contentClasses.append(c)
    }

    func updateContentClass(_ contentClass: ContentClass) {
        if let idx = contentClasses.firstIndex(where: { $0.id == contentClass.id }) {
            contentClasses[idx] = contentClass
        }
    }

    /// Löscht eine Klasse. Die enthaltenen Inhalte bleiben erhalten und
    /// wandern zurück nach "Unsortiert" (classID = nil) — es gehen also
    /// nie Dateien verloren, nur die Ordner-Zuordnung.
    func deleteContentClass(_ contentClass: ContentClass) {
        for i in contentPool.indices where contentPool[i].classID == contentClass.id {
            contentPool[i].classID = nil
        }
        contentClasses.removeAll { $0.id == contentClass.id }
    }

    func items(in contentClass: ContentClass) -> [ContentItem] {
        contentPool.filter { $0.classID == contentClass.id }
    }

    /// Inhalte, die noch keiner Klasse zugeordnet sind.
    var unclassifiedItems: [ContentItem] {
        contentPool.filter { $0.classID == nil }
    }

    /// Verschiebt einen Inhalt in eine Klasse (oder mit nil nach "Unsortiert").
    func move(_ item: ContentItem, toClass classID: UUID?) {
        guard let idx = contentPool.firstIndex(where: { $0.id == item.id }) else { return }
        contentPool[idx].classID = classID
    }

    private func saveContentClasses() {
        if let data = try? JSONEncoder().encode(contentClasses) {
            UserDefaults.standard.set(data, forKey: "al_contentclasses")
        }
    }

    // MARK: - Datenpool-Import
    //
    // Zentrale Import-Logik, genutzt von der Datenpool-Übersicht (Kachel
    // "Golf-Inhalte erfassen" → Eingang) und der Klassen-Ansicht (→ jeweilige
    // Klasse). `classID` bestimmt, wo der neue Inhalt landet (nil = Eingang).

    @MainActor
    func importPhotoItems(_ items: [PhotosPickerItem], into classID: UUID?) async {
        for item in items {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg")
            let filename = "pool_\(UUID().uuidString).\(ext)"
            saveImage(data, filename: filename)

            var thumbFilename: String? = nil
            if isVideo, let thumbData = await generateVideoThumbnail(url: imageURL(for: filename)) {
                thumbFilename = "pool_thumb_\(UUID().uuidString).jpg"
                saveImage(thumbData, filename: thumbFilename!)
            }

            let newItem = ContentItem(title: isVideo ? "Video \(importDateStamp())" : "Bild \(importDateStamp())",
                                      type: isVideo ? .video : .image,
                                      filename: filename, thumbnailFilename: thumbFilename,
                                      source: .imported, classID: classID)
            addContentItem(newItem)
        }
    }

    @MainActor
    func importFiles(_ urls: [URL], into classID: UUID?) async {
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }

            let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
            let filename = "pool_\(UUID().uuidString).\(ext)"
            saveImage(data, filename: filename)

            let type = contentType(forExtension: url.pathExtension)
            var thumbFilename: String? = nil
            if type == .video, let thumbData = await generateVideoThumbnail(url: imageURL(for: filename)) {
                thumbFilename = "pool_thumb_\(UUID().uuidString).jpg"
                saveImage(thumbData, filename: thumbFilename!)
            }

            let rawTitle = url.deletingPathExtension().lastPathComponent
            let newItem = ContentItem(title: rawTitle.isEmpty ? type.label : rawTitle,
                                      type: type, filename: filename, thumbnailFilename: thumbFilename,
                                      source: .imported, classID: classID)
            addContentItem(newItem)
        }
    }

    @MainActor
    func importRecordedVideo(from url: URL, into classID: UUID?) async {
        guard let data = try? Data(contentsOf: url) else { return }
        let filename = "pool_\(UUID().uuidString).mov"
        saveImage(data, filename: filename)

        var thumbFilename: String? = nil
        if let thumbData = await generateVideoThumbnail(url: imageURL(for: filename)) {
            thumbFilename = "pool_thumb_\(UUID().uuidString).jpg"
            saveImage(thumbData, filename: thumbFilename!)
        }
        let newItem = ContentItem(title: "Aufnahme \(importDateStamp())", type: .video,
                                  filename: filename, thumbnailFilename: thumbFilename,
                                  source: .recorded, classID: classID)
        addContentItem(newItem)
        try? FileManager.default.removeItem(at: url)
    }

    func contentType(forExtension ext: String) -> ContentType {
        guard let utType = UTType(filenameExtension: ext) else { return .text }
        if utType.conforms(to: .pdf) { return .pdf }
        if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
        if utType.conforms(to: .image) { return .image }
        if utType.conforms(to: .audio) { return .audio }
        return .text
    }

    private func generateVideoThumbnail(url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let result = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 60)) else { return nil }
        return UIImage(cgImage: result.image).jpegData(compressionQuality: 0.7)
    }

    private func importDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM. HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Progress

    func markCompleted(_ lessonID: UUID) {
        if let idx = progress.firstIndex(where: { $0.lessonID == lessonID }) {
            progress[idx].isCompleted = true
            progress[idx].dateViewed = Date()
        } else {
            progress.append(StudentProgress(lessonID: lessonID, isCompleted: true))
        }
    }

    func recordLessonOpened(_ lesson: Lesson) {
        if let idx = progress.firstIndex(where: { $0.lessonID == lesson.id }) {
            progress[idx].dateViewed = Date()
        } else {
            progress.append(StudentProgress(lessonID: lesson.id, dateViewed: Date()))
        }
    }

    /// Lektionstitel, die der Schüler auf diesem Gerät bereits geöffnet oder abgeschlossen hat.
    func studentViewedLessonTitles() -> [String] {
        let viewedIDs = Set(progress.map(\.lessonID))
        return lessons.filter { viewedIDs.contains($0.id) }.map(\.title)
    }

    func markSessionOpened(_ session: TrainingSession) {
        guard session.source == .received,
              let idx = sessions.firstIndex(where: { $0.id == session.id }),
              sessions[idx].openedDate == nil else { return }
        sessions[idx].openedDate = Date()
    }

    var unreadReceivedSessions: [TrainingSession] {
        receivedSessions.filter { $0.openedDate == nil }
    }

    func isCompleted(_ lessonID: UUID) -> Bool {
        progress.first(where: { $0.lessonID == lessonID })?.isCompleted ?? false
    }

    // MARK: - Export / Share (Lektion)

    func exportLesson(_ lesson: Lesson) -> URL? {
        var imageData: [String: Data] = [:]
        for filename in lesson.imageFilenames {
            if let data = try? Data(contentsOf: imageURL(for: filename)) {
                imageData[filename] = data
            }
        }
        // Datenpool-Inhalte der Lektion mit einbetten (Datei + ggf. Thumbnail
        // sowie die ContentItem-Metadaten), damit das Paket beim Schüler
        // weiterhin "self-contained" ankommt — inkl. nachträglich gelieferter Inhalte.
        let poolItems = contentItems(for: lesson)
        for item in poolItems {
            if let data = try? Data(contentsOf: imageURL(for: item.filename)) {
                imageData[item.filename] = data
            }
            if let thumb = item.thumbnailFilename,
               let data = try? Data(contentsOf: imageURL(for: thumb)) {
                imageData[thumb] = data
            }
        }
        let package = AfterLessonShare(
            lesson: lesson,
            imageData: imageData,
            contentItems: poolItems,
            exportDate: Date(),
            teacherName: teacherName
        )
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        let safeName = lesson.title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Grünbuch_\(safeName).afterlesson")
        try? data.write(to: url)
        return url
    }

    func importLesson(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let package = try? JSONDecoder().decode(AfterLessonShare.self, from: data)
        else { return false }
        for (filename, imgData) in package.imageData {
            saveImage(imgData, filename: filename)
        }
        // Mitgelieferte Datenpool-Inhalte unter denselben IDs registrieren, damit
        // contentItemIDs der importierten Lektion auflösbar bleiben — und doppelte
        // Einträge vermeiden, falls derselbe Inhalt schon vorhanden ist.
        var newPoolItems = package.contentItems.filter { item in
            !contentPool.contains(where: { $0.id == item.id })
        }
        // classID des Absenders zeigt auf eine Klasse, die es auf diesem Gerät
        // nicht gibt — zurücksetzen, sonst wäre der Inhalt im Datenpool unsichtbar
        // (weder in einer Klasse noch unter "Unsortiert" auffindbar).
        for i in newPoolItems.indices {
            if let cid = newPoolItems[i].classID,
               !contentClasses.contains(where: { $0.id == cid }) {
                newPoolItems[i].classID = nil
            }
        }
        if !newPoolItems.isEmpty {
            contentPool.insert(contentsOf: newPoolItems, at: 0)
        }
        var newLesson = package.lesson
        newLesson.id = UUID()
        newLesson.origin = .receivedFromPro
        newLesson.receivedFromPro = package.teacherName
        newLesson.openedDate = nil
        newLesson.dateCreated = package.exportDate
        if !folders.contains(where: { $0.id == newLesson.folderID }) {
            newLesson.folderID = folders.first?.id ?? UUID()
        }
        lessons.insert(newLesson, at: 0)
        return true
    }

    // MARK: - Export Folder

    func exportFolder(_ folder: LessonFolder) -> URL? {
        let folderLessons = lessonsIn(folder)
        var imageData: [String: Data] = [:]
        var seenContentIDs: Set<UUID> = []
        var poolItems: [ContentItem] = []
        for lesson in folderLessons {
            for filename in lesson.imageFilenames {
                if let data = try? Data(contentsOf: imageURL(for: filename)) {
                    imageData[filename] = data
                }
            }
            // Datenpool-Inhalte aller Lektionen des Ordners einsammeln — dedupliziert,
            // falls mehrere Lektionen denselben Inhalt referenzieren (z.B. ein Video,
            // das in zwei Lektionen verwendet wird, soll nur einmal eingebettet werden).
            for item in contentItems(for: lesson) where !seenContentIDs.contains(item.id) {
                seenContentIDs.insert(item.id)
                poolItems.append(item)
                if let data = try? Data(contentsOf: imageURL(for: item.filename)) {
                    imageData[item.filename] = data
                }
                if let thumb = item.thumbnailFilename,
                   let data = try? Data(contentsOf: imageURL(for: thumb)) {
                    imageData[thumb] = data
                }
            }
        }
        let package = AfterLessonFolderShare(
            folder: folder,
            lessons: folderLessons,
            imageData: imageData,
            contentItems: poolItems,
            exportDate: Date(),
            teacherName: teacherName
        )
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        let safeName = folder.title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Grünbuch_\(safeName).afterlessonfolder")
        try? data.write(to: url)
        return url
    }

    // MARK: - Persistence

    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "al_folders")
        }
    }

    private func saveLessons() {
        if let data = try? JSONEncoder().encode(lessons) {
            UserDefaults.standard.set(data, forKey: "al_lessons")
        }
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: "al_progress")
        }
    }

    // MARK: - Groups (Unterrichtsgruppen)

    func addGroup(name: String, icon: String = "person.3.fill", colorHex: String? = nil, notes: String = "") {
        let defaults = ["1B5E20", "1565C0", "4A148C", "E65100", "880E4F", "006064"]
        let color = colorHex ?? defaults[groups.count % defaults.count]
        var g = TeachingGroup(name: name, colorHex: color, icon: icon)
        g.notes = notes
        groups.append(g)
    }

    func updateGroup(_ group: TeachingGroup) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx] = group
        }
    }

    func deleteGroup(_ group: TeachingGroup) {
        groups.removeAll { $0.id == group.id }
    }

    func toggleStudent(_ student: Student, in group: TeachingGroup) {
        guard let gi = groups.firstIndex(where: { $0.id == group.id }) else { return }
        if groups[gi].studentIDs.contains(student.id) {
            groups[gi].studentIDs.removeAll { $0 == student.id }
        } else {
            groups[gi].studentIDs.append(student.id)
        }
    }

    func toggleLesson(_ lesson: Lesson, in group: TeachingGroup) {
        guard let gi = groups.firstIndex(where: { $0.id == group.id }) else { return }
        if groups[gi].lessonIDs.contains(lesson.id) {
            groups[gi].lessonIDs.removeAll { $0 == lesson.id }
        } else {
            groups[gi].lessonIDs.append(lesson.id)
        }
    }

    func studentsIn(_ group: TeachingGroup) -> [Student] {
        students.filter { group.studentIDs.contains($0.id) }
    }

    func lessonsIn(_ group: TeachingGroup) -> [Lesson] {
        lessons.filter { group.lessonIDs.contains($0.id) }
    }

    func exportGroup(_ group: TeachingGroup) -> [URL] {
        lessonsIn(group).compactMap { exportLesson($0) }
    }

    private func saveStudents() {
        if let data = try? JSONEncoder().encode(students) {
            UserDefaults.standard.set(data, forKey: "al_students")
        }
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: "al_groups")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "al_folders"),
           let decoded = try? JSONDecoder().decode([LessonFolder].self, from: data) {
            folders = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_lessons"),
           let decoded = try? JSONDecoder().decode([Lesson].self, from: data) {
            lessons = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_progress"),
           let decoded = try? JSONDecoder().decode([StudentProgress].self, from: data) {
            progress = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_students"),
           let decoded = try? JSONDecoder().decode([Student].self, from: data) {
            students = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_groups"),
           let decoded = try? JSONDecoder().decode([TeachingGroup].self, from: data) {
            groups = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_pronotes"),
           let decoded = try? JSONDecoder().decode([ProNote].self, from: data) {
            proNotes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_contentpool"),
           let decoded = try? JSONDecoder().decode([ContentItem].self, from: data) {
            contentPool = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_contentclasses"),
           let decoded = try? JSONDecoder().decode([ContentClass].self, from: data) {
            contentClasses = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_sessions"),
           let decoded = try? JSONDecoder().decode([TrainingSession].self, from: data) {
            sessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "al_studentcaptures"),
           let decoded = try? JSONDecoder().decode([StudentCapture].self, from: data) {
            studentCaptures = decoded
        }
    }

    private func saveProNotes() {
        if let data = try? JSONEncoder().encode(proNotes) {
            UserDefaults.standard.set(data, forKey: "al_pronotes")
        }
    }

    // MARK: - Student Captures (Live — nur Schülerprofil, nicht Bibliothek)

    func capturesFor(_ student: Student) -> [StudentCapture] {
        studentCaptures.filter { $0.studentID == student.id }
            .sorted { $0.date > $1.date }
    }

    func capturesFor(session: TrainingSession) -> [StudentCapture] {
        studentCaptures.filter { $0.sessionID == session.id }
            .sorted { $0.date < $1.date }
    }

    func addStudentCapture(_ capture: StudentCapture) {
        studentCaptures.insert(capture, at: 0)
        markLastActive(studentID: capture.studentID, date: capture.date)
    }

    @MainActor
    func addStudentCaptureFromPhoto(
        data: Data,
        studentID: UUID,
        sessionID: UUID? = nil,
        title: String? = nil
    ) async {
        let filename = "capture_\(UUID().uuidString).jpg"
        saveImage(data, filename: filename)
        let capture = StudentCapture(
            studentID: studentID,
            sessionID: sessionID,
            type: .image,
            title: title ?? "Foto \(importDateStamp())",
            filename: filename
        )
        addStudentCapture(capture)
    }

    @MainActor
    func addStudentCaptureFromVideo(
        url: URL,
        studentID: UUID,
        sessionID: UUID? = nil
    ) async {
        guard let data = try? Data(contentsOf: url) else { return }
        let filename = "capture_\(UUID().uuidString).mov"
        saveImage(data, filename: filename)

        var thumbFilename: String? = nil
        if let thumbData = await generateVideoThumbnail(url: imageURL(for: filename)) {
            thumbFilename = "capture_thumb_\(UUID().uuidString).jpg"
            saveImage(thumbData, filename: thumbFilename!)
        }

        let capture = StudentCapture(
            studentID: studentID,
            sessionID: sessionID,
            type: .video,
            title: "Video \(importDateStamp())",
            filename: filename,
            thumbnailFilename: thumbFilename
        )
        addStudentCapture(capture)
        try? FileManager.default.removeItem(at: url)
    }

    func addStudentCaptureTextNote(
        _ text: String,
        studentID: UUID,
        sessionID: UUID? = nil,
        title: String? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let capture = StudentCapture(
            studentID: studentID,
            sessionID: sessionID,
            type: .text,
            title: title ?? "Notiz \(importDateStamp())",
            textNote: trimmed
        )
        addStudentCapture(capture)
    }

    func deleteStudentCapture(_ capture: StudentCapture) {
        if let filename = capture.filename {
            try? FileManager.default.removeItem(at: imageURL(for: filename))
        }
        if let thumb = capture.thumbnailFilename {
            try? FileManager.default.removeItem(at: imageURL(for: thumb))
        }
        studentCaptures.removeAll { $0.id == capture.id }
    }

    private func markLastActive(studentID: UUID, date: Date = Date()) {
        guard let si = students.firstIndex(where: { $0.id == studentID }) else { return }
        students[si].lastActiveDate = date
    }

    private func saveStudentCaptures() {
        if let data = try? JSONEncoder().encode(studentCaptures) {
            UserDefaults.standard.set(data, forKey: "al_studentcaptures")
        }
    }

    // MARK: - Training Sessions

    func addSession(_ session: TrainingSession) {
        sessions.insert(session, at: 0)
        if let sid = session.studentID {
            markLastActive(studentID: sid, date: session.date)
        }
    }

    func updateSession(_ session: TrainingSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        }
    }

    func deleteSession(_ session: TrainingSession) {
        for f in session.imageFilenames {
            try? FileManager.default.removeItem(at: imageURL(for: f))
        }
        sessions.removeAll { $0.id == session.id }
    }

    func sessionsFor(_ student: Student) -> [TrainingSession] {
        sessions.filter { $0.studentID == student.id }
            .sorted { $0.date > $1.date }
    }

    var createdSessions: [TrainingSession] {
        sessions.filter { $0.source == .created }.sorted { $0.date > $1.date }
    }

    var receivedSessions: [TrainingSession] {
        sessions.filter { $0.source == .received }.sorted { $0.date > $1.date }
    }

    var receivedLessons: [Lesson] {
        lessons.filter { $0.origin == .receivedFromPro }.sorted { $0.dateCreated > $1.dateCreated }
    }

    var unreadReceivedLessons: [Lesson] {
        receivedLessons.filter { $0.openedDate == nil }
    }

    func markLessonOpened(_ lesson: Lesson) {
        guard let idx = lessons.firstIndex(where: { $0.id == lesson.id }) else { return }
        if lessons[idx].openedDate == nil {
            lessons[idx].openedDate = Date()
        }
    }

    // MARK: - Session Export / Import

    func exportSession(_ session: TrainingSession) -> URL? {
        let package = AfterLessonSessionShare(
            session: session,
            teacherName: teacherName,
            exportDate: Date()
        )
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        let safeName = session.title
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "·", with: "")
            .trimmingCharacters(in: .whitespaces)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Grünbuch_\(safeName).afterlessonsession")
        try? data.write(to: url)
        return url
    }

    func importSessionShare(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let package = try? JSONDecoder().decode(AfterLessonSessionShare.self, from: data)
        else { return false }
        var session = package.session
        session.id = UUID()
        session.source = .received
        session.teacherName = package.teacherName
        session.openedDate = nil
        sessions.insert(session, at: 0)
        return true
    }

    // MARK: - Student Feedback Export / Import

    func exportFeedback(
        kind: FeedbackKind,
        message: String,
        lessonTitle: String? = nil,
        sessionTitle: String? = nil
    ) -> URL? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let package = AfterLessonFeedbackShare(
            studentName: teacherName.isEmpty ? "Schüler" : teacherName,
            message: trimmed,
            kind: kind,
            lessonTitle: lessonTitle,
            sessionTitle: sessionTitle,
            viewedLessonTitles: studentViewedLessonTitles(),
            exportDate: Date()
        )
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        let safeName = (teacherName.isEmpty ? "Rueckmeldung" : teacherName)
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Grünbuch_\(safeName).afterlessonfeedback")
        try? data.write(to: url)
        return url
    }

    static let feedbackShareHint = """
    Grünbuch Rückmeldung — bitte an deinen Golf Pro senden (AirDrop, WhatsApp oder E-Mail). \
    Er öffnet die Datei in Grünbuch und sieht deine Nachricht.
    """

    static let sessionShareHint = """
    Grünbuch Trainingsprotokoll — bitte an deinen Schüler senden (AirDrop, WhatsApp oder E-Mail). \
    Der Schüler öffnet die Datei in Grünbuch im Schüler-Modus.
    """

    static let lessonShareHint = """
    Grünbuch Lektion — bitte an deinen Schüler senden (AirDrop, WhatsApp oder E-Mail). \
    Der Schüler öffnet die Datei in Grünbuch im Schüler-Modus; sie erscheint unter „Zugewiesen“.
    """

    static let composerShareHint = """
    Grünbuch Lernpaket — per AirDrop an deinen Schüler senden (am einfachsten: AirDrop oben wählen). \
    Der Schüler tippt die .afterlesson-Datei(en) an und öffnet sie in Grünbuch im Schüler-Modus — \
    die Inhalte erscheinen unter „Zugewiesen“. Einzelne Lektionen oder Nachreichungen können später \
    separat gesendet werden.
    """

    func importFeedbackShare(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let package = try? JSONDecoder().decode(AfterLessonFeedbackShare.self, from: data)
        else { return false }

        let name = package.studentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }

        let entry = StudentFeedbackEntry(
            date: package.exportDate,
            kind: package.kind,
            message: package.message,
            lessonTitle: package.lessonTitle,
            sessionTitle: package.sessionTitle,
            viewedLessonTitles: package.viewedLessonTitles
        )

        if let si = students.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            students[si].feedbackHistory.insert(entry, at: 0)
            students[si].remarks = package.message
            students[si].lastActiveDate = package.exportDate
            applyViewedLessonTitles(package.viewedLessonTitles, toStudentAt: si)
        } else {
            var student = Student(name: name)
            student.feedbackHistory = [entry]
            student.remarks = package.message
            student.lastActiveDate = package.exportDate
            students.append(student)
            if let si = students.firstIndex(where: { $0.id == student.id }) {
                applyViewedLessonTitles(package.viewedLessonTitles, toStudentAt: si)
            }
        }
        return true
    }

    private func applyViewedLessonTitles(_ titles: [String], toStudentAt si: Int) {
        guard si < students.count, !titles.isEmpty else { return }
        let titleSet = Set(titles)
        for lesson in lessons where titleSet.contains(lesson.title) {
            if !students[si].viewedLessonIDs.contains(lesson.id) {
                students[si].viewedLessonIDs.append(lesson.id)
            }
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "al_sessions")
        }
    }

    // MARK: - Activity Feed (Kommunikations-Hub)

    func teacherActivityFeed(limit: Int = 8) -> [ActivityItem] {
        var items: [ActivityItem] = []

        for student in students {
            for pkg in student.sentHistory {
                items.append(ActivityItem(
                    date: pkg.date,
                    icon: "paperplane.fill",
                    tintHex: "1565C0",
                    title: "An \(student.name) gesendet",
                    subtitle: pkg.lessonTitles.isEmpty
                        ? (pkg.note.isEmpty ? "Lektionspaket" : pkg.note)
                        : pkg.lessonTitles.joined(separator: " · "),
                    status: packageStatus(pkg, for: student)
                ))
            }
            if !student.remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items.append(ActivityItem(
                    date: student.lastActiveDate ?? student.dateCreated,
                    icon: "text.bubble.fill",
                    tintHex: "880E4F",
                    title: "Rückmeldung von \(student.name)",
                    subtitle: String(student.remarks.prefix(100)),
                    status: .new
                ))
            }
            for entry in student.feedbackHistory.prefix(3) {
                if entry.message == student.remarks { continue }
                items.append(ActivityItem(
                    date: entry.date,
                    icon: entry.kind.icon,
                    tintHex: "880E4F",
                    title: "Rückmeldung von \(student.name)",
                    subtitle: entrySubtitle(entry),
                    status: .new
                ))
            }
        }

        for session in createdSessions {
            let studentName = students.first(where: { $0.id == session.studentID })?.name ?? "Schüler"
            items.append(ActivityItem(
                date: session.date,
                icon: "figure.golf",
                tintHex: "1B5E20",
                title: "Stunde · \(studentName)",
                subtitle: session.title.isEmpty
                    ? (session.trained.isEmpty ? "Training dokumentiert" : session.trained)
                    : session.title,
                status: .completed
            ))
        }

        for capture in studentCaptures.prefix(5) {
            let studentName = students.first(where: { $0.id == capture.studentID })?.name ?? "Schüler"
            items.append(ActivityItem(
                date: capture.date,
                icon: capture.type.icon,
                tintHex: capture.type.colorHex,
                title: "Aufnahme · \(studentName)",
                subtitle: capture.title.isEmpty ? capture.type.label : capture.title,
                status: .completed
            ))
        }

        return Array(items.sorted { $0.date > $1.date }.prefix(limit))
    }

    func studentActivityFeed(limit: Int = 8) -> [ActivityItem] {
        var items: [ActivityItem] = []

        for lesson in receivedLessons {
            let isNew = lesson.openedDate == nil
            let done = isCompleted(lesson.id)
            items.append(ActivityItem(
                date: lesson.dateCreated,
                icon: done ? "checkmark.circle.fill" : "book.fill",
                tintHex: done ? "2D6A30" : "E65100",
                title: lesson.title,
                subtitle: lesson.receivedFromPro.isEmpty
                    ? (done ? "Übung abgeschlossen" : "Vom Pro zugewiesen")
                    : "Von \(lesson.receivedFromPro)",
                status: isNew ? .new : (done ? .completed : .received)
            ))
        }

        for session in receivedSessions {
            let isNew = session.openedDate == nil
            items.append(ActivityItem(
                date: session.date,
                icon: "doc.text.fill",
                tintHex: "1B5E20",
                title: session.teacherName.isEmpty ? "Trainingsprotokoll" : "Von \(session.teacherName)",
                subtitle: session.homework.isEmpty
                    ? (session.title.isEmpty ? "Dein letztes Training" : session.title)
                    : session.homework,
                status: isNew ? .new : .received
            ))
        }

        for lesson in lessons where lesson.origin == .local {
            let done = isCompleted(lesson.id)
            items.append(ActivityItem(
                date: lesson.dateCreated,
                icon: done ? "checkmark.circle.fill" : "book.fill",
                tintHex: done ? "2D6A30" : "E65100",
                title: lesson.title,
                subtitle: done ? "Übung abgeschlossen — weiter so!" : "Bereit zum Üben",
                status: done ? .completed : .inProgress
            ))
        }

        return Array(items.sorted { $0.date > $1.date }.prefix(limit))
    }

    func packageStatus(_ pkg: SentPackage, for student: Student) -> ActivityStatus {
        guard !pkg.lessonTitles.isEmpty else { return .sent }
        let viewedTitles = Set(
            student.viewedLessonIDs.compactMap { id in lessons.first(where: { $0.id == id })?.title }
        )
        let sentTitles = Set(pkg.lessonTitles)
        if sentTitles.isSubset(of: viewedTitles) { return .completed }
        if !sentTitles.isDisjoint(with: viewedTitles) { return .inProgress }
        return .sent
    }

    private func entrySubtitle(_ entry: StudentFeedbackEntry) -> String {
        var parts: [String] = [entry.message]
        if let lesson = entry.lessonTitle, !lesson.isEmpty {
            parts.append("Lektion: \(lesson)")
        }
        if !entry.viewedLessonTitles.isEmpty {
            parts.append("Gelesen: \(entry.viewedLessonTitles.joined(separator: ", "))")
        }
        return String(parts.joined(separator: " · ").prefix(120))
    }
}
