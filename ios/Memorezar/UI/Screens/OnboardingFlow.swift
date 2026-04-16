import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: OnboardingStep = .modeChoice
    @State private var selectedMode: MemorizationMode = .voice
    @State private var firstLetterEnabled = false
    @State private var showPractice = false
    @State private var wordHidden = false

    private enum OnboardingStep {
        case modeChoice
        case firstLetterChoice
    }

    /// Localized tutorial words — used for the quote, previews, and display text
    private var tutorialWords: [String] {
        String(localized: "Happy birthday to you").split(separator: " ").map(String.init)
    }

    /// Display string for the tutorial phrase (quoted, bold italic)
    private var tutorialPhrase: String {
        "\"\(tutorialWords.joined(separator: " "))\""
    }

    /// Transient quote — revealLevel 2 so slider starts at 50% (no animation jump)
    private var tutorialQuote: Quote {
        Quote(title: String(localized: "Tutorial"), text: tutorialWords.joined(separator: " "), revealLevel: 2)
    }

    private let dividerColor = Color(.separator)

    var body: some View {
        NavigationStack {
            Group {
                if showPractice {
                    Color(.systemBackground)
                } else {
                    switch step {
                    case .modeChoice:
                        modeChoiceScreen
                    case .firstLetterChoice:
                        firstLetterChoiceScreen
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
        .fullScreenCover(isPresented: $showPractice, onDismiss: {
            tutorialStore.hasCompletedOnboarding = true
        }) {
            RecitationScreen(quote: tutorialQuote, isTutorialMode: true)
        }
    }

    // MARK: - Step 1: Voice or Typing

    /// Shared top spacing so character + title land at the same Y on both screens
    private let topInset: CGFloat = 60

    private var modeChoiceScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Spacer().frame(height: topInset)
                BrainCharacterView(character: .pray1, size: 130)
                Text("How do you want to practice?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("You can always change this later.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal)

            tSplitPicker(
                left: optionCell(icon: "mic.fill", title: String(localized: "Voice"), color: .blue),
                right: optionCell(icon: "keyboard", title: String(localized: "Typing"), color: .indigo),
                onLeft: {
                    selectedMode = .voice
                    step = .firstLetterChoice
                },
                onRight: {
                    selectedMode = .typing
                    step = .firstLetterChoice
                }
            )
        }
    }

    // MARK: - Step 2: T-split with colored backgrounds

    private var firstLetterChoiceScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Spacer().frame(height: topInset)
                BrainCharacterView(character: .pray2, size: 130)
                Text(selectedMode == .voice
                     ? "How should we hide the words?"
                     : "How much do you want to type?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if selectedMode == .voice {
                    VStack(spacing: 6) {
                        Text("Let's try")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Text(tutorialPhrase)
                            .font(.callout.bold().italic())
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 6) {
                        Text("Let's try")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        ZStack {
                            centeredWordRow(hiddenWord: false)
                                .opacity(wordHidden ? 0 : 1)
                            centeredWordRow(hiddenWord: true)
                                .opacity(wordHidden ? 1 : 0)
                        }
                        .id("wordFade-\(step)")
                        .onAppear {
                            wordHidden = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    wordHidden = true
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            // T-split with colored backgrounds
            VStack(spacing: 0) {
                dividerColor.frame(height: 0.5)

                HStack(spacing: 0) {
                    // Left: Normal mode
                    Button {
                        firstLetterEnabled = false
                        applySettingsAndStart()
                    } label: {
                        VStack(spacing: 0) {
                            Spacer()
                            if selectedMode == .typing {
                                typingPreview(word: tutorialWords[0], fullWord: true)
                            } else {
                                wordPreview(words: [
                                    (tutorialWords[0], .hidden),
                                    (tutorialWords[1], .full),
                                    (tutorialWords[2], .hidden),
                                    (tutorialWords[3], .full),
                                ])
                            }
                            Spacer()
                            Text("Normal")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue.opacity(0.06))
                    }
                    .buttonStyle(.plain)

                    dividerColor.frame(width: 0.5)

                    // Right: First Letter mode
                    Button {
                        firstLetterEnabled = true
                        applySettingsAndStart()
                    } label: {
                        VStack(spacing: 0) {
                            Spacer()
                            if selectedMode == .typing {
                                typingPreview(word: tutorialWords[0], fullWord: false)
                            } else {
                                wordPreview(words: [
                                    (tutorialWords[0], .firstLetter),
                                    (tutorialWords[1], .firstLetter),
                                    (tutorialWords[2], .firstLetter),
                                    (tutorialWords[3], .firstLetter),
                                ])
                            }
                            Spacer()
                            Text("First Letter")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.indigo.opacity(0.06))
                    }
                    .buttonStyle(.plain)
                }

                dividerColor.frame(height: 0.5)
                Button {
                    step = .modeChoice
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Centered Word Row (for top section)

    private func centeredWordRow(hiddenWord: Bool) -> some View {
        let words = tutorialWords
        return HStack(spacing: -8) {
            WordView(
                word: words[0],
                state: .pending,
                isCurrentWord: false,
                fontSize: 20,
                isVisible: !hiddenWord,
                displayMode: hiddenWord ? .hidden : .full
            )
            .padding(.trailing, 5)
            ForEach(Array(words.dropFirst()), id: \.self) { word in
                WordView(
                    word: word,
                    state: .pending,
                    isCurrentWord: false,
                    fontSize: 20,
                    isVisible: true,
                    displayMode: .full
                )
            }
        }
    }

    // MARK: - Word Preview (compact, for T-split cells)

    private func wordPreview(words: [(String, WordDisplayMode)], fontSize: CGFloat = 20) -> some View {
        FlowLayout(spacing: 0) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, item in
                let (word, mode) = item
                let isFullyVisible: Bool = {
                    if case .full = mode { return true }
                    return false
                }()
                WordView(
                    word: word,
                    state: .pending,
                    isCurrentWord: false,
                    fontSize: fontSize,
                    isVisible: isFullyVisible,
                    displayMode: mode
                )
            }
        }
        .padding(10)
        .padding(.horizontal, 10)
    }

    // MARK: - Typing Preview (for typing mode T-split cells)

    /// Shows grey letters above dashes to illustrate what you'd type.
    /// `fullWord: true` = type the whole word, `fullWord: false` = type only first letter.
    private func typingPreview(word: String, fullWord: Bool) -> some View {
        let letters = fullWord ? Array(word) : [word.first!]
        let description = fullWord
            ? String(localized: "Type full\nmissing word")
            : String(localized: "Type only\nfirst letter")

        return VStack(spacing: 12) {
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                // Grey letters
                HStack(spacing: 4) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 22, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .frame(width: 20)
                    }
                }
                // Dashes below
                HStack(spacing: 4) {
                    ForEach(0..<letters.count, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 20, height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Simple Option Cell (for step 1)

    private func optionCell(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(color)
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.primary)
        }
    }

    // MARK: - T-Split Picker (step 1 only)

    private func tSplitPicker<L: View, R: View>(
        left: L,
        right: R,
        onLeft: @escaping () -> Void,
        onRight: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            dividerColor.frame(height: 0.5)

            HStack(spacing: 0) {
                Button(action: onLeft) {
                    left
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue.opacity(0.06))
                }
                .buttonStyle(.plain)

                dividerColor.frame(width: 0.5)

                Button(action: onRight) {
                    right
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.indigo.opacity(0.06))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Apply & Launch

    private func applySettingsAndStart() {
        settingsStore.settings.defaultMemorizationMode = selectedMode
        settingsStore.settings.firstLetterModeEnabled = firstLetterEnabled
        showPractice = true
    }
}
