import SwiftUI

@main
struct MemorezerApp: App {
    @StateObject private var quoteStore = QuoteStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(quoteStore)
                .environmentObject(settingsStore)
        }
    }
}
