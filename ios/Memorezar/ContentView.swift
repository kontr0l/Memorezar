import SwiftUI

struct ContentView: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @State private var selectedTab = 0
    @State private var homePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    // Incremented every time the Home tab button is tapped so HomeScreen
    // can observe the change and retry its pack fetch if the previous
    // load failed. Covers the case where the user never backgrounds the
    // app (scenePhase wouldn't fire).
    @State private var homeActivationToken = 0

    private static let iconHeight: CGFloat = 28
    private static let tabCount = 3

    var body: some View {
        Group {
            if !tutorialStore.hasCompletedOnboarding {
                OnboardingFlow()
            } else {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            HomeScreen(path: $homePath, homeActivationToken: homeActivationToken)
                                .frame(width: geo.size.width, height: geo.size.height)
                            QuoteLibraryScreen(path: $libraryPath)
                                .frame(width: geo.size.width, height: geo.size.height)
                            SettingsScreen()
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                        .offset(x: -CGFloat(selectedTab) * geo.size.width)
                        .animation(.easeInOut(duration: 0.35), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

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
                    if let category {
                        quoteStore.pendingCategoryNavigation = nil
                        // Defer navigation until the next run-loop so SwiftUI
                        // finishes processing the batch quote-add updates first.
                        // Without this, modifying libraryPath mid-update could
                        // crash on large packs (e.g. Movie Quotes).
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            var tx = Transaction()
                            tx.disablesAnimations = true
                            withTransaction(tx) {
                                libraryPath = NavigationPath()
                                libraryPath.append(category)
                            }
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedTab = 1
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                var cleanup = Transaction()
                                cleanup.disablesAnimations = true
                                withTransaction(cleanup) {
                                    homePath = NavigationPath()
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: tutorialStore.hasCompletedOnboarding) { completed in
            if completed {
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) { selectedTab = 0 }
            }
        }
    }

    private func tabButton(icon: String, tag: Int) -> some View {
        Button {
            switch tag {
            case 0:
                if !homePath.isEmpty { homePath = NavigationPath() }
                homeActivationToken &+= 1
            case 1: if !libraryPath.isEmpty { libraryPath = NavigationPath() }
            default: break
            }
            if selectedTab != tag {
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
