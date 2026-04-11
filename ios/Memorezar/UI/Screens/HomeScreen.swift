import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var tutorialStore: TutorialStore
    @State private var selectedQuote: Quote?
    @State private var showingQuoteInput = false
    @State private var showMasteredList = false
    @State private var showStreakDetail = false
    @State private var showAccuracyDetail = false
    @State private var remotePacks: [SuggestionPack] = []
    @State private var showPackSearch = false
    /// Last 5 actually practiced quotes, most recent first
    private var continuePracticingQuotes: [Quote] {
        Array(quoteStore.quotes
            .filter { $0.lastPracticedAt != nil }
            .sorted { ($0.lastPracticedAt ?? .distantPast) > ($1.lastPracticedAt ?? .distantPast) }
            .prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    heroSection

                    // Continue Practicing — horizontal scroll of quote cards
                    continuePracticingSection

                    // Stats Section
                    statsSection

                    // Browse Quote Packs (always last)
                    if !availablePacks.isEmpty {
                        suggestionSection
                    }
                }
                .padding()
            }
            .tipOverlay(.addOwnQuote, verticalOffset: -25)
            .tipOverlay(.browsePacks, verticalOffset: -15)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showMasteredList) {
                MasteredQuotesView()
            }
            .navigationDestination(isPresented: $showStreakDetail) {
                StreakDetailView()
            }
            .navigationDestination(isPresented: $showAccuracyDetail) {
                AccuracyDetailView()
            }
            .navigationDestination(isPresented: $showPackSearch) {
                PackSearchView(packs: remotePacks)
            }
            .navigationDestination(for: SuggestionPack.self) { pack in
                PackDetailView(pack: pack)
                    .onAppear {
                        tutorialStore.completeTip(TipDefinition.browsePacks.id)
                    }
            }
            .sheet(isPresented: $showingQuoteInput) {
                QuoteInputView { newQuote in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedQuote = newQuote
                    }
                }
            }
            .fullScreenCover(item: $selectedQuote) { quote in
                RecitationScreen(quote: quote)
            }
            .task {
                async let packsTask = PackService.shared.fetchPacks()
                async let langsTask: () = LanguageService.shared.fetchLanguages()
                remotePacks = await packsTask
                await langsTask
            }
        }
    }

    // Static so it's chosen once at app launch, not on every tab switch
    private static let heroCharacter: BrainCharacter = .random(from: BrainCharacter.hero)

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 0) {
            Image("MemorizarLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 16)

            BrainCharacterView(character: Self.heroCharacter, size: 180)
        }
    }

    // MARK: - Continue Practicing Section

    private var continuePracticingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(continuePracticingQuotes.isEmpty ? "Get Started" : "Continue Practicing",
                      systemImage: "play.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)

                Spacer()

                if continuePracticingQuotes.count > 2 {
                    Button {
                        showingQuoteInput = true
                    } label: {
                        Image("IconAddQuote").renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 36)
                    }
                    .actionTip(.addOwnQuote)
                }
            }

            if continuePracticingQuotes.isEmpty {
                // No practiced quotes — info tile + add quote tile, filling full width
                HStack(spacing: 12) {
                    // Info tile
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No quotes yet")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text("Add a quote or browse packs to get started!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)

                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 100)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))

                    addQuoteCard
                }
            } else if continuePracticingQuotes.count == 1 {
                // 1 quote — fill full width, no scroll
                HStack(spacing: 12) {
                    ContinueQuoteCard(quote: continuePracticingQuotes[0], flexible: true) {
                        selectedQuote = continuePracticingQuotes[0]
                    }
                    addQuoteCard
                }
            } else if continuePracticingQuotes.count == 2 {
                // 2 quotes + add card — horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(continuePracticingQuotes) { quote in
                            ContinueQuoteCard(quote: quote) {
                                selectedQuote = quote
                            }
                        }
                        addQuoteCard
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
            } else {
                // 3+ quotes — horizontal scroll, no add card
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(continuePracticingQuotes) { quote in
                            ContinueQuoteCard(quote: quote) {
                                selectedQuote = quote
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    /// Add-quote card styled like a quote card
    private var addQuoteCard: some View {
        Button {
            tutorialStore.completeTip(TipDefinition.addOwnQuote.id)
            showingQuoteInput = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add your own")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Image("IconAddQuote").renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .actionTip(.addOwnQuote)
            }
            .padding(12)
            .frame(width: 160, height: 100)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Progress", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundColor(.green)

            HStack(spacing: 12) {
                Button {
                    showMasteredList = true
                } label: {
                    StatCard(
                        title: "Mastered",
                        value: "\(quoteStore.masteredQuotesCount)",
                        icon: "crown.fill",
                        color: .yellow
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showStreakDetail = true
                } label: {
                    StatCard(
                        title: "Streak",
                        value: "\(quoteStore.dailyStreak)d",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showAccuracyDetail = true
                } label: {
                    StatCard(
                        title: "Accuracy",
                        value: String(format: "%.0f%%", quoteStore.averageAccuracy * 100),
                        icon: "target",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Suggestion Packs

    private var availablePacks: [SuggestionPack] {
        remotePacks.filter { !quoteStore.isPackAdded($0.id) }
    }

    private let packColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Browse Quote Packs", systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundColor(.indigo)
                    .actionTip(.browsePacks, delay: 1.0)

                Spacer()

                Button {
                    showPackSearch = true
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.indigo)
                }
            }

            LazyVGrid(columns: packColumns, spacing: 12) {
                ForEach(availablePacks) { pack in
                    NavigationLink(value: pack) {
                        SuggestionPackCard(pack: pack)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale(scale: 0.5).combined(with: .opacity)
                    ))
                }
            }

        }
    }

}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }
}

struct SuggestionPackCard: View {
    let pack: SuggestionPack
    private var lang: String { LanguageHelper.preferredLanguageCode }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Cover image — remote URL or gradient fallback.
                // Forced into geo.size and clipped locally so wide/tall
                // images can never escape the card bounds.
                Group {
                    if let urlString = pack.coverURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            LinearGradient(
                                colors: [.indigo.opacity(0.6), .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    } else {
                        LinearGradient(
                            colors: [.indigo.opacity(0.6), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Dark gradient overlay at bottom — same as CategoryCard
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Pack name and quote count — same layout as CategoryCard
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()

                    Text(pack.localizedName(for: lang))
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(String(localized: "\(pack.quotes.count) quotes"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(12)
            }
        }
        .frame(height: 200)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }
}

// MARK: - Pack Detail View

struct PackDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var purchaseService: PurchaseService
    let pack: SuggestionPack

    @State private var showPaywall = false

    private var lang: String { LanguageHelper.preferredLanguageCode }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Cover image header
                ZStack(alignment: .bottomLeading) {
                    packCoverImage(height: 260)

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Spacer()
                        Text(pack.localizedName(for: lang))
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text(String(localized: "\(pack.quotes.count) quotes"))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(16)
                }
                .frame(height: 260)

                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    Text(pack.localizedDescription(for: lang))
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Quote preview — show localized text
                    VStack(spacing: 0) {
                        Text("\u{201C}")
                            .font(.system(size: 100, weight: .bold, design: .serif))
                            .foregroundColor(.indigo.opacity(0.25))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, -10)
                            .padding(.bottom, -60)

                        VStack(spacing: 14) {
                            ForEach(Array(pack.quotes.prefix(3).enumerated()), id: \.offset) { _, quote in
                                Text(snippetDisplay(for: quote))
                                    .font(.body)
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)

                        Text("\u{201D}")
                            .font(.system(size: 100, weight: .bold, design: .serif))
                            .foregroundColor(.indigo.opacity(0.25))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, -20)
                    }

                    // Add to Library button
                    Button {
                        if purchaseService.canAccessPack(pack) {
                            quoteStore.addSuggestionPack(pack, preferredLanguage: lang)
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Text("Add to Library")
                            Image(systemName: "plus.square")
                            if !pack.isFree && !purchaseService.hasFullAccess {
                                ProBadge()
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.backward")
                        Text("Home")
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Text(pack.localizedName(for: lang))
                    .font(.headline)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func packCoverImage(height: CGFloat) -> some View {
        if let urlString = pack.coverURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                LinearGradient(
                    colors: [.indigo.opacity(0.6), .purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(height: height)
            .clipped()
        } else {
            LinearGradient(
                colors: [.indigo.opacity(0.6), .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: height)
        }
    }

    private func snippetDisplay(for quote: SuggestionQuote) -> String {
        let text = quote.localizedText(for: lang)
        let snippet = fallbackSnippet(text)
        if snippet == text { return snippet }
        return snippet + "..."
    }

    private func fallbackSnippet(_ text: String) -> String {
        let words = text.split(separator: " ")
        if words.count <= 7 { return text }

        let functionWords: Set<String> = [
            "a", "an", "the",
            "is", "are", "was", "were", "can", "could", "will", "would",
            "shall", "should", "has", "have", "had", "may", "might",
            "which", "who", "whom", "whose", "where", "when", "than",
            "with", "in", "on", "of", "to", "for", "from", "by",
            "and", "but", "or", "nor", "through", "lest", "ere", "not",
            // Spanish function words
            "el", "la", "los", "las", "un", "una", "de", "del", "en",
            "es", "son", "ser", "y", "o", "que", "por", "para", "con",
            "no", "se", "su", "al",
            // French function words
            "le", "les", "des", "du", "et", "ou", "est", "sont",
            "dans", "sur", "par", "pour", "avec", "ne", "pas",
        ]

        var bestCount: Int?
        var bestScore = Int.max

        for count in 4...7 where count <= words.count {
            let word = String(words[count - 1]).lowercased()
                .trimmingCharacters(in: .init(charactersIn: ".,;:!?\"'¡¿"))
            if functionWords.contains(word) {
                let snippet = words.prefix(count).joined(separator: " ")
                let charCount = snippet.count
                let score: Int
                if charCount >= 25 && charCount <= 30 {
                    score = 0
                } else if charCount < 25 {
                    score = 25 - charCount
                } else {
                    score = charCount - 30
                }
                if score < bestScore {
                    bestScore = score
                    bestCount = count
                }
            }
        }

        if let count = bestCount {
            return words.prefix(count).joined(separator: " ")
        }

        return words.prefix(5).joined(separator: " ")
    }
}

struct ContinueQuoteCard: View {
    let quote: Quote
    var flexible: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.displayTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !quote.titleMatchesPreview {
                    Text(quote.preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack {
                    MasteryBadge(level: quote.masteryLevel)
                    Spacer()
                    Text(lastPracticedLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: flexible ? .infinity : 160, alignment: .leading)
            .frame(height: 100)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
        }
    }

    private var lastPracticedLabel: String {
        guard let date = quote.lastPracticedAt else { return String(localized: "\(quote.wordCount)w") }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return String(localized: "Today") }
        if days == 1 { return String(localized: "1d ago") }
        if days < 7 { return String(localized: "\(days)d ago") }
        if days < 30 { return String(localized: "\(days / 7)w ago") }
        return String(localized: "\(days / 30)mo ago")
    }
}

struct QuoteCard: View {
    let quote: Quote
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(quote.displayTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !quote.titleMatchesPreview {
                    Text(quote.preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack {
                    MasteryBadge(level: quote.masteryLevel)
                    Spacer()
                    Text(String(localized: "\(quote.wordCount)w"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 160, height: 120)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
        }
    }
}

struct QuoteRow: View {
    let quote: Quote
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if !quote.titleMatchesPreview {
                        Text(quote.preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    MasteryBadge(level: quote.masteryLevel)
                    Text(String(localized: "\(quote.wordCount) words"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
        }
    }
}

struct MasteryBadge: View {
    let level: MasteryLevel

    var body: some View {
        if level != .none {
            HStack(spacing: 4) {
                Image(systemName: level.icon)
                Text(level.localizedName)
            }
            .font(.caption2.bold())
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
        }
    }

    private var color: Color {
        switch level {
        case .none: return .gray
        case .learning: return .green
        case .advancing: return .orange
        case .proficient: return .indigo
        case .mastered: return .yellow
        }
    }
}

// MARK: - Pack Search View

struct PackSearchView: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var tutorialStore: TutorialStore
    let packs: [SuggestionPack]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var lang: String { LanguageHelper.preferredLanguageCode }

    private var filteredPacks: [SuggestionPack] {
        let available = packs.filter { !quoteStore.isPackAdded($0.id) }
        guard !searchText.isEmpty else { return available }
        let query = searchText.lowercased()
        return available.filter {
            $0.localizedName(for: lang).lowercased().contains(query) ||
            $0.localizedDescription(for: lang).lowercased().contains(query)
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredPacks) { pack in
                    NavigationLink {
                        PackDetailView(pack: pack)
                            .onAppear {
                                tutorialStore.completeTip(TipDefinition.browsePacks.id)
                            }
                    } label: {
                        SuggestionPackCard(pack: pack)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search quote packs")
        .navigationTitle("Quote Packs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

#Preview {
    HomeScreen()
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
        .environmentObject(PurchaseService.shared)
}
