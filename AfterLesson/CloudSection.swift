//
//  CloudSection.swift
//  Grünbuch — Cloud (Supabase)
//
//  Der Cloud-Bereich in den Einstellungen: Sign in with Apple,
//  Anmelde-Status, Abmelden. Erscheint nur informativ-grau,
//  solange CloudConfig noch leer ist.
//

import SwiftUI
import AuthenticationServices

struct GrünbuchCloudSection: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var cloud = CloudService.shared
    @State private var currentNonce: String?
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    private var emailFormValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private var currentRole: String {
        store.appMode == AppMode.teacher.rawValue ? "teacher" : "student"
    }

    private func emailAction(register: Bool) async {
        isWorking = true
        defer { isWorking = false }
        let name = store.teacherName.isEmpty ? nil : store.teacherName
        if register {
            await CloudService.shared.signUpWithEmail(email, password: password, displayName: name, role: currentRole)
        } else {
            await CloudService.shared.signInWithEmail(email, password: password, displayName: name, role: currentRole)
        }
    }

    var body: some View {
        Section {
            if !cloud.isConfigured {
                Label("cloud.not_configured", systemImage: "icloud.slash")
                    .foregroundStyle(.secondary)
            } else if cloud.isSignedIn {
                HStack {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("cloud.signed_in")
                        if let mail = cloud.userEmail {
                            Text(mail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button(role: .destructive) {
                    Task { await cloud.signOut() }
                } label: {
                    Label("cloud.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = CloudService.randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName]
                    request.nonce = CloudService.sha256(nonce)
                } onCompletion: { result in
                    handleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .listRowBackground(Color.clear)

                TextField("cloud.email_placeholder", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("cloud.password_placeholder", text: $password)
                    .textContentType(.password)

                HStack {
                    Button("cloud.email_sign_in") {
                        Task { await emailAction(register: false) }
                    }
                    .disabled(!emailFormValid || isWorking)

                    Spacer()

                    Button("cloud.email_register") {
                        Task { await emailAction(register: true) }
                    }
                    .disabled(!emailFormValid || isWorking)
                }

                if isWorking {
                    ProgressView()
                }

                if let error = cloud.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("cloud.header")
        } footer: {
            Text(cloud.isConfigured ? "cloud.footer" : "cloud.footer_not_configured")
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        if case .failure(let error) = result {
            let code = (error as? ASAuthorizationError).map { " (Code \($0.code.rawValue))" } ?? ""
            // Abbruch durch den Nutzer ist kein Fehler, den wir anzeigen müssen
            if (error as? ASAuthorizationError)?.code != .canceled {
                CloudService.shared.lastErrorMessage = "Apple: \(error.localizedDescription)\(code)"
            }
            return
        }
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            CloudService.shared.lastErrorMessage = "Apple-Antwort unvollständig (kein Token)"
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let displayName = name.isEmpty ? store.teacherName : name
        let role = store.appMode == AppMode.teacher.rawValue ? "teacher" : "student"
        Task {
            await CloudService.shared.signInWithApple(
                idToken: idToken,
                nonce: nonce,
                displayName: displayName.isEmpty ? nil : displayName,
                role: role
            )
        }
    }
}
