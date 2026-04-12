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

    var soundTheme: SoundTheme {
        get { settings.soundTheme }
        set { settings.soundTheme = newValue }
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

    var defaultMemorizationMode: MemorizationMode {
        get { settings.defaultMemorizationMode }
        set { settings.defaultMemorizationMode = newValue }
    }

    var firstLetterModeEnabled: Bool {
        get { settings.firstLetterModeEnabled }
        set { settings.firstLetterModeEnabled = newValue }
    }

    var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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
        // CloudBackupService.shared.scheduleBackup()  // BACKUP-001: auto-backup disabled, manual only
    }

    // MARK: - Apply Settings

    private func applySettings() {
        let alertManager = AlertManager.shared
        alertManager.audioAlertEnabled = settings.audioAlertEnabled
        alertManager.visualAlertEnabled = settings.visualAlertEnabled
        alertManager.hapticAlertEnabled = settings.hapticAlertEnabled
        alertManager.soundTheme = settings.soundTheme
    }
}
