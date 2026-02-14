import Foundation

/// Result of comparing a spoken word against the expected word
struct ComparisonResult {
    let isMatch: Bool
    let expectedWord: String
    let spokenWord: String
    let normalizedExpected: String
    let normalizedSpoken: String
    let position: Int
}

/// Options for word comparison behavior
struct ComparatorOptions {
    var caseSensitive: Bool = false
    var ignorePunctuation: Bool = true
    var ignoreFillerWords: Bool = true
    var allowContractions: Bool = true
    var requireCorrectWord: Bool = true  // Don't advance until correct word is spoken

    static let `default` = ComparatorOptions()
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
    private(set) var currentPosition: Int = 0
    private var options: ComparatorOptions

    // Compound word buffer - holds partial word when speech recognition splits a compound word
    private var compoundBuffer: String? = nil
    private var compoundBufferTimestamp: Date? = nil
    private static let compoundBufferTimeout: TimeInterval = 1.5 // seconds to wait for second part

    // Pre-computed for performance
    private static let fillerWords: Set<String> = ["um", "uh", "er", "ah", "like", "you", "know", "so", "well", "actually"]
    private static let punctuationCharacters = CharacterSet.punctuationCharacters

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
        ["thee", "the", "thy"],
        ["thou", "you", "tho"],
        ["thy", "thigh", "the"],
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

    init(options: ComparatorOptions = .default) {
        self.options = options
    }

    // MARK: - Public Methods

    /// Set the target text that the user is trying to recite
    func setTargetText(_ text: String) {
        targetWords = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        normalizedTargetWords = targetWords.map { normalize($0) }
        currentPosition = 0
    }

