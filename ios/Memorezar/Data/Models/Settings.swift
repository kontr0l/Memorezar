import Foundation

/// User preferences and app settings
struct AppSettings: Codable {
    // Alert settings
    var audioAlertEnabled: Bool = true
    var visualAlertEnabled: Bool = true
    var hapticAlertEnabled: Bool = true

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

    // Practice settings
    var autoRestartOnCompletion: Bool = false
    var showHints: Bool = true
    var hintDelay: Double = 3.0 // Seconds before showing hint

    static let `default` = AppSettings()
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
