import Foundation
import SwiftUI
import Combine

/// State of a word in the display
enum WordState {
    case pending    // Not yet reached
    case current    // Current word being spoken
    case correct    // Correctly spoken
    case incorrect  // Incorrectly spoken
}

/// Word with its display state
struct WordDisplayState: Identifiable {
    let id = UUID()
    let word: String
    var state: WordState
    var isRevealed: Bool = false  // For partial reveal mode - whether this word is pre-revealed
}

/// Last mistake information
struct MistakeInfo {
    let expected: String
    let spoken: String
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
    @Published var showMistakeFlash = false
    @Published var showResults = false
    @Published var showHint = false
    @Published var lastMistake: MistakeInfo?
    @Published var showAllWords = false  // Manual override to show all words
    @Published var revealPercentage: Double = 0  // Percentage of words to randomly reveal (0-100)

    // MARK: - Computed Properties

    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentPosition) / Double(words.count)
    }

    var correctCount: Int {
        words.filter { $0.state == .correct }.count
    }

    var mistakeCount: Int {
        words.filter { $0.state == .incorrect }.count
    }

    var hintWord: String? {
        guard currentPosition < words.count else { return nil }
        return words[currentPosition].word
    }

    // MARK: - Private Properties

    private let quote: Quote
    private let speechService = SpeechRecognitionService()
    private let comparator: WordComparator
    private var mistakes: [PracticeMistake] = []
    private var sessionStartTime: Date?
    private var hintTimer: Timer?
    private var previousWordWasMistake = false  // Track for correct word sound after recovery

    var settingsStore: SettingsStore?

    // MARK: - Initialization

    init(quote: Quote) {
        self.quote = quote
        self.comparator = WordComparator()

        super.init()

        setupQuote()
        setupAlertManager()
        speechService.delegate = self
    }

    // MARK: - Setup

    private func setupQuote() {
        comparator.setTargetText(quote.text)
        let targetWords = comparator.getTargetWords()

        words = targetWords.map {
            WordDisplayState(word: $0, state: .pending, isRevealed: false)
        }

        // Mark first word as current
        if !words.isEmpty {
            words[0].state = .current
        }

        // Apply initial reveal for partial mode
        applyPartialReveal()
    }

    /// Apply partial reveal based on settings percentage
    private func applyPartialReveal() {
        guard let settings = settingsStore,
              settings.wordVisibility == .partial else { return }

        revealPercentage = settings.wordRevealPercentage
        applyRevealPercentage()
    }

    /// Apply the current reveal percentage with truly random word selection
    func applyRevealPercentage() {
        // Only reveal pending words (not current or already spoken words)
        let pendingIndices = words.enumerated()
            .filter { $0.offset > currentPosition && $0.element.state == .pending }
            .map { $0.offset }

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

    /// Check if a word should be visible
    func shouldShowWord(at index: Int) -> Bool {
        // Manual override to show all words
        if showAllWords { return true }

        let wordState = words[index]

        // Already spoken words (correct/incorrect) and current word are always visible
        if wordState.state == .correct || wordState.state == .incorrect || wordState.state == .current {
            return true
        }

        // For pending words, check if they're revealed by the slider
        // The revealPercentage slider controls visibility for all pending words
        if revealPercentage > 0 {
            return wordState.isRevealed
        }

        // If revealPercentage is 0, check the visibility mode from settings
        guard let settings = settingsStore else { return true }

        switch settings.wordVisibility {
        case .showAll:
            // If slider is at 0% but mode is showAll, show all
            return true
        case .hideUntilSpoken:
            // Hide until spoken
            return false
        case .partial:
            // Show if pre-revealed
            return wordState.isRevealed
        }
    }

    private func setupAlertManager() {
        AlertManager.shared.onVisualAlert = { [weak self] in
            self?.triggerVisualFlash()
        }
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

        // Apply settings
        if let settings = settingsStore {
            comparator.updateOptions(settings.comparatorOptions)
        }

        do {
            try speechService.startListening()
            isListening = true
            sessionStartTime = sessionStartTime ?? Date()
            startHintTimer()
        } catch {
            print("Failed to start listening: \(error)")
        }
    }

    func pause() {
        speechService.stopListening()
        isListening = false
        stopHintTimer()
    }

    func stop() {
        pause()
    }

    func reset() {
        stop()
        comparator.reset()
        mistakes.removeAll()
        sessionStartTime = nil
        lastMistake = nil
        showHint = false
        showResults = false
        previousWordWasMistake = false

        // Reset word states
        for i in words.indices {
            words[i].state = i == 0 ? .current : .pending
        }
        currentPosition = 0
    }

    // MARK: - Hints

    private func startHintTimer() {
        stopHintTimer()
        let delay = settingsStore?.hintDelay ?? 3.0
        hintTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showHint = true
            }
        }
    }

    private func stopHintTimer() {
        hintTimer?.invalidate()
        hintTimer = nil
        showHint = false
    }

    func showHintNow() {
        showHint = true
    }

    // MARK: - Visual Flash

    private func triggerVisualFlash() {
        showMistakeFlash = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.showMistakeFlash = false
        }
    }

    // MARK: - Session Creation

    func createSession() -> PracticeSession {
        PracticeSession(
            id: UUID(),
            quoteId: quote.id,
            startedAt: sessionStartTime ?? Date(),
            completedAt: Date(),
            totalWords: words.count,
            correctWords: correctCount,
            mistakes: mistakes
        )
    }

    // MARK: - Word Processing

    private func processWord(_ word: String) {
        guard let result = comparator.compareWord(word) else {
            // Word was filtered (filler word)
            return
        }

        let previousPosition = currentPosition

        // Update word state based on match result
        if previousPosition < words.count {
            if result.isMatch {
                // Correct word - mark as correct
                words[previousPosition].state = .correct

                // If we just recovered from a mistake, play correct word sound
                if previousWordWasMistake {
                    AlertManager.shared.triggerCorrectWordSound()
                    previousWordWasMistake = false
                }
            } else {
                // Incorrect word
                // Record mistake
                let mistake = PracticeMistake(
                    position: result.position,
                    expectedWord: result.expectedWord,
                    spokenWord: result.spokenWord,
                    timestamp: Date()
                )
                mistakes.append(mistake)

                // Show last mistake
                lastMistake = MistakeInfo(
                    expected: result.expectedWord,
                    spoken: result.spokenWord
                )

                // Trigger alerts
                AlertManager.shared.triggerMistakeAlert()

                // Track that this was a mistake (for correct word sound after recovery)
                previousWordWasMistake = true

                // If requireCorrectWord is enabled, flash incorrect then back to current
                // The comparator won't have advanced, so we stay on same word
                if settingsStore?.requireCorrectWord == true {
                    words[previousPosition].state = .incorrect
                    // Brief flash of incorrect, then back to current
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self = self, self.currentPosition == previousPosition else { return }
                        self.words[previousPosition].state = .current
                    }
                } else {
                    words[previousPosition].state = .incorrect
                    previousWordWasMistake = false  // Moving on, don't play correct sound
                }
            }

            // Update position to match comparator
            currentPosition = comparator.currentPosition

            // Mark next word as current (only if we advanced)
            if currentPosition != previousPosition && currentPosition < words.count {
                words[currentPosition].state = .current
            }

            // Reset hint timer
            startHintTimer()
        }

        // Check completion
        if comparator.isComplete {
            pause()
            // Play completion sound (applause, fanfare, etc.)
            AlertManager.shared.triggerCompletionSound()
            showResults = true
        }
    }
}

// MARK: - SpeechRecognitionDelegate

extension RecitationViewModel: SpeechRecognitionDelegate {
    nonisolated func speechRecognition(didRecognizeWord word: String, isFinal: Bool) {
        Task { @MainActor in
            processWord(word)
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
            // Recognition ended (possibly due to silence)
            // The speech service auto-restarts if still listening
        }
    }
}
