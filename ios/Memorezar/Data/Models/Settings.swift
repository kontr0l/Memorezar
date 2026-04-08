import Foundation
import CoreGraphics

/// User preferences and app settings
struct AppSettings: Codable {
    // Alert settings
    var audioAlertEnabled: Bool = true
    var visualAlertEnabled: Bool = true
    var hapticAlertEnabled: Bool = true
    var soundTheme: SoundTheme = .default
    // Legacy — kept for backward-compatible decoding only
    var mistakeSound: MistakeSound = .explosion1
    var correctWordSound: CorrectWordSound = .none
    var completionSound: CompletionSound = .applause

    // Display settings
    var showWordHighlighting: Bool = true
    var showProgressBar: Bool = true
    var fontSize: FontSize = .medium
    var theme: AppTheme = .light
    var wordVisibility: WordVisibility = .showAll
    var wordRevealPercentage: Double = 0.0 // 0-100%, used when visibility is .partial
    var defaultMemorizationMode: MemorizationMode = .voice
    var firstLetterModeEnabled: Bool = false

    static let `default` = AppSettings()

    // Custom decoder so new properties added in updates don't crash
    // when decoding settings saved by older versions of the app.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        audioAlertEnabled = (try? c.decode(Bool.self, forKey: .audioAlertEnabled)) ?? true
        visualAlertEnabled = (try? c.decode(Bool.self, forKey: .visualAlertEnabled)) ?? true
        hapticAlertEnabled = (try? c.decode(Bool.self, forKey: .hapticAlertEnabled)) ?? true
        soundTheme = (try? c.decode(SoundTheme.self, forKey: .soundTheme)) ?? .default
        mistakeSound = (try? c.decode(MistakeSound.self, forKey: .mistakeSound)) ?? .explosion1
        correctWordSound = (try? c.decode(CorrectWordSound.self, forKey: .correctWordSound)) ?? .none
        completionSound = (try? c.decode(CompletionSound.self, forKey: .completionSound)) ?? .applause
        showWordHighlighting = (try? c.decode(Bool.self, forKey: .showWordHighlighting)) ?? true
        showProgressBar = (try? c.decode(Bool.self, forKey: .showProgressBar)) ?? true
        fontSize = ((try? c.decode(FontSize.self, forKey: .fontSize)) ?? .medium).normalized
        theme = (try? c.decode(AppTheme.self, forKey: .theme)) ?? .light
        wordVisibility = (try? c.decode(WordVisibility.self, forKey: .wordVisibility)) ?? .showAll
        wordRevealPercentage = (try? c.decode(Double.self, forKey: .wordRevealPercentage)) ?? 0.0
        // Handle legacy "Image" → .audio, "Normal" → .voice, "Choice" → .multipleChoice
        if let modeStr = try? c.decode(String.self, forKey: .defaultMemorizationMode) {
            switch modeStr {
            case "Image": defaultMemorizationMode = .audio
            case "Normal": defaultMemorizationMode = .voice
            case "Choice": defaultMemorizationMode = .multipleChoice
            default: defaultMemorizationMode = MemorizationMode(rawValue: modeStr) ?? .voice
            }
        } else {
            defaultMemorizationMode = .voice
        }
        firstLetterModeEnabled = (try? c.decode(Bool.self, forKey: .firstLetterModeEnabled)) ?? false
    }

    init() {}
}

/// Sound options for mistake alerts
enum MistakeSound: String, Codable, CaseIterable {
    case explosion1 = "Explosion"
    case bomb = "Bomb"
    case buzzer = "Buzzer"
    case bullhorn = "Bullhorn"
    case cricket = "Cricket"
    case softChime = "Soft Chime"
    case drumHit = "Drum Hit"
    case glassBreak = "Glass Break"
    case thunder = "Thunder"
    case airHorn = "Air Horn"

    /// Display name for UI
    var displayName: String {
        switch self {
        case .explosion1: return String(localized: "Explosion")
        case .bomb: return String(localized: "Bomb")
        case .buzzer: return String(localized: "Buzzer")
        case .bullhorn: return String(localized: "Bullhorn")
        case .cricket: return String(localized: "Cricket")
        case .softChime: return String(localized: "Soft Chime")
        case .drumHit: return String(localized: "Drum Hit")
        case .glassBreak: return String(localized: "Glass Break")
        case .thunder: return String(localized: "Thunder")
        case .airHorn: return String(localized: "Air Horn")
        }
    }

    /// System sound ID or custom sound parameters
    var soundParameters: (frequency: Double, duration: Double, waveform: SoundWaveform) {
        switch self {
        case .explosion1:
            return (80, 0.3, .noise)      // Low rumble explosion
        case .bomb:
            return (50, 0.5, .noise)      // Heavy bass bomb
        case .buzzer:
            return (150, 0.15, .square)   // Classic buzzer
        case .bullhorn:
            return (400, 0.25, .square)   // Loud bullhorn
        case .cricket:
            return (4000, 0.08, .sine)    // Soft cricket chirp
        case .softChime:
            return (1200, 0.12, .sine)    // Gentle chime
        case .drumHit:
            return (120, 0.08, .sine)     // Punchy drum
        case .glassBreak:
            return (2000, 0.15, .noise)   // High shatter
        case .thunder:
            return (40, 0.6, .noise)      // Deep rumble
        case .airHorn:
            return (600, 0.35, .square)   // Loud air horn
        }
    }
}

