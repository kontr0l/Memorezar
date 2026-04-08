import Foundation
import SwiftUI

/// A translated version of a quote (title + text in another language)
struct TranslatedQuote: Codable, Equatable {
    let title: String
    let text: String
}

/// A quote or text passage that the user wants to memorize
struct Quote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var text: String
    var categoryId: UUID  // Reference to QuoteCategory
    var createdAt: Date
    var lastPracticedAt: Date?

    // Progress tracking
    var practiceCount: Int
    var bestAccuracy: Double  // 0.0 to 1.0
    var lastAccuracy: Double? // Most recent attempt

    // Translations — keyed by language code (e.g. "es" → Spanish)
    var translations: [String: TranslatedQuote]?
    var primaryLanguage: String?  // Language of title/text (e.g. "es"); nil = English
    var lastPracticedLanguage: String?  // Language user last practiced in; nil = primary

    // Mastery challenge — 3 consecutive passes at 95%+ with 0% reveal to earn Mastered
    var masteryStreak: Int  // 0-3: consecutive master-mode passes

    // Reveal progression: 1=90% revealed, 2=50%, 3=10%. 0=not started (defaults to level 1)
    var revealLevel: Int

    /// The reveal percentage for the current level
    var revealPercentageForLevel: Double {
        switch revealLevel {
        case 2: return 50
        case 3: return 20
        default: return 90  // level 0 or 1
        }
    }

    /// The letter reveal step for the current level (first-letter mode)
    var letterStepForLevel: Int {
        switch revealLevel {
        case 2: return 2
        case 3: return 1
        default: return 3  // level 0 or 1
        }
    }

    // Explicit sort order for pack quotes (nil = use array/insertion order)
    var sortOrder: Int?

    // Chunking — optional split into parts for practicing sections
    var chunks: [String]?
    var activeChunkIndex: Int?
    var chunkAccuracies: [Double]?  // Parallel to chunks, 0.0-1.0 per chunk
    var chunkRevealPercentages: [Double]?  // Reveal % used when chunk was completed (0-100)

    // Legacy support for old category enum
    private var legacyCategory: LegacyQuoteCategory?

    /// Whether this quote has been split into multiple parts
    var isSplit: Bool { chunks != nil && (chunks?.count ?? 0) > 1 }

    init(
        id: UUID = UUID(),
        title: String,
        text: String,
        categoryId: UUID = QuoteCategory.defaultCategory.id,
        createdAt: Date = Date(),
        lastPracticedAt: Date? = nil,
        practiceCount: Int = 0,
        bestAccuracy: Double = 0,
        lastAccuracy: Double? = nil,
        translations: [String: TranslatedQuote]? = nil,
        primaryLanguage: String? = nil,
        lastPracticedLanguage: String? = nil,
        masteryStreak: Int = 0,
        revealLevel: Int = 0,
        sortOrder: Int? = nil,
        chunks: [String]? = nil,
        activeChunkIndex: Int? = nil,
        chunkAccuracies: [Double]? = nil,
        chunkRevealPercentages: [Double]? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.categoryId = categoryId
        self.createdAt = createdAt
        self.lastPracticedAt = lastPracticedAt
        self.practiceCount = practiceCount
        self.bestAccuracy = bestAccuracy
        self.lastAccuracy = lastAccuracy
        self.translations = translations
        self.primaryLanguage = primaryLanguage
        self.lastPracticedLanguage = lastPracticedLanguage
        self.masteryStreak = masteryStreak
        self.revealLevel = revealLevel
        self.sortOrder = sortOrder
        self.chunks = chunks
        self.activeChunkIndex = activeChunkIndex
        self.chunkAccuracies = chunkAccuracies
        self.chunkRevealPercentages = chunkRevealPercentages
    }

    // Custom decoding to handle legacy enum-based categories
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastPracticedAt = try container.decodeIfPresent(Date.self, forKey: .lastPracticedAt)
        practiceCount = try container.decode(Int.self, forKey: .practiceCount)
        bestAccuracy = try container.decode(Double.self, forKey: .bestAccuracy)
        lastAccuracy = try container.decodeIfPresent(Double.self, forKey: .lastAccuracy)
        translations = try container.decodeIfPresent([String: TranslatedQuote].self, forKey: .translations)
        primaryLanguage = try container.decodeIfPresent(String.self, forKey: .primaryLanguage)
        lastPracticedLanguage = try container.decodeIfPresent(String.self, forKey: .lastPracticedLanguage)
        chunks = try container.decodeIfPresent([String].self, forKey: .chunks)
        activeChunkIndex = try container.decodeIfPresent(Int.self, forKey: .activeChunkIndex)
        chunkAccuracies = try container.decodeIfPresent([Double].self, forKey: .chunkAccuracies)
        chunkRevealPercentages = try container.decodeIfPresent([Double].self, forKey: .chunkRevealPercentages)
        masteryStreak = try container.decodeIfPresent(Int.self, forKey: .masteryStreak) ?? 0
        revealLevel = try container.decodeIfPresent(Int.self, forKey: .revealLevel) ?? 0
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)

        // Try to decode new categoryId first, fall back to legacy category
        if let catId = try? container.decode(UUID.self, forKey: .categoryId) {
            categoryId = catId
        } else if let legacy = try? container.decode(LegacyQuoteCategory.self, forKey: .legacyCategory) {
            // Map legacy category to default
            categoryId = QuoteCategory.defaultCategory.id
            legacyCategory = legacy
        } else {
            categoryId = QuoteCategory.defaultCategory.id
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, text, categoryId, createdAt, lastPracticedAt
        case practiceCount, bestAccuracy, lastAccuracy, translations, primaryLanguage, lastPracticedLanguage, masteryStreak, revealLevel, sortOrder, chunks, activeChunkIndex, chunkAccuracies, chunkRevealPercentages
        case legacyCategory = "category"  // Map old "category" key to legacyCategory
    }

    /// The title to display, respecting lastPracticedLanguage if a translation exists
    var displayTitle: String {
        if let lang = lastPracticedLanguage, let t = translations?[lang] {
            return t.title
        }
        return title
    }

    /// The text to display, respecting lastPracticedLanguage if a translation exists
    var displayText: String {
        if let lang = lastPracticedLanguage, let t = translations?[lang] {
            return t.text
        }
        return text
    }

    /// Word count in the quote
    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// Short preview of the display text
    var preview: String {
        let words = displayText.split(whereSeparator: { $0.isWhitespace }).prefix(10)
        let preview = words.joined(separator: " ")
        return words.count >= 10 ? preview + "..." : preview
    }

    /// Whether the title is just the first few words of the text (redundant with preview)
    var titleMatchesPreview: Bool {
        let displayTitleText = displayTitle
        let displayBodyText = displayText
        // Extract only alphanumeric words, lowercased
        let titleWords = displayTitleText.lowercased().unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : Character(" ") }
            .map(String.init).joined()
            .split(separator: " ").map(String.init)
        let textWords = displayBodyText.lowercased().unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : Character(" ") }
            .map(String.init).joined()
            .split(separator: " ").map(String.init)
        guard !titleWords.isEmpty else { return false }
        guard textWords.count >= titleWords.count else { return false }
        return Array(textWords.prefix(titleWords.count)) == titleWords
    }

    /// Mastery level tied to reveal level progression.
    /// No badge until at least 1 practice. Then: Learning (level 1) → Advancing (level 2) → Proficient (level 3) → Mastered (crown challenge).
    var masteryLevel: MasteryLevel {
        if practiceCount == 0 { return .none }
        if masteryStreak >= 3 { return .mastered }
        let level = max(1, revealLevel)
        switch level {
        case 3: return .proficient
        case 2: return .advancing
        default: return .learning
        }
    }

    /// Whether the mastered status is stale (no practice in 14+ days)
    var isMasteryStale: Bool {
        guard masteryStreak >= 3, let lastPracticed = lastPracticedAt else { return false }
        return Date().timeIntervalSince(lastPracticed) > 14 * 24 * 3600
    }
}

