import Foundation

final class FolderWatcher: @unchecked Sendable {
    private let router: NotificationRouter
    private var watchers: [URL: DirectoryWatch] = [:]
    private let queue = DispatchQueue(label: "com.occ.folder-watcher")
    private var pollTimer: DispatchSourceTimer?

    private struct DirectoryWatch {
        let source: DispatchSourceFileSystemObject
        let fileDescriptor: Int32
        var knownHashes: [String: Int]
    }

    init(router: NotificationRouter) {
        self.router = router
    }

    func watch(_ folderURL: URL) {
        guard watchers[folderURL] == nil else { return }

        let uniDirURL = uniDir(in: folderURL)
        let path = uniDirURL.path

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("[OCC] Failed to open directory for watching: \(path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        watchers[folderURL] = DirectoryWatch(
            source: source,
            fileDescriptor: fd,
            knownHashes: [:]
        )

        // Initial scan
        scanAndProcess(folderURL: folderURL)

        // DispatchSource catches new/deleted files
        source.setEventHandler { [weak self] in
            self?.queue.asyncAfter(deadline: .now() + 0.15) {
                self?.scanAndProcess(folderURL: folderURL)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()

        // Start polling timer to catch file CONTENT changes (status updates by the AI)
        startPolling()

        print("[OCC] Watching \(path) for .occ files")
    }

    func unwatch(_ folderURL: URL) {
        guard let watch = watchers.removeValue(forKey: folderURL) else { return }
        watch.source.cancel()
        if watchers.isEmpty { stopPolling() }
        print("[OCC] Stopped watching \(folderURL.path)")
    }

    func stopAll() {
        for (_, watch) in watchers {
            watch.source.cancel()
        }
        watchers.removeAll()
        stopPolling()
    }

    // MARK: - Polling for file content changes

    private func startPolling() {
        guard pollTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            for folderURL in self.watchers.keys {
                self.scanAndProcess(folderURL: folderURL)
            }
        }
        timer.resume()
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    // MARK: - Scanning

    private func scanAndProcess(folderURL: URL) {
        guard var watch = watchers[folderURL] else { return }

        let files = scanUniFiles(in: folderURL)

        // Clean up hashes for deleted files
        let currentNames = Set(files.map { $0.lastPathComponent })
        for name in watch.knownHashes.keys where !currentNames.contains(name) {
            watch.knownHashes.removeValue(forKey: name)
        }
        watchers[folderURL] = watch

        var requestedCount = 0
        var workingCount = 0

        for fileURL in files {
            let name = fileURL.lastPathComponent
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let hash = content.hashValue

            // Track AI-side statuses — any file where next=ai means AI is busy
            if let raw = OCCFileParser.parseRaw(content: content) {
                let next = raw.frontmatter["next"] ?? "human"
                let status = raw.frontmatter["status"] ?? "pending"
                if next == "ai" {
                    if status == "working" {
                        workingCount += 1
                    } else {
                        requestedCount += 1
                    }
                }
            }

            // Skip if content hasn't changed since last check
            if watch.knownHashes[name] == hash { continue }
            watch.knownHashes[name] = hash
            watchers[folderURL] = watch

            let folderName = folderURL.lastPathComponent
            let nudge = OCCFileParser.parse(content: content, sourceFolder: folderName, sourceFile: name)

            // Single Task to ensure fileChanged runs before push
            let router = self.router
            Task { @MainActor in
                router.fileChanged(name)
                if let nudge {
                    router.push(nudge)
                }
            }
        }

        // Update status indicators
        let router = self.router
        Task { @MainActor in
            router.requestedCount = requestedCount
            router.workingCount = workingCount
        }
    }

    private func uniDir(in folder: URL) -> URL {
        let dir = folder.appendingPathComponent(".occ")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func scanUniFiles(in folder: URL) -> [URL] {
        let dir = uniDir(in: folder)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "occ" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
