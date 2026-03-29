import Foundation
import Network

/// Listens on a Unix domain socket for JSON nudge messages from external processes.
/// Protocol: one JSON object per newline-delimited message.
/// Example: {"type":"nudge","title":"Meeting in 5m","body":"Standup","priority":"high"}
final class CLIBridge: @unchecked Sendable {
    private let router: NotificationRouter
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.occ.cli-bridge")

    static let socketPath: String = {
        let dir = NSHomeDirectory() + "/.occ"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/occ.sock"
    }()

    init(router: NotificationRouter) {
        self.router = router
    }

    func start() {
        let path = Self.socketPath
        try? FileManager.default.removeItem(atPath: path)

        do {
            let params = NWParameters()
            params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
            params.requiredLocalEndpoint = NWEndpoint.unix(path: path)

            let listener = try NWListener(using: params)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[OCC] Socket listening at \(path)")
                case .failed(let error):
                    print("[OCC] Socket listener failed: \(error)")
                default:
                    break
                }
            }

            listener.start(queue: queue)
        } catch {
            print("[OCC] Failed to create socket listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        try? FileManager.default.removeItem(atPath: Self.socketPath)
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                self?.connections.removeAll { $0 === connection }
            }
        }

        connection.start(queue: queue)
        receiveData(on: connection, buffer: Data())
    }

    private func receiveData(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var buffer = buffer
            if let data {
                buffer.append(data)

                while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let messageData = buffer[buffer.startIndex..<newlineIndex]
                    buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                    if let nudge = self.parseNudge(from: Data(messageData)) {
                        let router = self.router
                        Task { @MainActor in
                            router.push(nudge)
                        }
                    }
                }
            }

            if isComplete || error != nil {
                if !buffer.isEmpty, let nudge = self.parseNudge(from: buffer) {
                    let router = self.router
                    Task { @MainActor in
                        router.push(nudge)
                    }
                }
                connection.cancel()
            } else {
                self.receiveData(on: connection, buffer: buffer)
            }
        }
    }

    private func parseNudge(from data: Data) -> Nudge? {
        struct IncomingNudge: Decodable {
            let type: String?
            let title: String
            let body: String?
            let priority: String?
        }

        guard let incoming = try? JSONDecoder().decode(IncomingNudge.self, from: data) else {
            print("[OCC] Failed to parse nudge JSON")
            return nil
        }

        let priority = NudgePriority(rawValue: incoming.priority ?? "medium") ?? .medium
        return Nudge(
            type: incoming.type ?? "nudge",
            title: incoming.title,
            body: incoming.body,
            priority: priority
        )
    }
}
