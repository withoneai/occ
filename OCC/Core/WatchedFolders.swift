import Foundation
import Combine

@MainActor
final class WatchedFolders: ObservableObject {
    @Published private(set) var folders: [URL] = []

    private static let key = "occ.watched.folders.bookmarks"

    init() {
        loadBookmarks()
    }

    func add(_ url: URL) {
        guard !folders.contains(url) else { return }

        // Store security-scoped bookmark for persistence across launches
        guard url.startAccessingSecurityScopedResource() || true else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = savedBookmarks()
            bookmarks.append(bookmark)
            UserDefaults.standard.set(bookmarks, forKey: Self.key)
            folders.append(url)
        } catch {
            // Fallback: store path directly (works for non-sandboxed apps)
            var bookmarks = savedBookmarks()
            if let data = url.path.data(using: .utf8) {
                bookmarks.append(data)
                UserDefaults.standard.set(bookmarks, forKey: Self.key)
                folders.append(url)
            }
        }
    }

    func remove(_ url: URL) {
        guard let index = folders.firstIndex(of: url) else { return }
        folders.remove(at: index)

        var bookmarks = savedBookmarks()
        if index < bookmarks.count {
            bookmarks.remove(at: index)
            UserDefaults.standard.set(bookmarks, forKey: Self.key)
        }
    }

    private func loadBookmarks() {
        for data in savedBookmarks() {
            // Try as security-scoped bookmark first
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                folders.append(url)
            } else if let path = String(data: data, encoding: .utf8) {
                // Fallback: plain path
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    folders.append(url)
                }
            }
        }
    }

    private func savedBookmarks() -> [Data] {
        UserDefaults.standard.array(forKey: Self.key) as? [Data] ?? []
    }
}
