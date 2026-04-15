import SwiftUI

enum DS {
    // MARK: - Midnight Forge Palette

    // Base layers — deep blue-black, not pure black
    static let base = Color(red: 0.047, green: 0.055, blue: 0.078)       // #0C0E14
    static let surface1 = Color(red: 0.071, green: 0.078, blue: 0.110)   // #12141C
    static let surface2 = Color(red: 0.094, green: 0.106, blue: 0.145)   // #181B25
    static let surface3 = Color(red: 0.118, green: 0.130, blue: 0.188)   // #1E2130

    // Accents
    static let cyan = Color(red: 0.0, green: 0.83, blue: 1.0)            // #00D4FF
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.0)           // #FFB800
    static let emerald = Color(red: 0.0, green: 0.90, blue: 0.54)        // #00E68A
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)          // #FF6B6B
    static let violet = Color(red: 0.60, green: 0.40, blue: 1.0)         // #9966FF

    // Text hierarchy — off-white, not pure white
    static let text1 = Color(red: 0.91, green: 0.93, blue: 0.96)         // #E8ECF4
    static let text2 = Color(red: 0.55, green: 0.58, blue: 0.67)         // #8C95AB
    static let text3 = Color(red: 0.35, green: 0.38, blue: 0.46)         // #596175

    // Terminal
    static let termBg = Color(red: 0.035, green: 0.040, blue: 0.060)     // #090A0F
    static let termText = Color(red: 0.66, green: 0.85, blue: 0.73)      // #A8D8B9
    static let termPrompt = Color(red: 0.0, green: 0.83, blue: 1.0)      // cyan

    // Borders & glass
    static let glassBorder = Color.white.opacity(0.07)
    static let glassHighlight = Color.white.opacity(0.12)

    // MARK: - Spacing
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space6: CGFloat = 6
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16

    // MARK: - Radius
    static let r6: CGFloat = 6
    static let r8: CGFloat = 8
    static let r10: CGFloat = 10
    static let r12: CGFloat = 12

    // MARK: - Animations
    static let snapSpring = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.82)
    static let gentleSpring = Animation.spring(response: 0.55, dampingFraction: 0.88)
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    let accentColor: Color
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background(DS.surface1)
            .clipShape(RoundedRectangle(cornerRadius: DS.r10))
            .overlay {
                RoundedRectangle(cornerRadius: DS.r10)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isActive ? accentColor.opacity(0.4) : DS.glassHighlight,
                                DS.glassBorder
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

extension View {
    func glassCard(accent: Color = DS.cyan, active: Bool = false) -> some View {
        modifier(GlassCard(accentColor: accent, isActive: active))
    }

    func glow(_ color: Color, radius: CGFloat = 6, active: Bool = true) -> some View {
        self
            .shadow(color: active ? color.opacity(0.4) : .clear, radius: radius)
            .shadow(color: active ? color.opacity(0.15) : .clear, radius: radius * 2.5)
    }
}
