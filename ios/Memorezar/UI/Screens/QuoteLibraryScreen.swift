import SwiftUI

struct QuoteLibraryScreen: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var searchText = ""
    @State private var selectedCategory: QuoteCategory?
    @State private var selectedQuote: Quote?
    @State private var showingQuoteInput = false
    @State private var quoteToEdit: Quote?

    var filteredQuotes: [Quote] {
        var quotes = quoteStore.quotes

        // Filter by category
        if let category = selectedCategory {
            quotes = quotes.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            quotes = quotes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }

        return quotes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilter

                // Quote List
                if filteredQuotes.isEmpty {
                    emptyStateView
                } else {
                    quoteList
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search quotes...")
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
            .sheet(item: $quoteToEdit) { quote in
                QuoteInputView(quoteToEdit: quote)
            }
            .fullScreenCover(item: $selectedQuote) { quote in
                RecitationScreen(quote: quote)
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(QuoteCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Quote List

    private var quoteList: some View {
        List {
            ForEach(filteredQuotes) { quote in
                QuoteListRow(quote: quote) {
                    selectedQuote = quote
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        quoteStore.deleteQuote(quote)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        quoteToEdit = quote
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: searchText.isEmpty ? "books.vertical" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            if searchText.isEmpty {
                Text("No quotes in this category")
                    .font(.headline)
                Text("Add a new quote to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Add Quote") {
                    showingQuoteInput = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            } else {
                Text("No results found")
                    .font(.headline)
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct QuoteListRow: View {
    let quote: Quote
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(quote.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: quote.category.icon)
                        .foregroundColor(.secondary)
                }

                Text(quote.preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    MasteryBadge(level: quote.masteryLevel)

                    Spacer()

                    if quote.practiceCount > 0 {
                        Label("\(quote.practiceCount)", systemImage: "repeat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(quote.wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let accuracy = quote.lastAccuracy {
                        Text(String(format: "%.0f%%", accuracy * 100))
                            .font(.caption.bold())
                            .foregroundColor(accuracyColor(accuracy))
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.9 { return .green }
        if accuracy >= 0.7 { return .orange }
        return .red
    }
}

#Preview {
    QuoteLibraryScreen()
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
}
