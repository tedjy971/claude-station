import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = SessionManager()
    let hookServer = HookServer()
    let shortcuts = KeyboardShortcuts()
    let updater = AutoUpdater()
    private var notchWindow: NotchOverlayWindow?
    private var onboardingWindow: NSWindow?

    private var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "onboardingCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "onboardingCompleted") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installHookScript()

        hookServer.start()
        manager.hookServer = hookServer
        manager.startMonitoring()

        DispatchQueue.main.async { [self] in
            notchWindow = NotchOverlayWindow(manager: manager)
            notchWindow?.orderFrontRegardless()
            shortcuts.setup(manager: manager, overlayWindow: notchWindow)

            if !hasCompletedOnboarding {
                showOnboarding()
            }

            // Check for updates every 6 hours
            updater.checkForUpdates()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stopMonitoring()
        hookServer.stop()
        shortcuts.teardown()
    }

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Station"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView {
            self.hasCompletedOnboarding = true
            window.close()
        })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func installHookScript() {
        let destDir = NSString(string: "~/.claude-station").expandingTildeInPath
        let destPath = (destDir as NSString).appendingPathComponent("claude-station-hook")
        let fm = FileManager.default
        try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        if let bundled = Bundle.main.path(forResource: "claude-station-hook", ofType: nil) {
            try? fm.removeItem(atPath: destPath)
            try? fm.copyItem(atPath: bundled, toPath: destPath)
        }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
    }
}
