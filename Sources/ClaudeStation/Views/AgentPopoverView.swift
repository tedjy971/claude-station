import SwiftUI

struct AgentPopoverView: View {
    @Environment(SessionManager.self) private var manager
    @State private var expandedAgent: String?
    @State private var outputText: String = ""
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
        .frame(width: 380)
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
                Label("\(manager.runningCount) active", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if manager.agents.count > manager.runningCount {
                Text("\(manager.agents.count - manager.runningCount) idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

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

    // MARK: - Agent List

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
        .frame(maxHeight: 450)
    }

    // MARK: - Agent Row

    @ViewBuilder
    private func agentRow(_ agent: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Status dot
                Image(systemName: agent.status.systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(agent.status.color)
                    .frame(width: 20)

                // Info
                VStack(alignment: .leading, spacing: 2) {
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
                    }

                    if !agent.task.isEmpty {
                        Text(agent.task)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text(agent.formattedDuration)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    // Navigate button
                    Button {
                        manager.navigateToAgent(agent)
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Open in terminal")
                }
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
                        loadOutputForAgent(agent)
                    }
                }
            }

            // Expanded output preview
            if expandedAgent == agent.id {
                outputPreview
            }
        }
    }

    // MARK: - Output Preview

    private var outputPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Output")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if loadingOutput {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            Text(outputText.isEmpty ? "No output" : outputText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func loadOutputForAgent(_ agent: AgentSession) {
        loadingOutput = true
        outputText = ""
        Task {
            let text = await manager.loadOutput(for: agent)
            loadingOutput = false
            outputText = text
        }
    }
}
