import Foundation
import Combine

enum PillState: Equatable {
    case idle
    case active
    case expanded
    case input       // User is typing a request to the AI
}

@MainActor
final class NotificationRouter: ObservableObject {
    @Published private(set) var state: PillState = .idle
    @Published private(set) var activeNudges: [Nudge] = []
    @Published private(set) var history: [Nudge] = []
    @Published var requestedCount: Int = 0
    @Published var workingCount: Int = 0

    @Published var currentIndex: Int = 0
    @Published var showingFlows: Bool = false
    private var autoDismissTask: Task<Void, Never>?

    /// Tracks sourceFiles we've already handled (active, responded, or dismissed)
    /// to prevent the same file from being pushed again on re-scan.
    private var handledFiles: Set<String> = []

    var currentPriority: NudgePriority {
        currentNudge?.priority ?? activeNudges.first?.priority ?? .medium
    }

    var currentNudge: Nudge? {
        guard !activeNudges.isEmpty, currentIndex < activeNudges.count else { return nil }
        return activeNudges[currentIndex]
    }

    func push(_ nudge: Nudge) {
        // Deduplicate: skip if this source file is already active or was recently handled
        if let file = nudge.sourceFile {
            if handledFiles.contains(file) { return }
            if activeNudges.contains(where: { $0.sourceFile == file }) { return }
            handledFiles.insert(file)
        }

        print("[OCC] Push nudge: \(nudge.title) [from=\(nudge.from ?? "unknown"), replies=\(nudge.replies.count), body=\(nudge.body?.prefix(30) ?? "nil")] — state=\(state), active=\(activeNudges.count)")
        activeNudges.insert(nudge, at: 0)
        currentIndex = 0
        state = .active
        startAutoDismissTimer()
    }

    /// Called when a file changes on disk (e.g. AI updates it).
    /// Allows re-evaluation of a previously handled file.
    /// Called immediately when the user sends a request, before the file watcher picks it up.
    func markRequestSent() {
        requestedCount = max(requestedCount, 1)
    }

    func fileChanged(_ sourceFile: String) {
        handledFiles.remove(sourceFile)
    }

    func expand() {
        guard !activeNudges.isEmpty else { return }
        autoDismissTask?.cancel()
        state = .expanded
    }

    func showInput() {
        autoDismissTask?.cancel()
        state = .input
    }

    func collapse() {
        if !activeNudges.isEmpty {
            state = .active
        } else {
            state = .idle
        }
    }

    func dismiss() {
        autoDismissTask?.cancel()
        for nudge in activeNudges {
            var dismissed = nudge
            if dismissed.status == .pending { dismissed.status = .dismissed }
            history.insert(dismissed, at: 0)

            // Write dismissal to disk so it doesn't re-appear
            if dismissed.status == .dismissed {
                ReplyWriter.writeReply(for: nudge, status: .dismissed, message: nil)
            }
        }
        if history.count > 50 { history = Array(history.prefix(50)) }
        activeNudges.removeAll()
        state = .idle
    }

    func dismissSingle(_ nudge: Nudge) {
        var dismissed = nudge
        if dismissed.status == .pending { dismissed.status = .dismissed }
        history.insert(dismissed, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        activeNudges.removeAll { $0.id == nudge.id }

        // Write dismissal to disk so it doesn't re-appear
        if dismissed.status == .dismissed {
            ReplyWriter.writeReply(for: nudge, status: .dismissed, message: nil)
        }

        if activeNudges.isEmpty {
            autoDismissTask?.cancel()
            state = .idle
        }
    }

    func respond(to nudge: Nudge, status: NudgeStatus, message: String? = nil) {
        if let index = activeNudges.firstIndex(where: { $0.id == nudge.id }) {
            activeNudges[index].status = status
        }

        ReplyWriter.writeReply(for: nudge, status: status, message: message)

        var responded = nudge
        responded.status = status
        history.insert(responded, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        activeNudges.removeAll { $0.id == nudge.id }

        if currentIndex >= activeNudges.count {
            currentIndex = max(0, activeNudges.count - 1)
        }

        if activeNudges.isEmpty {
            autoDismissTask?.cancel()
            currentIndex = 0
            state = .idle
        }
    }

    func navigateNext() {
        guard currentIndex < activeNudges.count - 1 else { return }
        currentIndex += 1
    }

    func navigatePrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func startAutoDismissTimer() {
        autoDismissTask?.cancel()
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.state == .active {
                self.state = .idle
            }
        }
    }
}
