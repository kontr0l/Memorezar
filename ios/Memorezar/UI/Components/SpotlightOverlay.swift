import SwiftUI

// MARK: - Spotlight Preference Key

struct SpotlightAnchor {
    let id: String
    let bounds: Anchor<CGRect>
}

struct SpotlightPreferenceKey: PreferenceKey {
    static var defaultValue: [SpotlightAnchor] = []
    static func reduce(value: inout [SpotlightAnchor], nextValue: () -> [SpotlightAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Mark this view as a spotlight target with the given step ID.
    func spotlightAnchor(_ id: String) -> some View {
        self.anchorPreference(key: SpotlightPreferenceKey.self, value: .bounds) { anchor in
            [SpotlightAnchor(id: id, bounds: anchor)]
        }
    }
}

// MARK: - Tutorial Step

struct TutorialStep {
    let anchorId: String
    let text: String
    let position: TooltipPosition
    var padding: CGFloat = 8
    var cornerRadius: CGFloat = 12

    enum TooltipPosition {
        case above
        case below
    }
}

// MARK: - Spotlight Overlay

struct SpotlightOverlay: View {
    let steps: [TutorialStep]
    let anchors: [SpotlightAnchor]
    @Binding var currentStep: Int
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let step = steps[currentStep]
            let rect = anchorRect(for: step.anchorId, in: proxy)

            ZStack {
                // Dimmed background with cutout
                SpotlightCutout(
                    highlight: rect,
                    padding: step.padding,
                    cornerRadius: step.cornerRadius
                )
                .fill(style: FillStyle(eoFill: true))
                .foregroundColor(.black.opacity(0.7))
                .onTapGesture {
                    advance()
                }

                // Tooltip
                if let rect = rect {
                    tooltipView(step: step, targetRect: rect, proxySize: proxy.size)
                        .onTapGesture {
                            advance()
                        }
                }

            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .ignoresSafeArea()
    }

    private func anchorRect(for id: String, in proxy: GeometryProxy) -> CGRect? {
        guard let anchor = anchors.first(where: { $0.id == id }) else { return nil }
        return proxy[anchor.bounds]
    }

    private func advance() {
        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            onDismiss()
        }
    }

    @ViewBuilder
    private func tooltipView(step: TutorialStep, targetRect: CGRect, proxySize: CGSize) -> some View {
        let tooltipWidth: CGFloat = min(260, proxySize.width - 48)

        VStack(spacing: 0) {
            if step.position == .below {
                Triangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 16, height: 8)
                    .rotationEffect(.degrees(180))

                tooltipContent(step: step)
                    .frame(width: tooltipWidth)
            } else {
                tooltipContent(step: step)
                    .frame(width: tooltipWidth)

                Triangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 16, height: 8)
            }
        }
        .position(
            x: clamp(targetRect.midX, min: tooltipWidth / 2 + 16, max: proxySize.width - tooltipWidth / 2 - 16),
            y: step.position == .below
                ? targetRect.maxY + step.padding + 32
                : targetRect.minY - step.padding - 32
        )
    }

    private func tooltipContent(step: TutorialStep) -> some View {
        Text(.init(step.text))
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}

// MARK: - Spotlight Cutout Shape

struct SpotlightCutout: Shape {
    let highlight: CGRect?
    let padding: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if let highlight = highlight {
            let cutout = highlight.insetBy(dx: -padding, dy: -padding)
            path.addRoundedRect(in: cutout, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        return path
    }
}

// MARK: - Tooltip Bubble (Post-it style, used elsewhere)

struct TooltipBubble: View {
    let text: LocalizedStringKey
    var arrowOffset: CGFloat = 0

    private let noteColor = Color(red: 1.0, green: 0.95, blue: 0.6)

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .multilineTextAlignment(.center)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.black.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(noteColor)
                .cornerRadius(8)

            Triangle()
                .fill(noteColor)
                .frame(width: 14, height: 8)
                .offset(x: arrowOffset)
        }
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}
