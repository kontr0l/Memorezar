import Foundation

/// How a match was determined
enum MatchType: String, Codable {
    case exact
    case userEquivalence
    case communityEquivalence
    case homophone
    case contraction
    case oldEnglish        // Old English verb form match (e.g., clotheth → clothes)
    case phonetic          // Double Metaphone match
    case alternativeMatch  // ASR alternative hypothesis matched
    case fuzzy
    case mismatch
}

/// Result of comparing a spoken word against the expected word
struct ComparisonResult {
    let isMatch: Bool
    let expectedWord: String
    let spokenWord: String
    let normalizedExpected: String
    let normalizedSpoken: String
    let position: Int
    let confidence: Float      // 0.0 = unknown, >0 = Apple's score
    let matchType: MatchType   // How match was determined

    init(isMatch: Bool, expectedWord: String, spokenWord: String,
         normalizedExpected: String, normalizedSpoken: String, position: Int,
         confidence: Float = 0.0, matchType: MatchType = .mismatch) {
        self.isMatch = isMatch
        self.expectedWord = expectedWord
        self.spokenWord = spokenWord
        self.normalizedExpected = normalizedExpected
        self.normalizedSpoken = normalizedSpoken
        self.position = position
        self.confidence = confidence
        self.matchType = matchType
    }
}

/// Word-by-Word Comparator
///
/// Compares spoken words against target text in real-time.
/// Handles normalization, punctuation, contractions, and common variations.
///
/// Performance: Uses pre-allocated arrays and avoids allocations in hot path
final class WordComparator {

    // MARK: - Properties

    private var targetWords: [String] = []
    private var normalizedTargetWords: [String] = []
    private var targetPhoneticCodes: [DoubleMetaphone.PhoneticCode?] = []
    private(set) var currentPosition: Int = 0
    private var language: String? = nil  // nil = English (default)

    // User-defined word equivalences (expected → set of accepted spoken alternatives)
    private var userEquivalences: [String: Set<String>] = [:]

    // Community-sourced equivalences (lower priority than user equivalences)
    private var communityEquivalences: [String: Set<String>] = [:]

    // Compound word buffer - holds partial word when speech recognition splits a compound word
    private var compoundBuffer: String? = nil
    private var compoundBufferTimestamp: Date? = nil
    private static let compoundBufferTimeout: TimeInterval = 1.5 // seconds to wait for second part

    // Multi-word join buffer - tracks recent mismatched words at the same position
    // to detect STT splitting a compound word into multiple words
    // (e.g., "maidservant" → "mate" + "servant" → joined "mateservant" ≈ "maidservant")
    private var multiWordBuffer: [String] = []
    private var multiWordPosition: Int = -1
    private static let multiWordBufferMaxSize = 4

    // Look-ahead resync - when stuck at a position due to STT errors
    // (e.g., "O Thou" → "Although"), try matching against upcoming expected words
    private var consecutiveMismatchCount = 0
    private var consecutiveMismatchPosition = -1
    private static let lookAheadThreshold = 2
    private static let lookAheadRange = 8
    private static let lookAheadMinWordLength = 4

    // Pre-computed for performance
    private static let fillerWords: Set<String> = ["um", "uh", "er", "ah", "like", "you", "know", "so", "well", "actually"]
    private static let punctuationCharacters = CharacterSet.punctuationCharacters

    // Digit-to-word map for handling Apple's concatenated number transcriptions
    // e.g. "one two three" → "123" — last digit "3" → "three"
    private static let digitToWord: [Character: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
        "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine",
    ]

    // Contraction mappings (expanded form -> contracted forms)
    private static let contractionMap: [String: [String]] = [
        "do not": ["don't", "dont"],
        "does not": ["doesn't", "doesnt"],
        "did not": ["didn't", "didnt"],
        "is not": ["isn't", "isnt"],
        "are not": ["aren't", "arent"],
        "was not": ["wasn't", "wasnt"],
        "were not": ["weren't", "werent"],
        "have not": ["haven't", "havent"],
        "has not": ["hasn't", "hasnt"],
        "had not": ["hadn't", "hadnt"],
        "will not": ["won't", "wont"],
        "would not": ["wouldn't", "wouldnt"],
        "could not": ["couldn't", "couldnt"],
        "should not": ["shouldn't", "shouldnt"],
        "can not": ["can't", "cant", "cannot"],
        "cannot": ["can't", "cant"],
        "i am": ["i'm", "im"],
        "i have": ["i've", "ive"],
        "i will": ["i'll", "ill"],
        "i would": ["i'd", "id"],
        "you are": ["you're", "youre"],
        "you have": ["you've", "youve"],
        "you will": ["you'll", "youll"],
        "you would": ["you'd", "youd"],
        "he is": ["he's", "hes"],
        "she is": ["she's", "shes"],
        "it is": ["it's", "its"],
        "we are": ["we're", "were"],
        "we have": ["we've", "weve"],
        "they are": ["they're", "theyre"],
        "they have": ["they've", "theyve"],
        "that is": ["that's", "thats"],
        "there is": ["there's", "theres"],
        "here is": ["here's", "heres"],
        "what is": ["what's", "whats"],
        "who is": ["who's", "whos"],
        "let us": ["let's", "lets"],
    ]

