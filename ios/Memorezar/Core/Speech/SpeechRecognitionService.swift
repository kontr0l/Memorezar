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
    func speechRecognition(didRecognizeWord word: String, isFinal: Bool)
    func speechRecognition(didEncounterError error: Error)
    func speechRecognitionDidEnd()
}

final class SpeechRecognitionService: NSObject {

    // MARK: - Properties

    weak var delegate: SpeechRecognitionDelegate?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var lastProcessedWordCount = 0
    private var previousTranscript = ""
    private var lastProcessedWord = ""  // Track the last word we processed to detect revisions

    private(set) var isListening = false

    // MARK: - Initialization

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        speechRecognizer?.delegate = self
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

    func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Stop any existing task
        stopListening()

        // Configure audio session for low latency
        // Use .playAndRecord to allow both speech recognition and alert sounds
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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

        // For iOS 16+, enable automatic punctuation
        if #available(iOS 16, *) {
            recognitionRequest.addsPunctuation = false // We don't need punctuation for comparison
        }

        // Reset tracking
        lastProcessedWordCount = 0
        previousTranscript = ""
        lastProcessedWord = ""

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        var recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate the recording format - crash occurs if channelCount is 0
        if recordingFormat.channelCount == 0 {
            // Get a valid format from the input node's input format or use a standard format
            let inputFormat = inputNode.inputFormat(forBus: 0)
            if inputFormat.channelCount > 0 {
                recordingFormat = inputFormat
            } else {
                // Use standard mono format as fallback
                guard let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
                    throw SpeechError.requestCreationFailed
                }
                recordingFormat = standardFormat
            }
        }

        // Install tap to capture audio - use small buffer for lower latency
        inputNode.installTap(onBus: 0, bufferSize: 256, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    func stopListening() {
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

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        delegate?.speechRecognitionDidEnd()
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

        // Split into words
        let words = transcript.split(separator: " ").map(String.init)

        // Process new words
        // For interim results, we process words that appear stable
        // For final results, we process all remaining words

        if isFinal {
            // Final result - process all words from where we left off
            // Guard against transcript revision where word count decreased
            if lastProcessedWordCount < words.count {
                for i in lastProcessedWordCount..<words.count {
                    delegate?.speechRecognition(didRecognizeWord: words[i], isFinal: true)
                }
            }
            lastProcessedWordCount = 0
            previousTranscript = ""
            lastProcessedWord = ""
        } else {
            // Interim result - process ALL words including the last one
            // This eliminates the 1-word lag that occurs when waiting for "stable" words
            // The comparator handles any revisions (changed words) appropriately

            // Handle transcript revision (word count can decrease if recognizer revises)
            // When count drops, also update lastProcessedWord to prevent false revision detection.
            // This stops duplicate words being sent when recognizer changes e.g. "juxta position" → "juxtaposition"
            if words.count < lastProcessedWordCount {
                lastProcessedWordCount = words.count
                lastProcessedWord = words.last ?? ""
            }

            // Process any new words
            if words.count > lastProcessedWordCount {
                for i in lastProcessedWordCount..<words.count {
                    delegate?.speechRecognition(didRecognizeWord: words[i], isFinal: false)
                }
                lastProcessedWordCount = words.count
                lastProcessedWord = words.last ?? ""
            } else if words.count > 0 && words.count == lastProcessedWordCount {
                // Same word count - check if the last word was revised by the recognizer
                let currentLastWord = words[words.count - 1]
                if currentLastWord != lastProcessedWord && !lastProcessedWord.isEmpty {
                    // Last word changed - reprocess it (handles partial word completion)
                    delegate?.speechRecognition(didRecognizeWord: currentLastWord, isFinal: false)
                    lastProcessedWord = currentLastWord
                }
            }

            previousTranscript = transcript
        }
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
