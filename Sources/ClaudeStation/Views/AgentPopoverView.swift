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
            if manager.agents.isEmpty { emptyState } else { agentList }
        }
        .frame(width: 400)
    }

    private var header: some View {
        HStack {
            Image(systemName: "cloud.fill").foregroundStyle(.blue)
            Text("Claude Station").font(.system(.headline, design: .rounded))
            Spacer()
            if manager.runningCount > 0 { badge("\(manager.runningCount) active", color: .blue) }
            let idle = manager.agents.filter { $0.status == .idle }.count
            if idle > 0 { badge("\(idle) idle", color: .secondary) }
            let waiting = manager.waitingCount
            if waiting > 0 { badge("\(waiting) waiting", color: .orange) }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15)).foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud").font(.system(size: 28)).foregroundStyle(.quaternary)
            Text("No Claude sessions").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

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

    // MARK: - Agent Row

    @ViewBuilder
    private func agentRow(_ agent: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                Image(systemName: agent.status.systemImage)
                    .font(.system(size: 14)).foregroundStyle(agent.status.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(agent.workspace).font(.system(.body, weight: .semibold))
                        Text(agent.status.label).font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(agent.status.color.opacity(0.15))
                            .foregroundStyle(agent.status.color).clipShape(Capsule())
                        Spacer()
                        Text(agent.formattedDuration)
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
                    }

                    if !agent.lastMessage.isEmpty {
                        Text(agent.lastMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(2)
                    }
                }

                Button { manager.navigateToAgent(agent) } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(.blue)
                }
                .buttonStyle(.plain).help("Open terminal")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedAgent == agent.id { expandedAgent = nil }
                    else { expandedAgent = agent.id; loadFullOutput(agent) }
                }
            }

            // Action buttons (always visible for waiting agents)
            if agent.status == .waiting, let action = agent.pendingAction {
                actionButtons(agent: agent, action: action)
            }

            // Expanded output
            if expandedAgent == agent.id {
                expandedOutputView
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(agent: AgentSession, action: PendingAction) -> some View {
        switch action {
        case let .permission(tool, detail):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.caption).foregroundStyle(.orange)
                    Text("Permission: \(tool)")
                        .font(.system(.caption, weight: .medium))
                    Spacer()
                }

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(3)
                }

                HStack(spacing: 8) {
                    Button {
                        manager.approveAgent(agent)
                    } label: {
                        Label("Allow", systemImage: "checkmark")
                            .font(.system(.caption, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .controlSize(.small)

                    Button {
                        manager.denyAgent(agent)
                    } label: {
                        Label("Deny", systemImage: "xmark")
                            .font(.system(.caption, weight: .semibold))
                    }
                    .buttonStyle(.bordered).tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)
            .transition(.opacity.combined(with: .move(edge: .top)))

        case let .question(options):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption).foregroundStyle(.orange)
                    Text("Choose an option")
                        .font(.system(.caption, weight: .medium))
                }

                ForEach(options, id: \.index) { option in
                    Button {
                        manager.selectOption(agent, option: option.index)
                    } label: {
                        HStack {
                            Text("\(option.index).")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(option.label)
                                .font(.system(.caption, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Expanded Output

    private var expandedOutputView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Terminal Output").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if loadingOutput { ProgressView().controlSize(.mini) }
            }
            Text(fullOutput.isEmpty ? "No output" : fullOutput)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.8)).lineLimit(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func loadFullOutput(_ agent: AgentSession) {
        loadingOutput = true; fullOutput = ""
        Task {
            fullOutput = await manager.loadOutput(for: agent)
            loadingOutput = false
        }
    }
}
