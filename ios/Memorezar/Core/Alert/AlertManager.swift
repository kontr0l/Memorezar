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
    private var hapticEngine: CHHapticEngine?
    private var systemSoundID: SystemSoundID = 0

    // Alert configuration
    var audioAlertEnabled = true
    var visualAlertEnabled = true
    var hapticAlertEnabled = true

    // Callback for visual alerts (UI must handle this)
    var onVisualAlert: (() -> Void)?

    // Pre-loaded audio for minimal latency
    private var isAudioPrepared = false

    // MARK: - Initialization

    private init() {
        prepareAudio()
        prepareHaptics()
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

    private func prepareAudio() {
        // Method 1: System sound (fastest, ~10ms latency)
        // Use a built-in system sound for lowest latency
        // 1057 = Tink sound, 1052 = Tweet, 1016 = Tweet high
        systemSoundID = 1057

        // Method 2: Custom audio file (backup)
        if let soundURL = Bundle.main.url(forResource: "mistake_beep", withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 0.7
                isAudioPrepared = true
            } catch {
                print("Failed to prepare audio: \(error)")
            }
        }
    }

    private func triggerAudio() {
        // Use system sound for minimum latency
        AudioServicesPlaySystemSound(systemSoundID)

        // Alternative: custom audio
        // audioPlayer?.play()
        // audioPlayer?.prepareToPlay() // Re-prepare for next play
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
        return createWAVData(samples: samples, sampleRate: Int(sampleRate))
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
