import Foundation

/// Fetches suggestion packs from the remote server.
/// All packs require internet to browse. Once added to the library,
/// quotes are stored locally and work offline.
final class PackService {
    static let shared = PackService()

    private var packsURL: URL {
        URL(string: "\(SupabaseConfig.projectURL)/rest/v1/suggestion_packs?select=*&order=sort_order.asc")!
    }

    // MARK: - Fetch Packs for Browsing

    /// Fetch available packs from the server. Returns empty if offline.
    /// Supabase is the single source of truth — no cache or bundled fallback.
    func fetchPacks() async -> [SuggestionPack] {
        if let remote = await fetchRemote() {
            return remote
        }
        return []
    }

    // MARK: - Sync Installed Packs

    /// Check the server for updates to packs the user has already added.
    /// Uses version numbers — only fetches full pack data when the server
    /// version is higher than what we stored locally.
    func syncInstalledPacks(installedVersions: [String: Int], store: QuoteStore) async {
        guard !installedVersions.isEmpty else { return }

        guard let remotePacks = await fetchRemote() else { return }

        let lang = LanguageHelper.preferredLanguageCode

        for (packId, localVersion) in installedVersions {
            guard let remotePack = remotePacks.first(where: { $0.id == packId }) else { continue }
            guard remotePack.version > localVersion else { continue }

            // Version bumped — full resync of this pack
            // Match by sourcePackId (resilient to server-side name changes)
            guard let category = store.categories.first(where: { $0.sourcePackId == packId }) else { continue }

            // Update category name if it changed on the server (use localized name)
            let localizedName = remotePack.localizedName(for: lang)
            if category.name != localizedName {
                var updated = category
                updated.name = localizedName
                store.updateCategory(updated)
            }

            // Replace all quotes in this category with the latest from server
            store.replaceQuotes(inCategory: category.id, with: remotePack.quotes, preferredLanguage: lang)

            // Update cover image if changed
            if let coverURL = remotePack.coverURL {
                store.updateCoverImage(from: coverURL, for: category)
            }

            // Store the new version
            store.setInstalledPackVersion(packId, version: remotePack.version)
        }
    }

    // MARK: - Remote

    private func fetchRemote() async -> [SuggestionPack]? {
        var request = URLRequest(url: packsURL)
        request.timeoutInterval = 10
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let rows = try JSONDecoder().decode([RemotePackRow].self, from: data)
            return rows.compactMap { $0.toSuggestionPack() }
        } catch {
            print("[PackService] Remote fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

}

// MARK: - Remote Row Decoding

/// Maps the Supabase row structure to our domain model
private struct RemotePackRow: Codable {
    let id: String
    let name: String
    let description: String
    let cover_search_query: String?
    let cover_url: String?
    let cover_asset: String?
    let version: Int?
    let translations: [String: TranslatedPack]?
    let is_free: Bool?
    let quotes: [RemoteQuoteRow]

    struct RemoteQuoteRow: Codable {
        let title: String
        let text: String
        let translations: [String: TranslatedQuote]?
    }

    func toSuggestionPack() -> SuggestionPack {
        SuggestionPack(
            id: id,
            name: name,
            description: description,
            coverSearchQuery: cover_search_query ?? "",
            coverAsset: cover_asset,
            coverURL: cover_url,
            version: version ?? 1,
            translations: translations,
            isFree: is_free ?? true,
            quotes: quotes.map {
                SuggestionQuote(title: $0.title, text: $0.text, translations: $0.translations)
            }
        )
    }
}
