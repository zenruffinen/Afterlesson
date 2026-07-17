// StudentExchange – Austausch Pro <-> Schüler: Nachbesprechung, Empfang, Rückmeldung.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

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
        .navigationTitle("Grünbuch")
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
                    sectionBlock(title: "Notizen", icon: "note.text.badge.plus", color: ALColor.green) {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCapture) {
                    Label("Stunde erfassen", systemImage: "figure.golf")
                }
                .tint(ALColor.green)
            }
        }
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
        let tint = ALNoteStyle.accent(hex: note.colorHex)
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "pencil.tip")
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

// MARK: - Student Feedback Sheet

struct StudentFeedbackSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let lessonTitle: String?
    let sessionTitle: String?
    let onSend: ([Any]) -> Void

    @State private var selectedKind: FeedbackKind = .thanks
    @State private var message: String = FeedbackKind.thanks.presetMessage

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Deine Nachricht geht als Datei an deinen Pro — per AirDrop, WhatsApp oder E-Mail. Er sieht sie in Grünbuch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Schnellantwort") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FeedbackKind.allCases.filter { $0 != .custom }, id: \.self) { kind in
                                Button {
                                    selectedKind = kind
                                    message = kind.presetMessage
                                } label: {
                                    Label(kind.label, systemImage: kind.icon)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedKind == kind
                                                ? ALColor.gold.opacity(0.2)
                                                : Color(.secondarySystemGroupedBackground),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedKind == kind ? ALColor.gold : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Deine Nachricht") {
                    TextField("Schreib deinem Pro…", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: message) { _, newVal in
                            if newVal != selectedKind.presetMessage {
                                selectedKind = .custom
                            }
                        }
                }

                if lessonTitle != nil || sessionTitle != nil {
                    Section("Bezug") {
                        if let lessonTitle {
                            Label(lessonTitle, systemImage: "book.fill")
                        }
                        if let sessionTitle {
                            Label(sessionTitle, systemImage: "doc.text.fill")
                        }
                    }
                }
            }
            .navigationTitle("Rückmeldung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sendFeedback()
                    } label: {
                        Label("Senden", systemImage: "paperplane.fill")
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func sendFeedback() {
        guard let url = store.exportFeedback(
            kind: selectedKind,
            message: message,
            lessonTitle: lessonTitle,
            sessionTitle: sessionTitle
        ) else { return }
        let items: [Any] = [AppStore.feedbackShareHint, url]
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onSend(items)
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
                } footer: {
                    Label {
                        Text("In der Nachbesprechung: Lektionen persönlich per AirDrop übergeben — ca. 5 Minuten am Platz, direkt nach der Lektion.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "airdrop")
                            .foregroundStyle(ALColor.green)
                    }
                }
            }
            .navigationTitle("Nachbesprechung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        var items: [Any] = [AppStore.lessonShareHint]
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let dateStr = Date().formatted(date: .long, time: .omitted)
                            items.append("Grünbuch · \(student.name) · \(dateStr)\n\n\(trimmed)")
                        }
                        items += lessons.compactMap { store.exportLesson($0) }
                        store.recordSent(to: student, lessons: lessons, note: trimmed)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onSend(items)
                        }
                    } label: {
                        Label("Nachbesprechung starten", systemImage: "paperplane.fill")
                    }
                    .disabled(lessons.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}
