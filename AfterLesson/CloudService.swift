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
import UserNotifications
import UIKit

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

    /// Fehler festhalten — aber Task-Abbrüche (CancellationError, z.B.
    /// wenn ein Blatt mitten im Abruf geschlossen wird) sind KEIN Fehler
    /// und werden verschluckt (30.07.: geisterhafte "Cloud-Fehler"-Alerts).
    func meldeFehler(_ error: Error) {
        guard !(error is CancellationError) else { return }
        meldeFehler(error)
    }

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
            let previousID = userID
            userID = session?.user.id
            userEmail = session?.user.email
            // Bei JEDEM Kontowechsel das Klingelzeichen neu registrieren —
            // auch wenn ein Schüler direkt nacheinander zwei Codes einlöst
            // (jede Einlösung ist ein neues anonymes Konto; der Token muss
            // dem NEUESTEN gehören, sonst klingelt das alte).
            if let uid = userID, uid != previousID {
                enablePushIfPossible()
                if let token = letzterTokenHex {
                    Task { await self.registerDeviceToken(token) }
                }
            }
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
            meldeFehler(error)
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
            meldeFehler(error)
        }
    }

    func signInWithEmail(_ email: String, password: String, displayName: String?, role: String) async {
        guard let client else { return }
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            try await upsertProfile(displayName: displayName, role: role)
            lastErrorMessage = nil
        } catch {
            meldeFehler(error)
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

    // MARK: - Einladungscodes (Pro erzeugt, Schüler löst ein)

    private struct InviteRow: Codable {
        let code: String
        let pro_id: UUID
        let local_student_id: UUID
    }

    private struct InviteStatusRow: Codable {
        let code: String
        let used_by: UUID?
    }

    /// Erzeugt einen Einladungscode für einen Schüler und hinterlegt ihn
    /// in der Cloud. Ohne 0/O/1/I/L — am Platz gut vorlesbar.
    func createInviteCode(forLocalStudent localStudentID: UUID) async -> String? {
        guard let client, let proID = userID else { return nil }
        let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        let code = String((0..<6).map { _ in alphabet.randomElement()! })
        do {
            let row = InviteRow(code: code, pro_id: proID, local_student_id: localStudentID)
            try await client.from("invite_codes").insert(row).execute()
            lastErrorMessage = nil
            return code
        } catch {
            meldeFehler(error)
            return nil
        }
    }

    /// Prüft, ob der Code eines Schülers schon eingelöst wurde.
    /// Liefert die Cloud-Nutzer-ID des Schülers, sobald verbunden.
    func redeemedUserID(forCode code: String) async -> UUID? {
        guard let client else { return nil }
        do {
            let rows: [InviteStatusRow] = try await client.from("invite_codes")
                .select("code, used_by")
                .eq("code", value: code)
                .execute().value
            return rows.first?.used_by
        } catch {
            return nil
        }
    }

    /// Schüler-Anmeldung nur mit Code: legt (falls nötig) ein anonymes
    /// Cloud-Konto an und verknüpft es über den Code mit dem Pro.
    func signInStudent(withCode rawCode: String) async -> Bool {
        guard let client else { return false }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return false }
        do {
            if userID == nil {
                _ = try await client.auth.signInAnonymously()
            }
            // Erst das Profil anlegen — die Verknüpfung (pro_students)
            // verweist per Fremdschlüssel darauf.
            try await upsertProfile(displayName: nil, role: "student")
            let ok: Bool = try await client.rpc(
                "redeem_invite",
                params: ["invite_code": code]
            ).execute().value
            if ok {
                lastErrorMessage = nil
                return true
            } else {
                lastErrorMessage = String(localized: "cloud.code_invalid")
                return false
            }
        } catch {
            meldeFehler(error)
            return false
        }
    }

    // MARK: - Paket-Versand & Empfang (die Drehscheibe dreht sich)

    enum CloudError: Error {
        case notReady
    }

    /// Lädt eine Mediendatei in den eigenen Storage-Ordner des Pros.
    /// WICHTIG: UUID kleingeschrieben — die Storage-Schutzregel vergleicht
    /// den Ordnernamen als Text mit auth.uid() (immer klein).
    func uploadMedia(_ data: Data, filename: String) async throws {
        guard let client, let proID = userID else { throw CloudError.notReady }
        _ = try await client.storage.from("media").upload(
            "\(proID.uuidString.lowercased())/\(filename)",
            data: data,
            options: FileOptions(upsert: true)
        )
    }

    /// Holt eine Mediendatei aus dem Ordner des (verknüpften) Pros.
    func downloadMedia(proID: UUID, filename: String) async throws -> Data {
        guard let client else { throw CloudError.notReady }
        return try await client.storage.from("media").download(path: "\(proID.uuidString.lowercased())/\(filename)")
    }

    private struct PackageInsertRow: Codable {
        let pro_id: UUID
        let student_id: UUID
        let kind: String
        let title: String
        let payload: CloudLessonShare
    }

    /// Legt ein Lernpaket für einen verbundenen Schüler in die Drehscheibe.
    func insertPackage(title: String, payload: CloudLessonShare, to studentCloudID: UUID, kind: String = "lesson") async throws {
        guard let client, let proID = userID else { throw CloudError.notReady }
        let row = PackageInsertRow(
            pro_id: proID, student_id: studentCloudID,
            kind: kind, title: title, payload: payload
        )
        try await client.from("packages").insert(row).execute()
    }

    /// Schüler: alle an mich gesendeten Pakete (RLS filtert serverseitig).
    func fetchIncomingPackages() async -> [IncomingCloudPackage] {
        guard let client, isSignedIn else { return [] }
        do {
            return try await client.from("packages")
                .select("id, pro_id, title, payload, created_at")
                .order("created_at", ascending: false)
                .execute().value
        } catch {
            meldeFehler(error)
            return []
        }
    }

    /// Schüler: Lesestatus zurückmelden (Pro sieht "gesehen").
    func markPackageRead(_ packageID: UUID) async {
        guard let client else { return }
        struct ReadPatch: Codable { let read_at: Date }
        _ = try? await client.from("packages")
            .update(ReadPatch(read_at: Date()))
            .eq("id", value: packageID)
            .execute()
    }

    // MARK: - Push-Nachrichten

    /// Fragt (einmalig) nach Erlaubnis und registriert das Gerät bei
    /// Apple — das Token landet dann über den App-Delegate in der Cloud.
    func enablePushIfPossible() {
        guard isSignedIn else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private struct DeviceTokenRow: Codable {
        let token: String
        let user_id: UUID
    }

    /// Hinterlegt das Apple-Gerätetoken in der Drehscheibe, damit die
    /// Server-Funktion dieses Gerät erreichen kann.
    /// Das zuletzt gemeldete Gerätetoken — bei Kontowechsel wird es
    /// direkt neu registriert (30.07.: Token hing am verwaisten
    /// Erstversuch-Konto, weil didRegister nicht erneut feuerte).
    private(set) var letzterTokenHex: String? = nil

    func registerDeviceToken(_ tokenHex: String) async {
        letzterTokenHex = tokenHex
        guard let client, let uid = userID else { return }
        _ = try? await client.from("device_tokens")
            .upsert(DeviceTokenRow(token: tokenHex, user_id: uid))
            .execute()
    }

    // MARK: - Rückkanal (Schüler → Pro)

    private struct ProLinkRow: Codable {
        let pro_id: UUID
    }

    /// Der Pro, mit dem dieser Schüler verknüpft ist.
    func linkedProID() async -> UUID? {
        guard let client, let uid = userID else { return nil }
        let rows: [ProLinkRow]? = try? await client.from("pro_students")
            .select("pro_id")
            .eq("student_id", value: uid)
            .execute().value
        return rows?.first?.pro_id
    }

    /// Anzeigename des verbundenen Pros (aus seinem Cloud-Profil).
    func linkedProName() async -> String? {
        guard let client, let proID = await linkedProID() else { return nil }
        struct NameRow: Codable { let display_name: String? }
        let rows: [NameRow]? = try? await client.from("profiles")
            .select("display_name")
            .eq("id", value: proID)
            .execute().value
        let name = rows?.first?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty ?? true) ? nil : name
    }

    private struct ResponseInsertRow: Codable {
        let student_id: UUID
        let pro_id: UUID
        let message: String
    }

    struct IncomingCloudResponse: Codable, Identifiable {
        let id: UUID
        let student_id: UUID
        let message: String
        let created_at: Date
    }

    enum CloudFehler: LocalizedError {
        case keinPro
        var errorDescription: String? { String(localized: "cloud.response_no_pro") }
    }

    /// Schüler: kurze Antwort an den eigenen Pro senden.
    /// Wirft bei Fehlern — Netzfehler wandern in den Postausgang.
    func sendeAntwortKern(_ message: String) async throws {
        guard let client, let uid = userID else { throw CloudFehler.keinPro }
        let rows: [ProLinkRow] = try await client.from("pro_students")
            .select("pro_id")
            .eq("student_id", value: uid)
            .execute().value
        guard let proID = rows.first?.pro_id else { throw CloudFehler.keinPro }
        try await client.from("responses")
            .insert(ResponseInsertRow(student_id: uid, pro_id: proID, message: message))
            .execute()
        lastErrorMessage = nil
    }

    /// Pro: alle Antworten seiner Schüler (RLS filtert serverseitig).
    func fetchResponses() async -> [IncomingCloudResponse] {
        guard let client, isSignedIn else { return [] }
        do {
            return try await client.from("responses")
                .select("id, student_id, message, created_at")
                .order("created_at", ascending: false)
                .execute().value
        } catch {
            return []
        }
    }

    // MARK: - Mitteilungen („Zettel vom Pro")

    private struct MessageInsertRow: Codable {
        let pro_id: UUID
        let student_id: UUID
        let body: String
    }

    struct CloudMessage: Codable, Identifiable {
        let id: UUID
        let pro_id: UUID
        let student_id: UUID
        let body: String
        let created_at: Date
        let read_at: Date?
    }

    /// Pro: eine Mitteilung an einen oder mehrere Schüler senden.
    /// Eine Rundmitteilung ist einfach eine Zeile pro Empfänger.
    /// Wirft bei Fehlern — der Postausgang unterscheidet Netz von Rest.
    func sendMessage(_ body: String, to studentCloudIDs: [UUID]) async throws -> [CloudMessage] {
        guard let client, let uid = userID, !studentCloudIDs.isEmpty else { return [] }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let rows = studentCloudIDs.map { MessageInsertRow(pro_id: uid, student_id: $0, body: text) }
        let inserted: [CloudMessage] = try await client.from("messages")
            .insert(rows)
            .select("id, pro_id, student_id, body, created_at, read_at")
            .execute().value
        lastErrorMessage = nil
        return inserted
    }

    /// Alle Mitteilungen, die mich betreffen — RLS filtert serverseitig:
    /// der Pro sieht Gesendetes, der Schüler Empfangenes.
    func fetchCloudMessages() async -> [CloudMessage] {
        guard let client, isSignedIn else { return [] }
        do {
            return try await client.from("messages")
                .select("id, pro_id, student_id, body, created_at, read_at")
                .order("created_at", ascending: false)
                .execute().value
        } catch {
            return []
        }
    }

    /// Schüler: Mitteilung als gelesen markieren (der Pro sieht das Häkchen).
    func markMessageRead(_ messageID: UUID) async {
        guard let client else { return }
        struct ReadPatch: Codable { let read_at: Date }
        _ = try? await client.from("messages")
            .update(ReadPatch(read_at: Date()))
            .eq("id", value: messageID)
            .is("read_at", value: nil)
            .execute()
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
