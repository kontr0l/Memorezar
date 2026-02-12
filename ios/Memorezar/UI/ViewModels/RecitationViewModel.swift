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
        words = comparator.getTargetWords().map {
            WordDisplayState(word: $0, state: .pending)
        }

        // Mark first word as current
        if !words.isEmpty {
            words[0].state = .current
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
            let options = settings.comparatorOptions
            // Re-create comparator with new options if needed
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

        // Update word state
        if currentPosition < words.count {
            words[currentPosition].state = result.isMatch ? .correct : .incorrect

            if !result.isMatch {
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
            }

            currentPosition = comparator.currentPosition

            // Mark next word as current
            if currentPosition < words.count {
                words[currentPosition].state = .current
            }

            // Reset hint timer
            startHintTimer()
        }

        // Check completion
        if comparator.isComplete {
            pause()
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
