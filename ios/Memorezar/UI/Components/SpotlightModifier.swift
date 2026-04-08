import SwiftUI

// MARK: - Action Tip Modifier

/// Wiggle + glow + post-it tooltip on a button.
/// Shows every launch until the button is actually tapped.
/// Uses .simultaneousGesture so the button's own action still fires.
struct ActionTipModifier: ViewModifier {
    @EnvironmentObject var tutorialStore: TutorialStore

    let tip: TipDefinition
    var delay: TimeInterval = 0.6

    @State private var isShowing = false
    @State private var wiggleAngle: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var wiggleTimer: Timer?

    private let tipColor = Color(red: 1.0, green: 0.85, blue: 0.2)

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(wiggleAngle))
            .shadow(
                color: tipColor.opacity(glowOpacity),
                radius: isShowing ? 14 : 0
            )
            .background {
                if isShowing {
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: TipAnchorKey.self,
                                value: [tip.id: geo.frame(in: .global)]
                            )
                    }
                }
            }
            // Detect tap without stealing it from the button
            .simultaneousGesture(TapGesture().onEnded {
                if isShowing {
                    tutorialStore.completeTip(tip.id)
                    stopAnimations()
                }
            })
            .onAppear {
                guard tutorialStore.shouldShowTip(tip) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard tutorialStore.shouldShowTip(tip) else { return }
                    startAnimations()
                }
            }
            .onDisappear {
                stopWiggleTimer()
            }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.25)) {
            isShowing = true
        }

        wiggle()

        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            glowOpacity = 0.7
        }

        wiggleTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if isShowing { wiggle() }
            }
        }
    }

    private func stopAnimations() {
        stopWiggleTimer()
        withAnimation(.easeIn(duration: 0.2)) {
            isShowing = false
            glowOpacity = 0
        }
        wiggleAngle = 0
    }

    private func wiggle() {
        let d = 0.08
        withAnimation(.easeInOut(duration: d)) { wiggleAngle = 8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + d) {
            withAnimation(.easeInOut(duration: d)) { wiggleAngle = -6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + d * 2) {
            withAnimation(.easeInOut(duration: d)) { wiggleAngle = 5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + d * 3) {
            withAnimation(.easeInOut(duration: d)) { wiggleAngle = -3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + d * 4) {
            withAnimation(.easeInOut(duration: d)) { wiggleAngle = 0 }
        }
    }

    private func stopWiggleTimer() {
        wiggleTimer?.invalidate()
        wiggleTimer = nil
    }
}

// MARK: - Preference Key (supports multiple tips per screen)

struct TipAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Tip Overlay (renders tooltip outside clipping bounds)

struct TipOverlayModifier: ViewModifier {
    @EnvironmentObject var tutorialStore: TutorialStore
    let tip: TipDefinition
    var verticalOffset: CGFloat = 0

    @State private var buttonFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(TipAnchorKey.self) { frames in
                if let frame = frames[tip.id] {
                    buttonFrame = frame
                }
            }
            .overlay(alignment: .topLeading) {
                if buttonFrame != .zero, tutorialStore.shouldShowTip(tip) {
                    GeometryReader { geo in
                        let parentOrigin = geo.frame(in: .global).origin
                        let localCenterX = buttonFrame.midX - parentOrigin.x
                        let localTop = buttonFrame.minY - parentOrigin.y

                        let screenWidth = geo.size.width
                        let edgePadding: CGFloat = 40
                        let clampedX = min(max(localCenterX, edgePadding), screenWidth - edgePadding)
                        let arrowOffset = localCenterX - clampedX

                        TooltipBubble(text: tip.content, arrowOffset: arrowOffset)
                            .fixedSize()
                            .position(x: clampedX, y: localTop - 28 + verticalOffset)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func actionTip(_ tip: TipDefinition, delay: TimeInterval = 0.6) -> some View {
        modifier(ActionTipModifier(tip: tip, delay: delay))
    }

    func tipOverlay(_ tip: TipDefinition, verticalOffset: CGFloat = 0) -> some View {
        modifier(TipOverlayModifier(tip: tip, verticalOffset: verticalOffset))
    }
}
