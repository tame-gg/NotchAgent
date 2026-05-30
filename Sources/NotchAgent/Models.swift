import Foundation
import NotchAgentCore

struct TimelineEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let sessionId: String
    let source: String
    let project: String
    let eventName: String
    let title: String
    let detail: String?
    let toolName: String?
    let risk: String?
    let decision: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: String,
        source: String,
        project: String,
        eventName: String,
        title: String,
        detail: String? = nil,
        toolName: String? = nil,
        risk: String? = nil,
        decision: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.source = source
        self.project = project
        self.eventName = eventName
        self.title = title
        self.detail = detail
        self.toolName = toolName
        self.risk = risk
        self.decision = decision
    }
}

struct SessionMetrics: Identifiable, Equatable {
    let id: String
    let project: String
    let source: String
    let status: AgentStatus
    let toolCallCount: Int
    let approvalCount: Int
    let deniedApprovalCount: Int
    let elapsedSeconds: TimeInterval
    let lastActivity: Date
}

struct ApprovalRule: Identifiable, Codable, Equatable {
    enum Decision: String, Codable, CaseIterable {
        case allow
        case deny
    }

    var id: UUID
    var enabled: Bool
    var name: String
    var toolName: String
    var commandContains: String
    var cwdContains: String
    var source: String
    var decision: Decision

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        name: String,
        toolName: String = "",
        commandContains: String = "",
        cwdContains: String = "",
        source: String = "",
        decision: Decision = .allow
    ) {
        self.id = id
        self.enabled = enabled
        self.name = name
        self.toolName = toolName
        self.commandContains = commandContains
        self.cwdContains = cwdContains
        self.source = source
        self.decision = decision
    }

    var summary: String {
        var parts: [String] = []
        if !toolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("tool=\(toolName)")
        }
        if !commandContains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("command contains \(commandContains)")
        }
        if !cwdContains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("cwd contains \(cwdContains)")
        }
        if !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("source=\(source)")
        }
        return parts.isEmpty ? "matches every approval" : parts.joined(separator: " · ")
    }

    func matches(event: HookEvent) -> Bool {
        guard enabled else { return false }
        if !matchesNeedle(toolName, value: event.toolName) { return false }
        if !matchesNeedle(source, value: event.rawJSON["_source"] as? String) { return false }
        if !matchesNeedle(cwdContains, value: event.rawJSON["cwd"] as? String) { return false }
        if !matchesNeedle(commandContains, value: Self.commandText(from: event)) { return false }
        return true
    }

    static func commandText(from event: HookEvent) -> String {
        let keys = ["command", "cmd", "script", "path", "file_path", "filePath"]
        for key in keys {
            if let value = event.toolInput?[key] as? String, !value.isEmpty {
                return value
            }
        }
        return event.toolDescription ?? ""
    }

    private func matchesNeedle(_ needle: String, value: String?) -> Bool {
        let trimmed = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return (value ?? "").range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

enum ApprovalPreview {
    static func commandSummary(for event: HookEvent) -> String {
        let command = ApprovalRule.commandText(from: event)
        if !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return command
        }
        return event.toolName ?? "Approval request"
    }

    static func risk(for event: HookEvent) -> String {
        let haystack = "\(event.toolName ?? "") \(commandSummary(for: event))".lowercased()
        let highRisk = ["rm ", "sudo ", "chmod ", "chown ", "curl ", "wget ", "security ", "defaults write", "launchctl"]
        if highRisk.contains(where: { haystack.contains($0) }) {
            return "high"
        }
        let mediumRisk = ["git ", "mv ", "cp ", "python ", "node ", "npm ", "swift ", "xcodebuild"]
        if mediumRisk.contains(where: { haystack.contains($0) }) {
            return "medium"
        }
        return "low"
    }
}

struct PermissionRequest {
    let event: HookEvent
    let continuation: CheckedContinuation<Data, Never>

    var toolUseId: String? { event.toolUseId }
    var commandSummary: String { ApprovalPreview.commandSummary(for: event) }
    var risk: String { ApprovalPreview.risk(for: event) }
}

struct AskUserQuestionItem {
    let payload: QuestionPayload
    let answerKey: String
    let multiSelect: Bool
}

struct AskUserQuestionState {
    let items: [AskUserQuestionItem]
    var answers: [String: String]

    var canConfirm: Bool {
        items.allSatisfy { answers[$0.answerKey] != nil }
    }

    mutating func select(questionIndex: Int, option: String) {
        guard items.indices.contains(questionIndex) else { return }
        answers[items[questionIndex].answerKey] = option
    }
}

struct QuestionRequest {
    let event: HookEvent
    let question: QuestionPayload
    let continuation: CheckedContinuation<Data, Never>
    /// true when converted from AskUserQuestion PermissionRequest
    let isFromPermission: Bool
    var askUserQuestionState: AskUserQuestionState?

    init(event: HookEvent, question: QuestionPayload, continuation: CheckedContinuation<Data, Never>, isFromPermission: Bool = false, askUserQuestionState: AskUserQuestionState? = nil) {
        self.event = event
        self.question = askUserQuestionState?.items.first?.payload ?? question
        self.continuation = continuation
        self.isFromPermission = isFromPermission
        self.askUserQuestionState = askUserQuestionState
    }
}
