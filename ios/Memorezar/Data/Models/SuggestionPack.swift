import Foundation

/// A single quote within a suggestion pack
struct SuggestionQuote: Codable {
    let title: String
    let text: String
    let translations: [String: TranslatedQuote]?

    init(title: String, text: String, translations: [String: TranslatedQuote]? = nil) {
        self.title = title
        self.text = text
        self.translations = translations
    }

    /// Returns the title localized for the given language, falling back to English
    func localizedTitle(for lang: String) -> String {
        translations?[lang]?.title ?? title
    }

    /// Returns the text localized for the given language, falling back to English
    func localizedText(for lang: String) -> String {
        translations?[lang]?.text ?? text
    }
}

/// Translated pack metadata (name + description)
struct TranslatedPack: Codable {
    let name: String
    let description: String
}

/// A curated pack of quotes that users can add to their library
struct SuggestionPack: Identifiable, Hashable, Codable {
    static func == (lhs: SuggestionPack, rhs: SuggestionPack) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let name: String
    let description: String
    let coverSearchQuery: String
    let coverAsset: String?         // bundled asset catalog image name
    let coverURL: String?           // remote cover image URL
    let version: Int                // bump on server to push updates to installed packs
    let translations: [String: TranslatedPack]?
    let isFree: Bool                // true = available to all, false = Pro only
    let quotes: [SuggestionQuote]

    init(id: String, name: String, description: String, coverSearchQuery: String, coverAsset: String? = nil, coverURL: String? = nil, version: Int = 1, translations: [String: TranslatedPack]? = nil, isFree: Bool = true, quotes: [SuggestionQuote]) {
        self.id = id
        self.name = name
        self.description = description
        self.coverSearchQuery = coverSearchQuery
        self.coverAsset = coverAsset
        self.coverURL = coverURL
        self.version = version
        self.translations = translations
        self.isFree = isFree
        self.quotes = quotes
    }

    /// Returns the pack name localized for the given language, falling back to English
    func localizedName(for lang: String) -> String {
        translations?[lang]?.name ?? name
    }

    /// Returns the pack description localized for the given language, falling back to English
    func localizedDescription(for lang: String) -> String {
        translations?[lang]?.description ?? description
    }
}


// MARK: - Language Helper

enum LanguageHelper {
    /// Returns the user's preferred language code (e.g., "es", "fr", "it")
    /// Falls back to "en" if the system language isn't available
    static var preferredLanguageCode: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        // Extract base language: "es-419" → "es", "fr-FR" → "fr"
        let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        return code
    }
}
