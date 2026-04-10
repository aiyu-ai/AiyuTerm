//
// AgentHookEventMapper.swift
// AiyuTerm
//
// Phase 3 of the CodeIsland integration: translates decoded
// AgentHookEvents from the AgentHookServer socket into calls on
// AiyuTerm's existing WorkspaceModel state surface
// (setAgentStatus + markCompletionUnread / markPermissionUnread).
//
// This is the adapter layer that lets us keep the rich CodeIsland
// reducer (`reduceAgentHookEvent`, `AgentSessionSnapshot`) alongside
// AiyuTerm's simplified five-value `AgentSessionStatus` UI contract
// defined in WorkspaceModels.swift (the Phase 3 plan calls this the
// "translation layer").
//
// Key design points:
//
// • session_id -> worktreePath is resolved via a three-level fallback:
//     1. cwd walk-up — match the event's cwd (or a parent) against any
//        known worktree path.
//     2. tmux_pane reverse-lookup using `_tmux_pane` injected by the
//        bridge. (Only used when the cwd walk-up misses.)
//     3. session cache — the last worktreePath we successfully
//        resolved for this sessionId.
//   Resolution failures are logged and the event is dropped without
//   affecting the rest of the pipeline.
//
// • Blocking callbacks (permission / AskUserQuestion / question) are
//   deliberately simple in Phase 3: they reduce the event into the
//   snapshot, flip the worktree badge to `.permissionNeeded`, and
//   then return a `deny` response. Phase 6 will replace the deny
//   response with a real UI flow.
//
// • Every mutation is `@MainActor` so we can safely touch the
//   WorkspaceModel state without actor hops.
//

import Foundation
import os.log

@MainActor
final class AgentHookEventMapper: AgentHookReceiver {
    // MARK: - Dependencies

    /// Returns the current snapshot of workspaces. Passed as a closure
    /// so the mapper does not hold a strong reference to WorkspaceStore.
    private let workspacesProvider: () -> [WorkspaceModel]

    // MARK: - State (all MainActor-isolated)

    /// CodeIsland-style session snapshots. The reducer maintains this
    /// dictionary; we read the post-reduction status out of it to
    /// derive the `AgentSessionStatus` we forward to the UI.
    private var snapshots: [String: AgentSessionSnapshot] = [:]

    /// Last successfully-resolved worktree path per sessionId.
    /// Populated on successful resolution, consulted as fallback.
    private var sessionWorktreeCache: [String: String] = [:]

    private static let logger = Logger(
        subsystem: "com.aiyuai.aiyuterm",
        category: "AgentHookEventMapper"
    )

    /// How many tool history entries each snapshot keeps. Matches the
    /// default used by CodeIsland's AppState (50).
    private let maxHistory: Int = 50

    /// Ignore events whose normalized name is in this set — they carry
    /// state transitions that we don't want to forward to the badge
    /// layer yet (e.g. PreCompact during context compaction).
    private static let silentEventNames: Set<String> = [
        "SessionStart", "SessionEnd", "PreCompact",
    ]

    /// Canonical "allow once" permission response body. Phase 6 will
    /// replace the deny-by-default logic with a real UI flow; for now
    /// Phase 3 lets the tests assert the shape of the denial.
    private static let denyResponse: Data = {
        let payload = #"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}"#
        return Data(payload.utf8)
    }()

    // MARK: - Init

    init(workspacesProvider: @escaping () -> [WorkspaceModel]) {
        self.workspacesProvider = workspacesProvider
    }

    // MARK: - AgentHookReceiver

    func handleEvent(_ event: AgentHookEvent) {
        let sessionId = event.sessionId ?? "default"

        // Run the CodeIsland reducer to keep our rich snapshot up to
        // date. We mostly ignore the returned side effects in Phase 3
        // (Phase 4 will start listening to `.enqueueCompletion` etc).
        _ = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: maxHistory
        )

        guard let worktreePath = resolveWorktreePath(for: event, sessionId: sessionId) else {
            Self.logger.debug(
                "handleEvent: unresolved worktree for session \(sessionId, privacy: .public) event=\(event.eventName, privacy: .public)"
            )
            return
        }

        // Cache successful resolution so future events for this
        // session can fall back to it when cwd is missing.
        sessionWorktreeCache[sessionId] = worktreePath