    // Reverse mapping for quick lookup
    private static let reverseContractionMap: [String: String] = {
        var map: [String: String] = [:]
        for (expanded, contractions) in contractionMap {
            for contraction in contractions {
                map[contraction] = expanded
            }
        }
        return map
    }()

    // Common homophones that should be treated as equivalent
    // Includes speech recognition variations (how words are often transcribed)
    private static let homophones: [[String]] = [
        // Classic homophones
        ["maid", "made"],
        ["their", "there", "they're", "theyre"],
        ["your", "you're", "youre"],
        ["its", "it's"],
        ["to", "too", "two"],
        ["hear", "here"],
        ["no", "know"],
        ["knew", "new"],
        ["right", "write", "rite"],
        ["see", "sea"],
        ["be", "bee"],
        ["by", "buy", "bye"],
        ["for", "four", "fore"],
        ["one", "won"],
        ["sun", "son"],
        ["would", "wood"],
        ["wear", "where", "ware"],
        ["which", "witch"],
        ["peace", "piece"],
        ["wait", "weight"],
        ["week", "weak"],

        // Speech recognition variations - single letters and their spoken forms
        ["o", "oh", "owe"],
        ["i", "eye", "aye"],
        ["a", "ay", "eh"],
        ["u", "you"],
        ["r", "are", "our"],
        ["c", "see", "sea"],
        ["b", "be", "bee"],
        ["t", "tea", "tee"],
        ["p", "pea", "pee"],
        ["y", "why"],
        ["q", "queue", "cue"],
        ["w", "double-u", "doubleu"],

        // Common speech recognition confusions
        ["the", "thee", "da"],
        ["a", "uh", "ah"],
        ["an", "and"],  // Often confused in fast speech
        ["of", "off", "ov"],
        ["or", "ore", "oar"],
        ["are", "our", "r"],
        ["we", "wee"],
        ["in", "inn"],
        ["so", "sow", "sew"],
        ["know", "no", "nah"],
        ["through", "threw", "thru"],
        ["though", "tho"],
        ["cause", "'cause", "cuz", "because"],
        ["gonna", "going to", "gon"],
        ["wanna", "want to"],
        ["gotta", "got to"],
        ["kinda", "kind of"],
        ["sorta", "sort of"],
        ["coulda", "could have", "could of"],
        ["woulda", "would have", "would of"],
        ["shoulda", "should have", "should of"],

        // Numbers that sound alike
        ["eight", "ate"],
        ["2", "to", "too", "two"],
        ["4", "for", "four", "fore"],
        ["8", "eight", "ate"],

        // Religious/poetic terms often in memorization
        ["thou", "you", "tho", "though", "thow"],
        ["thy", "thigh", "they", "die"],
        ["thine", "vine", "fine", "dine", "mine"],
        ["unto", "un to", "on to"],
        ["hath", "has", "have"],
        ["doth", "does", "do"],
        ["art", "are"],
        ["shalt", "shall"],
        ["hast", "has", "have"],
        ["ye", "you", "yeah"],
        ["yea", "yeah", "yay", "yes"],
        ["nay", "nah", "no"],
        ["lo", "low"],
        ["o'er", "over", "oer"],
        ["ne'er", "never", "neer"],
        ["e'er", "ever", "eer"],
        ["'tis", "tis", "it is", "its"],
        ["'twas", "twas", "it was"],

        // Common proper noun variations
        ["god", "god's", "gods"],
        ["lord", "lord's", "lords"],
        ["christ", "christ's", "christs"],

        // Articles and prepositions that sound similar
        ["and", "end", "in"],
        ["than", "then"],
        ["accept", "except"],
        ["affect", "effect"],
        ["weather", "whether"],
        ["principal", "principle"],

        // Common words that speech recognition gets wrong
        ["going", "goin'", "goin"],
        ["something", "somethin'", "somethin"],
        ["nothing", "nothin'", "nothin"],
        ["everything", "everythin'", "everythin"],
    ]

    // Pre-computed homophone lookup
    private static let homophoneLookup: [String: Set<String>] = {
        var lookup: [String: Set<String>] = [:]
        for group in homophones {
            let groupSet = Set(group)
            for word in group {
                lookup[word] = groupSet
            }
        }
        return lookup
    }()

    // MARK: - Initialization

    init() {
    }

    // MARK: - Public Methods

    /// Set the target text that the user is trying to recite
    func setTargetText(_ text: String, language: String? = nil) {
        self.language = language
        targetWords = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        normalizedTargetWords = targetWords.map { normalize($0) }
        // Pre-compute phonetic codes for English only (Double Metaphone is English-specific)
        if language == nil {
            targetPhoneticCodes = normalizedTargetWords.map { DoubleMetaphone.encode($0) }
        } else {
            targetPhoneticCodes = Array(repeating: nil, count: normalizedTargetWords.count)
        }
        currentPosition = 0
        multiWordBuffer = []
        multiWordPosition = -1
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
    }