/// Image source for category cover photos
enum CategoryImageSource: Codable, Equatable, Hashable {
    case local(String)              // filename in app's Documents directory
    case unsplash(UnsplashImageInfo) // hotlinked URL + attribution
    case none                        // placeholder gradient
}

/// Unsplash photo metadata for attribution and display
struct UnsplashImageInfo: Codable, Equatable, Hashable {
    let regularURL: String
    let smallURL: String
    let photographerName: String
    let photographerURL: String
    let downloadURL: String  // trigger download endpoint per Unsplash API TOS
}

/// User-customizable category for organizing quotes
struct QuoteCategory: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var imageSource: CategoryImageSource
    var isDefault: Bool  // Cannot be deleted
    var gradientIndex: Int?  // Index into gradient palette when no photo is set
    var sourcePackId: String?  // Links to Supabase suggestion_packs.id for sync

    // Legacy icon field for backward compatibility during migration
    private var icon: String?

    /// Available gradient palettes for categories without cover photos
    static let gradientPalettes: [[Color]] = [
        [.blue, .blue],
        [.orange, .pink],
        [.green, .teal],
        [.indigo, .cyan],
        [.red, .orange],
        [.mint, .green],
        [.blue, .pink],
        [.teal, .blue],
    ]

    init(id: UUID = UUID(), name: String, imageSource: CategoryImageSource = .none, isDefault: Bool = false, gradientIndex: Int? = nil, sourcePackId: String? = nil) {
        self.id = id
        self.name = name
        self.imageSource = imageSource
        self.isDefault = isDefault
        self.gradientIndex = gradientIndex ?? Int.random(in: 0..<Self.gradientPalettes.count)
        self.sourcePackId = sourcePackId
    }

    // Custom decoding: migrate old icon-based categories to imageSource
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        gradientIndex = try container.decodeIfPresent(Int.self, forKey: .gradientIndex)
        sourcePackId = try container.decodeIfPresent(String.self, forKey: .sourcePackId)

        if let source = try? container.decode(CategoryImageSource.self, forKey: .imageSource) {
            imageSource = source
        } else {
            // Legacy migration: old category with icon but no imageSource
            imageSource = .none
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, imageSource, isDefault, icon, gradientIndex, sourcePackId
    }

    /// The default "My Quotes" category
    static let defaultCategory = QuoteCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "My Quotes",
        isDefault: true,
        gradientIndex: Int.random(in: 0..<gradientPalettes.count)
    )
}

