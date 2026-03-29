import Foundation

enum ReplyWriter {
    static var watchedFolderPaths: [String: String] = [:]

    /// Updates the original .uni file in place:
    /// 1. Changes `status` and `next: ai` in the frontmatter
    /// 2. Appends a `---reply [human] timestamp---` block with the user's message
    static func writeReply(for nudge: Nudge, status: NudgeStatus, message: String?) {
        guard let sourceFile = nudge.sourceFile,
              let sourceFolder = nudge.sourceFolder else {
            print("[OCC] Cannot reply — no source info on nudge")
            return
        }

        guard let folderPath = watchedFolderPaths[sourceFolder] else {
            print("[OCC] Cannot reply — folder '\(sourceFolder)' not in watched list")
            return
        }

        let uniDir = (folderPath as NSString).appendingPathComponent(".uni")
        let filePath = (uniDir as NSString).appendingPathComponent(sourceFile)

        // Read the current file content
        guard var content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("[OCC] Cannot read source file: \(sourceFile)")
            return
        }

        // Update frontmatter: status and next
        content = updateFrontmatter(content, key: "status", value: status.rawValue)
        content = updateFrontmatter(content, key: "next", value: "ai")
        content = updateFrontmatter(content, key: "updated", value: ISO8601DateFormatter().string(from: Date()))

        // Append the reply block
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var replyBlock = "\n\n---reply [human] \(timestamp)---\n"
        if let message = message, !message.isEmpty {
            replyBlock += message
        } else {
            replyBlock += "[\(status.rawValue)]"
        }
        content += replyBlock

        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("[OCC] Updated \(sourceFile) — status: \(status.rawValue)")

            // Archive rejected/dismissed conversations (approved stays for the AI to act on)
            if status == .rejected || status == .dismissed {
                archiveFile(filePath: filePath, uniDir: uniDir, fileName: sourceFile)
            }
        } catch {
            print("[OCC] Failed to update file: \(error)")
        }
    }

    private static func archiveFile(filePath: String, uniDir: String, fileName: String) {
        let archiveDir = (uniDir as NSString).appendingPathComponent("archive")
        let fm = FileManager.default

        try? fm.createDirectory(atPath: archiveDir, withIntermediateDirectories: true)

        let dest = (archiveDir as NSString).appendingPathComponent(fileName)
        try? fm.removeItem(atPath: dest)

        do {
            try fm.moveItem(atPath: filePath, toPath: dest)
            print("[OCC] Archived \(fileName)")
        } catch {
            print("[OCC] Failed to archive: \(error)")
        }
    }

    private static func updateFrontmatter(_ content: String, key: String, value: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var inFrontmatter = false
        var foundKey = false
        var passedFrontmatter = false

        for (i, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if !inFrontmatter && i == 0 {
                    inFrontmatter = true
                    result.append(line)
                    continue
                } else if inFrontmatter {
                    // End of frontmatter — insert key if not found
                    if !foundKey {
                        result.append("\(key): \(value)")
                    }
                    inFrontmatter = false
                    passedFrontmatter = true
                    result.append(line)
                    continue
                }
            }

            if inFrontmatter && line.lowercased().hasPrefix("\(key):") {
                result.append("\(key): \(value)")
                foundKey = true
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}
