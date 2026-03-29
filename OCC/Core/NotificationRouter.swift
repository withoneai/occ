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
    private var autoDismissTask: Task<Void, Never>?

    var currentPriority: NudgePriority {
        currentNudge?.priority ?? activeNudges.first?.priority ?? .medium
    }

    var currentNudge: Nudge? {
        guard !activeNudges.isEmpty, currentIndex < activeNudges.count else { return nil }
        return activeNudges[currentIndex]
    }

    func push(_ nudge: Nudge) {
        print("[OCC] Push nudge: \(nudge.title) — state=\(state), active=\(activeNudges.count)")
        activeNudges.insert(nudge, at: 0)
        currentIndex = 0
        state = .active
        startAutoDismissTimer()
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
