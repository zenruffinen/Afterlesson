// BibliothekView – Bibliothek (früher Datenpool): Lektionsgruppen, Inhalte erfassen & ansehen.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

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
    @State private var searchText = ""
    @State private var searchSelectedItem: ContentItem? = nil
    // Erfassen direkt von der Kachel aus (Import landet im Eingang)
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var showInbox = false
    @State private var isImporting = false
    @State private var importError: String? = nil

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Suchtreffer über ALLE Lektionsgruppen hinweg — nach Name oder Thema.
    var searchResults: [ContentItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return store.contentPool.filter { item in
            item.title.lowercased().contains(q)
            || item.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchResultsView
                } else if store.contentClasses.isEmpty && store.contentPool.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            inboxRow
                            newClassRow
                            classGrid
                        }
                        .padding(16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bibliothek")
            .navigationSubtitle("Lernstoff & Tipps — wiederverwendbar")
            .searchable(text: $searchText, prompt: "Inhalte suchen")
            .sheet(isPresented: $showNewClassSheet) {
                ContentClassEditorSheet(existingClass: nil)
            }
            .sheet(item: $editingClass) { c in
                ContentClassEditorSheet(existingClass: c)
            }
            .sheet(item: $searchSelectedItem) { item in
                ContentItemDetailView(item: item)
            }
            .navigationDestination(isPresented: $showInbox) {
                ClassContentView(contentClass: nil)
            }
            .onChange(of: photoPickerItems) { _, items in
                guard !items.isEmpty else { return }
                isImporting = true
                Task {
                    await store.importPhotoItems(items, into: nil)
                    photoPickerItems = []
                    isImporting = false
                    showInbox = true
                }
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $photoPickerItems,
                          maxSelectionCount: 20, matching: .any(of: [.images, .videos]))
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.pdf, .movie, .image, .audio, .plainText, .data],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    isImporting = true
                    Task {
                        await store.importFiles(urls, into: nil)
                        isImporting = false
                        showInbox = true
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                VideoCameraView { url in
                    isImporting = true
                    Task {
                        await store.importRecordedVideo(from: url, into: nil)
                        isImporting = false
                        showInbox = true
                    }
                }
                .ignoresSafeArea()
            }
            .overlay {
                if isImporting {
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
            }
            .alert("Import fehlgeschlagen",
                   isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    // MARK: Suchergebnisse (über alle Lektionsgruppen)

    @ViewBuilder
    var searchResultsView: some View {
        if searchResults.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(searchResults) { item in
                        Button { searchSelectedItem = item } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                ContentItemTile(item: item)
                                // Fundort anzeigen: in welcher Lektionsgruppe liegt der Treffer?
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 8))
                                    Text(store.contentClasses.first(where: { $0.id == item.classID })?.title ?? "Eingang")
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: Eingang-Feld (breite Zeile ganz oben)
    //
    // Der Eingang ist der Sammelplatz für alle neuen, noch nicht einsortierten
    // Inhalte — deshalb prominent als breites Feld über den Lektionsgruppen. Drinnen
    // gibt es oben rechts das Plus zum Importieren und Aufnehmen.

    var inboxRow: some View {
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
            Divider()
            Button { showInbox = true } label: {
                Label("Eingang öffnen", systemImage: "tray.and.arrow.down.fill")
            }
        } label: {
            HStack(spacing: 14) {
                Image("gb_erfassen_klein")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Golf-Inhalte erfassen")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tipps, Tricks & Vorlagen — wiederverwendbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.unclassifiedItems.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ALColor.gold)
                    .clipShape(Capsule())
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ALColor.gold)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: Lektionsgruppe-erstellen-Feld (breite Zeile unter dem Eingang)

    var newClassRow: some View {
        Button { showNewClassSheet = true } label: {
            HStack(spacing: 14) {
                Image("gb_gruppe_klein")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lektionsgruppe erstellen")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Neuen Ordner für deine Inhalte anlegen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ALColor.green)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: Lektionsgruppen-Grid (Ordner-Übersicht)

    var classGrid: some View {
        // Kleine Kacheln, alphabetisch — wie ein Karteikasten (Hans, 19.07.)
        // Oberste Ebene: Untergruppen wohnen in ihrer Obergruppe (21.07.)
        // Keine leeren Ordner (Hans, 21.07.): Gruppen erscheinen erst,
        // wenn Inhalte darin liegen — in den Auswahllisten zum
        // Verschieben bleiben sie trotzdem wählbar.
        let visible = store.topLevelClasses
            .filter { store.totalItemCount(of: $0) > 0 }
            .sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        let hiddenCount = store.topLevelClasses.count - visible.count
        return VStack(alignment: .leading, spacing: 8) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
            ForEach(visible) { c in
                NavigationLink {
                    ClassContentView(contentClass: c)
                } label: {
                    ContentClassTile(contentClass: c, count: store.totalItemCount(of: c),
                                     subgroupCount: store.subgroups(of: c).count)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    // Organisieren dürfen Pro UND Schüler (19.07.)
                    if true {
                        Button { editingClass = c } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.deleteContentClass(c)
                        } label: {
                            Label("Lektionsgruppe löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        if hiddenCount > 0 {
            Text(hiddenCount == 1
                 ? "1 leere Gruppe ausgeblendet — sie erscheint, sobald Inhalte darin liegen."
                 : "\(hiddenCount) leere Gruppen ausgeblendet — sie erscheinen, sobald Inhalte darin liegen.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        }
    }

    // MARK: Empty State (noch keine Lektionsgruppen & keine Inhalte)

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundStyle(ALColor.green.opacity(0.35))
            Text("Bibliothek ist leer")
                .font(.title3.bold())
            Text("Sammle hier wiederverwendbaren Lernstoff —\nTipps, Tricks, Film, Bild & Text für spätere Lektionen")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if true {
                Button { showNewClassSheet = true } label: {
                    Label("Neue Lektionsgruppe", systemImage: "folder.badge.plus")
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

// MARK: - Lektionsgruppen-Kachel (Ordner im Datenpool)

struct ContentClassTile: View {
    let contentClass: ContentClass?     // nil = "Unsortiert"
    let count: Int
    var subgroupCount: Int = 0          // Obergruppen zeigen ihre Untergruppen an

    var color: Color {
        contentClass.map { Color(hex: $0.colorHex) } ?? ALColor.gold
    }
    var icon: String { contentClass?.icon ?? "tray.and.arrow.down.fill" }
    var title: String { contentClass?.title ?? "Eingang" }

    var body: some View {
        // Kompakte Karteikarte: Icon mit Zähler, darunter der Name.
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(icon.hasPrefix("img:") ? 0 : 0.15))
                        .frame(width: 32, height: 32)
                    ClassIcon(icon: icon, color: color, side: 32, symbolSize: 15)
                }
                Spacer()
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(subgroupCount > 0 ? 1 : 2, reservesSpace: subgroupCount == 0)
                .multilineTextAlignment(.leading)
            if subgroupCount > 0 {
                Text(subgroupCount == 1 ? "1 Untergruppe" : "\(subgroupCount) Untergruppen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Lektionsgruppen-Inhalt (Grid der Inhalte einer Lektionsgruppe bzw. "Unsortiert")

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
    @State private var selectionMode = false            // Mehrfachauswahl aktiv?
    @State private var selectedIDs: Set<UUID> = []      // Ausgewählte Inhalte
    @State private var showClassEditor = false          // Gruppe umbenennen
    @State private var showNewSubgroup = false          // Untergruppe anlegen
    @State private var editingSubclass: ContentClass? = nil  // Untergruppe bearbeiten
    @Environment(\.dismiss) private var dismissView

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    /// Die Inhalte dieser Lektionsgruppe (bzw. alle ohne Lektionsgruppe bei "Unsortiert").
    var classItems: [ContentItem] {
        store.contentPool.filter { $0.classID == contentClass?.id }
    }

    /// Untergruppen dieser Gruppe (z.B. Kurzes Spiel → Putten/Chippen/Pitchen).
    var subclasses: [ContentClass] {
        guard let c = contentClass else { return [] }
        return store.subgroups(of: c)
    }

    /// Nur gefüllte Untergruppen werden gezeigt — keine leeren Ordner (21.07.).
    var visibleSubclasses: [ContentClass] {
        subclasses.filter { !store.items(in: $0).isEmpty }
    }

    /// Untergruppen kann nur eine Gruppe der obersten Ebene haben (eine Ebene Tiefe).
    var canHaveSubgroups: Bool {
        contentClass != nil && contentClass?.parentID == nil
    }

    /// Alle in dieser Lektionsgruppe vergebenen Themen ("Gruppierungen"), alphabetisch —
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
            if classItems.isEmpty && subclasses.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Erst die Untergruppen (falls vorhanden), dann die eigenen Inhalte
                        if !visibleSubclasses.isEmpty {
                            subgroupGrid
                        }
                        // "Unsortiert" ist der Eingangskorb für neue Inhalte —
                        // dort braucht es keine Typ-/Themen-Filter, sondern eine
                        // freundliche Überschrift mit Hinweis. In echten Lektionsgruppen
                        // bleiben die Filterleisten erhalten.
                        if contentClass == nil {
                            inboxHeader
                        } else if !classItems.isEmpty {
                            if !visibleSubclasses.isEmpty {
                                Text("Inhalte")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }
                            filterBar
                            themeFilterBar
                        }
                        if !classItems.isEmpty {
                            grid
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(contentClass?.title ?? "Eingang")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Sichtbarer Weg zum Umbenennen/Löschen — gilt auch für die
            // vordefinierten Golf-Gruppen (Hans, 19.07.)
            if let c = contentClass {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showClassEditor = true
                        } label: {
                            Label("Lektionsgruppe bearbeiten", systemImage: "pencil")
                        }
                        if canHaveSubgroups {
                            Button {
                                showNewSubgroup = true
                            } label: {
                                Label("Neue Untergruppe", systemImage: "folder.badge.plus")
                            }
                        }
                        Button(role: .destructive) {
                            store.deleteContentClass(c)
                            dismissView()
                        } label: {
                            Label("Lektionsgruppe löschen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            if true {
                if !classItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(selectionMode ? "Fertig" : "Auswählen") {
                            selectionMode.toggle()
                            selectedIDs.removeAll()
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    addMenu
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selectionMode && !selectedIDs.isEmpty {
                moveBar
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
        .sheet(isPresented: $showClassEditor) {
            ContentClassEditorSheet(existingClass: contentClass)
        }
        .sheet(isPresented: $showNewSubgroup) {
            ContentClassEditorSheet(existingClass: nil, presetParentID: contentClass?.id)
        }
        .sheet(item: $editingSubclass) { sub in
            ContentClassEditorSheet(existingClass: sub)
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
            Text(contentClass == nil ? "Eingang ist leer" : "Diese Lektionsgruppe ist leer")
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

    // MARK: Untergruppen-Grid (Obergruppe zeigt ihre Untergruppen)

    var subgroupGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Untergruppen")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(visibleSubclasses) { sub in
                    NavigationLink {
                        ClassContentView(contentClass: sub)
                    } label: {
                        ContentClassTile(contentClass: sub, count: store.items(in: sub).count)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingSubclass = sub
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.deleteContentClass(sub)
                        } label: {
                            Label("Untergruppe löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: Eingang-Überschrift (nur bei "Unsortiert")

    var inboxHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ALColor.gold.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.title3)
                    .foregroundStyle(ALColor.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Neue Inhalte")
                    .font(.headline)
                Text("Halte einen Inhalt gedrückt,\num ihn in eine Lektionsgruppe zu verschieben")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        // Briefmarken-Format: 4 pro Reihe auf dem iPhone, iPad mehr —
        // die Großansicht übernimmt das genaue Hinschauen (Hans, 19.07.).
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
            ForEach(filteredItems) { item in
                Button {
                    if selectionMode {
                        if selectedIDs.contains(item.id) {
                            selectedIDs.remove(item.id)
                        } else {
                            selectedIDs.insert(item.id)
                        }
                    } else {
                        selectedItem = item
                    }
                } label: {
                    ContentItemTile(item: item)
                        .overlay(alignment: .topLeading) {
                            if selectionMode {
                                Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(selectedIDs.contains(item.id) ? ALColor.green : Color(.systemGray3))
                                    .background(Circle().fill(.white))
                                    .padding(6)
                            }
                        }
                        .opacity(selectionMode && !selectedIDs.contains(item.id) ? 0.55 : 1)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    // Verschieben dürfen Pro UND Schüler (19.07.)
                    if true {
                        Menu {
                            ForEach(store.contentClasses.sorted(by: { $0.sortIndex < $1.sortIndex })) { c in
                                if c.id != contentClass?.id {
                                    Button {
                                        store.move(item, toClass: c.id)
                                    } label: {
                                        Label(c.title, systemImage: ClassIcon.menuSymbol(for: c.icon))
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
                            Label("In Lektionsgruppe verschieben", systemImage: "folder")
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

    // MARK: Verschieben-Leiste (Mehrfachauswahl)

    var moveBar: some View {
        HStack {
            Text(selectedIDs.count == 1 ? "1 ausgewählt" : "\(selectedIDs.count) ausgewählt")
                .font(.subheadline.bold())
            Spacer()
            Menu {
                ForEach(store.contentClasses.sorted(by: { $0.sortIndex < $1.sortIndex })) { c in
                    if c.id != contentClass?.id {
                        Button {
                            moveSelected(to: c.id)
                        } label: {
                            Label(c.title, systemImage: ClassIcon.menuSymbol(for: c.icon))
                        }
                    }
                }
                if contentClass != nil {
                    Button {
                        moveSelected(to: nil)
                    } label: {
                        Label("Eingang", systemImage: "tray.and.arrow.down.fill")
                    }
                }
            } label: {
                Label("Verschieben", systemImage: "folder")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ALColor.green)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    func moveSelected(to classID: UUID?) {
        for id in selectedIDs {
            if let item = store.contentPool.first(where: { $0.id == id }) {
                store.move(item, toClass: classID)
            }
        }
        selectedIDs.removeAll()
        selectionMode = false
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

    // MARK: Import — delegiert an die zentrale Logik im AppStore
    // (gemeinsam mit der Datenpool-Übersicht, siehe AppStore "Datenpool-Import")

    func importFromPhotos(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            await store.importPhotoItems(items, into: contentClass?.id)
            photoPickerItems = []
            isImporting = false
        }
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            isImporting = true
            Task {
                await store.importFiles(urls, into: contentClass?.id)
                isImporting = false
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    func importRecordedVideo(from url: URL) {
        isImporting = true
        Task {
            await store.importRecordedVideo(from: url, into: contentClass?.id)
            isImporting = false
        }
    }
}

// MARK: - Lektionsgruppen-Editor (Neue Lektionsgruppe anlegen / bearbeiten)

struct ContentClassEditorSheet: View {
    let existingClass: ContentClass?
    var presetParentID: UUID? = nil     // Neue Untergruppe direkt in einer Obergruppe anlegen
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "2C5F2D"
    @State private var parentID: UUID? = nil
    @State private var magnifiedIcon: String? = nil     // Glaslupe über der Auswahl
    @State private var magnifyTask: Task<Void, Never>? = nil

    var isEditing: Bool { existingClass != nil }

    /// Mögliche Obergruppen: nur oberste Ebene (genau EINE Ebene Tiefe),
    /// nicht die Gruppe selbst — und wer selbst Untergruppen hat, bleibt Obergruppe.
    var parentChoices: [ContentClass] {
        store.topLevelClasses
            .filter { $0.id != existingClass?.id }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var hasSubgroups: Bool {
        guard let c = existingClass else { return false }
        return !store.subgroups(of: c).isEmpty
    }

    // Golfbezogene Icon-Auswahl: Schwung, Fahne/Green, Ball, Ziel, Platz,
    // Wetter, Fitness & Mental — plus ein paar neutrale für Theorie & Medien.
    let classIcons = [
        "figure.golf", "flag.fill", "flag.circle.fill", "flag.2.crossed.fill",
        "circle.fill", "target", "scope", "trophy.fill",
        "medal.fill", "arrow.up.right", "ruler.fill", "map.fill",
        "mappin.and.ellipse", "sun.max.fill", "wind", "cloud.sun.fill",
        "leaf.fill", "tree.fill", "mountain.2.fill", "figure.flexibility",
        "figure.walk", "dumbbell.fill", "brain.head.profile", "eye.fill",
        "hand.raised.fill", "timer", "video.fill", "book.fill",
        "graduationcap.fill", "lightbulb.fill", "star.fill", "folder.fill"
    ]

    let colors: [(String, String)] = [
        ("1B5E20", "Dunkelgrün"), ("2C5F2D", "Golf-Grün"), ("1565C0", "Blau"),
        ("4A148C", "Lila"),      ("E65100", "Orange"),    ("37474F", "Grau"),
        ("880E4F", "Pink"),      ("006064", "Türkis"),    ("BF360C", "Rot"),
        ("F57F17", "Gold"),      ("263238", "Anthrazit"), ("4E342E", "Braun")
    ]

    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Zeigt das Icon eine gute Sekunde lang groß (Glaslupe).
    private func showMagnifier(_ asset: String) {
        magnifyTask?.cancel()
        magnifiedIcon = asset
        magnifyTask = Task {
            try? await Task.sleep(for: .seconds(1.1))
            if !Task.isCancelled { magnifiedIcon = nil }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Vorschau
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedIcon.hasPrefix("img:") ? Color.clear : Color(hex: selectedColor))
                            .frame(width: 72, height: 72)
                        if selectedIcon.hasPrefix("img:") {
                            ClassIcon(icon: selectedIcon, side: 72)
                        } else {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
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

                    // Obergruppe (z.B. Kurzes Spiel → Putten) — genau eine Ebene
                    if !hasSubgroups && !parentChoices.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Gehört zu").font(.caption.bold()).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            Menu {
                                Button("Keine Obergruppe") { parentID = nil }
                                ForEach(parentChoices) { choice in
                                    Button(choice.title) { parentID = choice.id }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: parentID == nil ? "square.grid.2x2" : "folder.fill")
                                        .foregroundStyle(ALColor.green)
                                    Text(parentChoices.first(where: { $0.id == parentID })?.title ?? "Keine Obergruppe")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                        }
                    } else if hasSubgroups {
                        Text("Diese Gruppe hat Untergruppen und bleibt daher auf der obersten Ebene.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // Golf-Icons (eigene Bilder — Hans, 21.07.)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Golf-Icons").font(.caption.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(GruppenIcons.alle, id: \.self) { asset in
                                let key = "img:\(asset)"
                                Button {
                                    selectedIcon = key
                                    showMagnifier(asset)
                                } label: {
                                    Image(asset)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay {
                                            if selectedIcon == key {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(Color(hex: selectedColor), lineWidth: 3)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Icon-Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Symbole").font(.caption.bold()).foregroundStyle(.secondary)
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
            .navigationTitle(isEditing ? "Lektionsgruppe bearbeiten" : "Neue Lektionsgruppe")
            .navigationBarTitleDisplayMode(.inline)
            // Glaslupe: das angetippte Icon erscheint kurz groß in der Mitte —
            // bei 62 kleinen Kacheln sieht man so genau, was man gewählt hat.
            .overlay {
                if let asset = magnifiedIcon {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(duration: 0.25), value: magnifiedIcon)
            .onAppear {
                if let c = existingClass {
                    title = c.title
                    selectedIcon = c.icon
                    selectedColor = c.colorHex
                    parentID = c.parentID
                } else {
                    parentID = presetParentID
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
                            c.parentID = hasSubgroups ? nil : parentID
                            store.updateContentClass(c)
                        } else {
                            store.addContentClass(title: t, icon: selectedIcon,
                                                  colorHex: selectedColor, parentID: parentID)
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

    // Eigene Kachel-Farbe des Inhalts, falls gewählt — sonst die Standardfarbe des Typs.
    var typeColor: Color { Color(hex: item.tileColorHex ?? item.type.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Einheitliches 4:3-Vorschauformat: Das Bild füllt den Rahmen,
                // ohne zu verzerren oder über die Kachel hinauszulaufen.
                Color.clear
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(typeColor.opacity(0.12))
                    .overlay(preview)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                ZStack {
                    Circle().fill(typeColor)
                        .frame(width: 18, height: 18)
                    Image(systemName: item.type.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                }
                .padding(4)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            }

            // Briefmarke: nur der Titel — Datum und Themen zeigt die Großansicht.
            Text(item.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    var preview: some View {
        if item.type == .image, let img = UIImage(contentsOfFile: store.imageURL(for: item.filename).path) {
            // "Fit in window": das ganze Bild sichtbar, nichts abgeschnitten
            Image(uiImage: img).resizable().scaledToFit().padding(4)
        } else if let thumb = item.thumbnailFilename,
                  let img = UIImage(contentsOfFile: store.imageURL(for: thumb).path) {
            ZStack {
                Image(uiImage: img).resizable().scaledToFit().padding(4)
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
    @State private var editTitle: String

    init(item: ContentItem) {
        self.item = item
        _tags = State(initialValue: item.tags)
        _editTitle = State(initialValue: item.title)
    }

    /// Aktueller Stand des Inhalts aus dem Store — `item` ist nur der Stand
    /// beim Öffnen; Lektionsgruppe/Farbe können sich währenddessen ändern.
    var currentItem: ContentItem {
        store.contentPool.first(where: { $0.id == item.id }) ?? item
    }

    /// Ändert den Inhalt im Store über eine Mutations-Closure — so gehen
    /// parallel gemachte Änderungen (z.B. Themen) nicht verloren.
    func updateItem(_ mutate: (inout ContentItem) -> Void) {
        var updated = currentItem
        mutate(&updated)
        store.updateContentItem(updated)
    }

    let tileColors: [String] = [
        "1B5E20", "2C5F2D", "1565C0", "4A148C", "E65100", "37474F",
        "880E4F", "006064", "BF360C", "F57F17"
    ]

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
                    editBar
                    themesBar
                }
            }
            .navigationTitle(editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        saveTitle()
                        dismiss()
                    }
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
                guard newThemes != currentItem.tags else { return }
                updateItem { $0.tags = newThemes }
            }
        }
    }

    func saveTitle() {
        let t = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t != currentItem.title else { return }
        updateItem { $0.title = t }
    }

    // MARK: Editor-Leiste (Name, Lektionsgruppe, Kachel-Farbe)

    var editBar: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Name ändern
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $editTitle)
                    .font(.subheadline.weight(.semibold))
                    .submitLabel(.done)
                    .onSubmit { saveTitle() }
            }
            .padding(10)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {

                // Lektionsgruppe wechseln
                Menu {
                    ForEach(store.contentClasses.sorted(by: { $0.sortIndex < $1.sortIndex })) { c in
                        Button {
                            updateItem { $0.classID = c.id }
                        } label: {
                            Label(c.title, systemImage: currentItem.classID == c.id ? "checkmark" : ClassIcon.menuSymbol(for: c.icon))
                        }
                    }
                    Button {
                        updateItem { $0.classID = nil }
                    } label: {
                        Label("Eingang", systemImage: currentItem.classID == nil ? "checkmark" : "tray.and.arrow.down.fill")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                        Text(store.contentClasses.first(where: { $0.id == currentItem.classID })?.title ?? "Eingang")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ALColor.green.opacity(0.12))
                    .foregroundStyle(ALColor.green)
                    .clipShape(Capsule())
                }

                // Kachel-Farbe wählen
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "Standard" = Typ-Farbe (tileColorHex = nil)
                        Button {
                            updateItem { $0.tileColorHex = nil }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color(hex: currentItem.type.colorHex), lineWidth: 2)
                                    .frame(width: 26, height: 26)
                                if currentItem.tileColorHex == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color(hex: currentItem.type.colorHex))
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(tileColors, id: \.self) { hex in
                            Button {
                                updateItem { $0.tileColorHex = hex }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 26, height: 26)
                                    if currentItem.tileColorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial)
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
                Text("Noch keinem Thema zugeordnet. Ordne diesen Inhalt z. B. „Putting“ oder „Anfänger“ zu, um ihn in der Bibliothek leichter wiederzufinden und beim Zusammenstellen einer Lektion zu gruppieren.")
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
            // Ganzes Bild bildschirmfüllend eingepasst — kein Scrollen,
            // auf iPhone und iPad gleichermaßen (Hans, 19.07.)
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Text("Lege zuerst eine Lektion an, um Inhalte aus der Bibliothek nachzuliefern.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("Wähle eine oder mehrere Lektionen — „\(item.title)“ wird dort als weiterer Inhalt aus der Bibliothek ergänzt, auch wenn die Lektion bereits einem Schüler zugewiesen ist.")
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
                    Text("Inhalte mit demselben Thema lassen sich in der Bibliothek gemeinsam anzeigen und beim Zusammenstellen einer Lektion leichter wiederfinden.")
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
                    Section("Bereits in der Bibliothek verwendet") {
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
