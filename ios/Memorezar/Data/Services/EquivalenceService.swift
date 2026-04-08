import Foundation

/// REST client for Supabase community equivalences API.
/// Uploads user-accepted word equivalences so all users benefit,
/// and fetches crowd-sourced equivalences for use during recitation.
class EquivalenceService {
    static let shared = EquivalenceService()
    private init() {}

    private let session = URLSession.shared

    // MARK: - Upload

    /// Report an equivalence pair (fire-and-forget upsert).
    /// On conflict (same expected+spoken), increments report_count.
    /// Errors are printed but never surface to the user.
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
        // Upsert: on conflict merge duplicates, increment report_count via RPC isn't needed —
        // Supabase merge-duplicates will update, but we need to increment. Use a two-step approach:
        // First try insert; if conflict (409), do a PATCH to increment.
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "expected_word": normalizedExpected,
            "spoken_word": normalizedSpoken,
            "report_count": 1
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 409 {
                    // Conflict — row exists, increment report_count via PATCH
                    await incrementReportCount(expected: normalizedExpected, spoken: normalizedSpoken)
                } else if !(200...299).contains(httpResponse.statusCode) {
                    print("[EquivalenceService] reportEquivalence unexpected status: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("[EquivalenceService] reportEquivalence error: \(error)")
        }
    }

    /// Increment report_count for an existing equivalence via Supabase RPC
    private func incrementReportCount(expected: String, spoken: String) async {
        // Use Supabase's PostgREST PATCH with a filter to increment
        // PostgREST doesn't support SQL expressions in PATCH body directly,
        // so we fetch current count then update.
        var components = URLComponents(url: SupabaseConfig.equivalencesURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "expected_word", value: "eq.\(expected)"),
            URLQueryItem(name: "spoken_word", value: "eq.\(spoken)"),
            URLQueryItem(name: "select", value: "report_count")
        ]

        guard let fetchURL = components.url else { return }

        var fetchRequest = URLRequest(url: fetchURL)
        for (key, value) in SupabaseConfig.headers {
            fetchRequest.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await session.data(for: fetchRequest)
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let currentCount = rows.first?["report_count"] as? Int else { return }

            // PATCH with incremented count
            var patchComponents = URLComponents(url: SupabaseConfig.equivalencesURL, resolvingAgainstBaseURL: false)!
            patchComponents.queryItems = [
                URLQueryItem(name: "expected_word", value: "eq.\(expected)"),
                URLQueryItem(name: "spoken_word", value: "eq.\(spoken)")
            ]
            guard let patchURL = patchComponents.url else { return }

            var patchRequest = URLRequest(url: patchURL)
            patchRequest.httpMethod = "PATCH"
            for (key, value) in SupabaseConfig.headers {
                patchRequest.setValue(value, forHTTPHeaderField: key)
            }

            let patchBody: [String: Any] = ["report_count": currentCount + 1]
            patchRequest.httpBody = try JSONSerialization.data(withJSONObject: patchBody)

            let (_, patchResponse) = try await session.data(for: patchRequest)
            if let httpResponse = patchResponse as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                print("[EquivalenceService] incrementReportCount PATCH status: \(httpResponse.statusCode)")
            }
        } catch {
            print("[EquivalenceService] incrementReportCount error: \(error)")
        }
    }

    // MARK: - Fetch

    /// Fetch community equivalences for a list of expected words.
    /// Returns `[expectedWord: Set<spokenAlternatives>]` — same format as UserEquivalencesStore.
    /// Returns empty dict on any error.
    func fetchEquivalences(forWords words: [String]) async -> [String: Set<String>] {
        guard SupabaseConfig.isConfigured, !words.isEmpty else { return [:] }

        let normalizedWords = Set(words.map { normalize($0) }).filter { !$0.isEmpty }
        guard !normalizedWords.isEmpty else { return [:] }

        // Build query: GET /equivalences?expected_word=in.(word1,word2,...)
        let wordList = normalizedWords.joined(separator: ",")
        var components = URLComponents(url: SupabaseConfig.equivalencesURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "expected_word", value: "in.(\(wordList))"),
            URLQueryItem(name: "select", value: "expected_word,spoken_word")
        ]

        guard let url = components.url else { return [:] }

        var request = URLRequest(url: url)
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await session.data(for: request)
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
                return [:]
            }

            var result: [String: Set<String>] = [:]
            for row in rows {
                guard let expected = row["expected_word"],
                      let spoken = row["spoken_word"] else { continue }
                result[expected, default: []].insert(spoken)
            }
            return result
        } catch {
            print("[EquivalenceService] fetchEquivalences error: \(error)")
            return [:]
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
