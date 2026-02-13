import Foundation
import AVFoundation
import UIKit
import CoreHaptics

/// Coordinates all alert types for immediate feedback when user makes a mistake
/// Target: < 50ms from detection to alert
final class AlertManager {

    // MARK: - Singleton

    static let shared = AlertManager()

    // MARK: - Properties

    private var audioPlayer: AVAudioPlayer?
    private var correctWordPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?
    private var hapticEngine: CHHapticEngine?
    private var systemSoundID: SystemSoundID = 0
    private var cachedMistakeSoundData: [MistakeSound: Data] = [:]
    private var cachedCorrectSoundData: [CorrectWordSound: Data] = [:]
    private var cachedCompletionSoundData: [CompletionSound: Data] = [:]
    private var currentSound: MistakeSound = .explosion1

    // Alert configuration
    var audioAlertEnabled = true
    var visualAlertEnabled = true
    var hapticAlertEnabled = true
    var mistakeSound: MistakeSound = .explosion1 {
        didSet {
            if mistakeSound != oldValue {
                prepareSound(mistakeSound)
            }
        }
    }
    var correctWordSound: CorrectWordSound = .none {
        didSet {
            if correctWordSound != oldValue {
                prepareCorrectWordSound(correctWordSound)
            }
        }
    }
    var completionSound: CompletionSound = .applause {
        didSet {
            if completionSound != oldValue {
                prepareCompletionSound(completionSound)
            }
        }
    }

    // Callback for visual alerts (UI must handle this)
    var onVisualAlert: (() -> Void)?

    // Pre-loaded audio for minimal latency
    private var isAudioPrepared = false
    private var isCorrectSoundPrepared = false
    private var isCompletionSoundPrepared = false

    // MARK: - Initialization

    private init() {
        prepareAllSounds()
        prepareHaptics()
        prepareSound(mistakeSound)
        prepareCorrectWordSound(correctWordSound)
        prepareCompletionSound(completionSound)
    }

    // MARK: - Alert Triggering

    /// Trigger all enabled alerts immediately
    /// Called when user speaks wrong word
    func triggerMistakeAlert() {
        // Run all alerts in parallel for minimum latency
        if hapticAlertEnabled {
            triggerHaptic()
        }

        if audioAlertEnabled {
            triggerAudio()
        }

        if visualAlertEnabled {
            DispatchQueue.main.async { [weak self] in
                self?.onVisualAlert?()
            }
        }
    }

    // MARK: - Audio Alert

    /// Pre-generate all sound effects for instant playback
    private func prepareAllSounds() {
        // Mistake sounds
        for sound in MistakeSound.allCases {
            if let data = generateMistakeSoundData(for: sound) {
                cachedMistakeSoundData[sound] = data
            }
        }

        // Correct word sounds
        for sound in CorrectWordSound.allCases {
            if let params = sound.soundParameters,
               let data = generateSound(frequency: params.frequency, duration: params.duration, waveform: params.waveform) {
                cachedCorrectSoundData[sound] = data
            }
        }

        // Completion sounds
        for sound in CompletionSound.allCases {
            if let params = sound.soundParameters,
               let data = generateSound(frequency: params.frequency, duration: params.duration, waveform: params.waveform) {
                cachedCompletionSoundData[sound] = data
            }
        }
    }

    /// Prepare a specific mistake sound for playback
    private func prepareSound(_ sound: MistakeSound) {
        currentSound = sound

        guard let data = cachedMistakeSoundData[sound] else {
            // Fallback to system sound
            systemSoundID = 1057
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.8
            isAudioPrepared = true
        } catch {
            print("Failed to prepare sound: \(error)")
            // Fallback to system sound
            systemSoundID = 1057
        }
    }

    /// Prepare correct word sound for playback
    private func prepareCorrectWordSound(_ sound: CorrectWordSound) {
        guard sound != .none, let data = cachedCorrectSoundData[sound] else {
            isCorrectSoundPrepared = false
            return
        }

        do {
            correctWordPlayer = try AVAudioPlayer(data: data)
            correctWordPlayer?.prepareToPlay()
            correctWordPlayer?.volume = 0.5  // Softer than mistake sound
            isCorrectSoundPrepared = true
        } catch {
            print("Failed to prepare correct word sound: \(error)")
            isCorrectSoundPrepared = false
        }
    }

    /// Prepare completion sound for playback
    private func prepareCompletionSound(_ sound: CompletionSound) {
        guard sound != .none, let data = cachedCompletionSoundData[sound] else {
            isCompletionSoundPrepared = false
            return
        }

        do {
            completionPlayer = try AVAudioPlayer(data: data)
            completionPlayer?.prepareToPlay()
            completionPlayer?.volume = 0.9
            isCompletionSoundPrepared = true
        } catch {
            print("Failed to prepare completion sound: \(error)")
            isCompletionSoundPrepared = false
        }
    }