    /// Compare a spoken word against the expected word at current position
    /// Returns nil if the word is a filler word (should be ignored)
    func compareWord(_ spokenWord: String) -> ComparisonResult? {
        let normalizedSpoken = normalize(spokenWord)

        // Skip empty words
        guard !normalizedSpoken.isEmpty else {
            return nil
        }

        // Skip filler words
        if options.ignoreFillerWords && isFillerWord(normalizedSpoken) {
            return nil
        }

        // Check if we've reached the end
        guard currentPosition < targetWords.count else {
            compoundBuffer = nil
            compoundBufferTimestamp = nil
            return ComparisonResult(
                isMatch: false,
                expectedWord: "[END]",
                spokenWord: spokenWord,
                normalizedExpected: "",
                normalizedSpoken: normalizedSpoken,
                position: currentPosition
            )
        }

        let expectedWord = targetWords[currentPosition]
        let normalizedExpected = normalizedTargetWords[currentPosition]

        // --- Compound word handling ---

        // First, check if this word is a REVISION of the buffered word (speech recognizer
        // revised a partial word to a complete word). This happens when:
        // - We have "glor" buffered and receive "glorious"
        // - "glorious" starts with "glor" → this is a revision, not a second word
        // In this case, clear the buffer and process the new word as the complete word.
        if let buffered = compoundBuffer, normalizedSpoken.hasPrefix(buffered) && normalizedSpoken.count > buffered.count {
            // This is a revision of the partial word, not a new word to combine
            compoundBuffer = nil
            compoundBufferTimestamp = nil
            // Fall through to normal comparison with the revised (complete) word
        }

        // If we have a buffered partial word, try combining it with the new spoken word
        if let buffered = compoundBuffer {
            let combined = buffered + normalizedSpoken
            let combinedFull = buffered + spokenWord

            // Check if the combined word matches the expected word
            if checkMatch(spoken: combined, expected: normalizedExpected) {
                compoundBuffer = nil
                compoundBufferTimestamp = nil

                let result = ComparisonResult(
                    isMatch: true,
                    expectedWord: expectedWord,
                    spokenWord: combinedFull,
                    normalizedExpected: normalizedExpected,
                    normalizedSpoken: combined,
                    position: currentPosition
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
                    position: currentPosition
                )

                if !options.requireCorrectWord {
                    currentPosition += 1
                }

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

            // Combined doesn't match and isn't a prefix — the buffer was wrong
            compoundBuffer = nil
            compoundBufferTimestamp = nil

            let result = ComparisonResult(
                isMatch: false,
                expectedWord: expectedWord,
                spokenWord: buffered,
                normalizedExpected: normalizedExpected,
                normalizedSpoken: buffered,
                position: currentPosition
            )

            if !options.requireCorrectWord {
                currentPosition += 1
            }

            return result
        }

        // --- Normal (non-buffered) comparison ---

        // Check for direct match (including homophone and contraction handling)
        let isMatch = checkMatch(spoken: normalizedSpoken, expected: normalizedExpected)

        if isMatch {
            let result = ComparisonResult(
                isMatch: true,
                expectedWord: expectedWord,
                spokenWord: spokenWord,
                normalizedExpected: normalizedExpected,
                normalizedSpoken: normalizedSpoken,
                position: currentPosition
            )
            currentPosition += 1
            return result
        }

        // Not a direct match — check if this could be the start of a compound word.
        // If the expected word starts with the spoken word (or a homophone of it),
        // buffer the spoken word and wait for the next part.
        if isCompoundWordPrefix(spoken: normalizedSpoken, expected: normalizedExpected) {
            compoundBuffer = normalizedSpoken
            compoundBufferTimestamp = Date()
            return nil // Buffering — no result yet
        }

        // Definite mismatch
        let result = ComparisonResult(
            isMatch: false,
            expectedWord: expectedWord,
            spokenWord: spokenWord,
            normalizedExpected: normalizedExpected,
            normalizedSpoken: normalizedSpoken,
            position: currentPosition
        )

        if !options.requireCorrectWord {
            currentPosition += 1
        }

        return result
    }

    /// Update comparator options
    func updateOptions(_ options: ComparatorOptions) {
        self.options = options
    }

    /// Reset to start of text
    func reset() {
        currentPosition = 0
        compoundBuffer = nil
        compoundBufferTimestamp = nil
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

        if options.ignorePunctuation {
            result = result.unicodeScalars
                .filter { !Self.punctuationCharacters.contains($0) }
                .map { Character($0) }
                .reduce(into: "") { $0.append($1) }
        }

        if !options.caseSensitive {
            result = result.lowercased()
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
        // Only consider this if the expected word is meaningfully longer than spoken
        guard expected.count > spoken.count + 1 else { return false }

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

    /// Flush the compound buffer, returning a mismatch result if there was buffered content.
    /// Call this when you know the buffer can't complete (e.g., recognition ended).
    func flushCompoundBuffer() -> ComparisonResult? {
        guard let buffered = compoundBuffer else { return nil }
        compoundBuffer = nil
        compoundBufferTimestamp = nil

        guard currentPosition < targetWords.count else { return nil }

        let expectedWord = targetWords[currentPosition]
        let normalizedExpected = normalizedTargetWords[currentPosition]

        let result = ComparisonResult(
            isMatch: false,
            expectedWord: expectedWord,
            spokenWord: buffered,
            normalizedExpected: normalizedExpected,
            normalizedSpoken: buffered,
            position: currentPosition
        )

        if !options.requireCorrectWord {
            currentPosition += 1
        }

        return result
    }

    /// Check if spoken word matches expected word (handles contractions and homophones)
    private func checkMatch(spoken: String, expected: String) -> Bool {
        // Direct match
        if spoken == expected {
            return true
        }

        // Check homophones
        if let homophoneGroup = Self.homophoneLookup[expected],
           homophoneGroup.contains(spoken) {
            return true
        }

        // Check contractions (both directions)
        if options.allowContractions {
            // Check if spoken is a contraction of expected
            if let expandedForm = Self.reverseContractionMap[spoken] {
                // Split expanded form and check if it starts with expected
                let expandedWords = expandedForm.split(separator: " ").map(String.init)
                if expandedWords.first == expected {
                    return true
                }
            }

            // Check if expected is a contraction of spoken
            if let expandedForm = Self.reverseContractionMap[expected] {
                let expandedWords = expandedForm.split(separator: " ").map(String.init)
                if expandedWords.first == spoken {
                    return true
                }
            }

            // Check contracted forms
            if let contractions = Self.contractionMap[expected], contractions.contains(spoken) {
                return true
            }
            if let contractions = Self.contractionMap[spoken], contractions.contains(expected) {
                return true
            }
        }

        return false
    }
}
