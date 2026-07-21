// StudentsView – Schülerverwaltung: Liste, Editor, Detailansicht.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

// MARK: - Students View

struct StudentsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddStudent = false
    @State private var selectedStudent: Student? = nil
    @State private var studentToEdit: Student? = nil

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

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
                                    // Avatar
                                    ZStack {
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
            .navigationTitle(isTeacher ? "Schüler" : String(localized: "Mein Profil"))
            .toolbar {
                if isTeacher {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showAddStudent = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // Pro: Beim Öffnen der Schülerliste neue Cloud-Antworten abholen
            // und die Gelesen-Häkchen der Mitteilungen nachführen
            .task {
                if isTeacher {
                    _ = await store.importCloudResponses()
                    await store.refreshProMessages()
                }
            }
            // Schüler-Modus: Der Nutzer sieht hier SICH SELBST — die eigene
            // Karteikarte wird beim ersten Besuch automatisch angelegt.
            .onAppear {
                if !isTeacher && store.students.isEmpty {
                    let myName = store.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.students.append(Student(name: myName.isEmpty ? String(localized: "Mein Profil") : myName))
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
            // Schüler-Modus: Das eigene Profil ist die Quelle des Namens —
            // Startbildschirm-Begrüßung zieht mit.
            if store.appMode == AppMode.student.rawValue {
                store.teacherName = n
            }
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
    @State private var photosItem: PhotosPickerItem? = nil
    @State private var selectedSession: TrainingSession? = nil
    @State private var showEditSheet = false
    @ObservedObject private var cloud = CloudService.shared
    @State private var isCreatingCode = false
    @State private var responseText = ""
    @State private var isSendingResponse = false
    @State private var responseSent = false

    var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }
    var currentStudent: Student { store.currentStudent(student) ?? student }
    var assignedLessons: [Lesson]  { store.assignedLessonsFor(currentStudent) }
    var trainingSessions: [TrainingSession] { store.sessionsFor(currentStudent).sorted { $0.date > $1.date } }
    var liveCaptures: [StudentCapture] { store.capturesFor(currentStudent) }

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
                    Text("Verlauf").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))

                Divider()

                // ── Tab Content ──
                Group {
                    if tab == 0 { karteiTab }
                    else { verlaufTab }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Stift für beide: Der Pro pflegt seine Schüler,
                // der Schüler korrigiert sein eigenes Profil.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(student.name)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            // Schließen auch unten — bequemer erreichbar als "Fertig" oben
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Schließen")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(ALColor.green, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showEditSheet) {
                StudentEditorSheet(existingStudent: currentStudent)
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(session: session)
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
                    // Stats — eine Zeile, schrumpft statt umzubrechen
                    Text("\(assignedLessons.count) Lektionen · \(trainingSessions.count) Stunden · \(liveCaptures.count) Aufnahmen")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                // Aktionen wohnen im Composer und auf dem Startbildschirm —
                // die Kartei zeigt, die Kartei handelt nicht.
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: Tab 0 — Kartei (Persönliche Infos)

    var karteiTab: some View {
        List {
            // Wichtige Nachrichten vom Pro — nur im Schüler-Modus
            // (Quelle: Hausaufgaben/Korrekturen der empfangenen Stunden)
            if !isTeacher {
                Section {
                    let messages = trainingSessions.filter { !$0.homework.isEmpty || !$0.corrections.isEmpty }.prefix(3)
                    if messages.isEmpty {
                        Text("Noch keine Nachrichten — dein Pro sendet dir Aufgaben und Hinweise nach der Stunde.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(messages)) { session in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: "megaphone.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ALColor.gold)
                                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption.bold())
                                    if !session.teacherName.isEmpty {
                                        Text("· \(session.teacherName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if !session.homework.isEmpty {
                                    Text(session.homework)
                                        .font(.subheadline)
                                }
                                if !session.corrections.isEmpty {
                                    Text(session.corrections)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Label("Wichtige Nachrichten vom Pro", systemImage: "megaphone.fill")
                        .foregroundStyle(ALColor.gold)
                }
            }

            // Rückkanal: Der Schüler antwortet seinem Pro über die Cloud
            if !isTeacher && cloud.isSignedIn {
                Section {
                    TextField("cloud.response_placeholder", text: $responseText, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        isSendingResponse = true
                        responseSent = false
                        Task {
                            let ok = await CloudService.shared.sendResponseToPro(
                                responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            if ok {
                                responseText = ""
                                responseSent = true
                            }
                            isSendingResponse = false
                        }
                    } label: {
                        if isSendingResponse {
                            ProgressView()
                        } else {
                            Label("cloud.response_send", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingResponse)

                    if responseSent {
                        Label("cloud.response_sent", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let error = cloud.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Label("cloud.response_header", systemImage: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(ALColor.green)
                }
            }

            // Kontakt — Telefonnummer braucht nur der Pro
            Section {
                if isTeacher, !currentStudent.phone.isEmpty {
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
                if (currentStudent.phone.isEmpty || !isTeacher) && currentStudent.birthday == nil {
                    Text(isTeacher
                         ? "Keine Kontaktdaten — über Bearbeiten (Stift oben links) ergänzen"
                         : "Keine Angaben")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Label("Kontakt", systemImage: "person.text.rectangle")
            }

            // Grünbuch Cloud: Einladungscode (nur Lehrer)
            if isTeacher {
                Section {
                    if !cloud.isConfigured || !cloud.isSignedIn {
                        Text("cloud.invite_needs_login")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let code = currentStudent.inviteCode {
                        VStack(alignment: .leading, spacing: 8) {
                            if currentStudent.cloudUserID != nil {
                                // Verbunden: Code hat seinen Dienst getan
                                // und verschwindet aus der Ansicht.
                                Label("cloud.invite_redeemed", systemImage: "checkmark.icloud.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            } else {
                                HStack {
                                    Text(code)
                                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                                        .kerning(3)
                                        .foregroundStyle(ALColor.green)
                                    Spacer()
                                    ShareLink(item: String(format: String(localized: "cloud.invite_share_text"), code)) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.title3)
                                    }
                                }
                                Label("cloud.invite_pending", systemImage: "hourglass")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .task {
                                        if let uid = await cloud.redeemedUserID(forCode: code) {
                                            var updated = currentStudent
                                            updated.cloudUserID = uid
                                            store.updateStudent(updated)
                                        }
                                    }
                            }

                            // Für Gerätewechsel oder gelöschte App: frischer Code,
                            // alte Verknüpfung wird dabei verworfen.
                            Button {
                                isCreatingCode = true
                                Task {
                                    if let newCode = await cloud.createInviteCode(forLocalStudent: currentStudent.id) {
                                        var updated = currentStudent
                                        updated.inviteCode = newCode
                                        updated.cloudUserID = nil
                                        store.updateStudent(updated)
                                    }
                                    isCreatingCode = false
                                }
                            } label: {
                                Label("cloud.invite_renew", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .disabled(isCreatingCode)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            isCreatingCode = true
                            Task {
                                if let code = await cloud.createInviteCode(forLocalStudent: currentStudent.id) {
                                    var updated = currentStudent
                                    updated.inviteCode = code
                                    store.updateStudent(updated)
                                }
                                isCreatingCode = false
                            }
                        } label: {
                            if isCreatingCode {
                                ProgressView()
                            } else {
                                Label("cloud.invite_create", systemImage: "qrcode")
                            }
                        }
                    }
                } header: {
                    Label("cloud.invite_header", systemImage: "icloud")
                        .foregroundStyle(ALColor.green)
                } footer: {
                    Text("cloud.invite_footer")
                }
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

            // Letzte Schüler-Rückmeldung (wird per Import aktualisiert)
            Section {
                if currentStudent.remarks.isEmpty && currentStudent.feedbackHistory.isEmpty {
                    Text("Noch keine Rückmeldung — Antworten des Schülers aus der Cloud erscheinen hier automatisch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(currentStudent.remarks.isEmpty
                         ? (currentStudent.feedbackHistory.first?.message ?? "")
                         : currentStudent.remarks)
                        .font(.subheadline)
                }
            } header: {
                Label("Letzte Rückmeldung", systemImage: "text.bubble")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Tab 1 — Verlauf (alles Gesendete, Stunden, Aufnahmen, Rückmeldungen)

    var verlaufTab: some View {
        List {
            // Nachbesprechungen (Composer-Pakete)
            Section {
                if currentStudent.sentHistory.isEmpty {
                    Text("Noch keine Nachbesprechung — Composer erstellt Pakete aus der Bibliothek.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                                    HStack(spacing: 6) {
                                        Text("\(pkg.lessonTitles.count) Lektionen")
                                            .font(.caption).foregroundStyle(.secondary)
                                        ShareStatusBadge(status: store.packageStatus(pkg, for: currentStudent))
                                    }
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
                Label(String(format: String(localized: "Nachbesprechungen (%d)"), currentStudent.sentHistory.count), systemImage: "paperplane.fill")
                    .foregroundStyle(Color(hex: "1565C0"))
            }

            // Gesendete Mitteilungen ("Zettel vom Pro") mit Gelesen-Häkchen
            if isTeacher {
                let sentMessages = store.proMessages.filter { $0.localStudentID == currentStudent.id }
                if !sentMessages.isEmpty {
                    Section {
                        ForEach(sentMessages) { message in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ALColor.gold)
                                    .alIconTile(tint: ALColor.gold, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(message.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Text(message.body)
                                        .font(.subheadline)
                                }
                                Spacer(minLength: 4)
                                if message.readDate != nil {
                                    Label("Gelesen", systemImage: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                        .labelStyle(.iconOnly)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Label("Mitteilungen", systemImage: "envelope.fill")
                            .foregroundStyle(ALColor.gold)
                    }
                }
            }

            // Zugewiesene Lektionen mit Gesehen-Status
            if !assignedLessons.isEmpty {
                Section {
                    ForEach(assignedLessons) { lesson in
                        let viewed = currentStudent.viewedLessonIDs.contains(lesson.id)
                        HStack(spacing: 10) {
                            Image(systemName: lesson.icon)
                                .foregroundStyle(ALColor.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.subheadline.bold())
                                Text(viewed ? "Gesehen" : "Zugewiesen")
                                    .font(.caption)
                                    .foregroundStyle(viewed ? .green : .secondary)
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Label("Zugewiesene Lektionen (\(assignedLessons.count))", systemImage: "rectangle.stack.fill")
                        .foregroundStyle(ALColor.green)
                }
            }

            Section {
                if liveCaptures.isEmpty {
                    Text("Noch keine Live-Aufnahmen — während der Stunde Foto, Video oder Notiz erfassen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(liveCaptures) { capture in
                        studentCaptureRow(capture)
                    }
                }
            } header: {
                Label("Live-Aufnahmen (\(liveCaptures.count))", systemImage: "camera.fill")
                    .foregroundStyle(ALColor.gold)
            }

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
                        Button { selectedSession = session } label: {
                            VStack(alignment: .leading, spacing: 8) {
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
                                            .foregroundStyle(.primary)
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                if !session.trained.isEmpty {
                                    sessionChip(icon: "figure.walk", text: session.trained, color: ALColor.green)
                                }
                                let linked = store.capturesFor(session: session)
                                if !linked.isEmpty {
                                    Text("\(linked.count) Aufnahme\(linked.count == 1 ? "" : "n") verknüpft")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Label("Stundenprotokolle (\(trainingSessions.count))", systemImage: "figure.golf")
                    .foregroundStyle(ALColor.green)
            }

            if !currentStudent.feedbackHistory.isEmpty {
                Section {
                    ForEach(currentStudent.feedbackHistory) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: entry.kind.icon)
                                    .foregroundStyle(ALColor.gold)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(entry.kind.label)
                                    .font(.caption2.bold())
                                    .foregroundStyle(ALColor.gold)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(ALColor.gold.opacity(0.12), in: Capsule())
                            }
                            Text(entry.message)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Rückmeldungen", systemImage: "text.bubble.fill")
                        .foregroundStyle(ALColor.gold)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    func studentCaptureRow(_ capture: StudentCapture) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: capture.type.colorHex).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: capture.type.icon)
                    .foregroundStyle(Color(hex: capture.type.colorHex))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(capture.title)
                    .font(.subheadline.bold())
                if capture.type == .text {
                    Text(capture.textNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(capture.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if capture.type == .image,
               let filename = capture.filename,
               let img = UIImage(contentsOfFile: store.imageURL(for: filename).path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if capture.type == .video,
                      let thumb = capture.thumbnailFilename,
                      let img = UIImage(contentsOfFile: store.imageURL(for: thumb).path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(Image(systemName: "play.fill").font(.caption2).foregroundStyle(.white))
            }
        }
        .padding(.vertical, 4)
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