    /// Compare a spoken word against the expected word at current position
    /// Returns nil if the word is a filler word (should be ignored)
    func compareWord(_ spokenWord: String, confidence: Float = 0.0, alternatives: [String] = []) -> ComparisonResult? {
        let normalizedSpoken = normalize(spokenWord)

        // DEBUG: Log incoming word
        print("[COMPARE] Received: \"\(spokenWord)\" → normalized: \"\(normalizedSpoken)\" | pos=\(currentPosition) buffer=\"\(compoundBuffer ?? "nil")\"")

        // Skip empty words
        guard !normalizedSpoken.isEmpty else {
            print("[COMPARE] → SKIP (empty)")
            return nil
        }

        // Skip filler words — but NOT if the filler word is the expected word at the current position.
        // Words like "so", "well", "you", "like" are common fillers but also appear in real text.
        if isFillerWord(normalizedSpoken) {
            let isExpectedWord = currentPosition < normalizedTargetWords.count &&
                normalizedSpoken == normalizedTargetWords[currentPosition]
            if !isExpectedWord {
                print("[COMPARE] → SKIP (filler)")
                return nil
            }
            print("[COMPARE] Filler word \"\(normalizedSpoken)\" matches expected — not skipping")
        }

        // Check if we've reached the end
        guard currentPosition < targetWords.count else {
            print("[COMPARE] → PAST END")
            compoundBuffer = nil
            compoundBufferTimestamp = nil
            return ComparisonResult(
                isMatch: false,
                expectedWord: "[END]",
                spokenWord: spokenWord,
                normalizedExpected: "",
                normalizedSpoken: normalizedSpoken,
                position: currentPosition,
                confidence: confidence
            )
        }

        let expectedWord = targetWords[currentPosition]
        let normalizedExpected = normalizedTargetWords[currentPosition]
        print("[COMPARE] Expected: \"\(expectedWord)\" → normalized: \"\(normalizedExpected)\"")

        // --- Echo filter ---
        // When the speech service restarts (after mistake popup or session restart),
        // residual audio from the previous word can be re-transcribed and sent again.
        // If the spoken word exactly matches the previous target word but doesn't match
        // the current expected word, it's an echo — ignore it.
        if currentPosition > 0 &&
           normalizedSpoken == normalizedTargetWords[currentPosition - 1] &&
           checkMatch(spoken: normalizedSpoken, expected: normalizedExpected) == .mismatch {
            print("[COMPARE] → SKIP (echo of previous word \"\(targetWords[currentPosition - 1])\")")
            return nil
        }

        // --- Compound word handling ---

        // First, check if this word is a REVISION of the buffered word (speech recognizer
        // revised a partial word to a complete word). This happens when:
        // - We have "glor" buffered and receive "glorious"
        // - "glorious" starts with "glor" → this is a revision, not a second word
        // In this case, clear the buffer and process the new word as the complete word.
        if let buffered = compoundBuffer, normalizedSpoken.hasPrefix(buffered) && normalizedSpoken.count > buffered.count {
            // This is a revision of the partial word, not a new word to combine
            print("[COMPARE] Buffer revision detected: \"\(buffered)\" → \"\(normalizedSpoken)\"")
            compoundBuffer = nil
            compoundBufferTimestamp = nil
            // Fall through to normal comparison with the revised (complete) word
        }

        // If we have a buffered partial word, try combining it with the new spoken word
        if let buffered = compoundBuffer {
            let combined = buffered + normalizedSpoken
            let combinedFull = buffered + spokenWord
            print("[COMPARE] Trying buffer combine: \"\(buffered)\" + \"\(normalizedSpoken)\" = \"\(combined)\"")

            // Check if the combined word matches the expected word
            let combinedMatchType = checkMatch(spoken: combined, expected: normalizedExpected)
            if combinedMatchType != .mismatch {
                print("[COMPARE] → MATCH (combined, \(combinedMatchType))! pos \(currentPosition) → \(currentPosition + 1)")
                compoundBuffer = nil
                compoundBufferTimestamp = nil
                consecutiveMismatchCount = 0

                let result = ComparisonResult(
                    isMatch: true,
                    expectedWord: expectedWord,
                    spokenWord: combinedFull,
                    normalizedExpected: normalizedExpected,
                    normalizedSpoken: combined,
                    position: currentPosition,
                    confidence: confidence,
                    matchType: combinedMatchType
                )

                currentPosition += 1
                return result
            }

            // Combined word doesn't match. Check if the buffer has timed out.
            let timedOut = compoundBufferTimestamp.map {
                Date().timeIntervalSince($0) > Self.compoundBufferTimeout
            } ?? true

            if timedOut {
                // Buffer timed out — the buffered word was genuinely wrong.
                // Emit a mismatch for the buffered word, then clear buffer
                // and re-process the current spoken word on next call.
                compoundBuffer = nil
                compoundBufferTimestamp = nil

                let result = ComparisonResult(
                    isMatch: false,
                    expectedWord: expectedWord,
                    spokenWord: buffered,
                    normalizedExpected: normalizedExpected,
                    normalizedSpoken: buffered,
                    position: currentPosition,
                    confidence: confidence
                )

                // Re-process the current word by recursing (it wasn't consumed)
                // We do this after returning the mismatch for the buffer
                return result
            }

            // Not timed out but combined doesn't match — check if the expected word
            // still starts with the combined text (keep buffering)
            if normalizedExpected.hasPrefix(combined) {
                compoundBuffer = combined
                return nil // Still buffering, no result yet
            }

            // If the new word is identical to the buffer, it's a STT duplicate/echo.
            // Keep the buffer as-is and ignore the duplicate — don't reset.
            if normalizedSpoken == buffered {
                print("[COMPARE] → SKIP (duplicate of buffer \"\(buffered)\")")
                return nil
            }

            // Before discarding the buffer, check if it already covers most of
            // the expected word. STT often recognises "heart" for "hearts" — the
            // buffer is a valid prefix and close enough (≥ 75% coverage). Accept
            // it as a match instead of firing a false mismatch.
            if normalizedExpected.hasPrefix(buffered),
               Double(buffered.count) >= Double(normalizedExpected.count) * 0.75 {
                print("[COMPARE] → MATCH (buffer prefix-coverage \(buffered.count)/\(normalizedExpected.count))! pos \(currentPosition) → \(currentPosition + 1)")
                compoundBuffer = nil
                compoundBufferTimestamp = nil
                consecutiveMismatchCount = 0

                let result = ComparisonResult(
                    isMatch: true,
                    expectedWord: expectedWord,
                    spokenWord: buffered,
                    normalizedExpected: normalizedExpected,
                    normalizedSpoken: buffered,
                    position: currentPosition,
                    confidence: confidence,
                    matchType: .fuzzy
                )
                currentPosition += 1

                // The current spoken word was NOT consumed — re-process it
                // by recursing now that position has advanced.
                if let nextResult = compareWord(spokenWord, confidence: confidence, alternatives: alternatives) {
                    // Return the buffer match; the recursive call already
                    // advanced position for the next word. We can only return
                    // one result, so return the buffer match and let the next
                    // call from the speech service handle the rest.
                    _ = nextResult  // consumed internally — position advanced
                }
                return result
            }

            // Combined doesn't match and isn't a prefix — the buffer was wrong.
            // Clear the buffer and fall through to check the new word independently.
            // This prevents consuming words like "maidservant" when the buffer "made"
            // can't combine with it (made + maidservant = mademaidservant ≠ maidservant).
            print("[COMPARE] Buffer \"\(buffered)\" was wrong — checking \"\(normalizedSpoken)\" independently")
            compoundBuffer = nil
            compoundBufferTimestamp = nil

            // Seed the multi-word buffer with the flushed buffer word so it can
            // participate in multi-word joins (e.g., "maids" + "servant" → "maidsservant" ≈ "maidservant")
            if multiWordPosition != currentPosition {
                multiWordBuffer = []
                multiWordPosition = currentPosition
            }
            multiWordBuffer.append(buffered)
            // Fall through to normal comparison below
        }

        // --- Normal (non-buffered) comparison ---

        // Check for direct match (including homophone, contraction, phonetic handling)
        let directMatchType = checkMatch(spoken: normalizedSpoken, expected: normalizedExpected)

        if directMatchType != .mismatch {
            print("[COMPARE] → MATCH (direct, \(directMatchType))! pos \(currentPosition) → \(currentPosition + 1)")
            consecutiveMismatchCount = 0
            let result = ComparisonResult(
                isMatch: true,
                expectedWord: expectedWord,
                spokenWord: spokenWord,
                normalizedExpected: normalizedExpected,
                normalizedSpoken: normalizedSpoken,
                position: currentPosition,
                confidence: confidence,
                matchType: directMatchType
            )
            currentPosition += 1
            return result
        }

        // --- Concatenated digit check ---
        // Apple's speech recognition sometimes concatenates number words into digit strings:
        // "one two three" → "1", "12", "123". The trailing digit(s) represent the new word.
        // Extract the last digit and check if its number-word form matches the expected word.
        if normalizedSpoken.allSatisfy(\.isNumber) && normalizedSpoken.count >= 2 {
            if let lastChar = normalizedSpoken.last,
               let digitWord = Self.digitToWord[lastChar] {
                let digitMatchType = checkMatch(spoken: digitWord, expected: normalizedExpected)
                if digitMatchType != .mismatch {
                    print("[COMPARE] → MATCH (digit-concat \"\(normalizedSpoken)\" → trailing \"\(digitWord)\", \(digitMatchType))! pos \(currentPosition) → \(currentPosition + 1)")
                    consecutiveMismatchCount = 0
                    let result = ComparisonResult(
                        isMatch: true,
                        expectedWord: expectedWord,
                        spokenWord: spokenWord,
                        normalizedExpected: normalizedExpected,
                        normalizedSpoken: digitWord,
                        position: currentPosition,
                        confidence: confidence,
                        matchType: digitMatchType
                    )
                    currentPosition += 1
                    return result
                }
            }
        }

        // --- Alternative hypotheses check ---
        // Apple's speech recognizer provides alternative transcriptions for each segment.
        // If any alternative matches the expected word, accept it as a match.
        if !alternatives.isEmpty {
            for alt in alternatives {
                let normalizedAlt = normalize(alt)
                guard !normalizedAlt.isEmpty else { continue }
                let altMatchType = checkMatch(spoken: normalizedAlt, expected: normalizedExpected)
                if altMatchType != .mismatch {
                    print("[COMPARE] → MATCH (alternative \"\(alt)\", \(altMatchType))! pos \(currentPosition) → \(currentPosition + 1)")
                    consecutiveMismatchCount = 0
                    let result = ComparisonResult(
                        isMatch: true,
                        expectedWord: expectedWord,
                        spokenWord: spokenWord,
                        normalizedExpected: normalizedExpected,
                        normalizedSpoken: normalizedAlt,
                        position: currentPosition,
                        confidence: confidence,
                        matchType: .alternativeMatch
                    )
                    currentPosition += 1
                    return result
                }
            }
        }

        // Not a direct match — check if this could be the start of a compound word.
        // If the expected word starts with the spoken word (or a homophone of it),
        // buffer the spoken word and wait for the next part.
        if isCompoundWordPrefix(spoken: normalizedSpoken, expected: normalizedExpected) {
            print("[COMPARE] → BUFFER: \"\(normalizedSpoken)\" (prefix of \"\(normalizedExpected)\")")
            compoundBuffer = normalizedSpoken
            compoundBufferTimestamp = Date()
            return nil // Buffering — no result yet
        }

        // --- Multi-word join attempt ---
        // STT sometimes splits compound/uncommon words into multiple words
        // (e.g., "maidservant" → "mate" + "servant"). Try joining recent
        // mismatched words at this position and check if the joined result matches.

        if multiWordPosition != currentPosition {
            multiWordBuffer = []
            multiWordPosition = currentPosition
        }

        // If the new word is a revision/extension of the last entry, replace instead of
        // appending. STT partials like "ser" → "servan" → "servant" should update in place,
        // not accumulate as separate entries that break joining.
        if let lastWord = multiWordBuffer.last,
           normalizedSpoken.hasPrefix(lastWord) && normalizedSpoken.count > lastWord.count {
            print("[COMPARE] Multi-word buffer revision: \"\(lastWord)\" → \"\(normalizedSpoken)\"")
            multiWordBuffer[multiWordBuffer.count - 1] = normalizedSpoken
        } else {
            multiWordBuffer.append(normalizedSpoken)
        }

        if multiWordBuffer.count >= 2 {
            let joinCount = min(multiWordBuffer.count, Self.multiWordBufferMaxSize)
            for n in 2...joinCount {
                let startIdx = multiWordBuffer.count - n
                let joined = multiWordBuffer[startIdx...].joined()
                let joinMatchType = checkMatch(spoken: joined, expected: normalizedExpected)
                if joinMatchType != .mismatch {
                    print("[COMPARE] → MATCH (multi-word join, \(joinMatchType))! \"\(joined)\" ≈ \"\(normalizedExpected)\" pos \(currentPosition) → \(currentPosition + 1)")
                    multiWordBuffer = []
                    consecutiveMismatchCount = 0

                    let result = ComparisonResult(
                        isMatch: true,
                        expectedWord: expectedWord,
                        spokenWord: joined,
                        normalizedExpected: normalizedExpected,
                        normalizedSpoken: joined,
                        position: currentPosition,
                        confidence: confidence,
                        matchType: joinMatchType
                    )
                    currentPosition += 1
                    return result
                }
            }
        }

        // Cap buffer size
        if multiWordBuffer.count > Self.multiWordBufferMaxSize {
            multiWordBuffer.removeFirst(multiWordBuffer.count - Self.multiWordBufferMaxSize)
        }

        // --- Look-ahead resync ---
        // When stuck at a position due to STT merging words (e.g., "O Thou" → "Although"),
        // try matching the spoken word against upcoming expected words to resync.
        if consecutiveMismatchPosition != currentPosition {
            consecutiveMismatchCount = 0
            consecutiveMismatchPosition = currentPosition
        }
        consecutiveMismatchCount += 1

        if consecutiveMismatchCount >= Self.lookAheadThreshold &&
           normalizedSpoken.count >= Self.lookAheadMinWordLength {
            // Only look-ahead for words >= 4 chars. Short common words ("the", "a", "and", "of")
            // appear many times in a quote and would match at the wrong position by coincidence.
            let maxPos = min(currentPosition + Self.lookAheadRange + 1, targetWords.count)
            for i in (currentPosition + 1)..<max(currentPosition + 1, maxPos) {
                let expectedLen = normalizedTargetWords[i].count
                // Skip if spoken word is much shorter than expected word — likely a partial
                // match for a split word (e.g., "made" matching "maidservant" via user
                // equivalences when STT split it as "made" + "servant"). Require spoken word
                // to be at least 50% of expected word's length.
                guard normalizedSpoken.count * 2 >= expectedLen else { continue }

                let laMatchType = checkMatch(spoken: normalizedSpoken, expected: normalizedTargetWords[i])
                if laMatchType != .mismatch {
                    print("[COMPARE] → MATCH (look-ahead at pos \(i), \(laMatchType))! Skipping pos \(currentPosition)..\(i - 1)")
                    consecutiveMismatchCount = 0
                    multiWordBuffer = []

                    let result = ComparisonResult(
                        isMatch: true,
                        expectedWord: targetWords[i],
                        spokenWord: spokenWord,
                        normalizedExpected: normalizedTargetWords[i],
                        normalizedSpoken: normalizedSpoken,
                        position: i,
                        confidence: confidence,
                        matchType: laMatchType
                    )
                    currentPosition = i + 1
                    return result
                }
            }
        }

        // Definite mismatch — position stays (user must say the correct word)
        print("[COMPARE] → MISMATCH: \"\(normalizedSpoken)\" != \"\(normalizedExpected)\"")
        return ComparisonResult(
            isMatch: false,
            expectedWord: expectedWord,
            spokenWord: spokenWord,
            normalizedExpected: normalizedExpected,
            normalizedSpoken: normalizedSpoken,
            position: currentPosition,
            confidence: confidence
        )
    }

