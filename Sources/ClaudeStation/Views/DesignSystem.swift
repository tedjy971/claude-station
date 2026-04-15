import SwiftUI

enum DS {
    // MARK: - Brand Colors
    static let accent = Color(red: 0.35, green: 0.56, blue: 1.0)
    static let purple = Color(red: 0.55, green: 0.36, blue: 0.97)
    static let green = Color(red: 0.20, green: 0.83, blue: 0.44)
    static let orange = Color(red: 1.0, green: 0.65, blue: 0.15)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let idle = Color(white: 0.45)

    // MARK: - Surfaces
    static let card = Color.white.opacity(0.06)
    static let cardHover = Color.white.opacity(0.10)
    static let cardBorder = Color.white.opacity(0.09)
    static let codeBg = Color.white.opacity(0.04)

    // MARK: - Text
    static let text1 = Color.white.opacity(0.92)
    static let text2 = Color.white.opacity(0.55)
    static let text3 = Color.white.opacity(0.30)

    // MARK: - Radius
    static let r8: CGFloat = 8
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16

    // MARK: - Animations
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.75)
    static let springSmooth = Animation.spring(response: 0.45, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.35, dampingFraction: 0.6)
}

// MARK: - Glow Modifier

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let active: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? color.opacity(0.5) : .clear, radius: radius)
            .shadow(color: active ? color.opacity(0.25) : .clear, radius: radius * 2)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 6, active: Bool = true) -> some View {
        modifier(GlowModifier(color: color, radius: radius, active: active))
    }
}

// MARK: - Status Bar Modifier

struct StatusBarModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            LinearGradient(
                colors: [color, color.opacity(0.3)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .clipShape(RoundedRectangle(cornerRadius: 1))
        }
    }
}

extension View {
    func statusBar(color: Color) -> some View {
        modifier(StatusBarModifier(color: color))
    }
}
