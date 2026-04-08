package com.memorezar.app.core.comparison

import java.text.Normalizer

/**
 * Word-by-Word Comparator
 *
 * Compares spoken words against target text in real-time.
 * Handles normalization, punctuation, contractions, and common variations.
 *
 * Performance: Uses pre-allocated arrays and avoids allocations in hot path
 */
class WordComparator {

    // -- Properties --

    private var targetWords: List<String> = emptyList()
    private var normalizedTargetWords: List<String> = emptyList()
    private var targetPhoneticCodes: List<DoubleMetaphone.PhoneticCode?> = emptyList()
    var currentPosition: Int = 0
        private set
    private var language: String? = null // null = English (default)

    // User-defined word equivalences (expected → set of accepted spoken alternatives)
    private var userEquivalences: Map<String, Set<String>> = emptyMap()

    // Community-sourced equivalences (lower priority than user equivalences)
    private var communityEquivalences: Map<String, Set<String>> = emptyMap()

    // Compound word buffer - holds partial word when speech recognition splits a compound word
    private var compoundBuffer: String? = null
    private var compoundBufferTimestamp: Long? = null // millis

    // Multi-word join buffer - tracks recent mismatched words at the same position
    // to detect STT splitting a compound word into multiple words
    // (e.g., "maidservant" → "mate" + "servant" → joined "mateservant" ≈ "maidservant")
    private var multiWordBuffer: MutableList<String> = mutableListOf()
    private var multiWordPosition: Int = -1

    // Look-ahead resync - when stuck at a position due to STT errors
    // (e.g., "O Thou" → "Although"), try matching against upcoming expected words
    private var consecutiveMismatchCount = 0
    private var consecutiveMismatchPosition = -1

    // -- Public Methods --

    /** Set the target text that the user is trying to recite */
    fun setTargetText(text: String, language: String? = null) {
        this.language = language
        targetWords = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
        normalizedTargetWords = targetWords.map { normalize(it) }
        // Pre-compute phonetic codes for English only (Double Metaphone is English-specific)
        targetPhoneticCodes = if (language == null) {
            normalizedTargetWords.map { DoubleMetaphone.encode(it) }
        } else {
            List(normalizedTargetWords.size) { null }
        }
        currentPosition = 0
        multiWordBuffer = mutableListOf()
        multiWordPosition = -1
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
    }

