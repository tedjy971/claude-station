import SwiftUI

struct MenuBarView: View {
    @Environment(SessionManager.self) private var manager
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "cloud.fill")
                .foregroundStyle(.blue)
            Text("Claude Station")
                .font(.headline)
            Spacer()
            Text("\(manager.totalCount) agent\(manager.totalCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if manager.agents.isEmpty {
            emptyState
        } else {
            agentList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No active agents")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var agentList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(manager.agents) { agent in
                    AgentRowView(agent: agent)
                    if agent.id != manager.agents.last?.id {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }

    private var footer: some View {
        HStack {
            Button("Refresh") {
                Task { await manager.refresh() }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.blue)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
