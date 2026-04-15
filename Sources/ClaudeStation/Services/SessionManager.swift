import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class SessionManager {
    private(set) var agents: [AgentSession] = []
    private(set) var hasUnmatchedWaiting = false

    var waitingCount: Int { agents.filter { $0.status == .waiting }.count }
    var runningCount: Int { agents.filter { $0.status == .running }.count }
    var hasWaiting: Bool { waitingCount > 0 || hasUnmatchedWaiting }
    var totalCount: Int { agents.count }

    private var refreshTask: Task<Void, Never>?
    private var fileMonitor: DispatchSourceFileSystemObject?
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

    func refresh() async {
        let sessionFiles = readSessionFiles()
        let aliveFiles = sessionFiles.filter { isProcessAlive(pid: $0.pid) }

        guard !aliveFiles.isEmpty else {
            agents = []
            hasUnmatchedWaiting = false
            return
        }

        async let workspacesResult = CmuxService.fetchWorkspaces()
        async let notificationsResult = CmuxService.fetchNotifications()
        async let ttyMapResult = fetchTTYMap(for: aliveFiles.map(\.pid))

        let workspaces = await workspacesResult
        let notifications = await notificationsResult
        let ttyMap = await ttyMapResult

        var newAgents: [AgentSession] = []
        var matchedNotifications: Set<Int> = []

        for session in aliveFiles {
            var workspace = session.projectName
            var task = ""
            var status: AgentStatus = .running
            var preview: String?
            var isUnread = false

            // Match session to cmux workspace via TTY
            if let tty = ttyMap[session.pid] {
                for ws in workspaces {
                    for surface in ws.surfaces where surface.tty == tty && surface.isClaude {
                        workspace = ws.name
                        task = surface.claudeTaskName ?? ""
                    }
                }
            }

            // Match notifications by workspace name
            for (idx, notif) in notifications.enumerated() {
                if notif.isCompleted, let hint = notif.workspaceHint,
                   hint.localizedCaseInsensitiveCompare(workspace) == .orderedSame {
                    status = .completed
                    preview = notif.preview
                    matchedNotifications.insert(idx)
                } else if notif.isWaiting, let hint = notif.workspaceHint,
                          hint.localizedCaseInsensitiveCompare(workspace) == .orderedSame {
                    status = .waiting
                    preview = notif.preview
                    isUnread = !notif.isRead
                    matchedNotifications.insert(idx)
                }
            }

            newAgents.append(AgentSession(
                id: session.sessionId,
                pid: session.pid,
                sessionId: session.sessionId,
                workspace: workspace,
                task: task,
                cwd: session.cwd,
                startedAt: session.startedAt,
                status: status,
                notificationPreview: preview,
                isUnread: isUnread
            ))
        }

        // Check for unmatched waiting notifications
        let unmatchedWaiting = notifications.enumerated().contains { idx, notif in
            notif.isWaiting && !matchedNotifications.contains(idx)
        }

        newAgents.sort { $0.status < $1.status }
        agents = newAgents
        hasUnmatchedWaiting = unmatchedWaiting
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

    // MARK: - Session Files

    private struct SessionFile {
        let pid: Int
        let sessionId: String
        let cwd: String
        let startedAt: Date

        var projectName: String {
            (cwd as NSString).lastPathComponent
        }
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

            return SessionFile(
                pid: pid,
                sessionId: sessionId,
                cwd: cwd,
                startedAt: Date(timeIntervalSince1970: startedAtMs / 1000)
            )
        }
    }

    private nonisolated func isProcessAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }

    // MARK: - File Monitoring

    private func startFileMonitor() {
        let fd = open(sessionsPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
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
