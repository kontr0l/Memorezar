import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var purchaseService: PurchaseService
    @EnvironmentObject var cloudBackupService: CloudBackupService
    @State private var showingResetAlert = false
    @State private var showRestoreConfirm = false
    @State private var showingDeleteDataAlert = false
    @State private var showFlash = false
    @State private var showAuthSheet = false
    @State private var showPaywall = false
    @State private var showContactSupport = false

    var body: some View {
        NavigationStack {
            List {
                alertsSection
                displaySection
                statisticsSection
                accountSection
                dataSection
                aboutSection
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthSheet()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
            .sheet(isPresented: $showContactSupport) {
                ContactSupportView()
                    .environmentObject(authService)
            }
            .onChange(of: settingsStore.settings.soundTheme) { _, newValue in
                // Gate meme theme behind Pro
                if newValue == .memes && !purchaseService.canUseSoundTheme(.memes) {
                    settingsStore.settings.soundTheme = .default
                    showPaywall = true
                    return
                }
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
                    tutorialStore.hasCompletedOnboarding = false
                }
            } message: {
                Text("This will delete all your quotes, practice history, and statistics. This action cannot be undone.")
            }
        }
    }

    // MARK: - Sections

    private var alertsSection: some View {
        Section {
            Toggle(isOn: $settingsStore.settings.audioAlertEnabled) {
                Label("Sound Alerts", systemImage: "speaker.wave.2.fill")
            }

            if settingsStore.settings.audioAlertEnabled {
                Picker(selection: $settingsStore.settings.soundTheme) {
                    ForEach(SoundTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName)
                        .tag(theme)
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
    }

    private var displaySection: some View {
        Section {
            Picker(selection: $settingsStore.settings.defaultMemorizationMode) {
                ForEach(MemorizationMode.settingsOptions, id: \.self) { mode in
                    Label(mode.localizedName, systemImage: mode.icon).tag(mode)
                }
            } label: {
                Label("Default Mode", systemImage: "rectangle.3.group")
            }

            if settingsStore.settings.defaultMemorizationMode == .voice || settingsStore.settings.defaultMemorizationMode == .typing {
                Toggle(isOn: $settingsStore.settings.firstLetterModeEnabled) {
                    Label("First Letter Mode", systemImage: "a.square")
                }
            }

            Picker(selection: $settingsStore.settings.fontSize) {
                ForEach(FontSize.allCases, id: \.self) { size in
                    Text(size.localizedName).tag(size)
                }
            } label: {
                Label("Font Size", systemImage: "textformat.size")
            }

            Picker(selection: $settingsStore.settings.theme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.localizedName).tag(theme)
                }
            } label: {
                Label("Theme", systemImage: "paintbrush.fill")
            }
        } header: {
            Text("Display")
        }
    }

    private var statisticsSection: some View {
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
    }

    private var accountSection: some View {
        Section {
            if authService.isSignedIn {
                Label(accountDisplayName, systemImage: "person.crop.circle.fill")

                // Back Up Now
                Button {
                    Task { await cloudBackupService.performBackup() }
                } label: {
                    HStack {
                        Label("Back Up Now", systemImage: "arrow.clockwise.icloud")
                        if cloudBackupService.backupState == .backingUp {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(cloudBackupService.backupState == .backingUp)

                // Restore from Backup
                Button {
                    showRestoreConfirm = true
                } label: {
                    Label("Restore from Backup", systemImage: "arrow.down.circle")
                }
                .disabled(cloudBackupService.backupState == .restoring || !cloudBackupService.cloudBackupExists)
                .confirmationDialog(
                    "Restore from cloud backup?",
                    isPresented: $showRestoreConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Replace with Cloud Data") {
                        Task {
                            do {
                                let payload = try await cloudBackupService.fetchBackupPayload()
                                await cloudBackupService.applyRestore(payload)
                            } catch {
                                print("[Settings] Restore failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    if let date = cloudBackupService.cloudBackupDate {
                        Text("This will replace all local data with your cloud backup from \(date.formatted(date: .abbreviated, time: .shortened)).")
                    } else {
                        Text("This will replace all local data with your cloud backup.")
                    }
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
                Text("Sign in to back up your data and share recordings.")
            } else if let date = cloudBackupService.lastBackupDate {
                Text("Last backed up \(relativeBackupTime(date))")
            }
        }
    }

    private var dataSection: some View {
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
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("v71.78")
                    .foregroundColor(.secondary)
            }

            Button {
                showContactSupport = true
            } label: {
                Label("Contact Support", systemImage: "envelope")
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private var isApplePrivateRelay: Bool {
        authService.currentUser?.email?.contains("@privaterelay.appleid.com") == true
    }

    private var accountDisplayName: String {
        if let email = authService.currentUser?.email, !email.isEmpty, !isApplePrivateRelay {
            return email
        }
        return String(localized: "Apple Account")
    }

    private func relativeBackupTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return String(localized: "1 min ago") }
        let minutes = Int(ceil(Double(seconds) / 60.0))
        if minutes < 60 { return String(localized: "\(minutes) min ago") }
        let hours = Int(ceil(Double(minutes) / 60.0))
        if hours < 24 { return String(localized: "\(hours) hr ago") }
        let days = Int(ceil(Double(hours) / 24.0))
        return String(localized: "\(days) days ago")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        } else {
            return String(localized: "\(minutes)m")
        }
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(SettingsStore())
        .environmentObject(QuoteStore())
        .environmentObject(AuthService.shared)
        .environmentObject(PurchaseService.shared)
}
