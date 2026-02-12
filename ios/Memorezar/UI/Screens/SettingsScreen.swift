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
                        Label("Sound Alert", systemImage: "speaker.wave.2.fill")
                    }

                    Toggle(isOn: $settingsStore.settings.visualAlertEnabled) {
                        Label("Visual Flash", systemImage: "lightbulb.fill")
                    }

                    Toggle(isOn: $settingsStore.settings.hapticAlertEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }

                    // Test alert button
                    Button {
                        AlertManager.shared.triggerMistakeAlert()
                    } label: {
                        Label("Test Alert", systemImage: "play.circle")
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Choose how you want to be notified when you make a mistake during recitation.")
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
                }

                // Practice Settings
                Section {
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
                    Text("Hints show the next expected word after a delay. Auto-restart begins a new session when you complete a quote.")
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
                    // Note: Would need to add a method to QuoteStore to clear all data
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
