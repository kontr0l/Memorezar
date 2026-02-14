import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var showingResetAlert = false
    @State private var showingDeleteDataAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Alert Settings
                Section {
                    Toggle(isOn: $settingsStore.settings.audioAlertEnabled) {
                        Label("Sound Alerts", systemImage: "speaker.wave.2.fill")
                    }

                    if settingsStore.settings.audioAlertEnabled {
                        // Mistake Sound
                        Picker(selection: $settingsStore.settings.mistakeSound) {
                            ForEach(MistakeSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        } label: {
                            Label("Mistake Sound", systemImage: "xmark.circle")
                        }

                        Button {
                            AlertManager.shared.previewSound(settingsStore.settings.mistakeSound)
                        } label: {
                            Label("Preview Mistake Sound", systemImage: "play.circle")
                        }

                        // Correct Word Sound
                        Picker(selection: $settingsStore.settings.correctWordSound) {
                            ForEach(CorrectWordSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        } label: {
                            Label("Correct Word Sound", systemImage: "checkmark.circle")
                        }

                        if settingsStore.settings.correctWordSound != .none {
                            Button {
                                AlertManager.shared.previewCorrectSound(settingsStore.settings.correctWordSound)
                            } label: {
                                Label("Preview Correct Sound", systemImage: "play.circle")
                            }
                        }

                        // Completion Sound
                        Picker(selection: $settingsStore.settings.completionSound) {
                            ForEach(CompletionSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        } label: {
                            Label("Completion Sound", systemImage: "party.popper")
                        }

                        if settingsStore.settings.completionSound != .none {
                            Button {
                                AlertManager.shared.previewCompletionSound(settingsStore.settings.completionSound)
                            } label: {
                                Label("Preview Completion Sound", systemImage: "play.circle")
                            }
                        }
                    }

                    Toggle(isOn: $settingsStore.settings.visualAlertEnabled) {
                        Label("Visual Flash", systemImage: "lightbulb.fill")
                    }

                    Toggle(isOn: $settingsStore.settings.hapticAlertEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }

                    if settingsStore.settings.hapticAlertEnabled {
                        Button {
                            AlertManager.shared.testHaptic()
                        } label: {
                            Label("Test Haptic Feedback", systemImage: "hand.tap")
                        }
                    }

                    // Test alert button
                    Button {
                        AlertManager.shared.triggerMistakeAlert()
                    } label: {
                        Label("Test Mistake Alert", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Choose how you want to be notified during recitation. Mistake sounds play when you say the wrong word, correct sounds play after you fix a mistake, and completion sounds play when you finish.")
                }

                // Comparison Settings
                Section {
                    Toggle(isOn: $settingsStore.settings.caseSensitive) {
                        Label("Case Sensitive", systemImage: "textformat")
                    }

                    Toggle(isOn: $settingsStore.settings.ignorePunctuation) {
                        Label("Ignore Punctuation", systemImage: "textformat.abc.dottedunderline")
                    }

                    Toggle(isOn: $settingsStore.settings.ignoreFillerWords) {
                        Label("Ignore Filler Words", systemImage: "bubble.left.and.bubble.right")
                    }

                    Toggle(isOn: $settingsStore.settings.allowContractions) {
                        Label("Allow Contractions", systemImage: "arrow.right.arrow.left")
                    }
                } header: {
                    Text("Comparison")
                } footer: {
                    Text("Adjust how strictly words are compared. Filler words include \"um\", \"uh\", \"like\", etc.")
                }

                // Display Settings
                Section {
                    Toggle(isOn: $settingsStore.settings.showWordHighlighting) {
                        Label("Word Highlighting", systemImage: "highlighter")
                    }

                    Toggle(isOn: $settingsStore.settings.showProgressBar) {
                        Label("Progress Bar", systemImage: "chart.bar.fill")
                    }

                    Picker(selection: $settingsStore.settings.wordVisibility) {
                        ForEach(WordVisibility.allCases, id: \.self) { visibility in
                            Text(visibility.rawValue).tag(visibility)
                        }
                    } label: {
                        Label("Word Visibility", systemImage: "eye")
                    }

                    if settingsStore.settings.wordVisibility == .partial {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Reveal Percentage", systemImage: "percent")
                                Spacer()
                                Text("\(Int(settingsStore.settings.wordRevealPercentage))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settingsStore.settings.wordRevealPercentage, in: 0...100, step: 5)
                        }
                    }

                    Picker(selection: $settingsStore.settings.fontSize) {
                        ForEach(FontSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    } label: {
                        Label("Font Size", systemImage: "textformat.size")
                    }

                    Picker(selection: $settingsStore.settings.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    } label: {
                        Label("Theme", systemImage: "paintbrush.fill")
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Word Visibility controls whether words are shown before you speak them. Use 'Hide Until Spoken' for a memory challenge or 'Partial Reveal' to show a percentage of words.")
                }

                // Practice Settings
                Section {
                    Toggle(isOn: $settingsStore.settings.requireCorrectWord) {
                        Label("Require Correct Word", systemImage: "checkmark.circle")
                    }

                    Toggle(isOn: $settingsStore.settings.showHints) {
                        Label("Show Hints", systemImage: "lightbulb.max.fill")
                    }

                    if settingsStore.settings.showHints {
                        Stepper(value: $settingsStore.settings.hintDelay, in: 1...10, step: 0.5) {
                            HStack {
                                Label("Hint Delay", systemImage: "clock")
                                Spacer()
                                Text("\(settingsStore.settings.hintDelay, specifier: "%.1f")s")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Toggle(isOn: $settingsStore.settings.autoRestartOnCompletion) {
                        Label("Auto-Restart", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Practice")
                } footer: {
                    Text("When 'Require Correct Word' is enabled, you must say the correct word before moving on. Hints show the next expected word after a delay.")
                }

                // Statistics
                Section {
                    HStack {
                        Label("Total Sessions", systemImage: "repeat.circle")
                        Spacer()
                        Text("\(quoteStore.totalPracticeSessions)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Quotes Mastered", systemImage: "star.fill")
                        Spacer()
                        Text("\(quoteStore.masteredQuotesCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Average Accuracy", systemImage: "target")
                        Spacer()
                        Text(String(format: "%.1f%%", quoteStore.averageAccuracy * 100))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Total Practice Time", systemImage: "clock.fill")
                        Spacer()
                        Text(formatDuration(quoteStore.totalPracticeTime))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Statistics")
                }

                // Data Management
                Section {
                    Button {
                        showingResetAlert = true
                    } label: {
                        Label("Reset Settings", systemImage: "arrow.counterclockwise")
                    }

                    Button(role: .destructive) {
                        showingDeleteDataAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Data")
                }

                // About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/memorezar")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Link(destination: URL(string: "mailto:support@memorezar.app")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsStore.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .alert("Delete All Data", isPresented: $showingDeleteDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    quoteStore.clearAllData()
                }
            } message: {
                Text("This will delete all your quotes, practice history, and statistics. This action cannot be undone.")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(SettingsStore())
        .environmentObject(QuoteStore())
}
