import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = SessionManager()
    private var notchWindow: NotchOverlayWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        manager.startMonitoring()

        DispatchQueue.main.async { [self] in
            notchWindow = NotchOverlayWindow(manager: manager)
            notchWindow?.orderFrontRegardless()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stopMonitoring()
    }
}
