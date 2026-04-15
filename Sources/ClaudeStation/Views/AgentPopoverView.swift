import SwiftUI

struct AgentPopoverView: View {
    @Environment(SessionManager.self) private var manager
    @State private var expandedAgent: String?
    @State private var fullOutput: String = ""
    @State private var loadingOutput = false
    @State private var heartbeatPhase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heartbeat
            header
            if manager.agents.isEmpty { emptyState } else { agentList }
            footer
        }
        .frame(width: 420)
        .background(DS.base)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                heartbeatPhase = true
            }
        }
    }

    // MARK: - Heartbeat Line

    private var heartbeat: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        heartbeatColor.opacity(heartbeatPhase ? 0.8 : 0.2),
                        heartbeatColor.opacity(heartbeatPhase ? 0.6 : 0.1),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1.5)
    }

    private var heartbeatColor: Color {
        if manager.hasWaiting { return DS.amber }
        if manager.runningCount > 0 { return DS.cyan }
        return DS.text3
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("λ")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.cyan)

            VStack(alignment: .leading, spacing: 1) {
                Text("Claude Station")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text1)
                Text("\(manager.agents.count) session\(manager.agents.count == 1 ? "" : "s")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DS.text3)
            }

            Spacer()

            HStack(spacing: 5) {
                if manager.runningCount > 0 { pill(manager.runningCount, "active", DS.cyan) }
                if manager.waitingCount > 0 { pill(manager.waitingCount, "waiting", DS.amber) }
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
    }

    private func pill(_ count: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(color.opacity(0.2), lineWidth: 0.5)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("λ")
                .font(.system(size: 32, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(DS.text3)
            Text("No active sessions")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DS.text3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }

    // MARK: - Agent List

    private var agentList: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(manager.agents) { agent in
                    AgentCard(
                        agent: agent,
                        isExpanded: expandedAgent == agent.id,
                        onTap: {
                            withAnimation(DS.snapSpring) {
                                expandedAgent = expandedAgent == agent.id ? nil : agent.id
                                if expandedAgent == agent.id { loadFullOutput(agent) }
                            }
                        },
                        onNavigate: { manager.navigateToAgent(agent) },
                        onApprove: { manager.approveAgent(agent) },
                        onDeny: { manager.denyAgent(agent) },
                        onSelectOption: { manager.selectOption(agent, option: $0) },
                        onSendMessage: { manager.sendMessage($0, to: agent) },
                        onRefreshOutput: { loadFullOutput(agent) },
                        expandedOutput: expandedAgent == agent.id ? fullOutput : "",
                        loadingOutput: expandedAgent == agent.id && loadingOutput
                    )
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .frame(maxHeight: 480)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            ForEach(keys, id: \.0) { key, label in
                HStack(spacing: 2) {
                    Text(key)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(DS.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(label).font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(DS.text3)
            }

            Spacer()

            Button { NSApplication.shared.terminate(nil) } label: {
                Text("quit")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.coral.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(DS.surface1.opacity(0.5))
    }

    private var keys: [(String, String)] {
        [("⌃⇧A", "allow"), ("⌃⇧D", "deny"), ("⌃⇧V", "toggle")]
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
    let onSendMessage: (String) -> Void
    let onRefreshOutput: () -> Void
    let expandedOutput: String
    let loadingOutput: Bool

    @State private var isHovered = false
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private var accentColor: Color {
        switch agent.status {
        case .waiting: DS.amber
        case .running: DS.cyan
        case .completed: DS.emerald
        default: DS.text3
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left status bar
            RoundedRectangle(cornerRadius: 1)
                .fill(accentColor)
                .frame(width: 2.5)
                .padding(.vertical, 6)
                .glow(accentColor, radius: 3, active: agent.status == .waiting)

            VStack(alignment: .leading, spacing: 0) {
                mainRow
                if agent.status == .waiting, let action = agent.pendingAction {
                    actionSection(action)
                }
                if isExpanded { terminalSection }
            }
        }
        .glassCard(accent: accentColor, active: agent.status == .waiting || isHovered)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovered = h } }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { inputFocused = true }
            } else {
                inputFocused = false; inputText = ""
            }
        }
    }

    // MARK: - Main Row

    private var mainRow: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(agent.workspace)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.text1)

                        Text(agent.status.label.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        Spacer()

                        Text(agent.formattedDuration)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DS.text3)
                    }

                    if !agent.task.isEmpty {
                        Text(agent.task)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(DS.text2)
                            .lineLimit(1)
                    }

                    if !agent.lastMessage.isEmpty && !isExpanded {
                        Text(agent.lastMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DS.text3)
                            .lineLimit(1)
                    }
                }

                VStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(DS.text3)

                    Button(action: onNavigate) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.cyan.opacity(0.7))
                            .padding(4)
                            .background(DS.cyan.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 24)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionSection(_ action: PendingAction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(DS.glassBorder).frame(height: 0.5).padding(.horizontal, 10)

            switch action {
            case let .permission(tool, detail):
                permissionView(tool: tool, detail: detail)
            case let .planReview(content):
                planView(content: content)
            case let .question(options):
                questionView(options: options)
            }
        }
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func permissionView(tool: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 10)).foregroundStyle(DS.amber)
                Text(tool)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.text2)
            }
            .padding(.horizontal, 10)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DS.text3).lineLimit(2)
                    .padding(.horizontal, 10)
            }

            approveRow
        }
    }

    private func planView(content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10)).foregroundStyle(DS.violet)
                Text("PLAN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.violet)
            }
            .padding(.horizontal, 10)

            ScrollView {
                Text(content)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DS.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
            .padding(6).background(DS.termBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.r6))
            .padding(.horizontal, 10)

            approveRow
        }
    }

    private func questionView(options: [(index: Int, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 10)).foregroundStyle(DS.amber)
                Text("SELECT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.amber)
            }
            .padding(.horizontal, 10)

            ForEach(options, id: \.index) { option in
                Button { onSelectOption(option.index) } label: {
                    HStack(spacing: 6) {
                        Text("\(option.index)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.cyan)
                            .frame(width: 16, height: 16)
                            .background(DS.cyan.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        Text(option.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.text1)

                        Spacer()

                        Image(systemName: "return")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DS.text3)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(DS.surface2.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: DS.r6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }
        }
    }

    private var approveRow: some View {
        HStack(spacing: 6) {
            Button(action: onApprove) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                    Text("Allow").font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(DS.emerald)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onDeny) {
                HStack(spacing: 3) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    Text("Deny").font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(DS.coral)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(DS.coral.opacity(0.1))
                .clipShape(Capsule())
                .overlay { Capsule().strokeBorder(DS.coral.opacity(0.25), lineWidth: 0.5) }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Terminal

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(DS.glassBorder).frame(height: 0.5).padding(.horizontal, 10)

            // Terminal header
            HStack(spacing: 6) {
                Text("~/\(agent.workspace.lowercased())")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.text3)

                Spacer()

                if loadingOutput {
                    ProgressView().controlSize(.mini)
                } else {
                    Button(action: onRefreshOutput) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DS.text3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)

            // Output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(expandedOutput.isEmpty ? "waiting..." : expandedOutput)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(DS.termText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: expandedOutput) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .frame(height: 140)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(DS.termBg)

            // Input — seamless terminal line
            HStack(spacing: 0) {
                Text("λ ")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(inputFocused ? DS.cyan : DS.text3)

                TextField("", text: $inputText, prompt:
                    Text("...").foregroundStyle(DS.text3.opacity(0.4))
                )
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.text1)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit { sendInput() }

                if !inputText.isEmpty {
                    Text("⏎")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.cyan.opacity(0.6))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(DS.termBg)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(inputFocused ? DS.cyan.opacity(0.3) : DS.glassBorder)
                    .frame(height: 0.5)
            }
            .animation(.easeOut(duration: 0.1), value: inputFocused)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.r6))
        .padding(.horizontal, 6).padding(.bottom, 6).padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        onSendMessage(text)
    }
}
