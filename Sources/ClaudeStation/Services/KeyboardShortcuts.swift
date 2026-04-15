import AppKit
import Carbon.HIToolbox

@MainActor
final class KeyboardShortcuts {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var manager: SessionManager?
    private weak var overlayWindow: NotchOverlayWindow?

    func setup(manager: SessionManager, overlayWindow: NotchOverlayWindow?) {
        self.manager = manager
        self.overlayWindow = overlayWindow

        // Global monitor: works when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
        }

        // Local monitor: works when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return event
        }
    }

    func teardown() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Ctrl+Shift+A → Approve all waiting agents
        if flags == [.control, .shift] && event.keyCode == UInt16(kVK_ANSI_A) {
            approveAll()
        }

        // Ctrl+Shift+D → Deny all waiting agents
        if flags == [.control, .shift] && event.keyCode == UInt16(kVK_ANSI_D) {
            denyAll()
        }

        // Ctrl+Shift+V → Toggle overlay popover
        if flags == [.control, .shift] && event.keyCode == UInt16(kVK_ANSI_V) {
            togglePopover()
        }
    }

    private func approveAll() {
        guard let manager else { return }
        let waiting = manager.agents.filter { $0.status == .waiting }
        for agent in waiting {
            manager.approveAgent(agent)
        }
    }

    private func denyAll() {
        guard let manager else { return }
        let waiting = manager.agents.filter { $0.status == .waiting }
        for agent in waiting {
            manager.denyAgent(agent)
        }
    }

    private func togglePopover() {
        overlayWindow?.togglePopover()
    }
}
