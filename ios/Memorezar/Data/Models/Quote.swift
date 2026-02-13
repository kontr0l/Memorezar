import Foundation

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

    // Legacy support for old category enum
    private var legacyCategory: LegacyQuoteCategory?

    init(
        id: UUID = UUID(),
        title: String,
        text: String,
        categoryId: UUID = QuoteCategory.defaultCategory.id,
        createdAt: Date = Date(),
        lastPracticedAt: Date? = nil,
        practiceCount: Int = 0,
        bestAccuracy: Double = 0,
        lastAccuracy: Double? = nil
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
        case practiceCount, bestAccuracy, lastAccuracy
        case legacyCategory = "category"  // Map old "category" key to legacyCategory
    }

    /// Word count in the quote
    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// Short preview of the text
    var preview: String {
        let words = text.split(whereSeparator: { $0.isWhitespace }).prefix(10)
        let preview = words.joined(separator: " ")
        return words.count >= 10 ? preview + "..." : preview
    }

    /// Mastery level based on practice count and accuracy
    var masteryLevel: MasteryLevel {
        if practiceCount == 0 { return .new }
        if bestAccuracy >= 0.95 && practiceCount >= 5 { return .mastered }
        if bestAccuracy >= 0.80 && practiceCount >= 3 { return .proficient }
        if bestAccuracy >= 0.60 { return .learning }
        return .beginner
    }
}

/// User-customizable category for organizing quotes
struct QuoteCategory: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var isDefault: Bool  // Cannot be deleted

    init(id: UUID = UUID(), name: String, icon: String = "folder.fill", isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isDefault = isDefault
    }

    /// The default "My Quotes" category
    static let defaultCategory = QuoteCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "My Quotes",
        icon: "text.quote",
        isDefault: true
    )

    /// Preset categories that users can add if they want
    static let presets: [QuoteCategory] = [
        QuoteCategory(name: "Scripture", icon: "book.closed.fill"),
        QuoteCategory(name: "Poetry", icon: "text.book.closed.fill"),
        QuoteCategory(name: "Speeches", icon: "person.wave.2.fill"),
        QuoteCategory(name: "Lyrics", icon: "music.note"),
        QuoteCategory(name: "Famous Quotes", icon: "quote.bubble.fill"),
    ]

    /// Available icons for custom categories
    static let availableIcons: [String] = [
        "folder.fill",
        "text.quote",
        "book.closed.fill",
        "text.book.closed.fill",
        "person.wave.2.fill",
        "music.note",
        "quote.bubble.fill",
        "star.fill",
        "heart.fill",
        "flag.fill",
        "bookmark.fill",
        "tag.fill",
        "doc.text.fill",
        "graduationcap.fill",
        "brain.head.profile",
        "lightbulb.fill"
    ]
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

/// Mastery levels for gamification
enum MasteryLevel: String, Codable {
    case new = "New"
    case beginner = "Beginner"
    case learning = "Learning"
    case proficient = "Proficient"
    case mastered = "Mastered"

    var color: String {
        switch self {
        case .new: return "gray"
        case .beginner: return "red"
        case .learning: return "orange"
        case .proficient: return "blue"
        case .mastered: return "green"
        }
    }

    var icon: String {
        switch self {
        case .new: return "circle"
        case .beginner: return "flame"
        case .learning: return "book"
        case .proficient: return "star.leadinghalf.filled"
        case .mastered: return "star.fill"
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
    let correctWords: Int
    let mistakes: [PracticeMistake]

    var accuracy: Double {
        guard totalWords > 0 else { return 0 }
        return Double(correctWords) / Double(totalWords)
    }

    var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
}

/// Record of a mistake during practice
struct PracticeMistake: Codable {
    let position: Int
    let expectedWord: String
    let spokenWord: String
    let timestamp: Date
}
