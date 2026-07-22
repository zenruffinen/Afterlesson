// NotesView – Pro-Notizen: Liste und Editor.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

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
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(ALColor.green.opacity(0.35))
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
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.proNotes) { note in
                                Button { selectedNote = note } label: {
                                    NoteRowView(note: note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteNote(note)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 30)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .gruenbuchSeite()
            .navigationTitle("Notizen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddNote = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .tint(ALColor.green)
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

    private var tint: Color { ALNoteStyle.accent(hex: note.colorHex) }

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: note.audioFilename != nil ? "mic.fill" : "note.text")
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Ohne Titel" : note.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
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
                            .foregroundStyle(tint)
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
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                                        .foregroundStyle(isRecording ? .red : ALColor.green)
                                    Text(isRecording ? "Aufnahme stoppen" : (audioFilename != nil ? "Neu aufnehmen" : "Aufnehmen"))
                                        .font(.subheadline)
                                        .foregroundStyle(isRecording ? .red : ALColor.green)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(ALColor.green.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                                                    .background(selectedStudentID == student.id ? ALColor.green : Color(.secondarySystemGroupedBackground))
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
                    .tint(ALColor.green)
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
