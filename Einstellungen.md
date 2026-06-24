# Grünbuch — Einstellungen

Arca-inspirierte Einstellungsseite im Tab **Einstellungen**.

## Sektionen

### Über Grünbuch
- Version aus Bundle (Marketing + Build)
- Entwickler: Hans zen Ruffinen
- **Grünbuch bewerten** — App-Store-Link wenn ID gesetzt, sonst `requestReview()`
- **Feedback senden** — `mailto:support@hansruffin.ch`

### So funktioniert die Nachbesprechung
Drei Kurzpunkte zum 5-Minuten-Ritual: professioneller Abschluss, persönlich per AirDrop, vor Ort.

### Sichern und wiederherstellen
- **Daten sichern** (blau) — verschlüsseltes `.gruenbuchbackup` (Apple Archive, wie Arca)
- **Daten wiederherstellen** (grün) — Datei-Picker oder „Öffnen mit“
- Passwort beim Export/Import, optional Zusammenführen oder Ersetzen

### Modus & Sicherheit
- Pro/Schüler wechseln (PIN-Gate für Lehrer-Modus)
- Bildschirmsperre (Face ID / PIN)

### Datenschutz
- NavigationLink → `PrivacyPolicyView`

### Wusstest du?
Rotierende Tipps (Composer, Bibliothek, Nachbesprechung, Stunde erfassen, …) — antippen wechselt Tipp.

### Footer
„Grünbuch ist kostenlos, werbefrei und sammelt keine Daten über dich.“

## Technik
- `SettingsView.swift` — UI
- `GrünbuchBackupSupport.swift` — Export/Import
- `GrünbuchBackup` in `Models.swift`
- Strings: `de.lproj` / `en.lproj` (`settings.*`)