// Legacy support - map old enum values to new category system
enum LegacyQuoteCategory: String, Codable {
    case general = "General"
    case scripture = "Scripture"
    case poetry = "Poetry"
    case speech = "Speech"
    case lyrics = "Lyrics"
    case quote = "Quote"
    case custom = "Custom"
}

/// Mastery levels for gamification — tied to reveal level progression
enum MasteryLevel: String, Codable {
    case none = "None"
    case learning = "Learning"
    case advancing = "Advancing"
    case proficient = "Proficient"
    case mastered = "Mastered"

    var localizedName: String {
        switch self {
        case .none: return String(localized: "None")
        case .learning: return String(localized: "Learning")
        case .advancing: return String(localized: "Advancing")
        case .proficient: return String(localized: "Proficient")
        case .mastered: return String(localized: "Mastered")
        }
    }

    var color: String {
        switch self {
        case .none: return "gray"
        case .learning: return "green"
        case .advancing: return "orange"
        case .proficient: return "indigo"
        case .mastered: return "yellow"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle"
        case .learning: return "leaf.fill"
        case .advancing: return "lightbulb.max.fill"
        case .proficient: return "sparkles"
        case .mastered: return "crown.fill"
        }
    }
}

/// Statistics for a single practice session
struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let quoteId: UUID
    let startedAt: Date
    let completedAt: Date
    let totalWords: Int
    let testedWords: Int          // Number of hidden words the user actually had to recite
    let correctWords: Int
    let mistakes: [PracticeMistake]
    let revealPercentage: Double  // Slider value at session end (0-100)
    let hintCount: Int            // Number of hints used during session

    var accuracy: Double {
        let tested = testedWords > 0 ? testedWords : totalWords
        guard tested > 0 else { return 0 }
        return Double(max(0, tested - mistakes.count)) / Double(tested)
    }

    var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }

    // Backward-compatible decoding: old sessions default to 50% reveal, 0 hints
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        quoteId = try container.decode(UUID.self, forKey: .quoteId)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        totalWords = try container.decode(Int.self, forKey: .totalWords)
        testedWords = try container.decodeIfPresent(Int.self, forKey: .testedWords) ?? 0  // 0 = legacy, falls back to totalWords
        correctWords = try container.decode(Int.self, forKey: .correctWords)
        mistakes = try container.decode([PracticeMistake].self, forKey: .mistakes)
        revealPercentage = try container.decodeIfPresent(Double.self, forKey: .revealPercentage) ?? 50
        hintCount = try container.decodeIfPresent(Int.self, forKey: .hintCount) ?? 0
    }

    init(id: UUID, quoteId: UUID, startedAt: Date, completedAt: Date, totalWords: Int, testedWords: Int = 0, correctWords: Int, mistakes: [PracticeMistake], revealPercentage: Double = 50, hintCount: Int = 0) {
        self.id = id
        self.quoteId = quoteId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.totalWords = totalWords
        self.testedWords = testedWords
        self.correctWords = correctWords
        self.mistakes = mistakes
        self.revealPercentage = revealPercentage
        self.hintCount = hintCount
    }
}

/// Certainty level for a mistake
enum MistakeCertainty: String, Codable {
    case definite
    case uncertain   // Legacy — kept for backward-compatible decoding of old sessions
}

/// Record of a mistake during practice
struct PracticeMistake: Codable {
    let position: Int
    let expectedWord: String
    let spokenWord: String
    let timestamp: Date
    let confidence: Float
    let certainty: MistakeCertainty

    init(position: Int, expectedWord: String, spokenWord: String, timestamp: Date,
         confidence: Float = 0.0, certainty: MistakeCertainty = .definite) {
        self.position = position
        self.expectedWord = expectedWord
        self.spokenWord = spokenWord
        self.timestamp = timestamp
        self.confidence = confidence
        self.certainty = certainty
    }

    // Backward-compatible decoding for stored sessions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(Int.self, forKey: .position)
        expectedWord = try container.decode(String.self, forKey: .expectedWord)
        spokenWord = try container.decode(String.self, forKey: .spokenWord)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        confidence = try container.decodeIfPresent(Float.self, forKey: .confidence) ?? 0.0
        certainty = try container.decodeIfPresent(MistakeCertainty.self, forKey: .certainty) ?? .definite
    }
}
