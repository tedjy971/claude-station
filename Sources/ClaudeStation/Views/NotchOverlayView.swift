import SwiftUI

struct NotchOverlayView: View {
    @Environment(SessionManager.self) private var manager
    @State private var isHovered = false
    @State private var breathe = false
    var onTap: () -> Void = {}

    private var activeDots: [AgentSession] {
        manager.agents.filter { $0.status == .running || $0.status == .waiting }
    }

    private var glowColor: Color {
        if manager.hasWaiting { return DS.amber }
        if manager.runningCount > 0 { return DS.cyan }
        return .clear
    }

    var body: some View {
        HStack(spacing: isHovered ? 7 : 4) {
            // Lambda icon — unique brand mark
            Text("λ")
                .font(.system(size: isHovered ? 14 : 12, weight: .bold, design: .monospaced))
                .foregroundStyle(activeDots.isEmpty ? DS.text3 : DS.cyan)

            // Active dots
            ForEach(activeDots.prefix(6)) { agent in
                BreathingDot(color: agent.status == .waiting ? DS.amber : DS.cyan)
            }

            // Hover expansion
            if isHovered && !manager.agents.isEmpty {
                let idleAgents = manager.agents.filter { $0.status == .idle }
                ForEach(idleAgents.prefix(4)) { agent in
                    Circle()
                        .fill(DS.text3.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .transition(.scale.combined(with: .opacity))
                }

                Text("\(manager.agents.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.text2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, isHovered ? 16 : 12)
        .padding(.vertical, isHovered ? 8 : 6)
        .background {
            Capsule()
                .fill(Color.black)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [DS.glassHighlight, DS.glassBorder, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: glowColor.opacity(breathe ? 0.35 : 0.1),
                    radius: isHovered ? 20 : 12
                )
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Capsule())
        .onHover { h in withAnimation(DS.snapSpring) { isHovered = h } }
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Breathing Dot

struct BreathingDot: View {
    let color: Color
    @State private var phase = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(phase ? 0.25 : 0.0))
                .frame(width: 14, height: 14)

            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.6), radius: phase ? 4 : 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}
