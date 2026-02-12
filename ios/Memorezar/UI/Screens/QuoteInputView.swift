import SwiftUI

struct QuoteInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore

    @State private var title: String
    @State private var text: String
    @State private var category: QuoteCategory
    @State private var showingPasteOptions = false

    private let quoteToEdit: Quote?
    private var isEditing: Bool { quoteToEdit != nil }

    init(quoteToEdit: Quote? = nil) {
        self.quoteToEdit = quoteToEdit
        _title = State(initialValue: quoteToEdit?.title ?? "")
        _text = State(initialValue: quoteToEdit?.text ?? "")
        _category = State(initialValue: quoteToEdit?.category ?? .general)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField("Quote Title", text: $title)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Title")
                } footer: {
                    Text("Give your quote a memorable name")
                }

                // Category Section
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(QuoteCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Category")
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

                    HStack {
                        Text("\(wordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.caption)
                        }

                        Button {
                            text = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .font(.caption)
                        }
                        .disabled(text.isEmpty)
                    }
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
                            TipRow(icon: "lightbulb.fill", color: .yellow, text: "Start with shorter passages")
                            TipRow(icon: "arrow.right", color: .blue, text: "Break long texts into sections")
                            TipRow(icon: "repeat", color: .green, text: "Practice regularly for best results")
                        }
                    } header: {
                        Text("Tips")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Quote" : "Add Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveQuote()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let clipboardText = UIPasteboard.general.string {
            text = clipboardText
        }
    }

    private func saveQuote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        if let existingQuote = quoteToEdit {
            // Update existing
            var updated = existingQuote
            updated.title = trimmedTitle
            updated.text = trimmedText
            updated.category = category
            quoteStore.updateQuote(updated)
        } else {
            // Create new
            let newQuote = Quote(
                title: trimmedTitle,
                text: trimmedText,
                category: category
            )
            quoteStore.addQuote(newQuote)
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
                    Text("+\(words.count - 20) more")
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
}

#Preview("Edit Quote") {
    QuoteInputView(quoteToEdit: Quote(
        title: "Test Quote",
        text: "This is a test quote that I want to memorize.",
        category: .general
    ))
    .environmentObject(QuoteStore())
}