    /// Try to match a spoken word against the next few expected words (for sync recovery).
    /// Called by ViewModel when a pending mismatch is about to fire as a popup.
    /// If the spoken word matches an upcoming position, the STT likely dropped a word.
    /// Advances position past the match and returns a match result.
    /// Returns nil if no nearby match found.
    func tryMatchAhead(spoken: String, range: Int = 2) -> ComparisonResult? {
        let normalizedSpoken = normalize(spoken)
        guard normalizedSpoken.count >= Self.lookAheadMinWordLength else { return nil }

        let maxPos = min(currentPosition + range + 1, targetWords.count)
        for i in (currentPosition + 1)..<max(currentPosition + 1, maxPos) {
            let expectedLen = normalizedTargetWords[i].count
            guard normalizedSpoken.count * 2 >= expectedLen else { continue }

            let syncMatchType = checkMatch(spoken: normalizedSpoken, expected: normalizedTargetWords[i])
            if syncMatchType != .mismatch {
                print("[COMPARE] → SYNC RECOVERY (match at pos \(i), \(syncMatchType))! Skipping pos \(currentPosition)..\(i - 1)")
                let result = ComparisonResult(
                    isMatch: true,
                    expectedWord: targetWords[i],
                    spokenWord: spoken,
                    normalizedExpected: normalizedTargetWords[i],
                    normalizedSpoken: normalizedSpoken,
                    position: i,
                    matchType: syncMatchType
                )
                currentPosition = i + 1
                consecutiveMismatchCount = 0
                consecutiveMismatchPosition = -1
                multiWordBuffer = []
                return result
            }
        }
        return nil
    }

