import Foundation
import SwiftUI
import Combine

/// Observable store for app settings
final class SettingsStore: ObservableObject {

    // MARK: - Published Properties

    @Published var settings: AppSettings {
        didSet {
            saveSettings()
            applySettings()
        }
    }

    // MARK: - Private Properties

    private let settingsKey = "memorezar_settings"
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults)
        applySettings()
    }

    // MARK: - Convenience Accessors

    var audioAlertEnabled: Bool {
        get { settings.audioAlertEnabled }
        set { settings.audioAlertEnabled = newValue }
    }

    var visualAlertEnabled: Bool {
        get { settings.visualAlertEnabled }
        set { settings.visualAlertEnabled = newValue }
    }

    var hapticAlertEnabled: Bool {
        get { settings.hapticAlertEnabled }
        set { settings.hapticAlertEnabled = newValue }
    }

    var mistakeSound: MistakeSound {
        get { settings.mistakeSound }
        set { settings.mistakeSound = newValue }
    }

    var caseSensitive: Bool {
        get { settings.caseSensitive }
        set { settings.caseSensitive = newValue }
    }

    var ignorePunctuation: Bool {
        get { settings.ignorePunctuation }
        set { settings.ignorePunctuation = newValue }
    }

    var ignoreFillerWords: Bool {
        get { settings.ignoreFillerWords }
        set { settings.ignoreFillerWords = newValue }
    }

    var allowContractions: Bool {
        get { settings.allowContractions }
        set { settings.allowContractions = newValue }
    }

    var showWordHighlighting: Bool {
        get { settings.showWordHighlighting }
        set { settings.showWordHighlighting = newValue }
    }

    var showProgressBar: Bool {
        get { settings.showProgressBar }
        set { settings.showProgressBar = newValue }
    }

    var fontSize: FontSize {
        get { settings.fontSize }
        set { settings.fontSize = newValue }
    }

    var theme: AppTheme {
        get { settings.theme }
        set { settings.theme = newValue }
    }

    var wordVisibility: WordVisibility {
        get { settings.wordVisibility }
        set { settings.wordVisibility = newValue }
    }

    var wordRevealPercentage: Double {
        get { settings.wordRevealPercentage }
        set { settings.wordRevealPercentage = newValue }
    }

    var requireCorrectWord: Bool {
        get { settings.requireCorrectWord }
        set { settings.requireCorrectWord = newValue }
    }

    var showHints: Bool {
        get { settings.showHints }
        set { settings.showHints = newValue }
    }

    var hintDelay: Double {
        get { settings.hintDelay }
        set { settings.hintDelay = newValue }
    }

    // MARK: - Comparator Options

    var comparatorOptions: ComparatorOptions {
        ComparatorOptions(
            caseSensitive: settings.caseSensitive,
            ignorePunctuation: settings.ignorePunctuation,
            ignoreFillerWords: settings.ignoreFillerWords,
            allowContractions: settings.allowContractions,
            requireCorrectWord: settings.requireCorrectWord
        )
    }

    // MARK: - Reset

    func resetToDefaults() {
        settings = .default
    }

    // MARK: - Persistence

    private static func loadSettings(from userDefaults: UserDefaults) -> AppSettings {
        guard let data = userDefaults.data(forKey: "memorezar_settings") else {
            return .default
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            return .default
        }
    }

    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    // MARK: - Sound Settings Accessors

    var correctWordSound: CorrectWordSound {
        get { settings.correctWordSound }
        set { settings.correctWordSound = newValue }
    }

    var completionSound: CompletionSound {
        get { settings.completionSound }
        set { settings.completionSound = newValue }
    }

    // MARK: - Apply Settings

    private func applySettings() {
        // Apply alert settings to AlertManager
        let alertManager = AlertManager.shared
        alertManager.audioAlertEnabled = settings.audioAlertEnabled
        alertManager.visualAlertEnabled = settings.visualAlertEnabled
        alertManager.hapticAlertEnabled = settings.hapticAlertEnabled
        alertManager.mistakeSound = settings.mistakeSound
        alertManager.correctWordSound = settings.correctWordSound
        alertManager.completionSound = settings.completionSound
    }
}
