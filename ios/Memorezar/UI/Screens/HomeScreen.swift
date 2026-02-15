import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var selectedQuote: Quote?
    @State private var showingQuoteInput = false
    @State private var showingRecitation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    heroSection

                    // Quick Start Section
                    if let recentQuote = quoteStore.recentlyPracticed.first {
                        quickStartSection(quote: recentQuote)
                    }

                    // Stats Section
                    statsSection

                    // Needs Practice Section
                    if !quoteStore.needsPractice.isEmpty {
                        needsPracticeSection
                    }

                    // Recently Added Section
                    recentlyAddedSection
                }
                .padding()
            }
            .navigationTitle("Memorezar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingQuoteInput = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingQuoteInput) {
                QuoteInputView()
            }
            .fullScreenCover(item: $selectedQuote) { quote in
                RecitationScreen(quote: quote)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)

            Text("Train Your Memory v1.1")
                .font(.title.bold())

            Text("Get instant feedback as you recite from memory")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Quick Start Section

    private func quickStartSection(quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Continue Practice", systemImage: "play.circle.fill")
                .font(.headline)
                .foregroundColor(.blue)

            Button {
                selectedQuote = quote
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quote.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(quote.preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        HStack {
                            MasteryBadge(level: quote.masteryLevel)
                            Text("\(quote.wordCount) words")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Progress", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundColor(.green)

            HStack(spacing: 12) {
                StatCard(
                    title: "Sessions",
                    value: "\(quoteStore.totalPracticeSessions)",
                    icon: "repeat.circle.fill",
                    color: .blue
                )

                StatCard(
                    title: "Mastered",
                    value: "\(quoteStore.masteredQuotesCount)",
                    icon: "star.fill",
                    color: .yellow
                )

                StatCard(
                    title: "Accuracy",
                    value: String(format: "%.0f%%", quoteStore.averageAccuracy * 100),
                    icon: "target",
                    color: .green
                )
            }
        }
    }

    // MARK: - Needs Practice Section

    private var needsPracticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Needs Practice", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.orange)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quoteStore.needsPractice.prefix(5)) { quote in
                        QuoteCard(quote: quote) {
                            selectedQuote = quote
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recently Added Section

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Library", systemImage: "books.vertical.fill")
                .font(.headline)
                .foregroundColor(.purple)

            if quoteStore.quotes.isEmpty {
                emptyLibraryView
            } else {
                ForEach(quoteStore.quotes.prefix(3)) { quote in
                    QuoteRow(quote: quote) {
                        selectedQuote = quote
                    }
                }
            }
        }
    }

    private var emptyLibraryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No quotes yet")
                .font(.headline)

            Text("Add your first quote to start practicing")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Add Quote") {
                showingQuoteInput = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuoteCard: View {
    let quote: Quote
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(quote.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(quote.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Spacer()

                HStack {
                    MasteryBadge(level: quote.masteryLevel)
                    Spacer()
                    Text("\(quote.wordCount)w")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 160, height: 120)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
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
                    Text(quote.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(quote.preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    MasteryBadge(level: quote.masteryLevel)
                    Text("\(quote.wordCount) words")
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
        }
    }
}

struct MasteryBadge: View {
    let level: MasteryLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
            Text(level.rawValue)
        }
        .font(.caption2.bold())
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private var color: Color {
        switch level {
        case .new: return .gray
        case .beginner: return .red
        case .learning: return .orange
        case .proficient: return .blue
        case .mastered: return .green
        }
    }
}

#Preview {
    HomeScreen()
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
}
