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
        case .waiting: .orange
        case .running: .blue
        case .idle: .secondary
        case .completed: .green
        case .unknown: .secondary
        }
    }

    var showInOverlay: Bool {
        self == .running || self == .waiting
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
