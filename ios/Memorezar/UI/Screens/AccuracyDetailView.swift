import SwiftUI

struct AccuracyDetailView: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var selectedQuote: Quote?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                        .frame(width: 70, height: 70)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)

                    Text(String(format: "%.0f%%", quoteStore.averageAccuracy * 100))
                        .font(.system(size: 36, weight: .bold))

                    Text("Overall Accuracy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Improvement indicator
                    improvementIndicator
                }
                .padding(.top)

                // Per-quote breakdown
                perQuoteSection

                // Recent sessions
                if !recentSessions.isEmpty {
                    recentSessionsSection
                }

                // Common mistakes
                if !commonMistakes.isEmpty {
                    commonMistakesSection
                }
            }
            .padding()
        }
        .navigationTitle("Accuracy")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedQuote) { quote in
            RecitationScreen(quote: quote)
        }
    }

    // MARK: - Improvement Indicator

    @ViewBuilder
    private var improvementIndicator: some View {
        if let improvement = quoteStore.accuracyImprovement {
            HStack(spacing: 4) {
                Image(systemName: improvement >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.bold())
                Text(String(format: "%+.1f%%", improvement * 100))
                    .font(.caption.bold())
                Text("vs previous")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(improvement >= 0 ? .green : .red)
        } else {
            Text("Not enough data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Per-Quote Breakdown

    private var practicedQuotes: [Quote] {
        quoteStore.quotes
            .filter { $0.practiceCount > 0 }
            .sorted { $0.bestAccuracy < $1.bestAccuracy }
    }

    private var perQuoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Quote Breakdown")
                .font(.headline)

            if practicedQuotes.isEmpty {
                Text("No quotes practiced yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(practicedQuotes) { quote in
                    Button {
                        selectedQuote = quote
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quote.displayTitle)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    MasteryBadge(level: quote.masteryLevel)
                                    Text(String(localized: "\(quote.practiceCount) practices"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Text(String(format: "%.0f%%", quote.bestAccuracy * 100))
                                .font(.title3.bold())
                                .foregroundColor(accuracyColor(quote.bestAccuracy))

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
        }
    }

    // MARK: - Recent Sessions

    private var recentSessions: [PracticeSession] {
        Array(quoteStore.sessions
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(10))
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if recentSessions.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentSessions) { session in
                    let quoteTitle = quoteStore.getQuote(byId: session.quoteId)?.title ?? String(localized: "Unknown")

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quoteTitle)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text(session.completedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatDuration(session.duration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text(String(format: "%.0f%%", session.accuracy * 100))
                            .font(.headline)
                            .foregroundColor(accuracyColor(session.accuracy))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }

    // MARK: - Common Mistakes

    private var commonMistakes: [(expected: String, spoken: String, count: Int)] {
        var counts: [String: Int] = [:]

        for session in quoteStore.sessions {
            for mistake in session.mistakes where mistake.certainty == .definite {
                let key = "\(mistake.expectedWord.lowercased())→\(mistake.spokenWord.lowercased())"
                counts[key, default: 0] += 1
            }
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { entry in
                let parts = entry.key.split(separator: "→", maxSplits: 1)
                return (
                    expected: String(parts[0]),
                    spoken: String(parts[1]),
                    count: entry.value
                )
            }
    }

    private var commonMistakesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common Mistakes")
                .font(.headline)

            if commonMistakes.isEmpty {
                Text("No mistakes recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(commonMistakes.indices, id: \.self) { idx in
                    let mistake = commonMistakes[idx]
                    HStack(spacing: 8) {
                        Text(mistake.expected)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(mistake.spoken)
                            .font(.subheadline)
                            .foregroundColor(.red)

                        Spacer()

                        Text(String(localized: "\(mistake.count)x"))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }

    // MARK: - Helpers

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.9 { return .green }
        if accuracy >= 0.7 { return .orange }
        return .red
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return String(localized: "\(mins)m \(secs)s")
        }
        return String(localized: "\(secs)s")
    }
}
