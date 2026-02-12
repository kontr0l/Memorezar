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
    private static let homophones: [[String]] = [
        ["their", "there", "they're", "theyre"],
        ["your", "you're", "youre"],
        ["its", "it's"],
        ["to", "too", "two"],
        ["hear", "here"],
        ["no", "know"],
        ["knew", "new"],
        ["right", "write"],
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

        // Check for match (including homophone and contraction handling)
        let isMatch = checkMatch(spoken: normalizedSpoken, expected: normalizedExpected)

        let result = ComparisonResult(
            isMatch: isMatch,
            expectedWord: expectedWord,
            spokenWord: spokenWord,
            normalizedExpected: normalizedExpected,
            normalizedSpoken: normalizedSpoken,
            position: currentPosition
        )

        // Advance position regardless of match
        currentPosition += 1

        return result
    }

    /// Reset to start of text
    func reset() {
        currentPosition = 0
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
