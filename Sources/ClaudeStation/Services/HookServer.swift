import Foundation

struct HookEvent {
    let timestamp: Double
    let sessionId: String
    let workspaceId: String
    let surfaceId: String
    let toolName: String
    let toolInput: [String: Any]

    var isAskUserQuestion: Bool { toolName == "AskUserQuestion" }

    var pendingAction: PendingAction? {
        if isAskUserQuestion {
            return parseQuestion()
        }
        if !toolName.isEmpty {
            return .permission(tool: toolName, detail: formatToolDetail())
        }
        return nil
    }

    private func parseQuestion() -> PendingAction? {
        guard let questions = toolInput["questions"] as? [[String: Any]],
              let first = questions.first,
              let opts = first["options"] as? [[String: Any]] else { return nil }

        var options: [(index: Int, label: String)] = []
        for (i, opt) in opts.enumerated() {
            let label = opt["label"] as? String ?? "Option \(i + 1)"
            options.append((i + 1, label))
        }
        guard options.count >= 2 else { return nil }
        return .question(options: options)
    }

    private func formatToolDetail() -> String {
        if let cmd = toolInput["command"] as? String {
            return "\(toolName)(\(cmd.prefix(120)))"
        }
        if let path = toolInput["file_path"] as? String {
            return "\(toolName)(\(path))"
        }
        return toolName
    }
}

@MainActor
final class HookServer {
    private(set) var latestEvents: [String: HookEvent] = [:] // workspaceId → latest event
    private var fileMonitor: DispatchSourceFileSystemObject?
    private let eventsPath: String
    private var processedFiles: Set<String> = []

    init() {
        eventsPath = NSString(string: "~/.claude-station/events").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: eventsPath, withIntermediateDirectories: true)
    }

    func start() {
        processExistingEvents()
        startWatching()
    }

    func stop() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    func pendingAction(forWorkspace wsRef: String) -> PendingAction? {
        // Match by workspace ID from cmux env vars
        for (_, event) in latestEvents {
            if event.workspaceId == wsRef || "workspace:\(event.workspaceId)" == wsRef {
                return event.pendingAction
            }
        }
        // Fallback: return most recent event if only one exists
        if latestEvents.count == 1, let event = latestEvents.values.first {
            return event.pendingAction
        }
        return nil
    }

    func clearEvent(forWorkspace wsRef: String) {
        latestEvents = latestEvents.filter { key, event in
            event.workspaceId != wsRef && "workspace:\(event.workspaceId)" != wsRef
        }
    }

    // MARK: - Private

    private func processExistingEvents() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: eventsPath) else { return }
        for file in files.sorted() where file.hasSuffix(".json") {
            processEventFile(file)
        }
    }

    private func processEventFile(_ filename: String) {
        guard !processedFiles.contains(filename) else { return }
        processedFiles.insert(filename)

        let path = (eventsPath as NSString).appendingPathComponent(filename)
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let hookEvent = json["hook_event"] as? [String: Any] ?? [:]
        let event = HookEvent(
            timestamp: json["timestamp"] as? Double ?? 0,
            sessionId: json["session_id"] as? String ?? "",
            workspaceId: json["workspace_id"] as? String ?? "",
            surfaceId: json["surface_id"] as? String ?? "",
            toolName: hookEvent["tool_name"] as? String ?? "",
            toolInput: hookEvent["tool_input"] as? [String: Any] ?? [:]
        )

        if !event.workspaceId.isEmpty {
            latestEvents[event.workspaceId] = event
        } else if !event.sessionId.isEmpty {
            latestEvents[event.sessionId] = event
        }

        // Clean old event files (keep last 20)
        cleanOldFiles()
    }

    private func cleanOldFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: eventsPath)
            .filter({ $0.hasSuffix(".json") })
            .sorted() else { return }

        if files.count > 20 {
            for file in files.prefix(files.count - 20) {
                try? fm.removeItem(atPath: (eventsPath as NSString).appendingPathComponent(file))
            }
        }
    }

    private func startWatching() {
        let fd = open(eventsPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write], queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(atPath: self.eventsPath) else { return }
            for file in files.sorted() where file.hasSuffix(".json") {
                self.processEventFile(file)
            }
        }

        source.setCancelHandler { close(fd) }
        source.resume()
        fileMonitor = source
    }

    // MARK: - Auto-install

    static func installHook() -> Bool {
        let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath
        let hookPath = Bundle.main.path(forResource: "claude-station-hook", ofType: nil)
            ?? NSString(string: "~/.claude-station/claude-station-hook").expandingTildeInPath

        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var preToolUse = hooks["PreToolUse"] as? [[String: Any]] ?? []

        // Check if already installed
        let alreadyInstalled = preToolUse.contains { entry in
            let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
            return innerHooks.contains { h in
                (h["command"] as? String)?.contains("claude-station-hook") == true
            }
        }

        guard !alreadyInstalled else { return true }

        // Add our hook
        preToolUse.append([
            "matcher": "",
            "hooks": [[
                "type": "command",
                "command": hookPath,
                "timeout": 5
            ] as [String: Any]]
        ] as [String: Any])

        hooks["PreToolUse"] = preToolUse
        settings["hooks"] = hooks

        guard let newData = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }

        return FileManager.default.createFile(atPath: settingsPath, contents: newData)
    }
}
