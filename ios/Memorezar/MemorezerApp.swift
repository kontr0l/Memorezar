import SwiftUI

@main
struct MemorezerApp: App {
    @StateObject private var quoteStore = QuoteStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var userEquivalencesStore = UserEquivalencesStore()
    @StateObject private var localRecordingStore = LocalRecordingStore()
    @StateObject private var tutorialStore = TutorialStore()
    @StateObject private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(quoteStore)
                .environmentObject(settingsStore)
                .environmentObject(userEquivalencesStore)
                .environmentObject(localRecordingStore)
                .environmentObject(tutorialStore)
                .environmentObject(authService)
                .preferredColorScheme(settingsStore.colorScheme)
                .onAppear {
                    authService.restoreSession()
                }
        }
    }
}
