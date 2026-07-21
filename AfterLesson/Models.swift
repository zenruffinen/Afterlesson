import Foundation
import SwiftUI

// MARK: - App Mode

enum AppMode: String, CaseIterable {
    case teacher = "Lehrer"
    case student = "Schüler"
}

// MARK: - Student (Schüler)

struct Student: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String = ""               // Telefonnummer
    var birthday: Date? = nil             // Geburtstag
    var handicap: String = ""            // Golf-Handicap z.B. "18.4"
    var notes: String = ""
    var dateCreated: Date = Date()
    var avatarColor: String = "1B5E20"
    var photoFilename: String? = nil       // Profilfoto
    var assignedFolderIDs: [UUID] = []    // Zugewiesene Ordner
    var assignedLessonIDs: [UUID] = []    // Direkt zugewiesene Lektionen
    var viewedLessonIDs: [UUID] = []      // Vom Lehrer als "gesehen" markierte Lektionen
    var lastActiveDate: Date? = nil       // Letzter Kontakt (beim Senden aktualisiert)
    var sentHistory: [SentPackage] = []  // Verlauf aller gesendeten Pakete
    var remarks: String = ""             // Letzte Anmerkung des Schülers (Spiegel der neuesten Rückmeldung)
    var feedbackHistory: [StudentFeedbackEntry] = []  // Chronologie importierter Schüler-Rückmeldungen
    // Grünbuch Cloud (beide optional → alte Bestände laden weiterhin sauber)
    var inviteCode: String? = nil        // Vom Pro erzeugter Einladungscode
    var cloudUserID: UUID? = nil         // Cloud-Konto des Schülers nach Code-Einlösung

    init(name: String,
         phone: String = "",
         notes: String = "",
         avatarColor: String = "1B5E20") {
        self.name = name
        self.phone = phone
        self.notes = notes
        self.avatarColor = avatarColor
    }

    // Defensiver Decoder (21.07.2026): Schüler-Datensätze aus älteren
    // App-Versionen kennen neuere Felder (phone, feedbackHistory, …) nicht.
    // Die Standard-Synthese bricht bei fehlenden Schlüsseln komplett ab —
    // und da per try? geladen wird, verschwinden dann ALLE Schüler still.
    // decodeIfPresent mit Standardwert macht das robust (Haus-Regel, siehe
    // gleicher Fix in Lesson).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        birthday = try c.decodeIfPresent(Date.self, forKey: .birthday)
        handicap = try c.decodeIfPresent(String.self, forKey: .handicap) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        dateCreated = try c.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        avatarColor = try c.decodeIfPresent(String.self, forKey: .avatarColor) ?? "1B5E20"
        photoFilename = try c.decodeIfPresent(String.self, forKey: .photoFilename)
        assignedFolderIDs = try c.decodeIfPresent([UUID].self, forKey: .assignedFolderIDs) ?? []
        assignedLessonIDs = try c.decodeIfPresent([UUID].self, forKey: .assignedLessonIDs) ?? []
        viewedLessonIDs = try c.decodeIfPresent([UUID].self, forKey: .viewedLessonIDs) ?? []
        lastActiveDate = try c.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        sentHistory = (try? c.decodeIfPresent([SentPackage].self, forKey: .sentHistory)) ?? []
        remarks = try c.decodeIfPresent(String.self, forKey: .remarks) ?? ""
        feedbackHistory = (try? c.decodeIfPresent([StudentFeedbackEntry].self, forKey: .feedbackHistory)) ?? []
        inviteCode = try c.decodeIfPresent(String.self, forKey: .inviteCode)
        cloudUserID = try c.decodeIfPresent(UUID.self, forKey: .cloudUserID)
    }
}

// MARK: - Lesson Category (Themen)

struct LessonFolder: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String = ""
    var colorHex: String = "2C5F2D" // Golf-Grün
    var icon: String = "figure.golf"
    var dateCreated: Date = Date()
    var sortIndex: Int = 0
    var studentIDs: [UUID] = []          // Zugewiesene Schüler
}

// MARK: - Lesson (Lektion)

enum LessonOrigin: String, Codable {
    case local
    case receivedFromPro
}

struct Lesson: Identifiable, Codable, Hashable {
    var id = UUID()
    var folderID: UUID
    var title: String
    var description: String = ""
    var icon: String = "figure.golf"    // Lektion-Icon
    var imageFilenames: [String] = []   // Gespeicherte Bilder (klassisch, pro Lektion hochgeladen)
    var videoFilename: String? = nil    // Optionales Video (klassisch, pro Lektion hochgeladen)
    var contentItemIDs: [UUID] = []     // Verweise auf Inhalte aus dem zentralen Datenpool (ContentItem)
    var tips: [String] = []             // Profi-Tipps
    var steps: [LessonStep] = []        // Schritt-für-Schritt
    var dateCreated: Date = Date()
    var isFavorite: Bool = false
    var tags: [String] = []             // z.B. ["Anfänger", "Fortgeschritten"]
    var origin: LessonOrigin = .local   // Schüler-Import markiert .receivedFromPro
    var receivedFromPro: String = ""    // Name des Pros bei empfangenen Lektionen
    var openedDate: Date? = nil         // Lesestatus (Schüler-Modus)
    var cloudPackageID: UUID? = nil     // Herkunfts-Paket in der Cloud (für Lesestatus-Rückmeldung)