    /**
     * Compare a spoken word against the expected word at current position.
     * Returns null if the word is a filler word (should be ignored).
     */
    fun compareWord(spokenWord: String, confidence: Float = 0f, alternatives: List<String> = emptyList()): ComparisonResult? {
        val normalizedSpoken = normalize(spokenWord)

        // DEBUG: Log incoming word
        println("[COMPARE] Received: \"$spokenWord\" → normalized: \"$normalizedSpoken\" | pos=$currentPosition buffer=\"${compoundBuffer ?: "nil"}\"")

        // Skip empty words
        if (normalizedSpoken.isEmpty()) {
            println("[COMPARE] → SKIP (empty)")
            return null
        }

        // Skip filler words — but NOT if the filler word is the expected word at the current position.
        // Words like "so", "well", "you", "like" are common fillers but also appear in real text.
        if (isFillerWord(normalizedSpoken)) {
            val isExpectedWord = currentPosition < normalizedTargetWords.size &&
                normalizedSpoken == normalizedTargetWords[currentPosition]
            if (!isExpectedWord) {
                println("[COMPARE] → SKIP (filler)")
                return null
            }
            println("[COMPARE] Filler word \"$normalizedSpoken\" matches expected — not skipping")
        }

        // Check if we've reached the end
        if (currentPosition >= targetWords.size) {
            println("[COMPARE] → PAST END")
            compoundBuffer = null
            compoundBufferTimestamp = null
            return ComparisonResult(
                isMatch = false,
                expectedWord = "[END]",
                spokenWord = spokenWord,
                normalizedExpected = "",
                normalizedSpoken = normalizedSpoken,
                position = currentPosition,
                confidence = confidence
            )
        }

        val expectedWord = targetWords[currentPosition]
        val normalizedExpected = normalizedTargetWords[currentPosition]
        println("[COMPARE] Expected: \"$expectedWord\" → normalized: \"$normalizedExpected\"")

        // --- Echo filter ---
        // When the speech service restarts (after mistake popup or session restart),
        // residual audio from the previous word can be re-transcribed and sent again.
        // If the spoken word exactly matches the previous target word but doesn't match
        // the current expected word, it's an echo — ignore it.
        if (currentPosition > 0 &&
            normalizedSpoken == normalizedTargetWords[currentPosition - 1] &&
            checkMatch(normalizedSpoken, normalizedExpected) == MatchType.MISMATCH
        ) {
            println("[COMPARE] → SKIP (echo of previous word \"${targetWords[currentPosition - 1]}\")")
            return null
        }

        // --- Compound word handling ---

        // First, check if this word is a REVISION of the buffered word (speech recognizer
        // revised a partial word to a complete word). This happens when:
        // - We have "glor" buffered and receive "glorious"
        // - "glorious" starts with "glor" → this is a revision, not a second word
        // In this case, clear the buffer and process the new word as the complete word.
        val bufferedRevision = compoundBuffer
        if (bufferedRevision != null && normalizedSpoken.startsWith(bufferedRevision) && normalizedSpoken.length > bufferedRevision.length) {
            // This is a revision of the partial word, not a new word to combine
            println("[COMPARE] Buffer revision detected: \"$bufferedRevision\" → \"$normalizedSpoken\"")
            compoundBuffer = null
            compoundBufferTimestamp = null
            // Fall through to normal comparison with the revised (complete) word
        }

        // If we have a buffered partial word, try combining it with the new spoken word
        val buffered = compoundBuffer
        if (buffered != null) {
            val combined = buffered + normalizedSpoken
            val combinedFull = buffered + spokenWord
            println("[COMPARE] Trying buffer combine: \"$buffered\" + \"$normalizedSpoken\" = \"$combined\"")

            // Check if the combined word matches the expected word
            val combinedMatchType = checkMatch(combined, normalizedExpected)
            if (combinedMatchType != MatchType.MISMATCH) {
                println("[COMPARE] → MATCH (combined, $combinedMatchType)! pos $currentPosition → ${currentPosition + 1}")
                compoundBuffer = null
                compoundBufferTimestamp = null
                consecutiveMismatchCount = 0

                val result = ComparisonResult(
                    isMatch = true,
                    expectedWord = expectedWord,
                    spokenWord = combinedFull,
                    normalizedExpected = normalizedExpected,
                    normalizedSpoken = combined,
                    position = currentPosition,
                    confidence = confidence,
                    matchType = combinedMatchType
                )

                currentPosition += 1
                return result
            }

            // Combined word doesn't match. Check if the buffer has timed out.
            val timestamp = compoundBufferTimestamp
            val timedOut = if (timestamp != null) {
                System.currentTimeMillis() - timestamp > COMPOUND_BUFFER_TIMEOUT
            } else {
                true
            }

            if (timedOut) {
                // Buffer timed out — the buffered word was genuinely wrong.
                // Emit a mismatch for the buffered word, then clear buffer
                // and re-process the current spoken word on next call.
                compoundBuffer = null
                compoundBufferTimestamp = null

                return ComparisonResult(
                    isMatch = false,
                    expectedWord = expectedWord,
                    spokenWord = buffered,
                    normalizedExpected = normalizedExpected,
                    normalizedSpoken = buffered,
                    position = currentPosition,
                    confidence = confidence
                )
            }

            // Not timed out but combined doesn't match — check if the expected word
            // still starts with the combined text (keep buffering)
            if (normalizedExpected.startsWith(combined)) {
                compoundBuffer = combined
                return null // Still buffering, no result yet
            }

            // If the new word is identical to the buffer, it's a STT duplicate/echo.
            // Keep the buffer as-is and ignore the duplicate — don't reset.
            if (normalizedSpoken == buffered) {
                println("[COMPARE] → SKIP (duplicate of buffer \"$buffered\")")
                return null
            }

            // Before discarding the buffer, check if it already covers most of
            // the expected word. STT often recognises "heart" for "hearts" — the
            // buffer is a valid prefix and close enough (≥ 75% coverage). Accept
            // it as a match instead of firing a false mismatch.
            if (normalizedExpected.startsWith(buffered) &&
                buffered.length.toDouble() >= normalizedExpected.length.toDouble() * 0.75
            ) {
                println("[COMPARE] → MATCH (buffer prefix-coverage ${buffered.length}/${normalizedExpected.length})! pos $currentPosition → ${currentPosition + 1}")
                compoundBuffer = null
                compoundBufferTimestamp = null
                consecutiveMismatchCount = 0

                val result = ComparisonResult(
                    isMatch = true,
                    expectedWord = expectedWord,
                    spokenWord = buffered,
                    normalizedExpected = normalizedExpected,
                    normalizedSpoken = buffered,
                    position = currentPosition,
                    confidence = confidence,
                    matchType = MatchType.FUZZY
                )
                currentPosition += 1

                // The current spoken word was NOT consumed — re-process it
                // by recursing now that position has advanced.
                val nextResult = compareWord(spokenWord, confidence, alternatives)
                if (nextResult != null) {
                    // consumed internally — position advanced
                    @Suppress("UNUSED_VARIABLE")
                    val consumed = nextResult
                }
                return result
            }

            // Combined doesn't match and isn't a prefix — the buffer was wrong.
            // Clear the buffer and fall through to check the new word independently.
            // This prevents consuming words like "maidservant" when the buffer "made"
            // can't combine with it (made + maidservant = mademaidservant ≠ maidservant).
            println("[COMPARE] Buffer \"$buffered\" was wrong — checking \"$normalizedSpoken\" independently")
            compoundBuffer = null
            compoundBufferTimestamp = null

            // Seed the multi-word buffer with the flushed buffer word so it can
            // participate in multi-word joins (e.g., "maids" + "servant" → "maidsservant" ≈ "maidservant")
            if (multiWordPosition != currentPosition) {
                multiWordBuffer = mutableListOf()
                multiWordPosition = currentPosition
            }
            multiWordBuffer.add(buffered)
            // Fall through to normal comparison below
        }

        // --- Normal (non-buffered) comparison ---

        // Check for direct match (including homophone, contraction, phonetic handling)
        val directMatchType = checkMatch(normalizedSpoken, normalizedExpected)

        if (directMatchType != MatchType.MISMATCH) {
            println("[COMPARE] → MATCH (direct, $directMatchType)! pos $currentPosition → ${currentPosition + 1}")
            consecutiveMismatchCount = 0
            val result = ComparisonResult(
                isMatch = true,
                expectedWord = expectedWord,
                spokenWord = spokenWord,
                normalizedExpected = normalizedExpected,
                normalizedSpoken = normalizedSpoken,
                position = currentPosition,
                confidence = confidence,
                matchType = directMatchType
            )
            currentPosition += 1
            return result
        }

        // --- Concatenated digit check ---
        // Apple's speech recognition sometimes concatenates number words into digit strings:
        // "one two three" → "1", "12", "123". The trailing digit(s) represent the new word.
        // Extract the last digit and check if its number-word form matches the expected word.
        if (normalizedSpoken.all { it.isDigit() } && normalizedSpoken.length >= 2) {
            val lastChar = normalizedSpoken.last()
            val digitWord = digitToWord[lastChar]
            if (digitWord != null) {
                val digitMatchType = checkMatch(digitWord, normalizedExpected)
                if (digitMatchType != MatchType.MISMATCH) {
                    println("[COMPARE] → MATCH (digit-concat \"$normalizedSpoken\" → trailing \"$digitWord\", $digitMatchType)! pos $currentPosition → ${currentPosition + 1}")
                    consecutiveMismatchCount = 0
                    val result = ComparisonResult(
                        isMatch = true,
                        expectedWord = expectedWord,
                        spokenWord = spokenWord,
                        normalizedExpected = normalizedExpected,
                        normalizedSpoken = digitWord,
                        position = currentPosition,
                        confidence = confidence,
                        matchType = digitMatchType
                    )
                    currentPosition += 1
                    return result
                }
            }
        }

        // --- Alternative hypotheses check ---
        // Speech recognizer provides alternative transcriptions for each segment.
        // If any alternative matches the expected word, accept it as a match.
        if (alternatives.isNotEmpty()) {
            for (alt in alternatives) {
                val normalizedAlt = normalize(alt)
                if (normalizedAlt.isEmpty()) continue
                val altMatchType = checkMatch(normalizedAlt, normalizedExpected)
                if (altMatchType != MatchType.MISMATCH) {
                    println("[COMPARE] → MATCH (alternative \"$alt\", $altMatchType)! pos $currentPosition → ${currentPosition + 1}")
                    consecutiveMismatchCount = 0
                    val result = ComparisonResult(
                        isMatch = true,
                        expectedWord = expectedWord,
                        spokenWord = spokenWord,
                        normalizedExpected = normalizedExpected,
                        normalizedSpoken = normalizedAlt,
                        position = currentPosition,
                        confidence = confidence,
                        matchType = MatchType.ALTERNATIVE_MATCH
                    )
                    currentPosition += 1
                    return result
                }
            }
        }

        // Not a direct match — check if this could be the start of a compound word.
        // If the expected word starts with the spoken word (or a homophone of it),
        // buffer the spoken word and wait for the next part.
        if (isCompoundWordPrefix(normalizedSpoken, normalizedExpected)) {
            println("[COMPARE] → BUFFER: \"$normalizedSpoken\" (prefix of \"$normalizedExpected\")")
            compoundBuffer = normalizedSpoken
            compoundBufferTimestamp = System.currentTimeMillis()
            return null // Buffering — no result yet
        }

        // --- Multi-word join attempt ---
        // STT sometimes splits compound/uncommon words into multiple words
        // (e.g., "maidservant" → "mate" + "servant"). Try joining recent
        // mismatched words at this position and check if the joined result matches.

        if (multiWordPosition != currentPosition) {
            multiWordBuffer = mutableListOf()
            multiWordPosition = currentPosition
        }

        // If the new word is a revision/extension of the last entry, replace instead of
        // appending. STT partials like "ser" → "servan" → "servant" should update in place,
        // not accumulate as separate entries that break joining.
        val lastWord = multiWordBuffer.lastOrNull()
        if (lastWord != null && normalizedSpoken.startsWith(lastWord) && normalizedSpoken.length > lastWord.length) {
            println("[COMPARE] Multi-word buffer revision: \"$lastWord\" → \"$normalizedSpoken\"")
            multiWordBuffer[multiWordBuffer.size - 1] = normalizedSpoken
        } else {
            multiWordBuffer.add(normalizedSpoken)
        }

        if (multiWordBuffer.size >= 2) {
            val joinCount = minOf(multiWordBuffer.size, MULTI_WORD_BUFFER_MAX_SIZE)
            for (n in 2..joinCount) {
                val startIdx = multiWordBuffer.size - n
                val joined = multiWordBuffer.subList(startIdx, multiWordBuffer.size).joinToString("")
                val joinMatchType = checkMatch(joined, normalizedExpected)
                if (joinMatchType != MatchType.MISMATCH) {
                    println("[COMPARE] → MATCH (multi-word join, $joinMatchType)! \"$joined\" ≈ \"$normalizedExpected\" pos $currentPosition → ${currentPosition + 1}")
                    multiWordBuffer = mutableListOf()
                    consecutiveMismatchCount = 0

                    val result = ComparisonResult(
                        isMatch = true,
                        expectedWord = expectedWord,
                        spokenWord = joined,
                        normalizedExpected = normalizedExpected,
                        normalizedSpoken = joined,
                        position = currentPosition,
                        confidence = confidence,
                        matchType = joinMatchType
                    )
                    currentPosition += 1
                    return result
                }
            }
        }

        // Cap buffer size
        if (multiWordBuffer.size > MULTI_WORD_BUFFER_MAX_SIZE) {
            multiWordBuffer = multiWordBuffer
                .drop(multiWordBuffer.size - MULTI_WORD_BUFFER_MAX_SIZE)
                .toMutableList()
        }

        // --- Look-ahead resync ---
        // When stuck at a position due to STT merging words (e.g., "O Thou" → "Although"),
        // try matching the spoken word against upcoming expected words to resync.
        if (consecutiveMismatchPosition != currentPosition) {
            consecutiveMismatchCount = 0
            consecutiveMismatchPosition = currentPosition
        }
        consecutiveMismatchCount += 1

        if (consecutiveMismatchCount >= LOOK_AHEAD_THRESHOLD &&
            normalizedSpoken.length >= LOOK_AHEAD_MIN_WORD_LENGTH
        ) {
            // Only look-ahead for words >= 4 chars. Short common words ("the", "a", "and", "of")
            // appear many times in a quote and would match at the wrong position by coincidence.
            val maxPos = minOf(currentPosition + LOOK_AHEAD_RANGE + 1, targetWords.size)
            for (i in (currentPosition + 1) until maxOf(currentPosition + 1, maxPos)) {
                val expectedLen = normalizedTargetWords[i].length
                // Skip if spoken word is much shorter than expected word — likely a partial
                // match for a split word. Require spoken word to be at least 50% of expected word's length.
                if (normalizedSpoken.length * 2 < expectedLen) continue

                val laMatchType = checkMatch(normalizedSpoken, normalizedTargetWords[i])
                if (laMatchType != MatchType.MISMATCH) {
                    println("[COMPARE] → MATCH (look-ahead at pos $i, $laMatchType)! Skipping pos $currentPosition..${i - 1}")
                    consecutiveMismatchCount = 0
                    multiWordBuffer = mutableListOf()

                    val result = ComparisonResult(
                        isMatch = true,
                        expectedWord = targetWords[i],
                        spokenWord = spokenWord,
                        normalizedExpected = normalizedTargetWords[i],
                        normalizedSpoken = normalizedSpoken,
                        position = i,
                        confidence = confidence,
                        matchType = laMatchType
                    )
                    currentPosition = i + 1
                    return result
                }
            }
        }

        // Definite mismatch — position stays (user must say the correct word)
        println("[COMPARE] → MISMATCH: \"$normalizedSpoken\" != \"$normalizedExpected\"")
        return ComparisonResult(
            isMatch = false,
            expectedWord = expectedWord,
            spokenWord = spokenWord,
            normalizedExpected = normalizedExpected,
            normalizedSpoken = normalizedSpoken,
            position = currentPosition,
            confidence = confidence
        )
    }

