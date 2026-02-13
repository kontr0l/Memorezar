import Foundation
import CoreGraphics

/// User preferences and app settings
struct AppSettings: Codable {
    // Alert settings
    var audioAlertEnabled: Bool = true
    var visualAlertEnabled: Bool = true
    var hapticAlertEnabled: Bool = true
    var mistakeSound: MistakeSound = .explosion1
    var correctWordSound: CorrectWordSound = .none
    var completionSound: CompletionSound = .applause

    // Comparison settings
    var caseSensitive: Bool = false
    var ignorePunctuation: Bool = true
    var ignoreFillerWords: Bool = true
    var allowContractions: Bool = true

    // Display settings
    var showWordHighlighting: Bool = true
    var showProgressBar: Bool = true
    var fontSize: FontSize = .medium
    var theme: AppTheme = .system
    var wordVisibility: WordVisibility = .showAll
    var wordRevealPercentage: Double = 0.0 // 0-100%, used when visibility is .partial

    // Practice settings
    var autoRestartOnCompletion: Bool = false
    var showHints: Bool = true
    var hintDelay: Double = 3.0 // Seconds before showing hint
    var requireCorrectWord: Bool = true // Stay on word until spoken correctly

    static let `default` = AppSettings()
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
    var displayName: String { rawValue }

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

    var displayName: String { rawValue }

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

    var displayName: String { rawValue }

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

/// Word visibility modes during recitation
enum WordVisibility: String, Codable, CaseIterable {
    case showAll = "Show All Words"
    case hideUntilSpoken = "Hide Until Spoken"
    case partial = "Partial Reveal"

    var description: String {
        switch self {
        case .showAll:
            return "All words visible"
        case .hideUntilSpoken:
            return "Words appear after speaking"
        case .partial:
            return "Show percentage of words"
        }
    }
}

/// Font size options
enum FontSize: String, Codable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    var pointSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        case .extraLarge: return 28
        }
    }
}

/// App theme options
enum AppTheme: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}
