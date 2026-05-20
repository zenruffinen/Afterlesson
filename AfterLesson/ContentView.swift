import SwiftUI
import PhotosUI

// MARK: - App Entry

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab: Tab = .home

    enum Tab { case home, lessons, groups, students, settings }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:     HomeView(selectedTab: $selectedTab)
                case .lessons:  FoldersView()
                case .groups:   GruppenView()
                case .students: StudentsView()
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

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home,     icon: "house.fill",           label: "Start",         color: ALColor.green)
            tabItem(.lessons,  icon: "rectangle.stack.fill", label: "Vorlagen",      color: ALColor.green)
            tabItem(.groups,   icon: "person.3.sequence.fill",label: "Klassen",      color: ALColor.gold)
            tabItem(.students, icon: "graduationcap.fill",    label: "Schüler",      color: Color(hex: "1565C0"))
            tabItem(.settings, icon: "gearshape.fill",        label: "Einstellungen",color: .gray)
        }
        .padding(.bottom, 28)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    func tabItem(_ tab: ContentView.Tab, icon: String, label: String, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = tab
            }
        } label: {
            let isSelected = selected == tab
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(color.opacity(isSelected ? 1.0 : 0.4))
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(color.opacity(isSelected ? 1.0 : 0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 24, height: 3)
                    .opacity(isSelected ? 1 : 0)
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
    static let green    = Color(red: 0.11, green: 0.37, blue: 0.16)   // Dunkelgrün
    static let gold     = Color(red: 0.72, green: 0.57, blue: 0.22)   // Golf-Gold
    static let dark     = Color(red: 0.10, green: 0.12, blue: 0.10)   // Fast Schwarz
    static let fairway  = Color(red: 0.17, green: 0.50, blue: 0.22)   // Fairway-Grün
    static let sand     = Color(red: 0.93, green: 0.87, blue: 0.70)   // Bunker-Sand
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedTab: ContentView.Tab
    @State private var showTeacherDashboard = false

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Hero Banner
                    heroBanner

                    // Schnellzugriff
                    quickAccess
                        .padding(.top, 8)

                    // Pro Studio Button
                    modeBanner
                        .padding(.top, 16)
                        .padding(.horizontal, 4)
                        .shadow(color: ALColor.dark.opacity(0.3), radius: 20, x: 0, y: 10)

                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }

    // MARK: Hero
    var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [ALColor.dark, ALColor.green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 110)

            // Dekoratives Golf-Element (rechts, hinter allem)
            Image(systemName: "figure.golf")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .allowsHitTesting(false)

            // Text links unten
            VStack(alignment: .leading, spacing: 4) {
                Text("AfterLesson")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(store.teacherName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Golf Pro")
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: "C9A84C"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "C9A84C").opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: Mode Banner (Pro Studio Button)
    var modeBanner: some View {
        Button {
            if isTeacher { showTeacherDashboard = true }
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ALColor.green)
                        .frame(width: 52, height: 52)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pro Studio")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(store.folders.count) Vorlagen · \(store.lessons.count) \(store.lessons.count == 1 ? "Lektion" : "Lektionen")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTeacherDashboard) {
            TeacherDashboardView()
        }
    }

    // MARK: Quick Access
    var quickAccess: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [ALColor.green, ALColor.gold, ALColor.green.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .cornerRadius(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickTile(icon: "book.fill", title: "Lektionsvorlagen",
                          subtitle: "\(store.lessons.count) \(store.lessons.count == 1 ? "Lektion" : "Lektionen")",
                          color: ALColor.green) {
                    selectedTab = .lessons
                }
                QuickTile(icon: "person.2.fill", title: "Schüler",
                          subtitle: "\(store.students.count) gespeichert",
                          color: Color(hex: "1565C0")) {
                    selectedTab = .students
                }
                QuickTile(icon: "bookmark.fill", title: "Erinnerung",
                          subtitle: "\(store.lessons.filter(\.isFavorite).count) gespeichert",
                          color: ALColor.gold) {
                    selectedTab = .lessons
                }
                QuickTile(icon: "chart.bar.fill", title: "Fortschritt",
                          subtitle: "\(store.progress.filter(\.isCompleted).count) erledigt",
                          color: .purple) {
                    selectedTab = .groups
                }
            }
        }
    }

    // MARK: Recent Lessons
    var recentLessons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zuletzt hinzugefügt")
                .font(.headline)
            ForEach(store.lessons.sorted { $0.dateCreated > $1.dateCreated }.prefix(3)) { lesson in
                LessonRowView(lesson: lesson)
            }
        }
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

    var firstImage: UIImage? {
        guard let first = lesson.imageFilenames.first else { return nil }
        return UIImage(contentsOfFile: store.imageURL(for: first).path)
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

                    // Bilder-Anzahl Badge
                    if lesson.imageFilenames.count > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.caption2)
                            Text("\(lesson.imageFilenames.count)")
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
                            .offset(x: 0, y: lesson.imageFilenames.count > 1 ? 28 : 0)
                    }
                }

                // Titel & Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)

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

    init(lesson: Lesson, onEdit: (() -> Void)? = nil) {
        self.lesson = lesson
        self.onEdit = onEdit
        _currentLesson = State(initialValue: lesson)
    }

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }
    var isCompleted: Bool { store.isCompleted(lesson.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Bilder Galerie (immer zeigen wenn Lehrer, auch leer für Add-Button)
                    if isTeacher || !currentLesson.imageFilenames.isEmpty {
                        imageGallery
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

    var body: some View {
        HStack(spacing: 12) {
            if let first = lesson.imageFilenames.first,
               let img = UIImage(contentsOfFile: store.imageURL(for: first).path) {
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
                Text("\(lesson.steps.count) Schritte · \(lesson.tips.count) Tipps")
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.12, blue: 0.10), ALColor.green],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
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

                // Buttons
                VStack(spacing: 16) {
                    // Lehrer
                    Button {
                        store.appMode = AppMode.teacher.rawValue
                        hasSelectedMode = true
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(ALColor.gold).frame(width: 56, height: 56)
                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ich bin Lehrer")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                Text("Vorlagen erstellen & Schüler verwalten")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(ALColor.gold)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(ALColor.gold.opacity(0.5), lineWidth: 1.5)
                                )
                        )
                    }
                    .padding(.horizontal, 24)

                    // Schüler
                    Button {
                        store.appMode = AppMode.student.rawValue
                        hasSelectedMode = true
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
                                Text("Meine Vorlagen ansehen & lernen")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(ALColor.green)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(ALColor.green.opacity(0.5), lineWidth: 1.5)
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                Text("Thomas Kubernat · AfterLesson")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 20)
            }
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
                            Section("Klassen") {
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
            Text("Noch keine Schüler oder Klassen")
                .font(.title3.bold())
            Text("Lege zuerst Schüler oder Klassen im jeweiligen Tab an")
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

// MARK: - Gruppen View

struct GruppenView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var newGroupIcon = "person.3.fill"
    @State private var selectedGroup: TeachingGroup? = nil
    @State private var groupToEdit: TeachingGroup? = nil

    let groupIcons = [
        "person.3.fill", "person.2.fill", "figure.golf", "graduationcap.fill",
        "trophy.fill", "flag.fill", "star.fill", "clock.fill",
        "calendar", "mappin.fill", "leaf.fill", "sportscourt.fill",
        "figure.walk", "sun.max.fill", "moon.fill", "bolt.fill"
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(ALColor.gold.opacity(0.4))
                        Text("Noch keine Klassen")
                            .font(.title3.bold())
                        Text("Tippe auf + um eine Klasse anzulegen")
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
                            Button { selectedGroup = group } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(hex: group.colorHex))
                                            .frame(width: 46, height: 46)
                                        Image(systemName: group.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.name).font(.headline).foregroundStyle(.primary)
                                        HStack(spacing: 8) {
                                            Label("\(store.studentsIn(group).count) Schüler",
                                                  systemImage: "person.2")
                                            Label("\(store.lessonsIn(group).count) Lektionen",
                                                  systemImage: "book")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    groupToEdit = group
                                } label: {
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
            .navigationTitle("Klassen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddGroup = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddGroup) {
                addGroupSheet
            }
            .sheet(item: $groupToEdit) { group in
                EditGroupSheet(group: group)
            }
            .sheet(item: $selectedGroup) { group in
                GruppeDetailView(group: group)
            }
        }
    }

    var addGroupSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name der Klasse")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        TextField("z.B. Anfänger Dienstag", text: $newGroupName)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }

                    // Icon picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(groupIcons, id: \.self) { icon in
                                Button {
                                    newGroupIcon = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(newGroupIcon == icon
                                                  ? ALColor.gold
                                                  : Color(.secondarySystemGroupedBackground))
                                            .frame(height: 64)
                                        Image(systemName: icon)
                                            .font(.system(size: 26))
                                            .foregroundStyle(newGroupIcon == icon ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neue Klasse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        newGroupName = ""
                        newGroupIcon = "person.3.fill"
                        showAddGroup = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty { store.addGroup(name: name, icon: newGroupIcon) }
                        newGroupName = ""
                        newGroupIcon = "person.3.fill"
                        showAddGroup = false
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Edit Group Sheet

struct EditGroupSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let group: TeachingGroup
    @State private var editName: String = ""
    @State private var editIcon: String = "person.3.fill"

    let groupIcons = [
        "person.3.fill", "person.2.fill", "figure.golf", "graduationcap.fill",
        "trophy.fill", "flag.fill", "star.fill", "clock.fill",
        "calendar", "mappin.fill", "leaf.fill", "sportscourt.fill",
        "figure.walk", "sun.max.fill", "moon.fill", "bolt.fill"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name der Klasse")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        TextField("Name", text: $editName)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }

                    // Icon picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(groupIcons, id: \.self) { icon in
                                Button {
                                    editIcon = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(editIcon == icon
                                                  ? ALColor.gold
                                                  : Color(.secondarySystemGroupedBackground))
                                            .frame(height: 64)
                                        Image(systemName: icon)
                                            .font(.system(size: 26))
                                            .foregroundStyle(editIcon == icon ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Klasse bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                editName = group.name
                editIcon = group.icon
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            var updated = group
                            updated.name = name
                            updated.icon = editIcon
                            store.updateGroup(updated)
                        }
                        dismiss()
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Gruppe Detail View

struct GruppeDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let group: TeachingGroup
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var tab: Int = 0

    var currentGroup: TeachingGroup {
        store.groups.first(where: { $0.id == group.id }) ?? group
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment
                Picker("", selection: $tab) {
                    Text("Schüler").tag(0)
                    Text("Lektionen").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(16)

                if tab == 0 {
                    // Schüler zuweisen
                    List {
                        Section("Schüler auswählen") {
                            if store.students.isEmpty {
                                Text("Zuerst Schüler im Schüler-Tab anlegen")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(store.students) { student in
                                let inGroup = currentGroup.studentIDs.contains(student.id)
                                Button {
                                    store.toggleStudent(student, in: currentGroup)
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
                                        Image(systemName: inGroup ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(inGroup ? ALColor.green : .secondary)
                                            .font(.title3)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    // Lektionen zuweisen
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
                                            HStack {
                                                Image(systemName: inGroup ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(inGroup ? ALColor.green : .secondary)
                                                    .font(.title3)
                                                Text(lesson.title).foregroundStyle(.primary)
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
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
            }
            .navigationTitle(currentGroup.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !store.lessonsIn(currentGroup).isEmpty {
                        Button {
                            shareItems = store.exportGroup(currentGroup)
                            if !shareItems.isEmpty { showShareSheet = true }
                        } label: {
                            Label("Senden", systemImage: "paperplane.fill")
                                .foregroundStyle(ALColor.gold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
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
            s.handicap = handicap.trimmingCharacters(in: .whitespacesAndNewlines)
            s.birthday = hasBirthday ? birthday : nil
            s.avatarColor = avatarColor
            s.photoFilename = photoFilename
            store.updateStudent(s)
        } else {
            var s = Student(name: n)
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

    var assignedLessons: [Lesson] {
        store.assignedLessonsFor(currentStudent)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Profil Header ──
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        // Foto / Avatar — tippbar für PhotosPicker
                        PhotosPicker(selection: $photosItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let filename = currentStudent.photoFilename,
                                   let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color(hex: student.avatarColor))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Text(String(student.name.prefix(1)).uppercased())
                                                .font(.title.bold()).foregroundStyle(.white)
                                        )
                                }
                                // Kamera-Badge
                                ZStack {
                                    Circle().fill(ALColor.green).frame(width: 22, height: 22)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
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

                        VStack(alignment: .leading, spacing: 4) {
                            Text(student.name).font(.title3.bold())
                            HStack(spacing: 10) {
                                if !currentStudent.handicap.isEmpty {
                                    Label("HCP \(currentStudent.handicap)", systemImage: "flag.fill")
                                        .font(.caption).foregroundStyle(ALColor.gold)
                                }
                                if let b = currentStudent.birthday {
                                    Label(b.formatted(.dateTime.day().month().year()), systemImage: "gift")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("\(assignedLessons.count) Lektionen zugewiesen")
                                .font(.caption).foregroundStyle(.secondary)
                            if let last = currentStudent.lastActiveDate {
                                Label("Zuletzt: \(last.formatted(.relative(presentation: .named)))",
                                      systemImage: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Senden Button
                        if !assignedLessons.isEmpty {
                            Button { showSendSheet = true } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 18))
                                    Text("Senden")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 52)
                                .background(ALColor.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)

                    // Fortschritts-Balken
                    let prog = store.progressFor(currentStudent)
                    if prog.total > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Fortschritt")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(prog.viewed) von \(prog.total) gesehen")
                                    .font(.caption)
                                    .foregroundStyle(prog.viewed == prog.total ? .green : .secondary)
                            }
                            ProgressView(value: Double(prog.viewed), total: Double(prog.total))
                                .tint(prog.viewed == prog.total ? .green : ALColor.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                .background(Color(.systemBackground))

                Divider()

                // Segment: Lektionen | Klassen | Verlauf
                Picker("", selection: $tab) {
                    Text("Lektionen").tag(0)
                    Text("Klassen").tag(1)
                    Text("Verlauf").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(12)

                if tab == 0 {
                    // Lektionen zuweisen + als gesehen markieren
                    List {
                        ForEach(store.folders) { folder in
                            let folderLessons = store.lessonsIn(folder)
                            if !folderLessons.isEmpty {
                                Section {
                                    ForEach(folderLessons) { lesson in
                                        let cs = currentStudent
                                        let assigned = cs.assignedLessonIDs.contains(lesson.id)
                                        let viewed  = cs.viewedLessonIDs.contains(lesson.id)
                                        HStack(spacing: 12) {
                                            // Zuweisen Toggle
                                            Button {
                                                store.toggleLessonForStudent(lesson, student: student)
                                            } label: {
                                                Image(systemName: assigned ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(assigned ? ALColor.green : .secondary)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(lesson.title).foregroundStyle(.primary)
                                                if !lesson.description.isEmpty {
                                                    Text(lesson.description)
                                                        .font(.caption).foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()

                                            // Gesehen Toggle (nur wenn zugewiesen)
                                            if assigned {
                                                Button {
                                                    store.toggleLessonViewed(lesson, for: student)
                                                } label: {
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

                } else if tab == 1 {
                    // Klassen anzeigen
                    List {
                        let studentClasses = store.groups.filter { $0.studentIDs.contains(student.id) }
                        if studentClasses.isEmpty {
                            Section {
                                Text("Noch keiner Klasse zugeordnet")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(studentClasses) { group in
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: group.colorHex))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: group.icon)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name).font(.subheadline.bold())
                                        Text("\(store.lessonsIn(group).count) Lektionen")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

                } else {
                    // Verlauf + Anmerkungen
                    List {
                        // Pro-Notizen (nur für Lehrer sichtbar)
                        if store.appMode == AppMode.teacher.rawValue {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Pro-Notizen (nur für dich)", systemImage: "lock.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(ALColor.green)
                                    TextField("Private Beobachtungen, Hinweise…", text: Binding(
                                        get: { currentStudent.notes },
                                        set: { newVal in
                                            var updated = currentStudent
                                            updated.notes = newVal
                                            store.updateStudent(updated)
                                        }
                                    ), axis: .vertical)
                                    .lineLimit(3...8)
                                    .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Anmerkungen des Schülers
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Anmerkungen des Schülers", systemImage: "text.bubble")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                TextField("Notizen vom Schüler für den Pro…", text: Binding(
                                    get: { currentStudent.remarks },
                                    set: { newVal in
                                        var updated = currentStudent
                                        updated.remarks = newVal
                                        store.updateStudent(updated)
                                    }
                                ), axis: .vertical)
                                .lineLimit(3...6)
                                .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }

                        // Gesendet-Verlauf
                        Section("Gesendet") {
                            if currentStudent.sentHistory.isEmpty {
                                Text("Noch nichts gesendet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(currentStudent.sentHistory) { pkg in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "paperplane.fill")
                                                .font(.caption)
                                                .foregroundStyle(ALColor.green)
                                            Text(pkg.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                        }
                                        ForEach(pkg.lessonTitles, id: \.self) { title in
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(ALColor.green)
                                                    .frame(width: 5, height: 5)
                                                Text(title)
                                                    .font(.subheadline)
                                            }
                                        }
                                        if !pkg.note.isEmpty {
                                            Text("\"\(pkg.note)\"")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .italic()
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(student.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            store.updateLesson(lesson)
        } else {
            var lesson = Lesson(folderID: folderID, title: t)
            lesson.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            lesson.icon = selectedIcon
            lesson.tips = tips
            lesson.imageFilenames = imageFilenames
            store.lessons.append(lesson)
        }
        dismiss()
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
