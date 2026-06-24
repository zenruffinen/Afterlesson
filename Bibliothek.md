# Grünbuch — Bibliothek

## Was die Bibliothek ist

Die **Bibliothek** ist der zentrale Vorrat für **wiederverwendbaren Lernstoff**:

- Tipps & Tricks
- Vorbereitete Filme, Bilder, Texte, PDFs, Audios
- Lektionsvorlagen und Klassen (Putten, Abschlag, …)

Alles hier ist **generisch** — gedacht zum mehrfachen Einsatz bei verschiedenen Schülern.

## Was die Bibliothek NICHT ist

Während einer **aktiven Stunde** am Platz:

- Keine Live-Aufnahmen
- Keine spontanen Notizen zur laufenden Lesson

Diese Inhalte gehören **direkt ins Schülerprofil** (Schülermaske → „Stunde erfassen“), nicht in die Bibliothek.

## Technik

| Speicher | Modell | Zweck |
|----------|--------|-------|
| `contentPool` | `ContentItem` | Medien & Texte in der Bibliothek |
| `contentClasses` | `ContentClass` | Ordner/Klassen in der Bibliothek |
| `lessons` | `Lesson` | Lektionsvorlagen mit Verweisen auf `contentItemIDs` |

Import über Bibliothek-Tab → `importPhotoItems`, `importFiles`, `importRecordedVideo` → landen in `contentPool`.

## Composer-Verknüpfung

Der **Composer** wählt Inhalte **aus der Bibliothek** (Lektionen + Einzelmedien), kombiniert sie mit Schüler + Datum + Nachricht und erzeugt ein **AirDrop-Paket** für den Schüler.

Live-Stundenmaterial wird **nicht** über den Composer in die Bibliothek zurückgeschrieben.
