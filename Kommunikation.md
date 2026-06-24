# Grünbuch — Kommunikation Pro ↔ Schüler

## Kernunterscheidung

| Pfad | Quelle | Ziel | Wann |
|------|--------|------|------|
| **Bibliothek → Composer** | `contentPool`, Lektionen | Schüler (AirDrop) | Vorbereiteter, wiederverwendbarer Lernstoff |
| **Stunde erfassen** | Live am Platz | Schülerprofil direkt | Aktive Unterrichtsstunde |

Live-Aufnahmen und Stundennotizen landen **nicht** in der Bibliothek.

---

## Composer (Bibliothek → Schüler)

Der **Composer** bündelt **vorbereiteten** Lernstoff aus der Bibliothek und weist ihn Schülern zu.

### Ablauf

1. **Schüler** wählen (ein oder mehrere)
2. **Datum** festlegen
3. **Inhalte wählen**
   - Fertige **Lektionen** aus Ordnern
   - **Einzelmedien** aus der Bibliothek (Video, Bild, Text, PDF, Audio)
   - Gemischte Pakete möglich
4. Optional **persönliche Nachricht**
5. **Paket an Schüler senden** — Zuordnung wird lokal gespeichert, Share-Sheet öffnet sich (AirDrop empfohlen)

### Paketformat

- Jede Lektion → eine `.afterlesson`-Datei (self-contained inkl. Medien)
- Nur Einzelmedien ohne Lektion → automatisches **Lernpaket** (virtuelle Lektion „Lernpaket DD.MM.YYYY“)
- Persönliche Nachricht → Text im Share-Sheet
- AirDrop-Hinweis → erklärt Schüler-Modus

---

## Stunde erfassen (Live → Schülerprofil)

Während der aktiven Lesson:

1. **Stunde erfassen** öffnen (Start, Schülermaske, AfterLesson-Flow)
2. Schüler wählen (Pflicht)
3. Optional: Foto, Video, Kurznotiz
4. Protokoll: Was geübt, Korrekturen, Übungen, Hausaufgaben
5. **Speichern** → `TrainingSession` + `StudentCapture` am Schüler
6. Optional: **Speichern & an Schüler senden** → `.afterlessonsession` per AirDrop

**Wichtig:** Diese Aufnahmen gehen in `studentCaptures` / `sessions`, **nicht** in `contentPool`.

---

## Nachreichung (teilweise Updates)

Aus der **Schüler-Kartei** → Button **Nachreichung**:

- Composer mit vorausgewähltem Schüler
- Nur neue Lektionen oder Bibliothek-Medien auswählen
- Gleicher Share-Weg per AirDrop

Alternativ: **Senden** in der Kartei teilt bereits zugewiesene Lektionen erneut (mit optionaler Notiz).

---

## Empfang (Schüler-Modus)

1. Schüler tippt `.afterlesson`-Datei an (AirDrop, Dateien, …)
2. Grünbuch öffnet sich (Schüler-Modus)
3. Lektion erscheint unter **Zugewiesen** auf dem Startbildschirm
4. Trainingsprotokolle (`.afterlessonsession`) erscheinen ebenfalls dort

---

## Rückmeldung (Schüler → Pro)

Schüler sendet `.afterlessonfeedback` — Pro importiert in der Schüler-Kartei unter „Letzte Rückmeldung“.
