// HomeView – Startbildschirm: Composer-Flow, Session-Zeilen, Schüler-Banner.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedTab: ContentView.Tab
    @State private var showComposer = false
    @State private var composerPreselectedStudents: Set<UUID> = []
    @State private var composerIsSupplemental = false
    @State private var composerShareItems: [Any] = []
    @State private var showComposerShare = false
    @State private var selectedSession: TrainingSession? = nil
    @State private var selectedReceivedLesson: Lesson? = nil
    @State private var showQuickCapture = false
    @State private var quickCaptureStudentID: UUID? = nil

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    private var roleLabel: String {
        let name = store.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTeacher {
            let display = name.isEmpty
                ? NSLocalizedString("Golf Pro", comment: "")
                : name
            return String(format: NSLocalizedString("Pro: %@", comment: ""), display)
        }
        let display = name.isEmpty ? "—" : name
        return String(format: NSLocalizedString("Schüler: %@", comment: ""), display)
    }

    var body: some View {
        ZStack {
            GrünbuchHomeBackground()

            VStack(spacing: 0) {
                headerBar
                if isTeacher {
                    teacherContent
                } else {
                    studentContent
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            ComposerSheet(
                preselectedStudentIDs: composerPreselectedStudents,
                isSupplemental: composerIsSupplemental
            ) { items in
                composerShareItems = items
                showComposerShare = true
            }
        }
        .onChange(of: showComposer) { _, isShowing in
            if !isShowing {
                composerPreselectedStudents = []
                composerIsSupplemental = false
            }
        }
        .sheet(isPresented: $showComposerShare) {
            ShareSheet(items: composerShareItems)
        }
        .sheet(item: $selectedSession) { session in SessionDetailSheet(session: session) }
        .sheet(item: $selectedReceivedLesson) { lesson in
            LessonDetailView(lesson: lesson)
                .onAppear { store.markLessonOpened(lesson) }
        }
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureSheet(preselectedStudentID: quickCaptureStudentID)
        }
        .onChange(of: showQuickCapture) { _, isShowing in
            if !isShowing { quickCaptureStudentID = nil }
        }
        // Schüler: beim Betreten des Startbildschirms neue Cloud-Pakete
        // abholen — sie landen im vertrauten "Neues vom Pro"-Fluss.
        .task {
            if !isTeacher {
                _ = await store.importCloudPackages()
            }
        }
        // … und auch immer, wenn die App in den Vordergrund kommt.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !isTeacher {
                Task { _ = await store.importCloudPackages() }
            }
        }
    }

    // MARK: Header Bar
    var headerBar: some View {
        GrünbuchHomeHeader(roleLabel: roleLabel)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    // MARK: Teacher Content
    var teacherContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            GrünbuchFairwayGraphic()
                .padding(.horizontal, 20)

            Spacer(minLength: 22)

            // Die Drehscheibe: der große grüne Aktions-Orb
            GrünbuchComposerOrb {
                composerPreselectedStudents = []
                composerIsSupplemental = false
                showComposer = true
            }
            .padding(.bottom, 6)

            // Die beiden Werkzeuge als Bild-Kacheln: Bücherregal & Golfer
            HStack(spacing: 14) {
                GrünbuchToolTile(
                    title: "Bibliothek",
                    subtitle: "Lernstoff & Tipps",
                    tint: ALColor.gold,
                    action: { selectedTab = .lessons }
                ) {
                    GrünbuchBookshelfIllustration()
                }

                GrünbuchToolTile(
                    title: "Stunde erfassen",
                    subtitle: "Direkt am Schüler",
                    tint: Color(hex: "1565C0"),
                    action: {
                        quickCaptureStudentID = nil
                        showQuickCapture = true
                    }
                ) {
                    GrünbuchPlayerIllustration()
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 16)
        }
    }

    // MARK: Student Content
    var studentContent: some View {
        VStack(spacing: 0) {
            let newCount = store.unreadReceivedSessions.count + store.unreadReceivedLessons.count
            if newCount > 0 {
                NewFromProBanner(
                    count: newCount,
                    teacherName: store.unreadReceivedSessions.first?.teacherName
                        ?? store.unreadReceivedLessons.first?.receivedFromPro
                        ?? ""
                ) {
                    if let session = store.unreadReceivedSessions.first {
                        selectedSession = session
                    } else if let lesson = store.unreadReceivedLessons.first {
                        selectedReceivedLesson = lesson
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Spacer(minLength: 12)

            if store.receivedSessions.isEmpty && store.receivedLessons.isEmpty {
                StudentEmptyPlaceholder()
                    .padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Eingang", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 20)
                    ForEach(store.receivedLessons.prefix(5)) { lesson in
                        studentLessonRow(lesson).padding(.horizontal, 20)
                    }
                    ForEach(store.receivedSessions.prefix(5)) { session in
                        studentSessionRow(session).padding(.horizontal, 20)
                    }
                    // Der Prozess in einem Satz — damit keine Magie
                    // unerklärt bleibt (Hans, 20.07.)
                    Text("home.inbox_hint")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 20)
                }
            }
            Spacer(minLength: 16)
        }
    }

    /// In welche Bibliotheks-Gruppe die Inhalte dieser Lektion eingezogen sind.
    private func libraryGroupName(for lesson: Lesson) -> String? {
        for itemID in lesson.contentItemIDs {
            if let item = store.contentPool.first(where: { $0.id == itemID }),
               let classID = item.classID,
               let group = store.contentClasses.first(where: { $0.id == classID }) {
                return group.title
            }
        }
        return nil
    }

    @ViewBuilder
    func studentLessonRow(_ lesson: Lesson) -> some View {
        Button { selectedReceivedLesson = lesson } label: {
            HStack(spacing: 12) {
                Image(systemName: lesson.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ALColor.gold)
                    .alIconTile(tint: ALColor.gold, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(lesson.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white).lineLimit(1)
                        if lesson.openedDate == nil {
                            Text("Neu")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ALColor.gold)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(ALColor.gold.opacity(0.18), in: Capsule())
                        }
                    }
                    if lesson.openedDate != nil, let group = libraryGroupName(for: lesson) {
                        // Gesehen → zeigt, wohin die Inhalte eingezogen sind
                        HStack(spacing: 3) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 9))
                            Text(String(format: String(localized: "home.in_library"), group))
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .foregroundStyle(ALColor.gold.opacity(0.8))
                    } else if !lesson.receivedFromPro.isEmpty {
                        Text(String(format: String(localized: "von %@"), lesson.receivedFromPro))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                Text(lesson.dateCreated, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .alGlass(tint: ALColor.gold.opacity(0.16), interactive: true, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func studentSessionRow(_ session: TrainingSession) -> some View {
        Button { selectedSession = session } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ALColor.green)
                    .alIconTile(tint: ALColor.green, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.title.isEmpty ? "Trainingsstunde" : session.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white).lineLimit(1)
                        if session.openedDate == nil {
                            Text("Neu")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ALColor.gold)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(ALColor.gold.opacity(0.18), in: Capsule())
                        }
                    }
                    if !session.teacherName.isEmpty {
                        Text("von \(session.teacherName)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                Text(session.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .alGlass(tint: ALColor.green.opacity(0.20), interactive: true, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Nav Tile
    @ViewBuilder
    func navTile(icon: String, label: String, value: String, color: Color,
                 assetImage: String? = nil,
                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    // Eigenes Bild (z.B. Golfschmiede-Logo) statt SF-Symbol, falls angegeben
                    if let assetImage {
                        Image(assetImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                        .lineLimit(1)                  // kein Umbruch mitten im Wort ("Datenp ool")
                        .minimumScaleFactor(0.65)      // lange Wörter werden stattdessen etwas kleiner
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "AAAAAA"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "DDDDDD"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent Section — Letzte Stunde pro Schüler

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Stunde")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "888888"))
                Spacer()
                Button {
                    quickCaptureStudentID = nil
                    showQuickCapture = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Stunde erfassen").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(ALColor.gold)
                }
            }

            let studentRows: [(Student, TrainingSession)] = store.students.compactMap { student in
                guard let last = store.sessionsFor(student).sorted(by: { $0.date > $1.date }).first
                else { return nil }
                return (student, last)
            }.sorted { $0.1.date > $1.1.date }

            if studentRows.isEmpty {
                // Leerzustand
                Button {
                    quickCaptureStudentID = nil
                    showQuickCapture = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(ALColor.gold.opacity(0.7))
                            .frame(width: 38, height: 38)
                            .background(ALColor.gold.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text("Erste Stunde erfassen …")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "BBBBBB"))
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(ALColor.gold.opacity(0.20),
                                      style: StrokeStyle(lineWidth: 1, dash: [5, 3])))
                }
                .buttonStyle(.plain)

                // Schüler ohne Stunden anzeigen
                ForEach(store.students.filter { student in
                    !studentRows.map(\.0.id).contains(student.id)
                }) { student in
                    studentNoSessionRow(student: student)
                }
            } else {
                ForEach(studentRows, id: \.0.id) { (student, session) in
                    studentLastSessionRow(student: student, session: session)
                }
                // Schüler ohne Stunden darunter
                let withSession = Set(studentRows.map(\.0.id))
                ForEach(store.students.filter { !withSession.contains($0.id) }) { student in
                    studentNoSessionRow(student: student)
                }
            }
        }
    }

    // Schüler-Karte MIT letzter Stunde
    func studentLastSessionRow(student: Student, session: TrainingSession) -> some View {
        Button { selectedSession = session } label: {
            HStack(spacing: 12) {
                // Avatar
                studentAvatar(student, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(student.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "1A1A1A"))
                        if !student.handicap.isEmpty {
                            Text("HCP \(student.handicap)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ALColor.gold)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(ALColor.gold.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    // Letzte Stunde Info
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundStyle(ALColor.green)
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ALColor.green)
                        if !session.trained.isEmpty {
                            Text("· \(session.trained)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "AAAAAA"))
                                .lineLimit(1)
                        } else if !session.title.isEmpty {
                            Text("· \(session.title)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "AAAAAA"))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "CCCCCC"))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // Schüler-Karte OHNE Stunden
    func studentNoSessionRow(student: Student) -> some View {
        HStack(spacing: 12) {
            studentAvatar(student, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(student.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                    if !student.handicap.isEmpty {
                        Text("HCP \(student.handicap)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ALColor.gold)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(ALColor.gold.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text("Noch keine Stunde erfasst")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "CCCCCC"))
            }
            Spacer()
            Image(systemName: "figure.golf")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "DDDDDD"))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color(hex: "EEEEEE"), lineWidth: 1))
    }

    // Avatar Helper
    func studentAvatar(_ student: Student, size: CGFloat) -> some View {
        Group {
            if let filename = student.photoFilename,
               let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: student.avatarColor))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(student.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.38, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    // Session Row (für eventuelle andere Nutzung)
    @ViewBuilder
    func sessionRow(_ session: TrainingSession) -> some View {
        Button { selectedSession = session } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(ALColor.green.opacity(0.10))
                        .frame(width: 38, height: 38)
                    Image(systemName: "figure.golf")
                        .font(.system(size: 15))
                        .foregroundStyle(ALColor.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title.isEmpty ? "Trainingsstunde" : session.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "1A1A1A")).lineLimit(1)
                    if let sid = session.studentID,
                       let s = store.students.first(where: { $0.id == sid }) {
                        Text(s.name).font(.system(size: 11)).foregroundStyle(Color(hex: "AAAAAA"))
                    }
                }
                Spacer()
                Text(session.date, style: .date).font(.system(size: 11)).foregroundStyle(Color(hex: "CCCCCC"))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Composer Sheet

struct ComposerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    var preselectedStudentIDs: Set<UUID> = []
    var isSupplemental: Bool = false
    let onShare: ([Any]) -> Void

    @State private var selectedStudentIDs: Set<UUID> = []
    @State private var assignmentDate: Date = Date()
    @State private var selectedLessonIDs: Set<UUID> = []
    @State private var selectedContentItemIDs: Set<UUID> = []
    @State private var note: String = ""
    @State private var isSendingCloud = false
    @State private var cloudResultMessage: String? = nil

    /// Cloud-Versand ist möglich, wenn der Pro angemeldet ist und
    /// mindestens ein gewählter Schüler seinen Code eingelöst hat.
    private var cloudSendPossible: Bool {
        CloudService.shared.isSignedIn
            && store.students.contains { selectedStudentIDs.contains($0.id) && $0.cloudUserID != nil }
    }

    /// Warum der Cloud-Knopf gerade nicht kann — statt ihn zu verstecken.
    private var cloudBlockedReason: String {
        if !CloudService.shared.isConfigured {
            return String(localized: "cloud.blocked_not_configured")
        }
        if !CloudService.shared.isSignedIn {
            return String(localized: "cloud.blocked_not_signed_in")
        }
        return String(localized: "cloud.blocked_no_connected_student")
    }

    private func sendViaCloud() {
        isSendingCloud = true
        Task {
            let result = await store.sendComposerPackageViaCloud(
                to: selectedStudentIDs,
                lessonIDs: selectedLessonIDs,
                contentItemIDs: selectedContentItemIDs,
                note: note,
                date: assignmentDate
            )
            isSendingCloud = false
            if result.sent > 0 && result.withoutCloud.isEmpty {
                cloudResultMessage = String(format: String(localized: "cloud.composer_sent"), result.sent)
            } else if result.sent > 0 {
                cloudResultMessage = String(
                    format: String(localized: "cloud.composer_sent_partial"),
                    result.sent, result.withoutCloud.joined(separator: ", ")
                )
            } else {
                cloudResultMessage = CloudService.shared.lastErrorMessage
                    ?? String(localized: "cloud.composer_sent_none")
            }
        }
    }

    private var selectedLessons: [Lesson] {
        store.lessons.filter { selectedLessonIDs.contains($0.id) }
    }

    private var selectedPoolItems: [ContentItem] {
        store.contentPool.filter { selectedContentItemIDs.contains($0.id) }
    }

    private var bundleTypeCounts: [(ContentType, Int)] {
        ContentType.allCases.compactMap { type in
            let count = selectedPoolItems.filter { $0.type == type }.count
            return count > 0 ? (type, count) : nil
        }
    }

    private var canAssign: Bool {
        !selectedStudentIDs.isEmpty
            && (!selectedLessonIDs.isEmpty || !selectedContentItemIDs.isEmpty)
    }

    private var packageSummary: String {
        var parts: [String] = []
        if !selectedLessons.isEmpty {
            parts.append("\(selectedLessons.count) Lektion\(selectedLessons.count == 1 ? "" : "en")")
        }
        if !selectedPoolItems.isEmpty {
            parts.append("\(selectedPoolItems.count) Einzelinhalt\(selectedPoolItems.count == 1 ? "" : "e")")
        }
        if bundleTypeCounts.count > 1 {
            let types = bundleTypeCounts.map { "\($0.1)× \($0.0.label)" }.joined(separator: ", ")
            parts.append("(\(types))")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            List {
                if isSupplemental {
                    supplementalBanner
                }
                stepHeader(step: 1, title: "Schüler", icon: "figure.golf")
                studentsSection

                // Hans' Regel: Erst wenn ein Schüler gewählt ist,
                // öffnen sich die Lerninhalte.
                if selectedStudentIDs.isEmpty {
                    Section {
                        Label("Wähle zuerst den Schüler — dann öffnen sich die Lerninhalte.", systemImage: "arrow.up")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    stepHeader(step: 2, title: "Inhalte aus der Bibliothek", icon: "books.vertical.fill")
                    bundlePreviewSection
                    poolItemsSection
                    stepHeader(step: 3, title: "Nachricht & Datum", icon: "text.bubble")
                    noteSection
                    dateSection
                    shareHintSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isSupplemental ? "Nachreichung" : "Composer")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !preselectedStudentIDs.isEmpty {
                    selectedStudentIDs = preselectedStudentIDs
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        assignOnly()
                    } label: {
                        Label("Zuweisen", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(!canAssign)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if canAssign {
                    VStack(spacing: 10) {
                        Button(action: assignOnly) {
                            Label("Zuweisen", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ALColor.green)

                        // Der zweite Weg: über die Drehscheibe — erreicht
                        // verbundene Schüler auch zuhause. Immer sichtbar;
                        // wenn er nicht kann, sagt er warum.
                        Button {
                            sendViaCloud()
                        } label: {
                            if isSendingCloud {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Label("cloud.composer_send", systemImage: "icloud.and.arrow.up.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "1565C0"))
                        .disabled(isSendingCloud || !cloudSendPossible)

                        if !cloudSendPossible {
                            Text(cloudBlockedReason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Der persönliche Weg am Platz — öffnet das
                        // iOS-Teilen-Fenster mit dem Grünbuch-Paket.
                        Button(action: assignAndShare) {
                            Label("Per AirDrop übergeben", systemImage: "airdrop")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(ALColor.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .alert("cloud.composer_result_title", isPresented: Binding(
                get: { cloudResultMessage != nil },
                set: { if !$0 { cloudResultMessage = nil; dismiss() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cloudResultMessage ?? "")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Sections

    private var supplementalBanner: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ergänze einzelne Lektionen oder Medien — kein vollständiges Paket nötig.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Nachreichungen in der Nachbesprechung — persönlich per AirDrop, wenn ihr zusammen seid.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } icon: {
                Image(systemName: "tray.and.arrow.down.fill")
                    .foregroundStyle(ALColor.gold)
            }
        }
    }

    private func stepHeader(step: Int, title: LocalizedStringKey, icon: String) -> some View {
        Section {
            EmptyView()
        } header: {
            HStack(spacing: 8) {
                Text("\(step)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(ALColor.green, in: Circle())
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(ALColor.green)
            }
            .textCase(nil)
        }
    }

    @ViewBuilder
    private var bundlePreviewSection: some View {
        if canAssign {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title2)
                        .foregroundStyle(ALColor.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lernpaket")
                            .font(.subheadline.bold())
                        Text(packageSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                if !bundleTypeCounts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(bundleTypeCounts, id: \.0) { type, count in
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                    Text("\(count)× \(type.label)")
                                }
                                .font(.caption2.bold())
                                .foregroundStyle(Color(hex: type.colorHex))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: type.colorHex).opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                if selectedPoolItems.isEmpty == false && selectedLessons.isEmpty == false {
                    Text("Lektionen und Einzelmedien werden als separate .afterlesson-Dateien geteilt.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !selectedPoolItems.isEmpty && selectedLessons.isEmpty {
                    Text("Einzelmedien werden zu einem Lernpaket gebündelt.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Paket-Vorschau")
            }
        }
    }

    private var studentsSection: some View {
        Section {
            if store.students.isEmpty {
                Text("Zuerst Schüler im Schüler-Tab anlegen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isSupplemental && preselectedStudentIDs.count == 1,
                      let student = store.students.first(where: { preselectedStudentIDs.contains($0.id) }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: student.avatarColor))
                            .frame(width: 36, height: 36)
                        Text(String(student.name.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    Text(student.name)
                        .font(.subheadline.bold())
                }
            } else {
                ForEach(store.students) { student in
                    let selected = selectedStudentIDs.contains(student.id)
                    Button {
                        if selected {
                            selectedStudentIDs.remove(student.id)
                        } else {
                            selectedStudentIDs.insert(student.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? ALColor.green : .secondary)
                                .font(.title3)
                            ZStack {
                                Circle()
                                    .fill(Color(hex: student.avatarColor))
                                    .frame(width: 36, height: 36)
                                Text(String(student.name.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }
                            Text(student.name)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } footer: {
            if !store.students.isEmpty && !isSupplemental {
                Text("Wähle einen oder mehrere Schüler für die Zuweisung.")
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Datum", selection: $assignmentDate, displayedComponents: .date)
        }
    }

    private var noteSection: some View {
        Section {
            TextField(
                "z.B. Hans, du hast das heute gut gemacht — beim nächsten Mal…",
                text: $note,
                axis: .vertical
            )
            .lineLimit(3...8)
        } footer: {
            Text("Optional — wird als Textdatei mit dem Paket geteilt.")
                .font(.caption2)
        }
    }

    private var shareHintSection: some View {
        Section {
            Label {
                Text(isSupplemental
                     ? "Nachreichungen in der Nachbesprechung — persönlich per AirDrop, wenn ihr zusammen seid."
                     : "Wähle im nächsten Schritt AirDrop und deinen Schüler. Die Nachbesprechung ist der professionelle Abschluss eurer Lektion — ca. 5 Minuten am Platz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "airdrop")
                    .foregroundStyle(ALColor.green)
            }
        } header: {
            Text("Nachbesprechung")
        }
    }


    @ViewBuilder
    /// Die Bibliothek im Composer: gegliedert nach Lektionsgruppen (Hans'
    /// Bündel), alle Inhalte direkt sichtbar, "Alle" wählt gruppenweise.
    private var poolItemsSection: some View {
        Group {
            if store.contentPool.isEmpty {
                Section {
                    Text("Importiere wiederverwendbaren Lernstoff im Bibliothek-Tab (Film, Bild, Text, PDF, Audio).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(store.contentClasses) { group in
                    let items = store.contentPool.filter { $0.classID == group.id }
                    if !items.isEmpty {
                        poolGroupSection(title: group.title, icon: group.icon, colorHex: group.colorHex, items: items)
                    }
                }
                let unsorted = store.contentPool.filter { item in
                    item.classID == nil || !store.contentClasses.contains(where: { $0.id == item.classID })
                }
                if !unsorted.isEmpty {
                    poolGroupSection(title: String(localized: "Eingang"), icon: "tray.fill", colorHex: "8D6E63", items: unsorted)
                }
            }
        }
    }

    @ViewBuilder
    private func poolGroupSection(title: String, icon: String, colorHex: String, items: [ContentItem]) -> some View {
        Section {
            ForEach(items) { item in
                poolItemRow(item)
            }
        } header: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(Color(hex: colorHex))
                    .font(.subheadline.bold())
                Spacer()
                let ids = items.map(\.id)
                let allSelected = ids.allSatisfy { selectedContentItemIDs.contains($0) }
                Button(allSelected ? String(localized: "Abwählen") : String(localized: "Alle wählen")) {
                    if allSelected {
                        ids.forEach { selectedContentItemIDs.remove($0) }
                    } else {
                        ids.forEach { selectedContentItemIDs.insert($0) }
                    }
                }
                .font(.caption.bold())
                .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private func poolItemRow(_ item: ContentItem) -> some View {
        let selected = selectedContentItemIDs.contains(item.id)
        Button {
            if selected {
                selectedContentItemIDs.remove(item.id)
            } else {
                selectedContentItemIDs.insert(item.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? ALColor.green : .secondary)
                Image(systemName: item.type.icon)
                    .foregroundStyle(Color(hex: item.type.colorHex))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.type.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Nur zuweisen — kein Teilen-Fenster. Das Paket steht danach im
    /// Verlauf des Schülers; übertragen wird per Cloud oder AirDrop.
    private func assignOnly() {
        let delivery = store.prepareComposerDelivery(
            to: selectedStudentIDs,
            lessonIDs: selectedLessonIDs,
            contentItemIDs: selectedContentItemIDs,
            note: note,
            date: assignmentDate
        )
        let names = delivery.targets.map(\.name).joined(separator: ", ")
        cloudResultMessage = String(format: String(localized: "composer.assigned"), names)
    }

    private func assignAndShare() {
        let items = store.deliverComposerPackage(
            to: selectedStudentIDs,
            lessonIDs: selectedLessonIDs,
            contentItemIDs: selectedContentItemIDs,
            note: note,
            date: assignmentDate
        )
        dismiss()
        if !items.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onShare(items)
            }
        }
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    @EnvironmentObject var store: AppStore
    let session: TrainingSession
    var onTap: () -> Void

    var studentName: String {
        guard let id = session.studentID else { return "" }
        return store.students.first(where: { $0.id == id })?.name ?? ""
    }

    var subtitle: String {
        if session.source == .received {
            if session.teacherName.isEmpty {
                return String(localized: "Trainingsprotokoll")
            }
            return String(format: String(localized: "von %@"), session.teacherName)
        }
        return studentName.isEmpty ? String(localized: "Kein Schüler") : studentName
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(session.source == .received
                              ? ALColor.gold.opacity(0.12)
                              : ALColor.green.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: session.source == .received ? "arrow.down.circle.fill" : "figure.golf")
                        .font(.system(size: 18))
                        .foregroundStyle(session.source == .received ? ALColor.gold : ALColor.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title.isEmpty ? "Trainingsstunde" : session.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !session.trained.isEmpty {
                            Text("·")
                                .foregroundStyle(Color(.tertiaryLabel))
                            Text(session.trained)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Text(session.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New From Pro Banner

struct NewFromProBanner: View {
    let count: Int
    let teacherName: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ALColor.gold.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ALColor.gold)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(teacherName.isEmpty
                         ? String(localized: "Deine Nachbesprechung von deinem Pro")
                         : String(format: String(localized: "Deine Nachbesprechung von %@"), teacherName))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                    Text(count == 1
                         ? String(localized: "1 Trainingsprotokoll wartet auf dich")
                         : String(format: String(localized: "%d Trainingsprotokolle warten auf dich"), count))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "888888"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ALColor.gold)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [ALColor.gold.opacity(0.14), ALColor.green.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(ALColor.gold.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Student Empty Placeholder

struct StudentEmptyPlaceholder: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {

            // Illustration
            ZStack {
                // Hintergrund-Kreis gross
                Circle()
                    .fill(ALColor.green.opacity(0.06))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(ALColor.green.opacity(0.09))
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse)

                // Goldener Ball
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "D4A840"), Color(hex: "8B6210")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(hex: "C9A84C").opacity(0.40), radius: 14, x: 0, y: 6)

                    // Dimple-Muster
                    ForEach(0..<6, id: \.self) { i in
                        let angle = Double(i) * 60.0
                        let r: CGFloat = 22
                        Circle()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: 8, height: 8)
                            .offset(
                                x: r * cos(angle * .pi / 180),
                                y: r * sin(angle * .pi / 180)
                            )
                    }
                    Circle()
                        .fill(Color.black.opacity(0.10))
                        .frame(width: 8, height: 8)
                }

                // Golfer oben rechts
                Image(systemName: "figure.golf")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(ALColor.green.opacity(0.35))
                    .offset(x: 54, y: -42)

                // Sterne / Glanz links
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(ALColor.gold.opacity(0.55))
                    .offset(x: -58, y: -36)
                    .scaleEffect(pulse ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4), value: pulse)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Text
            VStack(spacing: 10) {
                Text("Bereit für dein Training")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .multilineTextAlignment(.center)

                Text("Dein Pro überreicht dir am Ende der Lektion deine Nachbesprechung — ca. 5 Minuten, persönlich auf dem Platz. Tippe die AirDrop-Datei an, dann öffnet sich Grünbuch.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "888888"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Lektionen und Protokolle aus der Nachbesprechung erscheinen hier unter „Zugewiesen“.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "AAAAAA"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "F0EDE6"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(ALColor.green.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .onAppear { pulse = true }
    }
}
