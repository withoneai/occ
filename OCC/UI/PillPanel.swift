import AppKit
import SwiftUI

final class PillPanel: NSPanel {
    private var position: PillPosition
    private let router: NotificationRouter
    private var hostView: FirstMouseHostingView<PillContainerView>!

    init(router: NotificationRouter, position: PillPosition) {
        self.router = router
        self.position = position

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true

        hostView = FirstMouseHostingView(
            rootView: PillContainerView(router: router, position: position)
        )
        contentView = hostView

        reposition(to: position)

        // Monitor for clicks outside the panel to collapse expanded state
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self,
                  self.router.state == .expanded || self.router.state == .input else { return }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                    self.router.collapse()
                }
            }
        }
    }

    func reposition(to newPosition: PillPosition) {
        position = newPosition
        PillPosition.current = newPosition

        hostView.rootView = PillContainerView(router: router, position: newPosition)
        hostView.needsDisplay = true

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 4
        let size = frame.size

        var origin: NSPoint
        switch newPosition {
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - size.width - margin,
                y: screenFrame.minY + margin
            )
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.minY + margin
            )
        case .bottomCenter:
            origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.minY + margin
            )
        }

        setFrameOrigin(origin)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Make the panel key when clicked so buttons and text fields work
    override func mouseDown(with event: NSEvent) {
        makeKey()
        super.mouseDown(with: event)
    }
}

/// NSHostingView subclass that accepts first mouse click without requiring activation.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
