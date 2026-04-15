import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class SessionManager {
    private(set) var agents: [AgentSession] = []
    private(set) var hasUnmatchedWaiting = false

    var activeAgents: [AgentSession] { agents.filter { $0.status.showInOverlay } }
    var waitingCount: Int { agents.filter { $0.status == .waiting }.count }
    var runningCount: Int { agents.filter { $0.status == .running }.count }
    var hasWaiting: Bool { waitingCount > 0 || hasUnmatchedWaiting }
    var totalActive: Int { activeAgents.count }

    private var refreshTask: Task<Void, Never>?
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var isRefreshing = false
    private let sessionsPath = NSString(string: "~/.claude/sessions").expandingTildeInPath

    func startMonitoring() {
        Task { await refresh() }
        startRefreshLoop()
        startFileMonitor()
    }

    func stopMonitoring() {
        refreshTask?.cancel()
        refreshTask = nil
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    func navigateToAgent(_ agent: AgentSession) {
        Task { await CmuxService.selectWorkspace(ref: agent.workspaceRef) }
    }

    func loadOutput(for agent: AgentSession) async -> String {
        await CmuxService.readScreen(workspaceRef: agent.workspaceRef, lines: 15)
    }

    func approveAgent(_ agent: AgentSession) {
        Task {
            await CmuxService.sendText(workspaceRef: agent.workspaceRef, text: "y\n")
            try? await Task.sleep(for: .seconds(1))
            await refresh()
        }
    }

    func denyAgent(_ agent: AgentSession) {
        Task {
            await CmuxService.sendText(workspaceRef: agent.workspaceRef, text: "n\n")
            try? await Task.sleep(for: .seconds(1))
            await refresh()
        }
    }

    func selectOption(_ agent: AgentSession, option: Int) {
        Task {
            await CmuxService.sendText(workspaceRef: agent.workspaceRef, text: "\(option)\n")
            try? await Task.sleep(for: .seconds(1))
            await refresh()
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let workspacesResult = CmuxService.fetchWorkspaces()
        async let notificationsResult = CmuxService.fetchNotifications()

        let workspaces = await workspacesResult
        let notifications = await notificationsResult

        let sessionFiles = readSessionFiles()
        let ttyMap = await fetchTTYMap(for: sessionFiles.map(\.pid))
        var ttyToSession: [String: SessionFile] = [:]
        for session in sessionFiles {
            if let tty = ttyMap[session.pid] { ttyToSession[tty] = session }
        }

        var newAgents: [AgentSession] = []
        var matchedNotifications: Set<Int> = []

        for ws in workspaces {
            for surface in ws.surfaces where surface.claudeStatus != .none {
                var status: AgentStatus = surface.claudeStatus == .running ? .running : .idle
                let session = surface.tty.flatMap { ttyToSession[$0] }

                for (idx, notif) in notifications.enumerated() {
                    if notif.needsAttention, let hint = notif.workspaceHint,
                       hint.localizedCaseInsensitiveCompare(ws.name) == .orderedSame {
                        status = .waiting
                        matchedNotifications.insert(idx)
                    } else if notif.isCompleted, let hint = notif.workspaceHint,
                              hint.localizedCaseInsensitiveCompare(ws.name) == .orderedSame {
                        status = .completed
                        matchedNotifications.insert(idx)
                    }
                }

                newAgents.append(AgentSession(
                    id: session?.sessionId ?? surface.ref,
                    pid: session?.pid ?? 0,
                    sessionId: session?.sessionId ?? surface.ref,
                    workspace: ws.name,
                    workspaceRef: ws.ref,
                    surfaceRef: surface.ref,
                    task: surface.claudeTaskName ?? "",
                    cwd: session?.cwd ?? "",
                    startedAt: session?.startedAt ?? Date(),
                    status: status
                ))
            }
        }

        // Load screen output and parse actions in parallel
        await withTaskGroup(of: (String, String).self) { group in
            for agent in newAgents {
                let wsRef = agent.workspaceRef
                let agentId = agent.id
                group.addTask {
                    let screen = await CmuxService.readScreen(workspaceRef: wsRef, lines: 15)
                    return (agentId, screen)
                }
            }
            for await (id, screen) in group {
                if let idx = newAgents.firstIndex(where: { $0.id == id }) {
                    let lines = screen.components(separatedBy: "\n")
                    newAgents[idx].lastMessage = lines.suffix(3).joined(separator: "\n")
                    if newAgents[idx].status == .waiting {
                        newAgents[idx].pendingAction = PendingAction.parse(from: screen)
                    }
                }
            }
        }

        // Assign unmatched "Waiting" notifications to agents
        // (cmux "Waiting" notifications don't include workspace name)
        var unmatchedWaitingCount = notifications.enumerated().filter { idx, notif in
            notif.needsAttention && !matchedNotifications.contains(idx)
        }.count

        if unmatchedWaitingCount > 0 {
            // Priority 1: agent in the currently selected workspace
            for i in newAgents.indices where unmatchedWaitingCount > 0 {
                let isSelected = workspaces.first(where: { $0.ref == newAgents[i].workspaceRef })?.isSelected ?? false
                if isSelected && newAgents[i].status != .completed && newAgents[i].status != .waiting {
                    newAgents[i].status = .waiting
                    unmatchedWaitingCount -= 1
                }
            }
            // Priority 2: any running agent
            for i in newAgents.indices where unmatchedWaitingCount > 0 {
                if newAgents[i].status == .running {
                    newAgents[i].status = .waiting
                    unmatchedWaitingCount -= 1
                }
            }
            // Priority 3: any idle agent
            for i in newAgents.indices where unmatchedWaitingCount > 0 {
                if newAgents[i].status == .idle {
                    newAgents[i].status = .waiting
                    unmatchedWaitingCount -= 1
                }
            }
        }

        let hasUnmatched = unmatchedWaitingCount > 0

        newAgents.sort { $0.status < $1.status }
        agents = newAgents
        hasUnmatchedWaiting = hasUnmatched
    }

    // MARK: - Private

    private func startRefreshLoop() {
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    private func fetchTTYMap(for pids: [Int]) async -> [Int: String] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for pid in pids {
                group.addTask { (pid, await CmuxService.getTTYForPID(pid)) }
            }
            var map: [Int: String] = [:]
            for await (pid, tty) in group {
                if let tty { map[pid] = tty }
            }
            return map
        }
    }

    private struct SessionFile {
        let pid: Int
        let sessionId: String
        let cwd: String
        let startedAt: Date
    }

    private func readSessionFiles() -> [SessionFile] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: sessionsPath) else { return [] }
        return files.compactMap { file -> SessionFile? in
            guard file.hasSuffix(".json") else { return nil }
            let path = (sessionsPath as NSString).appendingPathComponent(file)
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let startedAtMs = json["startedAt"] as? Double else { return nil }
            return SessionFile(pid: pid, sessionId: sessionId, cwd: cwd,
                             startedAt: Date(timeIntervalSince1970: startedAtMs / 1000))
        }
    }

    private func startFileMonitor() {
        let fd = open(sessionsPath, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileMonitor = source
    }
}
