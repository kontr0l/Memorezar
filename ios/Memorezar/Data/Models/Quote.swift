import Foundation

/// A quote or text passage that the user wants to memorize
struct Quote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var text: String
    var category: QuoteCategory
    var createdAt: Date
    var lastPracticedAt: Date?

    // Progress tracking
    var practiceCount: Int
    var bestAccuracy: Double  // 0.0 to 1.0
    var lastAccuracy: Double? // Most recent attempt

    init(
        id: UUID = UUID(),
        title: String,
        text: String,
        category: QuoteCategory = .general,
        createdAt: Date = Date(),
        lastPracticedAt: Date? = nil,
        practiceCount: Int = 0,
        bestAccuracy: Double = 0,
        lastAccuracy: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.category = category
        self.createdAt = createdAt
        self.lastPracticedAt = lastPracticedAt
        self.practiceCount = practiceCount
        self.bestAccuracy = bestAccuracy
        self.lastAccuracy = lastAccuracy
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

/// Categories for organizing quotes
enum QuoteCategory: String, Codable, CaseIterable {
    case general = "General"
    case scripture = "Scripture"
    case poetry = "Poetry"
    case speech = "Speech"
    case lyrics = "Lyrics"
    case quote = "Quote"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .general: return "text.quote"
        case .scripture: return "book.closed.fill"
        case .poetry: return "text.book.closed.fill"
        case .speech: return "person.wave.2.fill"
        case .lyrics: return "music.note"
        case .quote: return "quote.bubble.fill"
        case .custom: return "folder.fill"
        }
    }
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
