package com.memorezar.app.data.storage

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.memorezar.app.data.models.DEFAULT_CATEGORY_ID
import com.memorezar.app.data.models.MasteryLevel
import com.memorezar.app.data.models.PracticeSession
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.QuoteCategory
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.data.models.TranslatedQuote
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "memorezar_store")

private val QUOTES_KEY = stringPreferencesKey("memorezar_quotes")
private val SESSIONS_KEY = stringPreferencesKey("memorezar_sessions")
private val CATEGORIES_KEY = stringPreferencesKey("memorezar_categories")
private val PACK_VERSIONS_KEY = stringPreferencesKey("memorezar_pack_versions")
private val TRANSLATION_SYNC_KEY = booleanPreferencesKey("memorezar_translation_sync_done")

/** Number of gradient palettes available for category backgrounds */
private const val GRADIENT_PALETTE_COUNT = 12

@Singleton
class QuoteStore @Inject constructor(
    @ApplicationContext context: Context
) {
    private val localizedDefaultCategory = QuoteCategory(
        id = DEFAULT_CATEGORY_ID,
        name = context.getString(com.memorezar.app.R.string.my_quotes),
        isDefault = true
    )
    private val dataStore = context.dataStore
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    // MARK: - State

    private val _quotes = MutableStateFlow<List<Quote>>(emptyList())
    val quotes: StateFlow<List<Quote>> = _quotes.asStateFlow()

    private val _sessions = MutableStateFlow<List<PracticeSession>>(emptyList())
    val sessions: StateFlow<List<PracticeSession>> = _sessions.asStateFlow()

    private val _categories = MutableStateFlow<List<QuoteCategory>>(emptyList())
    val categories: StateFlow<List<QuoteCategory>> = _categories.asStateFlow()

    /** Set after adding a pack — Library screen observes this to auto-navigate into the new category */
    val pendingCategoryNavigation = MutableStateFlow<QuoteCategory?>(null)

    init {
        scope.launch { loadAll() }
    }

    private suspend fun loadAll() {
        loadCategories()
        loadQuotes()
        loadSessions()

        // Ensure default category exists
        if (_categories.value.none { it.id == localizedDefaultCategory.id }) {
            val updated = listOf(localizedDefaultCategory) + _categories.value
            _categories.value = updated
            saveCategories()
        }

        // Keep default category name in sync with current locale
        val defaultCat = _categories.value.find { it.id == DEFAULT_CATEGORY_ID }
        if (defaultCat != null && defaultCat.name != localizedDefaultCategory.name) {
            _categories.value = _categories.value.map {
                if (it.id == DEFAULT_CATEGORY_ID) it.copy(name = localizedDefaultCategory.name) else it
            }
            saveCategories()
        }

        // Clean up stale pack entries (categories deleted before sourcePackId was tracked)
        val remainingPackIds = _categories.value.mapNotNull { it.sourcePackId }.toSet()
        val versions = installedPackVersions().toMutableMap()
        val staleIds = versions.keys.filter { it !in remainingPackIds }
        if (staleIds.isNotEmpty()) {
            staleIds.forEach { versions.remove(it) }
            savePackVersions(versions)
        }
    }

    // ──────────────────────────────────────────────────
    // MARK: - Pack Sync Helpers
    // ──────────────────────────────────────────────────

    /** Dictionary of packId → installed version */
    suspend fun installedPackVersions(): Map<String, Int> {
        val prefs = dataStore.data.first()
        val raw = prefs[PACK_VERSIONS_KEY] ?: return emptyMap()
        return try {
            json.decodeFromString(
                MapSerializer(String.serializer(), Int.serializer()),
                raw
            )
        } catch (_: Exception) {
            emptyMap()
        }
    }

    /** Update the stored version for a pack */
    fun setInstalledPackVersion(packId: String, version: Int) {
        scope.launch {
            val versions = installedPackVersions().toMutableMap()
            versions[packId] = version
            savePackVersions(versions)
        }
    }

    /** Check whether a suggestion pack has already been added */
    suspend fun isPackAdded(packId: String): Boolean {
        return installedPackVersions().containsKey(packId)
    }

    /** Replace all quotes in a category with fresh data from the server,
     *  preserving practice progress (accuracy, streak, mastery, etc.) */
    fun replaceQuotes(categoryId: String, remoteQuotes: List<com.memorezar.app.data.models.SuggestionQuote>, preferredLanguage: String) {
        val existingQuotes = _quotes.value.filter { it.categoryId == categoryId }

        // Remove old quotes for this category
        _quotes.value = _quotes.value.filter { it.categoryId != categoryId }

        // Add updated quotes, carrying over progress from matching old quotes
        val lang = preferredLanguage
        val newQuotes = mutableListOf<Quote>()
        remoteQuotes.forEachIndexed { index, item ->
            val title: String
            val text: String
            val translations = (item.translations ?: emptyMap()).toMutableMap()

            if (lang != "en" && translations.containsKey(lang)) {
                val translated = translations[lang]!!
                title = translated.title
                text = translated.text
                translations["en"] = TranslatedQuote(title = item.title, text = item.text)
                translations.remove(lang)
            } else {
                title = item.title
                text = item.text
            }

            // Match against existing quote by title or text to preserve progress
            val match = existingQuotes.firstOrNull {
                it.title == item.title || it.text == item.text ||
                        it.title == title || it.text == text
            }

            val primaryLang = if (lang != "en" && item.translations?.containsKey(lang) == true) lang else "en"
            var quote = Quote(
                title = title,
                text = text,
                categoryId = categoryId,
                translations = if (translations.isEmpty()) null else translations,
                primaryLanguage = primaryLang,
                sortOrder = index
            )

            // Carry over practice progress
            if (match != null) {
                quote = quote.copy(
                    practiceCount = match.practiceCount,
                    lastPracticedAt = match.lastPracticedAt,
                    lastAccuracy = match.lastAccuracy,
                    bestAccuracy = match.bestAccuracy
                )
            }

            newQuotes.add(quote)
        }

        _quotes.value = _quotes.value + newQuotes
        saveQuotes()
    }

    // ──────────────────────────────────────────────────
    // MARK: - Category Management
    // ──────────────────────────────────────────────────

    fun addCategory(category: QuoteCategory) {
        _categories.value = _categories.value + category
        saveCategories()
    }

    fun updateCategory(category: QuoteCategory) {
        _categories.value = _categories.value.map {
            if (it.id == category.id) category else it
        }
        saveCategories()
    }

    fun deleteCategory(category: QuoteCategory) {
        // Must keep at least one category
        if (_categories.value.size <= 1) return

        // Delete all quotes in this category
        _quotes.value = _quotes.value.filter { it.categoryId != category.id }
        saveQuotes()

        _categories.value = _categories.value.filter { it.id != category.id }
        saveCategories()

        // If this category came from a suggestion pack, un-mark it so the pack reappears
        scope.launch {
            if (category.sourcePackId != null) {
                val versions = installedPackVersions().toMutableMap()
                versions.remove(category.sourcePackId)
                savePackVersions(versions)
            } else {
                // Fallback: clean up any installed pack IDs that no longer have a matching category
                val remainingPackIds = _categories.value.mapNotNull { it.sourcePackId }.toSet()
                val versions = installedPackVersions().toMutableMap()
                val staleIds = versions.keys.filter { it !in remainingPackIds }
                if (staleIds.isNotEmpty()) {
                    staleIds.forEach { versions.remove(it) }
                    savePackVersions(versions)
                }
            }
        }
    }

    fun getCategory(id: String): QuoteCategory? {
        return _categories.value.firstOrNull { it.id == id }
    }

    fun quotesInCategory(categoryId: String): List<Quote> {
        return _quotes.value.filter { it.categoryId == categoryId }
    }

    /** Pick a gradient index not already used by an existing category */
    fun nextAvailableGradientIndex(): Int {
        val usedIndices = _categories.value.mapNotNull { it.gradientIndex }.toSet()
        val available = (0 until GRADIENT_PALETTE_COUNT).filter { it !in usedIndices }
        return available.randomOrNull() ?: (0 until GRADIENT_PALETTE_COUNT).random()
    }

    // ──────────────────────────────────────────────────
    // MARK: - Quote Management
    // ──────────────────────────────────────────────────

    fun addQuote(quote: Quote) {
        _quotes.value = _quotes.value + quote
        saveQuotes()
    }

    fun updateQuote(quote: Quote) {
        _quotes.value = _quotes.value.map {
            if (it.id == quote.id) quote else it
        }
        saveQuotes()
    }

    fun deleteQuote(quote: Quote) {
        _quotes.value = _quotes.value.filter { it.id != quote.id }
        saveQuotes()
    }

    fun getQuote(id: String): Quote? {
        return _quotes.value.firstOrNull { it.id == id }
    }

    // ──────────────────────────────────────────────────
    // MARK: - Practice Session Management
    // ──────────────────────────────────────────────────

    fun recordSession(session: PracticeSession) {
        _sessions.value = _sessions.value + session
        saveSessions()

        // Update quote statistics
        val quote = getQuote(session.quoteId) ?: return
        val updated = quote.copy(
            practiceCount = quote.practiceCount + 1,
            lastPracticedAt = session.completedAt,
            lastAccuracy = session.accuracy,
            bestAccuracy = if (session.accuracy > quote.bestAccuracy) session.accuracy else quote.bestAccuracy
        )
        updateQuote(updated)
    }

    /**
     * Mark a quote as touched via Read Aloud (TTS). Updates lastPracticedAt so it
     * surfaces in Continue Practicing, and bumps practiceCount from 0→1 so the
     * mastery badge stops being NONE. Doesn't keep inflating practiceCount on
     * subsequent plays.
     */
    fun markListenedToReadAloud(quoteId: String) {
        val quote = getQuote(quoteId) ?: return
        val updated = quote.copy(
            practiceCount = if (quote.practiceCount == 0) 1 else quote.practiceCount,
            lastPracticedAt = System.currentTimeMillis()
        )
        updateQuote(updated)
    }

    fun getSessions(quoteId: String): List<PracticeSession> {
        return _sessions.value
            .filter { it.quoteId == quoteId }
            .sortedByDescending { it.startedAt }
    }

    /** Reset all statistics for a single quote */
    fun resetQuoteStats(quote: Quote) {
        // Remove all sessions for this quote
        _sessions.value = _sessions.value.filter { it.quoteId != quote.id }
        saveSessions()

        // Reset the quote's stats
        val reset = quote.copy(
            practiceCount = 0,
            bestAccuracy = 0.0,
            lastAccuracy = null,
            lastPracticedAt = null,
            revealLevel = 0,
            masteryStreak = 0,
            chunkAccuracies = null,
            chunkRevealPercentages = null
        )
        updateQuote(reset)
    }

    // ──────────────────────────────────────────────────
    // MARK: - Statistics
    // ──────────────────────────────────────────────────

    /** Total practice time in milliseconds */
    val totalPracticeTime: Double
        get() = _sessions.value.sumOf { it.duration }.toDouble()

    val totalPracticeSessions: Int
        get() = _sessions.value.size

    val averageAccuracy: Double
        get() {
            val all = _sessions.value
            if (all.isEmpty()) return 0.0
            return all.sumOf { it.accuracy } / all.size
        }

    val masteredQuotesCount: Int
        get() = _quotes.value.count { it.masteryLevel == MasteryLevel.MASTERED }

    /** Total practice time from sessions completed this week (Mon–Sun) in milliseconds */
    val practiceTimeThisWeek: Double
        get() {
            val cal = Calendar.getInstance()
            cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            val weekStart = cal.timeInMillis
            return _sessions.value
                .filter { it.completedAt >= weekStart }
                .sumOf { it.duration }
                .toDouble()
        }

    /** Number of consecutive days (ending today or yesterday) with at least one session */
    val dailyStreak: Int
        get() {
            val all = _sessions.value
            if (all.isEmpty()) return 0

            val cal = Calendar.getInstance()
            fun startOfDay(millis: Long): Long {
                val c = Calendar.getInstance()
                c.timeInMillis = millis
                c.set(Calendar.HOUR_OF_DAY, 0)
                c.set(Calendar.MINUTE, 0)
                c.set(Calendar.SECOND, 0)
                c.set(Calendar.MILLISECOND, 0)
                return c.timeInMillis
            }

            val today = startOfDay(System.currentTimeMillis())
            val practiceDays = all.map { startOfDay(it.completedAt) }.toSet()
            val oneDayMs = 24L * 3600 * 1000

            var streak = 0
            var checkDate = today

            if (!practiceDays.contains(checkDate)) {
                checkDate -= oneDayMs
                if (!practiceDays.contains(checkDate)) return 0
            }
            while (practiceDays.contains(checkDate)) {
                streak++
                checkDate -= oneDayMs
            }
            return streak
        }

    /** Accuracy improvement: average of last 5 sessions minus average of 5 sessions before that */
    val accuracyImprovement: Double?
        get() {
            val all = _sessions.value
            if (all.size < 2) return null

            val sorted = all.sortedBy { it.completedAt }
            val recentCount = minOf(5, sorted.size)
            val recent = sorted.takeLast(recentCount)
            val recentAvg = recent.sumOf { it.accuracy } / recentCount

            val remaining = sorted.dropLast(recentCount)
            if (remaining.isEmpty()) return null
            val olderCount = minOf(5, remaining.size)
            val older = remaining.takeLast(olderCount)
            val olderAvg = older.sumOf { it.accuracy } / olderCount

            return recentAvg - olderAvg
        }

    /** Recently practiced quotes, most recent first, up to 5 */
    val recentlyPracticed: List<Quote>
        get() = _quotes.value
            .filter { it.lastPracticedAt != null }
            .sortedByDescending { it.lastPracticedAt ?: 0L }
            .take(5)

    /** Quotes that haven't been mastered yet, sorted by lowest accuracy first */
    val needsPractice: List<Quote>
        get() = _quotes.value
            .filter { it.masteryLevel != MasteryLevel.MASTERED }
            .sortedBy { it.bestAccuracy }

    // ──────────────────────────────────────────────────
    // MARK: - Suggestion Packs
    // ──────────────────────────────────────────────────

    /** Import all quotes from a suggestion pack into a new category */
    fun addSuggestionPack(pack: SuggestionPack, preferredLanguage: String = "en") {
        // Create category for the pack, linking back to the Supabase pack ID for sync
        val localizedName = pack.localizedName(preferredLanguage)
        val category = QuoteCategory(
            name = localizedName,
            gradientIndex = nextAvailableGradientIndex(),
            sourcePackId = pack.id,
            coverImageUrl = pack.coverURL
        )

        addCategory(category)

        // Create a Quote for each item in the pack, preserving Supabase order
        val lang = preferredLanguage
        val newQuotes = mutableListOf<Quote>()
        pack.quotes.forEachIndexed { index, item ->
            val title: String
            val text: String
            val translations = (item.translations ?: emptyMap()).toMutableMap()

            // If a translation exists for the preferred language, use it as primary
            if (lang != "en" && translations.containsKey(lang)) {
                val translated = translations[lang]!!
                title = translated.title
                text = translated.text
                // Store the English original as a translation
                translations["en"] = TranslatedQuote(title = item.title, text = item.text)
                translations.remove(lang)
            } else {
                title = item.title
                text = item.text
            }

            val primaryLang = if (lang != "en" && item.translations?.containsKey(lang) == true) lang else "en"
            val quote = Quote(
                title = title,
                text = text,
                categoryId = category.id,
                translations = if (translations.isEmpty()) null else translations,
                primaryLanguage = primaryLang,
                sortOrder = index
            )
            newQuotes.add(quote)
        }

        _quotes.value = _quotes.value + newQuotes
        saveQuotes()

        // Record pack as added with its version
        setInstalledPackVersion(pack.id, pack.version)

        // Trigger auto-navigation to the new category in the Library tab
        pendingCategoryNavigation.value = category
    }

    /** Update an installed pack with fresh data from the server */
    fun updateInstalledPack(pack: SuggestionPack, preferredLanguage: String = "en") {
        val category = _categories.value.firstOrNull { it.sourcePackId == pack.id } ?: return

        // Update category name (may have changed in translation)
        val localizedName = pack.localizedName(preferredLanguage)
        if (category.name != localizedName) {
            updateCategory(category.copy(name = localizedName))
        }

        // Replace all quotes, preserving progress
        replaceQuotes(category.id, pack.quotes, preferredLanguage)

        // Update stored version
        setInstalledPackVersion(pack.id, pack.version)
    }

    /** Replace all local data with a cloud backup snapshot. */
    fun restoreFromBackup(
        quotes: List<Quote>,
        sessions: List<PracticeSession>,
        categories: List<QuoteCategory>,
        packVersions: Map<String, Int>
    ) {
        _quotes.value = quotes
        _sessions.value = sessions
        _categories.value = categories
        saveQuotes()
        saveSessions()
        saveCategories()
        scope.launch { savePackVersions(packVersions) }
    }

    /** Clear all user data (for settings reset) */
    fun clearAllData() {
        _quotes.value = emptyList()
        _sessions.value = emptyList()
        _categories.value = listOf(localizedDefaultCategory)
        saveQuotes()
        saveSessions()
        saveCategories()
        scope.launch {
            dataStore.edit { prefs -> prefs.remove(PACK_VERSIONS_KEY) }
        }
    }

    // ──────────────────────────────────────────────────
    // MARK: - Persistence (DataStore)
    // ──────────────────────────────────────────────────

    private suspend fun loadQuotes() {
        val prefs = dataStore.data.first()
        val raw = prefs[QUOTES_KEY] ?: return
        try {
            _quotes.value = json.decodeFromString(ListSerializer(Quote.serializer()), raw)
        } catch (e: Exception) {
            android.util.Log.e("QuoteStore", "Failed to load quotes", e)
        }
    }

    private fun saveQuotes() {
        scope.launch {
            try {
                val encoded = json.encodeToString(ListSerializer(Quote.serializer()), _quotes.value)
                dataStore.edit { prefs -> prefs[QUOTES_KEY] = encoded }
            } catch (e: Exception) {
                android.util.Log.e("QuoteStore", "Failed to save quotes", e)
            }
        }
    }

    private suspend fun loadSessions() {
        val prefs = dataStore.data.first()
        val raw = prefs[SESSIONS_KEY] ?: return
        try {
            _sessions.value = json.decodeFromString(ListSerializer(PracticeSession.serializer()), raw)
        } catch (e: Exception) {
            android.util.Log.e("QuoteStore", "Failed to load sessions", e)
        }
    }

    private fun saveSessions() {
        scope.launch {
            try {
                val encoded = json.encodeToString(ListSerializer(PracticeSession.serializer()), _sessions.value)
                dataStore.edit { prefs -> prefs[SESSIONS_KEY] = encoded }
            } catch (e: Exception) {
                android.util.Log.e("QuoteStore", "Failed to save sessions", e)
            }
        }
    }

    private suspend fun loadCategories() {
        val prefs = dataStore.data.first()
        val raw = prefs[CATEGORIES_KEY]
        if (raw == null) {
            _categories.value = listOf(localizedDefaultCategory)
            return
        }
        try {
            _categories.value = json.decodeFromString(ListSerializer(QuoteCategory.serializer()), raw)
        } catch (e: Exception) {
            android.util.Log.e("QuoteStore", "Failed to load categories", e)
            _categories.value = listOf(localizedDefaultCategory)
        }
    }

    private fun saveCategories() {
        scope.launch {
            try {
                val encoded = json.encodeToString(ListSerializer(QuoteCategory.serializer()), _categories.value)
                dataStore.edit { prefs -> prefs[CATEGORIES_KEY] = encoded }
            } catch (e: Exception) {
                android.util.Log.e("QuoteStore", "Failed to save categories", e)
            }
        }
    }

    private suspend fun savePackVersions(versions: Map<String, Int>) {
        try {
            val encoded = json.encodeToString(
                MapSerializer(String.serializer(), Int.serializer()),
                versions
            )
            dataStore.edit { prefs -> prefs[PACK_VERSIONS_KEY] = encoded }
        } catch (e: Exception) {
            android.util.Log.e("QuoteStore", "Failed to save pack versions", e)
        }
    }

    /** Whether the one-time translation re-sync has been completed */
    suspend fun hasCompletedTranslationSync(): Boolean {
        val prefs = dataStore.data.first()
        return prefs[TRANSLATION_SYNC_KEY] == true
    }

    /** Mark the one-time translation re-sync as complete */
    fun markTranslationSyncComplete() {
        scope.launch {
            dataStore.edit { prefs -> prefs[TRANSLATION_SYNC_KEY] = true }
        }
    }
}
