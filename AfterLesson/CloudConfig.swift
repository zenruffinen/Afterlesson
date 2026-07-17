//
//  CloudConfig.swift
//  Grünbuch — Cloud (Supabase)
//
//  Die Zugangsdaten des Supabase-Projekts. Beide Werte stehen im
//  Supabase-Dashboard unter: Project Settings → API.
//
//  WICHTIG: Der "anon public"-Schlüssel ist ein öffentlicher
//  Client-Schlüssel und darf in der App stehen — die Sicherheit
//  regeln die Row-Level-Security-Regeln in der Datenbank
//  (siehe supabase/schema.sql). NIE den "service_role"-Schlüssel
//  hier eintragen!
//
//  Solange beide Werte leer sind, ist die Cloud in der App
//  vollständig abgeschaltet — Grünbuch verhält sich wie bisher.
//

import Foundation

enum CloudConfig {

    /// Projekt-URL, z. B. "https://abcdefgh.supabase.co"
    static let supabaseURL = "https://unkattxznrjjdjwdbkkh.supabase.co"

    /// Der öffentliche API-Schlüssel des Projekts (publishable/anon).
    static let supabaseAnonKey = "sb_publishable_yrJ6rxUkaDAdsljJ-uH2xQ_tZMJ5bV4"

    /// Cloud ist erst aktiv, wenn beide Werte eingetragen sind.
    static var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
}
