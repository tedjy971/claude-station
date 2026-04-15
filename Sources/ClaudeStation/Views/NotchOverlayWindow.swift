import AppKit
import SwiftUI

final class NotchOverlayWindow: NSWindow {
    private let manager: SessionManager
    private var popover: NSPopover?

    init(manager: SessionManager) {
        self.manager = manager

        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        // Position precisely below the notch
        // Use auxiliaryTopLeftArea to find exact notch bottom edge
        let notchBottomY: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea {
            notchBottomY = leftArea.origin.y
        } else {
            notchBottomY = screen.visibleFrame.maxY
        }

        let width: CGFloat = 340
        let height: CGFloat = 40
        let x = screen.frame.midX - width / 2
        let y = notchBottomY - height - 2

        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
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

        let hostView = NSHostingView(
            rootView: NotchOverlayView(onTap: { [weak self] in
                self?.togglePopover()
            }).environment(manager)
        )
        hostView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        contentView = hostView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

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
