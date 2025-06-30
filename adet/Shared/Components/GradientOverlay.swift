import SwiftUI

// MARK: - Gradient Overlay Component

struct GradientOverlay: View {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    let opacity: Double

    init(
        colors: [Color] = [Color.accentColor.opacity(0.1), Color.clear],
        startPoint: UnitPoint = .top,
        endPoint: UnitPoint = .bottom,
        opacity: Double = 1.0
    ) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.opacity = opacity
    }

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
        .opacity(opacity)
    }
}

// MARK: - Predefined Gradient Styles

extension GradientOverlay {
    static var friendsAccent: GradientOverlay {
        GradientOverlay(
            colors: [Color.accentColor.opacity(0.05), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
            opacity: 0.8
        )
    }

    static var success: GradientOverlay {
        GradientOverlay(
            colors: [Color.green.opacity(0.1), Color.clear],
            startPoint: .leading,
            endPoint: .trailing,
            opacity: 0.6
        )
    }

    static var warning: GradientOverlay {
        GradientOverlay(
            colors: [Color.orange.opacity(0.1), Color.clear],
            startPoint: .leading,
            endPoint: .trailing,
            opacity: 0.6
        )
    }

    static var subtle: GradientOverlay {
        GradientOverlay(
            colors: [Color.primary.opacity(0.02), Color.clear],
            startPoint: .top,
            endPoint: .bottom,
            opacity: 1.0
        )
    }
}

// MARK: - Instagram-Style Card Background

struct InstagramCardBackground: View {
    let isHighlighted: Bool

    init(isHighlighted: Bool = false) {
        self.isHighlighted = isHighlighted
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(isHighlighted ? 0.05 : 0.02),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(
                color: Color.black.opacity(isHighlighted ? 0.1 : 0.05),
                radius: isHighlighted ? 4 : 2,
                x: 0,
                y: isHighlighted ? 2 : 1
            )
    }
}

// MARK: - View Extensions

extension View {
    func friendsCardBackground(isHighlighted: Bool = false) -> some View {
        self.background(InstagramCardBackground(isHighlighted: isHighlighted))
    }

    func gradientOverlay(_ style: GradientOverlay) -> some View {
        self.overlay(style)
    }
}