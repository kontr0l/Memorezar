import Foundation

/// Tracks community recording IDs the user has already viewed.
/// Drives the "NEW" badges on the audio mode icon, the Community tab,
/// and each community recording row.
final class SeenCommunityRecordingsStore: ObservableObject {

    @Published var seenIds: Set<String> {
        didSet { save() }
    }

    private let key = "memorezar_seen_community_recordings"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let saved = userDefaults.stringArray(forKey: key) ?? []
        self.seenIds = Set(saved)
    }

    /// Add the given IDs to the seen set. No-op if all are already seen.
    func markSeen(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let updated = seenIds.union(ids)
        guard updated.count != seenIds.count else { return }
        seenIds = updated
    }

    private func save() {
        userDefaults.set(Array(seenIds), forKey: key)
    }
}
