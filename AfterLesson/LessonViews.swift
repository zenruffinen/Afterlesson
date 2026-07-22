// LessonViews – Lektionen: Karten, Detail, Editor und Datenpool-Auswahl.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

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
                        Label("\(poolItems.count) aus Bibliothek", systemImage: "books.vertical.fill")
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
            .background(ALColor.nachtOben.opacity(0.55))
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
    @State private var showFeedbackSheet = false
    @State private var feedbackShareItems: [Any] = []
    @State private var showFeedbackShareSheet = false

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
                Label("Inhalte aus der Bibliothek", systemImage: "books.vertical.fill")
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
                    .accessibilityLabel("Inhalte aus der Bibliothek ergänzen")
                }
            }

            if poolItems.isEmpty {
                Text("Noch keine Inhalte aus der Bibliothek zugeordnet. Du kannst jederzeit weitere Bilder, Videos, PDFs, Audios oder Texte nachliefern.")
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
        .background(ALColor.nachtOben.opacity(0.55))
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
                        .background(ALColor.nachtOben.opacity(0.55))
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

                    // Als erledigt markieren + Rückmeldung (Schüler)
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

                        Button { showFeedbackSheet = true } label: {
                            Label("Rückmeldung an deinen Pro", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ALColor.gold.opacity(0.15))
                                .foregroundStyle(ALColor.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(ALColor.gold.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            
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
            .sheet(isPresented: $showFeedbackSheet) {
                StudentFeedbackSheet(
                    lessonTitle: currentLesson.title,
                    sessionTitle: nil
                ) { items in
                    feedbackShareItems = items
                    showFeedbackShareSheet = true
                }
            }
            .sheet(isPresented: $showFeedbackShareSheet) {
                ShareSheet(items: feedbackShareItems)
            }
            .onAppear {
                if !isTeacher {
                    store.recordLessonOpened(currentLesson)
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
        .background(ALColor.nachtOben.opacity(0.55))
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
        if poolCount > 0 { parts.append("\(poolCount) aus Bibliothek") }
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
        .background(ALColor.nachtOben.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                                                .fill(selectedIcon == icon ? ALColor.green : ALColor.nachtOben.opacity(0.75))
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
                            Label("Inhalte aus der Bibliothek", systemImage: "books.vertical.fill")
                                .font(.caption.bold()).foregroundStyle(.secondary)

                            if poolContentItems.isEmpty {
                                Text("Stelle diese Lektion aus Bildern, Videos, PDFs oder Audio zusammen, die du bereits in deiner Bibliothek gesammelt hast.")
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
                                    Text(poolContentItems.isEmpty ? "Aus Bibliothek auswählen" : "Auswahl bearbeiten")
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
            .background(ALColor.nachtOben.opacity(0.55))
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
                    ContentUnavailableView("Bibliothek ist leer", systemImage: "books.vertical.fill",
                                           description: Text("Importiere zuerst Inhalte im Bibliothek-Tab — danach kannst du sie hier für Lektionen auswählen."))
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
            .background(isSelected ? color : ALColor.nachtOben.opacity(0.55))
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
