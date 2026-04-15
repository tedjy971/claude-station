import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = SessionManager()
    let hookServer = HookServer()
    private var notchWindow: NotchOverlayWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Install hook script to ~/.claude-station/
        installHookScript()

        // Start services
        hookServer.start()
        manager.hookServer = hookServer
        manager.startMonitoring()

        DispatchQueue.main.async { [self] in
            notchWindow = NotchOverlayWindow(manager: manager)
            notchWindow?.orderFrontRegardless()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stopMonitoring()
        hookServer.stop()
    }

    private func installHookScript() {
        let destDir = NSString(string: "~/.claude-station").expandingTildeInPath
        let destPath = (destDir as NSString).appendingPathComponent("claude-station-hook")
        let fm = FileManager.default

        try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)

        // Copy hook script from bundle or create it
        if let bundled = Bundle.main.path(forResource: "claude-station-hook", ofType: nil) {
            try? fm.removeItem(atPath: destPath)
            try? fm.copyItem(atPath: bundled, toPath: destPath)
        }

        // Ensure executable
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
    }
}
