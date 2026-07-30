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

    /// Nimmt parallel zur Erkennung auch die Stimme auf (Notizen:
    /// ein Diktat liefert Text UND Sprachnotiz in einem Rutsch).
    private var audioFile: AVAudioFile?

    func start(existing: String, recordingURL: URL? = nil, onChange: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch auth {
                case .authorized:
                    self.startEngine(existing: existing, recordingURL: recordingURL, onChange: onChange)
                default:
                    self.permissionDenied = true
                }
            }
        }
    }

    private func startEngine(existing: String, recordingURL: URL? = nil, onChange: @escaping (String) -> Void) {
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
        if let recordingURL {
            audioFile = try? AVAudioFile(forWriting: recordingURL, settings: format.settings)
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
            try? self?.audioFile?.write(from: buf)
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
        audioFile = nil          // schließt die parallel laufende Aufnahme
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

private struct MedienURL: Identifiable {
    let url: URL
    var id: String { url.path }
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
    @State private var sendeErgebnis: String? = nil
    @State private var sackOffen = false   // Golfsack angeklickt → Abschluss & Senden
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
        formatter.dateFormat = "dd.MM."
        let dateStr = formatter.string(from: Date())
        let lehrer = store.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        return lehrer.isEmpty
            ? "Unterricht vom \(dateStr)"
            : "Unterricht vom \(dateStr) – Lehrer \(lehrer)"
    }

    var canSave: Bool {
        selectedStudentID != nil && (
            !trained.isEmpty || !corrections.isEmpty || !exercises.isEmpty || !homework.isEmpty
            || !quickTextNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingPhotoData.isEmpty
            || !pendingVideoURLs.isEmpty
        )
    }

    /// Wie viele Dinge liegen im Sack? (Fotos + Videos + Kurznotiz)
    private var sackAnzahl: Int {
        pendingPhotoData.count + pendingVideoURLs.count
            + (quickTextNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    private var golfsackKarte: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                sackOffen.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    Image("gb_golfbag")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .scaleEffect(sackAnzahl > 0 ? 1.0 : 0.94)
                        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: sackAnzahl)
                    if sackAnzahl > 0 {
                        Text("\(sackAnzahl)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "0B150D"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ALColor.goldHell, in: Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Der Golfsack")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text(sackAnzahl == 0
                         ? "Noch leer — Fotos, Videos und Notizen landen hier."
                         : (sackOffen
                            ? "Bereit zum Schicken — unten wartet der Knopf."
                            : "\(sackAnzahl) gesammelt — antippen, wenn die Stunde fertig ist."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: sackOffen ? "chevron.up.circle.fill" : "paperplane.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ALColor.goldHell)
            }
            .padding(14)
            .nachtKarte(radius: 16, hervorgehoben: sackOffen)
        }
        .buttonStyle(GrünbuchTastenStyle(radius: 16))
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

                    // DER GOLFSACK (Hans, 23.07.): Alles Gesammelte liegt
                    // im Sack — antippen schnürt ihn zu (Abschluss & Senden).
                    golfsackKarte

                    if sackOffen {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Abschlussbesprechung")
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(ALColor.goldHell)
                            Text("Kurz festhalten — dann den Sack abschicken.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                if sackOffen && canSave && selectedStudentID != nil {
                    Button {
                        saveSession(thenSend: true)
                    } label: {
                        HStack(spacing: 10) {
                            Image("gb_golfbag")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Golfsack an \(selectedStudent?.name ?? "Schüler") schicken")
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
            .alert("Stunde", isPresented: Binding(
                get: { sendeErgebnis != nil },
                set: { if !$0 { sendeErgebnis = nil; dismiss() } }
            )) {
                Button("OK") { sendeErgebnis = nil; dismiss() }
            } message: {
                Text(sendeErgebnis ?? "")
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
            }
            guard thenSend else {
                await MainActor.run { dismiss() }
                return
            }
            // Abschluss: die komplette Stunde (Protokoll + alle Aufnahmen)
            // über die Cloud an den Schüler — Datei-Notweg nur ohne Cloud.
            let hatCloud = await MainActor.run {
                store.students.first(where: { $0.id == studentID })?.cloudUserID != nil
                    && CloudService.shared.isSignedIn
            }
            if hatCloud {
                let ergebnis = await store.sendeStundeViaCloud(session, anLocalStudentID: studentID)
                await MainActor.run {
                    if ergebnis.wartend {
                        sendeErgebnis = "Kein Netz — die Stunde liegt im Postausgang und geht automatisch raus."
                    } else if ergebnis.ok {
                        sendeErgebnis = "Stunde mit allen Aufnahmen an den Schüler gesendet. 🔔"
                    } else {
                        sendeErgebnis = CloudService.shared.lastErrorMessage ?? "Senden hat nicht geklappt."
                    }
                }
            } else {
                await MainActor.run {
                    if let url = store.exportSession(session) {
                        shareItems = [AppStore.sessionShareHint, url]
                        showShareSheet = true
                    } else {
                        dismiss()
                    }
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
    @State private var sendeErgebnis: String? = nil
    @State private var sackOffen = false   // Golfsack angeklickt → Abschluss & Senden
    @State private var showFeedbackSheet = false
    @State private var feedbackShareItems: [Any] = []
    @State private var showFeedbackShareSheet = false
    @State private var videoURL: URL? = nil
    @State private var fotoURL: URL? = nil

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

                    // Aufnahmen der Stunde: Fotos, Videos, Notizen (23.07.)
                    aufnahmenGalerie

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
    var aufnahmenGalerie: some View {
        let aufnahmen = store.capturesFor(session: session)
        if !aufnahmen.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ALColor.goldHell)
                    Text("Aufnahmen aus der Stunde")
                        .font(.caption.bold())
                        .foregroundStyle(ALColor.goldHell)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(aufnahmen) { aufnahme in
                        aufnahmeKachel(aufnahme)
                    }
                }
                ForEach(aufnahmen.filter { $0.type == .text && !$0.textNote.isEmpty }) { notiz in
                    Text(notiz.textNote)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(ALColor.nachtOben.opacity(0.4))
                        .cornerRadius(10)
                }
            }
            .padding(14)
            .background(ALColor.nachtOben.opacity(0.55))
            .cornerRadius(12)
            .sheet(item: Binding(
                get: { videoURL.map { MedienURL(url: $0) } },
                set: { if $0 == nil { videoURL = nil } }
            )) { medienURL in
                VideoPlayer(player: AVPlayer(url: medienURL.url))
                    .ignoresSafeArea()
            }
            .sheet(item: Binding(
                get: { fotoURL.map { MedienURL(url: $0) } },
                set: { if $0 == nil { fotoURL = nil } }
            )) { medienURL in
                if let img = UIImage(contentsOfFile: medienURL.url.path) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .ignoresSafeArea()
                }
            }
        }
    }

    @ViewBuilder
    private func aufnahmeKachel(_ aufnahme: StudentCapture) -> some View {
        if aufnahme.type == .image, let f = aufnahme.filename,
           let img = UIImage(contentsOfFile: store.imageURL(for: f).path) {
            Button { fotoURL = store.imageURL(for: f) } label: {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        } else if aufnahme.type == .video, let f = aufnahme.filename {
            Button { videoURL = store.imageURL(for: f) } label: {
                ZStack {
                    if let t = aufnahme.thumbnailFilename,
                       let img = UIImage(contentsOfFile: store.imageURL(for: t).path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ALColor.nachtUnten)
                            .frame(height: 100)
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
            }
            .buttonStyle(.plain)
        }
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