    /**
     * Try to match a spoken word against the next few expected words (for sync recovery).
     * Called by ViewModel when a pending mismatch is about to fire as a popup.
     * If the spoken word matches an upcoming position, the STT likely dropped a word.
     * Advances position past the match and returns a match result.
     * Returns null if no nearby match found.
     */
    fun tryMatchAhead(spoken: String, range: Int = 2): ComparisonResult? {
        val normalizedSpoken = normalize(spoken)
        if (normalizedSpoken.length < LOOK_AHEAD_MIN_WORD_LENGTH) return null

        val maxPos = minOf(currentPosition + range + 1, targetWords.size)
        for (i in (currentPosition + 1) until maxOf(currentPosition + 1, maxPos)) {
            val expectedLen = normalizedTargetWords[i].length
            if (normalizedSpoken.length * 2 < expectedLen) continue

            val syncMatchType = checkMatch(normalizedSpoken, normalizedTargetWords[i])
            if (syncMatchType != MatchType.MISMATCH) {
                println("[COMPARE] → SYNC RECOVERY (match at pos $i, $syncMatchType)! Skipping pos $currentPosition..${i - 1}")
                val result = ComparisonResult(
                    isMatch = true,
                    expectedWord = targetWords[i],
                    spokenWord = spoken,
                    normalizedExpected = normalizedTargetWords[i],
                    normalizedSpoken = normalizedSpoken,
                    position = i,
                    matchType = syncMatchType
                )
                currentPosition = i + 1
                consecutiveMismatchCount = 0
                consecutiveMismatchPosition = -1
                multiWordBuffer = mutableListOf()
                return result
            }
        }
        return null
    }

