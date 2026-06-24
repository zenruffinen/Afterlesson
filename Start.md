# Grünbuch — Start

## Home (Pro)

Leichtes Startbildschirm-Layout:

- **Header:** Golfbag-Icon · Grünbuch · Pro-Name
- **Fairway-Grafik:** Golfer-Silhouette auf Fairway (Glass-Ästhetik)
- **Zwei Hauptbuttons:**
  1. **Composer** (`square.and.pencil`) — Lernstoff aus der Bibliothek Schülern zuweisen
  2. **Bibliothek** (`books.vertical.fill`) — Lernstoff pflegen

Die kleinen Nav-Pills (Schüler / Bibliothek) und der grüne Orb mit Mikrofon sind entfernt. Schüler, Bibliothek, Notizen und Einstellungen bleiben in der Tab-Leiste.

## Composer

Kernfunktion zum Zuweisen vorbereiteter Bibliothek-Inhalte:

1. **Schüler** wählen (ein oder mehrere)
2. **Datum** festlegen
3. **Lektionen** aus der Bibliothek auswählen
4. Optional **Einzelinhalte** aus dem Datenpool
5. Optional **persönliche Nachricht** (z. B. Lob / Hinweis für die nächste Stunde)
6. **Zuweisen** — Zuordnung speichern, Verlauf aktualisieren, Share-Sheet zum Senden (AirDrop, WhatsApp, …)

Einzelinhalte ohne Lektion werden als **Lernpaket** gebündelt und mit zugewiesen.

## Home (Schüler)

- Banner bei neuen Zuweisungen vom Pro
- Liste **Zugewiesen** mit empfangenen Protokollen / Lektionen
- Leerzustand erklärt Composer-Empfang

## Tab-Leiste

| Tab | Funktion |
|-----|----------|
| Start | Composer + Bibliothek-Shortcut (Pro) / Zugewiesen (Schüler) |
| Bibliothek | Lernstoff, Lektionen, Datenpool |
| Schüler | Schülerverwaltung |
| Notizen | Pro-Notizen |
| Einstellungen | Modus, Sperre, Profil |

## Technik

- `ComposerSheet` in `ContentView.swift`
- `deliverComposerPackage(…)` in `AppStore.swift`
- UI-Komponenten: `GrünbuchFairwayGraphic`, `GrünbuchHomeActionButton` in `AfterLessonDesign.swift`
