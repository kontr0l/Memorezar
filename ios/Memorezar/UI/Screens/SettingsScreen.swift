import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @EnvironmentObject var authService: AuthService
    @State private var showingResetAlert = false
    @State private var showingDeleteDataAlert = false
    @State private var showFlash = false
    @State private var showAuthSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Alert Settings
                Section {
                    Toggle(isOn: $settingsStore.settings.audioAlertEnabled) {
                        Label("Sound Alerts", systemImage: "speaker.wave.2.fill")
                    }

                    if settingsStore.settings.audioAlertEnabled {
                        Picker(selection: $settingsStore.settings.soundTheme) {
                            ForEach(SoundTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        } label: {
                            Label("Sound Theme", systemImage: "music.note.list")
                        }
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
                        Label("Test Mistake Alert", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Choose how you want to be notified during recitation. Default plays clean tones, Memes plays random funny sounds.")
                }

                // Display Settings
                Section {
                    Picker(selection: $settingsStore.settings.defaultMemorizationMode) {
                        ForEach([MemorizationMode.voice, .typing, .firstLetter, .multipleChoice], id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    } label: {
                        Label("Default Mode", systemImage: "rectangle.3.group")
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

                // Statistics
                Section {
                    HStack {
                        Label("Total Sessions", systemImage: "repeat.circle")
                        Spacer()
                        Text("\(quoteStore.totalPracticeSessions)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Quotes Mastered", systemImage: "crown.fill")
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

                // Account
                Section {
                    if authService.isSignedIn {
                        HStack {
                            Label(authService.currentUser?.displayName ?? "Account", systemImage: "person.crop.circle.fill")
                            Spacer()
                            Text(authService.currentUser?.email ?? "")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Button(role: .destructive) {
                            authService.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button {
                            showAuthSheet = true
                        } label: {
                            Label("Sign In", systemImage: "person.crop.circle")
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if !authService.isSignedIn {
                        Text("Sign in to share recordings with the community.")
                    }
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
                        Text("v50.4")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "mailto:support@memorezar.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                } header: {
                    Text("About")
                }
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthSheet()
                    .environmentObject(authService)
            }
            .onChange(of: settingsStore.settings.soundTheme) { _, newValue in
                AlertManager.shared.previewTheme(newValue)
            }
            .overlay(
                showFlash ?
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    : nil
            )
            .navigationTitle("Settings")
            .onAppear {
                AlertManager.shared.onVisualAlert = {
                    showFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFlash = false
                    }
                }
            }
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
                    tutorialStore.resetAll()
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
        .environmentObject(AuthService.shared)
}
