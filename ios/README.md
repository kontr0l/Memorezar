# Memorezar iOS App

Native iOS app for real-time memorization practice with instant feedback.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Features

- **Real-time Speech Recognition**: Uses Apple's Speech framework for streaming word-by-word recognition
- **Instant Feedback**: < 300ms latency from mistake detection to alert
- **Multiple Alert Types**: Audio (system sound), Visual (screen flash), Haptic (Core Haptics)
- **Word Comparison Engine**: Handles case insensitivity, punctuation, contractions, filler words, and homophones
- **Quote Library**: Store and organize quotes by category
- **Progress Tracking**: Track practice sessions, accuracy, and mastery levels
- **SwiftUI Interface**: Modern, native iOS UI

## Project Structure

```
ios/
├── Memorezar.xcodeproj/     # Xcode project
└── Memorezar/
    ├── MemorezerApp.swift   # App entry point
    ├── ContentView.swift    # Main tab view
    ├── Info.plist           # App configuration
    │
    ├── Core/
    │   ├── Speech/
    │   │   └── SpeechRecognitionService.swift   # Streaming speech recognition
    │   ├── Comparison/
    │   │   └── WordComparator.swift             # Word-by-word comparison
    │   └── Alert/
    │       └── AlertManager.swift               # Audio/visual/haptic alerts
    │
    ├── Data/
    │   ├── Models/
    │   │   ├── Quote.swift                      # Quote data model
    │   │   └── Settings.swift                   # App settings model
    │   └── Storage/
    │       ├── QuoteStore.swift                 # Quote persistence
    │       └── SettingsStore.swift              # Settings persistence
    │
    ├── UI/
    │   ├── Screens/
    │   │   ├── HomeScreen.swift                 # Home dashboard
    │   │   ├── QuoteLibraryScreen.swift         # Quote management
    │   │   ├── RecitationScreen.swift           # Practice mode
    │   │   ├── SettingsScreen.swift             # App settings
    │   │   └── QuoteInputView.swift             # Add/edit quotes
    │   ├── Components/                          # Reusable UI components
    │   └── ViewModels/
    │       └── RecitationViewModel.swift        # Recitation logic
    │
    ├── Resources/
    │   └── Assets.xcassets/                     # App icons, colors
    │
    └── Preview Content/                         # SwiftUI previews
```

## Building

1. Open `Memorezar.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on a physical device (speech recognition requires real microphone)

## Architecture

### Speech Recognition Pipeline

```
Audio Input → SpeechRecognitionService → Word Callback → WordComparator → AlertManager
     ↓              ↓                        ↓               ↓              ↓
  AVAudioEngine   SFSpeechRecognizer    Word-by-word    Match/Mismatch   Alert
  (256 buffer)    (interim results)      streaming       detection      triggers
```

### Performance Targets

| Metric | Target | Implementation |
|--------|--------|----------------|
| Audio buffer | 256 samples | Low-latency capture |
| Speech recognition | Interim results | Real-time word detection |
| Word comparison | < 1ms | Optimized string matching |
| Alert trigger | < 50ms | System sounds + Core Haptics |
| Total latency | < 300ms | End-to-end from speech to alert |

## Key Technical Decisions

1. **Apple Speech Framework**: Native iOS speech recognition with interim results support
2. **System Sounds**: AudioServicesPlaySystemSound for minimal audio latency
3. **Core Haptics**: CHHapticEngine for precise haptic timing
4. **UserDefaults**: Simple persistence for quotes and settings (suitable for typical usage)
5. **SwiftUI**: Modern declarative UI with @MainActor for thread safety

## Permissions

The app requires:
- **Microphone**: To capture speech for recognition
- **Speech Recognition**: To transcribe speech to text

These are declared in Info.plist with user-friendly descriptions.

## Testing on Device

Speech recognition features require a physical device with a microphone. The iOS Simulator does not support real-time speech recognition testing.
