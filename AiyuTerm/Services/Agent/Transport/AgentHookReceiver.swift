//
// AgentHookReceiver.swift
// AiyuTerm
//
// Inspired by the AppState callback surface used by CodeIsland's
// HookServer (CodeIsland/HookServer.swift:106-160). AiyuTerm does not
// vendor CodeIsland's monolithic AppState; instead we define a small
// protocol that WorkspaceStore (or a test double) can implement to
// receive decoded hook events from AgentHookServer.
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//

import Foundation

/// Implemented by the component that owns AiyuTerm's agent state (the
/// `WorkspaceStore` in production, a test double in unit tests) and
/// consumes events delivered by `AgentHookServer`.
///
/// Phase 2 semantics:
///   - `handleEvent` is fire-and-forget. AgentHookServer replies to
///     the bridge with an empty JSON object `{}` without waiting.
///   - The three blocking callbacks (permission / ask-user-question /
///     free-form question) return a `Data` payload which is written
///     back to the bridge verbatim. The blob must be a valid JSON
///     object that Claude Code understands, e.g.
///     `{"hookSpecificOutput":{"hookEventName":"PermissionRequest",
///       "decision":{"behavior":"allow"}}}`.
///   - `handlePeerDisconnect` fires when the bridge process closes
///     the socket before we've written our response — typically the
///     user killed Claude Code mid-prompt. Implementers should drain
///     any pending UI state for the given session.
///
/// All callbacks are invoked on `MainActor`. Implementers do not need
/// to hop actors themselves; they just mutate state directly.
@MainActor
protocol AgentHookReceiver: AnyObject {
    /// Fire-and-forget event delivery (UserPromptSubmit, Stop, PreToolUse,
    /// PostToolUse, SessionStart, SessionEnd, PreCompact, ...).
    func handleEvent(_ event: AgentHookEvent)

    /// Blocking permission request from the Claude Code `PermissionRequest`
    /// hook. Return the JSON `Data` payload that should be sent back to
    /// the bridge. AgentHookServer keeps the socket open until you return.
    func handlePermissionRequest(_ event: AgentHookEvent) async -> Data

    /// Blocking structured question request from Claude Code's
    /// `AskUserQuestion` tool. Routed separately from permission flow
    /// because its JSON shape is different (options list instead of a
    /// single decision).
    func handleAskUserQuestion(_ event: AgentHookEvent) async -> Data

    /// Blocking free-form question extracted from a `Notification` hook
    /// event whose payload contains a `question` key.
    func handleQuestion(_ event: AgentHookEvent) async -> Data

    /// Signal that the bridge connection died before we sent our reply.
    /// Used to clean up dangling waitingApproval / waitingQuestion UI
    /// for the given session id.
    func handlePeerDisconnect(sessionId: String)
}

/// Errors thrown by `AgentHookServer.start()`.
enum AgentHookServerError: Error, CustomStringConvertible {
    /// The resolved socket path exceeds the 104-byte `sun_path` limit.
    case socketPathTooLong(String)
    /// `NWListener` construction or startup failed.
    case listenerStartFailed(Error)

    var description: String {
        switch self {
        case let .socketPathTooLong(path):
            return "Socket path exceeds sun_path limit (104 bytes): \(path)"
        case let .listenerStartFailed(error):
            return "Failed to start NWListener: \(error.localizedDescription)"
        }
    }
}