    init(id: UUID = UUID(),
         folderID: UUID,
         title: String,
         description: String = "",
         icon: String = "figure.golf",
         imageFilenames: [String] = [],
         videoFilename: String? = nil,
         contentItemIDs: [UUID] = [],
         tips: [String] = [],
         steps: [LessonStep] = [],
         dateCreated: Date = Date(),
         isFavorite: Bool = false,
         tags: [String] = [],
         origin: LessonOrigin = .local,
         receivedFromPro: String = "",
         openedDate: Date? = nil) {
        self.id = id
        self.folderID = folderID
        self.title = title
        self.description = description
        self.icon = icon
        self.imageFilenames = imageFilenames
        self.videoFilename = videoFilename
        self.contentItemIDs = contentItemIDs
        self.tips = tips
        self.steps = steps
        self.dateCreated = dateCreated
        self.isFavorite = isFavorite
        self.tags = tags
        self.origin = origin
        self.receivedFromPro = receivedFromPro
        self.openedDate = openedDate
    }

    // Eigener Decoder statt der automatisch generierten Synthese: Bereits gespeicherte
    // bzw. exportierte Lektionen (UserDefaults "al_lessons", .afterlesson-Pakete) können
    // älter sein als neu hinzugekommene Felder wie `contentItemIDs` — ein Schlüssel, der
    // im JSON fehlt, würde die Standard-Synthese mit "keyNotFound" abbrechen lassen und
    // (da das Laden per `try?` erfolgt) sämtliche Lektionen stillschweigend verschwinden
    // lassen. `decodeIfPresent(...) ?? Standardwert` macht das robust in beide Richtungen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        folderID = try c.decode(UUID.self, forKey: .folderID)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "figure.golf"
        imageFilenames = try c.decodeIfPresent([String].self, forKey: .imageFilenames) ?? []
        videoFilename = try c.decodeIfPresent(String.self, forKey: .videoFilename)
        contentItemIDs = try c.decodeIfPresent([UUID].self, forKey: .contentItemIDs) ?? []
        tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
        steps = try c.decodeIfPresent([LessonStep].self, forKey: .steps) ?? []
        dateCreated = try c.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        origin = try c.decodeIfPresent(LessonOrigin.self, forKey: .origin) ?? .local
        receivedFromPro = try c.decodeIfPresent(String.self, forKey: .receivedFromPro) ?? ""
        openedDate = try c.decodeIfPresent(Date.self, forKey: .openedDate)
        cloudPackageID = try c.decodeIfPresent(UUID.self, forKey: .cloudPackageID)
    }
}

// MARK: - Lesson Step

struct LessonStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var order: Int
    var title: String
    var description: String
    var imageFilename: String? = nil
}

// MARK: - Content Item (Datenpool)
//
// Ein einzelner Lerninhalt im zentralen "Datenpool" des Pros — beliebiges
// Dateiformat (Bild, Video, PDF, Audio, Text), importiert oder direkt in
// der App aufgenommen. Lektionen setzen sich aus solchen Items zusammen,
// und einzelne Items können auch direkt einem Schüler zugewiesen werden.

enum ContentType: String, Codable, CaseIterable {
    case image, video, pdf, audio, text

    var label: String {
        switch self {
        case .image: return "Bild"
        case .video: return "Video"
        case .pdf:   return "PDF"
        case .audio: return "Audio"
        case .text:  return "Text"
        }
    }

    /// SF-Symbol fürs Vorschau-Icon — zeigt auf einen Blick, um welchen Dateityp es sich handelt.
    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .pdf:   return "doc.richtext.fill"
        case .audio: return "waveform"
        case .text:  return "doc.text.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .image: return "1565C0"
        case .video: return "C62828"
        case .pdf:   return "E65100"
        case .audio: return "4A148C"
        case .text:  return "2C5F2D"
        }
    }
}

enum ContentSource: String, Codable {
    case imported   // aus Dateien/Fotos importiert
    case recorded   // direkt in der App aufgenommen/gefilmt
}

// MARK: - Content Class (Klasse im Datenpool)
//
// Eine "Klasse" ist ein Ordner im Datenpool: Der Pro strukturiert damit seine
// Inhalte (z.B. "Abschlag", "Putten", "Theorie"). Jeder Inhalt gehört zu
// höchstens einer Klasse — Inhalte ohne Klasse erscheinen unter "Unsortiert".

