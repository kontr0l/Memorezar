import Foundation

/// Available memorization practice modes
enum MemorizationMode: String, Codable, CaseIterable, Identifiable {
    case voice = "Voice"
    case firstLetter = "First Letter"
    case multipleChoice = "Multiple Choice"
    case typing = "Typing"
    case audio = "Audio"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .voice: return String(localized: "Voice")
        case .firstLetter: return String(localized: "First Letter")
        case .multipleChoice: return String(localized: "Multiple Choice")
        case .typing: return String(localized: "Typing")
        case .audio: return String(localized: "Audio")
        }
    }

    var icon: String {
        switch self {
        case .voice: return "mic.fill"
        case .firstLetter: return "a.square"
        case .multipleChoice: return "square.grid.2x2"
        case .typing: return "keyboard"
        case .audio: return "music.note"
        }
    }

    /// Modes shown in the Settings picker (excludes firstLetter, which is a toggle)
    static var settingsOptions: [MemorizationMode] {
        [.voice, .typing, .multipleChoice, .audio]
    }
}
