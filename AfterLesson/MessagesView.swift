// MessagesView – Mitteilungen: der "Zettel vom Pro".
// Pro: Umschlag-Kachel auf dem Start → Sende-Blatt (Empfänger-Chips,
// Vorlagen, ein grüner Knopf). Schüler: Lese-Blatt mit Schnellantworten.
// Bewusst KEIN Chat — der Pro schreibt, der Schüler quittiert.

import SwiftUI

// MARK: - Sende-Blatt (Pro)

struct MessageComposeSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// Optional mit vorgewähltem Schüler öffnen (z.B. aus der Kartei).
    var preselectedStudentID: UUID? = nil

    @State private var selectedIDs: Set<UUID> = []
    @State private var text: String = ""
    @State private var isSending = false
    @State private var resultMessage: String? = nil

    /// Nur verbundene Schüler können Mitteilungen empfangen.
    private var connectedStudents: [Student] {
        store.students
            .filter { $0.cloudUserID != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var unconnectedCount: Int {
        store.students.count - connectedStudents.count
    }

    private var allSelected: Bool {
        !connectedStudents.isEmpty && selectedIDs.count == connectedStudents.count
    }

    private var canSend: Bool {
        !selectedIDs.isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
    }

    /// Die drei Vorlagen — ein Tipper füllt das Textfeld.
    private let templates: [(icon: String, text: String)] = [
        ("hands.clap.fill", "Das hat heute gut geklappt, weiter so! 👏"),
        ("calendar.badge.exclamationmark", "Die nächste Stunde fällt leider aus. Ich melde mich für einen neuen Termin."),
        ("bubble.left.and.bubble.right.fill", "Bitte melde dich kurz bei mir."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Empfänger
                    VStack(alignment: .leading, spacing: 10) {
                        Label("An wen?", systemImage: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if connectedStudents.isEmpty {
                            Text("Noch kein Schüler über die Cloud verbunden. Erzeuge in der Kartei einen Einladungscode.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            FlowChips {
                                recipientChip(
                                    title: "Alle",
                                    icon: "person.3.fill",
                                    isOn: allSelected
                                ) {
                                    selectedIDs = allSelected ? [] : Set(connectedStudents.map(\.id))
                                }
                                ForEach(connectedStudents) { student in
                                    recipientChip(
                                        title: student.name,
                                        icon: nil,
                                        isOn: selectedIDs.contains(student.id)
                                    ) {
                                        if selectedIDs.contains(student.id) {
                                            selectedIDs.remove(student.id)
                                        } else {
                                            selectedIDs.insert(student.id)
                                        }
                                    }
                                }
                            }
                            if unconnectedCount > 0 {
                                Text("\(unconnectedCount) Schüler ohne Cloud-Verbindung werden hier nicht angezeigt.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Vorlagen
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Vorlagen", systemImage: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(templates, id: \.text) { template in
                            Button {
                                text = template.text
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: template.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(ALColor.gold)
                                        .frame(width: 24)
                                    Text(template.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ALColor.nachtOben.opacity(0.55))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Deine Mitteilung", systemImage: "envelope.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("Kurz und freundlich …", text: $text, axis: .vertical)
                            .lineLimit(4...8)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ALColor.nachtOben.opacity(0.55))
                            )
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                // Bilanz-Knopf: sagt in Klartext, was gleich passiert
                Button {
                    send()
                } label: {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(sendButtonTitle)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(ALColor.green)
                .disabled(!canSend)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .gruenbuchSeite()
            .navigationTitle("Mitteilung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .alert("Mitteilung", isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil; dismiss() } }
            )) {
                Button("OK") { resultMessage = nil; dismiss() }
            } message: {
                Text(resultMessage ?? "")
            }
            .onAppear {
                if let pre = preselectedStudentID,
                   connectedStudents.contains(where: { $0.id == pre }) {
                    selectedIDs = [pre]
                }
            }
        }
    }

    private var sendButtonTitle: String {
        if selectedIDs.isEmpty { return "Empfänger wählen" }
        if allSelected && connectedStudents.count > 1 {
            return "An alle \(connectedStudents.count) Schüler senden"
        }
        if selectedIDs.count == 1,
           let student = connectedStudents.first(where: { selectedIDs.contains($0.id) }) {
            return "An \(student.name) senden"
        }
        return "An \(selectedIDs.count) Schüler senden"
    }

    private func send() {
        guard canSend else { return }
        isSending = true
        Task {
            let result = await store.sendProMessage(text, toLocalStudentIDs: Array(selectedIDs))
            isSending = false
            if result.wartend {
                resultMessage = "Kein Netz — die Mitteilung liegt im Postausgang und geht automatisch raus, sobald Empfang da ist."
            } else if result.sent > 0 {
                resultMessage = result.sent == 1
                    ? "Mitteilung gesendet."
                    : "Mitteilung an \(result.sent) Schüler gesendet."
            } else {
                resultMessage = CloudService.shared.lastErrorMessage ?? "Senden hat nicht geklappt. Bitte später erneut versuchen."
            }
        }
    }

    @ViewBuilder
    private func recipientChip(title: String, icon: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isOn
                        ? AnyShapeStyle(LinearGradient(colors: [ALColor.nachtOben, ALColor.nachtUnten],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(ALColor.nachtOben.opacity(0.55))
                )
            )
            .overlay(
                Capsule().strokeBorder(isOn ? ALColor.goldHell.opacity(0.8) : Color.white.opacity(0.14),
                                       lineWidth: isOn ? 1.2 : 0.5)
            )
            .foregroundStyle(isOn ? ALColor.goldHell : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lese-Blatt (Schüler)

struct StudentMessageSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let message: ProMessage

    @State private var replySent = false
    @State private var isReplying = false

    private let quickReplies: [(icon: String, text: String)] = [
        ("hand.thumbsup.fill", "Danke!"),
        ("checkmark.circle.fill", "Erledigt"),
        ("questionmark.circle.fill", "Ich habe eine Frage — bitte melde dich."),
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ALColor.gold)
                        .alIconTile(tint: ALColor.gold, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.proName.isEmpty ? "Dein Pro" : store.proName)
                            .font(.headline)
                        Text(message.date.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ScrollView {
                    Text(message.body)
                        .font(.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Aufräumen: Archiv bewahrt, Löschen entfernt endgültig
                HStack(spacing: 10) {
                    Button {
                        store.archiveProMessage(message, archived: message.archivedDate == nil)
                        dismiss()
                    } label: {
                        Label(message.archivedDate == nil ? "Archivieren" : "Zurückholen",
                              systemImage: message.archivedDate == nil ? "archivebox" : "arrow.uturn.backward")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(ALColor.green)

                    Button(role: .destructive) {
                        store.deleteProMessage(message)
                        dismiss()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }

                if replySent {
                    Label("Antwort ist unterwegs zu deinem Pro.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ALColor.green)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Schnellantwort")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(quickReplies, id: \.text) { reply in
                            Button {
                                sendReply(reply.text)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: reply.icon)
                                        .foregroundStyle(ALColor.green)
                                        .frame(width: 24)
                                    Text(reply.text)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ALColor.nachtOben.opacity(0.55))
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isReplying)
                        }
                    }
                }
            }
            .padding(20)
            .gruenbuchSeite()
            .navigationTitle("Mitteilung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear {
                store.markProMessageRead(message)
            }
        }
    }

    private func sendReply(_ text: String) {
        isReplying = true
        Task {
            let ergebnis = await store.sendeAntwort(text)
            isReplying = false
            if ergebnis.ok || ergebnis.wartend { replySent = true }
        }
    }
}

// MARK: - Nachrichten-Eingang (Glocke, beide Rollen)

/// Der Eingang hinter der Glocke: Beim Pro alle Schüler-Antworten,
/// beim Schüler alle Mitteilungen des Pros (Antippen öffnet das
/// Lese-Blatt mit den Schnellantworten). Neueste zuerst.
struct NachrichtenEingangSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMessage: ProMessage? = nil

    private var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    private struct Eintrag: Identifiable {
        let id: UUID
        let studentName: String
        let avatarColor: String
        let entry: StudentFeedbackEntry
    }

    private var eintraege: [Eintrag] {
        store.students
            .flatMap { student in
                student.feedbackHistory.map {
                    Eintrag(id: $0.id, studentName: student.name,
                            avatarColor: student.avatarColor, entry: $0)
                }
            }
            .sorted { $0.entry.date > $1.entry.date }
    }

    private var schuelerNachrichten: [ProMessage] {
        store.proMessages
            .filter { $0.archivedDate == nil }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if isTeacher {
                    proEingang
                        .listRowBackground(ALColor.nachtOben.opacity(0.55))
                } else {
                    schuelerEingang
                        .listRowBackground(ALColor.nachtOben.opacity(0.55))
                }
            }
            .gruenbuchSeite()
            .navigationTitle("Nachrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $selectedMessage) { message in
                StudentMessageSheet(message: message)
            }
            // Beim Öffnen frisch aus der Cloud nachschauen
            .task {
                if isTeacher {
                    _ = await store.importCloudResponses()
                } else {
                    _ = await store.importCloudMessages()
                }
            }
        }
    }

    @ViewBuilder
    private var proEingang: some View {
        if eintraege.isEmpty {
            Text("Noch keine Nachrichten — Antworten deiner Schüler landen hier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(eintraege) { e in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: e.avatarColor))
                            .frame(width: 36, height: 36)
                        Text(String(e.studentName.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(e.studentName)
                                .font(.subheadline.bold())
                            Text(e.entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(e.entry.message)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    @ViewBuilder
    private var schuelerEingang: some View {
        if schuelerNachrichten.isEmpty {
            Text("Noch keine Mitteilungen — was dein Pro dir schreibt, landet hier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(schuelerNachrichten) { message in
                Button {
                    selectedMessage = message
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: message.readDate == nil ? "envelope.badge.fill" : "envelope.open.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ALColor.gold)
                            .alIconTile(tint: ALColor.gold, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                if message.readDate == nil {
                                    Circle()
                                        .fill(ALColor.gold)
                                        .frame(width: 7, height: 7)
                                }
                                Text(store.proName.isEmpty ? "Dein Pro" : store.proName)
                                    .font(.subheadline.bold())
                                Text(message.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(message.body)
                                .font(.subheadline.weight(message.readDate == nil ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                            .padding(.top, 10)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Archiv der Mitteilungen (Schüler)

struct MessageArchiveSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var archived: [ProMessage] {
        store.proMessages.filter { $0.archivedDate != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if archived.isEmpty {
                    Text("Das Archiv ist leer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(ALColor.nachtOben.opacity(0.55))
                } else {
                    ForEach(archived) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(message.body)
                                .font(.subheadline)
                            HStack(spacing: 16) {
                                Button {
                                    store.archiveProMessage(message, archived: false)
                                } label: {
                                    Label("Zurückholen", systemImage: "arrow.uturn.backward")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(.borderless)
                                .tint(ALColor.green)
                                Button(role: .destructive) {
                                    store.deleteProMessage(message)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(ALColor.nachtOben.opacity(0.55))
                }
            }
            .gruenbuchSeite()
            .navigationTitle("Archiv")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Chips-Fluss (bricht Zeilen wie ein Absatz um)

struct FlowChips: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
