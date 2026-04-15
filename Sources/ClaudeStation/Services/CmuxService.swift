import Foundation

struct WorkspaceInfo {
    let ref: String
    let name: String
    let isSelected: Bool
    var surfaces: [SurfaceInfo]
}

struct SurfaceInfo {
    let ref: String
    let title: String
    let tty: String?
    let isClaude: Bool
    let isActive: Bool

    var claudeTaskName: String? {
        guard isClaude else { return nil }
        var cleaned = title
        for prefix in ["✳ ", "⠐ ", "⠂ ", "⠄ ", "⡀ "] {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        return cleaned.isEmpty ? nil : cleaned
    }
}

struct NotificationInfo {
    let isRead: Bool
    let status: String
    let preview: String

    var isWaiting: Bool { status.contains("Waiting") }
    var isCompleted: Bool { status.contains("Completed") }

    var workspaceHint: String? {
        if let range = status.range(of: "Completed in ") {
            return String(status[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

enum CmuxService {

    static func fetchWorkspaces() async -> [WorkspaceInfo] {
        let output = await ShellExecutor.run("cmux tree --all 2>/dev/null")
        return parseTree(output)
    }

    static func fetchNotifications() async -> [NotificationInfo] {
        let output = await ShellExecutor.run("cmux list-notifications 2>/dev/null")
        return parseNotifications(output)
    }

    static func getTTYForPID(_ pid: Int) async -> String? {
        let output = await ShellExecutor.run("ps -p \(pid) -o tty=")
        let tty = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tty.isEmpty, tty != "??" else { return nil }
        return "tty\(tty)"
    }

    // MARK: - Tree Parsing

    private static func parseTree(_ output: String) -> [WorkspaceInfo] {
        var workspaces: [WorkspaceInfo] = []
        var current: WorkspaceInfo?

        for line in output.components(separatedBy: "\n") {
            if let wsRef = line.firstMatch(of: #"workspace:\d+"#),
               let wsName = line.firstCaptureGroup(of: #""([^"]*)""#),
               line.contains("workspace \(wsRef)") {
                if let ws = current { workspaces.append(ws) }
                current = WorkspaceInfo(
                    ref: wsRef,
                    name: wsName,
                    isSelected: line.contains("[selected]"),
                    surfaces: []
                )
            }

            if let sRef = line.firstMatch(of: #"surface:\d+"#),
               line.contains("[terminal]"),
               let title = line.firstCaptureGroup(of: #"\[terminal\] "([^"]*)""#) {
                let tty = line.firstCaptureGroup(of: #"tty=(\w+)"#)
                let isClaude = ["✳", "⠐", "⠂", "⠄", "⡀"].contains(where: { title.hasPrefix($0) })
                let surface = SurfaceInfo(
                    ref: sRef,
                    title: title,
                    tty: tty,
                    isClaude: isClaude,
                    isActive: line.contains("◀ active")
                )
                current?.surfaces.append(surface)
            }
        }

        if let ws = current { workspaces.append(ws) }
        return workspaces
    }

    // MARK: - Notification Parsing

    private static func parseNotifications(_ output: String) -> [NotificationInfo] {
        output.components(separatedBy: "\n").compactMap { line in
            guard !line.isEmpty,
                  let colonIdx = line.firstIndex(of: ":") else { return nil }

            let rest = String(line[line.index(after: colonIdx)...])
            let parts = rest.components(separatedBy: "|")
            guard parts.count >= 6, parts[4] == "Claude Code" else { return nil }

            return NotificationInfo(
                isRead: parts[3] == "read",
                status: parts[5],
                preview: parts.count > 6 ? parts[6...].joined(separator: "|") : ""
            )
        }
    }
}

// MARK: - String Regex Helpers

extension String {
    func firstMatch(of pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              let range = Range(match.range, in: self) else { return nil }
        return String(self[range])
    }

    func firstCaptureGroup(of pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self) else { return nil }
        return String(self[range])
    }
}
