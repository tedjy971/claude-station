import AppKit
import SwiftUI

final class NotchOverlayWindow: NSPanel {
    private let manager: SessionManager
    private var popover: NSPopover?
    private var screenObserver: Any?

    // Drag state
    private var dragMouseStart: NSPoint?
    private var dragFrameStart: NSPoint?
    private var globalDragMonitor: Any?
    private var localDragMonitor: Any?
    private var zoneOverlay: SnapZoneOverlay?

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
                onDragStart: { [weak self] in self?.startDrag() }
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
        cleanupDragMonitors()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Drag (NSEvent-based, pixel-perfect)

    private func startDrag() {
        dragMouseStart = NSEvent.mouseLocation
        dragFrameStart = frame.origin

        // Show zone indicators
        if let screen = NSScreen.main {
            zoneOverlay = SnapZoneOverlay(screen: screen, zones: Self.allZoneFrames(screen: screen))
            zoneOverlay?.orderFront(nil)
        }

        // Global monitor: track mouse everywhere on screen
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            if event.type == .leftMouseUp {
                self?.endDrag()
            } else {
                self?.updateDrag()
            }
        }

        // Local monitor: track within our own window
        localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            if event.type == .leftMouseUp {
                self?.endDrag()
            } else {
                self?.updateDrag()
            }
            return event
        }
    }

    private func updateDrag() {
        guard let start = dragMouseStart, let frameStart = dragFrameStart else { return }
        let current = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(
            x: frameStart.x + (current.x - start.x),
            y: frameStart.y + (current.y - start.y)
        ))

        // Highlight nearest zone
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let nearest = nearestZone(to: center)
        zoneOverlay?.highlightZone(nearest)
    }

    private func endDrag() {
        cleanupDragMonitors()

        let center = NSPoint(x: frame.midX, y: frame.midY)
        let zone = nearestZone(to: center)

        // Hide zone overlay
        zoneOverlay?.fadeOut()
        zoneOverlay = nil

        snapToZone(zone)
        dragMouseStart = nil
        dragFrameStart = nil
    }

    private func cleanupDragMonitors() {
        if let m = globalDragMonitor { NSEvent.removeMonitor(m); globalDragMonitor = nil }
        if let m = localDragMonitor { NSEvent.removeMonitor(m); localDragMonitor = nil }
    }

    // MARK: - Snap Zones

    enum SnapZone: String, CaseIterable {
        case topLeft, topCenter, topRight
        case left, center, right
        case bottomLeft, bottomCenter, bottomRight
    }

    private static func allZoneFrames(screen: NSScreen) -> [(SnapZone, NSRect)] {
        SnapZone.allCases.map { zone in
            let f = frameForZone(zone, screen: screen)
            // Return a compact indicator rect (centered, smaller)
            let indicatorW: CGFloat = 80
            let indicatorH: CGFloat = 30
            let rect = NSRect(
                x: f.midX - indicatorW / 2,
                y: f.midY - indicatorH / 2,
                width: indicatorW,
                height: indicatorH
            )
            return (zone, rect)
        }
    }

    private static func frameForZone(_ zone: SnapZone, screen: NSScreen) -> NSRect {
        let w = capsuleWidth
        let h = capsuleHeight
        let vis = screen.visibleFrame
        let margin: CGFloat = 10

        let x: CGFloat
        let y: CGFloat

        switch zone {
        case .topLeft:     x = vis.minX + margin; y = topY(screen: screen)
        case .topCenter:   x = screen.frame.midX - w / 2; y = topY(screen: screen)
        case .topRight:    x = vis.maxX - w - margin; y = topY(screen: screen)
        case .left:        x = vis.minX + margin; y = vis.midY - h / 2
        case .center:      x = vis.midX - w / 2; y = vis.midY - h / 2
        case .right:       x = vis.maxX - w - margin; y = vis.midY - h / 2
        case .bottomLeft:  x = vis.minX + margin; y = vis.minY + margin
        case .bottomCenter: x = vis.midX - w / 2; y = vis.minY + margin
        case .bottomRight: x = vis.maxX - w - margin; y = vis.minY + margin
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
            let f = Self.frameForZone(zone, screen: screen)
            let dist = hypot(point.x - f.midX, point.y - f.midY)
            if dist < bestDist { bestDist = dist; best = zone }
        }
        return best
    }

    private func snapToZone(_ zone: SnapZone, animate: Bool = true) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let target = Self.frameForZone(zone, screen: screen)
        UserDefaults.standard.set(zone.rawValue, forKey: Self.savedZoneKey)

        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
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

    func resetToDefault() { snapToZone(.topCenter) }

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

// MARK: - Snap Zone Overlay (dotted indicators)

final class SnapZoneOverlay: NSWindow {
    private var zones: [(NotchOverlayWindow.SnapZone, NSRect)]
    private var highlighted: NotchOverlayWindow.SnapZone?
    private let hostView: NSHostingView<SnapZoneIndicators>
    private var indicatorView: SnapZoneIndicators

    init(screen: NSScreen, zones: [(NotchOverlayWindow.SnapZone, NSRect)]) {
        self.zones = zones
        self.indicatorView = SnapZoneIndicators(zones: zones, highlighted: nil)

        let hostView = NSHostingView(rootView: indicatorView)
        self.hostView = hostView

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false

        hostView.frame = NSRect(origin: .zero, size: screen.frame.size)
        contentView = hostView
    }

    func highlightZone(_ zone: NotchOverlayWindow.SnapZone) {
        guard zone != highlighted else { return }
        highlighted = zone
        indicatorView = SnapZoneIndicators(zones: zones, highlighted: zone)
        hostView.rootView = indicatorView
    }

    func fadeOut() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 0
        }) {
            self.orderOut(nil)
        }
    }
}

struct SnapZoneIndicators: View {
    let zones: [(NotchOverlayWindow.SnapZone, NSRect)]
    let highlighted: NotchOverlayWindow.SnapZone?

    var body: some View {
        GeometryReader { geo in
            ForEach(zones, id: \.0.rawValue) { zone, rect in
                let isActive = zone == highlighted
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isActive ? DS.cyan : DS.text3.opacity(0.3),
                        style: StrokeStyle(lineWidth: isActive ? 1.5 : 1, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isActive ? DS.cyan.opacity(0.08) : .clear)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(
                        x: rect.midX,
                        y: geo.size.height - rect.midY  // flip Y for SwiftUI
                    )
                    .animation(.easeOut(duration: 0.15), value: isActive)
            }
        }
    }
}