    /// Advance position by one (used by popup "It's a Match" flow)
    func advancePosition() {
        guard currentPosition < targetWords.count else { return }
        currentPosition += 1
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
        multiWordBuffer = []
    }

    /// Jump to a specific position (used by tap-to-reveal)
    func setPosition(_ position: Int) {
        guard position >= 0 && position < targetWords.count else { return }
        currentPosition = position
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
        multiWordBuffer = []
    }

    /// Set user-defined word equivalences
    func setUserEquivalences(_ equivalences: [String: Set<String>]) {
        self.userEquivalences = equivalences
    }

    /// Set community-sourced equivalences (lower priority than user equivalences)
    func setCommunityEquivalences(_ equivalences: [String: Set<String>]) {
        self.communityEquivalences = equivalences
    }

    /// Reset to start of text
    func reset() {
        currentPosition = 0
        compoundBuffer = nil
        compoundBufferTimestamp = nil
        multiWordBuffer = []
        multiWordPosition = -1
        consecutiveMismatchCount = 0
        consecutiveMismatchPosition = -1
    }

    /// Get total word count
    var totalWords: Int {
        targetWords.count
    }

    /// Check if recitation is complete
    var isComplete: Bool {
        currentPosition >= targetWords.count
    }

    /// Get the next expected word (for hints)
    var nextExpectedWord: String? {
        guard currentPosition < targetWords.count else { return nil }
        return targetWords[currentPosition]
    }

