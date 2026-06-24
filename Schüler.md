# Grünbuch — Schüler (Schülermaske)

## Zwei Wege für Inhalte

### 1. Bibliothek → Composer → Schüler (vorbereitet)

1. Pro pflegt **wiederverwendbaren** Lernstoff in der Bibliothek
2. **Composer**: Schüler + Datum + Bibliothek-Inhalte + Nachricht
3. **AirDrop-Paket** an den Schüler
4. Erscheint in der Schülermaske unter **Pakete** (zugewiesene Lektionen + Gesendet-Verlauf)

### 2. Live während der Stunde (direkt am Schüler)

1. Pro ist mit dem Schüler auf dem Platz
2. **Stunde erfassen** (Start, Schülermaske oder AfterLesson-Flow)
3. Foto, Video, Kurznotiz, Protokoll-Felder (geübt, Korrekturen, …)
4. Speicherung **sofort am Schülerprofil** — `StudentCapture` + `TrainingSession`
5. **Nicht** in `contentPool` / Bibliothek

## Schülermaske — Tabs

| Tab | Inhalt |
|-----|--------|
| **Kartei** | Kontakt, Pro-Notizen, letzte Rückmeldung |
| **Lektionen** | Zuweisung von Bibliothek-Lektionen |
| **Unterricht** | Live-Aufnahmen + Stundenprotokolle + Rückmeldungen |
| **Pakete** | Composer-Zuweisungen + Gesendet-Verlauf |

## Schnellaktionen in der Maske

- **Stunde** — öffnet „Stunde erfassen“ (QuickCapture) für diesen Schüler
- **Senden** — bereits zugewiesene Lektionen erneut teilen
- **Nachreichung** — Composer mit vorausgewähltem Schüler (Bibliothek-Inhalte nachliefern)

## Technik

| Speicher | Modell | Zweck |
|----------|--------|-------|
| `students` | `Student` | Profil, Zuweisungen, `sentHistory` |
| `sessions` | `TrainingSession` | Stundenprotokoll (Textfelder) |
| `studentCaptures` | `StudentCapture` | Live Foto/Video/Text — nur Schüler |
| `proNotes` | `ProNote` | Pro-Notizen mit `assignedStudentID` |

Dateien von Live-Aufnahmen: Präfix `capture_` (nicht `pool_`).
