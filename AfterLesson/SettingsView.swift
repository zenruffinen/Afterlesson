import SwiftUI
import StoreKit
import UniformTypeIdentifiers

// MARK: - Wusstest du? Karte

private struct GrünbuchTip {
    let icon: String
    let textKey: String
    let tint: Color
}

struct GrünbuchDidYouKnowCard: View {
    private static let tips: [GrünbuchTip] = [
        GrünbuchTip(icon: "square.stack.3d.up.fill", textKey: "settings.tip.composer", tint: ALColor.green),
        GrünbuchTip(icon: "books.vertical.fill", textKey: "settings.tip.library", tint: .blue),
        GrünbuchTip(icon: "icloud.and.arrow.up.fill", textKey: "settings.tip.airdrop", tint: .cyan),
        GrünbuchTip(icon: "figure.golf", textKey: "settings.tip.session", tint: ALColor.gold),
        GrünbuchTip(icon: "person.2.fill", textKey: "settings.tip.students", tint: .orange),
        GrünbuchTip(icon: "text.bubble.fill", textKey: "settings.tip.feedback", tint: .purple),
        GrünbuchTip(icon: "lock.shield.fill", textKey: "settings.tip.lock", tint: .green),
        GrünbuchTip(icon: "photo.on.rectangle.angled", textKey: "settings.tip.capture", tint: .teal),
        GrünbuchTip(icon: "checkmark.circle.fill", textKey: "settings.tip.progress", tint: Color(hex: "2D6A30")),
        GrünbuchTip(icon: "square.and.arrow.up.fill", textKey: "settings.tip.backup", tint: .indigo),
        GrünbuchTip(icon: "road.lanes", textKey: "settings.tip.paths", tint: .pink),
        GrünbuchTip(icon: "mic.fill", textKey: "settings.tip.notes", tint: .yellow),
    ]

    @State private var index = Int.random(in: 0..<GrünbuchDidYouKnowCard.tips.count)

