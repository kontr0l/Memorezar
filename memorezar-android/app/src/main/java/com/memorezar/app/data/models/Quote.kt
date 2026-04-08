package com.memorezar.app.data.models

import kotlinx.serialization.Serializable
import java.util.UUID

const val DEFAULT_CATEGORY_ID = "00000000-0000-0000-0000-000000000001"

@Serializable
data class TranslatedQuote(
    val title: String,
    val text: String
)

@Serializable
data class Quote(
    val id: String = UUID.randomUUID().toString(),
    var title: String,
    var text: String,
    var categoryId: String = DEFAULT_CATEGORY_ID,
    val createdAt: Long = System.currentTimeMillis(),
    var lastPracticedAt: Long? = null,

    // Progress tracking
    var practiceCount: Int = 0,
    var bestAccuracy: Double = 0.0,
    var lastAccuracy: Double? = null,

    // Translations — keyed by language code (e.g. "es" -> Spanish)
    var translations: Map<String, TranslatedQuote>? = null,
    var primaryLanguage: String? = null,
    var lastPracticedLanguage: String? = null,

    // Mastery challenge — 3 consecutive passes at 95%+ with 0% reveal to earn Mastered
    var masteryStreak: Int = 0,

    // Reveal progression: 1=90% revealed, 2=50%, 3=10%. 0=not started (defaults to level 1)
    var revealLevel: Int = 0,

    // Explicit sort order for pack quotes
    var sortOrder: Int? = null,

    // Chunking — optional split into parts for practicing sections
    var chunks: List<String>? = null,
    var activeChunkIndex: Int? = null,
    var chunkAccuracies: List<Double>? = null,
    var chunkRevealPercentages: List<Double>? = null
) {
    /** The title to display, respecting lastPracticedLanguage if a translation exists */
    val displayTitle: String
        get() {
            val lang = lastPracticedLanguage ?: return title
            return translations?.get(lang)?.title ?: title
        }

    /** The text to display, respecting lastPracticedLanguage if a translation exists */
    val displayText: String
        get() {
            val lang = lastPracticedLanguage ?: return text
            return translations?.get(lang)?.text ?: text
        }

    /** Word count in the quote */
    val wordCount: Int
        get() = text.trim().split("\\s+".toRegex()).count { it.isNotEmpty() }

    /** Short preview of the display text */
    val preview: String
        get() {
            val words = displayText.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
            val taken = words.take(10)
            val joined = taken.joinToString(" ")
            return if (taken.size >= 10) "$joined..." else joined
        }

    /** Whether the title matches the start of the text (hides redundant preview) */
    val titleMatchesPreview: Boolean
        get() {
            fun extractWords(s: String) = s.lowercase()
                .replace(Regex("[^\\p{L}\\p{N} ]"), " ")
                .trim().split("\\s+".toRegex())
                .filter { it.isNotEmpty() }
            val titleWords = extractWords(displayTitle)
            val textWords = extractWords(displayText)
            if (titleWords.isEmpty()) return false
            if (textWords.size < titleWords.size) return false
            return textWords.take(titleWords.size) == titleWords
        }

    /** Whether this quote has been split into multiple parts */
    val isSplit: Boolean
        get() = chunks != null && (chunks?.size ?: 0) > 1

    /** The reveal percentage for the current level */
    val revealPercentageForLevel: Double
        get() = when (revealLevel) {
            2 -> 50.0
            3 -> 20.0
            else -> 90.0 // level 0 or 1
        }

    /** The letter reveal step for the current level (first-letter mode) */
    val letterStepForLevel: Int
        get() = when (revealLevel) {
            2 -> 2
            3 -> 1
            else -> 3 // level 0 or 1
        }

    /** Mastery level tied to reveal level progression */
    val masteryLevel: MasteryLevel
        get() {
            if (practiceCount == 0) return MasteryLevel.NONE
            if (masteryStreak >= 3) return MasteryLevel.MASTERED
            val level = maxOf(1, revealLevel)
            return when (level) {
                3 -> MasteryLevel.PROFICIENT
                2 -> MasteryLevel.ADVANCING
                else -> MasteryLevel.LEARNING
            }
        }

    /** Whether the mastered status is stale (no practice in 14+ days) */
    val isMasteryStale: Boolean
        get() {
            if (masteryStreak < 3) return false
            val lastPracticed = lastPracticedAt ?: return false
            val fourteenDaysMs = 14L * 24 * 3600 * 1000
            return (System.currentTimeMillis() - lastPracticed) > fourteenDaysMs
        }
}

@Serializable
data class QuoteCategory(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var gradientIndex: Int? = null,
    val isDefault: Boolean = false,
    var sourcePackId: String? = null,
    var coverImageUrl: String? = null
) {
    companion object {
        val defaultCategory = QuoteCategory(
            id = DEFAULT_CATEGORY_ID,
            name = "My Quotes",
            isDefault = true
        )
    }
}

@Serializable
enum class MasteryLevel(val displayName: String, val color: String, val icon: String) {
    NONE("None", "gray", "circle"),
    LEARNING("Learning", "green", "leaf_fill"),
    ADVANCING("Advancing", "orange", "lightbulb_max_fill"),
    PROFICIENT("Proficient", "indigo", "sparkles"),
    MASTERED("Mastered", "yellow", "crown_fill")
}

@Serializable
data class PracticeSession(
    val id: String = UUID.randomUUID().toString(),
    val quoteId: String,
    val startedAt: Long = System.currentTimeMillis(),
    val completedAt: Long = System.currentTimeMillis(),
    val totalWords: Int,
    val testedWords: Int = 0,
    val correctWords: Int,
    val mistakes: List<PracticeMistake> = emptyList(),
    val revealPercentage: Double = 50.0,
    val hintCount: Int = 0
) {
    /** Accuracy as a fraction 0.0-1.0 */
    val accuracy: Double
        get() {
            val tested = if (testedWords > 0) testedWords else totalWords
            if (tested <= 0) return 0.0
            return maxOf(0, tested - mistakes.size).toDouble() / tested.toDouble()
        }

    /** Duration in milliseconds */
    val duration: Long
        get() = completedAt - startedAt
}

@Serializable
enum class MistakeCertainty {
    DEFINITE,
    UNCERTAIN
}

@Serializable
data class PracticeMistake(
    val position: Int,
    val expectedWord: String,
    val spokenWord: String,
    val timestamp: Long = System.currentTimeMillis(),
    val confidence: Float = 0f,
    val certainty: MistakeCertainty = MistakeCertainty.DEFINITE
)
