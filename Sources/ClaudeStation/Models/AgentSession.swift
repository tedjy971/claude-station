import SwiftUI

enum AgentStatus: Int, Comparable {
    case waiting = 0
    case running = 1
    case idle = 2
    case completed = 3
    case unknown = 4

    static func < (lhs: AgentStatus, rhs: AgentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var systemImage: String {
        switch self {
        case .waiting: "exclamationmark.circle.fill"
        case .running: "circle.dotted.circle"
        case .idle: "moon.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .waiting: "Waiting"
        case .running: "Running"
        case .idle: "Idle"
        case .completed: "Done"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .waiting: DS.amber
        case .running: DS.cyan
        case .idle: DS.text3
        case .completed: DS.emerald
        case .unknown: DS.text3
        }
    }

    var showInOverlay: Bool {
        self == .running || self == .waiting
    }
}

enum PendingAction: Equatable {
    case permission(tool: String, detail: String)
    case question(options: [(index: Int, label: String)])
    case planReview(content: String)

    static func == (lhs: PendingAction, rhs: PendingAction) -> Bool {
        switch (lhs, rhs) {
        case let (.permission(t1, d1), .permission(t2, d2)): return t1 == t2 && d1 == d2
        case let (.question(o1), .question(o2)):
            return o1.map(\.index) == o2.map(\.index) && o1.map(\.label) == o2.map(\.label)
        case let (.planReview(c1), .planReview(c2)): return c1 == c2
        default: return false
        }
    }

    static func parse(from screen: String) -> PendingAction? {
        let lines = screen.components(separatedBy: "\n")

        // AskUserQuestion: detect by "Enter to select" marker
        if lines.contains(where: { $0.contains("Enter to select") }) {
            var options: [(index: Int, label: String)] = []
            for line in lines {
                var cleaned = line.trimmingCharacters(in: .whitespaces)
                // Remove ❯ prefix (selected item marker)
                if cleaned.hasPrefix("❯") {
                    cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                if let numStr = cleaned.firstCaptureGroup(of: #"^(\d+)\.\s+"#),
                   let num = Int(numStr),
                   let dotRange = cleaned.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                    let label = String(cleaned[dotRange.upperBound...])
                    if !label.isEmpty { options.append((num, label)) }
                }
            }
            if options.count >= 2 { return .question(options: options) }
        }

        // Plan review: detect plan mode
        if lines.contains(where: { $0.contains("Plan:") || $0.contains("plan mode") || $0.contains("ExitPlanMode") }) {
            let planContent = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .suffix(20).joined(separator: "\n")
            if !planContent.isEmpty { return .planReview(content: planContent) }
        }

        // Permission prompt: look for "Allow"
        for (i, line) in lines.enumerated() {
            if line.contains("Allow") && (line.contains("(y") || line.contains("yes")) {
                var tool = "Tool"
                var detail = ""
                for j in stride(from: i - 1, through: max(0, i - 6), by: -1) {
                    if lines[j].contains("⏺") {
                        if let match = lines[j].firstCaptureGroup(of: #"⏺\s+(\w+)"#) {
                            tool = match
                        }
                        detail = lines[j].trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                return .permission(tool: tool, detail: detail)
            }
        }

        return nil
    }
}

struct AgentSession: Identifiable, Equatable {
    let id: String
    let pid: Int
    let sessionId: String
    var workspace: String
    var workspaceRef: String
    var surfaceRef: String
    var task: String
    var cwd: String
    let startedAt: Date
    var status: AgentStatus
    var lastMessage: String = ""
    var pendingAction: PendingAction?
    var notificationPreview: String?
    var isUnread: Bool = false

    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        if minutes > 0 {
            return "\(minutes)m\(String(format: "%02d", seconds))s"
        }
        return "\(seconds)s"
    }

    var projectName: String {
        (cwd as NSString).lastPathComponent
    }
}
