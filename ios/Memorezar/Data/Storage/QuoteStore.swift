import Foundation
import SwiftUI
import Combine

/// Observable store for managing quotes
/// Persists to UserDefaults (could be upgraded to Core Data for larger datasets)
final class QuoteStore: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var sessions: [PracticeSession] = []

    // MARK: - Private Properties

    private let quotesKey = "memorezar_quotes"
    private let sessionsKey = "memorezar_sessions"
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadQuotes()
        loadSessions()

        // Add sample quotes if empty (first launch)
        if quotes.isEmpty {
            addSampleQuotes()
        }
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

    func quotes(in category: QuoteCategory) -> [Quote] {
        quotes.filter { $0.category == category }
    }

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

    // MARK: - Sample Data

    private func addSampleQuotes() {
        let sampleQuotes = [
            Quote(
                title: "Gettysburg Address (Opening)",
                text: "Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.",
                category: .speech
            ),
            Quote(
                title: "To be, or not to be",
                text: "To be, or not to be, that is the question: Whether 'tis nobler in the mind to suffer the slings and arrows of outrageous fortune, or to take arms against a sea of troubles.",
                category: .poetry
            ),
            Quote(
                title: "I Have a Dream (Excerpt)",
                text: "I have a dream that one day this nation will rise up and live out the true meaning of its creed: We hold these truths to be self-evident, that all men are created equal.",
                category: .speech
            ),
            Quote(
                title: "The Road Not Taken (Excerpt)",
                text: "Two roads diverged in a wood, and I took the one less traveled by, and that has made all the difference.",
                category: .poetry
            ),
            Quote(
                title: "Einstein Quote",
                text: "Imagination is more important than knowledge. Knowledge is limited. Imagination encircles the world.",
                category: .quote
            )
        ]

        quotes = sampleQuotes
        saveQuotes()
    }
}
