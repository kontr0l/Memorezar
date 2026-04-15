import Foundation

/// Community equivalence fetched from Supabase — carries the row ID so the
/// ViewModel can batch-report usage at session end.
struct CommunityEquivalence {
    let id: UUID
    let expectedWord: String
    let spokenWord: String
}

/// REST client for Supabase community equivalences.
/// - `reportEquivalence`: inserts a new user-accepted pair (first time only).
/// - `fetchEquivalences`: pulls the community list for the current quote's words.
/// - `reportUsage`: called at session end to atomically increment report_count
///   on every community equivalence that actually helped during the session.
class EquivalenceService {
    static let shared = EquivalenceService()
    private init() {}

    private let session = URLSession.shared

    // MARK: - Upload

    /// Insert a new equivalence pair (fire-and-forget).
    /// A 409 just means the row already exists — usage tracking via `reportUsage`
    /// will bump its count separately, so we ignore it.
    func reportEquivalence(expected: String, spoken: String) async {
        guard SupabaseConfig.isConfigured else { return }

        let normalizedExpected = normalize(expected)
        let normalizedSpoken = normalize(spoken)
        guard !normalizedExpected.isEmpty, !normalizedSpoken.isEmpty,
              normalizedExpected != normalizedSpoken else { return }

        var request = URLRequest(url: SupabaseConfig.equivalencesURL)
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "expected_word": normalizedExpected,
            "spoken_word": normalizedSpoken,
            "report_count": 1
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse,
               http.statusCode != 409, !(200...299).contains(http.statusCode) {
                print("[EquivalenceService] reportEquivalence status: \(http.statusCode)")
            }
        } catch {
            print("[EquivalenceService] reportEquivalence error: \(error)")
        }
    }

    /// Atomically bump report_count by 1 for every equivalence that matched
    /// during a recitation session. Called once at session end with the
    /// deduplicated set of matched IDs. Fire-and-forget.
    func reportUsage(ids: [UUID]) async {
        guard SupabaseConfig.isConfigured, !ids.isEmpty else { return }

        guard let rpcURL = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/rpc/increment_equivalence_reports") else { return }

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body: [String: Any] = ["ids": ids.map { $0.uuidString }]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                print("[EquivalenceService] reportUsage status: \(http.statusCode)")
            }
        } catch {
            print("[EquivalenceService] reportUsage error: \(error)")
        }
    }

    // MARK: - Fetch

    /// Fetch community equivalences for a list of expected words.
    /// Returns an array of rows (including IDs) so callers can batch-report usage later.
    func fetchEquivalences(forWords words: [String]) async -> [CommunityEquivalence] {
        guard SupabaseConfig.isConfigured, !words.isEmpty else { return [] }

        let normalizedWords = Set(words.map { normalize($0) }).filter { !$0.isEmpty }
        guard !normalizedWords.isEmpty else { return [] }

        let wordList = normalizedWords.joined(separator: ",")
        var components = URLComponents(url: SupabaseConfig.equivalencesURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "expected_word", value: "in.(\(wordList))"),
            URLQueryItem(name: "select", value: "id,expected_word,spoken_word")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await session.data(for: request)
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return rows.compactMap { row in
                guard let idString = row["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let expected = row["expected_word"] as? String,
                      let spoken = row["spoken_word"] as? String else { return nil }
                return CommunityEquivalence(id: id, expectedWord: expected, spokenWord: spoken)
            }
        } catch {
            print("[EquivalenceService] fetchEquivalences error: \(error)")
            return []
        }
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
}
