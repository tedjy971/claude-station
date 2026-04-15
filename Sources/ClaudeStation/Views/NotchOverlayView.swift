import SwiftUI

struct NotchOverlayView: View {
    @Environment(SessionManager.self) private var manager
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            if manager.activeAgents.isEmpty && !manager.agents.isEmpty {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(manager.agents.count) idle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else if manager.agents.isEmpty {
                Image(systemName: "cloud")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(manager.activeAgents.prefix(8)) { agent in
                    StatusDot(status: agent.status)
                }
                if manager.activeAgents.count > 8 {
                    Text("+\(manager.activeAgents.count - 8)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(.black.opacity(0.8))
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
        }
        .contentShape(Capsule())
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.3), value: manager.agents.count)
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