    /** Advance position by one (used by popup "It's a Match" flow) */
    fun advancePosition() {
        if (currentPosition >= targetWords.size) return
        currentPosition += 1
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
        multiWordBuffer = mutableListOf()
    }

    /** Jump to a specific position (used by tap-to-reveal) */
    fun setPosition(position: Int) {
        if (position < 0 || position >= targetWords.size) return
        currentPosition = position
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
        multiWordBuffer = mutableListOf()
    }

    /** Set user-defined word equivalences */
    fun setUserEquivalences(equivalences: Map<String, Set<String>>) {
        this.userEquivalences = equivalences
    }

    /** Set community-sourced equivalences (lower priority than user equivalences) */
    fun setCommunityEquivalences(equivalences: Map<String, Set<String>>) {
        this.communityEquivalences = equivalences
    }

    /** Reset to start of text */
    fun reset() {
        currentPosition = 0
        compoundBuffer = null
        compoundBufferTimestamp = null
        multiWordBuffer = mutableListOf()
        multiWordPosition = -1
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
    }

    /** Get total word count */
    val totalWords: Int
        get() = targetWords.size

    /** Check if recitation is complete */
    val isComplete: Boolean
        get() = currentPosition >= targetWords.size

    /** Get the next expected word (for hints) */
    val nextExpectedWord: String?
        get() = if (currentPosition < targetWords.size) targetWords[currentPosition] else null

