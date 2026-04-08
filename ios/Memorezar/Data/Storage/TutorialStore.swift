import Foundation

/// Tracks which tip buttons the user has actually tapped.
/// A tip shows every app launch until its button is tapped.
final class TutorialStore: ObservableObject {

    /// Tip IDs whose target button has been tapped at least once.
    @Published var completedTips: Set<String> {
        didSet { save() }
    }

    /// Whether the user has completed the initial onboarding setup flow.
    @Published var hasCompletedOnboarding: Bool {
        didSet { userDefaults.set(hasCompletedOnboarding, forKey: onboardingKey) }
    }

    private let key = "memorezar_completed_tips"
    private let onboardingKey = "memorezar_has_completed_onboarding"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let saved = userDefaults.stringArray(forKey: "memorezar_completed_tips") ?? []
        self.completedTips = Set(saved)
        self.hasCompletedOnboarding = userDefaults.bool(forKey: "memorezar_has_completed_onboarding")
    }

    func shouldShowTip(_ tip: TipDefinition) -> Bool {
        guard !completedTips.contains(tip.id) else { return false }
        if let required = tip.requiredTipId, !completedTips.contains(required) {
            return false
        }
        return true
    }

    func completeTip(_ tipId: String) {
        completedTips.insert(tipId)
    }

    func resetAll() {
        completedTips = []
    }

    private func save() {
        userDefaults.set(Array(completedTips), forKey: key)
    }
}
