import Foundation

enum RequestWriter {
    static var watchedFolderPaths: [String: String] = [:]

    /// Writes a new .occ file as a request FROM the human TO the AI.
    /// The AI's cron job picks this up and works on it.
    static func sendRequest(_ message: String, toFolder folderName: String? = nil) {
        // Use the first watched folder if none specified
        guard let (name, path) = resolveFolder(folderName) else {
            print("[OCC] Cannot send request — no watched folders")
            return
        }

        let uniDir = (path as NSString).appendingPathComponent(".occ")
        try? FileManager.default.createDirectory(atPath: uniDir, withIntermediateDirectories: true)

        let timestamp = Int(Date().timeIntervalSince1970)
        let slug = message
            .prefix(30)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let filename = "\(timestamp)-\(slug).occ"
        let filePath = (uniDir as NSString).appendingPathComponent(filename)

        let isoTimestamp = ISO8601DateFormatter().string(from: Date())

        var content = "---\n"
        content += "title: \(String(message.prefix(60)))\n"
        content += "priority: medium\n"
        content += "status: requested\n"
        content += "next: ai\n"
        content += "created: \(isoTimestamp)\n"
        content += "from: human\n"
        content += "---\n"
        content += message + "\n"

        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("[OCC] Request sent: \(filename)")
        } catch {
            print("[OCC] Failed to write request: \(error)")
        }
    }

    private static func resolveFolder(_ name: String?) -> (String, String)? {
        if let name = name, let path = watchedFolderPaths[name] {
            return (name, path)
        }
        return watchedFolderPaths.first.map { ($0.key, $0.value) }
    }
}
