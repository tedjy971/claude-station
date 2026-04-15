import SwiftUI

struct MenuBarView: View {
    @Environment(SessionManager.self) private var manager

    var body: some View {
        AgentPopoverView()
            .environment(manager)
    }
}
