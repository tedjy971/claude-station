import SwiftUI

enum AgentStatus: Int, Comparable {
    case waiting = 0
    case running = 1
    case completed = 2
    case unknown = 3

    static func < (lhs: AgentStatus, rhs: AgentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var systemImage: String {
        switch self {
        case .waiting: "exclamationmark.circle.fill"
        case .running: "circle.dotted.circle"
        case .completed: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .waiting: "Waiting for input"
        case .running: "Running"
        case .completed: "Completed"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .waiting: .orange
        case .running: .blue
        case .completed: .green
        case .unknown: .secondary
        }
    }
}

struct AgentSession: Identifiable, Equatable {
    let id: String
    let pid: Int
    let sessionId: String
    var workspace: String
    var task: String
    var cwd: String
    let startedAt: Date
    var status: AgentStatus
    var notificationPreview: String?
    var isUnread: Bool = false

    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }

    var projectName: String {
        (cwd as NSString).lastPathComponent
    }
}
