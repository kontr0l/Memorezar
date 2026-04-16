import Foundation
import SwiftUI
import UIKit
import Combine

/// Observable store for managing quotes
/// Persists to UserDefaults (could be upgraded to Core Data for larger datasets)
final class QuoteStore: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var sessions: [PracticeSession] = []
    @Published private(set) var categories: [QuoteCategory] = []
    @Published var pendingCategoryNavigation: QuoteCategory?

    // MARK: - Private Properties

    private let quotesKey = "memorezar_quotes"
    private let sessionsKey = "memorezar_sessions"
    private let categoriesKey = "memorezar_categories"
    private let packVersionsKey = "memorezar_pack_versions"
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

        // Legacy: old installs had sample quotes seeded here.
        // Now quotes come from Suggestion Packs on the HomeScreen.

        // Migrate: fix quotes where primaryLanguage was incorrectly overwritten
        // with a translation language (bug in v59.1). Move to lastPracticedLanguage.
        if !userDefaults.bool(forKey: "memorezar_migrated_practiced_lang") {
            var changed = false
            for i in quotes.indices {
                if let lang = quotes[i].primaryLanguage,
                   lang != "en",
                   quotes[i].translations?[lang] != nil {
                    // primaryLanguage was set to a translation lang — revert
                    quotes[i].lastPracticedLanguage = lang
                    quotes[i].primaryLanguage = nil
                    changed = true
                }
            }
            if changed { saveQuotes() }
            userDefaults.set(true, forKey: "memorezar_migrated_practiced_lang")
        }

        // Clean up stale pack entries (categories deleted before sourcePackId was added)
        let remainingPackIds = Set(categories.compactMap(\.sourcePackId))
        var versions = installedPackVersions
        let staleIds = versions.keys.filter { !remainingPackIds.contains($0) }
        if !staleIds.isEmpty {
            for id in staleIds {
                versions.removeValue(forKey: id)
            }
            userDefaults.set(versions, forKey: packVersionsKey)
        }

        // Sync installed packs with server — only fetches data when version is bumped
        Task {
            let versions = self.installedPackVersions
            await PackService.shared.syncInstalledPacks(installedVersions: versions, store: self)
        }
    }

    // MARK: - Pack Sync Helpers (used by PackService)

    /// Dictionary of packId → installed version
    var installedPackVersions: [String: Int] {
        userDefaults.dictionary(forKey: packVersionsKey) as? [String: Int] ?? [:]
    }

    /// Update the stored version for a pack
    func setInstalledPackVersion(_ packId: String, version: Int) {
        var versions = installedPackVersions
        versions[packId] = version
        userDefaults.set(versions, forKey: packVersionsKey)
    }

    /// Replace all quotes in a category with fresh data from the server,
    /// preserving practice progress (accuracy, streak, mastery, etc.)
    func replaceQuotes(inCategory categoryId: UUID, with remoteQuotes: [SuggestionQuote], preferredLanguage: String) {
        let existingQuotes = quotes.filter { $0.categoryId == categoryId }

        // Remove old quotes for this category
        quotes.removeAll { $0.categoryId == categoryId }

        // Add updated quotes, carrying over progress from matching old quotes
        let lang = preferredLanguage
        for (index, item) in remoteQuotes.enumerated() {
            let title: String
            let text: String
            var translations = item.translations ?? [:]

            if lang != "en", let translated = translations[lang] {
                title = translated.title
                text = translated.text
                translations["en"] = TranslatedQuote(title: item.title, text: item.text)
                translations.removeValue(forKey: lang)
            } else {
                title = item.title
                text = item.text
            }

            // Match against existing quote by English title or text to preserve progress
            let match = existingQuotes.first {
                $0.title == item.title || $0.text == item.text ||
                $0.title == title || $0.text == text
            }

            let primaryLang = (lang != "en" && item.translations?[lang] != nil) ? lang : nil
            var quote = Quote(
                title: title,
                text: text,
                categoryId: categoryId,
                translations: translations.isEmpty ? nil : translations,
                primaryLanguage: primaryLang,
                sortOrder: index
            )

            // Carry over practice progress
            if let match = match {
                quote.practiceCount = match.practiceCount
                quote.lastPracticedAt = match.lastPracticedAt
                quote.lastAccuracy = match.lastAccuracy
                quote.bestAccuracy = match.bestAccuracy
            }

            quotes.append(quote)
        }
        saveQuotes()
    }

    /// Update cover image for a category from a remote URL
    func updateCoverImage(from urlString: String, for category: QuoteCategory) async {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.85),
              let filename = saveCategoryImage(jpegData, for: category.id) else { return }
        await MainActor.run {
            if let idx = categories.firstIndex(where: { $0.id == category.id }) {
                categories[idx].imageSource = .local(filename)
                saveCategories()
            }
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
        // Must keep at least one category
        guard categories.count > 1 else { return }

        // Clean up local image if any
        if case .local(let filename) = category.imageSource {
            deleteCategoryImage(filename: filename)
        }

        // Delete all quotes in this category
        quotes.removeAll { $0.categoryId == category.id }
        saveQuotes()

        categories.removeAll { $0.id == category.id }
        saveCategories()

        // If this category came from a suggestion pack, un-mark it so the pack reappears.
        if let packId = category.sourcePackId {
            var versions = installedPackVersions
            versions.removeValue(forKey: packId)
            userDefaults.set(versions, forKey: packVersionsKey)
        } else {
            // Fallback for categories added before sourcePackId was introduced:
            // clean up any installed pack IDs that no longer have a matching category.
            let remainingPackIds = Set(categories.compactMap(\.sourcePackId))
            var versions = installedPackVersions
            let staleIds = versions.keys.filter { !remainingPackIds.contains($0) }
            if !staleIds.isEmpty {
                for id in staleIds {
                    versions.removeValue(forKey: id)
                }
                userDefaults.set(versions, forKey: packVersionsKey)
            }
        }
    }

    /// Pick a random gradient index not already used by an existing category
    func nextAvailableGradientIndex() -> Int {
        let usedIndices = Set(categories.compactMap { $0.gradientIndex })
        let paletteCount = QuoteCategory.gradientPalettes.count
        let available = (0..<paletteCount).filter { !usedIndices.contains($0) }
        if let pick = available.randomElement() { return pick }
        // All used — pick any at random
        return Int.random(in: 0..<paletteCount)
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

    /// Reset all statistics for a single quote (sessions, accuracy, practice count, level, mastery)
    func resetQuoteStats(_ quote: Quote) {
        // Remove all sessions for this quote
        sessions.removeAll { $0.quoteId == quote.id }
        saveSessions()

        // Reset the quote's stats
        var q = quote
        q.practiceCount = 0
        q.bestAccuracy = 0
        q.lastAccuracy = nil
        q.lastPracticedAt = nil
        q.revealLevel = 0
        q.masteryStreak = 0
        q.chunkAccuracies = nil
        q.chunkRevealPercentages = nil
        updateQuote(q)
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

    /// Total practice time from sessions completed this week (Mon–Sun)
    var practiceTimeThisWeek: TimeInterval {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return sessions
            .filter { $0.completedAt >= weekStart }
            .reduce(0) { $0 + $1.duration }
    }

    /// Number of consecutive days (ending today or yesterday) with at least one session
    var dailyStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let practiceDays = Set(sessions.map { calendar.startOfDay(for: $0.completedAt) })

        var streak = 0
        // Start from today; if no session today, try yesterday as the latest day
        var checkDate = today
        if !practiceDays.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if !practiceDays.contains(checkDate) { return 0 }
        }
        while practiceDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    /// Accuracy improvement: average of last 5 sessions minus average of 5 sessions before that
    var accuracyImprovement: Double? {
        guard sessions.count >= 2 else { return nil }
        let sorted = sessions.sorted { $0.completedAt < $1.completedAt }
        let recentCount = min(5, sorted.count)
        let recent = sorted.suffix(recentCount)
        let recentAvg = recent.reduce(0.0) { $0 + $1.accuracy } / Double(recentCount)

        let remaining = sorted.dropLast(recentCount)
        guard !remaining.isEmpty else { return nil }
        let olderCount = min(5, remaining.count)
        let older = remaining.suffix(olderCount)
        let olderAvg = older.reduce(0.0) { $0 + $1.accuracy } / Double(olderCount)

        return recentAvg - olderAvg
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
        // CloudBackupService.shared.scheduleBackup()  // BACKUP-001: auto-backup disabled, manual only
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
        // CloudBackupService.shared.scheduleBackup()  // BACKUP-001: auto-backup disabled, manual only
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
        // CloudBackupService.shared.scheduleBackup()  // BACKUP-001: auto-backup disabled, manual only
    }

    // MARK: - Category Image Storage

    private var categoryImagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("category_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Save image data for a category, returns the filename on success.
    /// Uses a unique suffix so SwiftUI detects the filename change and re-renders.
    func saveCategoryImage(_ imageData: Data, for categoryId: UUID) -> String? {
        // Compress to JPEG if needed
        guard let image = UIImage(data: imageData),
              let jpegData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        // Clean up any existing images for this category
        let prefix = "category_\(categoryId.uuidString)"
        if let files = try? FileManager.default.contentsOfDirectory(at: categoryImagesDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix(prefix) {
                try? FileManager.default.removeItem(at: file)
            }
        }

        // Unique suffix ensures SwiftUI sees a new value and re-renders
        let suffix = String(UUID().uuidString.prefix(8))
        let filename = "\(prefix)_\(suffix).jpg"
        let fileURL = categoryImagesDirectory.appendingPathComponent(filename)

        do {
            try jpegData.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save category image: \(error)")
            return nil
        }
    }

    /// Load a category image from local storage
    func loadCategoryImage(filename: String) -> UIImage? {
        let fileURL = categoryImagesDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Delete a category image from local storage
    func deleteCategoryImage(filename: String) {
        let fileURL = categoryImagesDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Suggestion Packs

    /// Check whether a suggestion pack has already been added.
    func isPackAdded(_ packId: String) -> Bool {
        installedPackVersions[packId] != nil
    }

    /// Import all quotes from a suggestion pack into a new category.
    /// When a preferred language is provided and a translation exists,
    /// the quote's title/text are stored in that language and the
    /// English original is added as a translation keyed under "en".
    func addSuggestionPack(_ pack: SuggestionPack, preferredLanguage: String = "en") {
        // Create category for the pack, linking back to the Supabase pack ID for sync
        let localizedName = pack.localizedName(for: preferredLanguage)
        let category = QuoteCategory(name: localizedName, gradientIndex: nextAvailableGradientIndex(), sourcePackId: pack.id)

        addCategory(category)

        // Download cover image asynchronously after adding the category
        if let coverURL = pack.coverURL {
            Task {
                await downloadAndSaveCoverImage(from: coverURL, for: category.id)
            }
        }

        // Build all quotes first, then append in one batch so @Published
        // fires only once instead of once per quote. Large packs (e.g. Movie
        // Quotes) were crashing because dozens of rapid objectWillChange
        // notifications overwhelmed SwiftUI's view reconciliation.
        let lang = preferredLanguage
        var newQuotes: [Quote] = []
        for (index, item) in pack.quotes.enumerated() {
            let title: String
            let text: String
            var translations = item.translations ?? [:]

            if lang != "en", let translated = translations[lang] {
                title = translated.title
                text = translated.text
                translations["en"] = TranslatedQuote(title: item.title, text: item.text)
                translations.removeValue(forKey: lang)
            } else {
                title = item.title
                text = item.text
            }

            let primaryLang = (lang != "en" && item.translations?[lang] != nil) ? lang : nil
            newQuotes.append(Quote(
                title: title,
                text: text,
                categoryId: category.id,
                translations: translations.isEmpty ? nil : translations,
                primaryLanguage: primaryLang,
                sortOrder: index
            ))
        }
        quotes.append(contentsOf: newQuotes)
        saveQuotes()

        // Record pack as added with its version
        setInstalledPackVersion(pack.id, version: pack.version)

        // Navigate directly to the new category
        pendingCategoryNavigation = category
    }

    /// Download a remote cover image and save it locally for a category
    private func downloadAndSaveCoverImage(from urlString: String, for categoryId: UUID) async {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.85),
              let filename = saveCategoryImage(jpegData, for: categoryId) else { return }
        // Dispatch back to the main actor so the @Published mutation fires
        // on the main thread — otherwise SwiftUI won't re-render the Library
        // grid until the next navigation event.
        await MainActor.run {
            if let idx = categories.firstIndex(where: { $0.id == categoryId }) {
                categories[idx].imageSource = .local(filename)
                saveCategories()
            }
        }
    }

    // MARK: - Cloud Backup Restore

    /// Replace all local data with a cloud backup snapshot.
    func restoreFromBackup(quotes: [Quote], sessions: [PracticeSession],
                           categories: [QuoteCategory], packVersions: [String: Int]) {
        self.quotes = quotes
        self.sessions = sessions
        self.categories = categories
        saveQuotes()
        saveSessions()
        saveCategories()
        for (packId, version) in packVersions {
            setInstalledPackVersion(packId, version: version)
        }
    }

    /// Clear all user data (for settings reset)
    func clearAllData() {
        quotes.removeAll()
        sessions.removeAll()
        categories = [QuoteCategory.defaultCategory]
        saveQuotes()
        saveSessions()
        saveCategories()
        userDefaults.removeObject(forKey: packVersionsKey)
    }
}
