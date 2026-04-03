import Foundation

enum NudgePriority: String, Codable {
    case low
    case medium
    case high
}

enum NudgeStatus: String, Codable {
    case pending
    case requested
    case working
    case approved
    case rejected
    case replied
    case dismissed
    case done
}

struct NudgeReply: Identifiable, Codable {
    let id: UUID
    let sender: String    // "human" or "ai"
    let timestamp: String
    let message: String

    init(sender: String, timestamp: String, message: String) {
        self.id = UUID()
        self.sender = sender
        self.timestamp = timestamp
        self.message = message
    }

    var isHuman: Bool { sender == "human" }
}

struct NudgeButtons: Codable {
    let primary: String    // Left button (positive action), e.g. "Approve", "Yes", "Ship"
    let secondary: String  // Right button (negative action), e.g. "Reject", "No", "Hold"

    static let `default` = NudgeButtons(primary: "Approve", secondary: "Reject")
}

struct Nudge: Identifiable, Codable {
    let id: UUID
    let type: String
    let title: String
    let body: String?
    let priority: NudgePriority
    let timestamp: Date
    let url: URL?
    let action: String?
    let sourceFolder: String?
    let sourceFile: String?
    let from: String?          // "human" or "ai" — who initiated the conversation
    var status: NudgeStatus
    var replies: [NudgeReply]
    let buttons: NudgeButtons

    /// True if this nudge is a reply to something the human initiated
    var isReplyToHuman: Bool { from == "human" }

    init(
        id: UUID = UUID(),
        type: String = "nudge",
        title: String,
        body: String? = nil,
        priority: NudgePriority = .medium,
        timestamp: Date = Date(),
        url: URL? = nil,
        action: String? = nil,
        sourceFolder: String? = nil,
        sourceFile: String? = nil,
        from: String? = nil,
        status: NudgeStatus = .pending,
        replies: [NudgeReply] = [],
        buttons: NudgeButtons = .default
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.priority = priority
        self.timestamp = timestamp
        self.url = url
        self.action = action
        self.sourceFolder = sourceFolder
        self.sourceFile = sourceFile
        self.from = from
        self.status = status
        self.replies = replies
        self.buttons = buttons
    }
}
