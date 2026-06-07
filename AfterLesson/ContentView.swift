import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

// MARK: - App Entry

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab: Tab = .home

    enum Tab { case home, lessons, students, notes, settings }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:     HomeView(selectedTab: $selectedTab)
                case .lessons:  DatenpoolView()
                case .students: StudentsView()
                case .notes:    NotesView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }

            AfterLessonTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar

struct AfterLessonTabBar: View {
    @Binding var selected: ContentView.Tab
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home,     icon: "house.fill",           label: "Start")
            tabItem(.lessons,  icon: "square.grid.2x2.fill", label: "Datenpool")
            tabItem(.students, icon: "figure.golf",          label: "Schüler")
            tabItem(.notes,    icon: "pencil.tip",           label: "Notizen")
            tabItem(.settings, icon: "gearshape.fill",       label: "Einstellungen")
        }
        .padding(.bottom, 28)
        .background(Color(hex: "0D160D"))
        .overlay(alignment: .top) {
            Rectangle().fill(Color(hex: "2A3A2A")).frame(height: 0.5)
        }
    }

    @ViewBuilder
    func tabItem(_ tab: ContentView.Tab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = tab
            }
        } label: {
            let isSelected = selected == tab
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? ALColor.gold : Color.white.opacity(0.45))
                    .scaleEffect(isSelected ? 1.10 : 1.0)
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ALColor.gold : Color.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Branding Colors

enum ALColor {
    static let green    = Color(hex: "2D6A30")                          // Golf-Grün (warm, edel)
    static let gold     = Color(red: 0.72, green: 0.57, blue: 0.22)   // Golf-Gold
    static let dark     = Color(red: 0.10, green: 0.12, blue: 0.10)   // Fast Schwarz
    static let fairway  = Color(red: 0.17, green: 0.50, blue: 0.22)   // Fairway-Grün
    static let sand     = Color(red: 0.93, green: 0.87, blue: 0.70)   // Bunker-Sand
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedTab: ContentView.Tab
    @State private var showQuickCapture = false
    @State private var showTeacherDashboard = false
    @State private var selectedSession: TrainingSession? = nil

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle()
                .fill(Color(hex: "E2DDD5"))
                .frame(height: 1)
            if isTeacher {
                teacherContent
            } else {
                studentContent
            }
        }
        .background(Color(hex: "F0EDE6"))
        .sheet(isPresented: $showQuickCapture) { AfterLessonFlowSheet() }
        .sheet(isPresented: $showTeacherDashboard) { TeacherDashboardView() }
        .sheet(item: $selectedSession) { session in SessionDetailSheet(session: session) }
    }

    // MARK: Header Bar
    var headerBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "D4A840"), Color(hex: "8B6210")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 46, height: 46)
                    .shadow(color: Color(hex: "C9A84C").opacity(0.35), radius: 5, x: 0, y: 3)
                Image(systemName: "figure.golf")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(store.teacherName)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .lineLimit(1)
                if isTeacher && !store.teacherTitle.isEmpty {
                    Text(store.teacherTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "888888"))
                        .tracking(0.3)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isTeacher {
                Button { showTeacherDashboard = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("Senden")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ALColor.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Teacher Content (kein Scroll)
    var teacherContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            AfterLessonOrb { showQuickCapture = true }

            Spacer(minLength: 12)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12),
                          GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                navTile(icon: "figure.golf",
                        label: "Schüler",
                        value: "\(store.students.count)",
                        color: ALColor.green) { selectedTab = .students }
                navTile(icon: "rectangle.stack.fill",
                        label: "Vorlagen",
                        value: "\(store.lessons.count)",
                        color: ALColor.gold) { selectedTab = .lessons }
                navTile(icon: "gearshape.fill",
                        label: "Einstellungen",
                        value: "",
                        color: Color(hex: "555555")) { selectedTab = .settings }
                navTile(icon: "pencil.tip",
                        label: "Notizen",
                        value: "\(store.proNotes.count)",
                        color: Color(hex: "880E4F")) { selectedTab = .notes }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 16)

            recentSection
                .padding(.horizontal, 20)

            Spacer(minLength: 16)
        }
    }

    // MARK: Student Content (kein Scroll)
    var studentContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            if store.receivedSessions.isEmpty {
                StudentEmptyPlaceholder()
                    .padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Meine Trainings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "666666"))
                        .padding(.horizontal, 20)
                    ForEach(store.receivedSessions.prefix(5)) { session in
                        sessionRow(session).padding(.horizontal, 20)
                    }
                }
            }
            Spacer(minLength: 16)
        }
    }

    // MARK: Nav Tile
    @ViewBuilder
    func navTile(icon: String, label: String, value: String, color: Color,
                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
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
                Button { showQuickCapture = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Erfassen").font(.system(size: 12, weight: .medium))
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
                Button { showQuickCapture = true } label: {
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

// MARK: - AfterLesson Orb

struct AfterLessonOrb: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {

                ZStack {
                    // Pulsierende Ringe (3 Ringe, versetzt)
                    ForEach(0..<3, id: \.self) { i in
                        PulseRing(
                            color: ALColor.gold,
                            size: 122,
                            delay: Double(i) * 0.7
                        )
                    }

                    // Statischer Goldring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "D4A840"), Color(hex: "A07820"),
                                         Color(hex: "D4A840"), Color(hex: "8B6210")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 128, height: 128)

                    // Haupt-Kreis Golf-Grün
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "2D6A30"), Color(hex: "173D1A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 122, height: 122)
                        .shadow(color: ALColor.green.opacity(0.55), radius: 20, x: 0, y: 10)

                    // Golfer + Mic
                    VStack(spacing: 4) {
                        Image(systemName: "figure.golf")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(.white.opacity(0.95))
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "D4A840"))
                    }
                }
                .frame(width: 200, height: 200)

                // Label
                VStack(spacing: 4) {
                    Text("AfterLesson")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                    Text("Stunde erfassen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "999999"))
                        .tracking(0.3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulse Ring

struct PulseRing: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color.opacity(animate ? 0 : 0.50), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(animate ? 1.9 : 1.0)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.4)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animate = true
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
            return session.teacherName.isEmpty ? "Trainingsprotokoll" : "von \(session.teacherName)"
        }
        return studentName.isEmpty ? "Kein Schüler" : studentName
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

                Text("Dein Golf Pro sendet dir nach\njedem Training eine Zusammenfassung.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "888888"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
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

// MARK: - Pinned Note Card

struct PinnedNoteCard: View {
    @EnvironmentObject var store: AppStore
    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 12) {
                // Pin-Icon
                ZStack {
                    Circle()
                        .fill(store.pinnedNote != nil
                              ? Color(hex: store.pinnedNote!.colorHex)
                              : Color(hex: "C9A84C").opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(store.pinnedNote != nil ? .white : Color(hex: "C9A84C"))
                        .rotationEffect(.degrees(45))
                }

                if let note = store.pinnedNote {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title.isEmpty ? "Unbenannte Notiz" : note.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "1A1A1A"))
                            .lineLimit(1)
                        if !note.text.isEmpty {
                            Text(note.text)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "888888"))
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("Wichtige Notiz anheften …")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "AAAAAA"))
                }

                Spacer()

                if store.pinnedNote != nil {
                    Button {
                        store.pinnedNoteID = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "BBBBBB"))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(store.pinnedNote != nil
                          ? Color(hex: store.pinnedNote!.colorHex).opacity(0.08)
                          : Color(hex: "F0EDE6"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        store.pinnedNote != nil
                            ? Color(hex: store.pinnedNote!.colorHex).opacity(0.25)
                            : Color(hex: "C9A84C").opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.2, dash: store.pinnedNote != nil ? [] : [5, 3])
                    )
            )
            .shadow(color: Color.black.opacity(store.pinnedNote != nil ? 0.05 : 0), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            PinNotePickerSheet()
        }
    }
}

// MARK: - Pin Note Picker

struct PinNotePickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.proNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "pin.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(ALColor.gold.opacity(0.5))
                        Text("Noch keine Notizen")
                            .font(.headline)
                        Text("Erstelle zuerst eine Notiz um sie anheften zu können.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.proNotes) { note in
                        Button {
                            store.pinnedNoteID = note.id.uuidString
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: note.colorHex))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                        .rotationEffect(.degrees(45))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(note.title.isEmpty ? "Unbenannte Notiz" : note.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if !note.text.isEmpty {
                                        Text(note.text)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if store.pinnedNoteID == note.id.uuidString {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(ALColor.green)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notiz anheften")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if !store.pinnedNoteID.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Lösen") {
                            store.pinnedNoteID = ""
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Golf Ball Jar

struct GolfBallJar: View {
    @State private var animate = false

    let balls: [(x: CGFloat, y: CGFloat, delay: Double, size: CGFloat, color: Color)] = [
        (-11,  5, 0.00, 19, Color(hex: "E53935")),   // Rot
        ( 11,  5, 0.08, 19, Color(hex: "C9A84C")),   // Gold
        ( -8, -11, 0.16, 17, ALColor.green),           // Grün
        (  9, -10, 0.10, 17, Color(hex: "1565C0")),   // Blau
    ]

    var body: some View {
        ZStack {
            // Glasgefäss
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1.0)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.6))
                )
                .frame(width: 58, height: 62)

            // Golfbälle — wackeln links/rechts
            ForEach(balls.indices, id: \.self) { i in
                let b = balls[i]
                GolfBall(size: b.size, color: b.color)
                    .offset(
                        x: b.x + (animate ? 4 : -4),
                        y: b.y + (animate ? 1 : -1)
                    )
                    .rotationEffect(.degrees(animate ? 8 : -8))
                    .animation(
                        .easeInOut(duration: 1.2)
                        .delay(b.delay)
                        .repeatForever(autoreverses: true),
                        value: animate
                    )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animate = true
            }
        }
    }
}

struct GolfBall: View {
    let size: CGFloat
    var color: Color = .white

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.6), color],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.35), radius: 3, x: 1, y: 2)

            // Dimples
            ForEach(dimplePositions(size: size), id: \.self) { pos in
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: size * 0.13, height: size * 0.13)
                    .offset(x: pos.x, y: pos.y)
            }
        }
    }

    func dimplePositions(size: CGFloat) -> [CGPoint] {
        let r = size * 0.28
        return [
            CGPoint(x: 0,  y: -r),
            CGPoint(x: r,  y: 0),
            CGPoint(x: 0,  y: r),
            CGPoint(x: -r, y: 0),
            CGPoint(x: r * 0.7, y: -r * 0.7),
            CGPoint(x: -r * 0.7, y: r * 0.7),
        ]
    }
}

// MARK: - Quick Tile

struct QuickTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Datenpool (zentrale Inhalts-Verwaltung)
//
// Ersetzt die frühere "Lektionsvorlagen"-Ansicht: Der Pro sammelt hier alle
// Lerninhalte – egal in welchem Format – an einem Ort. Jedes Element trägt
// ein kleines Vorschau-Icon, das auf einen Blick zeigt, um was es sich
// handelt. Aus diesem Pool heraus werden später Lektionen zusammengestellt
// und Inhalte gezielt den Schülern zugewiesen.

