import SwiftUI

@main
struct ClaudeStationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appDelegate.manager)
        } label: {
            let icon = appDelegate.manager.hasWaiting
                ? "exclamationmark.cloud.fill"
                : "cloud.fill"
            Image(systemName: icon)
        }
        .menuBarExtraStyle(.window)
    }
}
