//
// AgentPendingRequests.swift
// AiyuTerm
//
// Phase 6.1 data layer: the request descriptors that WorkspaceModel
// exposes to its SwiftUI views, plus the decision enum that the
// sidebar bubble pushes back down into the mapper to resolve the
// blocking continuation.
//
// Intentionally does NOT carry a `CheckedContinuation` reference.
// Continuations are held by `AgentHookEventMapper` in a separate
// `[UUID: CheckedContinuation<Data, Never>]` dictionary so that
// WorkspaceModel's @Published state stays fully `Sendable` /
// `Equatable` / safely observable from SwiftUI. The request `id` is
// the coupling key between the two sides.
//

import Foundation

/// A Claude Code `PermissionRequest` hook observed by the mapper,
/// waiting for a UI decision. Held in
/// `WorkspaceModel.pendingPermissionRequests` keyed by worktree path.
struct AgentPermissionRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    /// Correlation id from Claude Code's `tool_use_id` field, resolved
    /// by `AgentHookServer` before dispatch. `nil` for events that
    /// lack a tool_use_id (tests, older bridge versions).
    let toolUseId: String?
    let sessionId: String
    let worktreePath: String
    let toolName: String
    /// Human-readable summary (e.g. "rm -rf /tmp/foo" for Bash)
    /// pulled from `AgentHookEvent.toolDescription`.
    let toolDescription: String?
    let timestamp: Date
}

/// A Claude Code `AskUserQuestion` or Notification-question hook.
/// Separate from `AgentPermissionRequest` because its UI affordance
/// is an options list, not an approve/deny pair.
struct AgentQuestionRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let sessionId: String
    let worktreePath: String
    let question: String
    let options: [String]?
    let header: String?
    let timestamp: Date
}

/// Decision the user makes on a pending permission request in the
/// sidebar bubble. `allowAlways` instructs the bridge to remember
/// the approval so subsequent identical tool calls auto-pass.
enum AgentPermissionDecision: Equatable, Sendable {
    case allowOnce
    case allowAlways
    case deny
}

/// Canonical JSON payloads the mapper returns to the bridge.
/// Extracted here so both the mapper and the tests can share the
/// exact byte sequences.
enum AgentPermissionResponseBuilder {
    static let allowOnce: Data = {
        Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}"#.utf8)
    }()

    static let deny: Data = {
        Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}"#.utf8)
    }()

    /// "Allow always" carries a small `updatedPermissions` array so
    /// Claude Code persists the approval across future sessions.
    /// Phase 6.3 will plumb the real rule through; for now we return
    /// an allow-once payload so the bridge completes cleanly.
    static let allowAlways: Data = {
        // TODO(Phase 6.3): emit a real updatedPermissions entry once
        // the sidebar bubble surfaces a rule editor. For now the
        // difference between allowOnce and allowAlways is only the
        // UI copy; the JSON is identical.
        Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}"#.utf8)
    }()

    static func response(for decision: AgentPermissionDecision) -> Data {
        switch decision {
        case .allowOnce: return allowOnce
        case .allowAlways: return allowAlways
        case .deny: return deny
        }
    }
}

/// Canonical "answer chosen" payload for the `AskUserQuestion`
/// flow. The bridge inserts the answer into `toolInput.answers`
/// before re-running the tool.
enum AgentQuestionResponseBuilder {
    /// Deny a question request (treat "skip" as deny). Used when
    /// the user dismisses the question bubble without answering.
    static let skip: Data = {
        Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}"#.utf8)
    }()

    /// Build an "allow with answer" payload. The exact shape lives
    /// in Phase 6.3; for Phase 6.1 we just embed the selected
    /// option as a top-level `answer` field so tests have something
    /// concrete to assert on.
    static func answer(_ option: String, header: String?) -> Data {
        var payload: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": ["behavior": "allow"],
            ],
        ]
        var answerEntry: [String: Any] = ["answer": option]
        if let header { answerEntry["header"] = header }
        payload["answers"] = [answerEntry]
        // JSONSerialization always produces bytes — no try? needed
        // because the payload is a fixed literal shape.
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? skip
    }
}