struct ContentClass: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var icon: String = "folder.fill"
    var colorHex: String = "2C5F2D"
    var sortIndex: Int = 0
    var dateCreated: Date = Date()
    var parentID: UUID? = nil               // Obergruppe, z.B. "Kurzes Spiel" → Putten/Chippen/Pitchen.
                                            // Genau EINE Ebene. Optional, daher decodieren alte
                                            // Bestände und Cloud-Pakete fehlende Schlüssel als nil.
}

struct ContentItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var type: ContentType
    var filename: String                    // gespeicherte Datei (Bild/Video/PDF/Audio)
    var thumbnailFilename: String? = nil    // optionale Vorschau, z.B. generiertes Video-Thumbnail
    var source: ContentSource = .imported
    var dateCreated: Date = Date()
    var tags: [String] = []
    var notes: String = ""
    var classID: UUID? = nil                // Zugehörige Klasse (Ordner) — nil = "Unsortiert".
                                            // Optional, daher decodiert Swift fehlende Schlüssel
                                            // in alten Daten/Paketen automatisch als nil.
    var tileColorHex: String? = nil         // Eigene Kachel-Farbe — nil = Standardfarbe des Typs.
}

// MARK: - Student Progress

struct StudentProgress: Identifiable, Codable {
    var id = UUID()
    var lessonID: UUID
    var isCompleted: Bool = false
    var notes: String = ""              // Schüler-Notizen
    var dateViewed: Date = Date()
    var rating: Int = 0                 // 0-5 Sterne
}

// MARK: - Teaching Group (Unterrichtsgruppe)

struct TeachingGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String = "1B5E20"
    var icon: String = "person.3.fill"
    var dateCreated: Date = Date()
    var studentIDs: [UUID] = []       // Zugewiesene Schüler
    var lessonIDs: [UUID] = []        // Zugewiesene Lektionen
    var notes: String = ""
}

// MARK: - Activity Feed (Kommunikations-Hub)

enum ActivityStatus: String, Codable {
    case sent, received, inProgress, completed, new

    var label: String {
        switch self {
        case .sent:        return "Gesendet"
        case .received:    return "Empfangen"
        case .inProgress:  return "In Arbeit"
        case .completed:   return "Erledigt"
        case .new:         return "Neu"
        }
    }
}

// MARK: - Sent Package (Verlauf)

struct SentPackage: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var lessonTitles: [String] = []   // Snapshot der Lektionstitel beim Senden
    var note: String = ""             // Persönliche Notiz
}

// MARK: - Pro Note (Notiz des Pros)

struct ProNote: Identifiable, Codable {
    var id = UUID()
    var title: String = ""
    var text: String = ""
    var audioFilename: String? = nil      // Sprachaufnahme
    var assignedStudentID: UUID? = nil    // Zuweisung zu Schüler
    var assignedGroupID: UUID? = nil      // Zuweisung zu Gruppe
    var dateCreated: Date = Date()
    var colorHex: String = "1B5E20"

    var assignmentType: AssignmentType {
        if assignedStudentID != nil { return .student }
        if assignedGroupID != nil { return .group }
        return .none
    }

    enum AssignmentType { case student, group, none }
}

// MARK: - Student Capture (Live während der Stunde)
//
// Aufnahmen während des aktiven Unterrichts — Video, Foto, Audio, Textnotiz.
// Landen direkt am Schülerprofil, NICHT in der Bibliothek (contentPool).

struct StudentCapture: Identifiable, Codable, Hashable {
    var id = UUID()
    var studentID: UUID
    var sessionID: UUID? = nil       // optional: Verknüpfung zum Stundenprotokoll
    var date: Date = Date()
    var type: ContentType
    var title: String = ""
    var textNote: String = ""        // bei type == .text oder Kurznotiz
    var filename: String? = nil
    var thumbnailFilename: String? = nil
}

// MARK: - Training Session (Stundenprotokoll)

enum SessionSource: String, Codable {
    case created    // Pro hat diese Stunde erstellt
    case received   // Schüler hat diese Zusammenfassung empfangen
}

struct TrainingSession: Identifiable, Codable {
    var id = UUID()
    var studentID: UUID? = nil          // Optional – kann auch ohne Schüler gespeichert werden
    var date: Date = Date()
    var title: String = ""              // z.B. "Training 20.05.2026"
    var trained: String = ""            // Was geübt
    var corrections: String = ""        // Korrekturen
    var exercises: String = ""          // Übungen
    var homework: String = ""           // Hausaufgaben / nächste Aufgabe
    var rawTranscript: String = ""      // Rohtranskript (für spätere KI-Verarbeitung)
    var imageFilenames: [String] = []   // Fotos zur Stunde
    var source: SessionSource = .created
    var teacherName: String = ""        // Name des Pros (bei empfangenen Sessions)
    var openedDate: Date? = nil         // Wann der Schüler das Protokoll geöffnet hat (Lesestatus)
}

