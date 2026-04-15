import SwiftUI

struct AgentRowView: View {
    let agent: AgentSession

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(agent.status.color)
                .frame(width: 10, height: 10)
                .shadow(color: agent.status == .waiting ? agent.status.color.opacity(0.6) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(agent.workspace)
                        .font(.system(.body, weight: .medium))

                    if agent.isUnread {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                    }
                }

                if !agent.task.isEmpty {
                    Text(agent.task)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(agent.status.label)
                    .font(.caption2)
                    .foregroundStyle(agent.status.color)
            }

            Spacer()

            Text(agent.formattedDuration)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
