import SwiftUI

struct ContentView: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @State private var selectedTab = 0

    private static let iconHeight: CGFloat = 28

    var body: some View {
        if !tutorialStore.hasCompletedOnboarding {
            OnboardingFlow()
        } else {
            VStack(spacing: 0) {
                // Content area
                Group {
                    switch selectedTab {
                    case 0: HomeScreen()
                    case 1: QuoteLibraryScreen()
                    case 2: SettingsScreen()
                    default: HomeScreen()
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
            selectedTab = tag
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
