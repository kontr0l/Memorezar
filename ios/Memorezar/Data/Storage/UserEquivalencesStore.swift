import Foundation
import SwiftUI

/// Persists user-defined word equivalences.
/// When the speech recognizer consistently mishears a word,
/// the user can "Accept as match" to teach the app that
/// the spoken variant is equivalent to the expected word.
final class UserEquivalencesStore: ObservableObject {

    // MARK: - Published Properties

    /// Key is normalized expected word, value is set of accepted spoken alternatives
    @Published private(set) var equivalences: [String: Set<String>] = [:]

    // MARK: - Private Properties

    private let storageKey = "memorezar_user_equivalences"
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.equivalences = Self.load(from: userDefaults)
    }

    // MARK: - Public Methods

    /// Add an equivalence: "when I expect `expected`, accept `spoken` as a match"
    func addEquivalence(expected: String, spoken: String) {
        let normalizedExpected = normalize(expected)
        let normalizedSpoken = normalize(spoken)
        guard !normalizedExpected.isEmpty, !normalizedSpoken.isEmpty,
              normalizedExpected != normalizedSpoken else { return }

        var set = equivalences[normalizedExpected] ?? []
        set.insert(normalizedSpoken)
        equivalences[normalizedExpected] = set
        save()
    }

    /// Remove a specific equivalence
    func removeEquivalence(expected: String, spoken: String) {
        let normalizedExpected = normalize(expected)
        let normalizedSpoken = normalize(spoken)

        guard var set = equivalences[normalizedExpected] else { return }
        set.remove(normalizedSpoken)
        if set.isEmpty {
            equivalences.removeValue(forKey: normalizedExpected)
        } else {
            equivalences[normalizedExpected] = set
        }
        save()
    }

    /// Lookup accepted alternatives for an expected word
    func equivalences(for expected: String) -> Set<String>? {
        equivalences[normalize(expected)]
    }

    /// Remove all user equivalences
    func clearAll() {
        equivalences = [:]
        save()
    }

    // MARK: - Private

    private func normalize(_ word: String) -> String {
        word.lowercased()
            .unicodeScalars
            .filter { !CharacterSet.punctuationCharacters.contains($0) }
            .map { Character($0) }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Persistence

    private static func load(from userDefaults: UserDefaults) -> [String: Set<String>] {
        guard let data = userDefaults.data(forKey: "memorezar_user_equivalences") else {
            return [:]
        }
        do {
            let decoded = try JSONDecoder().decode([String: [String]].self, from: data)
            return decoded.mapValues { Set($0) }
        } catch {
            print("Failed to load user equivalences: \(error)")
            return [:]
        }
    }

    private func save() {
        do {
            let encodable = equivalences.mapValues { Array($0) }
            let data = try JSONEncoder().encode(encodable)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to save user equivalences: \(error)")
        }
    }
}
