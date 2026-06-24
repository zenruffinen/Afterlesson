# Grünbuch — Kommunikation Pro ↔ Schüler

## Composer (Pro → Schüler)

Der **Composer** bündelt Lernstoff aus der Bibliothek und weist ihn Schülern zu.

### Ablauf

1. **Schüler** wählen (ein oder mehrere)
2. **Datum** festlegen
3. **Inhalte wählen**
   - Fertige **Lektionen** aus Ordnern
   - **Einzelmedien** aus dem Datenpool (Video, Bild, Text, PDF, Audio)
   - Gemischte Pakete möglich
4. Optional **persönliche Nachricht**
5. **Paket an Schüler senden** — Zuordnung wird lokal gespeichert, Share-Sheet öffnet sich (AirDrop empfohlen)

### Paketformat

- Jede Lektion → eine `.afterlesson`-Datei (bestehendes Format, self-contained inkl. Medien)
- Nur Einzelmedien ohne Lektion → automatisches **Lernpaket** (virtuelle Lektion „Lernpaket DD.MM.YYYY“)
- Persönliche Nachricht → Text im Share-Sheet
- AirDrop-Hinweis → erklärt Schüler-Modus

## Nachreichung (teilweise Updates)

Aus der **Schüler-Kartei** → Button **Nachreichung**:

- Composer mit vorausgewähltem Schüler
- Nur neue Lektionen oder Einzelmedien auswählen
- Kein vollständiges Neu-Zusammenstellen nötig
- Gleicher Share-Weg per AirDrop

Alternativ: **Senden** in der Kartei teilt bereits zugewiesene Lektionen erneut (mit optionaler Notiz).

## Empfang (Schüler-Modus)

1. Schüler tippt `.afterlesson`-Datei an (AirDrop, Dateien, …)
2. Grünbuch öffnet sich (Schüler-Modus)
3. Lektion erscheint unter **Zugewiesen** auf dem Startbildschirm
4. Trainingsprotokolle (`.afterlessonsession`) erscheinen ebenfalls dort

## Rückmeldung (Schüler → Pro)

Schüler sendet `.afterlessonfeedback` — Pro importiert in der Schüler-Kartei unter „Letzte Rückmeldung“.