// MARK: - Student Feedback (Rückmeldung Schüler → Pro)

enum FeedbackKind: String, Codable, CaseIterable {
    case thanks, practiced, question, completed, custom

    var label: String {
        switch self {
        case .thanks:     return "Danke!"
        case .practiced:  return "Geübt"
        case .question:   return "Frage"
        case .completed:  return "Erledigt"
        case .custom:     return "Eigene Nachricht"
        }
    }

    var presetMessage: String {
        switch self {
        case .thanks:     return "Danke für die Lektion — ich habe sie angeschaut!"
        case .practiced:  return "Habe die Übungen schon einmal durchprobiert."
        case .question:   return "Ich habe noch eine Frage dazu…"
        case .completed:  return "Alles erledigt — bereit für die nächste Stunde!"
        case .custom:     return ""
        }
    }

    var icon: String {
        switch self {
        case .thanks:     return "hand.thumbsup.fill"
        case .practiced:  return "figure.golf"
        case .question:   return "questionmark.bubble.fill"
        case .completed:  return "checkmark.circle.fill"
        case .custom:     return "text.bubble.fill"
        }
    }
}

struct StudentFeedbackEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var kind: FeedbackKind
    var message: String
    var lessonTitle: String?
    var sessionTitle: String?
    var viewedLessonTitles: [String] = []
}

// MARK: - Mitteilung („Zettel vom Pro")

/// Kurze Botschaft des Pros ("Das hat gut geklappt!", "Stunde fällt aus").
/// Beim Pro: Ablage im Verlauf der Schüler-Kartei (localStudentID gesetzt).
/// Beim Schüler: Empfangene Mitteilungen (localStudentID bleibt nil).
struct ProMessage: Identifiable, Codable, Hashable {
    var id = UUID()                   // = Cloud-ID der messages-Zeile
    var localStudentID: UUID? = nil   // Karteikarte des Empfängers (nur Pro)
    var body: String
    var date: Date = Date()
    var readDate: Date? = nil         // Gelesen-Zeitpunkt (Pro: Häkchen, Schüler: eigener Status)
}

struct AfterLessonFeedbackShare: Codable {
    var studentName: String
    var message: String
    var kind: FeedbackKind
    var lessonTitle: String?
    var sessionTitle: String?
    var viewedLessonTitles: [String] = []
    var exportDate: Date
}

// MARK: - Session Share Package

struct AfterLessonSessionShare: Codable {
    var session: TrainingSession
    var teacherName: String
    var exportDate: Date
}

// MARK: - Share Package (für AirDrop / WhatsApp)

struct AfterLessonShare: Codable {
    var lesson: Lesson
    var imageData: [String: Data]            // filename → Dateidaten (Lektionsbilder + verknüpfte Datenpool-Inhalte)
    var contentItems: [ContentItem] = []      // Metadaten der über contentItemIDs verknüpften Datenpool-Inhalte
    var exportDate: Date
    var teacherName: String

    init(lesson: Lesson, imageData: [String: Data], contentItems: [ContentItem] = [], exportDate: Date, teacherName: String) {
        self.lesson = lesson
        self.imageData = imageData
        self.contentItems = contentItems
        self.exportDate = exportDate
        self.teacherName = teacherName
    }

    // Defensiver Decoder (siehe Lesson.init(from:)): ältere .afterlesson-Pakete kennen
    // das Feld `contentItems` noch nicht — ohne decodeIfPresent würde der Import
    // mit "keyNotFound" fehlschlagen (importLesson liefert dann still `false`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lesson = try c.decode(Lesson.self, forKey: .lesson)
        imageData = try c.decodeIfPresent([String: Data].self, forKey: .imageData) ?? [:]
        contentItems = try c.decodeIfPresent([ContentItem].self, forKey: .contentItems) ?? []
        exportDate = try c.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
        teacherName = try c.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
    }
}

// MARK: - Full App Backup

struct GrünbuchBackupSettings: Codable {
    var teacherName: String = ""
    var teacherTitle: String = "PGA Teaching Professional"
    var pinnedNoteID: String = ""
}

struct GrünbuchBackup: Codable {
    var folders: [LessonFolder]
    var lessons: [Lesson]
    var progress: [StudentProgress]
    var students: [Student]
    var groups: [TeachingGroup]
    var proNotes: [ProNote]
    var contentPool: [ContentItem]
    var contentClasses: [ContentClass]
    var sessions: [TrainingSession]
    var studentCaptures: [StudentCapture]
    var settings: GrünbuchBackupSettings
    var exportDate: Date
}