    /** Get all target words (for display) */
    fun getTargetWords(): List<String> = targetWords

    /** Get progress as percentage */
    val progress: Double
        get() = if (totalWords > 0) currentPosition.toDouble() / totalWords.toDouble() else 0.0

    // -- Private Methods --

    /** Normalize a word for comparison (optimized for performance) */
    private fun normalize(word: String): String {
        // Keep only letters and digits (strips punctuation)
        var result = word.filter { it.isLetterOrDigit() }
        result = result.lowercase()

        // For non-English languages, fold diacritics so "está" matches "esta"
        if (language != null) {
            result = Normalizer.normalize(result, Normalizer.Form.NFD)
                .replace(Regex("\\p{InCombiningDiacriticalMarks}+"), "")
        }

        return result.trim()
    }

    /** Check if a word is a filler word */
    private fun isFillerWord(word: String): Boolean {
        return fillerWords.contains(word.lowercase())
    }

    /**
     * Check if the spoken word could be the start of a compound target word.
     * e.g., spoken "maid" could be the start of target "maidservant"
     * Also checks homophones of the spoken word (e.g., "made" → "maid" prefix of "maidservant")
     */
    private fun isCompoundWordPrefix(spoken: String, expected: String): Boolean {
        // Only consider this if the expected word is longer than spoken
        if (expected.length <= spoken.length) return false

        // Direct prefix check
        if (expected.startsWith(spoken)) return true

        // Check if any homophone of the spoken word is a prefix of the expected word
        val homophoneGroup = homophoneLookup[spoken]
        if (homophoneGroup != null) {
            for (homophone in homophoneGroup) {
                if (homophone != spoken && expected.startsWith(homophone)) {
                    return true
                }
            }
        }

        return false
    }

    /**
     * Flush the compound buffer when speech recognition ends.
     * If the buffer contains a prefix of the expected word (which it always does if buffered),
     * we silently discard it rather than counting as a mistake - the user likely said the word
     * but speech recognition was incomplete. They can try again.
     */
    fun flushCompoundBuffer(): ComparisonResult? {
        if (compoundBuffer == null) return null

        // Silently discard the buffer - it was a prefix of the expected word,
        // so this was likely incomplete speech recognition, not a real mistake.
        // The user will try again.
        compoundBuffer = null
        compoundBufferTimestamp = null

        return null
    }

    /**
     * Check if spoken word matches expected word (handles contractions, homophones, phonetics).
     * Returns the MatchType if matched, or MISMATCH if not.
     */
    private fun checkMatch(spoken: String, expected: String): MatchType {
        // Direct match
        if (spoken == expected) return MatchType.EXACT

        // User-defined equivalences (user tapped "Accept as match" for this pair)
        val userAccepted = userEquivalences[expected]
        if (userAccepted != null && userAccepted.contains(spoken)) {
            return MatchType.USER_EQUIVALENCE
        }

        // Community-sourced equivalences (crowd-sourced from all users)
        val communityAccepted = communityEquivalences[expected]
        if (communityAccepted != null && communityAccepted.contains(spoken)) {
            return MatchType.COMMUNITY_EQUIVALENCE
        }

        // Check homophones
        val homophoneGroup = homophoneLookup[expected]
        if (homophoneGroup != null && homophoneGroup.contains(spoken)) {
            return MatchType.HOMOPHONE
        }

        // Check contractions (both directions)
        val expandedOfSpoken = reverseContractionMap[spoken]
        if (expandedOfSpoken != null) {
            val expandedWords = expandedOfSpoken.split(" ")
            if (expandedWords.firstOrNull() == expected) {
                return MatchType.CONTRACTION
            }
        }

        val expandedOfExpected = reverseContractionMap[expected]
        if (expandedOfExpected != null) {
            val expandedWords = expandedOfExpected.split(" ")
            if (expandedWords.firstOrNull() == spoken) {
                return MatchType.CONTRACTION
            }
        }

        val contractionsOfExpected = contractionMap[expected]
        if (contractionsOfExpected != null && contractionsOfExpected.contains(spoken)) {
            return MatchType.CONTRACTION
        }
        val contractionsOfSpoken = contractionMap[spoken]
        if (contractionsOfSpoken != null && contractionsOfSpoken.contains(expected)) {
            return MatchType.CONTRACTION
        }

        // English-specific matching (Old English, Double Metaphone)
        if (language == null) {
            // Old English verb form matching
            if (isOldEnglishMatch(spoken, expected)) {
                println("[COMPARE] Old English match: \"$spoken\" ≈ \"$expected\"")
                return MatchType.OLD_ENGLISH
            }

            // Phonetic matching via Double Metaphone (English-specific algorithm)
            if (DoubleMetaphone.arePhoneticallySimilar(spoken, expected)) {
                println("[COMPARE] Phonetic match: \"$spoken\" ≈ \"$expected\"")
                return MatchType.PHONETIC
            }
        }

        // Fuzzy matching for STT errors on uncommon words.
        if (isFuzzyMatch(spoken, expected)) {
            println("[COMPARE] Fuzzy match: \"$spoken\" ≈ \"$expected\"")
            return MatchType.FUZZY
        }

        return MatchType.MISMATCH
    }

