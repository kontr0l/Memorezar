import SwiftUI

/// Main screen for practicing recitation
/// Shows real-time feedback as user recites
struct RecitationScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var settingsStore: SettingsStore

    let quote: Quote

    @StateObject private var viewModel: RecitationViewModel

    init(quote: Quote) {
        self.quote = quote
        _viewModel = StateObject(wrappedValue: RecitationViewModel(quote: quote))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background flash for mistakes
                if viewModel.showMistakeFlash {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Progress bar
                    if settingsStore.showProgressBar {
                        progressBar
                    }

                    // Main content
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                // Title
                                Text(quote.title)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .padding(.top)

                                // Word display
                                wordDisplay(proxy: proxy)

                                // Status display
                                statusDisplay

                                Spacer(minLength: 100)
                            }
                            .padding()
                        }
                    }

                    // Control bar
                    controlBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.stop()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: viewModel.isListening ? "waveform" : "waveform.slash")
                            .foregroundColor(viewModel.isListening ? .green : .secondary)
                        Text(viewModel.isListening ? "Listening..." : "Paused")
                            .font(.subheadline)
                    }
                }
            }
            .onAppear {
                viewModel.settingsStore = settingsStore
                viewModel.requestPermissions()
            }
            .onDisappear {
                viewModel.stop()
            }
            .alert("Microphone Access Required", isPresented: $viewModel.showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Memorezar needs microphone access to hear your recitation. Please enable it in Settings.")
            }
            .sheet(isPresented: $viewModel.showResults) {
                ResultsView(
                    session: viewModel.createSession(),
                    quote: quote,
                    onDismiss: {
                        dismiss()
                    },
                    onRetry: {
                        viewModel.reset()
                    }
                )
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))

                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * viewModel.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Word Display

    private func wordDisplay(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 12) {
            FlowLayout(spacing: 8) {
                ForEach(Array(viewModel.words.enumerated()), id: \.offset) { index, wordState in
                    WordView(
                        word: wordState.word,
                        state: wordState.state,
                        isCurrentWord: index == viewModel.currentPosition,
                        fontSize: settingsStore.fontSize.pointSize,
                        isVisible: viewModel.shouldShowWord(at: index)
                    )
                    .id(index)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

            // Visibility controls
            if settingsStore.wordVisibility != .showAll {
                visibilityControls
            }
        }
        .onChange(of: viewModel.currentPosition) { _, newPosition in
            withAnimation {
                proxy.scrollTo(max(0, newPosition - 2), anchor: .center)
            }
        }
    }

    // MARK: - Visibility Controls

    private var visibilityControls: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation {
                    viewModel.toggleShowAllWords()
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.showAllWords ? "eye.fill" : "eye.slash.fill")
                    Text(viewModel.showAllWords ? "Hide Words" : "Show All Words")
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            if viewModel.showAllWords && settingsStore.wordVisibility == .partial {
                VStack(spacing: 4) {
                    HStack {
                        Text("Reveal:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(settingsStore.wordRevealPercentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { settingsStore.wordRevealPercentage },
                            set: { newValue in
                                settingsStore.wordRevealPercentage = newValue
                            }
                        ),
                        in: 0...100,
                        step: 5
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Status Display

    private var statusDisplay: some View {
        VStack(spacing: 16) {
            // Current stats
            HStack(spacing: 32) {
                StatLabel(
                    title: "Words",
                    value: "\(viewModel.currentPosition)/\(viewModel.words.count)"
                )

                StatLabel(
                    title: "Correct",
                    value: "\(viewModel.correctCount)",
                    color: .green
                )

                StatLabel(
                    title: "Mistakes",
                    value: "\(viewModel.mistakeCount)",
                    color: .red
                )
            }

            // Last mistake
            if let lastMistake = viewModel.lastMistake {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Expected: ")
                        .foregroundColor(.secondary)
                    + Text("\"\(lastMistake.expected)\"")
                        .foregroundColor(.primary)
                        .bold()

                    Text(" • Said: ")
                        .foregroundColor(.secondary)
                    + Text("\"\(lastMistake.spoken)\"")
                        .foregroundColor(.red)
                }
                .font(.subheadline)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Hint
            if settingsStore.showHints && viewModel.showHint, let hint = viewModel.hintWord {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Next word: \"\(hint)\"")
                        .italic()
                }
                .font(.subheadline)
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 24) {
                // Reset button
                Button {
                    viewModel.reset()
                } label: {
                    VStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Reset")
                            .font(.caption)
                    }
                }
                .foregroundColor(.orange)

                Spacer()

                // Main control button
                Button {
                    if viewModel.isListening {
                        viewModel.pause()
                    } else {
                        viewModel.start()
                    }
                } label: {
                    Image(systemName: viewModel.isListening ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(viewModel.isListening ? .orange : .blue)
                }

                Spacer()

                // Hint button
                Button {
                    viewModel.showHintNow()
                } label: {
                    VStack {
                        Image(systemName: "lightbulb")
                            .font(.title2)
                        Text("Hint")
                            .font(.caption)
                    }
                }
                .foregroundColor(.yellow)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Supporting Views

struct WordView: View {
    let word: String
    let state: WordState
    let isCurrentWord: Bool
    let fontSize: CGFloat
    var isVisible: Bool = true

    var body: some View {
        Group {
            if isVisible {
                Text(word)
                    .font(.system(size: fontSize, weight: isCurrentWord ? .bold : .regular))
                    .foregroundColor(foregroundColor)
            } else {
                // Show placeholder box with approximate word width
                Text(String(repeating: "_", count: word.count))
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            .background(Color(.systemGray5).cornerRadius(4))
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrentWord ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var foregroundColor: Color {
        switch state {
        case .pending: return .primary.opacity(0.5)
        case .correct: return .green
        case .incorrect: return .white
        case .current: return .primary
        }
    }

    private var backgroundColor: Color {
        if !isVisible && state == .pending {
            return .clear
        }
        switch state {
        case .pending: return .clear
        case .correct: return .green.opacity(0.2)
        case .incorrect: return .red
        case .current: return .blue.opacity(0.2)
        }
    }
}

struct StatLabel: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Results View

struct ResultsView: View {
    let session: PracticeSession
    let quote: Quote
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @EnvironmentObject var quoteStore: QuoteStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 20)

                    Circle()
                        .trim(from: 0, to: session.accuracy)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack {
                        Text(String(format: "%.0f%%", session.accuracy * 100))
                            .font(.system(size: 48, weight: .bold))

                        Text("Accuracy")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 200, height: 200)

                // Stats
                HStack(spacing: 32) {
                    VStack {
                        Text("\(session.correctWords)")
                            .font(.title.bold())
                            .foregroundColor(.green)
                        Text("Correct")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(session.totalWords - session.correctWords)")
                            .font(.title.bold())
                            .foregroundColor(.red)
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text(formatDuration(session.duration))
                            .font(.title.bold())
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Message
                Text(motivationalMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onRetry()
                    } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        quoteStore.recordSession(session)
                        onDismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var scoreColor: Color {
        if session.accuracy >= 0.9 { return .green }
        if session.accuracy >= 0.7 { return .orange }
        return .red
    }

    private var motivationalMessage: String {
        if session.accuracy >= 0.95 { return "Perfect! You've mastered this!" }
        if session.accuracy >= 0.9 { return "Excellent work! Almost perfect!" }
        if session.accuracy >= 0.8 { return "Great job! Keep practicing!" }
        if session.accuracy >= 0.7 { return "Good progress! You're getting there!" }
        if session.accuracy >= 0.5 { return "Nice effort! Practice makes perfect!" }
        return "Keep trying! Every attempt helps!"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
        return "\(seconds)s"
    }
}

#Preview {
    let quote = Quote(
        title: "Test Quote",
        text: "Four score and seven years ago our fathers brought forth on this continent a new nation."
    )
    return RecitationScreen(quote: quote)
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
}
