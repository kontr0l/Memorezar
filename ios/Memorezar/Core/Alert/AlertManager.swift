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

    private var errorPlayer: AVAudioPlayer?
    private var successPlayer: AVAudioPlayer?
    private var resultPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var hapticEngine: CHHapticEngine?

    // Cached default theme sounds (loaded once)
    private var defaultSounds: [SoundTheme.SoundEvent: Data] = [:]
    // Cached meme theme sounds (arrays of Data per category)
    private var memeSounds: [SoundTheme.SoundEvent: [Data]] = [:]

    // Alert configuration
    var audioAlertEnabled = true
    var visualAlertEnabled = true
    var hapticAlertEnabled = true
    var soundTheme: SoundTheme = .default {
        didSet {
            if soundTheme != oldValue {
                prepareCurrentSounds()
            }
        }
    }

    // Callback for visual alerts (UI must handle this)
    var onVisualAlert: (() -> Void)?

    private var isErrorPrepared = false
    private var isSuccessPrepared = false

    // MARK: - Initialization

    private init() {
        configureAudioSession()
        loadAllSounds()
        prepareHaptics()
        prepareCurrentSounds()
    }

    /// Configure the audio session so sounds play even when recording
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Sound Loading

    /// Load all sound files from bundle into memory
    private func loadAllSounds() {
        // Load default theme WAV files
        for event in [SoundTheme.SoundEvent.error, .success, .resultFail, .resultWin] {
            if let url = Bundle.main.url(forResource: event.defaultFile, withExtension: nil, subdirectory: "Sounds"),
               let data = try? Data(contentsOf: url) {
                defaultSounds[event] = data
            } else {
                print("[AlertManager] Missing default sound: Sounds/\(event.defaultFile)")
            }
        }

        // Load meme theme sounds from folders
        for event in [SoundTheme.SoundEvent.error, .success, .resultFail, .resultWin] {
            var sounds: [Data] = []
            let folderName = event.folderName

            if let folderURL = Bundle.main.url(forResource: folderName, withExtension: nil, subdirectory: "Sounds") {
                if let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
                    for file in files {
                        let ext = file.pathExtension.lowercased()
                        guard ["mp3", "wav", "m4a", "aac"].contains(ext) else { continue }
                        if let data = try? Data(contentsOf: file) {
                            sounds.append(data)
                        }
                    }
                }
            }
            if !sounds.isEmpty {
                memeSounds[event] = sounds
            } else {
                print("[AlertManager] No meme sounds found for: Sounds/\(folderName)/")
            }
        }
    }

    /// Get sound data for the current theme and event
    private func soundData(for event: SoundTheme.SoundEvent) -> Data? {
        switch soundTheme {
        case .default:
            return defaultSounds[event]
        case .memes:
            guard let sounds = memeSounds[event], !sounds.isEmpty else {
                // Fallback to default
                return defaultSounds[event]
            }
            return sounds.randomElement()
        }
    }

    /// Prepare error and success sounds for low-latency playback
    private func prepareCurrentSounds() {
        // Prepare error sound
        if let data = soundData(for: .error) {
            do {
                errorPlayer = try AVAudioPlayer(data: data)
                errorPlayer?.prepareToPlay()
                errorPlayer?.volume = 0.8
                isErrorPrepared = true
            } catch {
                print("Failed to prepare error sound: \(error)")
                isErrorPrepared = false
            }
        }

        // Prepare success sound
        if let data = soundData(for: .success) {
            do {
                successPlayer = try AVAudioPlayer(data: data)
                successPlayer?.prepareToPlay()
                successPlayer?.volume = 0.5
                isSuccessPrepared = true
            } catch {
                print("Failed to prepare success sound: \(error)")
                isSuccessPrepared = false
            }
        }
    }

    // MARK: - Alert Triggering

    /// Trigger all enabled alerts when user speaks wrong word
    func triggerMistakeAlert(audioPauseHandler: (pause: () -> Void, resume: () -> Void)? = nil) {
        if hapticAlertEnabled {
            audioPauseHandler?.pause()
            triggerHaptic()
            if let resume = audioPauseHandler?.resume {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    resume()
                }
            }
        }

        if audioAlertEnabled {
            triggerErrorSound()
        }

        if visualAlertEnabled {
            DispatchQueue.main.async { [weak self] in
                self?.onVisualAlert?()
            }
        }
    }

    /// Play error sound (mistake during recitation)
    private func triggerErrorSound() {
        if soundTheme == .memes {
            // Memes: pick random each time
            playRandomSound(for: .error, volume: 0.8)
        } else if isErrorPrepared, let player = errorPlayer {
            player.currentTime = 0
            player.play()
            DispatchQueue.global(qos: .userInitiated).async { [weak player] in
                player?.prepareToPlay()
            }
        }
    }

    /// Play success sound (correct word after a mistake)
    func triggerCorrectWordSound() {
        guard audioAlertEnabled else { return }

        if soundTheme == .memes {
            playRandomSound(for: .success, volume: 0.5)
        } else if isSuccessPrepared, let player = successPlayer {
            player.currentTime = 0
            player.play()
            DispatchQueue.global(qos: .userInitiated).async { [weak player] in
                player?.prepareToPlay()
            }
        }
    }

    /// Play result win sound (accuracy >= 70% or master mode pass)
    func triggerResultWinSound() {
        guard audioAlertEnabled else { return }
        playSound(for: .resultWin, volume: 0.9)
    }

    /// Play result fail sound (accuracy < 70% or master mode fail)
    func triggerResultFailSound() {
        guard audioAlertEnabled else { return }
        playSound(for: .resultFail, volume: 0.9)
    }

    /// Convenience: play the right result sound based on accuracy
    func triggerResultSound(accuracy: Double) {
        if accuracy >= 0.7 {
            triggerResultWinSound()
        } else {
            triggerResultFailSound()
        }
    }

    /// Stop any currently playing result sound
    func stopResultSound() {
        resultPlayer?.stop()
        resultPlayer = nil
    }

    // MARK: - Sound Playback Helpers

    /// Play a sound for the given event (creates a new player each time — for result sounds)
    private func playSound(for event: SoundTheme.SoundEvent, volume: Float) {
        guard let data = soundData(for: event) else { return }
        do {
            resultPlayer = try AVAudioPlayer(data: data)
            resultPlayer?.volume = volume
            resultPlayer?.prepareToPlay()
            resultPlayer?.play()
        } catch {
            print("Failed to play \(event) sound: \(error)")
        }
    }

    /// Play a random meme sound for the given event
    private func playRandomSound(for event: SoundTheme.SoundEvent, volume: Float) {
        guard let data = soundData(for: event) else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            // Keep a strong reference so it doesn't get deallocated mid-play
            if event == .error {
                errorPlayer = player
            } else if event == .success {
                successPlayer = player
            } else {
                resultPlayer = player
            }
        } catch {
            print("Failed to play random \(event) sound: \(error)")
        }
    }

    /// Preview a sound theme (plays the error sound as sample)
    func previewTheme(_ theme: SoundTheme) {
        configureAudioSession()
        let event = SoundTheme.SoundEvent.error
        let data: Data?
        switch theme {
        case .default:
            data = defaultSounds[event]
        case .memes:
            data = memeSounds[event]?.randomElement() ?? defaultSounds[event]
        }
        guard let soundData = data else { return }
        do {
            previewPlayer = try AVAudioPlayer(data: soundData)
            previewPlayer?.volume = 0.8
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
        } catch {
            print("Failed to preview theme: \(error)")
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

            try hapticEngine?.start()

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
        if let engine = hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)

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

    /// Test haptic feedback (for settings screen)
    func testHaptic() {
        triggerHaptic()
    }

    // MARK: - Visual Alert Helpers

    static func flashAnimation() -> (duration: Double, color: Color) {
        return (duration: 0.15, color: .red)
    }
}

// Color extension for SwiftUI compatibility
import SwiftUI

extension Color {
    static let mistakeFlash = Color.red.opacity(0.3)
}
