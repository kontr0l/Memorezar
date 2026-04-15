import SwiftUI

struct ContentView: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @State private var selectedTab = 0
    @State private var homePath = NavigationPath()
    @State private var libraryPath = NavigationPath()

    private static let iconHeight: CGFloat = 28

    var body: some View {
        if !tutorialStore.hasCompletedOnboarding {
            OnboardingFlow()
        } else {
            VStack(spacing: 0) {
                // Content area
                Group {
                    switch selectedTab {
                    case 0: HomeScreen(path: $homePath)
                    case 1: QuoteLibraryScreen(path: $libraryPath)
                    case 2: SettingsScreen()
                    default: HomeScreen(path: $homePath)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom tab bar
                Divider()
                HStack {
                    tabButton(icon: "IconHome", tag: 0)
                    tabButton(icon: "IconLibrary", tag: 1)
                    tabButton(icon: "IconSettings", tag: 2)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
            }
            .onChange(of: quoteStore.pendingCategoryNavigation) { category in
                if category != nil {
                    selectedTab = 1
                }
            }
        }
    }

    private func tabButton(icon: String, tag: Int) -> some View {
        Button {
            // If a tab is re-tapped while already selected, pop its stack back
            // to the root (matches Android behavior).
            if selectedTab == tag {
                switch tag {
                case 0: if !homePath.isEmpty { homePath = NavigationPath() }
                case 1: if !libraryPath.isEmpty { libraryPath = NavigationPath() }
                default: break
                }
            } else {
                // Home always starts fresh when entered from another tab.
                // (Library preserves its navigation state, matching Android.)
                if tag == 0 && !homePath.isEmpty {
                    homePath = NavigationPath()
                }
                selectedTab = tag
            }
        } label: {
            Image(icon)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: Self.iconHeight)
                .opacity(selectedTab == tag ? 1.0 : 0.4)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
        .environmentObject(TutorialStore())
}
