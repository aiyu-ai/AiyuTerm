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

    /// Phase 12.9: FIFO queue of pending permission requests per
    /// worktree. Multiple concurrent permission requests are queued;
    /// only the head entry is shown in the sidebar bubble UI. When the
    /// head is resolved the next entry is promoted.
    private var permissionQueues: [String: [PendingPermission]] = [:]

    /// A single queued permission request with its async continuation.
    struct PendingPermission {
        let id: UUID
        let toolUseId: String?
        let request: AgentPermissionRequest
        let continuation: CheckedContinuation<Data, Never>
        let enqueuedAt: Date
    }

    /// Same shape for AskUserQuestion / Notification-question flows.
    private var pendingQuestionContinuations: [UUID: CheckedContinuation<Data, Never>] = [:]

    /// Reverse lookup from worktree path to question request UUID so
    /// `handlePeerDisconnect` can find the right continuation.
    private var worktreeToQuestionRequestId: [String: UUID] = [:]

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
        "SessionStart", "SessionEnd",
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
        // date. Side effects other than `.playSound` are still
        // discarded in Phase 3 (Phase 4 will start listening to
        // `.enqueueCompletion` etc); `.playSound` is forwarded to
        // AgentSoundManager so the Phase 10.2 audio hookup works.
        let effects = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: maxHistory
        )
        Self.dispatchSideEffects(effects)

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

        applyStatus(
            derivedStatus,
            to: workspace,
            worktreePath: worktreePath,
            sessionId: sessionId
        )
    }

    func handlePermissionRequest(_ event: AgentHookEvent) async -> Data {
        // Phase 12.9: enqueue the request into a per-worktree FIFO
        // queue and suspend until the UI resolves it. Multiple
        // concurrent requests are queued silently; only the head
        // entry is shown in the sidebar bubble. If we cannot resolve
        // the worktree we deny immediately so the bridge never hangs.
        let sessionId = event.sessionId ?? "default"

        // Always run the reducer first so snapshot state stays fresh.
        let effects = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: maxHistory
        )
        Self.dispatchSideEffects(effects)

        guard let worktreePath = resolveWorktreePath(for: event, sessionId: sessionId),
              let workspace = findWorkspace(containing: worktreePath)
        else {
            Self.logger.debug(
                "permission request: no worktree for session \(sessionId, privacy: .public); denying"
            )
            return AgentPermissionResponseBuilder.deny
        }
        sessionWorktreeCache[sessionId] = worktreePath

        let request = AgentPermissionRequest(
            id: UUID(),
            toolUseId: event.resolvedToolUseId,
            sessionId: sessionId,
            worktreePath: worktreePath,
            toolName: event.toolName ?? "Unknown",
            toolDescription: event.toolDescription,
            timestamp: Date()
        )

        let isFirstInQueue = permissionQueues[worktreePath]?.isEmpty ?? true

        return await withCheckedContinuation { continuation in
            let pending = PendingPermission(
                id: request.id,
                toolUseId: event.resolvedToolUseId,
                request: request,
                continuation: continuation,
                enqueuedAt: Date()
            )
            permissionQueues[worktreePath, default: []].append(pending)

            if isFirstInQueue {
                workspace.enqueuePermissionRequest(request)
                workspace.markPermissionUnread(forWorktreePath: worktreePath)
                workspace.setAgentStatus(.permissionNeeded, forWorktreePath: worktreePath)
            }
        }
    }

    func handleAskUserQuestion(_ event: AgentHookEvent) async -> Data {
        await enqueueAndSuspendQuestion(event, fallbackHeader: "AskUserQuestion")
    }

    func handleQuestion(_ event: AgentHookEvent) async -> Data {
        await enqueueAndSuspendQuestion(event, fallbackHeader: nil)
    }

    private func enqueueAndSuspendQuestion(
        _ event: AgentHookEvent,
        fallbackHeader: String?
    ) async -> Data {
        let sessionId = event.sessionId ?? "default"

        let effects = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: maxHistory
        )
        Self.dispatchSideEffects(effects)

        guard let worktreePath = resolveWorktreePath(for: event, sessionId: sessionId),
              let workspace = findWorkspace(containing: worktreePath)
        else {
            return AgentQuestionResponseBuilder.skip
        }
        sessionWorktreeCache[sessionId] = worktreePath

        // Extract question payload from event. For structured
        // AskUserQuestion the options live under toolInput.questions;
        // for Notification questions the payload lives at the top
        // level.
        let questionText: String
        let options: [String]?
        let header: String?
        if let payload = AgentQuestionPayload.from(event: event) {
            questionText = payload.question
            options = payload.options
            header = payload.header ?? fallbackHeader
        } else if event.toolName == "AskUserQuestion",
                  let questions = event.toolInput?["questions"] as? [[String: Any]],
                  let first = questions.first,
                  let text = first["question"] as? String
        {
            questionText = text
            options = first["options"] as? [String]
            header = (first["header"] as? String) ?? fallbackHeader
        } else {
            return AgentQuestionResponseBuilder.skip
        }

        // Replace any older question on this worktree.
        if let existing = worktreeToQuestionRequestId[worktreePath],
           let prior = pendingQuestionContinuations.removeValue(forKey: existing)
        {
            prior.resume(returning: AgentQuestionResponseBuilder.skip)
            workspace.removeQuestionRequest(forWorktreePath: worktreePath)
        }

        let request = AgentQuestionRequest(
            id: UUID(),
            sessionId: sessionId,
            worktreePath: worktreePath,
            question: questionText,
            options: options,
            header: header,
            timestamp: Date()
        )
        workspace.enqueueQuestionRequest(request)
        workspace.markPermissionUnread(forWorktreePath: worktreePath)
        workspace.setAgentStatus(.permissionNeeded, forWorktreePath: worktreePath)

        return await withCheckedContinuation { continuation in
            pendingQuestionContinuations[request.id] = continuation
            worktreeToQuestionRequestId[worktreePath] = request.id
        }
    }

    func handlePeerDisconnect(sessionId: String) {
        // The bridge died before we replied. Drain any continuation
        // we were holding for this sessionId so the async task
        // doesn't leak. We also clear waitingApproval /
        // waitingQuestion state on the snapshot for hygiene.
        if var snapshot = snapshots[sessionId] {
            if snapshot.status == .waitingApproval || snapshot.status == .waitingQuestion {
                snapshot.status = .processing
                snapshots[sessionId] = snapshot
            }
        }

        // Drain all queued permission continuations and the question
        // continuation for this session's worktree.
        if let worktreePath = sessionWorktreeCache[sessionId] {
            // Drain entire permission queue for this worktree.
            if let queue = permissionQueues.removeValue(forKey: worktreePath) {
                for pending in queue {
                    pending.continuation.resume(returning: AgentPermissionResponseBuilder.deny)
                }
                if let workspace = findWorkspace(containing: worktreePath) {
                    workspace.removePermissionRequest(forWorktreePath: worktreePath)
                }
            }
            // Drain question continuation (still single-slot).
            if let id = worktreeToQuestionRequestId.removeValue(forKey: worktreePath),
               let continuation = pendingQuestionContinuations.removeValue(forKey: id)
            {
                continuation.resume(returning: AgentQuestionResponseBuilder.skip)
                if let workspace = findWorkspace(containing: worktreePath) {
                    workspace.removeQuestionRequest(forWorktreePath: worktreePath)
                }
            }
        }
    }

    // MARK: - UI-facing resolve entry points

    /// Resolve the head permission request on the given worktree
    /// with the user's decision. If more requests are queued behind
    /// it the next one is promoted to the sidebar bubble. Called by
    /// WorkspaceStore from the sidebar bubble action handler.
    /// No-op if the queue is empty.
    func resolvePermission(
        forWorktreePath path: String,
        decision: AgentPermissionDecision
    ) {
        guard var queue = permissionQueues[path], !queue.isEmpty else { return }

        let head = queue.removeFirst()
        permissionQueues[path] = queue.isEmpty ? nil : queue

        head.continuation.resume(returning: AgentPermissionResponseBuilder.response(for: decision))

        if let workspace = findWorkspace(containing: path) {
            workspace.removePermissionRequest(forWorktreePath: path)

            if let next = queue.first {
                // Promote the next queued request to the UI.
                workspace.enqueuePermissionRequest(next.request)
                workspace.markPermissionUnread(forWorktreePath: path)
                // Status stays .permissionNeeded — no transition needed.
            } else {
                // Queue drained: flip badge back to working so the
                // user sees activity resume. Next real event will
                // refine it.
                if decision != .deny {
                    workspace.setAgentStatus(.working, forWorktreePath: path)
                    workspace.markPermissionRead(forWorktreePath: path)
                }
            }
        }
    }

    /// Resolve the pending question request with the option the
    /// user selected. Passing nil for `option` resolves as "skip"
    /// (equivalent to deny).
    func resolveQuestion(
        forWorktreePath path: String,
        option: String?
    ) {
        guard let id = worktreeToQuestionRequestId.removeValue(forKey: path),
              let continuation = pendingQuestionContinuations.removeValue(forKey: id)
        else {
            return
        }
        let header = findWorkspace(containing: path)?
            .pendingQuestionRequests[path]?
            .header
        let response: Data
        if let option {
            response = AgentQuestionResponseBuilder.answer(option, header: header)
        } else {
            response = AgentQuestionResponseBuilder.skip
        }
        continuation.resume(returning: response)
        if let workspace = findWorkspace(containing: path) {
            workspace.removeQuestionRequest(forWorktreePath: path)
            if option != nil {
                workspace.setAgentStatus(.working, forWorktreePath: path)
                workspace.markPermissionRead(forWorktreePath: path)
            }
        }
    }

    // MARK: - Stale queue cleanup (Phase 12.11)

    /// Drain all queued permission entries older than `threshold`,
    /// resuming their continuations with deny. If the drain empties a
    /// worktree's queue entirely, clear the UI request too.
    func drainStalePermissions(olderThan threshold: Date) {
        for (path, var queue) in permissionQueues {
            let stale = queue.filter { $0.enqueuedAt < threshold }
            for entry in stale {
                entry.continuation.resume(returning: AgentPermissionResponseBuilder.deny)
            }
            queue.removeAll { $0.enqueuedAt < threshold }
            if queue.isEmpty {
                permissionQueues[path] = nil
                if let workspace = findWorkspace(containing: path) {
                    workspace.removePermissionRequest(forWorktreePath: path)
                }
            } else {
                permissionQueues[path] = queue
                // If the head was drained, promote the new head.
                if stale.contains(where: { $0.id == stale.first?.id }) {
                    if let workspace = findWorkspace(containing: path) {
                        workspace.removePermissionRequest(forWorktreePath: path)
                        workspace.enqueuePermissionRequest(queue[0].request)
                    }
                }
            }
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

    /// Number of queued permission requests for a worktree, used by
    /// tests to verify queue depth without exposing internal types.
    func _permissionQueueDepth(forWorktreePath path: String) -> Int {
        permissionQueues[path]?.count ?? 0
    }

    // MARK: - Notch panel read access

    /// Return the most-recently-active `AgentSessionSnapshot`
    /// whose cached worktree matches `worktreePath`. Used by the
    /// notch panel to hydrate per-session metadata (model, cwd,
    /// current tool, last assistant message, …).
    ///
    /// We iterate the cache and pick the snapshot with the latest
    /// `lastActivity`; the `sessionWorktreeCache` is the authoritative
    /// session→worktree mapping.
    func latestSnapshot(forWorktreePath path: String) -> AgentSessionSnapshot? {
        latestSnapshotWithId(forWorktreePath: path)?.snapshot
    }

    /// Same as `latestSnapshot(forWorktreePath:)` but also returns
    /// the underlying `sessionId` key. Callers that need to resolve
    /// a title via `AgentSessionTitleStore.title(for:provider:cwd:)`
    /// need the sessionId to look up the on-disk JSONL.
    func latestSnapshotWithId(
        forWorktreePath path: String
    ) -> (sessionId: String, snapshot: AgentSessionSnapshot)? {
        let matchingSessionIds = sessionWorktreeCache
            .filter { $0.value == path }
            .map(\.key)
        var best: (sessionId: String, snapshot: AgentSessionSnapshot)?
        for sid in matchingSessionIds {
            guard let candidate = snapshots[sid] else { continue }
            if let current = best {
                if candidate.lastActivity > current.snapshot.lastActivity {
                    best = (sid, candidate)
                }
            } else {
                best = (sid, candidate)
            }
        }
        return best
    }

    // MARK: - Persistence bridge (Phase 10.1.a)

    /// Copy of the snapshot dictionary. Used by the shutdown /
    /// periodic-save hook in `WorkspaceStore.persistAgentSessions()`.
    func allSnapshots() -> [String: AgentSessionSnapshot] {
        snapshots
    }

    /// Seed the mapper with a snapshot rebuilt from disk on launch.
    /// Call from `WorkspaceStore.loadIfNeeded()` with each
    /// `AgentPersistedSession` that survived the last session.
    ///
    /// Populates both the `snapshots` map and the
    /// `sessionWorktreeCache` (when the persisted cwd matches a
    /// known worktree) so subsequent live events can find the
    /// restored session without waiting for a new resolve.
    func restoreSnapshot(_ persisted: AgentPersistedSession) {
        var snapshot = AgentSessionSnapshot(startTime: persisted.startTime)
        snapshot.lastActivity = persisted.lastActivity
        snapshot.cwd = persisted.cwd
        snapshot.source = persisted.source
        snapshot.model = persisted.model
        snapshot.sessionTitle = persisted.sessionTitle
        snapshot.sessionTitleSource = persisted.sessionTitleSource
        snapshot.providerSessionId = persisted.providerSessionId
        snapshot.lastUserPrompt = persisted.lastUserPrompt
        snapshot.lastAssistantMessage = persisted.lastAssistantMessage
        snapshot.termApp = persisted.termApp
        snapshot.itermSessionId = persisted.itermSessionId
        snapshot.ttyPath = persisted.ttyPath
        snapshot.kittyWindowId = persisted.kittyWindowId
        snapshot.tmuxPane = persisted.tmuxPane
        snapshot.tmuxClientTty = persisted.tmuxClientTty
        snapshot.tmuxEnv = persisted.tmuxEnv
        snapshot.termBundleId = persisted.termBundleId
        if let pid = persisted.cliPid {
            snapshot.cliPid = pid_t(pid)
        }
        snapshot.cliStartTime = persisted.cliStartTime

        snapshots[persisted.sessionId] = snapshot

        // If the persisted cwd maps to a known worktree, prime the
        // session cache so the first live event resolves instantly.
        if let cwd = persisted.cwd,
           let matched = walkUpToMatchWorktree(from: cwd) {
            sessionWorktreeCache[persisted.sessionId] = matched
        }
    }

    // MARK: - Private: reducer side-effect dispatch (Phase 10.2)

    /// Fan reducer side effects out to the services that know how
    /// to handle them. Today the only handled effect is
    /// `.playSound`, which we route to `AgentSoundManager`. All
    /// other cases are intentional no-ops until the phases that
    /// need them land.
    ///
    /// Marked `static` because the only dependency it needs is
    /// `AgentSoundManager`, which is itself a static enum, and we
    /// want to keep this safe to call from the
    /// `handleEventForceStatus` path where we are already on the
    /// main actor.
    private static func dispatchSideEffects(_ effects: [AgentSessionSideEffect]) {
        guard AgentSoundManager.isEnabled else { return }
        for effect in effects {
            if case .playSound(let eventName) = effect {
                AgentSoundManager.play(eventName)
            }
        }
    }

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
        worktreePath: String,
        sessionId: String
    ) {
        switch status {
        case .taskCompleted:
            workspace.markCompletionUnread(forWorktreePath: worktreePath)
            workspace.setAgentStatus(.taskCompleted, forWorktreePath: worktreePath)
            // Phase 10.1.c: smart-suppress notification. The
            // router checks whether the terminal is already
            // visible before posting to avoid double-signalling
            // the user when the notch panel + sidebar badge are
            // enough.
            if let snapshot = snapshots[sessionId] {
                AgentNotificationRouter.notifyTaskCompleted(session: snapshot)
            }

        case .permissionNeeded:
            workspace.markPermissionUnread(forWorktreePath: worktreePath)
            workspace.setAgentStatus(.permissionNeeded, forWorktreePath: worktreePath)

        case .working:
            // A fresh activity cycle clears any stale unread flags.
            workspace.markCompletionRead(forWorktreePath: worktreePath)
            workspace.markPermissionRead(forWorktreePath: worktreePath)
            workspace.setAgentStatus(.working, forWorktreePath: worktreePath)

        case .compacting:
            workspace.setAgentStatus(.compacting, forWorktreePath: worktreePath)

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

        let effects = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: maxHistory
        )
        Self.dispatchSideEffects(effects)

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

        case "PreCompact":
            return .compacting

        case "PostCompact":
            return .working

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
