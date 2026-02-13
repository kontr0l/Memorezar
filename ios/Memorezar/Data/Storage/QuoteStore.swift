import Foundation
import SwiftUI
import Combine

/// Observable store for managing quotes
/// Persists to UserDefaults (could be upgraded to Core Data for larger datasets)
final class QuoteStore: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var sessions: [PracticeSession] = []
    @Published private(set) var categories: [QuoteCategory] = []

    // MARK: - Private Properties

    private let quotesKey = "memorezar_quotes"
    private let sessionsKey = "memorezar_sessions"
    private let categoriesKey = "memorezar_categories"
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCategories()
        loadQuotes()
        loadSessions()

        // Ensure default category exists
        if !categories.contains(where: { $0.id == QuoteCategory.defaultCategory.id }) {
            categories.insert(QuoteCategory.defaultCategory, at: 0)
            saveCategories()
        }

        // Add sample quotes if empty (first launch)
        if quotes.isEmpty {
            addSampleQuotes()
        }
    }

    // MARK: - Category Management

    func addCategory(_ category: QuoteCategory) {
        categories.append(category)
        saveCategories()
    }

    func updateCategory(_ category: QuoteCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }

    func deleteCategory(_ category: QuoteCategory) {
        // Don't allow deleting default category
        guard !category.isDefault else { return }

        // Move all quotes in this category to default
        for i in quotes.indices {
            if quotes[i].categoryId == category.id {
                quotes[i].categoryId = QuoteCategory.defaultCategory.id
            }
        }
        saveQuotes()

        categories.removeAll { $0.id == category.id }
        saveCategories()
    }

    func getCategory(byId id: UUID) -> QuoteCategory? {
        categories.first { $0.id == id }
    }

    /// Add a preset category
    func addPresetCategory(_ preset: QuoteCategory) {
        // Check if already exists by name
        guard !categories.contains(where: { $0.name == preset.name }) else { return }
        addCategory(preset)
    }

    /// Get quotes for a specific category
    func quotes(inCategory categoryId: UUID) -> [Quote] {
        quotes.filter { $0.categoryId == categoryId }
    }

    // MARK: - Quote Management

    func addQuote(_ quote: Quote) {
        quotes.append(quote)
        saveQuotes()
    }

    func updateQuote(_ quote: Quote) {
        if let index = quotes.firstIndex(where: { $0.id == quote.id }) {
            quotes[index] = quote
            saveQuotes()
        }
    }

    func deleteQuote(_ quote: Quote) {
        quotes.removeAll { $0.id == quote.id }
        saveQuotes()
    }

    func deleteQuotes(at offsets: IndexSet) {
        quotes.remove(atOffsets: offsets)
        saveQuotes()
    }

    func getQuote(byId id: UUID) -> Quote? {
        quotes.first { $0.id == id }
    }

    // MARK: - Practice Session Management

    func recordSession(_ session: PracticeSession) {
        sessions.append(session)
        saveSessions()

        // Update quote statistics
        if var quote = getQuote(byId: session.quoteId) {
            quote.practiceCount += 1
            quote.lastPracticedAt = session.completedAt
            quote.lastAccuracy = session.accuracy
            if session.accuracy > quote.bestAccuracy {
                quote.bestAccuracy = session.accuracy
            }
            updateQuote(quote)
        }
    }

    func getSessions(for quoteId: UUID) -> [PracticeSession] {
        sessions.filter { $0.quoteId == quoteId }
            .sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Statistics

    var totalPracticeTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    var totalPracticeSessions: Int {
        sessions.count
    }

    var averageAccuracy: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.accuracy } / Double(sessions.count)
    }

    var masteredQuotesCount: Int {
        quotes.filter { $0.masteryLevel == .mastered }.count
    }

    // MARK: - Filtering

    func quotes(withMastery level: MasteryLevel) -> [Quote] {
        quotes.filter { $0.masteryLevel == level }
    }

    var recentlyPracticed: [Quote] {
        quotes.filter { $0.lastPracticedAt != nil }
            .sorted { ($0.lastPracticedAt ?? .distantPast) > ($1.lastPracticedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var needsPractice: [Quote] {
        quotes.filter { $0.masteryLevel != .mastered }
            .sorted { $0.bestAccuracy < $1.bestAccuracy }
    }

    // MARK: - Persistence

    private func loadQuotes() {
        guard let data = userDefaults.data(forKey: quotesKey) else { return }
        do {
            quotes = try JSONDecoder().decode([Quote].self, from: data)
        } catch {
            print("Failed to load quotes: \(error)")
        }
    }

    private func saveQuotes() {
        do {
            let data = try JSONEncoder().encode(quotes)
            userDefaults.set(data, forKey: quotesKey)
        } catch {
            print("Failed to save quotes: \(error)")
        }
    }

    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey) else { return }
        do {
            sessions = try JSONDecoder().decode([PracticeSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }

    private func loadCategories() {
        guard let data = userDefaults.data(forKey: categoriesKey) else {
            // Initialize with default category only
            categories = [QuoteCategory.defaultCategory]
            return
        }
        do {
            categories = try JSONDecoder().decode([QuoteCategory].self, from: data)
        } catch {
            print("Failed to load categories: \(error)")
            categories = [QuoteCategory.defaultCategory]
        }
    }

    private func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: categoriesKey)
        } catch {
            print("Failed to save categories: \(error)")
        }
    }

    // MARK: - Sample Data

    private func addSampleQuotes() {
        // All sample quotes go to the default category
        let defaultCategoryId = QuoteCategory.defaultCategory.id

        let sampleQuotes = [
            Quote(
                title: "Gettysburg Address (Opening)",
                text: "Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.",
                categoryId: defaultCategoryId
            ),
            Quote(
                title: "To be, or not to be",
                text: "To be, or not to be, that is the question: Whether 'tis nobler in the mind to suffer the slings and arrows of outrageous fortune, or to take arms against a sea of troubles.",
                categoryId: defaultCategoryId
            ),
            Quote(
                title: "I Have a Dream (Excerpt)",
                text: "I have a dream that one day this nation will rise up and live out the true meaning of its creed: We hold these truths to be self-evident, that all men are created equal.",
                categoryId: defaultCategoryId
            ),
            Quote(
                title: "The Road Not Taken (Excerpt)",
                text: "Two roads diverged in a wood, and I took the one less traveled by, and that has made all the difference.",
                categoryId: defaultCategoryId
            ),
            Quote(
                title: "Einstein Quote",
                text: "Imagination is more important than knowledge. Knowledge is limited. Imagination encircles the world.",
                categoryId: defaultCategoryId
            )
        ]

        quotes = sampleQuotes
        saveQuotes()
    }

    /// Clear all user data (for settings reset)
    func clearAllData() {
        quotes.removeAll()
        sessions.removeAll()
        categories = [QuoteCategory.defaultCategory]
        saveQuotes()
        saveSessions()
        saveCategories()
    }
}
