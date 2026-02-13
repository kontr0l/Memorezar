import Foundation

/// User preferences and app settings
struct AppSettings: Codable {
    // Alert settings
    var audioAlertEnabled: Bool = true
    var visualAlertEnabled: Bool = true
    var hapticAlertEnabled: Bool = true
    var mistakeSound: MistakeSound = .explosion1

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
    case explosion1 = "Explosion 1"
    case explosion2 = "Explosion 2"
    case explosion3 = "Explosion 3"
    case bomb = "Bomb"
    case crash = "Crash"
    case buzzer = "Buzzer"
    case alarm = "Alarm"
    case glass = "Glass Break"
    case thunder = "Thunder"
    case drumHit = "Drum Hit"

    /// Display name for UI
    var displayName: String { rawValue }

    /// System sound ID or custom sound parameters
    var soundParameters: (frequency: Double, duration: Double, waveform: SoundWaveform) {
        switch self {
        case .explosion1:
            return (80, 0.3, .noise)      // Low rumble
        case .explosion2:
            return (60, 0.4, .noise)      // Deeper explosion
        case .explosion3:
            return (100, 0.25, .noise)    // Short blast
        case .bomb:
            return (50, 0.5, .noise)      // Heavy bass
        case .crash:
            return (200, 0.2, .noise)     // High crash
        case .buzzer:
            return (150, 0.15, .square)   // Classic buzzer
        case .alarm:
            return (880, 0.1, .sine)      // Sharp beep
        case .glass:
            return (2000, 0.15, .noise)   // High shatter
        case .thunder:
            return (40, 0.6, .noise)      // Deep rumble
        case .drumHit:
            return (120, 0.08, .sine)     // Punchy drum
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
