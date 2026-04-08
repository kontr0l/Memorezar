import SwiftUI

struct QuoteAccuracyDetailView: View {
    @EnvironmentObject var quoteStore: QuoteStore
    let quoteId: UUID

    // Scissors button callback — dismisses this sheet and opens split overlay on parent
    var onScissors: (() -> Void)? = nil
    // Called after stats are reset so parent can update slider etc.
    var onReset: (() -> Void)? = nil

    /// Live quote from the store (reflects resets immediately)
    private var quote: Quote {
        quoteStore.getQuote(byId: quoteId) ?? Quote(title: "", text: "")
    }

    private var sessions: [PracticeSession] {
        quoteStore.getSessions(for: quoteId)
    }

    @State private var showingResetAlert = false
    @State private var showConfetti = false
    @State private var badgeId = UUID()

    /// Trouble phrases: group mistakes by position, extract 5-word context, deduplicate by text
    private var troublePhrases: [String] {
        let quoteWords = quote.text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var positionCounts: [Int: Int] = [:]
        for session in sessions {
            for mistake in session.mistakes where mistake.certainty == .definite {
                positionCounts[mistake.position, default: 0] += 1
            }
        }
        let topPositions = positionCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(6)
            .map(\.key)

        var seen = Set<String>()
        var result: [String] = []
        for pos in topPositions {
            guard pos >= 0, pos < quoteWords.count else { continue }
            let start = max(0, pos - 2)
            let end = min(quoteWords.count - 1, pos + 2)
            let phrase = quoteWords[start...end].joined(separator: " ")
            let normalized = phrase.lowercased()
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(phrase)
            if result.count >= 3 { break }
        }
        return result
    }

