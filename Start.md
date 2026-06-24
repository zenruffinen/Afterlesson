# Grünbuch — Start

## Home (Pro)

Leichtes Startbildschirm-Layout:

- **Header:** Golfbag-Icon · Grünbuch · Pro-Name
- **Fairway-Grafik:** Golfer-Silhouette auf Fairway (Glass-Ästhetik)
- **Drei Hauptbuttons:**
  1. **Composer** (`square.and.pencil`) — Bibliothek-Inhalte für die Nachbesprechung vorbereiten
  2. **Bibliothek** (`books.vertical.fill`) — Lernstoff & Tipps, wiederverwendbar
  3. **Stunde erfassen** (`figure.golf`) — Live am Schüler, nicht Bibliothek

Die kleinen Nav-Pills (Schüler / Bibliothek) und der grüne Orb mit Mikrofon sind entfernt. Schüler, Bibliothek, Notizen und Einstellungen bleiben in der Tab-Leiste.

## Zwei Inhaltspfade

| Pfad | Wann | Wo gespeichert |
|------|------|----------------|
| **Bibliothek → Composer** | Vorbereiteter Lernstoff | `contentPool` → Paket zur Nachbesprechung |
| **Stunde erfassen** | Live während der Lesson | `studentCaptures` + `sessions` am Schüler |

Details: `Bibliothek.md`, `Schüler.md`, `Kommunikation.md`

## Composer

Kernfunktion zum Zuweisen vorbereiteter Bibliothek-Inhalte — Vorbereitung für die **Nachbesprechung** (ca. 5 Minuten am Platz):

1. **Schüler** wählen (ein oder mehrere)
2. **Datum** festlegen
3. **Inhalte wählen** — Lektionen + Einzelmedien (Film, Bild, Text, PDF, Audio)
4. Optional **persönliche Nachricht**
5. **Paket zur Nachbesprechung** — Zuordnung speichern, Share-Sheet (AirDrop in der Nachbesprechung)

Einzelinhalte ohne Lektion werden als **Lernpaket** gebündelt. Gemischte Pakete erzeugen mehrere `.afterlesson`-Dateien.

**Nachreichung:** Aus der Schüler-Kartei können später einzelne Lektionen oder Medien nachgeliefert werden — in der Nachbesprechung, ohne vollständiges Neu-Zusammenstellen.

Details: `Kommunikation.md`

## Home (Schüler)

- Banner bei neuer **Nachbesprechung** vom Pro („Deine Nachbesprechung von …“)
- Liste **Zugewiesen** mit empfangenen Lektionen und Trainingsprotokollen
- Leerzustand erklärt den Empfang in der Nachbesprechung

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
