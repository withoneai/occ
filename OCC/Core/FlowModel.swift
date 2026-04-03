import Foundation

struct Flow: Identifiable {
    let id: String           // key
    let name: String
    let description: String
    let platforms: [String]  // unique platform names, sorted
    let stepCount: Int
}

@MainActor
final class FlowStore: ObservableObject {
    @Published private(set) var flows: [Flow] = []
    @Published private(set) var allPlatforms: [String] = []
    private var lastRunDates: [String: Date] = [:]
    private var watchedFolderURLs: [URL] = []

    func lastRun(for flowId: String) -> Date? {
        lastRunDates[flowId]
    }

    func recordRun(for flowId: String) {
        lastRunDates[flowId] = Date()
    }

    func loadFlows(from watchedFolders: [URL]) {
        watchedFolderURLs = watchedFolders
        var allFlows: [Flow] = []
        var platformSet = Set<String>()

        for folder in watchedFolders {
            let flowsDir = folder.appendingPathComponent(".one/flows")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: flowsDir,
                includingPropertiesForKeys: nil
            ) else { continue }

            for file in files where file.pathExtension == "json" && file.lastPathComponent.hasSuffix(".flow.json") {
                if let flow = parseFlow(at: file) {
                    allFlows.append(flow)
                    platformSet.formUnion(flow.platforms)
                }
            }
        }

        flows = allFlows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        allPlatforms = platformSet.sorted()
    }

    private func parseFlow(at url: URL) -> Flow? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["key"] as? String,
              let name = json["name"] as? String else {
            return nil
        }

        let description = json["description"] as? String ?? ""

        var platforms = Set<String>()
        if let inputs = json["inputs"] as? [String: Any] {
            for (_, value) in inputs {
                if let input = value as? [String: Any],
                   let connection = input["connection"] as? [String: Any],
                   let platform = connection["platform"] as? String {
                    platforms.insert(platform)
                }
            }
        }

        let stepCount = countSteps(json["steps"] as? [[String: Any]] ?? [])

        return Flow(
            id: key,
            name: name,
            description: description,
            platforms: platforms.sorted(),
            stepCount: stepCount
        )
    }

    private func countSteps(_ steps: [[String: Any]]) -> Int {
        var count = 0
        for step in steps {
            count += 1
            if let parallel = step["parallel"] as? [String: Any],
               let nested = parallel["steps"] as? [[String: Any]] {
                count += nested.count
            }
        }
        return count
    }
}
