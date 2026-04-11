import Foundation
import SwiftUI
import Combine

/// State of a word in the display
enum WordState {
    case pending    // Not yet reached
    case current    // Current word being spoken
    case correct    // Correctly spoken
    case incorrect  // Mistake
}

/// Word with its display state
struct WordDisplayState: Identifiable {
    let id = UUID()
    let word: String
    var state: WordState
    var isRevealed: Bool = false  // For partial reveal mode - whether this word is pre-revealed
}

/// Saved state for one chunk when using inline split
struct ChunkState {
    let chunkText: String
    var words: [WordDisplayState]
    var currentPosition: Int
    var mistakes: [PracticeMistake]
    var hintCount: Int
    var mcChoices: [String]
    var mcCorrectIndex: Int
    var showHint: Bool
    var revealPercentage: Double
    var previousWordWasMistake: Bool
}

/// ViewModel for RecitationScreen
/// Coordinates speech recognition, word comparison, and alerts
@MainActor
final class RecitationViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var words: [WordDisplayState] = []
    @Published var currentPosition: Int = 0
    @Published var isListening = false
    @Published var showPermissionAlert = false
    @Published var audioSessionFailed = false
    @Published var showMistakeFlash = false
    @Published var showResults = false
    @Published var showHint = false
    @Published var tappedMistakeIndex: Int?  // Word index of tapped incorrect word
    @Published var showAllWords = false  // Manual override to show all words
    @Published var revealPercentage: Double = 0  // Percentage of words to randomly reveal (0-100)
    @Published var letterRevealStep: Int = 1  // 0=hidden, 1-5=number of letters revealed
    @Published var displayLevel: Int = 1  // Current slider level (not persisted until advancement)
    var tutorialRevealActive = false  // When true, forced tutorial word reveal is in effect
    var isTutorialMode = false  // Set once at init, never cleared — used for reveal calculations
    @Published var isFirstLetterToggle: Bool = false  // Toggle between word-hide and letter-hide in voice/typing modes
    @Published var currentMode: MemorizationMode = .voice
    @Published var typingInput: String = ""  // Current typing input for typing mode
    @Published var hintCount: Int = 0
    @Published var audioLevel: Float = 0
    @Published var showPauseIcon: Bool = false
    private var silenceTimer: Timer?
    private var wordActivityTimer: Timer?

    // Multiple Choice mode
    @Published var mcChoices: [String] = []
    @Published var mcCorrectIndex: Int = 0
    @Published var mcWrongIndex: Int? = nil

    // Master mode — 3 consecutive 95%+ at 0% reveal to earn Mastered badge
    @Published var isMasterMode: Bool = false
    @Published var showMasterModeHintBlock: Bool = false  // Popup when tapping word in master mode

    // Tap-to-flash hint
    @Published var flashingWordIndex: Int? = nil
    private var flashTimer: Timer?

    // Language switching
    @Published var activeLanguage: String? = nil  // nil = original language

    // Inline split
    @Published var splitChunks: [ChunkState]? = nil  // nil = not split
    @Published var activeChunkIndex: Int = 0
    @Published var showSplitPopup: Bool = false
    @Published var splitCount: Int = 3

    var isSplit: Bool { splitChunks != nil }

    // MARK: - Language Properties

    /// The text for the currently active language (original or translation)
    var activeText: String {
        guard let lang = activeLanguage,
              let translated = quote.translations?[lang] else {
            return quote.text
        }
        return translated.text
    }

    /// The title for the currently active language
    var activeTitle: String {
        guard let lang = activeLanguage,
              let translated = quote.translations?[lang] else {
            return quote.title
        }
        return translated.title
    }

    /// Whether this quote has any translations available
    var hasTranslations: Bool {
        guard let translations = quote.translations else { return false }
        return !translations.isEmpty
    }

    /// The language code of the quote's primary (title/text) language
    var primaryLanguageCode: String {
        quote.primaryLanguage ?? "en"
    }

    /// Available language codes (excluding original)
    var availableLanguages: [String] {
        guard let translations = quote.translations else { return [] }
        return Array(translations.keys).sorted()
    }

    /// Hash of the active text for recording lookups
    var activeTextHash: String {
        RecordingService.shared.hashQuoteText(activeText)
    }

    // MARK: - Computed Properties

    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentPosition) / Double(words.count)
    }

    /// Whether the current mode tests every word (including visible ones).
    /// Case 1: voice (normal + first letter), typing with first letter — all words tested
    /// Case 2: normal typing, multiple choice — only hidden words tested
    var testsAllWords: Bool {
        if currentMode == .voice { return true }
        if currentMode == .typing && isFirstLetterToggle { return true }
        return false
    }

    var correctCount: Int {
        if testsAllWords {
            return words.filter { $0.state == .correct }.count
        }
        return words.filter { $0.state == .correct && !$0.isRevealed }.count
    }

    var mistakeCount: Int {
        mistakes.count
    }

    /// Number of words the user actually has to recite in this session
    var testedWordCount: Int {
        if testsAllWords { return words.count }
        if revealPercentage >= 100 { return 0 }
        return words.filter { !$0.isRevealed }.count
    }

    /// Number of hidden words (for reveal slider logic, not accuracy)
    var hiddenWordCount: Int {
        if revealPercentage >= 100 { return 0 }
        return words.filter { !$0.isRevealed }.count
    }

    /// In master mode, checks whether 95% accuracy is still achievable.
    var masterModeCanStillPass: Bool {
        guard isMasterMode else { return true }
        if isSplit {
            let maxAllowed = Int(Double(masterModeTotalTested) * 0.05)
            return masterModeTotalMistakes <= maxAllowed
        }
        let tested = testedWordCount
        let maxAllowedMistakes = Int(Double(tested) * 0.05)
        return mistakeCount <= maxAllowedMistakes
    }

    /// Total words tested across all chunks (for master mode aggregate)
    var masterModeTotalTested: Int {
        guard let chunks = splitChunks else {
            return testedWordCount
        }
        var total = 0
        for (i, chunk) in chunks.enumerated() {
            if i == activeChunkIndex {
                total += testedWordCount
            } else {
                total += chunk.words.count
            }
        }
        return total
    }

    /// Total mistakes across all chunks (for master mode aggregate)
    var masterModeTotalMistakes: Int {
        guard let chunks = splitChunks else {
            return mistakeCount
        }
        var total = 0
        for (i, chunk) in chunks.enumerated() {
            if i == activeChunkIndex {
                total += mistakeCount
            } else {
                total += chunk.mistakes.count
            }
        }
        return total
    }

    var hintWord: String? {
        guard currentPosition < words.count else { return nil }
        return words[currentPosition].word
    }

    /// What the app heard for the tapped incorrect word
    var tappedMistakeSpoken: String? {
        guard let index = tappedMistakeIndex else { return nil }
        return mistakes.last(where: { $0.position == index })?.spokenWord
    }


    // MARK: - Private Properties

    private(set) var quote: Quote
    private let speechService = SpeechRecognitionService()
    private let comparator: WordComparator
    private var mistakes: [PracticeMistake] = []
    private var sessionStartTime: Date?
    private var previousWordWasMistake = false  // Track for correct word sound after recovery

    // Pending mismatch - defer alerts to allow speech recognizer revisions to settle
    // When a mismatch occurs, we wait before alerting in case the word is still being refined
    // Settle interval scales with expected word length (long words take longer to resolve)
    private var pendingMismatchResult: ComparisonResult?
    private var pendingMismatchTimer: Timer?
    private var consecutiveMismatchesAtPosition = 0  // Track repeated mismatches at same position
    private var lastMismatchPosition = -1
    private static let minSettleInterval: TimeInterval = 0.40  // 400ms - gives STT time to revise short words
    private static let maxSettleInterval: TimeInterval = 1.50  // 1.5s absolute cap

    /// Adaptive settle interval based on expected word length, consecutive mismatches, AND confidence.
    /// Short words resolve quickly in STT; long words like "juxtaposition" need more time.
    /// When the STT produces multiple wrong guesses at the same position, it's struggling
    /// with the section — each consecutive mismatch adds 300ms to let it settle.
    /// Low confidence scores add extra settle time to let the ASR revise.
    private func settleInterval(for result: ComparisonResult) -> TimeInterval {
        let charCount = Double(result.normalizedExpected.count)
        // Base: 400ms + 60ms per character beyond 4
        let baseInterval = max(Self.minSettleInterval, Self.minSettleInterval + (charCount - 4) * 0.06)
        // Extra: 300ms per consecutive mismatch at same position (2nd mismatch adds 300ms, 3rd adds 600ms, etc.)
        let consecutiveExtra = Double(max(0, consecutiveMismatchesAtPosition - 1)) * 0.30
        // Confidence-based extension (only when real confidence is available):
        // 0.0 = unknown (interim results always report 0.0) — no extra, use base timing
        // Low (<0.5): +200ms to let STT revise
        // Medium (0.5-0.85): +200ms
        // High (>=0.85): no extra
        let confidenceExtra: Double
        if result.confidence == 0.0 {
            confidenceExtra = 0.0   // Unknown/interim — don't penalize
        } else if result.confidence < 0.85 {
            confidenceExtra = 0.20  // Low/medium confidence — let STT revise
        } else {
            confidenceExtra = 0.0   // High confidence — fire promptly
        }
        return min(baseInterval + consecutiveExtra + confidenceExtra, Self.maxSettleInterval)
    }

    var settingsStore: SettingsStore?
    var userEquivalencesStore: UserEquivalencesStore?
    var quoteStore: QuoteStore?

    // MARK: - Initialization

    init(quote: Quote) {
        self.quote = quote
        self.comparator = WordComparator()

        super.init()

        setupQuote()
        setupAlertManager()
        speechService.delegate = self
        speechService.audioLevelCallback = { [weak self] level in
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
    }

    // MARK: - Setup

    private func setupQuote() {
        comparator.setTargetText(activeText, language: activeLanguage)
        let targetWords = comparator.getTargetWords()

        words = targetWords.map {
            WordDisplayState(word: $0, state: .pending, isRevealed: false)
        }

        // Mark first word as current
        if !words.isEmpty {
            words[0].state = .current
        }

        // Mastered quotes always load at hardest level
        if quote.masteryStreak >= 3 && quote.revealLevel < 3 {
            quote.revealLevel = 3
            quoteStore?.updateQuote(quote)
        }

        // Apply reveal based on the quote's current level
        applyLevelReveal()
    }

    /// Set the reveal level (1-3) temporarily for this session without persisting.
    /// The level is only saved when the user completes a session and meets the advancement threshold.
    func setLevel(_ newLevel: Int) {
        let wasTutorialReveal = tutorialRevealActive
        tutorialRevealActive = false
        displayLevel = newLevel
        applyLevelRevealForLevel(newLevel)
    }

    /// Apply reveal percentage and letter step for a specific level (without persisting)
    private func applyLevelRevealForLevel(_ level: Int) {
        switch level {
        case 2:
            revealPercentage = 50
            letterRevealStep = 2
        case 3:
            revealPercentage = 20
            letterRevealStep = 1
        default:
            revealPercentage = 90
            letterRevealStep = 3
        }
        applyRevealPercentage()
    }

    /// Apply reveal percentage and letter step from the quote's current level
    private func applyLevelReveal() {
        displayLevel = max(1, quote.revealLevel)
        revealPercentage = quote.revealPercentageForLevel
        letterRevealStep = quote.letterStepForLevel
        applyRevealPercentage()
    }

    /// Determine the level the user effectively achieved based on the reveal they used.
    /// E.g., if they manually slid to 60% and got 90%+ accuracy, they beat the 50% step (level 2).
    static func levelAchieved(atRevealPercentage reveal: Double) -> Int {
        if reveal <= 30 { return 3 }       // 20% level or harder
        if reveal <= 70 { return 2 }       // 50% level or harder
        return 1                            // 90% level
    }

    /// Check if the user should advance to the next level and update the quote.
    /// Called after session completion. Returns the new level if changed (advanced or demoted), nil otherwise.
    @discardableResult
    func checkLevelAdvancement(accuracy: Double) -> Int? {
        let currentLevel = max(1, quote.revealLevel)  // treat 0 as 1

        // Demote on failure: drop back one level if accuracy < 70%
        if accuracy < 0.70 && currentLevel > 1 {
            let newLevel = currentLevel - 1
            quote.revealLevel = newLevel
            quoteStore?.updateQuote(quote)
            return newLevel
        }

        guard accuracy >= 0.90 else { return nil }
        guard currentLevel < 3 else { return nil }

        // Determine what level they actually achieved based on the reveal they used
        let achieved = Self.levelAchieved(atRevealPercentage: revealPercentage)

        // They must have achieved at least their current level to advance
        guard achieved >= currentLevel else { return nil }

        let newLevel = min(3, achieved + 1)
        guard newLevel > currentLevel else { return nil }

        quote.revealLevel = newLevel
        quoteStore?.updateQuote(quote)
        return newLevel
    }

    /// Force specific words to be revealed by index (for tutorial mode)
    func applyTutorialReveal(revealedIndices: Set<Int>) {
        tutorialRevealActive = true
        for i in words.indices {
            words[i].isRevealed = revealedIndices.contains(i)
        }
    }

    /// Apply the current reveal percentage with truly random word selection
    func applyRevealPercentage() {
        // In tutorial mode, include all words so percentages work with small word counts
        let pendingIndices: [Int]
        if isTutorialMode {
            pendingIndices = words.indices.map { $0 }
        } else {
            // Only reveal pending words (not current or already spoken words)
            pendingIndices = words.enumerated()
                .filter { $0.offset > currentPosition && $0.element.state == .pending }
                .map { $0.offset }
        }

        guard !pendingIndices.isEmpty else {
            // No pending words to reveal
            return
        }

        let percentage = revealPercentage / 100.0
        let revealCount = Int(Double(pendingIndices.count) * percentage)

        // First, hide all pending words
        for index in pendingIndices {
            words[index].isRevealed = false
        }

        // Randomly select words to reveal (truly random selection)
        if revealCount > 0 {
            // Shuffle the indices and take the first N
            let shuffledIndices = pendingIndices.shuffled()
            let indicesToReveal = shuffledIndices.prefix(revealCount)

            for index in indicesToReveal {
                words[index].isRevealed = true
            }
        }
    }

    /// Toggle showing all words
    func toggleShowAllWords() {
        showAllWords.toggle()
    }

    // MARK: - Mode Management

    /// Set up mode from settings (call after settingsStore is assigned).
    /// Returns true if audio/playback mode should be activated (handled by RecitationScreen).
    @discardableResult
    func applyDefaultMode() -> Bool {
        guard let settings = settingsStore else { return false }
        let mode = settings.defaultMemorizationMode
        // Audio mode is handled as playback mode by RecitationScreen
        if mode == .audio { return true }
        switchMode(to: mode)
        // Initialize session start time for MC mode (no speech trigger)
        if mode == .multipleChoice {
            sessionStartTime = sessionStartTime ?? Date()
        }
        // Apply first letter mode setting for voice/typing (no animation)
        if settings.firstLetterModeEnabled && (mode == .voice || mode == .typing) {
            if !isFirstLetterToggle {
                isFirstLetterToggle = true
                applyLevelRevealForLevel(displayLevel)
            }
        }
        return false
    }

    /// Switch to a new memorization mode
    /// Toggle first-letter mode, converting the slider value proportionally so the
    /// thumb stays in roughly the same position.
    /// - revealPercentage 0-100 ↔ letterRevealStep 0-5
    func toggleFirstLetterMode() {
        isFirstLetterToggle.toggle()
        // Re-apply using the current display level (not the saved level)
        applyLevelRevealForLevel(displayLevel)
    }

    func switchMode(to newMode: MemorizationMode) {
        let oldMode = currentMode
        guard newMode != oldMode else { return }

        // Exit master mode when switching modes
        if isMasterMode {
            exitMasterMode()
        }

        // Pause speech if leaving voice mode
        if oldMode == .voice && isListening {
            pause()
        }

        // Clear typing input when leaving typing mode
        if oldMode == .typing {
            typingInput = ""
        }

        // Restore .current marker when switching modes
        if currentPosition < words.count && words[currentPosition].state != .current {
            words[currentPosition].state = .current
        }

        // When leaving voice with first-letter on, sync revealPercentage from letterStep
        // so typing mode's word-reveal slider reflects the same position
        if oldMode == .voice && isFirstLetterToggle {
            revealPercentage = Double(letterRevealStep) / 5.0 * 100.0
            applyRevealPercentage()
        }

        currentMode = newMode

        // Reset first-letter toggle for modes that don't support it
        if newMode != .voice && newMode != .typing {
            isFirstLetterToggle = false
        }

        // Generate choices when entering MC mode
        if newMode == .multipleChoice {
            generateChoices()
            sessionStartTime = sessionStartTime ?? Date()
        }

        // Skip to next hidden word when entering typing mode
        if newMode == .typing {
            skipToNextHiddenWord()
            sessionStartTime = sessionStartTime ?? Date()
        }
    }

    // MARK: - Typing Mode

    /// Submit a typed word (or first letter in first-letter toggle mode) and compare against expected
    func submitTypingInput() {
        let typed = typingInput.trimmingCharacters(in: .whitespacesAndNewlines)
        typingInput = ""
        guard !typed.isEmpty else { return }
        guard currentPosition < words.count else { return }

        // Start session timer if not started
        sessionStartTime = sessionStartTime ?? Date()

        let expected = words[currentPosition].word

        if isFirstLetterToggle {
            // First letter mode: compare just the first letter
            let typedChar = typed.lowercased().first
            let expectedChar = expected.lowercased().trimmingCharacters(in: .punctuationCharacters).first

            if typedChar == expectedChar {
                words[currentPosition].state = .correct
                if previousWordWasMistake {
                    AlertManager.shared.triggerCorrectWordSound()
                    previousWordWasMistake = false
                }
                showHint = false
                currentPosition += 1
                comparator.setPosition(currentPosition)

                // In first-letter typing mode, advance through ALL words (don't skip visible ones)
                if currentPosition < words.count {
                    words[currentPosition].state = .current
                }

                if currentPosition >= words.count {
                    handleCompletion()
                    return
                }
            } else {
                let mistake = PracticeMistake(
                    position: currentPosition,
                    expectedWord: expected,
                    spokenWord: typed,
                    timestamp: Date(),
                    confidence: 1.0,
                    certainty: .definite
                )
                mistakes.append(mistake)
                AlertManager.shared.triggerMistakeAlert(audioPauseHandler: audioPauseHandler)
                previousWordWasMistake = true
                words[currentPosition].state = .incorrect

                if !masterModeCanStillPass {
                    handleCompletion()
                    return
                }

                // Advance past the wrong word
                currentPosition += 1
                comparator.setPosition(currentPosition)
                if currentPosition < words.count {
                    words[currentPosition].state = .current
                }
                if currentPosition >= words.count {
                    handleCompletion()
                    return
                }
            }
        } else {
            // Normal typing mode: compare full word
            let normalizedTyped = typed.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let normalizedExpected = expected.lowercased().trimmingCharacters(in: .punctuationCharacters)

            if normalizedTyped == normalizedExpected {
                words[currentPosition].state = .correct
                if previousWordWasMistake {
                    AlertManager.shared.triggerCorrectWordSound()
                    previousWordWasMistake = false
                }
                showHint = false
                currentPosition += 1
                comparator.setPosition(currentPosition)

                // Skip past revealed words to next hidden word
                skipToNextHiddenWord()

                if currentPosition >= words.count {
                    handleCompletion()
                    return
                }
            } else {
                let mistake = PracticeMistake(
                    position: currentPosition,
                    expectedWord: expected,
                    spokenWord: typed,
                    timestamp: Date(),
                    confidence: 1.0,
                    certainty: .definite
                )
                mistakes.append(mistake)
                AlertManager.shared.triggerMistakeAlert(audioPauseHandler: audioPauseHandler)
                previousWordWasMistake = true
                words[currentPosition].state = .incorrect

                if !masterModeCanStillPass {
                    handleCompletion()
                    return
                }

                // Advance past the wrong word
                currentPosition += 1
                comparator.setPosition(currentPosition)
                skipToNextHiddenWord()
                if currentPosition >= words.count {
                    handleCompletion()
                    return
                }
            }
        }
    }

    // MARK: - Language Switching

    /// Switch to a different language (nil = original)
    func switchLanguage(_ language: String?) {
        guard language != activeLanguage else { return }

        // Stop listening
        if isListening { pause() }

        // Remove split — chunks are language-specific
        if isSplit {
            splitChunks = nil
            activeChunkIndex = 0
        }

        activeLanguage = language

        // Reconfigure speech recognizer locale
        let localeId = SpeechRecognitionService.speechLocaleIdentifier(for: language)
        speechService.reconfigureLocale(localeId)

        // Reconfigure comparator
        comparator.setTargetText(activeText, language: language)

        // Reset state
        let targetWords = comparator.getTargetWords()
        words = targetWords.map { WordDisplayState(word: $0, state: .pending, isRevealed: false) }
        if !words.isEmpty { words[0].state = .current }
        currentPosition = 0
        mistakes.removeAll()
        sessionStartTime = nil
        tappedMistakeIndex = nil
        showHint = false
        showResults = false
        previousWordWasMistake = false
        hintCount = 0

        applyLevelReveal()

        if currentMode == .multipleChoice { generateChoices() }
    }

    // MARK: - Master Mode

    func enterMasterMode() {
        isMasterMode = true
        isFirstLetterToggle = false
        // For split quotes, start from the first chunk
        if isSplit, let chunks = splitChunks, !chunks.isEmpty {
            switchToChunk(0)
        }
        reset()
        revealPercentage = 0
        letterRevealStep = 0
        applyRevealPercentage()
    }

    func exitMasterMode() {
        isMasterMode = false
        applyLevelReveal()
    }

    /// Record a mastery challenge result. Returns the updated streak count.
    func recordMasteryResult(passed: Bool) {
        guard let store = quoteStore else { return }
        if var updated = store.getQuote(byId: quote.id) {
            if passed {
                updated.masteryStreak = min(3, updated.masteryStreak + 1)
            } else {
                // If already mastered (streak >= 3), demote on failure
                if updated.masteryStreak >= 3 {
                    updated.masteryStreak = 0
                } else {
                    updated.masteryStreak = 0
                }
            }
            store.updateQuote(updated)
            quote = updated
        }
    }

    // MARK: - Multiple Choice

    /// In MC mode, advance past revealed/visible words to the next hidden word.
    /// Does NOT mark skipped words as correct — they stay pending (just visible).
    private func skipToNextHiddenWord() {
        // Clear .current from the old position before skipping
        if currentPosition < words.count && words[currentPosition].state == .current {
            words[currentPosition].state = .pending
        }

        while currentPosition < words.count {
            let ws = words[currentPosition]
            // Already spoken words — skip past
            if ws.state == .correct || ws.state == .incorrect {
                currentPosition += 1
                comparator.setPosition(currentPosition)
                continue
            }
            // Revealed by slider — skip (don't mark correct)
            if ws.isRevealed || revealPercentage >= 100 {
                // Leave state as .pending, just move past
                currentPosition += 1
                comparator.setPosition(currentPosition)
                continue
            }
            // Found a hidden word — stop here
            break
        }
        if currentPosition < words.count {
            words[currentPosition].state = .current
        }
    }

    /// Generate 4 word options for the current position (1 correct + 3 decoys)
    func generateChoices() {
        // Skip to the next hidden word
        skipToNextHiddenWord()

        guard currentPosition < words.count else {
            mcChoices = []
            return
        }

        let correctWord = words[currentPosition].word

        // Gather unique decoy words from other positions in the quote
        var decoys: [String] = []
        var usedWords: Set<String> = [correctWord.lowercased()]

        // Collect candidate positions (all words except current)
        var candidateIndices = Array(words.indices)
        candidateIndices.removeAll { $0 == currentPosition }
        candidateIndices.shuffle()

        for idx in candidateIndices {
            let candidate = words[idx].word
            let key = candidate.lowercased()
            if !usedWords.contains(key) {
                usedWords.insert(key)
                decoys.append(candidate)
            }
            if decoys.count >= 3 { break }
        }

        // If not enough unique words in the quote, pad with placeholders
        let fallbacks = ["and", "the", "but", "for"]
        for fb in fallbacks where decoys.count < 3 {
            let key = fb.lowercased()
            if !usedWords.contains(key) {
                usedWords.insert(key)
                decoys.append(fb)
            }
        }

        // Combine and shuffle
        var options = [correctWord] + decoys.prefix(3)
        options.shuffle()

        mcChoices = options
        mcCorrectIndex = options.firstIndex(of: correctWord) ?? 0
    }

    /// Handle user tapping a choice in multiple choice mode
    func selectChoice(at index: Int) {
        guard index < mcChoices.count else { return }

        if index == mcCorrectIndex {
            // Correct — mark word green and advance
            if currentPosition < words.count {
                words[currentPosition].state = .correct
            }
            if previousWordWasMistake {
                AlertManager.shared.triggerCorrectWordSound()
                previousWordWasMistake = false
            }
            currentPosition += 1
            comparator.setPosition(currentPosition)

            // Skip past revealed words to next hidden word, then generate choices
            skipToNextHiddenWord()

            if currentPosition >= words.count {
                handleCompletion()
                return
            }

            generateChoices()
        } else {
            // Wrong — record mistake, mark word red, advance
            let mistake = PracticeMistake(
                position: currentPosition,
                expectedWord: words[currentPosition].word,
                spokenWord: mcChoices[index],
                timestamp: Date(),
                confidence: 1.0,
                certainty: .definite
            )
            mistakes.append(mistake)
            AlertManager.shared.triggerMistakeAlert(audioPauseHandler: audioPauseHandler)
            previousWordWasMistake = true

            if currentPosition < words.count {
                words[currentPosition].state = .incorrect
            }

            mcWrongIndex = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.mcWrongIndex = nil
            }

            // Early fail in master mode if 95% is no longer reachable
            if !masterModeCanStillPass {
                handleCompletion()
                return
            }

            // Advance past the wrong word
            currentPosition += 1
            comparator.setPosition(currentPosition)
            skipToNextHiddenWord()

            if currentPosition >= words.count {
                handleCompletion()
                return
            }

            generateChoices()
        }
    }

    // MARK: - Tap-to-Flash Hint

    /// Tap a word to temporarily flash it as a hint (yellow background, show word for ~2s)
    /// Does NOT move the cursor — just peeks at the word and increments hint count.
    func tapWord(at index: Int, countAsHint: Bool = true) {
        guard index < words.count else { return }

        let state = words[index].state

        // Tap on incorrect word — show dispute popup
        if state == .incorrect {
            guard tappedMistakeIndex == nil else { return }
            pause()
            tappedMistakeIndex = index
            return
        }

        // Only flash pending/current words (already spoken words are visible)
        guard tappedMistakeIndex == nil else { return }
        guard state == .pending || state == .current else { return }

        // Master mode: block all hints
        if isMasterMode {
            showMasterModeHintBlock = true
            return
        }

        if countAsHint { hintCount += 1 }
        withAnimation(.easeIn(duration: 0.2)) {
            flashingWordIndex = index
        }

        // Clear flash after 1 second with fade out
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 1.2)) {
                    self?.flashingWordIndex = nil
                }
            }
        }
    }

    /// Whether a word at the given index should have a tap handler (hint or dispute)
    func isWordTappable(at index: Int) -> Bool {
        let state = words[index].state
        // Mistake words are always tappable (for dispute)
        if state == .incorrect { return true }
        // Already spoken correct words are not tappable
        if state == .correct { return false }
        // Currently showing full via hint/flash — not tappable
        if (showHint && index == currentPosition) || flashingWordIndex == index { return false }
        // First letter toggle in typing mode uses word-level visibility (same as normal modes)
        if isFirstLetterToggle && currentMode == .typing {
            if words[index].isRevealed { return false }
            return !shouldShowWord(at: index)
        }
        // First letter mode / first letter toggle in voice mode — letter-based hiding
        if currentMode == .firstLetter || (isFirstLetterToggle && currentMode == .voice) {
            // All letters already visible (e.g. "of" with step 5) — not tappable
            if letterRevealStep > 0 && words[index].word.count <= letterRevealStep { return false }
            // Still has hidden letters — tappable
            return true
        }
        // Other modes: pre-revealed words are fully visible — not tappable
        if words[index].isRevealed { return false }
        // Tappable if the word is hidden
        return !shouldShowWord(at: index)
    }

    // MARK: - Word Display Mode

    /// Determine how a word at the given index should be rendered
    func wordDisplayMode(at index: Int) -> WordDisplayMode {
        let wordState = words[index]

        // Already spoken words always show fully
        if wordState.state == .correct || wordState.state == .incorrect {
            return .full
        }

        // Show all words override
        if showAllWords {
            return .full
        }

        // First letter toggle in typing mode — use normal reveal slider for word visibility
        if isFirstLetterToggle && currentMode == .typing {
            if (showHint && index == currentPosition) || flashingWordIndex == index {
                return .full
            }
            return shouldShowWord(at: index) ? .full : .hidden
        }

        // First letter toggle in voice mode — ALL words get letter-hiding via stepped slider
        if isFirstLetterToggle && currentMode == .voice {
            if (showHint && index == currentPosition) || flashingWordIndex == index {
                return .full
            }
            if letterRevealStep == 0 {
                return .hidden
            } else {
                return .letters(letterRevealStep)
            }
        }

        switch currentMode {
        case .firstLetter:
            // Hint on current word or tapped word reveals fully
            if (showHint && index == currentPosition) || flashingWordIndex == index {
                return .full
            }
            // Smooth slider: 0=hidden box, 1-5=number of letters
            if letterRevealStep == 0 {
                return .hidden
            } else {
                return .letters(letterRevealStep)
            }

        case .voice, .typing, .multipleChoice, .audio:
            // Flashing hint reveals the word fully
            if flashingWordIndex == index { return .full }
            return shouldShowWord(at: index) ? .full : .hidden
        }
    }

    /// Check if a word should be visible
    func shouldShowWord(at index: Int) -> Bool {
        // Manual override to show all words
        if showAllWords { return true }

        let wordState = words[index]

        // Correctly spoken words are always visible
        if wordState.state == .correct {
            return true
        }

        // Incorrect words always visible (shown in red, user can tap to dispute)
        if wordState.state == .incorrect { return true }

        // Current word is only visible if hint is active, pre-revealed, or slider is at 100%
        if wordState.state == .current {
            return showHint || wordState.isRevealed || revealPercentage >= 100
        }

        // For pending words, the slider controls visibility
        // When slider is at 0%, hide all pending words
        // When slider is > 0%, show only revealed words
        if revealPercentage > 0 {
            return wordState.isRevealed
        }

        // revealPercentage is 0 - hide all pending words
        return false
    }

    private func setupAlertManager() {
        AlertManager.shared.onVisualAlert = { [weak self] in
            self?.triggerVisualFlash()
        }
    }

    /// Pause/resume handler passed to AlertManager so haptics can fire during recording
    private var audioPauseHandler: (pause: () -> Void, resume: () -> Void) {
        (
            pause: { [weak self] in self?.speechService.pauseAudioEngine() },
            resume: { [weak self] in
                guard let self, self.isListening else { return }
                self.speechService.resumeAudioEngine()
            }
        )
    }


    // MARK: - Permissions

    func requestPermissions() {
        SpeechRecognitionService.requestAuthorization { [weak self] authorized in
            if !authorized {
                self?.showPermissionAlert = true
            }
        }
    }

    // MARK: - Control

    func start() {
        guard !isListening else { return }

        // Apply user-defined word equivalences
        comparator.setUserEquivalences(userEquivalencesStore?.equivalences ?? [:])

        // Fetch community equivalences in background (fire-and-forget, non-blocking)
        let quoteWords = comparator.getTargetWords()
        Task {
            let community = await EquivalenceService.shared.fetchEquivalences(forWords: quoteWords)
            comparator.setCommunityEquivalences(community)
        }

        do {
            // Pass target text words as contextual strings so the recognizer
            // knows to look for uncommon/archaic words (e.g., "thine", "encircles")
            let targetWords = comparator.getTargetWords()
            try speechService.startListening(contextualStrings: targetWords)
            isListening = true
            sessionStartTime = sessionStartTime ?? Date()
            resetWordActivityTimer()
        } catch {
            print("Failed to start listening: \(error)")
            audioSessionFailed = true
        }
    }

    func pause() {
        // Set isListening to false BEFORE stopping speech service
        // This ensures any pending speech callbacks will be ignored
        isListening = false
        audioLevel = 0
        showPauseIcon = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        wordActivityTimer?.invalidate()
        wordActivityTimer = nil
        cancelPendingMismatch()
        speechService.stopListening()
    }

    func stop() {
        pause()
        speechService.deactivateAudioSession()
    }

    /// Resets the word activity timer — shows pause icon after 2s of no recognized words
    private func resetWordActivityTimer() {
        wordActivityTimer?.invalidate()
        if showPauseIcon {
            showPauseIcon = false
        }
        wordActivityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.isListening else { return }
                self.showPauseIcon = true
            }
        }
    }

    /// Reset the current recitation.
    /// - Parameter recalculateReveal: When true (e.g. "Try Again" after a recorded session),
    ///   refreshes the quote from the store and recalculates the reveal slider based on
    ///   updated practice stats. When false (footer reset button), keeps the current slider.
    func reset(recalculateReveal: Bool = false) {
        stop()

        if isSplit {
            if recalculateReveal, let updated = quoteStore?.getQuote(byId: quote.id) {
                quote = updated
            }

            // Only reset the active chunk
            comparator.setTargetText(splitChunks![activeChunkIndex].chunkText)
            comparator.reset()

            let targetWords = comparator.getTargetWords()
            words = targetWords.map { WordDisplayState(word: $0, state: .pending) }
            if !words.isEmpty { words[0].state = .current }
            currentPosition = 0
            mistakes.removeAll()
            tappedMistakeIndex = nil
            showHint = false
            showResults = false
            previousWordWasMistake = false
            hintCount = 0

            if recalculateReveal {
                revealPercentage = quote.revealPercentageForLevel
                letterRevealStep = quote.letterStepForLevel
            }
            if revealPercentage > 0 { applyRevealPercentage() }
            if currentMode == .multipleChoice { generateChoices() }

            // Save reset state back to chunk array
            saveCurrentChunkState()
        } else {
            if recalculateReveal, let updated = quoteStore?.getQuote(byId: quote.id) {
                quote = updated
            }

            comparator.reset()
            mistakes.removeAll()
            sessionStartTime = nil
            tappedMistakeIndex = nil
            showHint = false
            showResults = false
            previousWordWasMistake = false
            hintCount = 0

            for i in words.indices {
                words[i].state = i == 0 ? .current : .pending
                words[i].isRevealed = false
            }
            currentPosition = 0

            if recalculateReveal {
                applyLevelReveal()
            } else {
                if revealPercentage > 0 { applyRevealPercentage() }
            }
            if currentMode == .multipleChoice { generateChoices() }
        }
    }

    // MARK: - Inline Split

    /// Split the quote into N chunks for section-by-section practice
    func split(into count: Int) {
        stop()

        let chunkTexts = TextChunker.split(activeText, into: count)
        var chunks: [ChunkState] = []

        for (i, text) in chunkTexts.enumerated() {
            let chunkReveal = quote.revealPercentageForLevel
            let chunkWords = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            var wordStates = chunkWords.map { WordDisplayState(word: $0, state: .pending) }
            if !wordStates.isEmpty { wordStates[0].state = .current }

            // Apply per-chunk reveal percentage
            if chunkReveal > 0 {
                let pendingIndices = wordStates.enumerated()
                    .filter { $0.offset > 0 && $0.element.state == .pending }
                    .map { $0.offset }
                let revealCount = Int(Double(pendingIndices.count) * (chunkReveal / 100.0))
                if revealCount > 0 {
                    let shuffled = pendingIndices.shuffled()
                    for idx in shuffled.prefix(revealCount) {
                        wordStates[idx].isRevealed = true
                    }
                }
            }

            chunks.append(ChunkState(
                chunkText: text,
                words: wordStates,
                currentPosition: 0,
                mistakes: [],
                hintCount: 0,
                mcChoices: [],
                mcCorrectIndex: 0,
                showHint: false,
                revealPercentage: chunkReveal,
                previousWordWasMistake: false
            ))
        }

        splitChunks = chunks
        activeChunkIndex = 0
        loadChunk(at: 0)
        showSplitPopup = false

        // Persist the split
        saveSplitState()
    }

    /// Split the active chunk (or the whole quote if not yet split) into N sub-chunks.
    /// Supports recursive splitting — each section can be split further.
    func splitActiveChunk(into count: Int) {
        if !isSplit {
            // First split — split the whole quote
            split(into: count)
            return
        }

        // Already split — sub-split the active chunk
        stop()
        saveCurrentChunkState()
        guard var chunks = splitChunks,
              activeChunkIndex >= 0, activeChunkIndex < chunks.count else { return }

        let activeChunk = chunks[activeChunkIndex]
        let subTexts = TextChunker.split(activeChunk.chunkText, into: count)
        let currentReveal = activeChunk.revealPercentage

        var newSubChunks: [ChunkState] = []
        for text in subTexts {
            let chunkWords = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            var wordStates = chunkWords.map { WordDisplayState(word: $0, state: .pending) }
            if !wordStates.isEmpty { wordStates[0].state = .current }

            if currentReveal > 0 {
                let pendingIndices = wordStates.enumerated()
                    .filter { $0.offset > 0 && $0.element.state == .pending }
                    .map { $0.offset }
                let revealCount = Int(Double(pendingIndices.count) * (currentReveal / 100.0))
                if revealCount > 0 {
                    let shuffled = pendingIndices.shuffled()
                    for idx in shuffled.prefix(revealCount) {
                        wordStates[idx].isRevealed = true
                    }
                }
            }

            newSubChunks.append(ChunkState(
                chunkText: text,
                words: wordStates,
                currentPosition: 0,
                mistakes: [],
                hintCount: 0,
                mcChoices: [],
                mcCorrectIndex: 0,
                showHint: false,
                revealPercentage: currentReveal,
                previousWordWasMistake: false
            ))
        }

        // Replace the active chunk with the new sub-chunks
        chunks.remove(at: activeChunkIndex)
        chunks.insert(contentsOf: newSubChunks, at: activeChunkIndex)
        splitChunks = chunks

        // Load the first new sub-chunk
        loadChunk(at: activeChunkIndex)
        showSplitPopup = false
        saveSplitState()
    }

    /// Split a specific chunk by index. Switches to it first, then sub-splits.
    func splitChunkAt(_ index: Int, into count: Int) {
        guard isSplit, let chunks = splitChunks,
              index >= 0, index < chunks.count else { return }

        if index != activeChunkIndex {
            stop()
            saveCurrentChunkState()
            activeChunkIndex = index
            loadChunk(at: index, preserveReveal: true)
        }

        splitActiveChunk(into: count)
        // Keep popup open for continued chunk management
        showSplitPopup = true
    }

    /// Switch to a different chunk (tapped a peek container or nav control)
    func switchToChunk(_ index: Int) {
        guard let chunks = splitChunks,
              index >= 0, index < chunks.count,
              index != activeChunkIndex else { return }

        stop()
        saveCurrentChunkState()
        activeChunkIndex = index
        loadChunk(at: index, preserveReveal: true)
    }

    /// Merge chunk at `index` with the chunk at `index + 1`
    func mergeChunks(at index: Int) {
        guard var chunks = splitChunks,
              index >= 0, index < chunks.count - 1 else { return }

        stop()
        saveCurrentChunkState()
        // Re-read after save
        chunks = splitChunks!

        let first = chunks[index]
        let second = chunks[index + 1]

        // Combine text
        let mergedText = first.chunkText + " " + second.chunkText

        // Combine words: first chunk's words + second chunk's words (reset second's current marker)
        var mergedWords = first.words
        var secondWords = second.words
        // If the second chunk's first word is .current but user hasn't started it, mark pending
        if let firstIdx = secondWords.firstIndex(where: { $0.state == .current }) {
            if second.currentPosition == 0 {
                secondWords[firstIdx].state = .pending
            }
        }
        mergedWords.append(contentsOf: secondWords)

        // Merged position is the first chunk's position (since we merge into it)
        let mergedPosition = first.currentPosition

        let merged = ChunkState(
            chunkText: mergedText,
            words: mergedWords,
            currentPosition: mergedPosition,
            mistakes: first.mistakes + second.mistakes,
            hintCount: first.hintCount + second.hintCount,
            mcChoices: first.mcChoices,
            mcCorrectIndex: first.mcCorrectIndex,
            showHint: first.showHint,
            revealPercentage: first.revealPercentage,
            previousWordWasMistake: first.previousWordWasMistake
        )

        // Replace first with merged, remove second
        splitChunks![index] = merged
        splitChunks!.remove(at: index + 1)

        // If only 1 chunk left, unsplit entirely
        if splitChunks!.count <= 1 {
            unsplit()
            return
        }

        // Adjust activeChunkIndex
        if activeChunkIndex == index + 1 {
            activeChunkIndex = index
        } else if activeChunkIndex > index + 1 {
            activeChunkIndex -= 1
        }
        // Clamp
        activeChunkIndex = min(activeChunkIndex, splitChunks!.count - 1)

        loadChunk(at: activeChunkIndex, preserveReveal: true)
        saveSplitState()
    }

    /// Remove the split and restore the full quote
    func unsplit() {
        stop()
        splitChunks = nil
        activeChunkIndex = 0

        // Restore full quote
        comparator.setTargetText(activeText, language: activeLanguage)
        comparator.reset()
        let targetWords = comparator.getTargetWords()
        words = targetWords.map { WordDisplayState(word: $0, state: .pending) }
        if !words.isEmpty { words[0].state = .current }
        currentPosition = 0
        mistakes.removeAll()
        sessionStartTime = nil
        tappedMistakeIndex = nil
        showHint = false
        showResults = false
        previousWordWasMistake = false
        hintCount = 0

        if revealPercentage > 0 { applyRevealPercentage() }
        if currentMode == .multipleChoice { generateChoices() }

        // Clear persisted split
        saveSplitState()
    }

    /// Save current active state into the splitChunks array
    private func saveCurrentChunkState() {
        guard splitChunks != nil else { return }
        splitChunks![activeChunkIndex] = ChunkState(
            chunkText: splitChunks![activeChunkIndex].chunkText,
            words: words,
            currentPosition: currentPosition,
            mistakes: mistakes,
            hintCount: hintCount,
            mcChoices: mcChoices,
            mcCorrectIndex: mcCorrectIndex,
            showHint: showHint,
            revealPercentage: revealPercentage,
            previousWordWasMistake: previousWordWasMistake
        )
    }

    /// Load a chunk's saved state into the active properties.
    /// When `preserveReveal` is true, the slider stays where the user left it
    /// and the new chunk's words are re-revealed to match the current slider value.
    private func loadChunk(at index: Int, preserveReveal: Bool = false) {
        guard let chunks = splitChunks, index < chunks.count else { return }
        let chunk = chunks[index]

        comparator.setTargetText(chunk.chunkText)
        comparator.reset()
        comparator.setPosition(chunk.currentPosition)

        words = chunk.words
        currentPosition = chunk.currentPosition
        mistakes = chunk.mistakes
        hintCount = chunk.hintCount
        mcChoices = chunk.mcChoices
        mcCorrectIndex = chunk.mcCorrectIndex
        showHint = chunk.showHint
        if !preserveReveal {
            revealPercentage = chunk.revealPercentage
        }
        previousWordWasMistake = chunk.previousWordWasMistake
        tappedMistakeIndex = nil
        showResults = false

        // Re-apply reveal to this chunk's words using the current slider value
        if preserveReveal {
            applyRevealPercentage()
        }

        if currentMode == .multipleChoice && mcChoices.isEmpty {
            generateChoices()
        }
    }

    /// Handle completion of the current text (or chunk).
    /// Shows results screen for both split and non-split modes.
    /// Defers showResults to the next run loop tick to avoid
    /// "Publishing changes from within view updates" when called
    /// from commitComparisonResult (which already mutated @Published words).
    private func handleCompletion() {
        pause()
        let tested = testedWordCount
        let mistakes = mistakeCount
        let accuracy = tested > 0 ? max(0, Double(tested - mistakes) / Double(tested)) : 0

        if isSplit {
            saveCurrentChunkState()

            // In master mode with split: auto-advance to next chunk without showing results
            if isMasterMode {
                // Check if master mode already failed (can't pass 95%)
                let totalTested = masterModeTotalTested
                let totalMistakes = masterModeTotalMistakes
                let canStillPass = totalMistakes <= Int(Double(totalTested) * 0.05)

                if canStillPass {
                    // Try advancing to next chunk
                    if advanceToNextChunk() {
                        // More chunks to go — continue without showing results
                        return
                    }
                }
                // All chunks done (or failed) — show results with aggregate stats
            }
        }

        // Check if user earned a level advancement (non-master mode only)
        if !isMasterMode {
            checkLevelAdvancement(accuracy: accuracy)
        }

        // In master mode, only play win sound if passed (95%+), otherwise fail
        if isMasterMode {
            if accuracy >= 0.95 {
                AlertManager.shared.triggerResultSound(accuracy: accuracy)
            } else {
                AlertManager.shared.triggerResultFailSound()
            }
        } else {
            AlertManager.shared.triggerResultSound(accuracy: accuracy)
        }
        DispatchQueue.main.async { [weak self] in
            self?.showResults = true
        }
    }

    /// Restore a saved split from the quote's persisted chunks/activeChunkIndex.
    /// Call after settingsStore is set so reveal percentage is correct.
    /// Uses each chunk's own per-chunk default reveal (not preserveReveal).
    func restoreSavedSplit() {
        guard let chunks = quote.chunks, chunks.count > 1 else { return }
        split(into: chunks.count)
        // Jump to the saved active chunk — use its own per-chunk reveal default
        let savedIndex = quote.activeChunkIndex ?? 0
        if savedIndex > 0 && savedIndex < chunks.count {
            stop()
            saveCurrentChunkState()
            activeChunkIndex = savedIndex
            loadChunk(at: savedIndex)  // preserveReveal=false: use chunk's own default
        }
    }

    /// Reload the view model with a completely new quote (used for swipe navigation).
    func reloadQuote(_ newQuote: Quote) {
        stop()

        // Save split state of old quote before switching
        saveSplitState()

        quote = newQuote

        // Reset all state
        activeLanguage = nil
        splitChunks = nil
        activeChunkIndex = 0
        currentPosition = 0
        mistakes.removeAll()
        sessionStartTime = nil
        tappedMistakeIndex = nil
        showHint = false
        showResults = false
        tappedMistakeIndex = nil
        previousWordWasMistake = false
        hintCount = 0
        flashingWordIndex = nil
        flashTimer?.invalidate()
        mcChoices = []
        mcWrongIndex = nil

        // Reset speech recognizer to system language
        speechService.reconfigureLocale(SpeechRecognitionService.speechLocaleIdentifier())

        // Set up the new quote
        setupQuote()

        // Restore saved split if any — use per-chunk reveal defaults
        if let chunks = newQuote.chunks, chunks.count > 1 {
            split(into: chunks.count)
            let savedIndex = newQuote.activeChunkIndex ?? 0
            if savedIndex > 0 && savedIndex < chunks.count {
                stop()
                saveCurrentChunkState()
                activeChunkIndex = savedIndex
                loadChunk(at: savedIndex)
            }
        }

        // Re-apply mode
        if currentMode == .multipleChoice {
            generateChoices()
        }
    }

    /// Persist the current split state (chunks + active index) back to the quote via QuoteStore.
    func saveSplitState() {
        guard let store = quoteStore else { return }
        guard var updated = store.getQuote(byId: quote.id) else { return }

        if let chunks = splitChunks {
            saveCurrentChunkState()
            updated.chunks = chunks.map(\.chunkText)
            updated.activeChunkIndex = activeChunkIndex

            // Compute and persist per-chunk accuracies
            var accuracies = updated.chunkAccuracies ?? Array(repeating: 0.0, count: chunks.count)
            // Resize if chunk count changed (split/merge)
            while accuracies.count < chunks.count { accuracies.append(0.0) }
            if accuracies.count > chunks.count { accuracies = Array(accuracies.prefix(chunks.count)) }

            // Also track reveal percentages
            var reveals = updated.chunkRevealPercentages ?? Array(repeating: -1.0, count: chunks.count)
            while reveals.count < chunks.count { reveals.append(-1.0) }
            if reveals.count > chunks.count { reveals = Array(reveals.prefix(chunks.count)) }

            for (i, chunk) in chunks.enumerated() {
                let total = chunk.words.count
                let completedWords = chunk.words.filter { $0.state == .correct || $0.state == .incorrect }.count
                // Only update accuracy/reveal for chunks that have been fully completed
                if completedWords >= total && total > 0 {
                    accuracies[i] = Double(max(0, total - chunk.mistakes.count)) / Double(total)
                    reveals[i] = chunk.revealPercentage
                }
            }
            updated.chunkAccuracies = accuracies
            updated.chunkRevealPercentages = reveals
        } else {
            updated.chunks = nil
            updated.activeChunkIndex = nil
            updated.chunkAccuracies = nil
            updated.chunkRevealPercentages = nil
        }
        store.updateQuote(updated)
    }

    // MARK: - Hints

    func showHintNow() {
        showHint = true
    }

    // MARK: - User Equivalences

    /// Update the comparator's user equivalences mid-session
    func updateUserEquivalences(_ equivalences: [String: Set<String>]) {
        comparator.setUserEquivalences(equivalences)
    }

    // MARK: - Mistake Dispute Actions

    /// User tapped "I said the right word" on a red word — override the mistake
    func overrideMistake() {
        guard let index = tappedMistakeIndex else { return }

        // Grab the mistake before removing it so we can save the equivalence
        let mistake = mistakes.last(where: { $0.position == index })

        // Remove the mistake for this position
        mistakes.removeAll { $0.position == index }

        // Mark word as correct
        if index < words.count {
            words[index].state = .correct
        }

        tappedMistakeIndex = nil

        // Save equivalence locally + report to community
        if let mistake = mistake {
            let expected = mistake.expectedWord
            let spoken = mistake.spokenWord

            // Save locally so it works next session immediately
            userEquivalencesStore?.addEquivalence(expected: expected, spoken: spoken)

            // Update the comparator's live equivalences
            if let updated = userEquivalencesStore?.equivalences {
                comparator.setUserEquivalences(updated)
            }

            // Report to community (fire-and-forget)
            Task {
                await EquivalenceService.shared.reportEquivalence(expected: expected, spoken: spoken)
            }
        }
    }

    /// Dismiss the mistake dispute popup without correcting
    func dismissMistakePopup() {
        tappedMistakeIndex = nil
    }

    // MARK: - Visual Flash

    private func triggerVisualFlash() {
        showMistakeFlash = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.showMistakeFlash = false
        }
    }

    // MARK: - Session Creation

    /// Create a PracticeSession for the full quote (flattens all chunks if split).
    /// IMPORTANT: Must not have side effects — called during SwiftUI view evaluation.
    /// Callers must ensure saveCurrentChunkState() was called beforehand (handleCompletion does this).
    /// The reveal percentage to record for the session.
    private var sessionRevealPercentage: Double {
        revealPercentage
    }

    func createSession() -> PracticeSession {
        if let chunks = splitChunks {
            let allWords = chunks.flatMap { $0.words }
            let allMistakes = chunks.flatMap { $0.mistakes }
            let totalCorrect = testsAllWords
                ? allWords.filter { $0.state == .correct }.count
                : allWords.filter { $0.state == .correct && !$0.isRevealed }.count
            let totalTested = testsAllWords
                ? allWords.count
                : allWords.filter { !$0.isRevealed }.count
            let totalHints = chunks.reduce(0) { $0 + $1.hintCount }
            return PracticeSession(
                id: UUID(),
                quoteId: quote.id,
                startedAt: sessionStartTime ?? Date(),
                completedAt: Date(),
                totalWords: allWords.count,
                testedWords: totalTested,
                correctWords: totalCorrect,
                mistakes: allMistakes,
                revealPercentage: sessionRevealPercentage,
                hintCount: totalHints
            )
        }
        return PracticeSession(
            id: UUID(),
            quoteId: quote.id,
            startedAt: sessionStartTime ?? Date(),
            completedAt: Date(),
            totalWords: words.count,
            testedWords: testedWordCount,
            correctWords: correctCount,
            mistakes: mistakes,
            revealPercentage: sessionRevealPercentage,
            hintCount: hintCount
        )
    }

    /// Create a PracticeSession for just the active chunk (not flattened across all chunks).
    /// IMPORTANT: Must not have side effects — called during SwiftUI view evaluation.
    func createChunkSession() -> PracticeSession {
        return PracticeSession(
            id: UUID(),
            quoteId: quote.id,
            startedAt: sessionStartTime ?? Date(),
            completedAt: Date(),
            totalWords: words.count,
            testedWords: testedWordCount,
            correctWords: correctCount,
            mistakes: mistakes,
            revealPercentage: revealPercentage,
            hintCount: hintCount
        )
    }

    /// Advance to the next unfinished chunk. Returns false if all chunks are done.
    @discardableResult
    func advanceToNextChunk() -> Bool {
        guard let chunks = splitChunks else { return false }

        // Look for the next chunk after the current one that isn't fully completed
        let startSearch = activeChunkIndex + 1
        for i in startSearch..<chunks.count {
            let chunk = chunks[i]
            let completedWords = chunk.words.filter { $0.state == .correct || $0.state == .incorrect }.count
            if completedWords < chunk.words.count {
                switchToChunk(i)
                return true
            }
        }

        // Wrap around and check chunks before the current one
        for i in 0..<activeChunkIndex {
            let chunk = chunks[i]
            let completedWords = chunk.words.filter { $0.state == .correct || $0.state == .incorrect }.count
            if completedWords < chunk.words.count {
                switchToChunk(i)
                return true
            }
        }

        // All chunks are done
        return false
    }

    // MARK: - Word Processing

    private func processWord(_ word: String, confidence: Float = 0.0,
                              alternatives: [String] = [], isRevision: Bool = false) {
        // Ignore words if not actively listening (e.g., after reset)
        guard isListening else { return }

        // Handle STT word-boundary revision: when the recognizer revises a previously-matched
        // word by merging it with the next syllable (e.g., Spanish "veracidad" + "es" →
        // "veracidades"), extract the suffix and compare that instead of the merged word.
        if isRevision && currentPosition > 0 && currentPosition - 1 < words.count
            && words[currentPosition - 1].state == .correct {
            let prevWord = words[currentPosition - 1].word
            let incomingLower = word.lowercased()
            let prevLower = prevWord.lowercased()
            if incomingLower.hasPrefix(prevLower) && incomingLower.count > prevLower.count {
                let suffix = String(word.dropFirst(prevWord.count))
                print("[RESULT] Revision \"\(word)\" swallowed prev match \"\(prevWord)\" — extracting suffix \"\(suffix)\"")
                if let result = comparator.compareWord(suffix, confidence: confidence, alternatives: alternatives) {
                    processComparisonResult(result, isRevision: isRevision)
                }
                return
            }
        }

        guard let result = comparator.compareWord(word, confidence: confidence, alternatives: alternatives) else {
            // Word was filtered (filler word) or buffered for compound word matching
            // Reset pending mismatch timer - word is still being refined by speech recognizer
            if pendingMismatchResult != nil {
                resetPendingMismatchTimer()
            }
            return
        }

        processComparisonResult(result, isRevision: isRevision)
    }

    /// Process a comparison result with pending mismatch logic.
    /// Mismatches are deferred to allow speech recognizer revisions to settle,
    /// preventing false alerts when long words produce intermediate partial transcriptions.
    private func processComparisonResult(_ result: ComparisonResult, isRevision: Bool = false) {
        if result.isMatch {
            // Match - cancel any pending mismatch at this position or earlier.
            if let pendingPos = pendingMismatchResult?.position, result.position >= pendingPos {
                print("[RESULT] Pending mismatch cancelled by match at pos=\(result.position) (pending was pos=\(pendingPos))")
                cancelPendingMismatch()
            }
            commitComparisonResult(result)
        } else {
            // Mismatch - defer to allow for speech recognizer revisions.
            // If a mismatch is already pending, DON'T replace it — the first
            // wrong word is the real mistake. Subsequent words at the same position
            // (the user kept speaking) are ignored; the pending fires via its timer.
            // This prevents: "banana" pending replaced by "of" (flushed, isRevision=true),
            // then look-ahead cancels "of" → real mistake lost.
            if pendingMismatchResult != nil {
                print("[RESULT] Ignoring mismatch \"\(result.spokenWord)\" at pos=\(result.position) — pending already exists")
                return
            }
            schedulePendingMismatch(result)
        }
    }

    // MARK: - Pending Mismatch Management

    /// Schedule a deferred mismatch alert. If a revision corrects the word before
    /// the timer fires, the pending mismatch is cancelled (zero false alerts).
    private func schedulePendingMismatch(_ result: ComparisonResult) {
        pendingMismatchTimer?.invalidate()
        pendingMismatchResult = result

        // Track consecutive mismatches at the same position
        if result.position == lastMismatchPosition {
            consecutiveMismatchesAtPosition += 1
        } else {
            consecutiveMismatchesAtPosition = 1
            lastMismatchPosition = result.position
        }

        let interval = settleInterval(for: result)
        print("[RESULT] PENDING mismatch: \"\(result.spokenWord)\" at pos=\(result.position) - settling \(String(format: "%.2f", interval))s (expected \"\(result.expectedWord)\" \(result.normalizedExpected.count) chars, attempt #\(consecutiveMismatchesAtPosition))")

        pendingMismatchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.firePendingMismatch()
            }
        }
    }

    /// Fire the pending mismatch - timer expired or a new word confirmed it was a real mistake
    private func firePendingMismatch() {
        guard let result = pendingMismatchResult else { return }

        // Before showing popup, check if the spoken word matches one of the next
        // 1-2 expected words. This catches "dropped word" cases where the STT
        // skipped a word (e.g., "Thy" dropped, "love" arrives at "Thy" position
        // but matches the next position). Range=2 keeps it targeted to avoid
        // false matches on distant words.
        if let syncResult = comparator.tryMatchAhead(spoken: result.spokenWord, range: 2) {
            print("[RESULT] Sync recovery instead of popup: \"\(result.spokenWord)\" matches ahead at pos=\(syncResult.position)")
            pendingMismatchResult = nil
            pendingMismatchTimer?.invalidate()
            pendingMismatchTimer = nil
            consecutiveMismatchesAtPosition = 0
            lastMismatchPosition = -1
            commitComparisonResult(syncResult)
            return
        }

        print("[RESULT] FIRING pending mismatch: \"\(result.spokenWord)\" at pos=\(result.position)")

        pendingMismatchResult = nil
        pendingMismatchTimer?.invalidate()
        pendingMismatchTimer = nil
        consecutiveMismatchesAtPosition = 0
        lastMismatchPosition = -1

        commitComparisonResult(result)
    }

    /// Cancel the pending mismatch without processing (word was corrected by a revision)
    private func cancelPendingMismatch() {
        if let pending = pendingMismatchResult {
            print("[RESULT] CANCELLED pending mismatch: \"\(pending.spokenWord)\" at pos=\(pending.position)")
        }
        pendingMismatchTimer?.invalidate()
        pendingMismatchTimer = nil
        pendingMismatchResult = nil
        consecutiveMismatchesAtPosition = 0
        lastMismatchPosition = -1
    }

    /// Reset the pending mismatch timer without cancelling (word still being refined,
    /// e.g. comparator buffered a prefix like "juxta" for compound matching)
    private func resetPendingMismatchTimer() {
        guard let result = pendingMismatchResult else { return }

        let interval = settleInterval(for: result)
        print("[RESULT] RESET pending mismatch timer (word still refining at pos=\(result.position))")

        pendingMismatchTimer?.invalidate()
        pendingMismatchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.firePendingMismatch()
            }
        }
    }

    /// Commit a comparison result - actually update state, record mistakes, trigger alerts
    private func commitComparisonResult(_ result: ComparisonResult) {
        // Don't process results while mistake dispute popup is showing
        guard tappedMistakeIndex == nil else { return }

        let previousPosition = currentPosition

        // DEBUG: Log comparison result
        print("[RESULT] isMatch=\(result.isMatch) spoken=\"\(result.spokenWord)\" expected=\"\(result.expectedWord)\" pos=\(result.position)")

        // Update word state based on match result
        if previousPosition < words.count {
            if result.isMatch {
                // Mark the matched word as correct.
                let matchedPos = result.position
                if matchedPos < words.count {
                    words[matchedPos].state = .correct
                }

                // If look-ahead skipped positions, mark skipped words as correct too
                if matchedPos > previousPosition {
                    for i in previousPosition..<matchedPos {
                        if i < words.count {
                            words[i].state = .correct
                        }
                    }
                }

                print("[RESULT] → CORRECT count now: \(correctCount)")

                // If we just recovered from a mistake, play correct word sound
                if previousWordWasMistake {
                    AlertManager.shared.triggerCorrectWordSound()
                    previousWordWasMistake = false
                }

                // Reset hint when word advances
                showHint = false
            } else {
                // Record mistake
                let mistake = PracticeMistake(
                    position: result.position,
                    expectedWord: result.expectedWord,
                    spokenWord: result.spokenWord,
                    timestamp: Date(),
                    confidence: result.confidence,
                    certainty: .definite
                )
                mistakes.append(mistake)
                print("[RESULT] → MISTAKE #\(mistakes.count): expected=\"\(result.expectedWord)\" got=\"\(result.spokenWord)\" conf=\(String(format: "%.2f", result.confidence))")

                AlertManager.shared.triggerMistakeAlert(audioPauseHandler: audioPauseHandler)
                previousWordWasMistake = true
                words[previousPosition].state = .incorrect
                showHint = false

                // Advance past the word — keep listening
                comparator.advancePosition()
            }

            // Update position to match comparator
            currentPosition = comparator.currentPosition

            // Mark next word as current (only if we advanced)
            if currentPosition != previousPosition && currentPosition < words.count {
                words[currentPosition].state = .current
            }

        }

        // Check completion — also early-fail in master mode if 95% is no longer reachable
        if comparator.isComplete || !masterModeCanStillPass {
            handleCompletion()
        }
    }
}

// MARK: - SpeechRecognitionDelegate

extension RecitationViewModel: SpeechRecognitionDelegate {
    nonisolated func speechRecognition(didRecognizeWord word: String, confidence: Float,
                                       alternatives: [String], isFinal: Bool, isRevision: Bool) {
        Task { @MainActor in
            // Guard against processing after reset/stop
            guard self.isListening else { return }
            resetWordActivityTimer()
            processWord(word, confidence: confidence, alternatives: alternatives, isRevision: isRevision)
        }
    }

    nonisolated func speechRecognition(didEncounterError error: Error) {
        Task { @MainActor in
            print("Speech error: \(error)")
            // Could show error to user here
        }
    }

    nonisolated func speechRecognitionDidEnd() {
        Task { @MainActor in
            // Guard against processing after reset/stop
            guard self.isListening else { return }

            // Recognition ended (possibly due to silence)
            // Flush any buffered compound word — if speech stopped, the partial word
            // won't be completed, so treat it as a mismatch.
            if let result = comparator.flushCompoundBuffer() {
                processComparisonResult(result)
            }

            // Fire any pending mismatch — no more words are coming
            firePendingMismatch()
        }
    }
}
