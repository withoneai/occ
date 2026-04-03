import Foundation

struct ParsedOCCFile {
    let frontmatter: [String: String]
    let body: String
    let replies: [Reply]

    struct Reply {
        let sender: String   // "human" or "ai"
        let timestamp: String
        let message: String
    }
}

enum OCCFileParser {
    /// Parses a `.occ` nudge file with frontmatter, body, and reply thread.
    ///
    /// Format:
    /// ```
    /// ---
    /// title: Short title
    /// priority: high
    /// status: pending
    /// next: human
    /// created: 2026-03-27T19:30:00Z
    /// url: https://example.com
    /// action: Open PR
    /// ---
    /// Body text here.
    ///
    /// ---reply [human] 2026-03-27T19:35:00Z---
    /// Response text here.
    ///
    /// ---reply [ai] 2026-03-27T19:36:00Z---
    /// Follow-up text here.
    /// ```
    static func parse(content: String, sourceFolder: String? = nil, sourceFile: String? = nil) -> Nudge? {
        guard let parsed = parseRaw(content: content) else { return nil }

        guard let title = parsed.frontmatter["title"], !title.isEmpty else { return nil }

        // Only show nudges where next = human (or no next field = new nudge)
        let next = parsed.frontmatter["next"] ?? "human"
        guard next == "human" else { return nil }

        // Skip already completed conversations
        let status = parsed.frontmatter["status"] ?? "pending"
        guard status == "pending" || status == "replied" || status == "done" else { return nil }

        let nudgeStatus = NudgeStatus(rawValue: status) ?? .pending
        let priority = NudgePriority(rawValue: parsed.frontmatter["priority"] ?? "medium") ?? .medium
        let url = parsed.frontmatter["url"].flatMap { URL(string: $0) }
        let action = parsed.frontmatter["action"]
        let from = parsed.frontmatter["from"] // "human" or "ai"

        let displayBody = parsed.body.isEmpty ? nil : parsed.body

        // Parse custom buttons: "buttons: Ship | Hold" → primary="Ship", secondary="Hold"
        let buttons: NudgeButtons
        if let buttonsStr = parsed.frontmatter["buttons"],
           buttonsStr.contains("|") {
            let parts = buttonsStr.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 && !parts[0].isEmpty && !parts[1].isEmpty {
                buttons = NudgeButtons(primary: parts[0], secondary: parts[1])
            } else {
                buttons = .default
            }
        } else {
            buttons = .default
        }

        let nudgeReplies = parsed.replies.map {
            NudgeReply(sender: $0.sender, timestamp: $0.timestamp, message: $0.message)
        }

        return Nudge(
            title: title,
            body: displayBody,
            priority: priority,
            url: url,
            action: action,
            sourceFolder: sourceFolder,
            sourceFile: sourceFile,
            from: from,
            status: nudgeStatus,
            replies: nudgeReplies,
            buttons: buttons
        )
    }

    static func parseRaw(content: String) -> ParsedOCCFile? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return nil }

        let afterOpening = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let rest = String(trimmed[afterOpening...]).trimmingCharacters(in: .newlines)

        guard let closingRange = rest.range(of: "\n---") else { return nil }

        let frontmatterStr = String(rest[rest.startIndex..<closingRange.lowerBound])
        let afterFrontmatter = String(rest[rest.index(closingRange.upperBound, offsetBy: 0)...])
            .trimmingCharacters(in: .newlines)

        // Parse frontmatter
        var fields: [String: String] = [:]
        for line in frontmatterStr.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            guard let colonIndex = trimmedLine.firstIndex(of: ":") else { continue }

            let key = String(trimmedLine[trimmedLine.startIndex..<colonIndex])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)

            fields[key] = value
        }

        // Split body and replies on ---reply markers
        let parts = afterFrontmatter.components(separatedBy: "\n---reply ")
        let body = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var replies: [ParsedOCCFile.Reply] = []
        for part in parts.dropFirst() {
            // Parse: [human] 2026-03-27T19:35:00Z---\nMessage
            guard let headerEnd = part.range(of: "---") else { continue }
            let header = String(part[part.startIndex..<headerEnd.lowerBound]).trimmingCharacters(in: .whitespaces)
            let message = String(part[headerEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse [sender] timestamp
            var sender = "human"
            var timestamp = ""

            if let bracketOpen = header.firstIndex(of: "["),
               let bracketClose = header.firstIndex(of: "]") {
                sender = String(header[header.index(after: bracketOpen)..<bracketClose])
                timestamp = String(header[header.index(after: bracketClose)...]).trimmingCharacters(in: .whitespaces)
            }

            replies.append(ParsedOCCFile.Reply(sender: sender, timestamp: timestamp, message: message))
        }

        return ParsedOCCFile(frontmatter: fields, body: body, replies: replies)
    }
}
