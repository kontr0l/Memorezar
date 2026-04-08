import SwiftUI

/// Sheet for splitting a quote into multiple smaller quotes at natural punctuation boundaries
struct QuoteSplitView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore

    let quote: Quote

    @State private var chunkCount: Int = 3
    @State private var previewChunks: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quote info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quote.displayTitle)
                            .font(.headline)
                        Text(quote.preview)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(String(localized: "\(quote.wordCount) words"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Chunk count stepper
                    HStack {
                        Label("Number of chunks", systemImage: "scissors")
                            .font(.subheadline)
                        Spacer()
                        Stepper("\(chunkCount)", value: $chunkCount, in: 2...10)
                            .labelsHidden()
                        Text("\(chunkCount)")
                            .font(.title3.bold())
                            .monospacedDigit()
                            .frame(width: 30)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Live preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)

                        ForEach(Array(previewChunks.enumerated()), id: \.offset) { index, chunk in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "Chunk \(index + 1) of \(previewChunks.count)"))
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)

                                Text(chunk)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(4)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }

                    // Split / Remove Split buttons
                    if quote.isSplit {
                        Button(role: .destructive) {
                            removeSplit()
                        } label: {
                            Label("Remove Split", systemImage: "arrow.uturn.backward")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.top, 4)
                    }

                    Button {
                        performSplit()
                    } label: {
                        Label(String(localized: "Split into \(previewChunks.count) Parts"), systemImage: "scissors")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Split Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updatePreview()
            }
            .onChange(of: chunkCount) { _, _ in
                updatePreview()
            }
        }
    }

    private func updatePreview() {
        previewChunks = TextChunker.split(quote.text, into: chunkCount)
    }

    private func performSplit() {
        let chunks = TextChunker.split(quote.text, into: chunkCount)
        var updated = quote
        updated.chunks = chunks
        quoteStore.updateQuote(updated)
        dismiss()
    }

    private func removeSplit() {
        var updated = quote
        updated.chunks = nil
        quoteStore.updateQuote(updated)
        dismiss()
    }
}
