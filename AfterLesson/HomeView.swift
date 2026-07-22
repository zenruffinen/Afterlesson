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
    @State private var showMessageCompose = false
    @State private var selectedProMessage: ProMessage? = nil
    // Aufräumen per Checkbox (Hans, 21.07.): Auswählen → ankreuzen → löschen
    @State private var inboxSelectionMode = false
    @State private var inboxSelectedLessonIDs: Set<UUID> = []
    @State private var inboxSelectedSessionIDs: Set<UUID> = []
    @State private var showMessageArchive = false
    @State private var showProInbox = false   // Nachrichten-Eingang hinter der Glocke
    @State private var heroFlight = 0     // Ballflug in der Hero-Grafik auslösen

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
        .sheet(isPresented: $showMessageCompose) {
            MessageComposeSheet()
        }
        .sheet(item: $selectedProMessage) { message in
            StudentMessageSheet(message: message)
        }
        .sheet(isPresented: $showMessageArchive) {
            MessageArchiveSheet()
        }
        .sheet(isPresented: $showProInbox) {
            NachrichtenEingangSheet()
        }
        .onChange(of: showQuickCapture) { _, isShowing in
            if !isShowing { quickCaptureStudentID = nil }
        }
        // Schüler: beim Betreten sofort abholen — und danach automatisch
        // jede Minute nachschauen, solange der Start sichtbar ist.
        .task {
            // Beide Rollen holen bei der Drehscheibe ab — der Schüler seine
            // Pakete und Mitteilungen, der Pro die Antworten seiner Schüler.
            if isTeacher {
                _ = await store.importCloudResponses()
                await store.refreshProMessages()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    _ = await store.importCloudResponses()
                    await store.refreshProMessages()
                }
            } else {
                _ = await store.importCloudPackages()
                _ = await store.importCloudMessages()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    _ = await store.importCloudPackages()
                    _ = await store.importCloudMessages()
                }
            }
        }
        // … und auch immer, wenn die App in den Vordergrund kommt.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                if isTeacher {
                    _ = await store.importCloudResponses()
                    await store.refreshProMessages()
                } else {
                    _ = await store.importCloudPackages()
                    _ = await store.importCloudMessages()
                }
            }
        }
    }

    // MARK: Header Bar

    /// Wann der Pro zuletzt auf die Glocke getippt hat — alles Neuere zählt.
    @AppStorage("al_bellseen") private var bellSeenTime: Double = 0

    /// Die Glocke: beim Pro die noch ungesehenen Schüler-Nachrichten
    /// (Antippen = gesehen), beim Schüler der ungelesene Eingang.
    private var bellCount: Int {
        if isTeacher {
            let seit = Date(timeIntervalSince1970: bellSeenTime)
            return store.students
                .flatMap(\.feedbackHistory)
                .filter { $0.date > seit }
                .count
        }
        return store.receivedLessons.filter { $0.openedDate == nil }.count
            + store.receivedSessions.filter { $0.openedDate == nil }.count
            + store.proMessages.filter { $0.readDate == nil && $0.archivedDate == nil }.count
    }

    var headerBar: some View {
        GrünbuchHomeHeader(roleLabel: roleLabel, bellCount: bellCount) {
            // Pro: Glocke öffnet den Nachrichten-Eingang (gesehen =
            // Zähler leert sich). Schüler: bleibt beim Start-Eingang.
            if isTeacher {
                bellSeenTime = Date().timeIntervalSince1970
            }
            showProInbox = true
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: Teacher Content
    var teacherContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            GrünbuchFairwayGraphic(flightTrigger: heroFlight)
                .padding(.horizontal, 20)

            Spacer(minLength: 22)

            // Die Drehscheibe: der Composer als Karte (Abendgarderobe 22.07.),
            // das Wappen-Medaillon trägt weiter den rotierenden Punktring
            GrünbuchComposerCard {
                composerPreselectedStudents = []
                composerIsSupplemental = false
                showComposer = true
            }
            .padding(.horizontal, 20)
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
                        heroFlight += 1        // der Ball fliegt zur Fahne
                        quickCaptureStudentID = nil
                        showQuickCapture = true
                    }
                ) {
                    GrünbuchPlayerIllustration()
                }
            }
            .padding(.horizontal, 20)

            // Der Umschlag: kurze Mitteilung an einen oder alle Schüler
            Button {
                showMessageCompose = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ALColor.gold)
                        .alIconTile(tint: ALColor.gold, size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Mitteilung")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Kurze Nachricht an deine Schüler")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .alGlass(tint: ALColor.gold.opacity(0.22), interactive: true,
                         in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(GrünbuchTastenStyle(radius: 16))
            .padding(.horizontal, 20)
            .padding(.top, 12)

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

            if store.receivedSessions.isEmpty && store.receivedLessons.isEmpty && store.proMessages.isEmpty {
                StudentEmptyPlaceholder()
                    .padding(.horizontal, 20)
                Spacer(minLength: 16)
            } else {
                // Drei klare Abschnitte (Hans, 20.07.):
                // Eingang (neu) → Nachrichten vom Pro → Zugewiesen (gesehen)
                let newLessons = store.receivedLessons.filter { $0.openedDate == nil }
                let seenLessons = store.receivedLessons.filter { $0.openedDate != nil }
                let newSessions = store.receivedSessions.filter { $0.openedDate == nil }
                let seenSessions = store.receivedSessions.filter { $0.openedDate != nil }
                let sessionNotes = store.receivedSessions.filter { !$0.homework.isEmpty || !$0.corrections.isEmpty }.prefix(2)
                let cloudMessages = store.proMessages.filter { $0.archivedDate == nil }.prefix(5)
                let archivedCount = store.proMessages.filter { $0.archivedDate != nil }.count

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Aufräum-Schalter: Auswählen → ankreuzen → unten löschen
                        HStack {
                            Spacer()
                            Button(inboxSelectionMode ? "Fertig" : "Auswählen") {
                                inboxSelectionMode.toggle()
                                inboxSelectedLessonIDs.removeAll()
                                inboxSelectedSessionIDs.removeAll()
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 20)

                        if !newLessons.isEmpty || !newSessions.isEmpty {
                            studentSectionHeader("Eingang", icon: "tray.and.arrow.down.fill")
                                .padding(.top, 2)
                            ForEach(newLessons) { lesson in
                                inboxRow(selected: inboxSelectedLessonIDs.contains(lesson.id),
                                         toggle: { toggleSelection(lessonID: lesson.id) }) {
                                    studentLessonRow(lesson)
                                }
                                .padding(.horizontal, 20)
                            }
                            ForEach(newSessions) { session in
                                inboxRow(selected: inboxSelectedSessionIDs.contains(session.id),
                                         toggle: { toggleSelection(sessionID: session.id) }) {
                                    studentSessionRow(session)
                                }
                                .padding(.horizontal, 20)
                            }
                            Text("home.inbox_hint")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.horizontal, 20)
                        }

                        if !cloudMessages.isEmpty || !sessionNotes.isEmpty || archivedCount > 0 {
                            // Mit Namen ist es persönlicher: "Nachrichten von Hans"
                            studentSectionHeaderText(
                                store.proName.isEmpty
                                    ? String(localized: "Nachrichten vom Pro")
                                    : String(format: String(localized: "Nachrichten von %@"), store.proName),
                                icon: "megaphone.fill"
                            )
                            .padding(.top, 6)
                            ForEach(Array(cloudMessages)) { message in
                                cloudMessageRow(message).padding(.horizontal, 20)
                            }
                            ForEach(Array(sessionNotes)) { session in
                                proMessageRow(session).padding(.horizontal, 20)
                            }
                            if archivedCount > 0 {
                                Button {
                                    showMessageArchive = true
                                } label: {
                                    Label("Archiv (\(archivedCount))", systemImage: "archivebox")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                            }
                        }

                        if !seenLessons.isEmpty || !seenSessions.isEmpty {
                            studentSectionHeader("Zugewiesen", icon: "books.vertical.fill")
                                .padding(.top, 6)
                            // Die wachsende Sammlung als Briefmarken-Raster —
                            // wie in der Bibliothek (Hans, 21.07.)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                                ForEach(seenLessons) { lesson in
                                    studentLessonTile(lesson)
                                }
                                ForEach(seenSessions) { session in
                                    studentSessionTile(session)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                // Herunterziehen = sofort bei der Drehscheibe nachschauen
                .refreshable {
                    _ = await store.importCloudPackages()
                    _ = await store.importCloudMessages()
                }

                // Löschleiste des Auswahl-Modus
                if inboxSelectionMode {
                    let count = inboxSelectedLessonIDs.count + inboxSelectedSessionIDs.count
                    Button {
                        deleteSelectedInboxItems()
                    } label: {
                        Label(count == 0 ? String(localized: "Zum Löschen ankreuzen")
                                         : String(format: String(localized: "%d löschen"), count),
                              systemImage: "trash.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(count == 0)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: Kacheln für "Zugewiesen" (Briefmarken-Raster)

    @ViewBuilder
    private func studentLessonTile(_ lesson: Lesson) -> some View {
        let selected = inboxSelectedLessonIDs.contains(lesson.id)
        Button {
            if inboxSelectionMode {
                toggleSelection(lessonID: lesson.id)
            } else {
                selectedReceivedLesson = lesson
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: lesson.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ALColor.gold)
                        .alIconTile(tint: ALColor.gold, size: 30)
                    Spacer()
                    if inboxSelectionMode {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(selected ? Color(hex: "66BB6A") : .white.opacity(0.45))
                    }
                }
                Text(lesson.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(selected ? 0.12 : 0.06),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func studentSessionTile(_ session: TrainingSession) -> some View {
        let selected = inboxSelectedSessionIDs.contains(session.id)
        Button {
            if inboxSelectionMode {
                toggleSelection(sessionID: session.id)
            } else {
                selectedSession = session
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "64B5F6"))
                        .alIconTile(tint: Color(hex: "1565C0"), size: 30)
                    Spacer()
                    if inboxSelectionMode {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(selected ? Color(hex: "66BB6A") : .white.opacity(0.45))
                    }
                }
                Text(session.title.isEmpty
                     ? session.date.formatted(date: .abbreviated, time: .omitted)
                     : session.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(selected ? 0.12 : 0.06),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Aufräumen per Checkbox

    /// Im Auswahl-Modus bekommt jede Zeile eine Checkbox davor —
    /// Antippen kreuzt an statt zu öffnen.
    @ViewBuilder
    private func inboxRow<Content: View>(selected: Bool,
                                         toggle: @escaping () -> Void,
                                         @ViewBuilder content: () -> Content) -> some View {
        if inboxSelectionMode {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? Color(hex: "66BB6A") : .white.opacity(0.45))
                    content()
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    private func toggleSelection(lessonID: UUID) {
        if inboxSelectedLessonIDs.contains(lessonID) {
            inboxSelectedLessonIDs.remove(lessonID)
        } else {
            inboxSelectedLessonIDs.insert(lessonID)
        }
    }

    private func toggleSelection(sessionID: UUID) {
        if inboxSelectedSessionIDs.contains(sessionID) {
            inboxSelectedSessionIDs.remove(sessionID)
        } else {
            inboxSelectedSessionIDs.insert(sessionID)
        }
    }

    private func deleteSelectedInboxItems() {
        for lesson in store.receivedLessons where inboxSelectedLessonIDs.contains(lesson.id) {
            store.deleteLesson(lesson)
        }
        for session in store.receivedSessions where inboxSelectedSessionIDs.contains(session.id) {
            store.deleteSession(session)
        }
        inboxSelectedLessonIDs.removeAll()
        inboxSelectedSessionIDs.removeAll()
        inboxSelectionMode = false
    }

    private func studentSectionHeader(_ title: LocalizedStringKey, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 20)
    }

    /// Wie studentSectionHeader, aber für zur Laufzeit gebaute Titel
    /// (z.B. "Nachrichten von Hans").
    private func studentSectionHeaderText(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 20)
    }

    /// Eine Cloud-Mitteilung des Pros — Antippen öffnet das Lese-Blatt
    /// (und markiert die Mitteilung als gelesen).
    @ViewBuilder
    private func cloudMessageRow(_ message: ProMessage) -> some View {
        Button { selectedProMessage = message } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: message.readDate == nil ? "envelope.badge.fill" : "envelope.open.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ALColor.gold)
                    .alIconTile(tint: ALColor.gold, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if message.readDate == nil {
                            Circle()
                                .fill(Color(hex: "66BB6A"))
                                .frame(width: 8, height: 8)
                        }
                        Text(message.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Text(message.body)
                        .font(.system(size: 13, weight: message.readDate == nil ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 12)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Hausaufgaben/Korrekturen aus einer empfangenen Stunde als
    /// kompakte Nachricht — Antippen öffnet das Stundenprotokoll.
    @ViewBuilder
    private func proMessageRow(_ session: TrainingSession) -> some View {
        Button { selectedSession = session } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ALColor.gold)
                    .alIconTile(tint: ALColor.gold, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                        if !session.teacherName.isEmpty {
                            Text("· \(session.teacherName)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    Text(session.homework.isEmpty ? session.corrections : session.homework)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 12)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
    // Composer-Redesign (Hans, 21.07.): Nach der Schülerwahl verschwindet
    // die Liste (Chips oben), die Bibliothek wird zum Akkordeon — immer
    // nur eine Gruppe offen, Zähler-Plakette an den zugeklappten.
    @State private var studentsCollapsed = false
    @State private var openGroupKey: String? = nil

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

    private var canAssign: Bool {
        !selectedStudentIDs.isEmpty
            && (!selectedLessonIDs.isEmpty || !selectedContentItemIDs.isEmpty)
    }

    /// Die Bilanz auf dem grünen Knopf: "5 Inhalte an Tomas senden" —
    /// man weiß immer, was gleich passiert.
    private var sendButtonTitle: String {
        let count = selectedLessonIDs.count + selectedContentItemIDs.count
        guard count > 0 else { return String(localized: "Inhalte wählen") }
        let chosen = store.students.filter { selectedStudentIDs.contains($0.id) }
        let target = chosen.count == 1
            ? (chosen.first?.name ?? "")
            : String(format: String(localized: "%d Schüler"), chosen.count)
        let content = count == 1
            ? String(localized: "1 Inhalt")
            : String(format: String(localized: "%d Inhalte"), count)
        return String(format: String(localized: "%@ an %@ senden"), content, target)
    }

    var body: some View {
        NavigationStack {
            List {
                if isSupplemental {
                    supplementalBanner
                }

                if studentsCollapsed && !selectedStudentIDs.isEmpty {
                    // Schüler als Chips oben — antippen entfernt, Plus holt die Liste zurück
                    studentChipsSection
                } else {
                    stepHeader(step: 1, title: "Schüler", icon: "figure.golf")
                    studentsSection
                    if !selectedStudentIDs.isEmpty {
                        Section {
                            Button {
                                withAnimation { studentsCollapsed = true }
                            } label: {
                                Label("Weiter zu den Inhalten", systemImage: "arrow.down.circle.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(ALColor.green)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }

                // Hans' Regel: Erst wenn ein Schüler gewählt ist,
                // öffnen sich die Lerninhalte.
                if selectedStudentIDs.isEmpty {
                    Section {
                        Label("Wähle zuerst den Schüler — dann öffnen sich die Lerninhalte.", systemImage: "arrow.up")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if studentsCollapsed {
                    stepHeader(step: 2, title: "Inhalte aus der Bibliothek", icon: "books.vertical.fill")
                    accordionSections
                    stepHeader(step: 3, title: "Nachricht & Datum", icon: "text.bubble")
                    noteSection
                    dateSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isSupplemental ? "Nachreichung" : "Composer")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !preselectedStudentIDs.isEmpty {
                    selectedStudentIDs = preselectedStudentIDs
                    studentsCollapsed = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if studentsCollapsed && !selectedStudentIDs.isEmpty {
                    VStack(spacing: 10) {
                        // Senden IST Zuweisen (Hans, 20.07.) — und der Knopf
                        // sagt in Klartext, was gleich passiert (21.07.).
                        Button {
                            sendViaCloud()
                        } label: {
                            if isSendingCloud {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Label(sendButtonTitle, systemImage: "icloud.and.arrow.up.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ALColor.green)
                        .disabled(isSendingCloud || !canAssign || !cloudSendPossible)

                        if !cloudSendPossible {
                            Text(cloudBlockedReason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Hans' Beschluss (20.07.): Die Cloud ist der einzige
                        // Versandweg — AirDrop-Knopf entfernt. Der Datei-Weg
                        // (assignAndShare/exportLesson) bleibt im Code als
                        // Reserve, ist aber nicht mehr in der Oberfläche.
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

    /// Die gewählten Schüler als Chips — antippen entfernt,
    /// das Plus holt die Auswahlliste zurück (Hans, 21.07.).
    private var studentChipsSection: some View {
        Section {
            FlowChips {
                ForEach(store.students.filter { selectedStudentIDs.contains($0.id) }) { student in
                    Button {
                        selectedStudentIDs.remove(student.id)
                        if selectedStudentIDs.isEmpty {
                            withAnimation { studentsCollapsed = false }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(student.name)
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(ALColor.green))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    withAnimation { studentsCollapsed = false }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(.secondarySystemFill)))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        } header: {
            Label("An", systemImage: "figure.golf")
                .font(.subheadline.bold())
                .foregroundStyle(ALColor.green)
                .textCase(nil)
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

    // MARK: Akkordeon — die Bibliothek als aufklappbare Gruppen (Hans, 21.07.)
    // "Alles" → Obergruppen (mit Untergruppen darin) → "Eingang".
    // Immer nur eine Gruppe offen; zugeklappte zeigen eine grüne
    // Zähler-Plakette, damit nichts verloren geht.

    private struct ComposerGroup: Identifiable {
        let key: String
        let title: String
        let icon: String
        let colorHex: String
        let ownItems: [ContentItem]
        let subgroups: [(cls: ContentClass, items: [ContentItem])]
        var id: String { key }
        var allItems: [ContentItem] { ownItems + subgroups.flatMap { $0.items } }
    }

    /// Nur einsortierte Inhalte sind sendbar — der Eingang ist Sammelkiste,
    /// nicht Versandlager (Hans, 21.07.): erst einsortieren, dann senden.
    private var composerUnsortedCount: Int {
        store.contentPool.filter { item in
            item.classID == nil || !store.contentClasses.contains(where: { $0.id == item.classID })
        }.count
    }

    private var composerGroups: [ComposerGroup] {
        let classIDs = Set(store.contentClasses.map(\.id))
        let pool = store.contentPool.filter { $0.classID.map(classIDs.contains) ?? false }
        var groups: [ComposerGroup] = []
        guard !pool.isEmpty else { return groups }

        // Kein "Alle Inhalte" mehr (Hans, 21.07.): Im Composer stehen
        // ausschließlich die eingelagerten Gruppen — das Lager-Prinzip.
        for cls in store.topLevelClasses.sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending }) {
            let own = pool.filter { $0.classID == cls.id }
            let subs = store.subgroups(of: cls).compactMap { sub -> (cls: ContentClass, items: [ContentItem])? in
                let items = pool.filter { $0.classID == sub.id }
                return items.isEmpty ? nil : (sub, items)
            }
            if !own.isEmpty || !subs.isEmpty {
                groups.append(ComposerGroup(
                    key: cls.id.uuidString, title: cls.title,
                    icon: cls.icon, colorHex: cls.colorHex,
                    ownItems: own, subgroups: subs
                ))
            }
        }
        return groups
    }

    @ViewBuilder
    private var accordionSections: some View {
        if store.contentPool.isEmpty {
            Section {
                Text("Importiere wiederverwendbaren Lernstoff im Bibliothek-Tab (Film, Bild, Text, PDF, Audio).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(composerGroups) { group in
                accordionSection(group)
            }
            if composerUnsortedCount > 0 {
                Section {
                    Label(
                        String(format: String(localized: "%d Inhalte liegen noch im Eingang — sortiere sie in der Bibliothek in Gruppen, dann kannst du sie senden."), composerUnsortedCount),
                        systemImage: "tray.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func accordionSection(_ group: ComposerGroup) -> some View {
        let isOpen = openGroupKey == group.key
        let selectedCount = group.allItems.filter { selectedContentItemIDs.contains($0.id) }.count
        Section {
            // Kopfzeile: Icon, Name, Plakette, Pfeil
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    openGroupKey = isOpen ? nil : group.key
                }
            } label: {
                HStack(spacing: 12) {
                    ClassIcon(icon: group.icon, color: Color(hex: group.colorHex),
                              side: 28, symbolSize: 15)
                        .frame(width: 28)
                    Text(group.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedCount > 0 {
                        Text("\(selectedCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(ALColor.green, in: Capsule())
                    }
                    Text("\(group.allItems.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if isOpen {
                selectAllRow(items: group.allItems)
                ForEach(group.ownItems) { poolItemRow($0) }
                ForEach(group.subgroups, id: \.cls.id) { sub in
                    subgroupHeaderRow(sub.cls, items: sub.items)
                    ForEach(sub.items) { poolItemRow($0) }
                }
            }
        }
    }

    /// "Alle wählen"-Zeile für eine geöffnete Gruppe.
    @ViewBuilder
    private func selectAllRow(items: [ContentItem]) -> some View {
        let ids = items.map(\.id)
        let allSelected = !ids.isEmpty && ids.allSatisfy { selectedContentItemIDs.contains($0) }
        Button {
            if allSelected {
                ids.forEach { selectedContentItemIDs.remove($0) }
            } else {
                ids.forEach { selectedContentItemIDs.insert($0) }
            }
        } label: {
            Label(allSelected ? String(localized: "Abwählen") : String(localized: "Alle wählen"),
                  systemImage: allSelected ? "checkmark.circle.badge.xmark" : "checkmark.circle")
                .font(.caption.bold())
                .foregroundStyle(ALColor.green)
        }
        .buttonStyle(.plain)
    }

    /// Untergruppen-Zwischenzeile innerhalb einer geöffneten Obergruppe.
    @ViewBuilder
    private func subgroupHeaderRow(_ cls: ContentClass, items: [ContentItem]) -> some View {
        let ids = items.map(\.id)
        let allSelected = !ids.isEmpty && ids.allSatisfy { selectedContentItemIDs.contains($0) }
        HStack {
            HStack(spacing: 5) {
                ClassIcon(icon: cls.icon, color: Color(hex: cls.colorHex),
                          side: 18, symbolSize: 11)
                Text(cls.title)
            }
            .font(.caption.bold())
            .foregroundStyle(Color(hex: cls.colorHex))
            Spacer()
            Button(allSelected ? String(localized: "Abwählen") : String(localized: "Alle wählen")) {
                if allSelected {
                    ids.forEach { selectedContentItemIDs.remove($0) }
                } else {
                    ids.forEach { selectedContentItemIDs.insert($0) }
                }
            }
            .font(.caption.bold())
            .buttonStyle(.plain)
            .foregroundStyle(ALColor.green)
        }
        .padding(.top, 2)
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
