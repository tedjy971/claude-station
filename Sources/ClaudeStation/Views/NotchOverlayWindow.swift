import AppKit
import SwiftUI

final class NotchOverlayWindow: NSPanel {
    private let manager: SessionManager
    private var popover: NSPopover?
    private var screenObserver: Any?
    private var dragOrigin: NSPoint?

    private static let savedPositionKey = "capsulePosition"

    init(manager: SessionManager) {
        self.manager = manager

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = Self.initialFrame(for: screen)

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
        isMovable = false

        let hostView = NSHostingView(
            rootView: NotchOverlayView(onTap: { [weak self] in
                self?.togglePopover()
            }).environment(manager)
        )
        hostView.frame = NSRect(origin: .zero, size: frame.size)
        hostView.autoresizingMask = [.width, .height]
        hostView.translatesAutoresizingMaskIntoConstraints = true
        contentView = hostView

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.resetToDefault()
        }
    }

    deinit {
        if let obs = screenObserver { NotificationCenter.default.removeObserver(obs) }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Dragging

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            resetToDefault()
            return
        }
        dragOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let current = event.locationInWindow
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        var newOrigin = frame.origin
        newOrigin.x += dx
        newOrigin.y += dy
        setFrameOrigin(newOrigin)
        savePosition()
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
    }

    // MARK: - Position Persistence

    private func savePosition() {
        let point = frame.origin
        UserDefaults.standard.set(
            ["x": point.x, "y": point.y],
            forKey: Self.savedPositionKey
        )
    }

    private static func savedPosition() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: savedPositionKey),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat else { return nil }
        return NSPoint(x: x, y: y)
    }

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.savedPositionKey)
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = Self.defaultFrame(for: screen)
        setFrame(frame, display: true, animate: true)
    }

    // MARK: - Frame Calculation

    private static let capsuleWidth: CGFloat = 460
    private static let capsuleHeight: CGFloat = 90

    private static func defaultFrame(for screen: NSScreen) -> NSRect {
        let x = screen.frame.midX - capsuleWidth / 2
        let y: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea {
            y = leftArea.origin.y - capsuleHeight - 2
        } else {
            y = screen.visibleFrame.maxY - capsuleHeight - 6
        }
        return NSRect(x: x, y: y, width: capsuleWidth, height: capsuleHeight)
    }

    private static func initialFrame(for screen: NSScreen) -> NSRect {
        if let saved = savedPosition() {
            return NSRect(x: saved.x, y: saved.y, width: capsuleWidth, height: capsuleHeight)
        }
        return defaultFrame(for: screen)
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
        p.contentSize = NSSize(width: 420, height: 450)
        p.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        self.popover = p
    }
}