/// Sound options for correct word feedback
enum CorrectWordSound: String, Codable, CaseIterable {
    case none = "None"
    case softClick = "Soft Click"
    case ding = "Ding"
    case pop = "Pop"
    case chime = "Chime"

    var displayName: String {
        switch self {
        case .none: return String(localized: "None")
        case .softClick: return String(localized: "Soft Click")
        case .ding: return String(localized: "Ding")
        case .pop: return String(localized: "Pop")
        case .chime: return String(localized: "Chime")
        }
    }

    var soundParameters: (frequency: Double, duration: Double, waveform: SoundWaveform)? {
        switch self {
        case .none:
            return nil
        case .softClick:
            return (800, 0.02, .sine)      // Very short click
        case .ding:
            return (1400, 0.08, .sine)     // Pleasant ding
        case .pop:
            return (600, 0.03, .sine)      // Quick pop
        case .chime:
            return (1000, 0.1, .sine)      // Gentle chime
        }
    }
}

/// Sound options for completion
enum CompletionSound: String, Codable, CaseIterable {
    case applause = "Applause"
    case fanfare = "Fanfare"
    case celebration = "Celebration"
    case chime = "Success Chime"
    case none = "None"

    var displayName: String {
        switch self {
        case .applause: return String(localized: "Applause")
        case .fanfare: return String(localized: "Fanfare")
        case .celebration: return String(localized: "Celebration")
        case .chime: return String(localized: "Success Chime")
        case .none: return String(localized: "None")
        }
    }

    var soundParameters: (frequency: Double, duration: Double, waveform: SoundWaveform)? {
        switch self {
        case .none:
            return nil
        case .applause:
            return (300, 0.8, .noise)      // Simulated applause noise
        case .fanfare:
            return (880, 0.5, .sine)       // Triumphant fanfare
        case .celebration:
            return (1200, 0.6, .sine)      // Happy celebration tone
        case .chime:
            return (1400, 0.3, .sine)      // Success chime
        }
    }
}

/// Waveform types for sound generation
enum SoundWaveform: String, Codable {
    case sine
    case square
    case noise
}

/// Sound theme — determines which sound files are played for each event
enum SoundTheme: String, Codable, CaseIterable {
    case `default` = "Default"
    case memes = "Memes"

    var displayName: String {
        switch self {
        case .default: return String(localized: "Default")
        case .memes: return String(localized: "Memes")
        }
    }

    /// Subfolder name within Resources/Sounds for themed sounds (nil = use root WAV files)
    var isRandom: Bool { self != .default }

    /// Sound categories that map to files/folders
    enum SoundEvent: String {
        case error
        case success
        case resultFail = "result fail"
        case resultWin = "result win"

        /// Default WAV filename (for .default theme)
        var defaultFile: String {
            switch self {
            case .error: return "error.wav"
            case .success: return "success.wav"
            case .resultFail: return "result_fail.wav"
            case .resultWin: return "result_win.wav"
            }
        }

        /// Folder name for meme sounds
        var folderName: String { rawValue }
    }
}

/// How each word is rendered in the word grid
enum WordDisplayMode {
    case full            // "Four" — normal text
    case hidden          // placeholder box (existing behavior)
    case firstLetter     // "F___" — first letter + underscores
    case firstTwoLetters // "Fo__" — current word gets extra hint
    case letters(Int)    // Show N letters + underscores (0 = hidden box, 4+ = full)
}

/// Word visibility modes during recitation
enum WordVisibility: String, Codable, CaseIterable {
    case showAll = "Show All Words"
    case hideUntilSpoken = "Hide Until Spoken"
    case partial = "Partial Reveal"

    var localizedName: String {
        switch self {
        case .showAll: return String(localized: "Show All Words")
        case .hideUntilSpoken: return String(localized: "Hide Until Spoken")
        case .partial: return String(localized: "Partial Reveal")
        }
    }

    var description: String {
        switch self {
        case .showAll:
            return String(localized: "All words visible")
        case .hideUntilSpoken:
            return String(localized: "Words appear after speaking")
        case .partial:
            return String(localized: "Show percentage of words")
        }
    }
}

/// Font size options
enum FontSize: String, Codable {
    // Legacy cases kept for backward-compatible decoding
    case small = "Small"
    case large = "Large"
    // Active cases
    case medium = "Medium"
    case extraLarge = "Extra Large"

    /// Only Normal and Large are shown in the UI
    static var allCases: [FontSize] { [.medium, .extraLarge] }

    var localizedName: String {
        switch self {
        case .medium: return String(localized: "Normal")
        case .extraLarge: return String(localized: "Large")
        case .small, .large: return String(localized: "Normal")
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .small, .medium: return 18
        case .large: return 22
        case .extraLarge: return 28
        }
    }

    /// Migrate legacy values to active cases
    var normalized: FontSize {
        switch self {
        case .small: return .medium
        case .large: return .extraLarge
        default: return self
        }
    }
}

/// App theme options
enum AppTheme: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var localizedName: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}
