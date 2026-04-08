import Foundation
import Speech
import AVFoundation

/// Streaming Speech Recognition Service using Apple's Speech Framework
///
/// Key features:
/// - Real-time interim results (words as they're spoken)
/// - Continuous listening mode
/// - Word-by-word callback for immediate processing
/// - Low latency optimized for < 200ms word detection

protocol SpeechRecognitionDelegate: AnyObject {
    func speechRecognition(didRecognizeWord word: String, confidence: Float,
                           alternatives: [String], isFinal: Bool, isRevision: Bool)
    func speechRecognition(didEncounterError error: Error)
    func speechRecognitionDidEnd()
}

final class SpeechRecognitionService: NSObject {

    // MARK: - Properties

    weak var delegate: SpeechRecognitionDelegate?

    /// Callback for real-time audio level (0.0–1.0), called on audio thread
    var audioLevelCallback: ((Float) -> Void)?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    private var lastAudioLevelUpdate: CFAbsoluteTime = 0
    private static let audioLevelThrottleInterval: CFAbsoluteTime = 0.033 // ~30fps

    private var lastProcessedWordCount = 0
    private var previousTranscript = ""
    private var lastProcessedWord = ""  // Track the last word we processed to detect revisions
    private var previousWords: [String] = []  // Words from last result for restructuring detection
    private var latestSegments: [SFTranscriptionSegment] = []  // Store segments for confidence/alternatives lookup

    // Debounce mechanism for word revisions
    // When speech recognition revises a word, we wait for it to "settle" before sending
    private var pendingWord: String?
    private var pendingWordIndex: Int = -1  // Segment index for confidence/alternatives lookup
    private var pendingWordTimer: Timer?
    private static let revisionDebounceInterval: TimeInterval = 0.20 // 200ms stability window

    // Session restart - proactively restart before Apple's ~60s degradation
    private var sessionRestartTimer: Timer?
    private var sessionGeneration = 0
    private var currentContextualStrings: [String] = []
    private static let maxSessionDuration: TimeInterval = 50 // Restart before corruption

    // After a session restart, the new recognizer replays the old transcript before
    // producing new words. We save the word count at restart time and skip all results
    // until the transcript exceeds that count (indicating genuinely new words).
    private var isPostRestart = false
    private var preRestartWordCount = 0
    private var postRestartTimeout: Timer?

    private(set) var isListening = false

    // MARK: - Initialization

    /// Maps a short language code (e.g. "es", "fr") to a full speech locale identifier.
    /// Falls back to the system's preferred language if no code is given.
    static func speechLocaleIdentifier(for languageCode: String? = nil) -> String {
        let code = languageCode ?? LanguageHelper.preferredLanguageCode
        let localeMap: [String: String] = [
            "en": "en-US", "es": "es-ES", "fr": "fr-FR", "de": "de-DE",
            "pt": "pt-BR", "ar": "ar-SA", "it": "it-IT", "ja": "ja-JP",
            "zh": "zh-CN", "ko": "ko-KR", "ru": "ru-RU", "hi": "hi-IN",
            "tr": "tr-TR", "nl": "nl-NL", "pl": "pl-PL", "sv": "sv-SE",
        ]
        return localeMap[code] ?? "\(code)-\(code.uppercased())"
    }

    override init() {
        let localeId = SpeechRecognitionService.speechLocaleIdentifier()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        super.init()
        speechRecognizer?.delegate = self
        print("[SPEECH] Initialized with locale: \(localeId)")
    }

