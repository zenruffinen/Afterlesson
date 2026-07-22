// QuickCapture – Live-Stunden-Erfassung: Diktat, Foto/Video, Session-Detail.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

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
                    .fill(ALColor.nachtOben.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isActive ? color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }
}

// MARK: - Quick Capture Sheet

enum QuickCaptureMediaKind: String, CaseIterable, Identifiable {
    case photo, video, note

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: return String(localized: "Foto")
        case .video: return String(localized: "Video")
        case .note:  return String(localized: "Notiz")
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video.fill"
        case .note:  return "note.text"
        }
    }
}

// MARK: - Quick Capture Sheet

struct QuickCaptureSheet: View {
    var preselectedStudentID: UUID? = nil

    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @FocusState private var quickNoteFocused: Bool

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
    @State private var quickTextNote: String = ""
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var pendingPhotoData: [Data] = []
    @State private var pendingVideoURLs: [URL] = []
    @State private var selectedMediaKind: QuickCaptureMediaKind? = nil

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
        selectedStudentID != nil && (
            !trained.isEmpty || !corrections.isEmpty || !exercises.isEmpty || !homework.isEmpty
            || !quickTextNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingPhotoData.isEmpty
            || !pendingVideoURLs.isEmpty
        )
    }

    private func isMediaKindSelected(_ kind: QuickCaptureMediaKind) -> Bool {
        if selectedMediaKind == kind { return true }
        switch kind {
        case .photo: return !pendingPhotoData.isEmpty
        case .video: return !pendingVideoURLs.isEmpty
        case .note:
            return !quickTextNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @ViewBuilder
    private func captureMediaChip(_ kind: QuickCaptureMediaKind) -> some View {
        let highlighted = isMediaKindSelected(kind)
        Button {
            selectedMediaKind = kind
            switch kind {
            case .photo:
                showPhotosPicker = true
            case .video:
                showCamera = true
            case .note:
                quickNoteFocused = true
            }
        } label: {
            Label(kind.label, systemImage: kind.icon)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(highlighted ? .white : .primary)
                .background(highlighted ? ALColor.green : ALColor.nachtOben.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            highlighted ? ALColor.green.opacity(0.55) : Color.clear,
                            lineWidth: 1.5
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(kind == .video && selectedStudentID == nil)
        .opacity(kind == .video && selectedStudentID == nil ? 0.45 : 1)
    }

    private func cleanupPendingMedia() {
        for url in pendingVideoURLs {
            try? FileManager.default.removeItem(at: url)
        }
        pendingVideoURLs = []
        pendingPhotoData = []
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
                                          : ALColor.nachtOben.opacity(0.75))
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
                        .background(ALColor.nachtOben.opacity(0.55))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)

                    // Trennlinie
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [ALColor.green, ALColor.gold, ALColor.green.opacity(0)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2).cornerRadius(1)

                    // Schnellnotiz + Medien (direkt am Schüler, nicht Bibliothek)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Aufnahmen & Notizen")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("Landen direkt am Schüler — nicht in der Bibliothek")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        TextField("Kurznotiz zur Stunde…", text: $quickTextNote, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($quickNoteFocused)
                            .padding(12)
                            .background(ALColor.nachtOben.opacity(0.55))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        isMediaKindSelected(.note) ? ALColor.green.opacity(0.55) : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                            .onChange(of: quickTextNote) { _, text in
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    selectedMediaKind = .note
                                }
                            }

                        HStack(spacing: 10) {
                            captureMediaChip(.photo)
                            captureMediaChip(.video)
                        }

                        if !pendingPhotoData.isEmpty || !pendingVideoURLs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(pendingPhotoData.enumerated()), id: \.offset) { idx, data in
                                        ZStack(alignment: .topTrailing) {
                                            if let img = UIImage(data: data) {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 72, height: 72)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            Button {
                                                pendingPhotoData.remove(at: idx)
                                                if pendingPhotoData.isEmpty, selectedMediaKind == .photo {
                                                    selectedMediaKind = nil
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.white, .black.opacity(0.5))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                    ForEach(Array(pendingVideoURLs.enumerated()), id: \.offset) { idx, _ in
                                        ZStack(alignment: .topTrailing) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(hex: ContentType.video.colorHex).opacity(0.15))
                                                    .frame(width: 72, height: 72)
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(Color(hex: ContentType.video.colorHex))
                                            }
                                            Button {
                                                let url = pendingVideoURLs.remove(at: idx)
                                                try? FileManager.default.removeItem(at: url)
                                                if pendingVideoURLs.isEmpty, selectedMediaKind == .video {
                                                    selectedMediaKind = nil
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.white, .black.opacity(0.5))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Protokoll-Felder
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
            
            .navigationTitle("Stunde erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        transcriber.stop()
                        cleanupPendingMedia()
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
                            Text("Speichern & Nachbesprechung")
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
            .photosPicker(isPresented: $showPhotosPicker, selection: $photoPickerItems,
                          maxSelectionCount: 10, matching: .images)
            .onChange(of: photoPickerItems) { _, items in
                guard !items.isEmpty else { return }
                selectedMediaKind = .photo
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            pendingPhotoData.append(data)
                        }
                    }
                    photoPickerItems = []
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                VideoCameraView { url in
                    selectedMediaKind = .video
                    pendingVideoURLs.append(url)
                }
                .ignoresSafeArea()
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
        guard let studentID = selectedStudentID else { return }

        var session = TrainingSession()
        session.studentID = studentID
        session.title = autoTitle
        session.trained = trained
        session.corrections = corrections
        session.exercises = exercises
        session.homework = homework
        store.addSession(session)

        let note = quickTextNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            store.addStudentCaptureTextNote(note, studentID: studentID, sessionID: session.id)
        }

        Task {
            for data in pendingPhotoData {
                await store.addStudentCaptureFromPhoto(
                    data: data,
                    studentID: studentID,
                    sessionID: session.id
                )
            }
            for url in pendingVideoURLs {
                await store.addStudentCaptureFromVideo(
                    url: url,
                    studentID: studentID,
                    sessionID: session.id
                )
            }
            await MainActor.run {
                pendingPhotoData = []
                pendingVideoURLs = []
                selectedMediaKind = nil
                if thenSend, let url = store.exportSession(session) {
                    shareItems = [AppStore.sessionShareHint, url]
                    showShareSheet = true
                } else {
                    dismiss()
                }
            }
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
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))
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
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))
            }
            .listStyle(.insetGrouped)
            .gruenbuchSeite()
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
    @State private var showFeedbackSheet = false
    @State private var feedbackShareItems: [Any] = []
    @State private var showFeedbackShareSheet = false

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
                                shareItems = [AppStore.sessionShareHint, url]
                                showShareSheet = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "paperplane.fill")
                                Text("Zur Nachbesprechung")
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

                    // Rückmeldung (Schüler, empfangenes Protokoll)
                    if session.source == .received {
                        Button { showFeedbackSheet = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.thumbsup.fill")
                                Text("Rückmeldung an deinen Pro")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(ALColor.gold.opacity(0.15))
                            .foregroundStyle(ALColor.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(ALColor.gold.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            
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
            .sheet(isPresented: $showFeedbackSheet) {
                StudentFeedbackSheet(
                    lessonTitle: nil,
                    sessionTitle: session.title.isEmpty ? "Trainingsprotokoll" : session.title
                ) { items in
                    feedbackShareItems = items
                    showFeedbackShareSheet = true
                }
            }
            .sheet(isPresented: $showFeedbackShareSheet) {
                ShareSheet(items: feedbackShareItems)
            }
            .onAppear {
                if session.source == .received {
                    store.markSessionOpened(session)
                }
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
        .background(ALColor.nachtOben.opacity(0.55))
        .cornerRadius(12)
    }
}
