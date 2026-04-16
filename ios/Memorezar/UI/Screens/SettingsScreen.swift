import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var purchaseService: PurchaseService
    @EnvironmentObject var cloudBackupService: CloudBackupService
    @EnvironmentObject var localRecordingStore: LocalRecordingStore
    @State private var showingResetAlert = false
    @State private var showRestoreConfirm = false
    @State private var showingDeleteDataAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var deleteAccountInFlight = false
    @State private var deleteAccountConfirmationMessage: String?
    @State private var showFlash = false
    @State private var showAuthSheet = false
    @State private var showPaywall = false
    @State private var showContactSupport = false
    @State private var showRestoreToast = false
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Inline large title — matches the Library screen's title style.
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 1, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)

                Group {
                    alertsSection
                    displaySection
                    statisticsSection
                    accountSection
                    dataSection
                    aboutSection
                }
                // Invert default colors: cards become grey instead of white.
                .listRowBackground(Color(.systemGroupedBackground))
            }
            // Invert default colors: scroll background becomes white (the
            // color normally used for the section cards) instead of grey.
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemGroupedBackground))
            // Pull the List's default insets down to zero so the gutter
            // matches the Library/Home screens' 16pt edge inset (provided
            // by .padding() on their VStack), not the List default.
            .contentMargins(.top, 0, for: .scrollContent)
            .listSectionSpacing(.compact)
            // Pull section card margins from the default ~20pt down to ~10pt
            // by extending the List 10pt past its bounds on each side.
            .padding(.horizontal, -5)
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
            // ViewBuilder-trailing-closure form (the older .overlay(content)
            // with a nil-returning ternary stopped re-rendering on state flips
            // in iOS 17+ — the optional View would sometimes silently skip
            // the update, leaving showFlash=true with no red tint visible).
            .overlay {
                if showFlash {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.1), value: showFlash)
            // Restore-complete toast — bottom capsule shown briefly after a
            // successful cloud restore, mirroring the Android "PDF saved to
            // Downloads" toast pattern.
            .overlay(alignment: .bottom) {
                if showRestoreToast {
                    Text("All restored!")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.85)))
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showRestoreToast)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                AlertManager.shared.onVisualAlert = {
                    print("[Settings] visual alert fired — showFlash set to true")
                    showFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFlash = false
                    }
                }
            }
            .task {
                // Re-check cloud backup existence when Settings appears. Covers
                // the case where the cold-launch check failed (no network) —
                // otherwise the Restore button stays stuck disabled.
                if authService.isSignedIn {
                    _ = await cloudBackupService.checkForCloudBackup()
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
                    // Fire off the community-unshare cleanup async, then wipe
                    // everything local. The unshare requests run in parallel
                    // in the background — we don't block the UI on them.
                    let toUnshare = localRecordingStore.recordings.compactMap { r -> (UUID, String?)? in
                        guard !r.isFavorite, let cid = r.communityRecordingId else { return nil }
                        return (cid, r.localFileName)
                    }
                    Task.detached(priority: .background) {
                        for (communityId, _) in toUnshare {
                            do {
                                try await RecordingService.shared.deleteRecording(id: communityId, filePath: nil)
                            } catch {
                                print("[Settings] Delete All Data: community unshare failed for \(communityId): \(error)")
                            }
                        }
                    }
                    // Local wipe: quotes + sessions + categories, tutorials,
                    // AND local recordings (metadata + audio files on disk).
                    quoteStore.clearAllData()
                    tutorialStore.resetAll()
                    tutorialStore.hasCompletedOnboarding = false
                    localRecordingStore.wipeAllAudioFiles()
                    localRecordingStore.replaceAll([])
                }
            } message: {
                Text("This will delete all your quotes, practice history, statistics, and local recordings. Any recordings you've shared to the community will also be removed. This action cannot be undone.")
            }
            .alert("Sign out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("You'll need to sign in again to back up your data or share recordings with the community.")
            }
            .alert("Delete My Account?", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    submitAccountDeletionRequest()
                }
            } message: {
                Text("This will permanently delete your account, cloud backups, community recordings, and all your local data (quotes, practice history, stats). This cannot be undone.")
            }
            .alert("Request Received", isPresented: Binding(
                get: { deleteAccountConfirmationMessage != nil },
                set: { if !$0 { deleteAccountConfirmationMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountConfirmationMessage ?? "")
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

                // Restore from Backup — only show the row when a backup actually
                // exists on the server. Hiding (rather than disabling) prevents
                // user confusion when the footer and button state used to drift.
                if cloudBackupService.cloudBackupExists {
                    Button {
                        showRestoreConfirm = true
                    } label: {
                        Label("Restore from Backup", systemImage: "arrow.down.circle")
                    }
                    .disabled(cloudBackupService.backupState == .restoring)
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
                                    await MainActor.run {
                                        withAnimation { showRestoreToast = true }
                                    }
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    await MainActor.run {
                                        withAnimation { showRestoreToast = false }
                                    }
                                } catch {
                                    print("[Settings] Restore failed: \(error.localizedDescription)")
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        // Matches Android v2.9.0: main line + relative "Last
                        // backed up X ago" subtitle (same phrasing as the
                        // Account-section footer).
                        let whenText: String = {
                            if let date = cloudBackupService.lastBackupDate {
                                return "\n\nLast backed up \(relativeBackupTime(date))"
                            } else if let date = cloudBackupService.cloudBackupDate {
                                return "\n\nLast backed up \(relativeBackupTime(date))"
                            } else {
                                return ""
                            }
                        }()
                        Text("This will replace all local data with your cloud backup." + whenText)
                    }
                }

                Button(role: .destructive) {
                    showingSignOutAlert = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    showingDeleteAccountAlert = true
                } label: {
                    Label("Delete My Account", systemImage: "trash")
                }
                .disabled(deleteAccountInFlight)
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
                Text("v74.6")
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

    /// Performs the full account deletion: server-side cascade (recordings +
    /// audio files + cloud backups + support tickets + auth user), then local
    /// data wipe + sign-out. Combines what Sign Out and Delete All Data do,
    /// plus the Supabase cleanup.
    private func submitAccountDeletionRequest() {
        guard !deleteAccountInFlight else { return }
        deleteAccountInFlight = true

        Task {
            let serverError = await deleteUserAccountOnServer()
            if let err = serverError {
                print("[Settings] Server-side account delete failed: \(err)")
                // Fall through anyway — local wipe + signOut still happens so
                // the user isn't stuck on a dead session.
            }

            await MainActor.run {
                // Local wipe = same path as the Delete All Data button.
                quoteStore.clearAllData()
                tutorialStore.resetAll()
                settingsStore.resetToDefaults()
                // Community recordings are already deleted server-side by the
                // delete-user-account Edge Function's cascade — we only need
                // to wipe the local audio files + metadata here.
                localRecordingStore.wipeAllAudioFiles()
                localRecordingStore.replaceAll([])
                authService.signOut()
                deleteAccountInFlight = false
                deleteAccountConfirmationMessage = serverError == nil
                    ? String(localized: "Your account and all associated data have been deleted.")
                    : String(localized: "Local data was cleared and you've been signed out, but the server-side delete didn't complete. Please contact support if you see your data again.")
            }
        }
    }

    /// Calls the delete-user-account Edge Function with the user's JWT.
    /// Returns nil on success, an error string on failure.
    private func deleteUserAccountOnServer() async -> String? {
        guard let token = authService.accessToken else {
            return "Not signed in"
        }
        let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/delete-user-account")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return "no response" }
            if (200...299).contains(http.statusCode) { return nil }
            let body = String(data: data, encoding: .utf8) ?? ""
            return "HTTP \(http.statusCode): \(body)"
        } catch {
            return error.localizedDescription
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
