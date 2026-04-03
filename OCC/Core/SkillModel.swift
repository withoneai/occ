import Foundation

struct Skill: Identifiable {
    let id: String           // folder name
    let name: String
    let description: String
    let triggers: [String]

    /// The slash command trigger (e.g., "/gmail-draft"), if any
    var slashCommand: String? {
        triggers.first { $0.hasPrefix("/") }
    }
}

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [Skill] = []

    func loadSkills(from watchedFolders: [URL]) {
        var allSkills: [Skill] = []

        for folder in watchedFolders {
            let skillsDir = folder.appendingPathComponent(".claude/skills")
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: skillsDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { continue }

            for entry in entries {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir),
                      isDir.boolValue else { continue }

                if let skill = parseSkill(at: entry) {
                    allSkills.append(skill)
                }
            }
        }

        skills = allSkills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        print("[OCC] Loaded \(skills.count) skills from \(watchedFolders.count) folders")
        for skill in skills.prefix(3) {
            print("[OCC]   - \(skill.name): \(skill.description)")
        }
    }

    private func parseSkill(at dir: URL) -> Skill? {
        let skillFile = dir.appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }

        let folderId = dir.lastPathComponent

        // Try parsing YAML frontmatter
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            // No frontmatter — extract title from first heading
            let title = extractTitle(from: content) ?? folderId
            return Skill(id: folderId, name: title, description: "", triggers: [])
        }

        let afterOpening = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let rest = String(trimmed[afterOpening...]).trimmingCharacters(in: .newlines)
        guard let closingRange = rest.range(of: "\n---") else {
            return Skill(id: folderId, name: folderId, description: "", triggers: [])
        }

        let frontmatter = String(rest[rest.startIndex..<closingRange.lowerBound])

        var name = folderId
        var description = ""
        var triggers: [String] = []
        var inTriggers = false

        for line in frontmatter.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if inTriggers {
                if trimmedLine.hasPrefix("- ") {
                    let value = String(trimmedLine.dropFirst(2))
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    triggers.append(value)
                    continue
                } else {
                    inTriggers = false
                }
            }

            if trimmedLine.lowercased().hasPrefix("name:") {
                name = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmedLine.lowercased().hasPrefix("description:") {
                description = String(trimmedLine.dropFirst(12))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            } else if trimmedLine.lowercased().hasPrefix("triggers:") {
                inTriggers = true
            }
        }

        // Humanize the name: "gmail-draft" → "Gmail Draft"
        if name == folderId {
            name = folderId
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }

        return Skill(id: folderId, name: name, description: description, triggers: triggers)
    }

    private func extractTitle(from content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
