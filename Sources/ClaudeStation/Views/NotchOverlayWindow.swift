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

        let width: CGFloat = 280
        let height: CGFloat = 34
        let x = screen.frame.midX - width / 2
        let y = screen.visibleFrame.maxY - height - 4

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
        hasShadow = true
        ignoresMouseEvents = false

        let hostView = NSHostingView(
            rootView: NotchOverlayView(onTap: { [weak self] in
                self?.togglePopover()
            }).environment(manager)
        )
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
        let controller = NSHostingController(
            rootView: AgentPopoverView().environment(manager)
        )
        p.contentViewController = controller
        p.behavior = .transient
        p.contentSize = NSSize(width: 380, height: 400)
        p.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        self.popover = p
    }
}
