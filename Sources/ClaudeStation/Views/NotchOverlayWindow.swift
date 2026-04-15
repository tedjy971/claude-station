import AppKit
import SwiftUI

final class NotchOverlayWindow: NSPanel {
    private let manager: SessionManager
    private var popover: NSPopover?
    private var screenObserver: Any?

    init(manager: SessionManager) {
        self.manager = manager

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let (frame, _) = Self.computeFrame(for: screen)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        let hostView = NSHostingView(
            rootView: NotchOverlayView(onTap: { [weak self] in
                self?.togglePopover()
            }).environment(manager)
        )
        hostView.frame = NSRect(origin: .zero, size: frame.size)
        contentView = hostView

        // Reposition when screens change (plug/unplug external display)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.repositionForCurrentScreen()
        }
    }

    deinit {
        if let obs = screenObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // Non-activating: never steal focus
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Positioning

    private static func computeFrame(for screen: NSScreen) -> (NSRect, Bool) {
        let width: CGFloat = 340
        let height: CGFloat = 40
        let x = screen.frame.midX - width / 2

        // Check for notch: auxiliaryTopLeftArea exists only on notch displays
        let hasNotch = screen.auxiliaryTopLeftArea != nil
        let y: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea {
            // Notch display: position just below notch
            y = leftArea.origin.y - height - 2
        } else {
            // External/no-notch: floating bar at top center, below menu bar
            y = screen.visibleFrame.maxY - height - 6
        }

        return (NSRect(x: x, y: y, width: width, height: height), hasNotch)
    }

    func repositionForCurrentScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let (frame, _) = Self.computeFrame(for: screen)
        setFrame(frame, display: true, animate: true)
        contentView?.frame = NSRect(origin: .zero, size: frame.size)
    }

    // MARK: - Popover

    func togglePopover() {
        if let popover, popover.isShown {
            popover.close()
            self.popover = nil
            return
        }

        guard let contentView else { return }

        let p = NSPopover()
        p.contentViewController = NSHostingController(
            rootView: AgentPopoverView().environment(manager)
        )
        p.behavior = .transient
        p.contentSize = NSSize(width: 400, height: 450)
        p.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        self.popover = p
    }
}
