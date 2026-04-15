import SwiftUI

struct AgentPopoverView: View {
    @Environment(SessionManager.self) private var manager
    @State private var expandedAgent: String?
    @State private var fullOutput: String = ""
    @State private var loadingOutput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            separator
            if manager.agents.isEmpty { emptyState } else { agentList }
            separator
            footer
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(DS.accent.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "cloud.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Claude Station")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(DS.text1)
                Text("\(manager.agents.count) session\(manager.agents.count == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(DS.text3)
            }

            Spacer()

            HStack(spacing: 6) {
                if manager.runningCount > 0 { statusPill(manager.runningCount, "active", DS.accent) }
                if manager.waitingCount > 0 { statusPill(manager.waitingCount, "waiting", DS.orange) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func statusPill(_ count: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 36))
                .foregroundStyle(DS.text3)
                .symbolRenderingMode(.hierarchical)
            Text("No active sessions")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(DS.text2)
            Text("Start a Claude Code session to see it here")
                .font(.caption2).foregroundStyle(DS.text3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
    }

    // MARK: - Agent List

    private var agentList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(manager.agents) { agent in
                    AgentCard(
                        agent: agent,
                        isExpanded: expandedAgent == agent.id,
                        onTap: {
                            withAnimation(DS.springSnappy) {
                                expandedAgent = expandedAgent == agent.id ? nil : agent.id
                                if expandedAgent == agent.id { loadFullOutput(agent) }
                            }
                        },
                        onNavigate: { manager.navigateToAgent(agent) },
                        onApprove: { manager.approveAgent(agent) },
                        onDeny: { manager.denyAgent(agent) },
                        onSelectOption: { manager.selectOption(agent, option: $0) },
                        expandedOutput: expandedAgent == agent.id ? fullOutput : "",
                        loadingOutput: expandedAgent == agent.id && loadingOutput
                    )
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .frame(maxHeight: 480)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            ForEach(shortcuts, id: \.0) { key, label in
                HStack(spacing: 3) {
                    Text(key)
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(DS.card)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text(label)
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(DS.text3)
                if label != "toggle" { Spacer() }
            }

            Spacer()

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.red.opacity(0.7))
                    .padding(4)
                    .background(DS.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var shortcuts: [(String, String)] {
        [("⌃⇧A", "approve"), ("⌃⇧D", "deny"), ("⌃⇧V", "toggle")]
    }

    private var separator: some View {
        Rectangle().fill(DS.cardBorder).frame(height: 1)
    }

    private func loadFullOutput(_ agent: AgentSession) {
        loadingOutput = true; fullOutput = ""
        Task {
            fullOutput = await manager.loadOutput(for: agent)
            loadingOutput = false
        }
    }
}

// MARK: - Agent Card

struct AgentCard: View {
    let agent: AgentSession
    let isExpanded: Bool
    let onTap: () -> Void
    let onNavigate: () -> Void
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onSelectOption: (Int) -> Void
    let expandedOutput: String
    let loadingOutput: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if agent.status == .waiting, let action = agent.pendingAction {
                actionSection(action)
            }
            if isExpanded { outputSection }
        }
        .background(isHovered ? DS.cardHover : DS.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.r12))
        .overlay {
            RoundedRectangle(cornerRadius: DS.r12)
                .strokeBorder(agent.status == .waiting ? DS.orange.opacity(0.3) : DS.cardBorder, lineWidth: 0.5)
        }
        .statusBar(color: agent.status.color)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovered = h } }
        .contentShape(RoundedRectangle(cornerRadius: DS.r12))
        .onTapGesture(perform: onTap)
    }

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(spacing: 10) {
            // Status icon with glow
            ZStack {
                Circle()
                    .fill(agent.status.color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: agent.status.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(agent.status.color)
            }
            .glow(agent.status.color, radius: 4, active: agent.status == .waiting)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.workspace)
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(DS.text1)

                    Text(agent.status.label)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(agent.status.color)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(agent.status.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                if !agent.task.isEmpty {
                    Text(agent.task)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(DS.text2)
                        .lineLimit(1)
                }

                if !agent.lastMessage.isEmpty {
                    Text(agent.lastMessage)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(DS.text3)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(agent.formattedDuration)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(DS.text3)

                Button(action: onNavigate) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.accent.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Open in terminal")
            }
        }
        .padding(12)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionSection(_ action: PendingAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 12)

            switch action {
            case let .permission(tool, detail):
                permissionAction(tool: tool, detail: detail)
            case let .planReview(content):
                planAction(content: content)
            case let .question(options):
                questionAction(options: options)
            }
        }
        .padding(.bottom, 12)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    private func permissionAction(tool: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption).foregroundStyle(DS.orange)
                Text("Permission: **\(tool)**")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(DS.text2)
            }
            .padding(.horizontal, 12)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(DS.text3).lineLimit(2)
                    .padding(.horizontal, 12)
            }

            actionButtonRow
        }
    }

    private func planAction(content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption).foregroundStyle(DS.purple)
                Text("Plan Review")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(DS.text2)
            }
            .padding(.horizontal, 12)

            ScrollView {
                Text(content)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(DS.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .padding(8)
            .background(DS.codeBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.r8))
            .padding(.horizontal, 12)

            actionButtonRow
        }
    }

    private func questionAction(options: [(index: Int, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.caption).foregroundStyle(DS.orange)
                Text("Choose an option")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(DS.text2)
            }
            .padding(.horizontal, 12)

            ForEach(options, id: \.index) { option in
                Button { onSelectOption(option.index) } label: {
                    HStack(spacing: 8) {
                        Text("\(option.index)")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(DS.accent)
                            .frame(width: 18, height: 18)
                            .background(DS.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(option.label)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(DS.text1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DS.text3)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(DS.accent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DS.r8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
        }
    }

    private var actionButtonRow: some View {
        HStack(spacing: 8) {
            Button(action: onApprove) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    Text("Allow").font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(
                    LinearGradient(colors: [DS.green, DS.green.opacity(0.8)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onDeny) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    Text("Deny").font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(DS.red)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(DS.red.opacity(0.12))
                .clipShape(Capsule())
                .overlay { Capsule().strokeBorder(DS.red.opacity(0.3), lineWidth: 0.5) }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Output

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 12)

            HStack {
                Text("TERMINAL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text3)
                    .tracking(1)
                Spacer()
                if loadingOutput {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)

            Text(expandedOutput.isEmpty ? "..." : expandedOutput)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(DS.text2).lineLimit(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).background(DS.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.r8))
                .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
