import SwiftUI

struct NotchOverlayView: View {
    @Environment(SessionManager.self) private var manager
    @State private var isHovered = false
    var onTap: () -> Void = {}

    private var activeDots: [AgentSession] {
        manager.agents.filter { $0.status == .running || $0.status == .waiting }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))

            // Always show dots for running/waiting agents
            if !activeDots.isEmpty {
                ForEach(activeDots.prefix(8)) { agent in
                    StatusDot(status: agent.status)
                }
            }

            // On hover: also show idle agents + total count
            if isHovered && !manager.agents.isEmpty {
                let idleAgents = manager.agents.filter { $0.status == .idle }
                ForEach(idleAgents.prefix(6)) { agent in
                    StatusDot(status: agent.status)
                }

                Text("\(manager.agents.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, isHovered ? 14 : 10)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(.black.opacity(0.85))
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .contentShape(Capsule())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture { onTap() }
        .animation(.spring(duration: 0.3), value: manager.agents.count)
    }
}

struct StatusDot: View {
    let status: AgentStatus
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .shadow(color: status.color.opacity(isPulsing ? 0.6 : 0), radius: isPulsing ? 4 : 0)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .animation(
                status == .waiting
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear { isPulsing = status == .waiting }
            .onChange(of: status) { _, newValue in isPulsing = newValue == .waiting }
    }
}
