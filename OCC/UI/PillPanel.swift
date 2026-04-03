import AppKit
import SwiftUI

final class PillPanel: NSPanel {
    private var position: PillPosition
    private let router: NotificationRouter
    private let flowStore: FlowStore
    private let skillStore: SkillStore
    private var hostView: FirstMouseHostingView<PillContainerView>!
    private var flowWindow: NSWindow?
    private var flowInputWindow: NSWindow?
    private var flowClickMonitor: Any?

    init(router: NotificationRouter, flowStore: FlowStore, skillStore: SkillStore, position: PillPosition) {
        self.router = router
        self.flowStore = flowStore
        self.skillStore = skillStore
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
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.router.state == .expanded || self.router.state == .input else { return }
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

        repositionOnScreen()
    }

    func moveToScreen(id: UInt32) {
        UserDefaults.standard.set(Int(id), forKey: "occ.pill.screenId")
        repositionOnScreen()
    }

    private func repositionOnScreen() {
        let savedId = UInt32(UserDefaults.standard.integer(forKey: "occ.pill.screenId"))
        let screen = NSScreen.screens.first(where: { $0.displayId == savedId })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 4
        let size = frame.size

        var origin: NSPoint
        switch position {
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

    override func rightMouseDown(with event: NSEvent) {
        // Only trigger if clicking near the pill dot area
        let clickScreen = NSEvent.mouseLocation
        let dotScreen = pillDotScreenRect()
        let hitArea = dotScreen.insetBy(dx: -20, dy: -20)
        guard hitArea.contains(clickScreen) else {
            super.rightMouseDown(with: event)
            return
        }
        toggleFlowWindow()
    }

    /// Pill dot rect in screen coordinates (AppKit: y=0 at bottom)
    private func pillDotScreenRect() -> NSRect {
        let panelFrame = self.frame
        let dotX: CGFloat
        switch position {
        case .bottomRight:
            dotX = panelFrame.maxX - 8 - 32
        case .bottomLeft:
            dotX = panelFrame.minX + 8
        case .bottomCenter:
            dotX = panelFrame.midX - 16
        }
        let dotY = panelFrame.minY + 8
        return NSRect(x: dotX, y: dotY, width: 32, height: 32)
    }

    private func toggleFlowWindow() {
        if let existing = flowWindow, existing.isVisible {
            dismissFlowWindow()
            return
        }

        let viewWidth: CGFloat = 300
        let maxItems = max(flowStore.flows.count, skillStore.skills.count)
        let viewHeight = maxItems == 0 ? CGFloat(120) : min(CGFloat(maxItems * 44 + 80), 400)
        let viewSize = NSSize(width: viewWidth, height: viewHeight)

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: viewSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)))
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Use NSVisualEffectView as the base for proper rounded corners
        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: viewSize))
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0.5
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor

        let hostingView = TransparentHostingView(rootView:
            CommandPanelView(
                flowStore: flowStore,
                skillStore: skillStore,
                onSelectFlow: { [weak self] flow in
                    self?.showFlowInput(for: flow)
                },
                onSelectSkill: { [weak self] skill in
                    self?.showSkillInput(for: skill)
                }
            )
        )
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)

        window.contentView = effectView
        // Also mask the window's own content view layer
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true

        // Position directly above the pill dot, centered, clamped to screen
        let dotScreen = pillDotScreenRect()
        var windowX = dotScreen.midX - viewSize.width / 2
        let windowY = dotScreen.maxY + 8

        // Keep within screen bounds
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(dotScreen.origin) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            windowX = max(screenFrame.minX + 4, min(windowX, screenFrame.maxX - viewSize.width - 4))
        }

        window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        window.alphaValue = 0
        window.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        flowWindow = window
        router.showingFlows = true

        // Dismiss on outside click
        flowClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return }
            let clickLoc = NSEvent.mouseLocation
            let inFlow = self.flowWindow?.frame.contains(clickLoc) ?? false
            let inInput = self.flowInputWindow?.frame.contains(clickLoc) ?? false
            if !inFlow && !inInput {
                self.dismissFlowInput()
                self.dismissFlowWindow()
            }
        }
    }

    private func showFlowInput(for flow: Flow) {
        // Dismiss any existing input
        dismissFlowInput()

        guard let flowWin = flowWindow else { return }

        let inputSize = NSSize(width: 300, height: 72)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: inputSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // NSVisualEffectView for the blurred background with proper rounded corners
        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: inputSize))
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0.5
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        let hostingView = TransparentHostingView(rootView:
            FlowInputView(
                flow: flow,
                onSend: { [weak self] message in
                    guard let self else { return }
                    let request = "Run flow: \(flow.id)\n\n\(message)"
                    RequestWriter.sendRequest(request)
                    self.router.markRequestSent()
                    self.flowStore.recordRun(for: flow.id)
                    self.dismissFlowInput()
                    self.dismissFlowWindow()
                },
                onCancel: { [weak self] in
                    self?.dismissFlowInput()
                }
            )
        )
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)

        panel.contentView = effectView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 14
        panel.contentView?.layer?.masksToBounds = true

        // Position directly above the flow list window
        let flowFrame = flowWin.frame
        let inputX = flowFrame.midX - inputSize.width / 2
        let inputY = flowFrame.maxY + 2

        panel.setFrameOrigin(NSPoint(x: inputX, y: inputY))
        panel.alphaValue = 0
        panel.orderFront(nil)

        // Activate app, then make panel key so text field gets focus
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        flowInputWindow = panel
    }

    private func showSkillInput(for skill: Skill) {
        dismissFlowInput()
        guard let flowWin = flowWindow else { return }

        let inputSize = NSSize(width: 300, height: 72)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: inputSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: inputSize))
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0.5
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        let hostingView = TransparentHostingView(rootView:
            SkillInputView(
                skill: skill,
                onSend: { [weak self] message in
                    guard let self else { return }
                    let request = "Run skill: \(skill.id)\n\n\(message)"
                    RequestWriter.sendRequest(request)
                    self.router.markRequestSent()
                    self.dismissFlowInput()
                    self.dismissFlowWindow()
                },
                onCancel: { [weak self] in
                    self?.dismissFlowInput()
                }
            )
        )
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)

        panel.contentView = effectView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 14
        panel.contentView?.layer?.masksToBounds = true

        let flowFrame = flowWin.frame
        let inputX = flowFrame.midX - inputSize.width / 2
        let inputY = flowFrame.maxY + 2

        panel.setFrameOrigin(NSPoint(x: inputX, y: inputY))
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        flowInputWindow = panel
    }

    private func dismissFlowInput() {
        guard let window = flowInputWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
        flowInputWindow = nil
    }

    private func dismissFlowWindow() {
        dismissFlowInput()
        guard let window = flowWindow else { return }
        if let monitor = flowClickMonitor {
            NSEvent.removeMonitor(monitor)
            flowClickMonitor = nil
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.flowWindow = nil
        })
        router.showingFlows = false
    }
}

/// NSHostingView subclass that accepts first mouse click without requiring activation.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Borderless panel that can become key (needed for text field focus).
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// NSHostingView subclass that forces a transparent background.
/// NSHostingView internally resets its layer background, so we must
/// override layout to continuously clear it.
final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearBackground()
    }

    override func layout() {
        super.layout()
        clearBackground()
    }

    private func clearBackground() {
        wantsLayer = true
        layer?.backgroundColor = .clear
        // Walk sublayers and clear any opaque ones NSHostingView adds
        layer?.sublayers?.forEach { $0.backgroundColor = .clear }
    }
}
