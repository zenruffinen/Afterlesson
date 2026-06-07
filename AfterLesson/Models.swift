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
    var remarks: String = ""             // Anmerkungen des Schülers für den Pro
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
         tags: [String] = []) {
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

// MARK: - Folder Share

struct AfterLessonFolderShare: Codable {
    var folder: LessonFolder
    var lessons: [Lesson]
    var imageData: [String: Data]
    var contentItems: [ContentItem] = []      // Metadaten der über contentItemIDs verknüpften Datenpool-Inhalte
    var exportDate: Date
    var teacherName: String

    init(folder: LessonFolder, lessons: [Lesson], imageData: [String: Data], contentItems: [ContentItem] = [], exportDate: Date, teacherName: String) {
        self.folder = folder
        self.lessons = lessons
        self.imageData = imageData
        self.contentItems = contentItems
        self.exportDate = exportDate
        self.teacherName = teacherName
    }

    // Defensiver Decoder, gleicher Grund wie bei AfterLessonShare.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        folder = try c.decode(LessonFolder.self, forKey: .folder)
        lessons = try c.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        imageData = try c.decodeIfPresent([String: Data].self, forKey: .imageData) ?? [:]
        contentItems = try c.decodeIfPresent([ContentItem].self, forKey: .contentItems) ?? []
        exportDate = try c.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
        teacherName = try c.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
    }
}
