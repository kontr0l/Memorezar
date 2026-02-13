import SwiftUI

struct QuoteLibraryScreen: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedQuote: Quote?
    @State private var showingQuoteInput = false
    @State private var quoteToEdit: Quote?
    @State private var showingCategoryManagement = false

    var filteredQuotes: [Quote] {
        var quotes = quoteStore.quotes

        // Filter by category
        if let categoryId = selectedCategoryId {
            quotes = quotes.filter { $0.categoryId == categoryId }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingCategoryManagement = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                }

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
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView()
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
                    isSelected: selectedCategoryId == nil
                ) {
                    selectedCategoryId = nil
                }

                ForEach(quoteStore.categories) { category in
                    CategoryChip(
                        title: category.name,
                        icon: category.icon,
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = category.id
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
    @EnvironmentObject var quoteStore: QuoteStore
    let quote: Quote
    let action: () -> Void

    private var categoryIcon: String {
        quoteStore.getCategory(byId: quote.categoryId)?.icon ?? "folder.fill"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(quote.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: categoryIcon)
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

// MARK: - Category Management View

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var showingAddCategory = false
    @State private var categoryToEdit: QuoteCategory?

    var body: some View {
        NavigationStack {
            List {
                // User's categories
                Section {
                    ForEach(quoteStore.categories) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            Text(category.name)

                            Spacer()

                            Text("\(quoteStore.quotes(inCategory: category.id).count)")
                                .foregroundColor(.secondary)
                                .font(.subheadline)

                            if category.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    quoteStore.deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    categoryToEdit = category
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                } header: {
                    Text("Your Categories")
                } footer: {
                    Text("The default category cannot be deleted. Deleting a category moves its quotes to the default category.")
                }

                // Add preset categories
                if hasAvailablePresets {
                    Section {
                        ForEach(availablePresets) { preset in
                            Button {
                                quoteStore.addPresetCategory(preset)
                            } label: {
                                HStack {
                                    Image(systemName: preset.icon)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30)

                                    Text(preset.name)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    } header: {
                        Text("Suggested Categories")
                    } footer: {
                        Text("Tap to add these preset categories")
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                CategoryEditView(category: nil)
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryEditView(category: category)
            }
        }
    }

    private var availablePresets: [QuoteCategory] {
        QuoteCategory.presets.filter { preset in
            !quoteStore.categories.contains { $0.name == preset.name }
        }
    }

    private var hasAvailablePresets: Bool {
        !availablePresets.isEmpty
    }
}

// MARK: - Category Edit View

struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore

    @State private var name: String
    @State private var selectedIcon: String

    private let existingCategory: QuoteCategory?

    init(category: QuoteCategory?) {
        self.existingCategory = category
        _name = State(initialValue: category?.name ?? "")
        _selectedIcon = State(initialValue: category?.icon ?? "folder.fill")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(QuoteCategory.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(selectedIcon == icon ? Color.blue : Color(.secondarySystemBackground))
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }
            }
            .navigationTitle(existingCategory == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = existingCategory {
            var updated = existing
            updated.name = trimmedName
            updated.icon = selectedIcon
            quoteStore.updateCategory(updated)
        } else {
            let newCategory = QuoteCategory(
                name: trimmedName,
                icon: selectedIcon
            )
            quoteStore.addCategory(newCategory)
        }

        dismiss()
    }
}

#Preview {
    QuoteLibraryScreen()
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
}
