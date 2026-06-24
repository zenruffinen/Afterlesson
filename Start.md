# Grünbuch — Start

## Home (Pro)

Leichtes Startbildschirm-Layout:

- **Header:** Golfbag-Icon · Grünbuch · Pro-Name
- **Fairway-Grafik:** Golfer-Silhouette auf Fairway (Glass-Ästhetik)
- **Drei Hauptbuttons:**
  1. **Composer** (`square.and.pencil`) — Bibliothek-Inhalte Schülern zuweisen (AirDrop)
  2. **Bibliothek** (`books.vertical.fill`) — Lernstoff & Tipps, wiederverwendbar
  3. **Stunde erfassen** (`figure.golf`) — Live am Schüler, nicht Bibliothek

Die kleinen Nav-Pills (Schüler / Bibliothek) und der grüne Orb mit Mikrofon sind entfernt. Schüler, Bibliothek, Notizen und Einstellungen bleiben in der Tab-Leiste.

## Zwei Inhaltspfade

| Pfad | Wann | Wo gespeichert |
|------|------|----------------|
| **Bibliothek → Composer** | Vorbereiteter Lernstoff | `contentPool` → Paket an Schüler |
| **Stunde erfassen** | Live während der Lesson | `studentCaptures` + `sessions` am Schüler |

Details: `Bibliothek.md`, `Schüler.md`, `Kommunikation.md`

## Composer

Kernfunktion zum Zuweisen vorbereiteter Bibliothek-Inhalte:

1. **Schüler** wählen (ein oder mehrere)
2. **Datum** festlegen
3. **Inhalte wählen** — Lektionen + Einzelmedien (Film, Bild, Text, PDF, Audio)
4. Optional **persönliche Nachricht**
5. **Paket an Schüler senden** — Zuordnung speichern, Share-Sheet (AirDrop empfohlen)

Einzelinhalte ohne Lektion werden als **Lernpaket** gebündelt. Gemischte Pakete erzeugen mehrere `.afterlesson`-Dateien.

**Nachreichung:** Aus der Schüler-Kartei können später einzelne Lektionen oder Medien nachgeliefert werden — ohne vollständiges Neu-Zusammenstellen.

Details: `Kommunikation.md`

## Home (Schüler)

- Banner bei neuen Zuweisungen vom Pro
- Liste **Zugewiesen** mit empfangenen Lektionen und Trainingsprotokollen
- Leerzustand erklärt AirDrop-Empfang

## Tab-Leiste

| Tab | Funktion |
|-----|----------|
| Start | Composer + Bibliothek-Shortcut (Pro) / Zugewiesen (Schüler) |
| Bibliothek | Wiederverwendbarer Lernstoff & Tipps (contentPool) |
| Schüler | Schülerverwaltung |
| Notizen | Pro-Notizen (`note.text.badge.plus`) |
| Einstellungen | Modus, Sperre, Profil |

## Technik

- `ComposerSheet` in `ContentView.swift`
- `deliverComposerPackage(…)` in `AppStore.swift`
- Schüler-Import: `importLesson` markiert Lektionen als `receivedFromPro`
- UI-Komponenten: `GrünbuchFairwayGraphic`, `GrünbuchHomeActionButton` in `AfterLessonDesign.swift`
