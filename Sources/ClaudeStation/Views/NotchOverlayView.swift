import SwiftUI

struct NotchOverlayView: View {
    @Environment(SessionManager.self) private var manager
    @State private var isHovered = false
    @State private var glowPulse = false
    var onTap: () -> Void = {}

    private var activeDots: [AgentSession] {
        manager.agents.filter { $0.status == .running || $0.status == .waiting }
    }

    private var glowColor: Color {
        if manager.hasWaiting { return DS.orange }
        if manager.runningCount > 0 { return DS.accent }
        return .clear
    }

    private var hasGlow: Bool { !activeDots.isEmpty }

    var body: some View {
        HStack(spacing: isHovered ? 8 : 5) {
            // Cloud icon — always visible
            Image(systemName: manager.hasWaiting ? "exclamationmark.cloud.fill" : "cloud.fill")
                .font(.system(size: isHovered ? 13 : 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))

            // Active dots — always visible
            ForEach(activeDots.prefix(6)) { agent in
                IslandDot(status: agent.status)
            }

            // Hover expansion
            if isHovered && !manager.agents.isEmpty {
                let idleAgents = manager.agents.filter { $0.status == .idle }
                ForEach(idleAgents.prefix(4)) { agent in
                    IslandDot(status: agent.status)
                        .transition(.scale.combined(with: .opacity))
                }

                Text("\(manager.agents.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, isHovered ? 18 : 12)
        .padding(.vertical, isHovered ? 9 : 7)
        .background { capsuleBackground }
        .contentShape(Capsule())
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { h in
            withAnimation(DS.springSnappy) { isHovered = h }
        }
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var capsuleBackground: some View {
        Capsule()
            .fill(.black)
            // Inner highlight
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            // Status glow
            .shadow(
                color: glowColor.opacity(glowPulse ? 0.45 : 0.15),
                radius: isHovered ? 16 : 10
            )
            .shadow(
                color: glowColor.opacity(glowPulse ? 0.2 : 0.0),
                radius: 24
            )
    }
}

// MARK: - Island Dot (premium version)

struct IslandDot: View {
    let status: AgentStatus
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer glow ring
            if status == .waiting || status == .running {
                Circle()
                    .fill(status.color.opacity(pulse ? 0.3 : 0.0))
                    .frame(width: 14, height: 14)
            }

            // Core dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [status.color, status.color.opacity(0.7)],
                        center: .center,
                        startRadius: 0, endRadius: 5
                    )
                )
                .frame(width: status == .idle ? 6 : 8, height: status == .idle ? 6 : 8)
                .shadow(color: status.color.opacity(0.5), radius: status == .idle ? 0 : 3)
        }
        .scaleEffect(pulse && status == .waiting ? 1.2 : 1.0)
        .onAppear {
            guard status == .waiting else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: status) { _, new in
            pulse = false
            guard new == .waiting else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
