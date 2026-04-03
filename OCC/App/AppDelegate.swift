import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pillPanel: PillPanel!
    private var popover: NSPopover!
    private var cliBridge: CLIBridge!
    private var folderWatcher: FolderWatcher!
    private var folderSubscription: AnyCancellable?
    private var clickMonitor: Any?

    let nudgeRouter = NotificationRouter()
    let watchedFolders = WatchedFolders()
    let flowStore = FlowStore()
    let skillStore = SkillStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPillPanel()
        setupCLIBridge()
        setupFolderWatcher()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cliBridge.stop()
        folderWatcher.stopAll()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let svgURL = Bundle.module.url(forResource: "icon-mark", withExtension: "svg"),
               let svgImage = NSImage(contentsOf: svgURL) {
                // Render SVG into a bitmap so template tinting works reliably
                let size = NSSize(width: 16, height: 16)
                let rendered = NSImage(size: size)
                rendered.lockFocus()
                svgImage.draw(
                    in: NSRect(origin: .zero, size: size),
                    from: NSRect(origin: .zero, size: svgImage.size),
                    operation: .sourceOver,
                    fraction: 1.0
                )
                rendered.unlockFocus()
                rendered.isTemplate = true
                button.image = rendered
            } else {
                button.image = NSImage(
                    systemSymbolName: "circle.fill",
                    accessibilityDescription: "One's Command Center"
                )
                button.image?.size = NSSize(width: 14, height: 14)
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover(
                router: nudgeRouter,
                watchedFolders: watchedFolders,
                onPositionChange: { [weak self] position in
                    self?.pillPanel.reposition(to: position)
                },
                onScreenChange: { [weak self] screenId in
                    self?.pillPanel.moveToScreen(id: screenId)
                },
                onAddFolder: { [weak self] in
                    self?.addFolder()
                }
            )
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            clickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Add Folder

    private func addFolder() {
        // Close the popover first
        popover.performClose(nil)

        // Delay to let the popover fully dismiss, then activate app and show panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            // Temporarily become a regular app so the open panel works properly
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Choose a project folder to watch for .occ nudge files"
            panel.prompt = "Watch"

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    self?.watchedFolders.add(url)
                }

                // Go back to being an agent app (no dock icon)
                DispatchQueue.main.async {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    // MARK: - Pill Panel

    private func setupPillPanel() {
        let position = PillPosition.current
        pillPanel = PillPanel(router: nudgeRouter, flowStore: flowStore, skillStore: skillStore, position: position)
        pillPanel.orderFrontRegardless()
    }

    // MARK: - CLI Bridge

    private func setupCLIBridge() {
        cliBridge = CLIBridge(router: nudgeRouter)
        cliBridge.start()
    }

    // MARK: - Folder Watcher

    private func setupFolderWatcher() {
        folderWatcher = FolderWatcher(router: nudgeRouter)

        // Watch all currently saved folders + populate reply lookup
        var pathMap: [String: String] = [:]
        for folder in watchedFolders.folders {
            folderWatcher.watch(folder)
            pathMap[folder.lastPathComponent] = folder.path
        }
        ReplyWriter.watchedFolderPaths = pathMap
        RequestWriter.watchedFolderPaths = pathMap

        // Load flows from watched folders
        flowStore.loadFlows(from: watchedFolders.folders)
        skillStore.loadSkills(from: watchedFolders.folders)

        // React to folder list changes
        folderSubscription = watchedFolders.$folders
            .removeDuplicates()
            .sink { [weak self] folders in
                guard let self else { return }
                self.folderWatcher.stopAll()

                // Update ReplyWriter's folder lookup
                var pathMap: [String: String] = [:]
                for folder in folders {
                    pathMap[folder.lastPathComponent] = folder.path
                    self.folderWatcher.watch(folder)
                }
                ReplyWriter.watchedFolderPaths = pathMap
                RequestWriter.watchedFolderPaths = pathMap

                // Reload flows and skills
                self.flowStore.loadFlows(from: folders)
                self.skillStore.loadSkills(from: folders)
            }
    }
}
