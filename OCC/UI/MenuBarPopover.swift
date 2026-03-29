import SwiftUI
import AppKit
import CoreGraphics

struct MenuBarPopover: View {
    @ObservedObject var router: NotificationRouter
    @ObservedObject var watchedFolders: WatchedFolders
    let onPositionChange: (PillPosition) -> Void
    let onScreenChange: (UInt32) -> Void
    let onAddFolder: () -> Void

    @AppStorage("occ.pill.position") private var positionRaw = PillPosition.bottomRight.rawValue
    @AppStorage("occ.pill.screenId") private var selectedScreenId: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("One's Command Center")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("v0.2")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Sections
            ScrollView {
                VStack(spacing: 0) {
                    // Position
                    popoverSection {
                        HStack {
                            Label("Position", systemImage: "rectangle.bottomthird.inset.filled")
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            Spacer()
                            Picker("", selection: $positionRaw) {
                                ForEach(PillPosition.allCases, id: \.rawValue) { pos in
                                    Text(pos.label).tag(pos.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                            .onChange(of: positionRaw) { newValue in
                                if let pos = PillPosition(rawValue: newValue) {
                                    onPositionChange(pos)
                                }
                            }
                        }
                    }

                    // Display
                    if NSScreen.screens.count > 1 {
                        popoverSection {
                            HStack {
                                Label("Display", systemImage: "display")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Picker("", selection: $selectedScreenId) {
                                    ForEach(NSScreen.screens, id: \.displayIdInt) { screen in
                                        Text(screen.displayName)
                                            .tag(screen.displayIdInt)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: 140)
                                .onChange(of: selectedScreenId) { newValue in
                                    onScreenChange(UInt32(newValue))
                                }
                            }
                        }
                    }

                    // Watched Folders
                    popoverSection {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Watched Folders", systemImage: "folder")
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)

                            if watchedFolders.folders.isEmpty {
                                Text("Add a project folder to watch")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 6)
                            } else {
                                VStack(spacing: 2) {
                                    ForEach(watchedFolders.folders, id: \.path) { folder in
                                        HStack(spacing: 8) {
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)

                                            Text(shortenedPath(folder))
                                                .font(.system(size: 11))
                                                .lineLimit(1)
                                                .truncationMode(.middle)

                                            Spacer()

                                            Button(action: { watchedFolders.remove(folder) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.quaternary)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Circle())
                                        }
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(.quaternary.opacity(0.15))
                                        )
                                    }
                                }
                            }

                            Button(action: onAddFolder) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Add Folder")
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }
                    }

                    // Recent
                    popoverSection {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Recent", systemImage: "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)

                            if router.history.isEmpty {
                                Text("No nudges yet")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            } else {
                                VStack(spacing: 2) {
                                    ForEach(router.history.prefix(8)) { nudge in
                                        HStack(spacing: 8) {
                                            statusDot(nudge.status)
                                                .frame(width: 8, height: 8)

                                            Text(nudge.title)
                                                .font(.system(size: 11))
                                                .lineLimit(1)

                                            Spacer()

                                            Text(nudge.timestamp, style: .relative)
                                                .font(.system(size: 9))
                                                .foregroundStyle(.quaternary)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(.quaternary.opacity(0.08))
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer actions
            HStack(spacing: 12) {
                Button {
                    router.push(Nudge(
                        title: "Test Notification",
                        body: "This is a test nudge from the menu bar.",
                        priority: .medium,
                        url: URL(string: "https://github.com"),
                        action: "Open GitHub"
                    ))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 10))
                        Text("Test Nudge")
                            .font(.system(size: 11))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.system(size: 11))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 440)
    }

    // MARK: - Components

    @ViewBuilder
    private func popoverSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func statusDot(_ status: NudgeStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .overlay(
                Circle()
                    .strokeBorder(statusColor(status).opacity(0.3), lineWidth: 1)
            )
    }

    private func shortenedPath(_ url: URL) -> String {
        let components = url.pathComponents
        if components.count > 3 {
            return "~/" + components.suffix(2).joined(separator: "/")
        }
        return url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func statusColor(_ status: NudgeStatus) -> Color {
        switch status {
        case .approved: return .green
        case .rejected: return .red
        case .replied: return .blue
        case .dismissed: return .gray
        case .pending: return .orange
        case .requested: return .yellow
        case .working: return .green
        }
    }
}

// MARK: - NSScreen helpers

extension NSScreen {
    var displayId: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) ?? 0
    }

    var displayIdInt: Int {
        Int(displayId)
    }

    var displayName: String {
        if CGDisplayIsBuiltin(displayId) != 0 {
            return "Built-in Display"
        }
        return localizedName
    }
}