    /// Get all target words (for display)
    func getTargetWords() -> [String] {
        targetWords
    }

    /// Get progress as percentage
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(currentPosition) / Double(totalWords)
    }

    // MARK: - Private Methods

    /// Normalize a word for comparison (optimized for performance)
    private func normalize(_ word: String) -> String {
        var result = word
            .unicodeScalars
            .filter { !Self.punctuationCharacters.contains($0) }
            .map { Character($0) }
            .reduce(into: "") { $0.append($1) }

        result = result.lowercased()

        // For non-English languages, fold diacritics so "está" matches "esta"
        if language != nil {
            result = result.folding(options: .diacriticInsensitive, locale: nil)
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Check if a word is a filler word
    private func isFillerWord(_ word: String) -> Bool {
        Self.fillerWords.contains(word.lowercased())
    }

    /// Check if the spoken word could be the start of a compound target word.
    /// e.g., spoken "maid" could be the start of target "maidservant"
    /// Also checks homophones of the spoken word (e.g., "made" → "maid" prefix of "maidservant")
    private func isCompoundWordPrefix(spoken: String, expected: String) -> Bool {
        // Only consider this if the expected word is longer than spoken
        guard expected.count > spoken.count else { return false }

        // Direct prefix check
        if expected.hasPrefix(spoken) {
            return true
        }

        // Check if any homophone of the spoken word is a prefix of the expected word
        if let homophoneGroup = Self.homophoneLookup[spoken] {
            for homophone in homophoneGroup {
                if homophone != spoken && expected.hasPrefix(homophone) {
                    return true
                }
            }
        }

        return false
    }

    /// Flush the compound buffer when speech recognition ends.
    /// If the buffer contains a prefix of the expected word (which it always does if buffered),
    /// we silently discard it rather than counting as a mistake - the user likely said the word
    /// but speech recognition was incomplete. They can try again.
    func flushCompoundBuffer() -> ComparisonResult? {
        guard compoundBuffer != nil else { return nil }

        // Silently discard the buffer - it was a prefix of the expected word,
        // so this was likely incomplete speech recognition, not a real mistake.
        // The user will try again.
        compoundBuffer = nil
        compoundBufferTimestamp = nil

        return nil
    }

    /// Check if spoken word matches expected word (handles contractions, homophones, phonetics)
    /// Returns the MatchType if matched, or .mismatch if not
    private func checkMatch(spoken: String, expected: String) -> MatchType {
        // Direct match
        if spoken == expected {
            return .exact
        }

        // User-defined equivalences (user tapped "Accept as match" for this pair)
        if let accepted = userEquivalences[expected], accepted.contains(spoken) {
            return .userEquivalence
        }

        // Community-sourced equivalences (crowd-sourced from all users)
        if let accepted = communityEquivalences[expected], accepted.contains(spoken) {
            return .communityEquivalence
        }

        // Check homophones
        if let homophoneGroup = Self.homophoneLookup[expected],
           homophoneGroup.contains(spoken) {
            return .homophone
        }

        // Check contractions (both directions)
        if let expandedForm = Self.reverseContractionMap[spoken] {
            let expandedWords = expandedForm.split(separator: " ").map(String.init)
            if expandedWords.first == expected {
                return .contraction
            }
        }

        if let expandedForm = Self.reverseContractionMap[expected] {
            let expandedWords = expandedForm.split(separator: " ").map(String.init)
            if expandedWords.first == spoken {
                return .contraction
            }
        }

        if let contractions = Self.contractionMap[expected], contractions.contains(spoken) {
            return .contraction
        }
        if let contractions = Self.contractionMap[spoken], contractions.contains(expected) {
            return .contraction
        }

        // English-specific matching (Old English, Double Metaphone)
        if language == nil {
            // Old English verb form matching
            if isOldEnglishMatch(spoken: spoken, expected: expected) {
                print("[COMPARE] Old English match: \"\(spoken)\" ≈ \"\(expected)\"")
                return .oldEnglish
            }

            // Phonetic matching via Double Metaphone (English-specific algorithm)
            if DoubleMetaphone.arePhoneticallySimilar(spoken, expected) {
                print("[COMPARE] Phonetic match: \"\(spoken)\" ≈ \"\(expected)\"")
                return .phonetic
            }
        }

        // Fuzzy matching for STT errors on uncommon words.
        // The speech recognizer sometimes splits words (e.g., "encircles" → "In circles")
        // or drops prefixes. Check if the spoken word is close enough to the expected word.
        if isFuzzyMatch(spoken: spoken, expected: expected) {
            print("[COMPARE] Fuzzy match: \"\(spoken)\" ≈ \"\(expected)\"")
            return .fuzzy
        }

        return .mismatch
    }

    // MARK: - Old English Detection

    /// Irregular old English → modern English mappings that can't be derived algorithmically.
    /// These are checked first before the generic suffix-stripping algorithm.
    private static let oldEnglishIrregulars: [String: Set<String>] = [
        "hath": ["has", "have", "had"],
        "doth": ["does", "do", "did"],
        "shalt": ["shall", "should"],
        "wilt": ["will", "would"],
        "hast": ["has", "have", "had"],
        "dost": ["do", "does", "did"],
        "art": ["are", "is"],
        "wert": ["were", "was"],
        "canst": ["can", "could"],
        "shouldst": ["should"],
        "wouldst": ["would"],
        "couldst": ["could"],
        "methinks": ["i think", "thinks"],
        "wherefore": ["why", "therefore"],
        "whence": ["where", "from where"],
        "thence": ["there", "from there"],
        "hither": ["here"],
        "thither": ["there"],
        "ere": ["before"],
        "lest": ["for fear that", "unless"],
        "nigh": ["near", "nearly"],
        "betwixt": ["between"],
        "amongst": ["among"],
        "whilst": ["while"],
        "oft": ["often"],
        "perchance": ["perhaps", "maybe"],
        "forthwith": ["immediately"],
        "saith": ["says", "said"],
        "cometh": ["comes", "come"],
        "goeth": ["goes", "go"],
        "knoweth": ["knows", "know"],
        "doeth": ["does", "do"],
        "loveth": ["loves", "love"],
        "giveth": ["gives", "give"],
        "liveth": ["lives", "live"],
        "maketh": ["makes", "make"],
        "taketh": ["takes", "take"],
        "seeketh": ["seeks", "seek"],
    ]

    /// Check if spoken word matches an old English expected word.
    /// Works by extracting the modern root from old English verb forms
    /// and generating possible modern equivalents that STT might produce.
    private func isOldEnglishMatch(spoken: String, expected: String) -> Bool {
        // Need at least 3 characters for meaningful matching
        guard expected.count >= 3, spoken.count >= 2 else { return false }

        // 1. Check irregular old English forms first
        if let modernForms = Self.oldEnglishIrregulars[expected], modernForms.contains(spoken) {
            return true
        }

        // 2. Generic suffix-stripping algorithm
        // Generate modern equivalents from old English verb suffixes
        let modernVariants = Self.modernEquivalents(ofOldEnglish: expected)
        if modernVariants.contains(spoken) {
            return true
        }

        // 3. Phonetic check: if any modern variant sounds like the spoken word
        for variant in modernVariants {
            if DoubleMetaphone.arePhoneticallySimilar(spoken, variant) {
                return true
            }
        }

        // 4. Fuzzy check against modern variants (for STT garbling)
        for variant in modernVariants where variant.count >= 4 && spoken.count >= 4 {
            let distance = Self.levenshteinDistance(spoken, variant)
            let maxLen = max(spoken.count, variant.count)
            let similarity = 1.0 - (Double(distance) / Double(maxLen))
            if similarity >= 0.75 {
                return true
            }
        }

        return false
    }

    /// Generate modern English equivalents from an old English word.
    /// Strips archaic suffixes (-eth, -th, -est, -st) and produces
    /// common modern verb conjugations from the root.
    private static func modernEquivalents(ofOldEnglish word: String) -> Set<String> {
        var variants = Set<String>()

        // Try each suffix pattern, longest first
        let suffixPatterns: [(suffix: String, rootAdjustments: (String) -> [String])] = [
            // -eth suffix: "clotheth" → root "cloth", "giveth" → root "giv"
            ("eth", { root in
                var results = [root]                    // cloth
                results.append(root + "e")              // clothe
                results.append(root + "es")             // clothes
                results.append(root + "s")              // cloths
                results.append(root + "ed")             // clothed
                results.append(root + "ing")            // clothing

                // Handle doubled consonant: "runneth" → root "runn" → "run"
                if root.count >= 2 && root.last == root.dropLast().last {
                    let trimmed = String(root.dropLast())
                    results.append(trimmed)             // run
                    results.append(trimmed + "s")       // runs
                    results.append(trimmed + "ing")     // running
                }

                // Handle silent-e verbs: "giveth" → root "giv" → "give"
                // Already covered by root + "e" above

                return results
            }),

            // -est suffix (2nd person): "knowest" → root "know"
            ("est", { root in
                var results = [root]
                results.append(root + "s")
                results.append(root + "e")
                results.append(root + "es")
                results.append(root + "ed")

                // Handle doubled consonant
                if root.count >= 2 && root.last == root.dropLast().last {
                    let trimmed = String(root.dropLast())
                    results.append(trimmed)
                    results.append(trimmed + "s")
                }

                return results
            }),

            // -th suffix (shorter form): "doeth" handled by -eth above;
            // this catches "comth" style (rare) and words like "saith" → root "sai"
            // Only trigger if root is at least 3 chars to avoid false positives
            ("th", { root in
                guard root.count >= 3 else { return [] }
                var results = [root]
                results.append(root + "s")
                results.append(root + "e")
                results.append(root + "es")
                results.append(root + "d")
                results.append(root + "ed")

                // "saith" → root "sai" → "say" (vowel ending → y)
                if root.hasSuffix("i") || root.hasSuffix("ai") {
                    let yRoot = String(root.dropLast()) + "y"
                    results.append(yRoot)               // say
                    results.append(yRoot + "s")          // says
                }

                return results
            }),

            // -st suffix (2nd person short form): "canst" → root "can"
            ("st", { root in
                guard root.count >= 3 else { return [] }
                var results = [root]
                results.append(root + "s")
                return results
            }),
        ]

        for (suffix, adjustments) in suffixPatterns {
            if word.hasSuffix(suffix) {
                let root = String(word.dropLast(suffix.count))
                guard !root.isEmpty else { continue }
                let adjusted = adjustments(root)
                variants.formUnion(adjusted)
            }
        }

        return variants
    }

    /// Check if spoken word is a fuzzy match for the expected word.
    /// Uses Levenshtein edit distance with strict thresholds to avoid false positives.
    private func isFuzzyMatch(spoken: String, expected: String) -> Bool {
        // Only apply fuzzy matching for longer words where STT errors are more likely
        guard spoken.count >= 5, expected.count >= 7 else { return false }

        // Spoken word must be at least 75% of expected word's length
        guard Double(spoken.count) >= Double(expected.count) * 0.75 else { return false }

        let distance = Self.levenshteinDistance(spoken, expected)
        let maxLength = max(spoken.count, expected.count)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        // Require at least 75% similarity
        return similarity >= 0.75
    }

    /// Compute Levenshtein edit distance between two strings.
    /// O(n*m) time and O(min(n,m)) space - fine for word-length strings.
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let n = a.count
        let m = b.count

        if n == 0 { return m }
        if m == 0 { return n }

        // Use two rows instead of full matrix to save memory
        var previousRow = Array(0...m)
        var currentRow = Array(repeating: 0, count: m + 1)

        for i in 1...n {
            currentRow[0] = i
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                currentRow[j] = min(
                    currentRow[j - 1] + 1,      // insertion
                    previousRow[j] + 1,          // deletion
                    previousRow[j - 1] + cost    // substitution
                )
            }
            previousRow = currentRow
        }

        return previousRow[m]
    }
}
