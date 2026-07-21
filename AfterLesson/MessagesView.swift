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
                                        .fill(Color(.secondarySystemBackground))
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
                                    .fill(Color(.secondarySystemBackground))
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
            if result.sent > 0 {
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
                Capsule().fill(isOn ? ALColor.green : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isOn ? .white : .primary)
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
                        Text(store.teacherName.isEmpty ? "Dein Pro" : store.teacherName)
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
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isReplying)
                        }
                    }
                }
            }
            .padding(20)
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
            let ok = await CloudService.shared.sendResponseToPro(text)
            isReplying = false
            if ok { replySent = true }
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