    private var tip: GrünbuchTip { Self.tips[index] }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                var next = index
                while next == index && Self.tips.count > 1 {
                    next = Int.random(in: 0..<Self.tips.count)
                }
                index = next
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: tip.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tip.tint)
                    .frame(width: 44, height: 44)
                    .background(tip.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("settings.did_you_know"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tip.tint)
                    Text(LocalizedStringKey(tip.textKey))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tip.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rate & Feedback

struct GrünbuchRateAppRow: View {
    /// Numerische App-Store-ID — leer bis Grünbuch im Store ist.
    private let appStoreID = ""

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Button {
            if !appStoreID.isEmpty,
               let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
                UIApplication.shared.open(url)
            } else {
                requestReview()
            }
        } label: {
            HStack {
                Label("settings.rate_app", systemImage: "star.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}

struct GrünbuchFeedbackLinkRow: View {
    let url: URL?
    private let email = "support@hansruffin.ch"

    @State private var showCopiedAlert = false

    private var canOpenMail: Bool {
        guard let url else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    var body: some View {
        Button {
            if let url, canOpenMail {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = email
                showCopiedAlert = true
            }
        } label: {
            HStack {
                Label("settings.send_feedback", systemImage: "envelope.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .alert("settings.email_copied_title", isPresented: $showCopiedAlert) {
            Button("Fertig", role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("settings.email_copied_message", comment: ""), email))
        }
    }
}

// MARK: - Handoff Info

struct HandoffInfoSection: View {
    private let bullets = [
        "settings.handoff.bullet1",
        "settings.handoff.bullet2",
        "settings.handoff.bullet3",
    ]

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(bullets, id: \.self) { key in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(ALColor.green)
                            .padding(.top, 6)
                        Text(LocalizedStringKey(key))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("settings.handoff.title", systemImage: "icloud.and.arrow.up.fill")
        }.listRowBackground(ALColor.nachtOben.opacity(0.55))
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showTeacherPIN = false

    @State private var showExportPasswordSheet = false
    @State private var exportPassword = ""
    @State private var exportPasswordConfirm = ""
    @State private var exportPasswordError = ""
    @State private var showExportPassword = false
    @State private var exportURL: URL? = nil

    @State private var showImportPicker = false
    @State private var pendingImportURL: URL? = nil
    @State private var showImportPasswordSheet = false
    @State private var importPassword = ""
    @State private var showImportPasswordReveal = false
    @State private var importMerge = true
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    private var isTeacher: Bool { store.appMode == AppMode.teacher.rawValue }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var feedbackURL: URL? {
        let subject = String(format: NSLocalizedString("settings.feedback_subject", comment: ""), appVersion)
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@hansruffin.ch"
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(
                        String(format: NSLocalizedString("settings.version_label", comment: ""), appVersion),
                        systemImage: "app.badge"
                    )
                    Label("settings.developer", systemImage: "person.fill")
                    GrünbuchRateAppRow()
                    GrünbuchFeedbackLinkRow(url: feedbackURL)
                } header: {
                    Text("settings.about_header")
                } footer: {
                    Text("settings.about_footer")
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))


                Section {
                    Button {
                        exportPassword = ""
                        exportPasswordConfirm = ""
                        exportPasswordError = ""
                        showExportPassword = false
                        showExportPasswordSheet = true
                    } label: {
                        Label("settings.backup_export", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(.blue)
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("settings.backup_import", systemImage: "square.and.arrow.down.fill")
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("settings.backup_header")
                } footer: {
                    Text("settings.backup_footer")
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))

                GrünbuchCloudSection()

                Section {
                    HStack {
                        Image(systemName: isTeacher ? "person.badge.key.fill" : "graduationcap.fill")
                            .foregroundStyle(isTeacher ? ALColor.gold : ALColor.green)
                        Text(isTeacher ? "settings.mode_teacher" : "settings.mode_student")
                        Spacer()
                        Button("Wechseln") {
                            if isTeacher {
                                store.appMode = AppMode.student.rawValue
                            } else {
                                showTeacherPIN = true
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }

                    Toggle(isOn: Binding(
                        get: { store.lockEnabled },
                        set: { enabled in
                            store.lockEnabled = enabled
                            if enabled { store.isLocked = true }
                        }
                    )) {
                        Label("Bildschirmsperre", systemImage: "lock.shield.fill")
                    }
                    .tint(ALColor.green)
                } header: {
                    Text("settings.mode_security_header")
                } footer: {
                    if store.lockEnabled {
                        Text("settings.lock_footer")
                    }
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))

                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("settings.privacy", systemImage: "hand.raised.fill")
                    }
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))

                Section {
                    GrünbuchDidYouKnowCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } footer: {
                    Label("settings.privacy_footer", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))
            }
            .gruenbuchSeite()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("Einstellungen")
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showTeacherPIN) {
                TeacherModePINGate(isGranted: Binding(
                    get: { store.appMode == AppMode.teacher.rawValue },
                    set: { granted in if granted { store.appMode = AppMode.teacher.rawValue } }
                ))
            }
            .sheet(isPresented: $showExportPasswordSheet, onDismiss: {
                if let url = exportURL {
                    // Direkt übers System teilen — kein schwarzes Blatt mehr
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        TeilenHelfer.praesentiere([url])
                        exportURL = nil
                    }
                }
            }) {
                backupPasswordSheet(
                    title: "settings.backup_export",
                    header: "settings.backup_password_set_header",
                    footer: "settings.backup_password_set_footer",
                    password: $exportPassword,
                    confirmPassword: $exportPasswordConfirm,
                    showPassword: $showExportPassword,
                    error: exportPasswordError,
                    confirmLabel: "settings.backup_save",
                    onCancel: {
                        exportURL = nil
                        showExportPasswordSheet = false
                    },
                    onConfirm: {
                        guard exportPassword.count >= 4 else {
                            exportPasswordError = NSLocalizedString("settings.backup_password_min", comment: "")
                            return
                        }
                        guard exportPassword == exportPasswordConfirm else {
                            exportPasswordError = NSLocalizedString("settings.backup_password_mismatch", comment: "")
                            return
                        }
                        if let url = store.exportData(password: exportPassword) {
                            exportURL = url
                            showExportPasswordSheet = false
                        } else {
                            exportPasswordError = NSLocalizedString("settings.backup_export_failed", comment: "")
                        }
                    }
                )
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.data]) { result in
                if case .success(let url) = result {
                    pendingImportURL = url
                    importPassword = ""
                    showImportPasswordSheet = true
                }
            }
            .onChange(of: store.pendingBackupURL) { _, url in
                guard let url else { return }
                pendingImportURL = url
                importPassword = ""
                store.pendingBackupURL = nil
                showImportPasswordSheet = true
            }
            .sheet(isPresented: $showImportPasswordSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Group {
                                    if showImportPasswordReveal {
                                        TextField("settings.backup_password", text: $importPassword)
                                    } else {
                                        SecureField("settings.backup_password", text: $importPassword)
                                    }
                                }
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                Button {
                                    showImportPasswordReveal.toggle()
                                } label: {
                                    Image(systemName: showImportPasswordReveal ? "eye.slash" : "eye")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        } header: {
                            Text("settings.backup_password_enter_header")
                        } footer: {
                            Text("settings.backup_password_enter_footer")
                        }.listRowBackground(ALColor.nachtOben.opacity(0.55))

                        Section {
                            Toggle(isOn: $importMerge) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("settings.backup_merge")
                                    Text("settings.backup_merge_hint")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } footer: {
                            Text(importMerge
                                 ? NSLocalizedString("settings.backup_merge_safe", comment: "")
                                 : NSLocalizedString("settings.backup_merge_replace", comment: ""))
                                .foregroundStyle(importMerge ? .green : .orange)
                        }.listRowBackground(ALColor.nachtOben.opacity(0.55))
                    }
                    .gruenbuchSeite()
            .navigationTitle("settings.backup_restore_title")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                showImportPasswordSheet = false
                                pendingImportURL = nil
                                showImportPasswordReveal = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(importMerge
                                   ? NSLocalizedString("settings.backup_merge_action", comment: "")
                                   : NSLocalizedString("settings.backup_replace_action", comment: "")) {
                                guard let url = pendingImportURL else { return }
                                showImportPasswordSheet = false
                                showImportPasswordReveal = false
                                let mergeMode = importMerge
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if store.importData(from: url, password: importPassword, merge: mergeMode) {
                                        showImportSuccess = true
                                    } else {
                                        importErrorMessage = NSLocalizedString("settings.backup_import_failed", comment: "")
                                        showImportError = true
                                    }
                                    pendingImportURL = nil
                                }
                            }
                            .disabled(importPassword.isEmpty)
                        }
                    }
                }
            }
            .alert("settings.backup_import_success_title", isPresented: $showImportSuccess) {
                Button("Fertig", role: .cancel) {}
            } message: {
                Text("settings.backup_import_success_message")
            }
            .alert("settings.backup_import_error_title", isPresented: $showImportError) {
                Button("Fertig", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
    }

    @ViewBuilder
    private func backupPasswordSheet(
        title: LocalizedStringKey,
        header: LocalizedStringKey,
        footer: LocalizedStringKey,
        password: Binding<String>,
        confirmPassword: Binding<String>,
        showPassword: Binding<Bool>,
        error: String,
        confirmLabel: LocalizedStringKey,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if showPassword.wrappedValue {
                                TextField("settings.backup_password", text: password)
                            } else {
                                SecureField("settings.backup_password", text: password)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                        Button {
                            showPassword.wrappedValue.toggle()
                        } label: {
                            Image(systemName: showPassword.wrappedValue ? "eye.slash" : "eye")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                    HStack {
                        Group {
                            if showPassword.wrappedValue {
                                TextField("settings.backup_password_confirm", text: confirmPassword)
                            } else {
                                SecureField("settings.backup_password_confirm", text: confirmPassword)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text(header)
                } footer: {
                    Text(footer)
                }.listRowBackground(ALColor.nachtOben.opacity(0.55))
                if !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }.listRowBackground(ALColor.nachtOben.opacity(0.55))
                }
            }
            .gruenbuchSeite()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel, action: onConfirm)
                        .disabled(password.wrappedValue.isEmpty)
                }
            }
        }
    }
}