    private func triggerAudio() {
        if isAudioPrepared, let player = audioPlayer {
            player.currentTime = 0
            player.play()
            // Re-prepare for next play (non-blocking)
            DispatchQueue.global(qos: .userInitiated).async { [weak player] in
                player?.prepareToPlay()
            }
        } else {
            // Fallback: system sound
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }

    /// Trigger correct word sound
    func triggerCorrectWordSound() {
        guard audioAlertEnabled, correctWordSound != .none, isCorrectSoundPrepared,
              let player = correctWordPlayer else { return }

        player.currentTime = 0
        player.play()
        // Re-prepare for next play
        DispatchQueue.global(qos: .userInitiated).async { [weak player] in
            player?.prepareToPlay()
        }
    }

    /// Trigger completion sound (applause, fanfare, etc.)
    func triggerCompletionSound() {
        guard audioAlertEnabled, completionSound != .none, isCompletionSoundPrepared,
              let player = completionPlayer else { return }

        player.currentTime = 0
        player.play()
    }

    /// Generate sound data for a specific mistake sound
    private func generateMistakeSoundData(for sound: MistakeSound) -> Data? {
        let params = sound.soundParameters
        return generateSound(
            frequency: params.frequency,
            duration: params.duration,
            waveform: params.waveform
        )
    }

    /// Generate a sound with specified parameters
    private func generateSound(frequency: Double, duration: Double, waveform: SoundWaveform) -> Data? {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)

        // Generate waveform
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample: Float

            switch waveform {
            case .sine:
                sample = Float(sin(2 * .pi * frequency * t))
            case .square:
                sample = Float(sin(2 * .pi * frequency * t) > 0 ? 1 : -1)
            case .noise:
                // Filtered noise with frequency-based envelope
                let noise = Float.random(in: -1...1)
                let envelope = Float(exp(-t * (frequency / 20)))
                sample = noise * envelope
            }

            // Apply envelope (attack/decay for punchier sound)
            let attackFrames = Int(sampleRate * 0.005) // 5ms attack
            let releaseStart = frameCount - Int(sampleRate * duration * 0.3) // 30% release

            let envelope: Float
            if i < attackFrames {
                envelope = Float(i) / Float(attackFrames)
            } else if i > releaseStart {
                let releaseProgress = Float(i - releaseStart) / Float(frameCount - releaseStart)
                envelope = 1.0 - releaseProgress
            } else {
                envelope = 1.0
            }

            samples[i] = sample * envelope * 0.85
        }

        return Self.createWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    /// Preview a mistake sound (for settings screen)
    func previewSound(_ sound: MistakeSound) {
        guard let data = cachedMistakeSoundData[sound] else { return }
        do {
            let previewPlayer = try AVAudioPlayer(data: data)
            previewPlayer.volume = 0.8
            previewPlayer.play()
        } catch {
            print("Failed to preview sound: \(error)")
        }
    }

    /// Preview a correct word sound (for settings screen)
    func previewCorrectSound(_ sound: CorrectWordSound) {
        guard sound != .none, let data = cachedCorrectSoundData[sound] else { return }
        do {
            let previewPlayer = try AVAudioPlayer(data: data)
            previewPlayer.volume = 0.5
            previewPlayer.play()
        } catch {
            print("Failed to preview sound: \(error)")
        }
    }

    /// Preview a completion sound (for settings screen)
    func previewCompletionSound(_ sound: CompletionSound) {
        guard sound != .none, let data = cachedCompletionSoundData[sound] else { return }
        do {
            let previewPlayer = try AVAudioPlayer(data: data)
            previewPlayer.volume = 0.9
            previewPlayer.play()
        } catch {
            print("Failed to preview sound: \(error)")
        }
    }

    // MARK: - Haptic Feedback

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.playsHapticsOnly = true

            // Start and stop to prepare
            try hapticEngine?.start()

            // Set up auto-restart handler
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.restartHapticEngine()
            }

            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartHapticEngine()
            }

        } catch {
            print("Failed to prepare haptics: \(error)")
        }
    }

    private func restartHapticEngine() {
        do {
            try hapticEngine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
        }
    }

    private func triggerHaptic() {
        // Method 1: Core Haptics (most precise, ~5ms latency)
        if let engine = hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                // Create a sharp, noticeable pattern
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)

                // Double tap pattern for clear feedback
                let event1 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [sharpness, intensity],
                    relativeTime: 0
                )
                let event2 = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [sharpness, intensity],
                    relativeTime: 0.1
                )

                let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                print("Haptic playback failed: \(error)")
            }
        }

        // Fallback: UIKit haptics
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - Visual Alert Helpers

    /// Create a visual flash effect
    /// Returns the animation parameters for SwiftUI
    static func flashAnimation() -> (duration: Double, color: Color) {
        return (duration: 0.15, color: .red)
    }
}

// MARK: - Audio Generation

extension AlertManager {

    /// Generate a simple beep sound programmatically
    /// (Used if no audio file is bundled)
    static func generateBeepSound() -> Data? {
        let sampleRate: Double = 44100
        let duration: Double = 0.05 // 50ms
        let frequency: Double = 880  // A5 note

        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)

        // Generate sine wave with envelope
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let amplitude = Float(sin(2 * .pi * frequency * t))

            // Apply envelope (quick attack, quick decay)
            let envelope: Float
            let attackFrames = Int(sampleRate * 0.005) // 5ms attack
            let releaseFrames = Int(sampleRate * 0.01) // 10ms release

            if i < attackFrames {
                envelope = Float(i) / Float(attackFrames)
            } else if i > frameCount - releaseFrames {
                envelope = Float(frameCount - i) / Float(releaseFrames)
            } else {
                envelope = 1.0
            }

            samples[i] = amplitude * envelope * 0.7
        }

        // Convert to WAV data
        return Self.createWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    private static func createWAVData(samples: [Float], sampleRate: Int) -> Data? {
        var data = Data()

        // WAV header
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate * Int(numChannels) * Int(bitsPerSample / 8))
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        let dataSize = Int32(samples.count * Int(bitsPerSample / 8))
        let fileSize = Int32(36 + dataSize)

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // Convert float samples to Int16
        for sample in samples {
            let intSample = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
    }
}

// Color extension for SwiftUI compatibility
import SwiftUI

extension Color {
    static let mistakeFlash = Color.red.opacity(0.3)
}
