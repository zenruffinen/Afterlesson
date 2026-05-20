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
    var imageFilenames: [String] = []   // Gespeicherte Bilder
    var videoFilename: String? = nil    // Optionales Video
    var tips: [String] = []             // Profi-Tipps
    var steps: [LessonStep] = []        // Schritt-für-Schritt
    var dateCreated: Date = Date()
    var isFavorite: Bool = false
    var tags: [String] = []             // z.B. ["Anfänger", "Fortgeschritten"]
}

// MARK: - Lesson Step

struct LessonStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var order: Int
    var title: String
    var description: String
    var imageFilename: String? = nil
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

// MARK: - Share Package (für AirDrop / WhatsApp)

struct AfterLessonShare: Codable {
    var lesson: Lesson
    var imageData: [String: Data]       // filename → Bilddaten
    var exportDate: Date
    var teacherName: String
}

// MARK: - Folder Share

struct AfterLessonFolderShare: Codable {
    var folder: LessonFolder
    var lessons: [Lesson]
    var imageData: [String: Data]
    var exportDate: Date
    var teacherName: String
}