struct DatenpoolView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingClass: ContentClass? = nil
    @State private var showNewClassSheet = false

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var body: some View {
        NavigationStack {
            Group {
                if store.contentClasses.isEmpty && store.contentPool.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            classGrid
                        }
                        .padding(16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Datenpool")
            .toolbar {
                if isTeacher {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showNewClassSheet = true } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewClassSheet) {
                ContentClassEditorSheet(existingClass: nil)
            }
            .sheet(item: $editingClass) { c in
                ContentClassEditorSheet(existingClass: c)
            }
        }
    }

    // MARK: Klassen-Grid (Ordner-Übersicht)

    var classGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(store.contentClasses.sorted(by: { $0.sortIndex < $1.sortIndex })) { c in
                NavigationLink {
                    ClassContentView(contentClass: c)
                } label: {
                    ContentClassTile(contentClass: c, count: store.items(in: c).count)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if isTeacher {
                        Button { editingClass = c } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.deleteContentClass(c)
                        } label: {
                            Label("Klasse löschen", systemImage: "trash")
                        }
                    }
                }
            }

            // "Unsortiert" — alle Inhalte ohne Klasse. Immer sichtbar, damit
            // neue Importe sofort einen Ort haben und nichts "verschwindet".
            NavigationLink {
                ClassContentView(contentClass: nil)
            } label: {
                ContentClassTile(contentClass: nil, count: store.unclassifiedItems.count)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Empty State (noch keine Klassen & keine Inhalte)

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(ALColor.green.opacity(0.35))
            Text("Datenpool ist leer")
                .font(.title3.bold())
            Text("Lege Klassen an, um deine Inhalte zu strukturieren –\nz.B. Abschlag, Putten oder Theorie")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isTeacher {
                Button { showNewClassSheet = true } label: {
                    Label("Neue Klasse", systemImage: "folder.badge.plus")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(ALColor.green)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Klassen-Kachel (Ordner im Datenpool)

struct ContentClassTile: View {
    let contentClass: ContentClass?     // nil = "Unsortiert"
    let count: Int

    var color: Color {
        contentClass.map { Color(hex: $0.colorHex) } ?? Color(.systemGray)
    }
    var icon: String { contentClass?.icon ?? "tray.fill" }
    var title: String { contentClass?.title ?? "Unsortiert" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                Spacer()
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(Capsule())
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(count == 1 ? "1 Inhalt" : "\(count) Inhalte")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Klassen-Inhalt (Grid der Inhalte einer Klasse bzw. "Unsortiert")

struct ClassContentView: View {
    let contentClass: ContentClass?     // nil = "Unsortiert"
    @EnvironmentObject var store: AppStore
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var selectedItem: ContentItem? = nil
    @State private var filterType: ContentType? = nil
    @State private var filterTheme: String? = nil
    @State private var isImporting = false
    @State private var importError: String? = nil

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    /// Die Inhalte dieser Klasse (bzw. alle ohne Klasse bei "Unsortiert").
    var classItems: [ContentItem] {
        store.contentPool.filter { $0.classID == contentClass?.id }
    }

    /// Alle in dieser Klasse vergebenen Themen ("Gruppierungen"), alphabetisch —
    /// Grundlage für die Themen-Filterleiste. Bleibt leer, solange noch nichts zugeordnet wurde.
    var allThemes: [String] {
        Array(Set(classItems.flatMap { $0.tags })).sorted()
    }

    var filteredItems: [ContentItem] {
        classItems.filter { item in
            (filterType == nil || item.type == filterType)
            && (filterTheme == nil || item.tags.contains(filterTheme!))
        }
    }

    var body: some View {
        Group {
            if classItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        filterBar
                        themeFilterBar
                        grid
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(contentClass?.title ?? "Unsortiert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isTeacher {
                ToolbarItem(placement: .primaryAction) {
                    addMenu
                }
            }
        }
        .onChange(of: photoPickerItems) { _, items in
            guard !items.isEmpty else { return }
            importFromPhotos(items)
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photoPickerItems,
                      maxSelectionCount: 20, matching: .any(of: [.images, .videos]))
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.pdf, .movie, .image, .audio, .plainText, .data],
                      allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
        .fullScreenCover(isPresented: $showCamera) {
            VideoCameraView { url in
                importRecordedVideo(from: url)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedItem) { item in
            ContentItemDetailView(item: item)
        }
        .overlay {
            if isImporting { importOverlay }
        }
        .alert("Import fehlgeschlagen",
               isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: Hinzufügen-Menü

    var addMenu: some View {
        Menu {
            Button { showPhotosPicker = true } label: {
                Label("Fotos & Videos", systemImage: "photo.on.rectangle")
            }
            Button { showFileImporter = true } label: {
                Label("Datei importieren", systemImage: "doc.badge.plus")
            }
            Button { showCamera = true } label: {
                Label("Video aufnehmen", systemImage: "video.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
        }
    }

    // MARK: Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 60))
                .foregroundStyle(ALColor.green.opacity(0.35))
            Text(contentClass == nil ? "Keine unsortierten Inhalte" : "Diese Klasse ist leer")
                .font(.title3.bold())
            Text("Importiere Fotos, Videos und PDFs\noder nimm direkt etwas Neues auf")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isTeacher {
                Menu {
                    Button { showPhotosPicker = true } label: {
                        Label("Fotos & Videos", systemImage: "photo.on.rectangle")
                    }
                    Button { showFileImporter = true } label: {
                        Label("Datei importieren", systemImage: "doc.badge.plus")
                    }
                    Button { showCamera = true } label: {
                        Label("Video aufnehmen", systemImage: "video.badge.plus")
                    }
                } label: {
                    Label("Inhalt hinzufügen", systemImage: "plus")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(ALColor.green)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Filter-Leiste

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "Alle")
                ForEach(ContentType.allCases, id: \.self) { type in
                    filterChip(type, label: type.label)
                }
            }
        }
    }

    func filterChip(_ type: ContentType?, label: String) -> some View {
        let isSelected = filterType == type
        let color = type.map { Color(hex: $0.colorHex) } ?? ALColor.green
        return Button {
            filterType = type
        } label: {
            HStack(spacing: 6) {
                if let type {
                    Image(systemName: type.icon).font(.caption2)
                }
                Text(label).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Themen-Filterleiste ("Gruppierungen")
    //
    // Zweite, optionale Filterebene über die im Pool vergebenen Themen
    // (ContentItem.tags) — ergänzt den Typ-Filter oben. Erscheint erst,
    // sobald mindestens ein Inhalt einem Thema zugeordnet wurde, damit der
    // Datenpool für Hans' aktuelle Daten unverändert schlank bleibt.

    @ViewBuilder
    var themeFilterBar: some View {
        if !allThemes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    themeChip(nil, label: "Alle Themen")
                    ForEach(allThemes, id: \.self) { theme in
                        themeChip(theme, label: theme)
                    }
                }
            }
        }
    }

    func themeChip(_ theme: String?, label: String) -> some View {
        let isSelected = filterTheme == theme
        return Button {
            filterTheme = theme
        } label: {
            HStack(spacing: 6) {
                if theme != nil {
                    Image(systemName: "tag.fill").font(.caption2)
                }
                Text(label).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? ALColor.gold : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Grid

    var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(filteredItems) { item in
                Button { selectedItem = item } label: {
                    ContentItemTile(item: item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if isTeacher {
                        Menu {
                            ForEach(store.contentClasses.sorted(by: { $0.sortIndex < $1.sortIndex })) { c in
                                if c.id != contentClass?.id {
                                    Button {
                                        store.move(item, toClass: c.id)
                                    } label: {
                                        Label(c.title, systemImage: c.icon)
                                    }
                                }
                            }
                            if contentClass != nil {
                                Button {
                                    store.move(item, toClass: nil)
                                } label: {
                                    Label("Unsortiert", systemImage: "tray.fill")
                                }
                            }
                        } label: {
                            Label("In Klasse verschieben", systemImage: "folder")
                        }
                    }
                    Button(role: .destructive) {
                        store.deleteContentItem(item)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
    }

    var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white).scaleEffect(1.3)
                Text("Wird importiert …")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Import – Fotos & Videos aus der Mediathek

    func importFromPhotos(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            for item in items {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg")
                let filename = "pool_\(UUID().uuidString).\(ext)"
                store.saveImage(data, filename: filename)

                var thumbFilename: String? = nil
                if isVideo, let thumbData = await generateVideoThumbnail(url: store.imageURL(for: filename)) {
                    thumbFilename = "pool_thumb_\(UUID().uuidString).jpg"
                    store.saveImage(thumbData, filename: thumbFilename!)
                }

                let newItem = ContentItem(title: isVideo ? "Video \(dateStamp())" : "Bild \(dateStamp())",
                                          type: isVideo ? .video : .image,
                                          filename: filename, thumbnailFilename: thumbFilename,
                                          source: .imported, classID: contentClass?.id)
                store.addContentItem(newItem)
            }
            photoPickerItems = []
            isImporting = false
        }
    }

    // MARK: Import – Dateien (PDF, Audio, Text, …)

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            isImporting = true
            Task {
                for url in urls {
                    await importFile(from: url)
                }
                isImporting = false
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    func importFile(from url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }

        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        let filename = "pool_\(UUID().uuidString).\(ext)"
        store.saveImage(data, filename: filename)

        let type = contentType(forExtension: url.pathExtension)
        var thumbFilename: String? = nil
        if type == .video, let thumbData = await generateVideoThumbnail(url: store.imageURL(for: filename)) {
            thumbFilename = "pool_thumb_\(UUID().uuidString).jpg"
            store.saveImage(thumbData, filename: thumbFilename!)
        }

        let rawTitle = url.deletingPathExtension().lastPathComponent
        let newItem = ContentItem(title: rawTitle.isEmpty ? type.label : rawTitle,
                                  type: type, filename: filename, thumbnailFilename: thumbFilename,
                                  source: .imported, classID: contentClass?.id)
        store.addContentItem(newItem)
    }

    func contentType(forExtension ext: String) -> ContentType {
        guard let utType = UTType(filenameExtension: ext) else { return .text }
        if utType.conforms(to: .pdf) { return .pdf }
        if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
        if utType.conforms(to: .image) { return .image }
        if utType.conforms(to: .audio) { return .audio }
        return .text
    }

    // MARK: Aufnahme – Video direkt filmen

    func importRecordedVideo(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let filename = "pool_\(UUID().uuidString).mov"
        store.saveImage(data, filename: filename)

        isImporting = true
        Task {
            var thumbFilename: String? = nil
            if let thumbData = await generateVideoThumbnail(url: store.imageURL(for: filename)) {
                thumbFilename = "pool_thumb_\(UUID().uuidString).jpg"
                store.saveImage(thumbData, filename: thumbFilename!)
            }
            let newItem = ContentItem(title: "Aufnahme \(dateStamp())", type: .video,
                                      filename: filename, thumbnailFilename: thumbFilename,
                                      source: .recorded, classID: contentClass?.id)
            store.addContentItem(newItem)
            try? FileManager.default.removeItem(at: url)
            isImporting = false
        }
    }

    // MARK: Hilfsfunktionen

    func generateVideoThumbnail(url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let result = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 60)) else { return nil }
        return UIImage(cgImage: result.image).jpegData(compressionQuality: 0.7)
    }

    func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM. HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - Klassen-Editor (Neue Klasse anlegen / bearbeiten)

struct ContentClassEditorSheet: View {
    let existingClass: ContentClass?
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "2C5F2D"

    var isEditing: Bool { existingClass != nil }

    let classIcons = [
        "folder.fill", "figure.golf", "figure.stand", "sportscourt.fill",
        "trophy.fill", "flag.fill", "star.fill", "bolt.fill",
        "scope", "target", "brain.head.profile", "eye.fill",
        "sun.max.fill", "leaf.fill", "video.fill", "photo.fill",
        "doc.richtext.fill", "waveform", "book.fill", "lightbulb.fill",
        "timer", "repeat", "checkmark.seal.fill", "graduationcap.fill"
    ]

    let colors: [(String, String)] = [
        ("1B5E20", "Dunkelgrün"), ("2C5F2D", "Golf-Grün"), ("1565C0", "Blau"),
        ("4A148C", "Lila"),      ("E65100", "Orange"),    ("37474F", "Grau"),
        ("880E4F", "Pink"),      ("006064", "Türkis"),    ("BF360C", "Rot"),
        ("F57F17", "Gold"),      ("263238", "Anthrazit"), ("4E342E", "Braun")
    ]

    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Vorschau
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: selectedColor))
                            .frame(width: 72, height: 72)
                        Image(systemName: selectedIcon)
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        TextField("z.B. Abschlag, Putten, Theorie", text: $title)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }

                    // Icon-Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(classIcons, id: \.self) { icon in
                                Button { selectedIcon = icon } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon
                                                  ? Color(hex: selectedColor)
                                                  : Color(.tertiarySystemFill))
                                            .frame(height: 44)
                                        Image(systemName: icon)
                                            .font(.system(size: 17))
                                            .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Farb-Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Farbe").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(colors, id: \.0) { hex, _ in
                                Button { selectedColor = hex } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 38, height: 38)
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Klasse bearbeiten" : "Neue Klasse")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let c = existingClass {
                    title = c.title
                    selectedIcon = c.icon
                    selectedColor = c.colorHex
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isEditing, var c = existingClass {
                            c.title = t
                            c.icon = selectedIcon
                            c.colorHex = selectedColor
                            store.updateContentClass(c)
                        } else {
                            store.addContentClass(title: t, icon: selectedIcon, colorHex: selectedColor)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Content Item Tile (Kachel im Datenpool-Grid)

struct ContentItemTile: View {
    let item: ContentItem
    @EnvironmentObject var store: AppStore

    var typeColor: Color { Color(hex: item.type.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                preview
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .background(typeColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                ZStack {
                    Circle().fill(typeColor)
                        .frame(width: 26, height: 26)
                    Image(systemName: item.type.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .padding(6)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: item.source == .recorded ? "video.fill" : "square.and.arrow.down.fill")
                        .font(.system(size: 9))
                    Text(item.dateCreated.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                if let firstTheme = item.tags.first {
                    HStack(spacing: 3) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 8))
                        Text(item.tags.count > 1 ? "\(firstTheme) +\(item.tags.count - 1)" : firstTheme)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(ALColor.green)
                }
            }
        }
    }

    @ViewBuilder
    var preview: some View {
        if item.type == .image, let img = UIImage(contentsOfFile: store.imageURL(for: item.filename).path) {
            Image(uiImage: img).resizable().scaledToFill().frame(height: 110).clipped()
        } else if let thumb = item.thumbnailFilename,
                  let img = UIImage(contentsOfFile: store.imageURL(for: thumb).path) {
            ZStack {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 110).clipped()
                if item.type == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
            }
        } else {
            Image(systemName: item.type.icon)
                .font(.system(size: 32))
                .foregroundStyle(typeColor)
        }
    }
}

// MARK: - Content Item Detail (Vorschau je nach Typ)

struct ContentItemDetailView: View {
    let item: ContentItem
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirm = false
    @State private var showAddToLesson = false
    @State private var showTagEditor = false
    @State private var tags: [String]

    init(item: ContentItem) {
        self.item = item
        _tags = State(initialValue: item.tags)
    }

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    /// Alle im Datenpool bereits verwendeten Themen — als Vorschläge beim Zuordnen,
    /// damit sich über mehrere Inhalte hinweg dieselben Gruppierungen bilden.
    var allPoolThemes: [String] {
        Array(Set(store.contentPool.flatMap { $0.tags })).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch item.type {
                    case .image:
                        imagePreview
                    case .video:
                        VideoPlayer(player: AVPlayer(url: store.imageURL(for: item.filename)))
                    case .pdf:
                        PDFKitRepresentable(url: store.imageURL(for: item.filename))
                    case .audio:
                        AudioPlayerView(url: store.imageURL(for: item.filename))
                    case .text:
                        ScrollView {
                            Text(item.notes.isEmpty ? "Kein Text hinterlegt." : item.notes)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isTeacher {
                    themesBar
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddToLesson = true
                    } label: {
                        Image(systemName: "plus.rectangle.on.folder")
                    }
                    .accessibilityLabel("Zu Lektion hinzufügen")
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog("Diesen Inhalt wirklich löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.deleteContentItem(item)
                    dismiss()
                }
            }
            .sheet(isPresented: $showAddToLesson) {
                AddToLessonSheet(item: item)
            }
            .sheet(isPresented: $showTagEditor) {
                TagEditorSheet(themes: $tags, suggestions: allPoolThemes)
            }
            .onChange(of: tags) { _, newThemes in
                guard newThemes != item.tags else { return }
                var updated = item
                updated.tags = newThemes
                store.updateContentItem(updated)
            }
        }
    }

    // MARK: Themen-Leiste
    //
    // Kompakte Anzeige der zugeordneten Themen ("Gruppierungen") direkt in der
    // Detail-Vorschau, mit Einstieg ins Bearbeiten — macht Datenpool-Inhalte
    // über gemeinsame Themen wiederfind- und gruppierbar (z. B. "Putting",
    // "Anfänger", "Kurzes Spiel" …). Nutzt das vorhandene ContentItem.tags-Feld,
    // persistiert über store.updateContentItem (siehe onChange oben).

    var themesBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundStyle(ALColor.green)
                Text("Themen")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showTagEditor = true
                } label: {
                    Text(tags.isEmpty ? "Zuordnen" : "Bearbeiten")
                        .font(.caption.weight(.semibold))
                }
            }
            if tags.isEmpty {
                Text("Noch keinem Thema zugeordnet. Ordne diesen Inhalt z. B. „Putting“ oder „Anfänger“ zu, um ihn im Datenpool leichter wiederzufinden und beim Zusammenstellen einer Lektion zu gruppieren.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { theme in
                            Text(theme)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ALColor.green.opacity(0.12))
                                .foregroundStyle(ALColor.green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }

    @ViewBuilder
    var imagePreview: some View {
        if let img = UIImage(contentsOfFile: store.imageURL(for: item.filename).path) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            .background(Color.black)
        } else {
            ContentUnavailableView("Bild konnte nicht geladen werden", systemImage: "photo")
        }
    }
}

// MARK: - Inhalt nachträglich zu Lektion(en) hinzufügen ("nachliefern")
//
// Erlaubt es, einen einzelnen Datenpool-Inhalt im Nachhinein einer oder
// mehreren bestehenden Lektionen zuzuordnen — auch wenn diese bereits an
// Schüler zugewiesen/versendet wurden. Der Inhalt wird beim nächsten Versand
// automatisch mitgeliefert (siehe AppStore.exportLesson).

struct AddToLessonSheet: View {
    let item: ContentItem
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.lessons.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Lege zuerst eine Lektion an, um Inhalte aus dem Datenpool nachzuliefern.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("Wähle eine oder mehrere Lektionen — „\(item.title)“ wird dort als weiterer Inhalt aus dem Datenpool ergänzt, auch wenn die Lektion bereits einem Schüler zugewiesen ist.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(store.folders.sorted(by: { $0.sortIndex < $1.sortIndex })) { folder in
                            let folderLessons = store.lessonsIn(folder)
                            if !folderLessons.isEmpty {
                                Section(folder.title) {
                                    ForEach(folderLessons) { lesson in
                                        let alreadyIn = lesson.contentItemIDs.contains(item.id)
                                        Button {
                                            store.addContentItem(item, toLesson: lesson)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: alreadyIn ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(alreadyIn ? ALColor.green : .secondary)
                                                    .font(.title3)
                                                Text(lesson.title)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                if alreadyIn {
                                                    Text("bereits enthalten")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(alreadyIn)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Zu Lektion hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Themen-Editor (Gruppierung von Datenpool-Inhalten)
//
// Erlaubt es, einem Datenpool-Inhalt frei wählbare Themen zuzuordnen — nutzt
// das vorhandene ContentItem.tags-Feld als leichtgewichtigen Gruppierungs-
// Mechanismus (ein Inhalt kann mehreren Themen zugleich angehören, z. B.
// "Putting" + "Anfänger"). Inhalte mit gemeinsamen Themen lassen sich im
// Datenpool gefiltert anzeigen (siehe DatenpoolView) und beim Zusammenstellen
// einer Lektion leichter wiederfinden.

struct TagEditorSheet: View {
    @Binding var themes: [String]
    let suggestions: [String]
    @Environment(\.dismiss) var dismiss
    @State private var newThemeText: String = ""

    var availableSuggestions: [String] {
        suggestions.filter { !themes.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Neues Thema, z. B. „Putting“", text: $newThemeText)
                            .onSubmit(addTheme)
                        Button("Hinzufügen", action: addTheme)
                            .fontWeight(.semibold)
                            .disabled(newThemeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } footer: {
                    Text("Inhalte mit demselben Thema lassen sich im Datenpool gemeinsam anzeigen und beim Zusammenstellen einer Lektion leichter wiederfinden.")
                }

                if !themes.isEmpty {
                    Section("Zugeordnet") {
                        ForEach(themes, id: \.self) { theme in
                            HStack(spacing: 10) {
                                Image(systemName: "number")
                                    .foregroundStyle(ALColor.green)
                                Text(theme)
                            }
                        }
                        .onDelete { offsets in
                            themes.remove(atOffsets: offsets)
                        }
                    }
                }

                if !availableSuggestions.isEmpty {
                    Section("Bereits im Datenpool verwendet") {
                        ForEach(availableSuggestions, id: \.self) { theme in
                            Button {
                                themes.append(theme)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(ALColor.green)
                                    Text(theme)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Themen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addTheme() {
        let trimmed = newThemeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !themes.contains(trimmed) else {
            newThemeText = ""
            return
        }
        themes.append(trimmed)
        newThemeText = ""
    }
}

// MARK: - PDF-Vorschau (PDFKit)

struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - Audio-Vorschau

struct AudioPlayerView: View {
    let url: URL
    @State private var player: AVAudioPlayer? = nil
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: ContentType.audio.colorHex))
            Button {
                isPlaying ? stop() : play()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                    Text(isPlaying ? "Stoppen" : "Abspielen")
                        .font(.headline)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: ContentType.audio.colorHex).opacity(0.12))
                .foregroundStyle(Color(hex: ContentType.audio.colorHex))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onDisappear { stop() }
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }
}

// MARK: - Video-Aufnahme (Kamera)

struct VideoCameraView: UIViewControllerRepresentable {
    var onFinish: (URL) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoQuality = .typeMedium
        picker.cameraCaptureMode = .video
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoCameraView
        init(_ parent: VideoCameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let url = info[.mediaURL] as? URL
            picker.dismiss(animated: true) {
                if let url { self.parent.onFinish(url) }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Folders View

struct FoldersView: View {
    @EnvironmentObject var store: AppStore
    @State private var showNewFolder = false
    @State private var selectedFolder: LessonFolder? = nil
    @State private var folderToEdit: LessonFolder? = nil

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.folders.sorted { $0.sortIndex < $1.sortIndex }) { folder in
                    HStack(spacing: 0) {
                        Button { selectedFolder = folder } label: {
                            FolderRowView(folder: folder, lessonCount: store.lessonsIn(folder).count)
                        }
                        .foregroundStyle(.primary)

                        if isTeacher {
                            Button { folderToEdit = folder } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(ALColor.gold.opacity(0.7))
                                    .padding(.leading, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if isTeacher {
                            Button(role: .destructive) {
                                store.deleteFolder(folder)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                Color.clear.frame(height: 8).listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Lektionsvorlagen")
            .toolbar {
                if isTeacher {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showNewFolder = true } label: {
                            Image(systemName: "folder.badge.plus")
                        }
                    }
                }
            }
            .sheet(item: $selectedFolder) { folder in
                LessonsInFolderView(folder: folder)
            }
            .sheet(isPresented: $showNewFolder) {
                FolderEditorSheet(existingFolder: nil)
            }
            .sheet(item: $folderToEdit) { folder in
                FolderEditorSheet(existingFolder: folder)
            }
        }
    }
}

// MARK: - Folder Editor Sheet

struct FolderEditorSheet: View {
    let existingFolder: LessonFolder?
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "2C5F2D"

    var isEditing: Bool { existingFolder != nil }

    let folderIcons = [
        "folder.fill", "figure.golf", "figure.walk", "figure.stand",
        "sportscourt.fill", "trophy.fill", "flag.fill", "star.fill",
        "bolt.fill", "arrow.up.right", "scope", "target",
        "brain.head.profile", "eye.fill", "checkmark.seal.fill", "rotate.3d",
        "sun.max.fill", "wind", "leaf.fill", "mountain.2.fill",
        "timer", "repeat", "waveform.path.ecg", "slider.horizontal.3"
    ]

    let colors: [(String, String)] = [
        ("1B5E20", "Dunkelgrün"), ("2C5F2D", "Golf-Grün"), ("1565C0", "Blau"),
        ("4A148C", "Lila"),      ("E65100", "Orange"),    ("37474F", "Grau"),
        ("880E4F", "Pink"),      ("006064", "Türkis"),    ("BF360C", "Rot"),
        ("F57F17", "Gold"),      ("263238", "Anthrazit"), ("4E342E", "Braun")
    ]

    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Vorschau
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: selectedColor))
                            .frame(width: 72, height: 72)
                        Image(systemName: selectedIcon)
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    // Name & Untertitel
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name").font(.caption.bold()).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            TextField("z.B. Abschlag", text: $title)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Untertitel (optional)").font(.caption.bold()).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            TextField("z.B. Drive & Aufstellung", text: $subtitle)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }
                    }

                    // Icon-Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(folderIcons, id: \.self) { icon in
                                Button { selectedIcon = icon } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon
                                                  ? Color(hex: selectedColor)
                                                  : Color(.tertiarySystemFill))
                                            .frame(height: 44)
                                        Image(systemName: icon)
                                            .font(.system(size: 17))
                                            .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Farb-Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Farbe").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(colors, id: \.0) { hex, _ in
                                Button { selectedColor = hex } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 38, height: 38)
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Vorlage bearbeiten" : "Neue Vorlage")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let f = existingFolder {
                    title = f.title
                    subtitle = f.subtitle
                    selectedIcon = f.icon
                    selectedColor = f.colorHex
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isEditing, var f = existingFolder {
                            f.title = t
                            f.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            f.icon = selectedIcon
                            f.colorHex = selectedColor
                            store.updateFolder(f)
                        } else {
                            store.addFolder(title: t, subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines), icon: selectedIcon, colorHex: selectedColor)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Folder Row

struct FolderRowView: View {
    let folder: LessonFolder
    let lessonCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: folder.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: folder.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: folder.colorHex))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.title).font(.headline)
                Text(folder.subtitle.isEmpty ? "\(lessonCount) Lektionen" : folder.subtitle)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(lessonCount)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: folder.colorHex))
                .clipShape(Capsule())
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Lessons in Folder

struct LessonsInFolderView: View {
    let folder: LessonFolder
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showNewLesson = false
    @State private var selectedLesson: Lesson? = nil
    @State private var lessonToEdit: Lesson? = nil
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }
    var lessons: [Lesson] { store.lessonsIn(folder) }

    var body: some View {
        NavigationStack {
            Group {
                if lessons.isEmpty {
                    emptyState
                } else {
                    lessonGrid
                }
            }
            .navigationTitle(folder.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button {
                            if let url = store.exportFolder(folder) {
                                shareURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        if isTeacher {
                            Button { showNewLesson = true } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson) {
                    lessonToEdit = lesson
                }
            }
            .sheet(isPresented: $showNewLesson) {
                LessonEditorView(folderID: folder.id, existingLesson: nil)
            }
            .sheet(item: $lessonToEdit) { lesson in
                LessonEditorView(folderID: folder.id, existingLesson: lesson)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: folder.icon)
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: folder.colorHex).opacity(0.4))
            Text("Noch keine Vorlagen")
                .font(.headline).foregroundStyle(.secondary)
            if isTeacher {
                Text("Tippe auf + um eine Vorlage hinzuzufügen")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var lessonGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(lessons) { lesson in
                    LessonCardView(lesson: lesson) {
                        selectedLesson = lesson
                    }
                    .contextMenu {
                        if isTeacher {
                            Button {
                                store.duplicateLesson(lesson)
                            } label: {
                                Label("Duplizieren", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                store.deleteLesson(lesson)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Lesson Card (mit Bild-Preview)

struct LessonCardView: View {
    let lesson: Lesson
    let onTap: () -> Void
    @EnvironmentObject var store: AppStore

    /// Inhalte, die diese Lektion zusätzlich aus dem zentralen Datenpool bezieht.
    var poolItems: [ContentItem] { store.contentItems(for: lesson) }

    /// Gesamtzahl der Medien — klassisch hochgeladene Bilder plus Pool-Inhalte.
    var totalMediaCount: Int { lesson.imageFilenames.count + poolItems.count }

    var firstImage: UIImage? {
        if let first = lesson.imageFilenames.first,
           let img = UIImage(contentsOfFile: store.imageURL(for: first).path) {
            return img
        }
        for item in poolItems {
            if item.type == .image, let img = UIImage(contentsOfFile: store.imageURL(for: item.filename).path) {
                return img
            }
            if let thumb = item.thumbnailFilename, let img = UIImage(contentsOfFile: store.imageURL(for: thumb).path) {
                return img
            }
        }
        return nil
    }

    var isCompleted: Bool { store.isCompleted(lesson.id) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Bild Preview
                ZStack(alignment: .topTrailing) {
                    if let img = firstImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(ALColor.green.opacity(0.12))
                            .frame(height: 110)
                            .overlay {
                                Image(systemName: lesson.icon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(ALColor.green.opacity(0.3))
                            }
                    }

                    // Medien-Anzahl Badge (klassisch + Datenpool)
                    if totalMediaCount > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.caption2)
                            Text("\(totalMediaCount)")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(6)
                    }

                    // Erledigt Badge
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                            .padding(6)
                            .offset(x: 0, y: totalMediaCount > 1 ? 28 : 0)
                    }
                }

                // Titel & Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !poolItems.isEmpty {
                        Label("\(poolItems.count) aus Datenpool", systemImage: "square.grid.2x2.fill")
                            .font(.caption)
                            .foregroundStyle(ALColor.fairway)
                    }
                    if !lesson.tips.isEmpty {
                        Text("\(lesson.tips.count) Tipps")
                            .font(.caption)
                            .foregroundStyle(ALColor.green)
                    }
                    if !lesson.steps.isEmpty {
                        Text("\(lesson.steps.count) Schritte")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lesson Detail

struct LessonDetailView: View {
    let lesson: Lesson
    let onEdit: (() -> Void)?
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var currentLesson: Lesson
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isAddingPhotos = false
    @State private var previewImage: UIImage? = nil
    @State private var previewIndex: Int? = nil
    @State private var selectedPoolItem: ContentItem? = nil
    @State private var showAddPoolContent = false

    init(lesson: Lesson, onEdit: (() -> Void)? = nil) {
        self.lesson = lesson
        self.onEdit = onEdit
        _currentLesson = State(initialValue: lesson)
    }

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }
    var isCompleted: Bool { store.isCompleted(lesson.id) }

    /// Inhalte, die diese Lektion zusätzlich aus dem zentralen Datenpool bezieht.
    var poolItems: [ContentItem] { store.contentItems(for: currentLesson) }

    var poolContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Inhalte aus dem Datenpool", systemImage: "square.grid.2x2.fill")
                    .font(.headline)
                    .foregroundStyle(ALColor.green)
                Spacer()
                if isTeacher {
                    Button {
                        showAddPoolContent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(ALColor.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Inhalte aus dem Datenpool ergänzen")
                }
            }

            if poolItems.isEmpty {
                Text("Noch keine Inhalte aus dem Datenpool zugeordnet. Du kannst jederzeit weitere Bilder, Videos, PDFs, Audios oder Texte nachliefern.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(poolItems) { item in
                        Button { selectedPoolItem = item } label: {
                            ContentItemTile(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Bilder Galerie (immer zeigen wenn Lehrer, auch leer für Add-Button)
                    if isTeacher || !currentLesson.imageFilenames.isEmpty {
                        imageGallery
                    }

                    // Inhalte aus dem Datenpool (Bilder, Videos, PDFs, Audio, Text) —
                    // für den Lehrer immer sichtbar (auch leer, zum Nachliefern), für Schüler nur mit Inhalt
                    if isTeacher || !poolItems.isEmpty {
                        poolContentSection
                    }

                    // Beschreibung
                    if !currentLesson.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Beschreibung", systemImage: "text.alignleft")
                                .font(.headline)
                                .foregroundStyle(ALColor.green)
                            Text(currentLesson.description)
                                .font(.body)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Schritte
                    if !currentLesson.steps.isEmpty {
                        stepsSection
                    }

                    // Profi-Tipps
                    if !currentLesson.tips.isEmpty {
                        tipsSection
                    }

                    // Als erledigt markieren (Schüler)
                    if !isTeacher {
                        Button {
                            store.markCompleted(lesson.id)
                        } label: {
                            Label(
                                isCompleted ? "Erledigt ✓" : "Als erledigt markieren",
                                systemImage: isCompleted ? "checkmark.circle.fill" : "circle"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isCompleted ? Color.green : ALColor.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(currentLesson.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        // Bearbeiten (nur Lehrer)
                        if isTeacher, let onEdit {
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onEdit()
                                }
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                        // Fotos hinzufügen (nur Lehrer)
                        if isTeacher {
                            PhotosPicker(
                                selection: $photoItems,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundStyle(ALColor.green)
                            }
                            .onChange(of: photoItems) { _, newItems in
                                guard !newItems.isEmpty else { return }
                                isAddingPhotos = true
                                Task {
                                    for item in newItems {
                                        if let data = try? await item.loadTransferable(type: Data.self) {
                                            let filename = "lesson_\(currentLesson.id.uuidString)_\(UUID().uuidString).jpg"
                                            store.saveImage(data, filename: filename)
                                            currentLesson.imageFilenames.append(filename)
                                        }
                                    }
                                    store.updateLesson(currentLesson)
                                    photoItems = []
                                    isAddingPhotos = false
                                }
                            }
                        }
                        // Teilen
                        Button {
                            if let url = store.exportLesson(currentLesson) {
                                shareURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .overlay {
                if isAddingPhotos {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.4)
                            Text("Fotos werden gespeichert…")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
            .sheet(item: Binding(
                get: { previewIndex.map { ImagePreviewItem(index: $0) } },
                set: { previewIndex = $0?.index }
            )) { item in
                ImagePreviewView(
                    filenames: currentLesson.imageFilenames,
                    startIndex: item.index,
                    isTeacher: isTeacher
                ) { filenameToDelete in
                    if let idx = currentLesson.imageFilenames.firstIndex(of: filenameToDelete) {
                        try? FileManager.default.removeItem(at: store.imageURL(for: filenameToDelete))
                        currentLesson.imageFilenames.remove(at: idx)
                        store.updateLesson(currentLesson)
                    }
                    previewIndex = nil
                }
            }
            .sheet(item: $selectedPoolItem) { item in
                ContentItemDetailView(item: item)
            }
            .sheet(isPresented: $showAddPoolContent) {
                ContentPoolPickerView(initialSelection: currentLesson.contentItemIDs) { newSelection in
                    currentLesson.contentItemIDs = newSelection
                    store.updateLesson(currentLesson)
                }
            }
        }
    }

    var imageGallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !currentLesson.imageFilenames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(currentLesson.imageFilenames.enumerated()), id: \.element) { idx, filename in
                            if let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                                Button { previewIndex = idx } label: {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 220, height: 160)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .topTrailing) {
                                            if isTeacher {
                                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                    .font(.caption2)
                                                    .foregroundStyle(.white)
                                                    .padding(5)
                                                    .background(.black.opacity(0.4))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    .padding(6)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }

            // Foto hinzufügen Button (Lehrer, wenn noch keine oder als Ergänzung)
            if isTeacher {
                PhotosPicker(
                    selection: $photoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.subheadline)
                        Text(currentLesson.imageFilenames.isEmpty ? "Übungsfotos hinzufügen" : "Weitere Fotos hinzufügen")
                            .font(.subheadline)
                    }
                    .foregroundStyle(ALColor.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ALColor.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ALColor.green.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                }
            }
        }
    }

    var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schritt für Schritt", systemImage: "list.number")
                .font(.headline)
                .foregroundStyle(ALColor.green)
            ForEach(currentLesson.steps.sorted { $0.order < $1.order }) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(step.order)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(ALColor.green)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title).font(.subheadline.bold())
                        Text(step.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Profi-Tipps", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(ALColor.gold)
            ForEach(currentLesson.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ALColor.gold)
                        .font(.subheadline)
                    Text(tip).font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(ALColor.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Lesson Row (für Home)

struct LessonRowView: View {
    let lesson: Lesson
    @EnvironmentObject var store: AppStore

    var previewImage: UIImage? {
        if let first = lesson.imageFilenames.first,
           let img = UIImage(contentsOfFile: store.imageURL(for: first).path) {
            return img
        }
        for item in store.contentItems(for: lesson) {
            if item.type == .image, let img = UIImage(contentsOfFile: store.imageURL(for: item.filename).path) {
                return img
            }
            if let thumb = item.thumbnailFilename, let img = UIImage(contentsOfFile: store.imageURL(for: thumb).path) {
                return img
            }
        }
        return nil
    }

    var infoLine: String {
        var parts: [String] = []
        if !lesson.steps.isEmpty { parts.append("\(lesson.steps.count) Schritte") }
        if !lesson.tips.isEmpty { parts.append("\(lesson.tips.count) Tipps") }
        let poolCount = store.contentItems(for: lesson).count
        if poolCount > 0 { parts.append("\(poolCount) aus Datenpool") }
        return parts.isEmpty ? "Lektion" : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ALColor.green.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay { Image(systemName: "figure.golf").foregroundStyle(ALColor.green) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(.subheadline.bold())
                Text(infoLine)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Progress View

struct ProgressView_: View {
    @EnvironmentObject var store: AppStore

    var completedCount: Int { store.progress.filter(\.isCompleted).count }
    var totalCount: Int { store.lessons.count }
    var progressValue: Double { totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Gesamt-Fortschritt
                    VStack(spacing: 12) {
                        Text("\(Int(progressValue * 100))%")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(ALColor.green)
                        Text("\(completedCount) von \(totalCount) Lektionen abgeschlossen")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: progressValue)
                            .tint(ALColor.green)
                            .scaleEffect(x: 1, y: 2)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Pro Ordner
                    ForEach(store.folders) { folder in
                        let total = store.lessonsIn(folder).count
                        let done = store.lessonsIn(folder).filter { store.isCompleted($0.id) }.count
                        if total > 0 {
                            HStack {
                                Image(systemName: folder.icon)
                                    .foregroundStyle(Color(hex: folder.colorHex))
                                    .frame(width: 28)
                                Text(folder.title).font(.subheadline.bold())
                                Spacer()
                                Text("\(done)/\(total)")
                                    .font(.caption.bold())
                                    .foregroundStyle(done == total ? .green : .secondary)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fortschritt")
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @Binding var hasSelectedMode: Bool

    @State private var step = 0                      // 0 = Modus, 1 = Name
    @State private var selectedMode: AppMode = .teacher
    @State private var inputName = ""
    @State private var inputTitle = ""
    @FocusState private var nameFocused: Bool

    var canProceed: Bool {
        !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.12, blue: 0.10), ALColor.green],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if step == 0 {
                modeStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                nameStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: - Schritt 1: Modus wählen
    var modeStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 72))
                    .foregroundStyle(ALColor.gold)
                Text("AfterLesson")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Wähle deinen Modus")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 16) {
                // Golf Pro
                Button {
                    selectedMode = .teacher
                    inputTitle = "PGA Teaching Professional"
                    withAnimation { step = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        nameFocused = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(ALColor.gold).frame(width: 56, height: 56)
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ich bin Golf Pro")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Vorlagen erstellen & Schüler verwalten")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(ALColor.gold)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.white.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .stroke(ALColor.gold.opacity(0.5), lineWidth: 1.5))
                    )
                }
                .padding(.horizontal, 24)

                // Schüler
                Button {
                    selectedMode = .student
                    inputTitle = ""
                    withAnimation { step = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        nameFocused = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(ALColor.green).frame(width: 56, height: 56)
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ich bin Schüler")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Trainings empfangen & Fortschritt verfolgen")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(ALColor.green)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.white.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .stroke(ALColor.green.opacity(0.5), lineWidth: 1.5))
                    )
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Text("AfterLesson").font(.caption).foregroundStyle(.white.opacity(0.3)).padding(.bottom, 20)
        }
    }

    // MARK: - Schritt 2: Name eingeben
    var nameStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon je nach Modus
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selectedMode == .teacher ? ALColor.gold : ALColor.green)
                        .frame(width: 80, height: 80)
                    Image(systemName: selectedMode == .teacher ? "figure.golf" : "graduationcap.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
                Text(selectedMode == .teacher ? "Willkommen, Golf Pro!" : "Willkommen!")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Wie heisst du?")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 14) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dein Name")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                    TextField("Vorname Nachname", text: $inputName)
                        .focused($nameFocused)
                        .font(.system(size: 18, weight: .medium))
                        .padding(16)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .foregroundStyle(.white)
                        .tint(ALColor.gold)
                }

                // Titel (nur für Golf Pro)
                if selectedMode == .teacher {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dein Titel (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                        TextField("z.B. PGA Teaching Professional", text: $inputTitle)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .foregroundStyle(.white)
                            .tint(ALColor.gold)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Los geht's Button
            Button {
                let name = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                store.teacherName = name
                if selectedMode == .teacher && !inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.teacherTitle = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                store.appMode = selectedMode.rawValue
                hasSelectedMode = true
            } label: {
                Text("Los geht's →")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canProceed ? ALColor.dark : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(canProceed ? ALColor.gold : Color.white.opacity(0.08))
                    )
            }
            .disabled(!canProceed)
            .padding(.horizontal, 24)

            // Zurück
            Button { withAnimation { step = 0 } } label: {
                Text("← Zurück")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
    }
}

// MARK: - Teacher Dashboard View

struct DashboardRecipient: Identifiable {
    let id = UUID()
    enum Kind {
        case student(Student)
        case group(TeachingGroup)
    }
    let kind: Kind
    var name: String {
        switch kind {
        case .student(let s): return s.name
        case .group(let g): return g.name
        }
    }
    var icon: String {
        switch kind {
        case .student: return "person.fill"
        case .group(let g): return g.icon
        }
    }
    var colorHex: String {
        switch kind {
        case .student(let s): return s.avatarColor
        case .group(let g): return g.colorHex
        }
    }
    var photoFilename: String? {
        switch kind {
        case .student(let s): return s.photoFilename
        case .group: return nil
        }
    }
}

struct TeacherDashboardView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var sendTarget: DashboardRecipient? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var hasContent: Bool { !store.students.isEmpty || !store.groups.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if !hasContent {
                    emptyState
                } else {
                    List {
                        // Klassen
                        if !store.groups.isEmpty {
                            Section("Lernpfade") {
                                ForEach(store.groups) { group in
                                    recipientRow(DashboardRecipient(kind: .group(group)))
                                }
                            }
                        }
                        // Einzelpersonen
                        if !store.students.isEmpty {
                            Section("Einzelpersonen") {
                                ForEach(store.students) { student in
                                    recipientRow(DashboardRecipient(kind: .student(student)))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Senden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $sendTarget) { recipient in
                SendPackageSheet(recipient: recipient) { items in
                    shareItems = items
                    showShareSheet = true
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    @ViewBuilder
    func recipientRow(_ recipient: DashboardRecipient) -> some View {
        Button { sendTarget = recipient } label: {
            HStack(spacing: 14) {
                // Avatar / Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: recipient.colorHex))
                        .frame(width: 46, height: 46)
                    if let filename = recipient.photoFilename,
                       let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: recipient.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipient.name).font(.headline).foregroundStyle(.primary)
                    switch recipient.kind {
                    case .student(let s):
                        let prog = store.progressFor(s)
                        Text(prog.total > 0
                             ? "\(s.assignedLessonIDs.count) Lektionen · \(prog.viewed)/\(prog.total) gesehen"
                             : "\(s.assignedLessonIDs.count) Lektionen zugewiesen")
                            .font(.caption).foregroundStyle(.secondary)
                    case .group(let g):
                        Text("\(store.studentsIn(g).count) Schüler · \(store.lessonsIn(g).count) Lektionen")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                    Text("Senden")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(ALColor.green)
                .clipShape(Capsule())
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 56))
                .foregroundStyle(ALColor.gold.opacity(0.4))
            Text("Noch keine Schüler oder Lernpfade")
                .font(.title3.bold())
            Text("Lege zuerst Schüler oder Lernpfade im jeweiligen Tab an")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Send Package Sheet

struct SendPackageSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let recipient: DashboardRecipient
    let onSend: ([Any]) -> Void

    @State private var selectedLessonIDs: Set<UUID> = []
    @State private var note: String = ""

    var preSelectedIDs: Set<UUID> {
        switch recipient.kind {
        case .student(let s):
            return Set(s.assignedLessonIDs)
        case .group(let g):
            return Set(g.lessonIDs)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Empfänger Header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: recipient.colorHex))
                                .frame(width: 46, height: 46)
                            if let filename = recipient.photoFilename,
                               let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 46, height: 46)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Image(systemName: recipient.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recipient.name).font(.headline)
                            Text(Date().formatted(date: .long, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: { Text("An") }

                // Notiz
                Section {
                    TextField("z.B. Konzentriere dich diese Woche auf die Rotation…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: { Text("Persönliche Notiz (optional)") }

                // Lektionen wählen
                if store.lessons.isEmpty {
                    Section {
                        Text("Zuerst Vorlagen im Vorlagen-Tab anlegen")
                            .font(.caption).foregroundStyle(.secondary)
                    } header: { Text("Lektionen") }
                } else {
                    ForEach(store.folders) { folder in
                        let folderLessons = store.lessonsIn(folder)
                        if !folderLessons.isEmpty {
                            Section {
                                ForEach(folderLessons) { lesson in
                                    let selected = selectedLessonIDs.contains(lesson.id)
                                    Button {
                                        if selected {
                                            selectedLessonIDs.remove(lesson.id)
                                        } else {
                                            selectedLessonIDs.insert(lesson.id)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selected ? ALColor.green : .secondary)
                                                .font(.title3)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(lesson.title).foregroundStyle(.primary)
                                                if !lesson.description.isEmpty {
                                                    Text(lesson.description)
                                                        .font(.caption).foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                                HStack(spacing: 8) {
                                                    if !lesson.tips.isEmpty {
                                                        Text("\(lesson.tips.count) Tipps")
                                                            .font(.caption2).foregroundStyle(ALColor.gold)
                                                    }
                                                    if !lesson.steps.isEmpty {
                                                        Text("\(lesson.steps.count) Schritte")
                                                            .font(.caption2).foregroundStyle(.secondary)
                                                    }
                                                    if !lesson.imageFilenames.isEmpty {
                                                        Label("\(lesson.imageFilenames.count)", systemImage: "photo")
                                                            .font(.caption2).foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                HStack {
                                    Label(folder.title, systemImage: folder.icon)
                                        .foregroundStyle(Color(hex: folder.colorHex))
                                    Spacer()
                                    // Alle aus Ordner wählen
                                    Button {
                                        let ids = folderLessons.map(\.id)
                                        let allSelected = ids.allSatisfy { selectedLessonIDs.contains($0) }
                                        if allSelected {
                                            ids.forEach { selectedLessonIDs.remove($0) }
                                        } else {
                                            ids.forEach { selectedLessonIDs.insert($0) }
                                        }
                                    } label: {
                                        Text(folderLessons.map(\.id).allSatisfy { selectedLessonIDs.contains($0) }
                                             ? "Alle ab" : "Alle")
                                            .font(.caption)
                                            .foregroundStyle(ALColor.green)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Paket zusammenstellen")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedLessonIDs = preSelectedIDs
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        var items: [Any] = []
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let dateStr = Date().formatted(date: .long, time: .omitted)
                            items.append("AfterLesson · \(recipient.name) · \(dateStr)\n\n\(trimmed)")
                        }
                        let selected = store.lessons.filter { selectedLessonIDs.contains($0.id) }
                        items += selected.compactMap { store.exportLesson($0) }
                        if case .student(let s) = recipient.kind {
                            store.recordSent(to: s, lessons: selected, note: trimmed)
                        }
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onSend(items)
                        }
                    } label: {
                        Label("Senden (\(selectedLessonIDs.count))", systemImage: "paperplane.fill")
                    }
                    .disabled(selectedLessonIDs.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Gruppen View (Lernpfade)

struct GruppenView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddGroup = false
    @State private var groupToEdit: TeachingGroup? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "road.lanes")
                            .font(.system(size: 60))
                            .foregroundStyle(ALColor.gold.opacity(0.4))
                        Text("Noch keine Lernpfade")
                            .font(.title3.bold())
                        Text("Tippe auf + um einen Lernpfad anzulegen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(store.groups) { group in
                            NavigationLink(destination: LernpfadDetailView(group: group)) {
                                LernpfadRow(group: group)
                            }
                            .swipeActions(edge: .leading) {
                                Button { groupToEdit = group } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(ALColor.gold)
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { store.deleteGroup(store.groups[$0]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Lernpfade")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddGroup = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddGroup) {
                AddEditGroupSheet()
            }
            .sheet(item: $groupToEdit) { group in
                AddEditGroupSheet(existing: group)
            }
        }
    }
}

// MARK: - Lernpfad Row

struct LernpfadRow: View {
    @EnvironmentObject var store: AppStore
    let group: TeachingGroup

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(hex: group.colorHex))
                    .frame(width: 52, height: 52)
                Image(systemName: group.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !group.notes.isEmpty {
                    Text(group.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label("\(store.lessonsIn(group).count) Lektionen", systemImage: "book.fill")
                    Label("\(store.studentsIn(group).count) Schüler", systemImage: "person.2.fill")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color(hex: group.colorHex))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Lernpfad Detail View

struct LernpfadDetailView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEditSheet = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showAddLesson = false
    @State private var showAddStudent = false

    let group: TeachingGroup

    var currentGroup: TeachingGroup {
        store.groups.first(where: { $0.id == group.id }) ?? group
    }
    var groupColor: Color { Color(hex: currentGroup.colorHex) }
    var lessons: [Lesson] { store.lessonsIn(currentGroup) }
    var students: [Student] { store.studentsIn(currentGroup) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Card
                headerCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Lektionen
                lektionenSection
                    .padding(.top, 24)

                // Schüler
                schuelerSection
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("Lernpfad bearbeiten", systemImage: "pencil")
                    }
                    if !lessons.isEmpty {
                        Button {
                            shareItems = store.exportGroup(currentGroup)
                            if !shareItems.isEmpty { showShareSheet = true }
                        } label: {
                            Label("Alle Lektionen senden", systemImage: "paperplane.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditGroupSheet(existing: currentGroup)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showAddLesson) {
            LernpfadLessonPickerSheet(group: currentGroup)
        }
        .sheet(isPresented: $showAddStudent) {
            LernpfadStudentPickerSheet(group: currentGroup)
        }
    }

    // MARK: Header Card
    var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(groupColor)
                    .frame(width: 68, height: 68)
                Image(systemName: currentGroup.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(currentGroup.name)
                    .font(.title3.bold())
                if !currentGroup.notes.isEmpty {
                    Text(currentGroup.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    Label("\(lessons.count) Lektionen", systemImage: "book.fill")
                    Label("\(students.count) Schüler", systemImage: "person.2.fill")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(groupColor)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: Lektionen Section
    var lektionenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lektionen")
                    .font(.headline)
                Spacer()
                Button { showAddLesson = true } label: {
                    Label("Hinzufügen", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(groupColor)
                }
            }
            .padding(.horizontal, 20)

            if lessons.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                    Text("Noch keine Lektionen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { idx, lesson in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(groupColor.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Text("\(idx + 1)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(groupColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if let folder = store.folders.first(where: { $0.id == lesson.folderID }) {
                                    Text(folder.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                store.toggleLesson(lesson, in: currentGroup)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground))
                        if idx < lessons.count - 1 {
                            Divider().padding(.leading, 62).background(Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Schüler Section
    var schuelerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Schüler")
                    .font(.headline)
                Spacer()
                Button { showAddStudent = true } label: {
                    Label("Hinzufügen", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(groupColor)
                }
            }
            .padding(.horizontal, 20)

            if students.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.slash")
                        .foregroundStyle(.secondary)
                    Text("Noch keine Schüler")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(students.enumerated()), id: \.element.id) { idx, student in
                        let total = lessons.count
                        let lessonIDs = lessons.map(\.id)
                        let viewed = student.viewedLessonIDs.filter { lessonIDs.contains($0) }.count
                        let progress = total > 0 ? Double(viewed) / Double(total) : 0.0

                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: student.avatarColor))
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Text(String(student.name.prefix(1)).uppercased())
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading, spacing: 5) {
                                Text(student.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if total > 0 {
                                    HStack(spacing: 8) {
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color(.tertiarySystemFill))
                                                    .frame(height: 5)
                                                Capsule()
                                                    .fill(progress == 1.0 ? ALColor.green : groupColor)
                                                    .frame(width: geo.size.width * progress, height: 5)
                                            }
                                        }
                                        .frame(height: 5)
                                        Text("\(viewed)/\(total)")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .frame(minWidth: 28, alignment: .trailing)
                                    }
                                } else {
                                    Text("Noch keine Lektionen im Pfad")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                store.toggleStudent(student, in: currentGroup)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground))
                        if idx < students.count - 1 {
                            Divider().padding(.leading, 72).background(Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Lernpfad Lesson Picker Sheet

struct LernpfadLessonPickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let group: TeachingGroup

    var currentGroup: TeachingGroup {
        store.groups.first(where: { $0.id == group.id }) ?? group
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.lessons.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Zuerst Vorlagen im Vorlagen-Tab anlegen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.folders) { folder in
                            let folderLessons = store.lessonsIn(folder)
                            if !folderLessons.isEmpty {
                                Section(folder.title) {
                                    ForEach(folderLessons) { lesson in
                                        let inGroup = currentGroup.lessonIDs.contains(lesson.id)
                                        Button {
                                            store.toggleLesson(lesson, in: currentGroup)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: inGroup ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(inGroup ? Color(hex: currentGroup.colorHex) : .secondary)
                                                    .font(.title3)
                                                Text(lesson.title)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Lektionen auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Lernpfad Student Picker Sheet

struct LernpfadStudentPickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let group: TeachingGroup

    var currentGroup: TeachingGroup {
        store.groups.first(where: { $0.id == group.id }) ?? group
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.students.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Zuerst Schüler im Schüler-Tab anlegen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.students) { student in
                            let inGroup = currentGroup.studentIDs.contains(student.id)
                            Button {
                                store.toggleStudent(student, in: currentGroup)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: student.avatarColor))
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Text(String(student.name.prefix(1)).uppercased())
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                        )
                                    Text(student.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: inGroup ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(inGroup ? Color(hex: currentGroup.colorHex) : .secondary)
                                        .font(.title3)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Schüler auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Add / Edit Group Sheet

struct AddEditGroupSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    var existing: TeachingGroup? = nil
    var isEditing: Bool { existing != nil }

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedIcon: String = "figure.golf"
    @State private var selectedColor: String = "1B5E20"

    let groupIcons = [
        "figure.golf",   "graduationcap.fill", "person.3.fill",  "person.2.fill",
        "trophy.fill",   "flag.fill",           "star.fill",      "scope",
        "bolt.fill",     "chart.line.uptrend.xyaxis", "leaf.fill", "sun.max.fill",
        "clock.fill",    "calendar",            "mappin.fill",    "sportscourt.fill"
    ]

    let colors: [(String, String)] = [
        ("1B5E20", "Grün"),    ("2C5F2D", "Dunkelgrün"), ("1565C0", "Blau"),  ("4A148C", "Lila"),
        ("E65100", "Orange"),  ("37474F", "Grau"),        ("880E4F", "Pink"),  ("006064", "Türkis"),
        ("BF360C", "Rot"),     ("F57F17", "Gold"),        ("263238", "Anthrazit"), ("4E342E", "Braun")
    ]

    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Vorschau
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: selectedColor))
                            .frame(width: 84, height: 84)
                        Image(systemName: selectedIcon)
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                    .animation(.spring(response: 0.3), value: selectedColor)
                    .animation(.spring(response: 0.3), value: selectedIcon)

                    // Name + Beschreibung
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name").font(.caption.bold()).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            TextField("z.B. Anfänger Drive", text: $name)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Beschreibung (optional)").font(.caption.bold()).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            TextField("z.B. Drive-Technik für Einsteiger", text: $description)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(groupIcons, id: \.self) { icon in
                                Button { selectedIcon = icon } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon
                                                  ? Color(hex: selectedColor)
                                                  : Color(.tertiarySystemFill))
                                            .frame(height: 58)
                                        Image(systemName: icon)
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Farb-Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Farbe").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(colors, id: \.0) { hex, _ in
                                Button { selectedColor = hex } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 40, height: 40)
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Lernpfad bearbeiten" : "Neuer Lernpfad")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let g = existing {
                    name = g.name
                    description = g.notes
                    selectedIcon = g.icon
                    selectedColor = g.colorHex
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !n.isEmpty else { return }
                        if var g = existing {
                            g.name = n
                            g.notes = description
                            g.icon = selectedIcon
                            g.colorHex = selectedColor
                            store.updateGroup(g)
                        } else {
                            store.addGroup(name: n, icon: selectedIcon,
                                           colorHex: selectedColor, notes: description)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Speech Transcriber

@MainActor
class SpeechTranscriber: ObservableObject {
    @Published var isRecording = false
    @Published var permissionDenied = false

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    init() {
        // Deutsch (Schweiz) bevorzugt, Fallback auf Deutsch
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-CH"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    }

    func start(existing: String, onChange: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch auth {
                case .authorized:
                    self.startEngine(existing: existing, onChange: onChange)
                default:
                    self.permissionDenied = true
                }
            }
        }
    }

    private func startEngine(existing: String, onChange: @escaping (String) -> Void) {
        stopEngine()
        guard let recognizer, recognizer.isAvailable else { return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let prefix = existing.trimmingCharacters(in: .whitespaces)

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            if let result = result {
                let new = result.bestTranscription.formattedString
                let combined = prefix.isEmpty ? new : prefix + " " + new
                onChange(combined)
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in self?.stopEngine() }
            }
        }

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            try engine.start()
            isRecording = true
        } catch {
            stopEngine()
        }
    }

    func stop() {
        stopEngine()
    }

    private func stopEngine() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Voice Input Field

struct VoiceInputField: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var text: String
    @ObservedObject var transcriber: SpeechTranscriber
    var activeField: String
    @Binding var currentActiveField: String

    var isActive: Bool { currentActiveField == activeField && transcriber.isRecording }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Spacer()
                Button {
                    if isActive {
                        transcriber.stop()
                        currentActiveField = ""
                    } else {
                        if transcriber.isRecording {
                            transcriber.stop()
                        }
                        currentActiveField = activeField
                        transcriber.start(existing: text) { newText in
                            text = newText
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isActive ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(isActive ? .red : color.opacity(0.7))
                        if isActive {
                            Text("Stopp")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Tippe oder sprich…")
                        .font(.subheadline)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }
                TextEditor(text: $text)
                    .font(.subheadline)
                    .frame(minHeight: 70)
                    .padding(8)
                    .scrollContentBackground(.hidden)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isActive ? color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }
}

// MARK: - Quick Capture Sheet

// MARK: - AfterLesson Flow Sheet

struct AfterLessonFlowSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var path: [Student] = []
    @State private var showCapture = false
    @State private var captureStudentID: UUID? = nil

    var body: some View {
        NavigationStack(path: $path) {
            studentListView
                .navigationDestination(for: Student.self) { student in
                    StudentAfterLessonView(student: student) {
                        captureStudentID = student.id
                        showCapture = true
                    }
                }
        }
        .sheet(isPresented: $showCapture) {
            QuickCaptureSheet(preselectedStudentID: captureStudentID)
        }
    }

    // MARK: Schülerliste
    var studentListView: some View {
        Group {
            if store.students.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 64))
                        .foregroundStyle(ALColor.green.opacity(0.25))
                    Text("Noch keine Schüler")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                    Text("Lege Schüler im Schüler-Tab an\num sie hier zu sehen.")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "888888"))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "F0EDE6"))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.students) { student in
                            Button { path.append(student) } label: {
                                studentRow(student)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .background(Color(hex: "F0EDE6"))
            }
        }
        .navigationTitle("AfterLesson")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    @ViewBuilder
    func studentRow(_ student: Student) -> some View {
        let lessons = store.assignedLessonsFor(student)
        let notes   = store.notesFor(student: student)
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: student.avatarColor))
                    .frame(width: 52, height: 52)
                    .shadow(color: Color(hex: student.avatarColor).opacity(0.35), radius: 6, x: 0, y: 3)
                Text(String(student.name.prefix(1)).uppercased())
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(student.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                HStack(spacing: 10) {
                    if !student.handicap.isEmpty {
                        Label("HCP \(student.handicap)", systemImage: "flag.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ALColor.green)
                    }
                    Label("\(lessons.count)", systemImage: "rectangle.stack.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("\(notes.count)", systemImage: "pencil.tip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "CCCCCC"))
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Student AfterLesson View

struct StudentAfterLessonView: View {
    @EnvironmentObject var store: AppStore
    let student: Student
    let onCapture: () -> Void

    var lessons: [Lesson]  { store.assignedLessonsFor(student) }
    var notes:   [ProNote] { store.notesFor(student: student) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Schüler-Banner
                studentBanner

                // Lektionen
                if !lessons.isEmpty {
                    sectionBlock(title: "Lektionen", icon: "rectangle.stack.fill", color: ALColor.gold) {
                        ForEach(lessons) { lessonCard($0) }
                    }
                }

                // Notizen
                if !notes.isEmpty {
                    sectionBlock(title: "Notizen", icon: "pencil.tip", color: ALColor.green) {
                        ForEach(notes) { noteCard($0) }
                    }
                }

                // Leer-Hinweis
                if lessons.isEmpty && notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundStyle(ALColor.gold.opacity(0.35))
                        Text("Noch keine Inhalte zugewiesen")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text("Weise im Schüler-Tab Lektionen und Notizen zu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }

                Color.clear.frame(height: 80)
            }
            .padding(16)
        }
        .background(Color(hex: "F0EDE6"))
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { captureBar }
    }

    // MARK: Banner
    var studentBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: student.avatarColor))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(hex: student.avatarColor).opacity(0.4), radius: 8, x: 0, y: 4)
                Text(String(student.name.prefix(1)).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(student.name)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                HStack(spacing: 12) {
                    if !student.handicap.isEmpty {
                        Label("HCP \(student.handicap)", systemImage: "flag.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ALColor.green)
                    }
                    Text("\(lessons.count) Lektionen · \(notes.count) Notizen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: Section
    @ViewBuilder
    func sectionBlock<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "666666"))
            }
            .padding(.leading, 4)
            content()
        }
    }

    // MARK: Lektion Card
    @ViewBuilder
    func lessonCard(_ lesson: Lesson) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ALColor.gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: lesson.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(ALColor.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                if !lesson.description.isEmpty {
                    Text(lesson.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if !lesson.tips.isEmpty {
                        Text("\(lesson.tips.count) Tipps")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ALColor.gold)
                    }
                    if !lesson.steps.isEmpty {
                        Text("\(lesson.steps.count) Schritte")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !lesson.imageFilenames.isEmpty {
                        Label("\(lesson.imageFilenames.count)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: Notiz Card
    @ViewBuilder
    func noteCard(_ note: ProNote) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: note.colorHex).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "pencil.tip")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: note.colorHex))
            }
            VStack(alignment: .leading, spacing: 3) {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                }
                if !note.text.isEmpty {
                    Text(note.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: Capture Bar
    var captureBar: some View {
        Button(action: onCapture) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "D4A840"), Color(hex: "8B6410")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 38, height: 38)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Stunde erfassen")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ALColor.gold.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ALColor.green)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Capture Sheet

struct QuickCaptureSheet: View {
    var preselectedStudentID: UUID? = nil

    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var transcriber = SpeechTranscriber()

    @State private var selectedStudentID: UUID? = nil

    init(preselectedStudentID: UUID? = nil) {
        self.preselectedStudentID = preselectedStudentID
        _selectedStudentID = State(initialValue: preselectedStudentID)
    }
    @State private var title: String = ""
    @State private var trained: String = ""
    @State private var corrections: String = ""
    @State private var exercises: String = ""
    @State private var homework: String = ""
    @State private var activeField: String = ""
    @State private var showStudentPicker = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var selectedStudent: Student? {
        guard let id = selectedStudentID else { return nil }
        return store.students.first(where: { $0.id == id })
    }

    var autoTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let dateStr = formatter.string(from: Date())
        if let s = selectedStudent { return "Training \(dateStr) · \(s.name)" }
        return "Training \(dateStr)"
    }

    var canSave: Bool {
        !trained.isEmpty || !corrections.isEmpty || !exercises.isEmpty || !homework.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Schüler auswählen
                    Button { showStudentPicker = true } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(selectedStudent != nil
                                          ? Color(hex: selectedStudent!.avatarColor)
                                          : Color(.tertiarySystemFill))
                                    .frame(width: 42, height: 42)
                                if let s = selectedStudent {
                                    Text(String(s.name.prefix(1)).uppercased())
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedStudent?.name ?? "Schüler auswählen")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(selectedStudent != nil ? .primary : .secondary)
                                Text(autoTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)

                    // Trennlinie
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [ALColor.green, ALColor.gold, ALColor.green.opacity(0)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2).cornerRadius(1)

                    // Felder
                    VoiceInputField(
                        label: "Was geübt",
                        icon: "figure.golf",
                        color: ALColor.green,
                        text: $trained,
                        transcriber: transcriber,
                        activeField: "trained",
                        currentActiveField: $activeField
                    )

                    VoiceInputField(
                        label: "Korrekturen",
                        icon: "arrow.triangle.2.circlepath",
                        color: Color(hex: "1565C0"),
                        text: $corrections,
                        transcriber: transcriber,
                        activeField: "corrections",
                        currentActiveField: $activeField
                    )

                    VoiceInputField(
                        label: "Übungen",
                        icon: "repeat.circle.fill",
                        color: Color(hex: "4A148C"),
                        text: $exercises,
                        transcriber: transcriber,
                        activeField: "exercises",
                        currentActiveField: $activeField
                    )

                    VoiceInputField(
                        label: "Hausaufgaben / Nächste Stunde",
                        icon: "house.and.flag.fill",
                        color: ALColor.gold,
                        text: $homework,
                        transcriber: transcriber,
                        activeField: "homework",
                        currentActiveField: $activeField
                    )
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neue Lektion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        transcriber.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveSession(thenSend: false)
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if canSave && selectedStudentID != nil {
                    Button {
                        saveSession(thenSend: true)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                            Text("Speichern & an Schüler senden")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(ALColor.gold)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showStudentPicker) {
                studentPickerSheet
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .alert("Spracherkennung nicht verfügbar",
                   isPresented: $transcriber.permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Bitte erlaube Spracherkennung in den Einstellungen.")
            }
        }
        .presentationDetents([.large])
    }

    private func saveSession(thenSend: Bool) {
        transcriber.stop()
        var session = TrainingSession()
        session.studentID = selectedStudentID
        session.title = autoTitle
        session.trained = trained
        session.corrections = corrections
        session.exercises = exercises
        session.homework = homework
        store.addSession(session)
        if thenSend, let url = store.exportSession(session) {
            shareItems = [url]
            showShareSheet = true
        } else {
            dismiss()
        }
    }

    var studentPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedStudentID = nil
                        showStudentPicker = false
                    } label: {
                        HStack {
                            Image(systemName: "person.slash")
                                .foregroundStyle(.secondary)
                            Text("Kein Schüler")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedStudentID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ALColor.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section("Schüler") {
                    ForEach(store.students) { student in
                        Button {
                            selectedStudentID = student.id
                            showStudentPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: student.avatarColor))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(student.name.prefix(1)).uppercased())
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                    )
                                Text(student.name).foregroundStyle(.primary)
                                Spacer()
                                if selectedStudentID == student.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(ALColor.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Schüler auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showStudentPicker = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Session Detail Sheet

struct SessionDetailSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let session: TrainingSession

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var studentName: String? {
        guard let id = session.studentID else { return nil }
        return store.students.first(where: { $0.id == id })?.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 6) {
                        Text(session.title.isEmpty ? "Trainingsstunde" : session.title)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            if session.source == .received, !session.teacherName.isEmpty {
                                Label(session.teacherName, systemImage: "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let name = studentName {
                                Label(name, systemImage: "graduationcap.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Label(session.date.formatted(date: .abbreviated, time: .omitted),
                                  systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)

                    // Sections
                    if !session.trained.isEmpty {
                        sessionBlock(
                            icon: "figure.golf", color: ALColor.green,
                            label: "Was geübt", text: session.trained)
                    }
                    if !session.corrections.isEmpty {
                        sessionBlock(
                            icon: "arrow.triangle.2.circlepath", color: Color(hex: "1565C0"),
                            label: "Korrekturen", text: session.corrections)
                    }
                    if !session.exercises.isEmpty {
                        sessionBlock(
                            icon: "repeat.circle.fill", color: Color(hex: "4A148C"),
                            label: "Übungen", text: session.exercises)
                    }
                    if !session.homework.isEmpty {
                        sessionBlock(
                            icon: "house.and.flag.fill", color: ALColor.gold,
                            label: "Hausaufgaben", text: session.homework)
                    }

                    // Senden-Button (nur für Pros)
                    if session.source == .created {
                        Button {
                            if let url = store.exportSession(session) {
                                shareItems = [url]
                                showShareSheet = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "paperplane.fill")
                                Text("An Schüler senden")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(ALColor.gold)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trainingsprotokoll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    func sessionBlock(icon: String, color: Color, label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Students View

struct StudentsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddStudent = false
    @State private var selectedStudent: Student? = nil
    @State private var studentToEdit: Student? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.students.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(ALColor.green.opacity(0.4))
                        Text("Noch keine Schüler")
                            .font(.title3.bold())
                        Text("Tippe auf + um einen Schüler hinzuzufügen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(store.students) { student in
                            Button {
                                selectedStudent = student
                            } label: {
                                HStack(spacing: 14) {
                                    // Avatar mit Fortschritt-Ring
                                    let prog = store.progressFor(student)
                                    ZStack {
                                        // Fortschritt Ring
                                        if prog.total > 0 {
                                            Circle()
                                                .stroke(ALColor.green.opacity(0.15), lineWidth: 3)
                                                .frame(width: 50, height: 50)
                                            Circle()
                                                .trim(from: 0, to: CGFloat(prog.viewed) / CGFloat(prog.total))
                                                .stroke(ALColor.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                                .frame(width: 50, height: 50)
                                                .rotationEffect(.degrees(-90))
                                        }
                                        // Foto oder Initial
                                        if let filename = student.photoFilename,
                                           let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                                            Image(uiImage: img)
                                                .resizable().scaledToFill()
                                                .frame(width: 42, height: 42)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color(hex: student.avatarColor))
                                                .frame(width: 42, height: 42)
                                                .overlay(
                                                    Text(String(student.name.prefix(1)).uppercased())
                                                        .font(.headline.bold())
                                                        .foregroundStyle(.white)
                                                )
                                        }
                                    }
                                    .frame(width: 50, height: 50)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(student.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 8) {
                                            if !student.handicap.isEmpty {
                                                Text("HCP \(student.handicap)")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(ALColor.gold)
                                            }
                                            if prog.total > 0 {
                                                Text("\(prog.viewed)/\(prog.total) gesehen")
                                                    .font(.caption)
                                                    .foregroundStyle(prog.viewed == prog.total ? .green : ALColor.green)
                                            }
                                        }
                                        if let last = student.lastActiveDate {
                                            Text("Zuletzt: \(last.formatted(.relative(presentation: .named)))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button { studentToEdit = student } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(Color(hex: "1565C0"))
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { store.deleteStudent(store.students[$0]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Schüler")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddStudent = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddStudent) {
                StudentEditorSheet(existingStudent: nil)
            }
            .sheet(item: $studentToEdit) { student in
                StudentEditorSheet(existingStudent: student)
            }
            .sheet(item: $selectedStudent) { student in
                StudentDetailView(student: student)
            }
        }
    }
}

// MARK: - Student Editor Sheet

struct StudentEditorSheet: View {
    let existingStudent: Student?
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var handicap = ""
    @State private var birthday: Date = Date()
    @State private var hasBirthday = false
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoFilename: String? = nil
    @State private var avatarColor = "1B5E20"

    let colors = ["1B5E20","1565C0","4A148C","E65100","37474F","880E4F","006064","BF360C"]
    var isEditing: Bool { existingStudent != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Foto
                    VStack(spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let filename = photoFilename,
                                   let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color(hex: avatarColor))
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            Text(name.prefix(1).uppercased())
                                                .font(.system(size: 36, weight: .bold))
                                                .foregroundStyle(.white)
                                        )
                                }
                                ZStack {
                                    Circle().fill(ALColor.green).frame(width: 28, height: 28)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 4, y: 4)
                            }
                        }
                        .onChange(of: photoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    let filename = "student_\(existingStudent?.id.uuidString ?? UUID().uuidString).jpg"
                                    store.saveImage(data, filename: filename)
                                    photoFilename = filename
                                }
                            }
                        }
                        Text("Foto antippen").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Felder
                    VStack(spacing: 12) {
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal, 4)
                            TextField("Vorname Nachname", text: $name)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }

                        // Telefonnummer
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Telefon").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal, 4)
                            TextField("+41 79 000 00 00", text: $phone)
                                .keyboardType(.phonePad)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }

                        // Handicap
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Handicap").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal, 4)
                            TextField("z.B. 18.4", text: $handicap)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                        }

                        // Geburtstag
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Geburtstag").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal, 4)
                            Toggle("Geburtstag angeben", isOn: $hasBirthday)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            if hasBirthday {
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                            }
                        }

                        // Farbe
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Avatar-Farbe").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal, 4)
                            HStack(spacing: 10) {
                                ForEach(colors, id: \.self) { hex in
                                    Button { avatarColor = hex } label: {
                                        ZStack {
                                            Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                                            if avatarColor == hex {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Schüler bearbeiten" : "Neuer Schüler")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadExisting() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Speichern" : "Hinzufügen") { save() }
                        .bold()
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }

    func loadExisting() {
        guard let s = existingStudent else { return }
        name = s.name
        phone = s.phone
        handicap = s.handicap
        avatarColor = s.avatarColor
        photoFilename = s.photoFilename
        if let b = s.birthday { birthday = b; hasBirthday = true }
    }

    func save() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        if isEditing, var s = existingStudent {
            s.name = n
            s.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            s.handicap = handicap.trimmingCharacters(in: .whitespacesAndNewlines)
            s.birthday = hasBirthday ? birthday : nil
            s.avatarColor = avatarColor
            s.photoFilename = photoFilename
            store.updateStudent(s)
        } else {
            var s = Student(name: n)
            s.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            s.handicap = handicap.trimmingCharacters(in: .whitespacesAndNewlines)
            s.birthday = hasBirthday ? birthday : nil
            s.avatarColor = avatarColor
            s.photoFilename = photoFilename
            store.students.append(s)
        }
        dismiss()
    }
}

// MARK: - Student Detail View

struct StudentDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let student: Student
    @State private var tab: Int = 0
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showSendSheet = false
    @State private var photosItem: PhotosPickerItem? = nil

    var currentStudent: Student { store.currentStudent(student) ?? student }
    var assignedLessons: [Lesson]  { store.assignedLessonsFor(currentStudent) }
    var trainingSessions: [TrainingSession] { store.sessionsFor(currentStudent).sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Kartei Header ──
                karteiBanner
                    .background(Color(.systemBackground))

                Divider()

                // ── Segment ──
                Picker("", selection: $tab) {
                    Text("Kartei").tag(0)
                    Text("Lektionen").tag(1)
                    Text("Verlauf").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))

                Divider()

                // ── Tab Content ──
                Group {
                    if tab == 0 { karteiTab }
                    else if tab == 1 { lektionenTab }
                    else { verlaufTab }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(student.name)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .sheet(isPresented: $showSendSheet) {
                SendWithNoteSheet(student: currentStudent, lessons: assignedLessons) { items in
                    shareItems = items
                    showShareSheet = true
                }
            }
        }
    }

    // MARK: Banner

    var karteiBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Großer Avatar
                PhotosPicker(selection: $photosItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        let prog = store.progressFor(currentStudent)
                        if prog.total > 0 {
                            Circle().stroke(ALColor.green.opacity(0.15), lineWidth: 4).frame(width: 88, height: 88)
                            Circle()
                                .trim(from: 0, to: CGFloat(prog.viewed) / CGFloat(prog.total))
                                .stroke(ALColor.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 88, height: 88)
                                .rotationEffect(.degrees(-90))
                        }
                        if let filename = currentStudent.photoFilename,
                           let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 80, height: 80).clipShape(Circle())
                        } else {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: currentStudent.avatarColor), Color(hex: currentStudent.avatarColor).opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(student.name.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .bold, design: .serif))
                                        .foregroundStyle(.white)
                                )
                        }
                        ZStack {
                            Circle().fill(ALColor.green).frame(width: 24, height: 24)
                            Image(systemName: "camera.fill").font(.system(size: 11)).foregroundStyle(.white)
                        }
                        .offset(x: 4, y: 4)
                    }
                }
                .onChange(of: photosItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            let filename = "student_\(student.id.uuidString).jpg"
                            store.saveImage(data, filename: filename)
                            var updated = currentStudent
                            updated.photoFilename = filename
                            store.updateStudent(updated)
                        }
                    }
                }

                // Name + Infos
                VStack(alignment: .leading, spacing: 6) {
                    Text(student.name)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                    // Badges-Zeile
                    HStack(spacing: 8) {
                        if !currentStudent.handicap.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill").font(.system(size: 10))
                                Text("HCP \(currentStudent.handicap)").font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(ALColor.gold.opacity(0.15))
                            .foregroundStyle(ALColor.gold)
                            .clipShape(Capsule())
                        }
                        if let b = currentStudent.birthday {
                            HStack(spacing: 4) {
                                Image(systemName: "gift").font(.system(size: 10))
                                Text(b.formatted(.dateTime.day().month()))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                        }
                    }
                    // Stats
                    HStack(spacing: 12) {
                        statPill(icon: "rectangle.stack.fill", value: "\(assignedLessons.count)", label: "Lektionen", color: ALColor.green)
                        statPill(icon: "figure.golf",          value: "\(trainingSessions.count)", label: "Stunden",   color: Color(hex: "1565C0"))
                    }
                }

                Spacer()

                // Senden-Button
                if !assignedLessons.isEmpty {
                    Button { showSendSheet = true } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "paperplane.fill").font(.system(size: 17))
                            Text("Senden").font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 50)
                        .background(ALColor.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Fortschritts-Balken
            let prog = store.progressFor(currentStudent)
            if prog.total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Lernfortschritt").font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(prog.viewed)/\(prog.total) gesehen")
                            .font(.caption).foregroundStyle(prog.viewed == prog.total ? .green : .secondary)
                    }
                    ProgressView(value: Double(prog.viewed), total: Double(prog.total))
                        .tint(prog.viewed == prog.total ? .green : ALColor.green)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 4)
            }
        }
    }

    func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    // MARK: Tab 0 — Kartei (Persönliche Infos)

    var karteiTab: some View {
        List {
            // Kontakt
            Section {
                if !currentStudent.phone.isEmpty {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(ALColor.green.opacity(0.12)).frame(width: 34, height: 34)
                            Image(systemName: "phone.fill").font(.system(size: 14)).foregroundStyle(ALColor.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Telefon").font(.caption).foregroundStyle(.secondary)
                            Text(currentStudent.phone).font(.subheadline)
                        }
                        Spacer()
                        Button {
                            if let url = URL(string: "tel://\(currentStudent.phone.filter { $0.isNumber || $0 == "+" })") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "phone.arrow.up.right")
                                .font(.system(size: 16))
                                .foregroundStyle(ALColor.green)
                        }
                    }
                    .padding(.vertical, 2)
                }
                if let b = currentStudent.birthday {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(ALColor.gold.opacity(0.12)).frame(width: 34, height: 34)
                            Image(systemName: "gift.fill").font(.system(size: 14)).foregroundStyle(ALColor.gold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Geburtstag").font(.caption).foregroundStyle(.secondary)
                            Text(b.formatted(.dateTime.day().month().year())).font(.subheadline)
                        }
                    }
                    .padding(.vertical, 2)
                }
                if currentStudent.phone.isEmpty && currentStudent.birthday == nil {
                    Text("Keine Kontaktdaten eingetragen")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Label("Kontakt", systemImage: "person.text.rectangle")
            }

            // Pro-Notizen (nur Lehrer)
            if store.appMode == AppMode.teacher.rawValue {
                Section {
                    TextField("Private Beobachtungen, Technik-Hinweise…", text: Binding(
                        get: { currentStudent.notes },
                        set: { newVal in var u = currentStudent; u.notes = newVal; store.updateStudent(u) }
                    ), axis: .vertical)
                    .lineLimit(3...8)
                    .font(.subheadline)
                } header: {
                    Label("Pro-Notizen (nur für dich)", systemImage: "lock.fill")
                        .foregroundStyle(ALColor.green)
                }
            }

            // Schüler-Anmerkungen
            Section {
                TextField("Notizen des Schülers für den Pro…", text: Binding(
                    get: { currentStudent.remarks },
                    set: { newVal in var u = currentStudent; u.remarks = newVal; store.updateStudent(u) }
                ), axis: .vertical)
                .lineLimit(3...6)
                .font(.subheadline)
            } header: {
                Label("Anmerkungen des Schülers", systemImage: "text.bubble")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Tab 1 — Lektionen zuweisen

    var lektionenTab: some View {
        List {
            ForEach(store.folders) { folder in
                let folderLessons = store.lessonsIn(folder)
                if !folderLessons.isEmpty {
                    Section {
                        ForEach(folderLessons) { lesson in
                            let cs = currentStudent
                            let assigned = cs.assignedLessonIDs.contains(lesson.id)
                            let viewed   = cs.viewedLessonIDs.contains(lesson.id)
                            HStack(spacing: 12) {
                                Button { store.toggleLessonForStudent(lesson, student: student) } label: {
                                    Image(systemName: assigned ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(assigned ? ALColor.green : .secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lesson.title).foregroundStyle(.primary)
                                    if !lesson.description.isEmpty {
                                        Text(lesson.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                if assigned {
                                    Button { store.toggleLessonViewed(lesson, for: student) } label: {
                                        Image(systemName: viewed ? "eye.fill" : "eye")
                                            .foregroundStyle(viewed ? ALColor.gold : .secondary)
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } header: {
                        Label(folder.title, systemImage: folder.icon)
                            .foregroundStyle(Color(hex: folder.colorHex))
                    }
                }
            }
            if store.lessons.isEmpty {
                Section {
                    Text("Zuerst Vorlagen im Vorlagen-Tab anlegen")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Tab 2 — Verlauf (Sessions + Gesendet)

    var verlaufTab: some View {
        List {
            // Training Sessions
            Section {
                if trainingSessions.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.golf")
                            .font(.system(size: 28))
                            .foregroundStyle(ALColor.green.opacity(0.3))
                        Text("Noch keine Stunden dokumentiert")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(trainingSessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            // Datum + Titel
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(ALColor.green.opacity(0.12))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "figure.golf")
                                        .font(.system(size: 14))
                                        .foregroundStyle(ALColor.green)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(session.title.isEmpty ? "Trainingseinheit" : session.title)
                                        .font(.subheadline.bold())
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            // Inhalte als Chips
                            if !session.trained.isEmpty {
                                sessionChip(icon: "figure.walk", text: session.trained, color: ALColor.green)
                            }
                            if !session.corrections.isEmpty {
                                sessionChip(icon: "pencil.tip", text: session.corrections, color: Color(hex: "1565C0"))
                            }
                            if !session.exercises.isEmpty {
                                sessionChip(icon: "repeat", text: session.exercises, color: ALColor.gold)
                            }
                            if !session.homework.isEmpty {
                                sessionChip(icon: "house.fill", text: session.homework, color: Color(hex: "880E4F"))
                            }
                            if !session.imageFilenames.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.fill").font(.caption2).foregroundStyle(.secondary)
                                    Text("\(session.imageFilenames.count) Fotos")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Label("Dokumentierte Stunden (\(trainingSessions.count))", systemImage: "figure.golf")
                    .foregroundStyle(ALColor.green)
            }

            // Gesendet-Verlauf
            Section {
                if currentStudent.sentHistory.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "1565C0").opacity(0.3))
                        Text("Noch nichts gesendet")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(currentStudent.sentHistory) { pkg in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "1565C0").opacity(0.12))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: "1565C0"))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pkg.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.bold())
                                    Text("\(pkg.lessonTitles.count) Lektionen gesendet")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(pkg.lessonTitles, id: \.self) { title in
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2).fill(ALColor.green).frame(width: 3, height: 14)
                                    Text(title).font(.subheadline).foregroundStyle(.primary)
                                }
                            }
                            if !pkg.note.isEmpty {
                                Text("\u{201E}\(pkg.note)\u{201C}")
                                    .font(.caption).foregroundStyle(.secondary).italic()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Label("Gesendet (\(currentStudent.sentHistory.count))", systemImage: "paperplane.fill")
                    .foregroundStyle(Color(hex: "1565C0"))
            }
        }
        .listStyle(.insetGrouped)
    }

    func sessionChip(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.leading, 4)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showModeSwitch = false
    @State private var teacherPassword = ""
    @State private var wrongPassword = false

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var body: some View {
        NavigationStack {
            List {
                Section("Profil") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(ALColor.green)
                                .frame(width: 50, height: 50)
                            Text(store.teacherName.prefix(1))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.teacherName).font(.headline)
                            Text("Golf Pro").font(.caption).foregroundStyle(ALColor.gold)
                            Text("© AfterLesson").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Modus") {
                    HStack {
                        Image(systemName: isTeacher ? "person.badge.key.fill" : "graduationcap.fill")
                            .foregroundStyle(isTeacher ? ALColor.gold : ALColor.green)
                        Text(isTeacher ? "Lehrer-Modus" : "Schüler-Modus")
                        Spacer()
                        Button("Wechseln") {
                            if isTeacher {
                                store.appMode = AppMode.student.rawValue
                            } else {
                                showModeSwitch = true
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                }

                Section("App") {
                    Label("Version 1.0", systemImage: "app.badge")
                    Label("AfterLesson", systemImage: "figure.golf")
                    Label("2026 Thomas Kubernat", systemImage: "person.fill")
                }
            }
            .navigationTitle("Einstellungen")
            .alert("Lehrer-Modus", isPresented: $showModeSwitch) {
                SecureField("Passwort", text: $teacherPassword)
                Button("Entsperren") {
                    if teacherPassword == "golf" { // Später: echtes Passwort
                        store.appMode = AppMode.teacher.rawValue
                    } else {
                        wrongPassword = true
                    }
                    teacherPassword = ""
                }
                Button("Abbrechen", role: .cancel) { teacherPassword = "" }
            } message: {
                Text(wrongPassword ? "Falsches Passwort" : "Passwort eingeben")
            }
        }
    }
}


// MARK: - Lesson Editor

struct LessonEditorView: View {
    let folderID: UUID
    let existingLesson: Lesson?
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedIcon: String = "figure.golf"
    @State private var tips: [String] = []
    @State private var newTip: String = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var imageFilenames: [String] = []
    @State private var isAddingPhotos = false
    @State private var previewIndex: Int? = nil
    @State private var contentItemIDs: [UUID] = []
    @State private var showPoolPicker = false
    @FocusState private var focusedField: Field?

    enum Field { case title, description, tip }

    let lessonIcons = [
        "figure.golf", "figure.walk", "figure.stand", "figure.archery",
        "sportscourt.fill", "trophy.fill", "flag.fill", "star.fill",
        "bolt.fill", "arrow.up.right", "rotate.3d", "scope",
        "eye.fill", "brain.head.profile", "checkmark.seal.fill", "target",
        "timer", "repeat", "slider.horizontal.3", "waveform.path.ecg",
        "sun.max.fill", "wind", "leaf.fill", "mountain.2.fill"
    ]

    var isEditing: Bool { existingLesson != nil }
    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Datenpool-Inhalte in der Reihenfolge der Auswahl, für die Vorschau im Editor.
    var poolContentItems: [ContentItem] {
        let lookup = Dictionary(uniqueKeysWithValues: store.contentPool.map { ($0.id, $0) })
        return contentItemIDs.compactMap { lookup[$0] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // ── Titel ──
                    editorCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Titel", systemImage: "text.cursor")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("z.B. Drive-Technik Basics", text: $title)
                                .font(.title3.bold())
                                .focused($focusedField, equals: .title)
                        }
                    }

                    // ── Icon ──
                    editorCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Icon", systemImage: selectedIcon)
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(ALColor.green)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: selectedIcon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                ForEach(lessonIcons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? ALColor.green : Color(.tertiarySystemFill))
                                                .frame(height: 40)
                                            Image(systemName: icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // ── Beschreibung ──
                    editorCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Beschreibung", systemImage: "text.alignleft")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("Erkläre die Übung in eigenen Worten…", text: $description, axis: .vertical)
                                .lineLimit(4...10)
                                .focused($focusedField, equals: .description)
                        }
                    }

                    // ── Fotos ──
                    editorCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Fotos", systemImage: "photo.on.rectangle")
                                .font(.caption.bold()).foregroundStyle(.secondary)

                            if !imageFilenames.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(imageFilenames.enumerated()), id: \.element) { idx, filename in
                                            if let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                                                ZStack(alignment: .topTrailing) {
                                                    Image(uiImage: img)
                                                        .resizable().scaledToFill()
                                                        .frame(width: 120, height: 90)
                                                        .clipped()
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                        .onTapGesture { previewIndex = idx }

                                                    Button {
                                                        try? FileManager.default.removeItem(at: store.imageURL(for: filename))
                                                        imageFilenames.remove(at: idx)
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.title3)
                                                            .foregroundStyle(.white)
                                                            .background(Color.black.opacity(0.5).clipShape(Circle()))
                                                    }
                                                    .padding(4)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            PhotosPicker(
                                selection: $photoItems,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                    Text(imageFilenames.isEmpty ? "Fotos hinzufügen" : "Weitere Fotos")
                                }
                                .font(.subheadline)
                                .foregroundStyle(ALColor.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(ALColor.green.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ALColor.green.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                )
                            }
                            .onChange(of: photoItems) { _, newItems in
                                guard !newItems.isEmpty else { return }
                                isAddingPhotos = true
                                Task {
                                    for item in newItems {
                                        if let data = try? await item.loadTransferable(type: Data.self) {
                                            let filename = "lesson_\(folderID.uuidString)_\(UUID().uuidString).jpg"
                                            store.saveImage(data, filename: filename)
                                            imageFilenames.append(filename)
                                        }
                                    }
                                    photoItems = []
                                    isAddingPhotos = false
                                }
                            }
                        }
                    }

                    // ── Inhalte aus dem Datenpool ──
                    editorCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Inhalte aus dem Datenpool", systemImage: "square.grid.2x2.fill")
                                .font(.caption.bold()).foregroundStyle(.secondary)

                            if poolContentItems.isEmpty {
                                Text("Stelle diese Lektion aus Bildern, Videos, PDFs oder Audio zusammen, die du bereits in deinem Datenpool gesammelt hast.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(poolContentItems) { item in
                                            ZStack(alignment: .topTrailing) {
                                                PoolItemThumb(item: item)
                                                Button {
                                                    contentItemIDs.removeAll { $0 == item.id }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(.white)
                                                        .background(Color.black.opacity(0.5).clipShape(Circle()))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                }
                            }

                            Button { showPoolPicker = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "tray.full.fill")
                                    Text(poolContentItems.isEmpty ? "Aus Datenpool auswählen" : "Auswahl bearbeiten")
                                }
                                .font(.subheadline)
                                .foregroundStyle(ALColor.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(ALColor.green.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ALColor.green.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                )
                            }
                        }
                    }

                    // ── Profi-Tipps ──
                    editorCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Profi-Tipps", systemImage: "lightbulb.fill")
                                .font(.caption.bold()).foregroundStyle(.secondary)

                            ForEach(Array(tips.enumerated()), id: \.offset) { idx, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ALColor.gold)
                                    Text(tip).font(.subheadline)
                                    Spacer()
                                    Button {
                                        tips.remove(at: idx)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                TextField("Neuer Tipp…", text: $newTip)
                                    .focused($focusedField, equals: .tip)
                                    .onSubmit { addTip() }
                                Button(action: addTip) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(newTip.isEmpty ? .secondary : ALColor.gold)
                                        .font(.title3)
                                }
                                .disabled(newTip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Lektion bearbeiten" : "Neue Lektion")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadExisting() }
            .overlay {
                if isAddingPhotos {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white).scaleEffect(1.4)
                            Text("Fotos werden gespeichert…")
                                .font(.subheadline).foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .sheet(item: Binding(
                get: { previewIndex.map { ImagePreviewItem(index: $0) } },
                set: { previewIndex = $0?.index }
            )) { item in
                ImagePreviewView(filenames: imageFilenames, startIndex: item.index, isTeacher: true) { filename in
                    if let idx = imageFilenames.firstIndex(of: filename) {
                        try? FileManager.default.removeItem(at: store.imageURL(for: filename))
                        imageFilenames.remove(at: idx)
                    }
                    previewIndex = nil
                }
            }
            .sheet(isPresented: $showPoolPicker) {
                ContentPoolPickerView(initialSelection: contentItemIDs) { newSelection in
                    contentItemIDs = newSelection
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        // Neu erstellte Fotos aufräumen wenn abgebrochen
                        if existingLesson == nil {
                            for f in imageFilenames {
                                try? FileManager.default.removeItem(at: store.imageURL(for: f))
                            }
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        save()
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Helpers

    @ViewBuilder
    func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func addTip() {
        let t = newTip.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { tips.append(t) }
        newTip = ""
    }

    func loadExisting() {
        guard let l = existingLesson else { return }
        title = l.title
        description = l.description
        selectedIcon = l.icon
        tips = l.tips
        imageFilenames = l.imageFilenames
        contentItemIDs = l.contentItemIDs
    }

    func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        if var lesson = existingLesson {
            lesson.title = t
            lesson.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            lesson.icon = selectedIcon
            lesson.tips = tips
            lesson.imageFilenames = imageFilenames
            lesson.contentItemIDs = contentItemIDs
            store.updateLesson(lesson)
        } else {
            var lesson = Lesson(folderID: folderID, title: t)
            lesson.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            lesson.icon = selectedIcon
            lesson.tips = tips
            lesson.imageFilenames = imageFilenames
            lesson.contentItemIDs = contentItemIDs
            store.lessons.append(lesson)
        }
        dismiss()
    }
}

// MARK: - Pool Item Thumb (kompakte Vorschau in Auswahl-Listen)

struct PoolItemThumb: View {
    let item: ContentItem
    @EnvironmentObject var store: AppStore

    var typeColor: Color { Color(hex: item.type.colorHex) }

    var thumbImage: UIImage? {
        if item.type == .image {
            return UIImage(contentsOfFile: store.imageURL(for: item.filename).path)
        }
        if let thumb = item.thumbnailFilename {
            return UIImage(contentsOfFile: store.imageURL(for: thumb).path)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let img = thumbImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Rectangle().fill(typeColor.opacity(0.12))
                    Image(systemName: item.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(typeColor)
                }
            }
            .frame(width: 92, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.title)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 92)
        }
    }
}

// MARK: - Datenpool-Auswahl (Lektionen aus Pool-Inhalten zusammenstellen)

struct ContentPoolPickerView: View {
    let initialSelection: [UUID]
    let onDone: ([UUID]) -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var selection: [UUID] = []
    @State private var filterType: ContentType? = nil

    var filteredItems: [ContentItem] {
        guard let filterType else { return store.contentPool }
        return store.contentPool.filter { $0.type == filterType }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.contentPool.isEmpty {
                    ContentUnavailableView("Datenpool ist leer", systemImage: "tray",
                                           description: Text("Importiere zuerst Inhalte im Datenpool-Tab — danach kannst du sie hier für Lektionen auswählen."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            filterBar
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(filteredItems) { item in
                                    Button { toggle(item) } label: {
                                        ZStack(alignment: .topLeading) {
                                            ContentItemTile(item: item)
                                            selectionBadge(isSelected: selection.contains(item.id))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Inhalte auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selection.isEmpty ? "Übernehmen" : "Übernehmen (\(selection.count))") {
                        onDone(selection)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear { selection = initialSelection }
        .presentationDetents([.large])
    }

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "Alle")
                ForEach(ContentType.allCases, id: \.self) { type in
                    filterChip(type, label: type.label)
                }
            }
        }
    }

    func filterChip(_ type: ContentType?, label: String) -> some View {
        let isSelected = filterType == type
        let color = type.map { Color(hex: $0.colorHex) } ?? ALColor.green
        return Button {
            filterType = type
        } label: {
            HStack(spacing: 6) {
                if let type {
                    Image(systemName: type.icon).font(.caption2)
                }
                Text(label).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    func selectionBadge(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? ALColor.green : Color.black.opacity(0.25))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(8)
    }

    func toggle(_ item: ContentItem) {
        if let idx = selection.firstIndex(of: item.id) {
            selection.remove(at: idx)
        } else {
            selection.append(item.id)
        }
    }
}

// MARK: - Image Preview

struct ImagePreviewItem: Identifiable {
    let id = UUID()
    let index: Int
}

struct ImagePreviewView: View {
    @Environment(\.dismiss) var dismiss
    let filenames: [String]
    let startIndex: Int
    let isTeacher: Bool
    let onDelete: (String) -> Void

    @State private var currentIndex: Int
    @EnvironmentObject var store: AppStore

    init(filenames: [String], startIndex: Int, isTeacher: Bool, onDelete: @escaping (String) -> Void) {
        self.filenames = filenames
        self.startIndex = startIndex
        self.isTeacher = isTeacher
        self.onDelete = onDelete
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(filenames.enumerated()), id: \.element) { idx, filename in
                    Group {
                        if let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)
                        } else {
                            Color.black
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page)
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("\(currentIndex + 1) / \(filenames.count)")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                if isTeacher {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            let filename = filenames[currentIndex]
                            onDelete(filename)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Send With Note Sheet

struct SendWithNoteSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let student: Student
    let lessons: [Lesson]
    let onSend: ([Any]) -> Void

    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        if let filename = student.photoFilename,
                           let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(hex: student.avatarColor))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(student.name.prefix(1)).uppercased())
                                        .font(.headline.bold()).foregroundStyle(.white)
                                )
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(student.name).font(.headline)
                            Text(Date().formatted(date: .long, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: { Text("An") }

                Section {
                    TextField("z.B. Übe täglich 10 Minuten auf dem Chip...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: { Text("Persönliche Notiz (optional)") }

                Section {
                    ForEach(lessons) { lesson in
                        Label(lesson.title, systemImage: "book.fill")
                            .font(.subheadline)
                    }
                } header: {
                    Text("\(lessons.count) Lektionen")
                }
            }
            .navigationTitle("Senden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        var items: [Any] = []
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let dateStr = Date().formatted(date: .long, time: .omitted)
                            items.append("AfterLesson · \(student.name) · \(dateStr)\n\n\(trimmed)")
                        }
                        items += lessons.compactMap { store.exportLesson($0) }
                        store.recordSent(to: student, lessons: lessons, note: trimmed)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onSend(items)
                        }
                    } label: {
                        Label("Senden", systemImage: "paperplane.fill")
                    }
                    .disabled(lessons.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Notes View

struct NotesView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddNote = false
    @State private var selectedNote: ProNote? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.proNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 60))
                            .foregroundStyle(Color(hex: "4A148C").opacity(0.3))
                        Text("Noch keine Notizen")
                            .font(.title3.bold())
                        Text("Halte Beobachtungen zu Schülern\noder Gruppen fest")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(store.proNotes) { note in
                            Button { selectedNote = note } label: {
                                NoteRowView(note: note)
                            }
                            .foregroundStyle(.primary)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteNote(note)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notizen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddNote = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showAddNote) {
                NoteEditorView(existingNote: nil)
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(existingNote: note)
            }
        }
    }
}

// MARK: - Note Row

struct NoteRowView: View {
    let note: ProNote
    @EnvironmentObject var store: AppStore

    var assignmentLabel: String? {
        if let sid = note.assignedStudentID,
           let s = store.students.first(where: { $0.id == sid }) {
            return s.name
        }
        if let gid = note.assignedGroupID,
           let g = store.groups.first(where: { $0.id == gid }) {
            return g.name
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: note.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: note.audioFilename != nil ? "mic.fill" : "note.text")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: note.colorHex))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Ohne Titel" : note.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if !note.text.isEmpty {
                    Text(note.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if let label = assignmentLabel {
                        Label(label, systemImage: note.assignedStudentID != nil ? "graduationcap.fill" : "person.3.sequence.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: note.colorHex))
                    }
                    Text(note.dateCreated.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Note Editor

struct NoteEditorView: View {
    let existingNote: ProNote?
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var text = ""
    @State private var selectedStudentID: UUID? = nil
    @State private var selectedGroupID: UUID? = nil
    @State private var assignmentMode: Int = 0   // 0=keine, 1=Schüler, 2=Gruppe

    // Audio Recording
    @State private var isRecording = false
    @State private var audioFilename: String? = nil
    @State private var recorder: AVAudioRecorder? = nil
    @State private var player: AVAudioPlayer? = nil
    @State private var isPlaying = false

    var isEditing: Bool { existingNote != nil }
    var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty || !text.trimmingCharacters(in: .whitespaces).isEmpty || audioFilename != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Titel
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Titel").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Kurze Beschreibung…", text: $title)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notiz").font(.caption.bold()).foregroundStyle(.secondary)
                        TextEditor(text: $text)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Sprachaufnahme
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sprachnotiz").font(.caption.bold()).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            // Aufnahme Button
                            Button {
                                isRecording ? stopRecording() : startRecording()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isRecording ? .red : Color(hex: "4A148C"))
                                    Text(isRecording ? "Aufnahme stoppen" : (audioFilename != nil ? "Neu aufnehmen" : "Aufnehmen"))
                                        .font(.subheadline)
                                        .foregroundStyle(isRecording ? .red : Color(hex: "4A148C"))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color(hex: "4A148C").opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            // Abspielen Button (wenn Aufnahme vorhanden)
                            if audioFilename != nil {
                                Button {
                                    isPlaying ? stopPlayback() : startPlayback()
                                } label: {
                                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(ALColor.green)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if audioFilename != nil {
                            Label("Sprachnotiz vorhanden", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(ALColor.green)
                        }
                    }

                    // Zuweisung
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Zuweisen an").font(.caption.bold()).foregroundStyle(.secondary)
                        Picker("", selection: $assignmentMode) {
                            Text("Keine").tag(0)
                            Text("Schüler").tag(1)
                            Text("Gruppe").tag(2)
                        }
                        .pickerStyle(.segmented)

                        if assignmentMode == 1 {
                            if store.students.isEmpty {
                                Text("Noch keine Schüler erfasst")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(store.students) { student in
                                            Button {
                                                selectedStudentID = selectedStudentID == student.id ? nil : student.id
                                            } label: {
                                                Text(student.name)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(selectedStudentID == student.id ? Color(hex: "1565C0") : Color(.secondarySystemGroupedBackground))
                                                    .foregroundStyle(selectedStudentID == student.id ? .white : .primary)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        if assignmentMode == 2 {
                            if store.groups.isEmpty {
                                Text("Noch keine Gruppen erfasst")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(store.groups) { group in
                                            Button {
                                                selectedGroupID = selectedGroupID == group.id ? nil : group.id
                                            } label: {
                                                Text(group.name)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(selectedGroupID == group.id ? Color(hex: group.colorHex) : Color(.secondarySystemGroupedBackground))
                                                    .foregroundStyle(selectedGroupID == group.id ? .white : .primary)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Notiz bearbeiten" : "Neue Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadExisting() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        saveNote()
                        dismiss()
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadExisting() {
        guard let n = existingNote else { return }
        title = n.title
        text = n.text
        audioFilename = n.audioFilename
        if let sid = n.assignedStudentID { selectedStudentID = sid; assignmentMode = 1 }
        else if let gid = n.assignedGroupID { selectedGroupID = gid; assignmentMode = 2 }
    }

    private func saveNote() {
        let sid = assignmentMode == 1 ? selectedStudentID : nil
        let gid = assignmentMode == 2 ? selectedGroupID : nil
        if isEditing, var n = existingNote {
            n.title = title
            n.text = text
            n.audioFilename = audioFilename
            n.assignedStudentID = sid
            n.assignedGroupID = gid
            store.updateNote(n)
        } else {
            store.addNote(title: title, text: text, audioFilename: audioFilename,
                          studentID: sid, groupID: gid)
        }
    }

    private func startRecording() {
        let filename = "note_\(UUID().uuidString).m4a"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        AVAudioApplication.requestRecordPermission { granted in
            guard granted else { return }
            DispatchQueue.main.async {
                try? AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                if let rec = try? AVAudioRecorder(url: url, settings: settings) {
                    self.recorder = rec
                    rec.record()
                    self.isRecording = true
                    self.audioFilename = filename
                }
            }
        }
    }

    private func stopRecording() {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
    }

    private func startPlayback() {
        guard let filename = audioFilename else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let p = try? AVAudioPlayer(contentsOf: url) {
            player = p
            p.play()
            isPlaying = true
        }
    }

    private func stopPlayback() {
        player?.stop()
        isPlaying = false
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView().environmentObject(AppStore())
}
