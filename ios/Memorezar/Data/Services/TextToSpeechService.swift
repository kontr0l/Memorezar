import AVFoundation
import CryptoKit

/// Generates natural-sounding speech via OpenAI TTS (proxied through Supabase Edge Function).
/// Caches audio locally so repeat plays are instant and free.
final class TextToSpeechService: NSObject, ObservableObject {

    static let shared = TextToSpeechService()

    @Published var isSpeaking = false
    @Published var isLoading = false
    @Published var error: String?

    /// Called when playback finishes naturally (not stopped by user)
    var onFinish: (() -> Void)?

    private var player: AVAudioPlayer?
    private let session = URLSession.shared

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Speak the given text. Checks cache first, otherwise calls the TTS edge function.
    func speak(_ text: String, language: String = "en") {
        stop()
        error = nil

        let cacheKey = self.cacheKey(text: text, language: language)

        // Check cache first
        if let cachedData = loadFromCache(key: cacheKey) {
            playAudio(cachedData)
            return
        }

        // Fetch from edge function
        isLoading = true
        Task {
            do {
                let data = try await fetchTTS(text: text, language: language)
                saveToCache(key: cacheKey, data: data)
                await MainActor.run {
                    self.isLoading = false
                    self.playAudio(data)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error.localizedDescription
                    print("[TTS] Error: \(error)")
                }
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isSpeaking = false
        isLoading = false
    }

    func togglePlayback() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            isSpeaking = false
        } else {
            player.play()
            isSpeaking = true
        }
    }

    // MARK: - Network

    private func fetchTTS(text: String, language: String) async throws -> Data {
        let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/tts")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["text": text, "language": language]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[TTS] Server error \(httpResponse.statusCode): \(message)")
            throw TTSError.serverError(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw TTSError.emptyResponse
        }

        return data
    }

    // MARK: - Playback

    private func playAudio(_ data: Data) {
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            // Voice recitation leaves the session in
            //   .playAndRecord + mode .measurement + .defaultToSpeaker
            // — .measurement aggressively attenuates output (great for ASR,
            // terrible for playback), and reconfiguring on top of a still-
            // releasing session sometimes sticks the route to the earpiece.
            // Explicitly deactivate first, then set .playback + .spokenAudio
            // (optimized for TTS; guaranteed to route to the loud speaker
            // and clear any prior mode).
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
            #endif

            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.delegate = self
            audioPlayer.volume = 1.0               // defend against any stale level
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
            isSpeaking = true

            #if os(iOS)
            // Diagnostic: confirm the loud speaker won the route. If you see
            // "Receiver" (earpiece) here while listening quietly, the session
            // handoff still regressed and the category change got dropped.
            let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
                .map { "\($0.portType.rawValue) (\($0.portName))" }
                .joined(separator: ", ")
            print("[TTS] Output route: \(outputs)")
            #endif
        } catch {
            print("[TTS] Playback error: \(error)")
            self.error = "Playback failed"
        }
    }

    // MARK: - Cache

    private var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("tts_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheKey(text: String, language: String) -> String {
        let input = "\(language):\(text)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromCache(key: String) -> Data? {
        let url = cacheDirectory.appendingPathComponent("\(key).aac")
        return try? Data(contentsOf: url)
    }

    private func saveToCache(key: String, data: Data) {
        let url = cacheDirectory.appendingPathComponent("\(key).aac")
        try? data.write(to: url)
    }

    // MARK: - AVAudioPlayerDelegate

    // Using NSObject + AVAudioPlayerDelegate for completion callbacks
}

// MARK: - AVAudioPlayerDelegate

extension TextToSpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onFinish?()
        }
    }
}

// MARK: - Errors

enum TTSError: LocalizedError {
    case networkError
    case serverError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error"
        case .serverError(let code): return "Server error (\(code))"
        case .emptyResponse: return "No audio received"
        }
    }
}