    // MARK: - Authorization

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                default:
                    completion(false)
                }
            }
        }
    }

    static var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Start/Stop Recognition

    /// Start listening with optional contextual strings to improve recognition of uncommon words.
    /// Pass the target text words so the recognizer knows to look for them (e.g., "thine", "encircles").
    func startListening(contextualStrings: [String] = []) throws {
        // Stop any existing task and fully release audio session
        stopListening()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Configure audio session for low latency BEFORE checking recognizer availability.
        // SFSpeechRecognizer.isAvailable can return false when the audio session is inactive,
        // especially after a locale reconfigure following deactivateAudioSession().
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Set preferred buffer duration for lower latency (smaller = faster but more CPU)
        try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        // Configure for real-time results - CRITICAL for low latency
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Cloud has better interim results

        // Prime the recognizer with words from the target text.
        // This dramatically improves recognition of archaic, uncommon, or compound words
        // (e.g., "thine", "encircles", "maidservant") that the recognizer would otherwise
        // misinterpret as common words ("vine", "in circles", "maid servant").
        if !contextualStrings.isEmpty {
            recognitionRequest.contextualStrings = contextualStrings
            print("[SPEECH] Set \(contextualStrings.count) contextual strings for recognition")
        }

        // For iOS 16+, enable automatic punctuation
        if #available(iOS 16, *) {
            recognitionRequest.addsPunctuation = false // We don't need punctuation for comparison
        }

        // Reset tracking
        lastProcessedWordCount = 0
        previousTranscript = ""
        lastProcessedWord = ""
        previousWords = []
        latestSegments = []
        pendingWord = nil
        pendingWordIndex = -1
        pendingWordTimer?.invalidate()
        pendingWordTimer = nil
        isPostRestart = false
        preRestartWordCount = 0
        postRestartTimeout?.invalidate()
        postRestartTimeout = nil
        currentContextualStrings = contextualStrings

        // Start recognition task with generation counter to ignore stale results.
        // IMPORTANT: Dispatch to main thread so all state access (isPostRestart,
        // preRestartWordCount, lastProcessedWordCount, timers) is serialized with
        // restartRecognitionSession() which also runs on main thread.
        sessionGeneration += 1
        let currentGeneration = sessionGeneration
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, self.sessionGeneration == currentGeneration else { return }
                self.handleRecognitionResult(result: result, error: error)
            }
        }

        // Check if audio input is available (not available on simulator)
        guard AVAudioSession.sharedInstance().isInputAvailable else {
            self.recognitionRequest = nil
            recognitionTask = nil
            throw SpeechError.recognizerUnavailable
        }

        // Create a fresh audio engine so it picks up the newly activated audio session.
        // Reusing a stopped engine after deactivateAudioSession() leaves inputNode in a
        // stale state (0 Hz / 0 channels) that even reset() doesn't fix.
        audioEngine = AVAudioEngine()

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate the recording format - crash occurs if channelCount or sampleRate is 0
        guard recordingFormat.channelCount > 0 && recordingFormat.sampleRate > 0 else {
            self.recognitionRequest = nil
            recognitionTask = nil
            throw SpeechError.recognizerUnavailable
        }

        // Install tap to capture audio - use small buffer for lower latency
        inputNode.installTap(onBus: 0, bufferSize: 256, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate RMS audio level for waveform visualization (throttled to ~30fps)
            guard let self = self, let callback = self.audioLevelCallback,
                  let channelData = buffer.floatChannelData?[0] else { return }

            let now = CFAbsoluteTimeGetCurrent()
            guard now - self.lastAudioLevelUpdate >= Self.audioLevelThrottleInterval else { return }
            self.lastAudioLevelUpdate = now

            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrtf(sum / Float(max(1, frameLength)))
            // Normalize: typical speech RMS is ~0.01–0.1, scale to 0–1
            // Use sqrt curve so quieter speech still produces visible waveform movement
            let linear = min(1.0, rms * 20)
            let normalized = sqrtf(linear)
            callback(normalized)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        startSessionRestartTimer()
    }

    /// Temporarily pause the audio engine (recognition task stays alive).
    /// Used to allow haptic feedback which iOS suppresses during active mic recording.
    func pauseAudioEngine() {
        guard audioEngine.isRunning else { return }
        audioEngine.pause()
    }

    /// Resume the audio engine after a brief pause.
    /// Caller must check that listening is still active before calling —
    /// the 250ms haptic delay can fire after the engine has been torn down.
    func resumeAudioEngine() {
        guard !audioEngine.isRunning else { return }
        do {
            try audioEngine.start()
        } catch {
            print("[SPEECH] Failed to resume audio engine: \(error)")
        }
    }

    func stopListening() {
        // Increment generation so any pending/queued callbacks from the
        // cancelled task are ignored (they check sessionGeneration on main thread)
        sessionGeneration += 1

        // Flush any pending word before stopping
        flushPendingWord()

        sessionRestartTimer?.invalidate()
        sessionRestartTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        lastProcessedWordCount = 0
        previousTranscript = ""
        lastProcessedWord = ""
        previousWords = []
        latestSegments = []
        pendingWord = nil
        pendingWordIndex = -1
        pendingWordTimer?.invalidate()
        pendingWordTimer = nil
        isPostRestart = false
        preRestartWordCount = 0
        postRestartTimeout?.invalidate()
        postRestartTimeout = nil

        delegate?.speechRecognitionDidEnd()
    }

    /// Fully release the audio session. Call only when leaving the screen.
    func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Reconfigure the speech recognizer for a different locale (e.g. "es-ES" for Spanish).
    /// Must be called while NOT listening — stops listening first if needed.
    func reconfigureLocale(_ identifier: String) {
        if isListening { stopListening() }
        let newRecognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
        newRecognizer?.delegate = self
        speechRecognizer = newRecognizer
        print("[SPEECH] Reconfigured locale to \(identifier)")
    }

    // MARK: - Result Handling

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // Handle specific errors
            if let nsError = error as NSError? {
                // Error code 1 = "No speech detected" - this is normal
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1 {
                    return
                }
            }
            delegate?.speechRecognition(didEncounterError: error)
            return
        }

        guard let result = result else { return }

        let transcript = result.bestTranscription.formattedString
        let isFinal = result.isFinal
        let segments = result.bestTranscription.segments
        latestSegments = segments

        // Split into words
        let words = transcript.split(separator: " ").map(String.init)

        // DEBUG: Log every recognition result
        print("[SPEECH] \(isFinal ? "FINAL" : "INTERIM"): \"\(transcript)\" | words=\(words.count) lastProcessed=\(lastProcessedWordCount) lastWord=\"\(lastProcessedWord)\"")

        // DEBUG: Log segment confidence and alternatives for new/changed words
        if words.count > lastProcessedWordCount || (words.count == lastProcessedWordCount && words.last != lastProcessedWord) {
            let startIdx = words.count == lastProcessedWordCount ? max(0, words.count - 1) : lastProcessedWordCount
            let segEnd = min(words.count, segments.count)
            for i in startIdx..<max(startIdx, segEnd) {
                let seg = segments[i]
                let alts = seg.alternativeSubstrings
                let altsStr = alts.isEmpty ? "none" : alts.joined(separator: ", ")
                print("[SEGMENT] \"\(seg.substring)\" conf=\(String(format: "%.2f", seg.confidence)) alts=[\(altsStr)]")
            }
        }

        // ── Post-restart replay guard ──
        // After a session restart, the new recognizer replays the old transcript.
        // Skip ALL results (final or interim) until word count exceeds preRestartWordCount,
        // which indicates genuinely new words have appeared.
        if isPostRestart {
            if isFinal {
                // Final result from the cancelled old task — ignore completely
                print("[SPEECH] ♻️ POST-RESTART: ignoring final result")
                return
            }
            if words.count <= preRestartWordCount {
                // Transcript still replaying old content — skip entirely
                print("[SPEECH] ♻️ POST-RESTART: skipping replay (\(words.count) <= \(preRestartWordCount))")
                return
            }
            // Transcript has new words beyond the replay — resume normal processing
            lastProcessedWordCount = preRestartWordCount
            lastProcessedWord = preRestartWordCount > 0 && preRestartWordCount <= words.count
                ? words[preRestartWordCount - 1] : ""
            isPostRestart = false
            postRestartTimeout?.invalidate()
            postRestartTimeout = nil
            print("[SPEECH] ♻️ POST-RESTART: caught up (\(words.count) > \(preRestartWordCount)), resuming from \(preRestartWordCount)")
            // Fall through to normal processing below
        }

        // Process new words
        // For interim results, we process words that appear stable
        // For final results, we process all remaining words

        if isFinal {
            // Final result - flush any pending revision first
            flushPendingWord()

            // Guard against empty final result (transcript corruption in long sessions)
            guard !words.isEmpty else {
                print("[SPEECH] ⚠️ Empty final result ignored (transcript corruption)")
                lastProcessedWordCount = 0
                previousTranscript = ""
                lastProcessedWord = ""
                return
            }

            // Process all words from where we left off
            // Guard against transcript revision where word count decreased
            if lastProcessedWordCount < words.count {
                for i in lastProcessedWordCount..<words.count {
                    let info = segmentInfo(at: i)
                    print("[SPEECH] → SEND (final): \"\(words[i])\" conf=\(String(format: "%.2f", info.confidence))")
                    delegate?.speechRecognition(didRecognizeWord: words[i], confidence: info.confidence,
                                                alternatives: info.alternatives, isFinal: true, isRevision: false)
                }
            }
            lastProcessedWordCount = 0
            previousTranscript = ""
            lastProcessedWord = ""
            previousWords = []
        } else {
            // Interim result - process ALL words including the last one
            // This eliminates the 1-word lag that occurs when waiting for "stable" words
            // The comparator handles any revisions (changed words) appropriately

            // Handle transcript revision (word count can decrease if recognizer revises).
            // DON'T lower lastProcessedWordCount — keep the high water mark.
            // Lowering it causes already-matched words to be re-sent when the count
            // recovers (STT restructures transcript), triggering false mistake alerts.
            // The count will naturally catch up when genuinely new words arrive.
            if words.count < lastProcessedWordCount {
                print("[SPEECH] ⚠️ COUNT DROP: \(lastProcessedWordCount) → \(words.count) (keeping high water mark)")
            }

            // Process any new words
            if words.count > lastProcessedWordCount {
                // ── Mid-transcript insertion detection ──
                // STT sometimes restructures the transcript, inserting words at indices
                // below our high water mark. For example, "threshold" at index 21
                // becomes "threshold of th..." with "of" inserted at 21 and "threshold"
                // shifted to 20. Detect this by checking if the word at the boundary
                // shifted position, and if so, lower our effective start to include
                // the newly inserted words.
                var effectiveStart = lastProcessedWordCount

                if !previousWords.isEmpty && lastProcessedWordCount > 0 && lastProcessedWordCount <= previousWords.count {
                    let prevBoundaryWord = previousWords[lastProcessedWordCount - 1]
                    let newBoundaryWord = (lastProcessedWordCount - 1 < words.count) ? words[lastProcessedWordCount - 1] : ""

                    if prevBoundaryWord.lowercased() != newBoundaryWord.lowercased() {
                        // Words shifted — find where the last confirmed word now sits
                        let searchStart = max(0, lastProcessedWordCount - 5)
                        for i in stride(from: lastProcessedWordCount - 2, through: searchStart, by: -1) {
                            if i < words.count && words[i].lowercased() == prevBoundaryWord.lowercased() {
                                effectiveStart = i + 1
                                print("[SPEECH] ⚠️ RESTRUCTURING: \"\(prevBoundaryWord)\" shifted \(lastProcessedWordCount - 1) → \(i), sending from \(effectiveStart)")
                                break
                            }
                        }
                    }
                }

                // New word(s) arrived - flush any pending revision first
                // (the pending word is confirmed by the appearance of a new word)
                flushPendingWord()

                // Send all confirmed words (all but the trailing one) immediately.
                // These are confirmed because a subsequent word has appeared.
                for i in effectiveStart..<(words.count - 1) {
                    let info = segmentInfo(at: i)
                    print("[SPEECH] → SEND (new): \"\(words[i])\" conf=\(String(format: "%.2f", info.confidence))")
                    delegate?.speechRecognition(didRecognizeWord: words[i], confidence: info.confidence,
                                                alternatives: info.alternatives, isFinal: false, isRevision: false)
                }

                // Debounce the trailing word - it may still be revised by the recognizer.
                // This prevents false alerts from intermediate partial transcriptions
                // (e.g., "Just" → "Jax" → "Juxta" → "Juxtaposition")
                let trailingWord = words[words.count - 1]
                let trailingIndex = words.count - 1
                print("[SPEECH] ⏳ DEBOUNCE (new trailing): \"\(trailingWord)\"")
                scheduleRevisionSend(word: trailingWord, segmentIndex: trailingIndex)

                lastProcessedWordCount = words.count
                lastProcessedWord = words.last ?? ""
            } else if words.count > 0 && words.count == lastProcessedWordCount {
                // Same word count - check if the last word was revised by the recognizer
                let currentLastWord = words[words.count - 1]
                if currentLastWord != lastProcessedWord && !lastProcessedWord.isEmpty {
                    // Last word changed - this is a revision (speech recognizer refining its guess)
                    // Don't send immediately - debounce to let the word "settle"
                    print("[SPEECH] ⏳ REVISION: \"\(currentLastWord)\" (was \"\(lastProcessedWord)\") - debouncing...")
                    lastProcessedWord = currentLastWord
                    scheduleRevisionSend(word: currentLastWord, segmentIndex: words.count - 1)
                }
            }

            previousTranscript = transcript

            // Update previous words snapshot for restructuring detection
            // (only when count is stable or growing to preserve boundary reference)
            if words.count >= lastProcessedWordCount {
                previousWords = words
            }
        }
    }

    /// Look up segment confidence and alternatives for a word at the given index
    private func segmentInfo(at index: Int) -> (confidence: Float, alternatives: [String]) {
        guard index >= 0, index < latestSegments.count else { return (0.0, []) }
        let seg = latestSegments[index]
        return (seg.confidence, seg.alternativeSubstrings)
    }

    /// Schedule a debounced send for a revised word.
    /// If the word is revised again before the timer fires, the timer restarts.
    /// This prevents multiple alerts when speech recognition refines its transcription.
    private func scheduleRevisionSend(word: String, segmentIndex: Int) {
        // Cancel any existing timer
        pendingWordTimer?.invalidate()

        // Store the pending word and its segment index
        pendingWord = word
        pendingWordIndex = segmentIndex

        // Schedule new timer
        pendingWordTimer = Timer.scheduledTimer(withTimeInterval: Self.revisionDebounceInterval, repeats: false) { [weak self] _ in
            guard let self = self, let word = self.pendingWord else { return }

            let info = self.segmentInfo(at: self.pendingWordIndex)
            print("[SPEECH] → SEND (settled): \"\(word)\" conf=\(String(format: "%.2f", info.confidence))")
            self.delegate?.speechRecognition(didRecognizeWord: word, confidence: info.confidence,
                                             alternatives: info.alternatives, isFinal: false, isRevision: true)

            self.pendingWord = nil
            self.pendingWordIndex = -1
            self.pendingWordTimer = nil
        }
    }

    /// Flush any pending word immediately (called when recognition ends or new word arrives)
    private func flushPendingWord() {
        pendingWordTimer?.invalidate()
        pendingWordTimer = nil

        if let word = pendingWord {
            let info = segmentInfo(at: pendingWordIndex)
            print("[SPEECH] → SEND (flushed): \"\(word)\" conf=\(String(format: "%.2f", info.confidence))")
            delegate?.speechRecognition(didRecognizeWord: word, confidence: info.confidence,
                                        alternatives: info.alternatives, isFinal: false, isRevision: true)
            pendingWord = nil
            pendingWordIndex = -1
        }
    }

    // MARK: - Session Restart (anti-corruption)

    /// Start timer to proactively restart recognition before Apple's ~60s degradation
    private func startSessionRestartTimer() {
        sessionRestartTimer?.invalidate()
        sessionRestartTimer = Timer.scheduledTimer(
            withTimeInterval: Self.maxSessionDuration,
            repeats: false
        ) { [weak self] _ in
            self?.restartRecognitionSession()
        }
    }

    /// Seamlessly restart the recognition session.
    /// The audio engine stays running — only the recognition task is swapped.
    /// This prevents transcript corruption that occurs in long sessions.
    private func restartRecognitionSession() {
        guard isListening, let speechRecognizer = speechRecognizer else { return }

        print("[SPEECH] ♻️ Restarting recognition session (anti-corruption, \(Self.maxSessionDuration)s)")

        // Flush any pending word
        flushPendingWord()

        // Increment generation so results from old task are ignored
        sessionGeneration += 1
        let currentGeneration = sessionGeneration

        // Cancel old task and request — explicitly nil out to release audio buffers
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Create new request
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = false
        if !currentContextualStrings.isEmpty {
            newRequest.contextualStrings = currentContextualStrings
        }
        if #available(iOS 16, *) {
            newRequest.addsPunctuation = false
        }

        // Save word count before restart so we can skip replayed words.
        // The new session may replay the full old transcript before producing new words.
        preRestartWordCount = lastProcessedWordCount
        previousTranscript = ""
        isPostRestart = true

        // Timeout: if the new session doesn't catch up within 3 seconds,
        // assume it's a fresh start (user paused) and resume normal processing
        postRestartTimeout?.invalidate()
        postRestartTimeout = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isPostRestart else { return }
            print("[SPEECH] ♻️ POST-RESTART: timeout, resuming normal processing (resetting high water mark from \(self.lastProcessedWordCount) to 0)")
            self.isPostRestart = false
            // The new session started fresh without replaying old content.
            // Reset the high water mark so new words aren't dropped as "count drops".
            self.lastProcessedWordCount = 0
            self.lastProcessedWord = ""
            self.previousWords = []
        }

        // Swap request — the existing audio tap reads self.recognitionRequest,
        // so it will automatically start feeding audio to the new request
        recognitionRequest = newRequest

        // Start new recognition task (dispatch to main thread — same as startListening)
        recognitionTask = speechRecognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, self.sessionGeneration == currentGeneration else { return }
                self.handleRecognitionResult(result: result, error: error)
            }
        }

        // Schedule next restart
        startSessionRestartTimer()

        print("[SPEECH] ♻️ Recognition session restarted")
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && isListening {
            stopListening()
            delegate?.speechRecognition(didEncounterError: SpeechError.recognizerUnavailable)
        }
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case requestCreationFailed
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device"
        case .requestCreationFailed:
            return "Failed to create speech recognition request"
        case .notAuthorized:
            return "Speech recognition is not authorized"
        }
    }
}