    // -- Old English Detection --

    /**
     * Check if spoken word matches an old English expected word.
     * Works by extracting the modern root from old English verb forms
     * and generating possible modern equivalents that STT might produce.
     */
    private fun isOldEnglishMatch(spoken: String, expected: String): Boolean {
        // Need at least 3 characters for meaningful matching
        if (expected.length < 3 || spoken.length < 2) return false

        // 1. Check irregular old English forms first
        val modernForms = oldEnglishIrregulars[expected]
        if (modernForms != null && modernForms.contains(spoken)) return true

        // 2. Generic suffix-stripping algorithm
        // Generate modern equivalents from old English verb suffixes
        val modernVariants = modernEquivalents(expected)
        if (modernVariants.contains(spoken)) return true

        // 3. Phonetic check: if any modern variant sounds like the spoken word
        for (variant in modernVariants) {
            if (DoubleMetaphone.arePhoneticallySimilar(spoken, variant)) {
                return true
            }
        }

        // 4. Fuzzy check against modern variants (for STT garbling)
        for (variant in modernVariants) {
            if (variant.length >= 4 && spoken.length >= 4) {
                val distance = levenshteinDistance(spoken, variant)
                val maxLen = maxOf(spoken.length, variant.length)
                val similarity = 1.0 - (distance.toDouble() / maxLen.toDouble())
                if (similarity >= 0.75) return true
            }
        }

        return false
    }

    /**
     * Check if spoken word is a fuzzy match for the expected word.
     * Uses Levenshtein edit distance with strict thresholds to avoid false positives.
     */
    private fun isFuzzyMatch(spoken: String, expected: String): Boolean {
        // Only apply fuzzy matching for longer words where STT errors are more likely
        if (spoken.length < 5 || expected.length < 7) return false

        // Spoken word must be at least 75% of expected word's length
        if (spoken.length.toDouble() < expected.length.toDouble() * 0.75) return false

        val distance = levenshteinDistance(spoken, expected)
        val maxLength = maxOf(spoken.length, expected.length)
        val similarity = 1.0 - (distance.toDouble() / maxLength.toDouble())

        // Require at least 75% similarity
        return similarity >= 0.75
    }