    /// Recent sessions (last 3, newest first)
    private var recentSessions: [PracticeSession] {
        Array(sessions.sorted { $0.completedAt > $1.completedAt }.prefix(3))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Current level badge or mastered badge
                    LevelBadge(level: max(1, quote.revealLevel), masteryLevel: quote.masteryLevel)
                        .id(badgeId)
                        .padding(.top, 4)

                    // Key stats row
                    statsRow

                    // Trouble phrases
                    if !troublePhrases.isEmpty {
                        troublePhrasesSection
                    }

                    // Recent sessions
                    if !recentSessions.isEmpty {
                        recentSessionsSection
                    }

                    // Reset stats
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset Statistics", systemImage: "arrow.counterclockwise")
                    }
                    .padding(.top, 8)
                }
                .padding()
            }

            if showConfetti {
                StatsConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if quote.masteryLevel == .mastered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showConfetti = true
                }
            }
        }
        .navigationTitle(quote.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Statistics", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                quoteStore.resetQuoteStats(quote)
                showConfetti = false
                badgeId = UUID()
                onReset?()
            }
        } message: {
            Text("This will reset all practice history, accuracy, and level progress for this quote.")
        }
        .toolbar {
            if onScissors != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onScissors?()
                    } label: {
                        Image(systemName: "scissors")
                    }
                }
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: String(localized: "\(quote.practiceCount)"),
                label: String(localized: "Attempts")
            )
            Divider().frame(height: 40)
            statItem(
                value: String(format: "%.0f%%", quote.bestAccuracy * 100),
                label: String(localized: "Best")
            )
            Divider().frame(height: 40)
            statItem(
                value: lastPracticedLabel,
                label: String(localized: "Last Practiced")
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }

    private var lastPracticedLabel: String {
        guard let date = quote.lastPracticedAt else { return String(localized: "Never") }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return String(localized: "Today") }
        if days == 1 { return String(localized: "Yesterday") }
        if days < 7 { return String(localized: "\(days)d ago") }
        if days < 30 { return String(localized: "\(days / 7)w ago") }
        return String(localized: "\(days / 30)mo ago")
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trouble Phrases

    private var troublePhrasesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trouble Spots")
                .font(.headline)

            ForEach(troublePhrases.indices, id: \.self) { idx in
                Text(troublePhrases[idx])
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)

            ForEach(recentSessions) { session in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(relativeDate(session.completedAt))
                            .font(.subheadline)
                        HStack(spacing: 6) {
                            Text(formatDuration(session.duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if session.mistakes.count > 0 {
                                Text(String(localized: "\(session.mistakes.count) mistake\(session.mistakes.count == 1 ? "" : "s")"))
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()

                    Text(String(format: "%.0f%%", session.accuracy * 100))
                        .font(.headline)
                        .foregroundColor(accuracyColor(session.accuracy))
                }
                .padding(.vertical, 2)
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

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return String(localized: "Today") }
        if days == 1 { return String(localized: "Yesterday") }
        if days < 7 { return String(localized: "\(days) days ago") }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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

// MARK: - Level Badge

struct LevelBadge: View {
    let level: Int
    var masteryLevel: MasteryLevel = .none
    var isMastered: Bool { masteryLevel == .mastered }
    @State private var animate = false
    @State private var bounced = false
    var body: some View {
        VStack(spacing: 4) {
            iconView
                .frame(height: 100)
            badgeText(badgeLabel)
                .animation(nil, value: animate)
        }
        .frame(height: 150)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    animate = true
                }
                bounced = true
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if isMastered {
            Image(systemName: "crown.fill")
                .font(.system(size: 100))
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: bounced)
        } else {
            switch level {
            case 2:
                if #available(iOS 26.0, *) {
                    ZStack {
                        // Invisible placeholder to reserve space
                        Image(systemName: "lightbulb.max.fill")
                            .font(.system(size: 80))
                            .opacity(0)
                        if animate {
                            Image(systemName: "lightbulb.max.fill")
                                .font(.system(size: 80))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.yellow, .orange)
                                .transition(.symbolEffect(.drawOn.individually))
                        }
                    }
                } else {
                    Image(systemName: "lightbulb.max.fill")
                        .font(.system(size: 80))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.yellow, .orange)
                        .symbolEffect(.variableColor.cumulative.dimInactiveLayers, isActive: animate)
                }

            case 3:
                if #available(iOS 26.0, *) {
                    ZStack {
                        // Invisible placeholder to reserve space
                        Image(systemName: "sparkles")
                            .font(.system(size: 100))
                            .opacity(0)
                        if animate {
                            Image(systemName: "sparkles")
                                .font(.system(size: 100))
                                .foregroundStyle(badgeColor)
                                .symbolRenderingMode(.hierarchical)
                                .transition(.symbolEffect(.drawOn.individually))
                        }
                    }
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 100))
                        .foregroundStyle(badgeColor)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.variableColor.cumulative.dimInactiveLayers, isActive: animate)
                }

            default:
                Image(systemName: "leaf.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(badgeColor)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: bounced)
            }
        }
    }

    // MARK: - Styling

    private func badgeText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 45, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.3)
            .lineLimit(1)
            .foregroundColor(badgeColor)
    }

    private var badgeLabel: String {
        masteryLevel.localizedName
    }

    private var badgeColor: Color {
        if isMastered { return .yellow }
        switch level {
        case 1: return .green
        case 2: return .orange
        case 3: return .indigo
        default: return .green
        }
    }
}

// MARK: - Stats Confetti

struct StatsConfettiView: View {
    private let colors: [Color] = [.yellow, .orange, .red, .blue, .green, .purple]
    @State private var pieces: [(id: Int, x: CGFloat, delay: Double, color: Color, size: CGFloat)] = []
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces, id: \.id) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .position(
                            x: piece.x,
                            y: fallen ? geo.size.height + 20 : -20
                        )
                        .animation(
                            .easeIn(duration: Double.random(in: 1.5...3.0))
                                .delay(piece.delay),
                            value: fallen
                        )
                }
            }
            .onAppear {
                pieces = (0..<40).map { i in
                    (
                        id: i,
                        x: CGFloat.random(in: 0...geo.size.width),
                        delay: Double.random(in: 0...0.5),
                        color: colors.randomElement()!,
                        size: CGFloat.random(in: 4...10)
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fallen = true
                }
            }
        }
    }
}
