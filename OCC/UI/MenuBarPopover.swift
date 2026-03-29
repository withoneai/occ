import SwiftUI
import AppKit

struct MenuBarPopover: View {
    @ObservedObject var router: NotificationRouter
    @ObservedObject var watchedFolders: WatchedFolders
    let onPositionChange: (PillPosition) -> Void
    let onAddFolder: () -> Void

    @AppStorage("occ.pill.position") private var positionRaw = PillPosition.bottomRight.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("OCC")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("v0.2")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Position picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Position")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: $positionRaw) {
                    ForEach(PillPosition.allCases, id: \.rawValue) { pos in
                        Text(pos.label).tag(pos.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: positionRaw) { newValue in
                    if let pos = PillPosition(rawValue: newValue) {
                        onPositionChange(pos)
                    }
                }
            }

            Divider()

            // Watched Folders
            VStack(alignment: .leading, spacing: 8) {
                Text("Watched Folders")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if watchedFolders.folders.isEmpty {
                    Text("Add a project folder to watch for .uni nudge files")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 4) {
                        ForEach(watchedFolders.folders, id: \.path) { folder in
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)

                                Text(shortenedPath(folder))
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.head)

                                Spacer()

                                Button(action: { watchedFolders.remove(folder) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.quaternary.opacity(0.3))
                            )
                        }
                    }
                }

                Button(action: onAddFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Add Folder")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Divider()

            // Recent nudges
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if router.history.isEmpty {
                    Text("No nudges yet")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(router.history.prefix(10)) { nudge in
                                HStack(spacing: 8) {
                                    statusIcon(nudge.status)
                                        .font(.system(size: 8))
                                        .frame(width: 12)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(nudge.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        HStack(spacing: 4) {
                                            Text(statusLabel(nudge.status))
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundStyle(statusColor(nudge.status))
                                            if let folder = nudge.sourceFolder {
                                                Text("· \(folder)")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            Text("· \(nudge.timestamp, style: .relative)")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.quaternary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }

            Divider()

            // Test nudge
            Button("Send Test Nudge") {
                router.push(Nudge(
                    title: "Test Notification",
                    body: "This is a test nudge from the menu bar.",
                    priority: .medium,
                    url: URL(string: "https://github.com"),
                    action: "Open GitHub"
                ))
            }
            .font(.system(size: 11))
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 0)

            Button("Quit OCC") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 300, height: 460)
    }

    private func shortenedPath(_ url: URL) -> String {
        let components = url.pathComponents
        if components.count > 3 {
            return "~/" + components.suffix(2).joined(separator: "/")
        }
        return url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    @ViewBuilder
    private func statusIcon(_ status: NudgeStatus) -> some View {
        switch status {
        case .approved:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .rejected:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .replied:
            Image(systemName: "arrowshape.turn.up.left.circle.fill").foregroundStyle(.blue)
        case .dismissed:
            Image(systemName: "minus.circle.fill").foregroundStyle(.gray)
        case .pending:
            Circle().fill(.orange).frame(width: 5, height: 5)
        case .requested:
            Image(systemName: "arrow.up.circle.fill").foregroundStyle(.yellow)
        case .working:
            Image(systemName: "gear.circle.fill").foregroundStyle(.green)
        }
    }

    private func statusLabel(_ status: NudgeStatus) -> String {
        switch status {
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .replied: return "Replied"
        case .dismissed: return "Dismissed"
        case .pending: return "Pending"
        case .requested: return "Requested"
        case .working: return "Working"
        }
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
