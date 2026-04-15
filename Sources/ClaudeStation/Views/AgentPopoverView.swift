import SwiftUI

struct AgentPopoverView: View {
    @Environment(SessionManager.self) private var manager
    @State private var expandedAgent: String?
    @State private var fullOutput: String = ""
    @State private var loadingOutput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if manager.agents.isEmpty {
                emptyState
            } else {
                agentList
            }
        }
        .frame(width: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "cloud.fill")
                .foregroundStyle(.blue)
            Text("Claude Station")
                .font(.system(.headline, design: .rounded))
            Spacer()

            if manager.runningCount > 0 {
                badge("\(manager.runningCount) active", color: .blue)
            }
            let idleCount = manager.agents.filter { $0.status == .idle }.count
            if idleCount > 0 {
                badge("\(idleCount) idle", color: .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No Claude sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - List

    private var agentList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(manager.agents) { agent in
                    agentRow(agent)
                    if agent.id != manager.agents.last?.id {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 500)
    }

    // MARK: - Row

    @ViewBuilder
    private func agentRow(_ agent: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: agent.status.systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(agent.status.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(agent.workspace)
                            .font(.system(.body, weight: .semibold))

                        Text(agent.status.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(agent.status.color.opacity(0.15))
                            .foregroundStyle(agent.status.color)
                            .clipShape(Capsule())

                        Spacer()

                        Text(agent.formattedDuration)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    // Last message preview
                    if !agent.lastMessage.isEmpty {
                        Text(agent.lastMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }

                // Navigate button
                Button {
                    manager.navigateToAgent(agent)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Open terminal")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedAgent == agent.id {
                        expandedAgent = nil
                    } else {
                        expandedAgent = agent.id
                        loadFullOutput(agent)
                    }
                }
            }

            // Expanded: full output
            if expandedAgent == agent.id {
                expandedOutput
            }
        }
    }

    // MARK: - Expanded Output

    private var expandedOutput: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Terminal Output")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if loadingOutput {
                    ProgressView().controlSize(.mini)
                }
            }

            Text(fullOutput.isEmpty ? "No output" : fullOutput)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func loadFullOutput(_ agent: AgentSession) {
        loadingOutput = true
        fullOutput = ""
        Task {
            let text = await manager.loadOutput(for: agent)
            loadingOutput = false
            fullOutput = text
        }
    }
}
