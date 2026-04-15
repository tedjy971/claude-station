import AppKit
import SwiftUI

final class NotchOverlayWindow: NSPanel {
    private let manager: SessionManager
    private var popover: NSPopover?
    private var screenObserver: Any?
    private var dragStartOrigin: NSPoint?
    private var dragStartMouse: NSPoint?

    private static let savedZoneKey = "capsuleSnapZone"
    private static let capsuleWidth: CGFloat = 460
    private static let capsuleHeight: CGFloat = 90

    init(manager: SessionManager) {
        self.manager = manager

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = Self.frameForZone(Self.loadZone(), screen: screen)

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
            rootView: NotchOverlayView(
                onTap: { [weak self] in self?.togglePopover() },
                onDrag: { [weak self] translation in self?.handleDrag(translation) },
                onDragEnd: { [weak self] in self?.handleDragEnd() }
            ).environment(manager)
        )
        hostView.frame = NSRect(origin: .zero, size: frame.size)
        hostView.autoresizingMask = [.width, .height]
        hostView.translatesAutoresizingMaskIntoConstraints = true
        contentView = hostView

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.snapToZone(.topCenter, animate: false)
        }
    }

    deinit {
        if let obs = screenObserver { NotificationCenter.default.removeObserver(obs) }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Snap Zones

    enum SnapZone: String, CaseIterable {
        case topLeft, topCenter, topRight
        case left, center, right
        case bottomLeft, bottomCenter, bottomRight
    }

    private static func frameForZone(_ zone: SnapZone, screen: NSScreen) -> NSRect {
        let w = capsuleWidth
        let h = capsuleHeight
        let vis = screen.visibleFrame
        let margin: CGFloat = 10

        let x: CGFloat
        let y: CGFloat

        switch zone {
        // Top row
        case .topLeft:
            x = vis.minX + margin
            y = topY(screen: screen)
        case .topCenter:
            x = screen.frame.midX - w / 2
            y = topY(screen: screen)
        case .topRight:
            x = vis.maxX - w - margin
            y = topY(screen: screen)

        // Middle row
        case .left:
            x = vis.minX + margin
            y = vis.midY - h / 2
        case .center:
            x = vis.midX - w / 2
            y = vis.midY - h / 2
        case .right:
            x = vis.maxX - w - margin
            y = vis.midY - h / 2

        // Bottom row
        case .bottomLeft:
            x = vis.minX + margin
            y = vis.minY + margin
        case .bottomCenter:
            x = vis.midX - w / 2
            y = vis.minY + margin
        case .bottomRight:
            x = vis.maxX - w - margin
            y = vis.minY + margin
        }

        return NSRect(x: x, y: y, width: w, height: h)
    }

    private static func topY(screen: NSScreen) -> CGFloat {
        if let leftArea = screen.auxiliaryTopLeftArea {
            return leftArea.origin.y - capsuleHeight - 2
        }
        return screen.visibleFrame.maxY - capsuleHeight - 6
    }

    private func nearestZone(to point: NSPoint) -> SnapZone {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .topCenter }
        var best: SnapZone = .topCenter
        var bestDist = CGFloat.greatestFiniteMagnitude

        for zone in SnapZone.allCases {
            let frame = Self.frameForZone(zone, screen: screen)
            let center = NSPoint(x: frame.midX, y: frame.midY)
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist < bestDist {
                bestDist = dist
                best = zone
            }
        }
        return best
    }

    private func snapToZone(_ zone: SnapZone, animate: Bool = true) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let target = Self.frameForZone(zone, screen: screen)
        UserDefaults.standard.set(zone.rawValue, forKey: Self.savedZoneKey)

        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: true)
        }
    }

    private static func loadZone() -> SnapZone {
        guard let raw = UserDefaults.standard.string(forKey: savedZoneKey),
              let zone = SnapZone(rawValue: raw) else { return .topCenter }
        return zone
    }

    // MARK: - Dragging

    private func handleDrag(_ translation: CGSize) {
        if dragStartOrigin == nil {
            dragStartOrigin = frame.origin
        }
        guard let start = dragStartOrigin else { return }
        setFrameOrigin(NSPoint(
            x: start.x + translation.width,
            y: start.y - translation.height
        ))
    }

    private func handleDragEnd() {
        let currentCenter = NSPoint(x: frame.midX, y: frame.midY)
        let zone = nearestZone(to: currentCenter)
        dragStartOrigin = nil
        snapToZone(zone)
    }

    func resetToDefault() {
        snapToZone(.topCenter)
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