        guard let workspace = findWorkspace(containing: worktreePath) else {
            return
        }

        let derivedStatus = deriveStatus(from: event, normalizedName: AgentHookEventNormalizer.normalize(event.eventName))

        applyStatus(derivedStatus, to: workspace, worktreePath: worktreePath)
    }

    func handlePermissionRequest(_ event: AgentHookEvent) async -> Data {
        // Phase 3: record the event into state and flip the badge to
        // permissionNeeded, but always return deny. Phase 6 will plug
        // in real UI-mediated approval.
        handleEventForceStatus(event, forcedStatus: .permissionNeeded, markUnread: .permission)
        return Self.denyResponse
    }

    func handleAskUserQuestion(_ event: AgentHookEvent) async -> Data {
        handleEventForceStatus(event, forcedStatus: .permissionNeeded, markUnread: .permission)
        return Self.denyResponse
    }

    func handleQuestion(_ event: AgentHookEvent) async -> Data {
        handleEventForceStatus(event, forcedStatus: .permissionNeeded, markUnread: .permission)
        return Self.denyResponse
    }

    func handlePeerDisconnect(sessionId: String) {
        // The bridge died before we replied. In Phase 3 all blocking
        // calls return deny immediately so there is nothing to drain,
        // but we still clear any lingering waitingApproval /
        // waitingQuestion state on the snapshot for hygiene.
        guard var snapshot = snapshots[sessionId] else { return }
        if snapshot.status == .waitingApproval || snapshot.status == .waitingQuestion {
            snapshot.status = .processing
            snapshots[sessionId] = snapshot
        }
    }

    // MARK: - Helpers exposed for tests

    /// Clear all internal state. Used by tests to reset between cases.
    func _resetForTesting() {
        snapshots.removeAll()
        sessionWorktreeCache.removeAll()
    }

    /// Snapshot count, used by tests to assert state bookkeeping.
    var _snapshotCountForTesting: Int { snapshots.count }

    // MARK: - Private: event status derivation

    private enum UnreadMark {
        case none
        case completion
        case permission
    }

    /// Apply the derived status to the workspace, plus any unread-state
    /// bookkeeping that the badge rendering depends on.
    private func applyStatus(
        _ status: AgentSessionStatus,
        to workspace: WorkspaceModel,
        worktreePath: String
    ) {
        switch status {
        case .taskCompleted:
            workspace.markCompletionUnread(forWorktreePath: worktreePath)
            workspace.setAgentStatus(.taskCompleted, forWorktreePath: worktreePath)

        case .permissionNeeded:
            workspace.markPermissionUnread(forWorktreePath: worktreePath)
            workspace.setAgentStatus(.permissionNeeded, forWorktreePath: worktreePath)

        case .working:
            // A fresh activity cycle clears any stale unread flags.
            workspace.markCompletionRead(forWorktreePath: worktreePath)
            workspace.markPermissionRead(forWorktreePath: worktreePath)
            workspace.setAgentStatus(.working, forWorktreePath: worktreePath)

        case .error:
            workspace.setAgentStatus(.error, forWorktreePath: worktreePath)

        case .none:
            // Intentional: don't overwrite an existing badge with `.none`
            // because we might have more specific state already set via
            // the title-detection fast path in ShellSession.
            break
        }
    }

    /// Force-set the status on the resolved worktree and mark unread
    /// state accordingly. Used by the blocking callbacks which know
    /// the badge must switch to permissionNeeded regardless of what
    /// the reducer says.
    private func handleEventForceStatus(
        _ event: AgentHookEvent,
        forcedStatus: AgentSessionStatus,
        markUnread: UnreadMark
    ) {
        let sessionId = event.sessionId ?? "default"

        _ = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: maxHistory
        )

        guard let worktreePath = resolveWorktreePath(for: event, sessionId: sessionId) else {
            Self.logger.debug("forceStatus: unresolved worktree for session \(sessionId, privacy: .public)")
            return
        }
        sessionWorktreeCache[sessionId] = worktreePath

        guard let workspace = findWorkspace(containing: worktreePath) else { return }

        switch markUnread {
        case .completion:
            workspace.markCompletionUnread(forWorktreePath: worktreePath)
        case .permission:
            workspace.markPermissionUnread(forWorktreePath: worktreePath)
        case .none:
            break
        }
        workspace.setAgentStatus(forcedStatus, forWorktreePath: worktreePath)
    }

    /// Translate a normalized event name into the coarse
    /// `AgentSessionStatus` that the sidebar badge needs.
    ///
    /// This intentionally ignores the post-reduction
    /// `AgentHookStatus` because the reducer keeps a richer enum
    /// (idle/processing/running/waitingApproval/waitingQuestion)
    /// that doesn't map 1:1 to AiyuTerm's 5 values without losing
    /// nuance around unread/completed flags.
    private func deriveStatus(
        from event: AgentHookEvent,
        normalizedName: String
    ) -> AgentSessionStatus {
        if Self.silentEventNames.contains(normalizedName) {
            return .none
        }

        switch normalizedName {
        case "UserPromptSubmit",
             "PreToolUse",
             "PostToolUse",
             "SubagentStart",
             "SubagentStop",
             "AfterAgentResponse":
            return .working

        case "Stop":
            return .taskCompleted

        case "StopFailure", "PostToolUseFailure":
            return .error

        case "PermissionRequest":
            return .permissionNeeded

        case "PermissionDenied":
            // Permission flow finished — return to working so the
            // badge doesn't stick on "needs permission".
            return .working

        case "Notification":
            if let type = event.rawJSON["notification_type"] as? String,
               type == "permission_prompt" || type == "idle_prompt"
            {
                return .permissionNeeded
            }
            if AgentQuestionPayload.from(event: event) != nil {
                return .permissionNeeded
            }
            // Plain informational notifications don't change the badge.
            return .none

        default:
            // Unknown / passthrough event — leave the badge alone.
            return .none
        }
    }

    // MARK: - Private: worktree resolution

    /// Resolve which AiyuTerm worktree this event belongs to.
    ///
    /// Walks three fallbacks (cwd -> tmux_pane -> session cache) in
    /// order. This is the keystone of Phase 3 — the quality of the
    /// sidebar badge stream depends entirely on this function.
    private func resolveWorktreePath(
        for event: AgentHookEvent,
        sessionId: String
    ) -> String? {
        // Level 1: match event.cwd against any known worktree. Walk
        // up the path so that a deep subdir inside the worktree still
        // resolves to the worktree root.
        if let cwd = event.rawJSON["cwd"] as? String,
           let matched = walkUpToMatchWorktree(from: cwd)
        {
            return matched
        }

        // Level 2: tmux pane reverse lookup. The bridge injects
        // `_tmux_pane` when the hook ran inside a tmux session. In
        // Phase 3 we do not yet scan ShellSession for matching tmux
        // panes (that requires more wiring into session controller),
        // so this level is a pure cache check: if a previous event
        // with the same tmux pane resolved, reuse its worktree.
        if let pane = event.rawJSON["_tmux_pane"] as? String,
           let cached = tmuxPaneCache[pane]
        {
            return cached
        }

        // Level 3: session-scoped cache from a previous successful
        // resolution of this same sessionId.
        return sessionWorktreeCache[sessionId]
    }

    /// Mutable cache from tmux pane id -> worktree path. Populated
    /// whenever we resolve via level 1 for a tmux event, so follow-up
    /// events in the same pane stay fast.
    private var tmuxPaneCache: [String: String] = [:]

    private func walkUpToMatchWorktree(from path: String) -> String? {
        let workspaces = workspacesProvider()
        // Build an indexed lookup for the walk.
        var knownPaths: Set<String> = []
        for workspace in workspaces {
            for worktree in workspace.worktrees {
                knownPaths.insert(worktree.path)
            }
        }

        var candidate = path
        while !candidate.isEmpty, candidate != "/" {
            if knownPaths.contains(candidate) {
                return candidate
            }
            candidate = (candidate as NSString).deletingLastPathComponent
        }
        return nil
    }

    private func findWorkspace(containing worktreePath: String) -> WorkspaceModel? {
        for workspace in workspacesProvider() {
            if workspace.worktrees.contains(where: { $0.path == worktreePath }) {
                return workspace
            }
        }
        return nil
    }
}
