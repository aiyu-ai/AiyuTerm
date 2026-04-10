//
// AgentHookModels.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandCore/Models.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Shared data model for the AiyuTerm agent hook protocol. Types are
// renamed with `AgentHook` / `AgentSubagent` prefixes so that they don't
// collide with AiyuTerm's existing `AgentSessionStatus` enum, which
// remains the UI-facing contract.
//
// The types here intentionally mirror the original CodeIsland surface
// so that the reducer in AgentSessionSnapshot.swift ports cleanly. They
// are not public — the framework boundary inside AiyuTerm is not Swift
// module based, so internal access is enough.
//

import Foundation

/// Internal lifecycle status used by the hook-protocol reducer.
/// This is NOT the same as `AgentSessionStatus` (the UI contract);
/// it is mapped to that enum by `AgentHookEventMapper` (Phase 3).
enum AgentHookStatus: Equatable {
    case idle
    case processing
    case running
    case waitingApproval
    case waitingQuestion
}

/// A single hook event decoded from JSON that arrived over the
/// AgentHookServer socket. Because hook payloads are heterogeneous
/// across 9 different CLIs, we keep the raw dictionary around rather
/// than defining a Codable schema for every variant.
struct AgentHookEvent {
    let eventName: String
    let sessionId: String?
    let toolName: String?
    let agentId: String?
    let toolInput: [String: Any]?
    /// Full payload for event-specific fields (cwd, model, transcript_path, etc.)
    let rawJSON: [String: Any]

    init?(from data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventName = json["hook_event_name"] as? String
        else {
            return nil
        }
        self.eventName = eventName
        self.sessionId = json["session_id"] as? String
        self.toolName = json["tool_name"] as? String
        self.toolInput = json["tool_input"] as? [String: Any]
        self.agentId = json["agent_id"] as? String
        self.rawJSON = json
    }

    /// Convenience initializer used by tests. Lets tests pass a pre-built
    /// JSON dictionary without going through `JSONSerialization`.
    init(eventName: String,
         sessionId: String? = nil,
         toolName: String? = nil,
         agentId: String? = nil,
         toolInput: [String: Any]? = nil,
         rawJSON: [String: Any] = [:])
    {
        self.eventName = eventName
        self.sessionId = sessionId
        self.toolName = toolName
        self.agentId = agentId
        self.toolInput = toolInput
        var merged = rawJSON
        merged["hook_event_name"] = eventName
        if let sessionId { merged["session_id"] = sessionId }
        if let toolName { merged["tool_name"] = toolName }
        if let agentId { merged["agent_id"] = agentId }
        if let toolInput { merged["tool_input"] = toolInput }
        self.rawJSON = merged
    }

    /// A short human-readable description of the tool call this event
    /// represents, used for sidebar badges and notch panel rows. The
    /// logic walks the tool input payload tool-by-tool because every
    /// CLI has its own conventions.
    var toolDescription: String? {
        if let input = toolInput {
            switch toolName {
            case "Bash":
                if let desc = input["description"] as? String, !desc.isEmpty { return desc }
                if let cmd = input["command"] as? String {
                    let line = cmd.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? cmd
                    return String(line.prefix(60))
                }
            case "Read":
                if let fp = input["file_path"] as? String {
                    let name = (fp as NSString).lastPathComponent
                    if let offset = input["offset"] as? Int {
                        return "\(name):\(offset)"
                    }
                    return name
                }
            case "Edit":
                if let fp = input["file_path"] as? String {
                    return (fp as NSString).lastPathComponent
                }
            case "Write":
                if let fp = input["file_path"] as? String {
                    return (fp as NSString).lastPathComponent
                }
            case "Grep":
                if let pattern = input["pattern"] as? String {
                    let path = (input["path"] as? String).map { " in \(($0 as NSString).lastPathComponent)" } ?? ""
                    return "\(pattern)\(path)"
                }
            case "Glob":
                if let pattern = input["pattern"] as? String { return pattern }
            case "WebSearch":
                if let query = input["query"] as? String { return query }
            case "WebFetch":
                if let url = input["url"] as? String {
                    if let host = URL(string: url)?.host { return host }
                    return String(url.prefix(40))
                }
            case "Task", "Agent":
                if let desc = input["description"] as? String, !desc.isEmpty { return desc }
                if let prompt = input["prompt"] as? String { return String(prompt.prefix(40)) }
            case "TodoWrite":
                return "Updating tasks"
            default:
                if let fp = input["file_path"] as? String { return (fp as NSString).lastPathComponent }
                if let pattern = input["pattern"] as? String { return pattern }
                if let command = input["command"] as? String { return String(command.prefix(60)) }
                if let prompt = input["prompt"] as? String { return String(prompt.prefix(40)) }
            }
        }
        if let msg = rawJSON["message"] as? String { return msg }
        if let agentType = rawJSON["agent_type"] as? String { return agentType }
        if let prompt = rawJSON["prompt"] as? String { return String(prompt.prefix(40)) }
        return nil
    }
}

/// Lightweight state of a subagent (nested agent call). Mirrors
/// CodeIsland's SubagentState exactly — the reducer depends on this
/// shape.
struct AgentSubagentState {
    let agentId: String
    let agentType: String
    var status: AgentHookStatus = .running
    var currentTool: String?
    var toolDescription: String?
    var startTime: Date = Date()
    var lastActivity: Date = Date()

    init(agentId: String, agentType: String) {
        self.agentId = agentId
        self.agentType = agentType
    }
}

/// A single past tool invocation kept in the per-session history ring.
struct AgentToolHistoryEntry: Identifiable {
    let id = UUID()
    let tool: String
    let description: String?
    let timestamp: Date
    let success: Bool
    /// nil = main thread; non-nil = subagent of the given type.
    let agentType: String?

    init(tool: String, description: String?, timestamp: Date, success: Bool, agentType: String?) {
        self.tool = tool
        self.description = description
        self.timestamp = timestamp
        self.success = success
        self.agentType = agentType
    }
}

/// Chat-style entry used by the optional Phase 6 message-scrollback UI.
struct AgentChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String

    init(isUser: Bool, text: String) {
        self.isUser = isUser
        self.text = text
    }
}

/// Structured question payload extracted from Notification events or
/// Claude Code's `AskUserQuestion` tool.
struct AgentQuestionPayload {
    let question: String
    let options: [String]?
    let descriptions: [String]?
    let header: String?

    init(question: String,
         options: [String]?,
         descriptions: [String]? = nil,
         header: String? = nil)
    {
        self.question = question
        self.options = options
        self.descriptions = descriptions
        self.header = header
    }

    /// Try to extract a question payload from a Notification event.
    /// Intentionally conservative: requires an explicit `"question"` key
    /// in the raw JSON. We do NOT use any "ends with ?" heuristic
    /// because normal status text can trip it up and stall the hook.
    static func from(event: AgentHookEvent) -> AgentQuestionPayload? {
        if let question = event.rawJSON["question"] as? String {
            let options = event.rawJSON["options"] as? [String]
            return AgentQuestionPayload(question: question, options: options)
        }
        return nil
    }
}
