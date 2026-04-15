import AppKit
import SwiftUI

final class NotchOverlayWindow: NSWindow {
    init(manager: SessionManager) {
        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        let width: CGFloat = 280
        let height: CGFloat = 34
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height - 2

        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hasShadow = false
        ignoresMouseEvents = true

        contentView = NSHostingView(
            rootView: NotchOverlayView().environment(manager)
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
