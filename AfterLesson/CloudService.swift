//
//  CloudService.swift
//  Grünbuch — Cloud (Supabase)
//
//  Die eine Anlaufstelle für alles Cloud: Anmeldung (Sign in with
//  Apple), Profil und — in der nächsten Ausbaustufe — der Versand
//  von Lektionen und Stunden an Schüler, egal wo sie sind.
//
//  Ohne Konfiguration (CloudConfig leer) tut dieser Dienst nichts;
//  die App bleibt dann eine reine AirDrop-App wie bisher.
//

import Foundation
import Combine
import CryptoKit
import Supabase

@MainActor
final class CloudService: ObservableObject {

    static let shared = CloudService()

    /// Nil, solange CloudConfig leer ist — dann ist die Cloud aus.
    let client: SupabaseClient?

    @Published private(set) var userID: UUID?
    @Published private(set) var userEmail: String?
    @Published var lastErrorMessage: String?

    var isConfigured: Bool { client != nil }
    var isSignedIn: Bool { userID != nil }

    private init() {
        if CloudConfig.isConfigured, let url = URL(string: CloudConfig.supabaseURL) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: CloudConfig.supabaseAnonKey)
        } else {
            client = nil
        }
        Task { await observeAuthChanges() }
    }

    /// Hält userID/userEmail aktuell — auch nach App-Neustart
    /// (Supabase speichert die Sitzung selbst im Schlüsselbund).
    private func observeAuthChanges() async {
        guard let client else { return }
        for await (_, session) in client.auth.authStateChanges {
            userID = session?.user.id
            userEmail = session?.user.email
        }
    }

    // MARK: - Sign in with Apple

    /// Meldet den Nutzer mit dem Apple-Identitätstoken bei Supabase an
    /// und legt sein Profil an (bzw. aktualisiert es).
    func signInWithApple(idToken: String, nonce: String, displayName: String?, role: String) async {
        guard let client else { return }
        do {
            _ = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            try await upsertProfile(displayName: displayName, role: role)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }

    // MARK: - E-Mail + Passwort (Plan B, solange die iOS-27-Beta
    // "Sign in with Apple" serverseitig blockiert — und dauerhaft
    // nützlich für Test-Konten mit verschiedenen Rollen)

    func signUpWithEmail(_ email: String, password: String, displayName: String?, role: String) async {
        guard let client else { return }
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            try await upsertProfile(displayName: displayName, role: role)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func signInWithEmail(_ email: String, password: String, displayName: String?, role: String) async {
        guard let client else { return }
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            try await upsertProfile(displayName: displayName, role: role)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Profil

    private struct CloudProfile: Codable {
        let id: UUID
        let role: String
        let display_name: String?
    }

    /// Legt die Profilzeile des angemeldeten Nutzers an oder
    /// aktualisiert sie (Rolle: "teacher" oder "student").
    private func upsertProfile(displayName: String?, role: String) async throws {
        guard let client, let userID = try? await client.auth.session.user.id else { return }
        let profile = CloudProfile(id: userID, role: role, display_name: displayName)
        try await client.from("profiles").upsert(profile).execute()
    }

    // MARK: - Nonce-Helfer für Sign in with Apple

    /// Zufälliger Einmalwert — Apple bekommt den Hash, Supabase das Original.
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