    companion object {

        private const val COMPOUND_BUFFER_TIMEOUT = 1500L // millis to wait for second part
        private const val MULTI_WORD_BUFFER_MAX_SIZE = 4
        private const val LOOK_AHEAD_THRESHOLD = 2
        private const val LOOK_AHEAD_RANGE = 8
        private const val LOOK_AHEAD_MIN_WORD_LENGTH = 4

        private val fillerWords: Set<String> = setOf(
            "um", "uh", "er", "ah", "like", "you", "know", "so", "well", "actually"
        )

        // Digit-to-word map for handling concatenated number transcriptions
        // e.g. "one two three" → "123" — last digit "3" → "three"
        private val digitToWord: Map<Char, String> = mapOf(
            '0' to "zero", '1' to "one", '2' to "two", '3' to "three", '4' to "four",
            '5' to "five", '6' to "six", '7' to "seven", '8' to "eight", '9' to "nine"
        )

        // Contraction mappings (expanded form -> contracted forms)
        private val contractionMap: Map<String, List<String>> = mapOf(
            "do not" to listOf("don't", "dont"),
            "does not" to listOf("doesn't", "doesnt"),
            "did not" to listOf("didn't", "didnt"),
            "is not" to listOf("isn't", "isnt"),
            "are not" to listOf("aren't", "arent"),
            "was not" to listOf("wasn't", "wasnt"),
            "were not" to listOf("weren't", "werent"),
            "have not" to listOf("haven't", "havent"),
            "has not" to listOf("hasn't", "hasnt"),
            "had not" to listOf("hadn't", "hadnt"),
            "will not" to listOf("won't", "wont"),
            "would not" to listOf("wouldn't", "wouldnt"),
            "could not" to listOf("couldn't", "couldnt"),
            "should not" to listOf("shouldn't", "shouldnt"),
            "can not" to listOf("can't", "cant", "cannot"),
            "cannot" to listOf("can't", "cant"),
            "i am" to listOf("i'm", "im"),
            "i have" to listOf("i've", "ive"),
            "i will" to listOf("i'll", "ill"),
            "i would" to listOf("i'd", "id"),
            "you are" to listOf("you're", "youre"),
            "you have" to listOf("you've", "youve"),
            "you will" to listOf("you'll", "youll"),
            "you would" to listOf("you'd", "youd"),
            "he is" to listOf("he's", "hes"),
            "she is" to listOf("she's", "shes"),
            "it is" to listOf("it's", "its"),
            "we are" to listOf("we're", "were"),
            "we have" to listOf("we've", "weve"),
            "they are" to listOf("they're", "theyre"),
            "they have" to listOf("they've", "theyve"),
            "that is" to listOf("that's", "thats"),
            "there is" to listOf("there's", "theres"),
            "here is" to listOf("here's", "heres"),
            "what is" to listOf("what's", "whats"),
            "who is" to listOf("who's", "whos"),
            "let us" to listOf("let's", "lets")
        )

        // Reverse mapping for quick lookup
        private val reverseContractionMap: Map<String, String> by lazy {
            val map = mutableMapOf<String, String>()
            for ((expanded, contractions) in contractionMap) {
                for (contraction in contractions) {
                    map[contraction] = expanded
                }
            }
            map
        }

        // Common homophones that should be treated as equivalent
        // Includes speech recognition variations (how words are often transcribed)
        private val homophones: List<List<String>> = listOf(
            // Classic homophones
            listOf("maid", "made"),
            listOf("their", "there", "they're", "theyre"),
            listOf("your", "you're", "youre"),
            listOf("its", "it's"),
            listOf("to", "too", "two"),
            listOf("hear", "here"),
            listOf("no", "know"),
            listOf("knew", "new"),
            listOf("right", "write", "rite"),
            listOf("see", "sea"),
            listOf("be", "bee"),
            listOf("by", "buy", "bye"),
            listOf("for", "four", "fore"),
            listOf("one", "won"),
            listOf("sun", "son"),
            listOf("would", "wood"),
            listOf("wear", "where", "ware"),
            listOf("which", "witch"),
            listOf("peace", "piece"),
            listOf("wait", "weight"),
            listOf("week", "weak"),

            // Speech recognition variations - single letters and their spoken forms
            listOf("o", "oh", "owe"),
            listOf("i", "eye", "aye"),
            listOf("a", "ay", "eh"),
            listOf("u", "you"),
            listOf("r", "are", "our"),
            listOf("c", "see", "sea"),
            listOf("b", "be", "bee"),
            listOf("t", "tea", "tee"),
            listOf("p", "pea", "pee"),
            listOf("y", "why"),
            listOf("q", "queue", "cue"),
            listOf("w", "double-u", "doubleu"),

            // Common speech recognition confusions
            listOf("the", "thee", "da"),
            listOf("a", "uh", "ah"),
            listOf("an", "and"),  // Often confused in fast speech
            listOf("of", "off", "ov"),
            listOf("or", "ore", "oar"),
            listOf("are", "our", "r"),
            listOf("we", "wee"),
            listOf("in", "inn"),
            listOf("so", "sow", "sew"),
            listOf("know", "no", "nah"),
            listOf("through", "threw", "thru"),
            listOf("though", "tho"),
            listOf("cause", "'cause", "cuz", "because"),
            listOf("gonna", "going to", "gon"),
            listOf("wanna", "want to"),
            listOf("gotta", "got to"),
            listOf("kinda", "kind of"),
            listOf("sorta", "sort of"),
            listOf("coulda", "could have", "could of"),
            listOf("woulda", "would have", "would of"),
            listOf("shoulda", "should have", "should of"),

            // Numbers that sound alike
            listOf("eight", "ate"),
            listOf("2", "to", "too", "two"),
            listOf("4", "for", "four", "fore"),
            listOf("8", "eight", "ate"),

            // Religious/poetic terms often in memorization
            listOf("thou", "you", "tho", "though", "thow"),
            listOf("thy", "thigh", "they", "die"),
            listOf("thine", "vine", "fine", "dine", "mine"),
            listOf("unto", "un to", "on to"),
            listOf("hath", "has", "have"),
            listOf("doth", "does", "do"),
            listOf("art", "are"),
            listOf("shalt", "shall"),
            listOf("hast", "has", "have"),
            listOf("ye", "you", "yeah"),
            listOf("yea", "yeah", "yay", "yes"),
            listOf("nay", "nah", "no"),
            listOf("lo", "low"),
            listOf("o'er", "over", "oer"),
            listOf("ne'er", "never", "neer"),
            listOf("e'er", "ever", "eer"),
            listOf("'tis", "tis", "it is", "its"),
            listOf("'twas", "twas", "it was"),

            // Common proper noun variations
            listOf("god", "god's", "gods"),
            listOf("lord", "lord's", "lords"),
            listOf("christ", "christ's", "christs"),

            // Articles and prepositions that sound similar
            listOf("and", "end", "in"),
            listOf("than", "then"),
            listOf("accept", "except"),
            listOf("affect", "effect"),
            listOf("weather", "whether"),
            listOf("principal", "principle"),

            // Common words that speech recognition gets wrong
            listOf("going", "goin'", "goin"),
            listOf("something", "somethin'", "somethin"),
            listOf("nothing", "nothin'", "nothin"),
            listOf("everything", "everythin'", "everythin")
        )

        // Pre-computed homophone lookup
        private val homophoneLookup: Map<String, Set<String>> by lazy {
            val lookup = mutableMapOf<String, Set<String>>()
            for (group in homophones) {
                val groupSet = group.toSet()
                for (word in group) {
                    lookup[word] = groupSet
                }
            }
            lookup
        }

        // Irregular old English → modern English mappings that can't be derived algorithmically.
        // These are checked first before the generic suffix-stripping algorithm.
        private val oldEnglishIrregulars: Map<String, Set<String>> = mapOf(
            "hath" to setOf("has", "have", "had"),
            "doth" to setOf("does", "do", "did"),
            "shalt" to setOf("shall", "should"),
            "wilt" to setOf("will", "would"),
            "hast" to setOf("has", "have", "had"),
            "dost" to setOf("do", "does", "did"),
            "art" to setOf("are", "is"),
            "wert" to setOf("were", "was"),
            "canst" to setOf("can", "could"),
            "shouldst" to setOf("should"),
            "wouldst" to setOf("would"),
            "couldst" to setOf("could"),
            "methinks" to setOf("i think", "thinks"),
            "wherefore" to setOf("why", "therefore"),
            "whence" to setOf("where", "from where"),
            "thence" to setOf("there", "from there"),
            "hither" to setOf("here"),
            "thither" to setOf("there"),
            "ere" to setOf("before"),
            "lest" to setOf("for fear that", "unless"),
            "nigh" to setOf("near", "nearly"),
            "betwixt" to setOf("between"),
            "amongst" to setOf("among"),
            "whilst" to setOf("while"),
            "oft" to setOf("often"),
            "perchance" to setOf("perhaps", "maybe"),
            "forthwith" to setOf("immediately"),
            "saith" to setOf("says", "said"),
            "cometh" to setOf("comes", "come"),
            "goeth" to setOf("goes", "go"),
            "knoweth" to setOf("knows", "know"),
            "doeth" to setOf("does", "do"),
            "loveth" to setOf("loves", "love"),
            "giveth" to setOf("gives", "give"),
            "liveth" to setOf("lives", "live"),
            "maketh" to setOf("makes", "make"),
            "taketh" to setOf("takes", "take"),
            "seeketh" to setOf("seeks", "seek")
        )

        /**
         * Generate modern English equivalents from an old English word.
         * Strips archaic suffixes (-eth, -th, -est, -st) and produces
         * common modern verb conjugations from the root.
         */
        private fun modernEquivalents(ofOldEnglish: String): Set<String> {
            val word = ofOldEnglish
            val variants = mutableSetOf<String>()

            // Try each suffix pattern, longest first
            data class SuffixPattern(val suffix: String, val adjustments: (String) -> List<String>)

            val suffixPatterns = listOf(
                // -eth suffix: "clotheth" → root "cloth", "giveth" → root "giv"
                SuffixPattern("eth") { root ->
                    val results = mutableListOf<String>()
                    results.add(root)                    // cloth
                    results.add(root + "e")              // clothe
                    results.add(root + "es")             // clothes
                    results.add(root + "s")              // cloths
                    results.add(root + "ed")             // clothed
                    results.add(root + "ing")            // clothing

                    // Handle doubled consonant: "runneth" → root "runn" → "run"
                    if (root.length >= 2 && root.last() == root[root.length - 2]) {
                        val trimmed = root.dropLast(1)
                        results.add(trimmed)             // run
                        results.add(trimmed + "s")       // runs
                        results.add(trimmed + "ing")     // running
                    }

                    // Handle silent-e verbs: "giveth" → root "giv" → "give"
                    // Already covered by root + "e" above

                    results
                },

                // -est suffix (2nd person): "knowest" → root "know"
                SuffixPattern("est") { root ->
                    val results = mutableListOf<String>()
                    results.add(root)
                    results.add(root + "s")
                    results.add(root + "e")
                    results.add(root + "es")
                    results.add(root + "ed")

                    // Handle doubled consonant
                    if (root.length >= 2 && root.last() == root[root.length - 2]) {
                        val trimmed = root.dropLast(1)
                        results.add(trimmed)
                        results.add(trimmed + "s")
                    }

                    results
                },

                // -th suffix (shorter form): catches "comth" style (rare) and words like "saith" → root "sai"
                // Only trigger if root is at least 3 chars to avoid false positives
                SuffixPattern("th") { root ->
                    if (root.length < 3) return@SuffixPattern emptyList()
                    val results = mutableListOf<String>()
                    results.add(root)
                    results.add(root + "s")
                    results.add(root + "e")
                    results.add(root + "es")
                    results.add(root + "d")
                    results.add(root + "ed")

                    // "saith" → root "sai" → "say" (vowel ending → y)
                    if (root.endsWith("i") || root.endsWith("ai")) {
                        val yRoot = root.dropLast(1) + "y"
                        results.add(yRoot)               // say
                        results.add(yRoot + "s")          // says
                    }

                    results
                },

                // -st suffix (2nd person short form): "canst" → root "can"
                SuffixPattern("st") { root ->
                    if (root.length < 3) return@SuffixPattern emptyList()
                    val results = mutableListOf<String>()
                    results.add(root)
                    results.add(root + "s")
                    results
                }
            )

            for ((suffix, adjustments) in suffixPatterns) {
                if (word.endsWith(suffix)) {
                    val root = word.dropLast(suffix.length)
                    if (root.isEmpty()) continue
                    val adjusted = adjustments(root)
                    variants.addAll(adjusted)
                }
            }

            return variants
        }

        /**
         * Compute Levenshtein edit distance between two strings.
         * O(n*m) time and O(min(n,m)) space - fine for word-length strings.
         */
        private fun levenshteinDistance(s1: String, s2: String): Int {
            val a = s1.toCharArray()
            val b = s2.toCharArray()
            val n = a.size
            val m = b.size

            if (n == 0) return m
            if (m == 0) return n

            // Use two rows instead of full matrix to save memory
            var previousRow = IntArray(m + 1) { it }
            var currentRow = IntArray(m + 1)

            for (i in 1..n) {
                currentRow[0] = i
                for (j in 1..m) {
                    val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                    currentRow[j] = minOf(
                        currentRow[j - 1] + 1,      // insertion
                        previousRow[j] + 1,          // deletion
                        previousRow[j - 1] + cost    // substitution
                    )
                }
                val temp = previousRow
                previousRow = currentRow
                currentRow = temp
            }

            return previousRow[m]
        }
    }
}
