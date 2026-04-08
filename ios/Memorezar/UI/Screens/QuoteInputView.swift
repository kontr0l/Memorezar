import SwiftUI

struct QuoteInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var purchaseService: PurchaseService

    @State private var title: String
    @State private var text: String
    @State private var selectedCategoryId: UUID?
    @State private var showPaywall = false

    private let quoteToEdit: Quote?
    private let onSave: ((Quote) -> Void)?
    private var isEditing: Bool { quoteToEdit != nil }

    init(quoteToEdit: Quote? = nil, initialCategoryId: UUID? = nil, onSave: ((Quote) -> Void)? = nil) {
        self.quoteToEdit = quoteToEdit
        self.onSave = onSave
        _title = State(initialValue: quoteToEdit?.title ?? "")
        _text = State(initialValue: quoteToEdit?.text ?? "")
        _selectedCategoryId = State(initialValue: quoteToEdit?.categoryId ?? initialCategoryId)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField(String(localized: "Quote Title"), text: $title)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Title")
                } footer: {
                    Text("Give your quote a memorable name")
                }

                // Category Section
                Section {
                    Picker(String(localized: "Category"), selection: $selectedCategoryId) {
                        ForEach(quoteStore.categories.filter { $0.sourcePackId == nil }) { category in
                            Text(category.name)
                                .tag(category.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Text Section
                Section {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Enter the text you want to memorize...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }

                        TextEditor(text: $text)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                    }

                    Text(String(localized: "\(wordCount) words"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Text")
                } footer: {
                    Text("This is the text you'll practice reciting from memory")
                }

                // Preview Section
                if !text.isEmpty {
                    Section {
                        WordPreviewView(text: text)
                    } header: {
                        Text("Preview")
                    } footer: {
                        Text("This is how your text will appear during practice")
                    }
                }

                // Tips Section
                if !isEditing {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "lightbulb.fill", color: .yellow, text: String(localized: "Start with shorter passages"))
                            TipRow(icon: "arrow.right", color: .blue, text: String(localized: "Break long texts into sections"))
                            TipRow(icon: "repeat", color: .green, text: String(localized: "Practice regularly for best results"))
                        }
                    } header: {
                        Text("Tips")
                    }
                }
            }
            .onAppear {
                // Default to first category when adding from library
                if selectedCategoryId == nil {
                    selectedCategoryId = quoteStore.categories.first(where: { $0.sourcePackId == nil })?.id
                }
            }
            .navigationTitle(isEditing ? String(localized: "Edit Quote") : String(localized: "Add Quote"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? String(localized: "Save") : String(localized: "Add")) {
                        saveQuote()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
        }
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !text.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedCategoryId != nil
    }

    // MARK: - Actions

    private func saveQuote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard let categoryId = selectedCategoryId else { return }

        // Enforce 20-quote cap for free users (only on new quotes, not edits)
        if quoteToEdit == nil && !purchaseService.canAddCustomQuote(quoteStore: quoteStore) {
            showPaywall = true
            return
        }

        if let existingQuote = quoteToEdit {
            // Update existing
            var updated = existingQuote
            updated.title = trimmedTitle
            updated.text = trimmedText
            updated.categoryId = categoryId
            quoteStore.updateQuote(updated)
            onSave?(updated)
        } else {
            // Create new
            let newQuote = Quote(
                title: trimmedTitle,
                text: trimmedText,
                categoryId: categoryId
            )
            quoteStore.addQuote(newQuote)
            onSave?(newQuote)
        }

        dismiss()
    }
}

// MARK: - Supporting Views

struct WordPreviewView: View {
    let text: String

    var words: [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(words.prefix(20).enumerated()), id: \.offset) { _, word in
                    Text(word)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                if words.count > 20 {
                    Text(String(localized: "+\(words.count - 20) more"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview("Add Quote") {
    QuoteInputView()
        .environmentObject(QuoteStore())
        .environmentObject(PurchaseService.shared)
}

#Preview("Edit Quote") {
    QuoteInputView(quoteToEdit: Quote(
        title: "Test Quote",
        text: "This is a test quote that I want to memorize.",
        categoryId: QuoteCategory.defaultCategory.id
    ))
    .environmentObject(QuoteStore())
    .environmentObject(PurchaseService.shared)
}
