import SwiftUI

@main
struct MemorezerApp: App {
    @StateObject private var quoteStore = QuoteStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var userEquivalencesStore = UserEquivalencesStore()
    @StateObject private var localRecordingStore = LocalRecordingStore()
    @StateObject private var tutorialStore = TutorialStore()
    @StateObject private var authService = AuthService.shared
    @StateObject private var purchaseService = PurchaseService.shared
    @StateObject private var cloudBackupService = CloudBackupService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(quoteStore)
                .environmentObject(settingsStore)
                .environmentObject(userEquivalencesStore)
                .environmentObject(localRecordingStore)
                .environmentObject(tutorialStore)
                .environmentObject(authService)
                .environmentObject(purchaseService)
                .environmentObject(cloudBackupService)
                .preferredColorScheme(settingsStore.colorScheme)
                .onAppear {
                    // Wire store references for backup service
                    cloudBackupService.quoteStore = quoteStore
                    cloudBackupService.settingsStore = settingsStore
                    cloudBackupService.userEquivalencesStore = userEquivalencesStore
                    cloudBackupService.tutorialStore = tutorialStore

                    purchaseService.configure()
                    authService.restoreSession()
                }
        }
    }
}
