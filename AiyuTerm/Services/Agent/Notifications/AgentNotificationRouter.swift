//
// AgentNotificationRouter.swift
// AiyuTerm
//
// Phase 10.1.c: smart-suppress notification router for agent
// task completion. Wraps the global WorkspaceNotificationCenter
// with a two-stage visibility check powered by
// AgentTerminalVisibilityDetector — if the user is already
// looking at the session's terminal we skip posting the
// notification so the notch panel + sidebar badge stay the
// only signals.
//
// Stage 1 (main thread, fast): app-level frontmost check.
// Stage 2 (background thread, slow): tab/pane-level check via
//   AppleScript / CLI. May block 50-200ms, so it's dispatched
//   off the main queue.
//
// If either stage returns true, the notification is suppressed.
// Otherwise we forward to WorkspaceNotificationCenter.deliver.
//

import Foundation
import UserNotifications

enum AgentNotificationRouter {

    /// Ask for notification authorization at launch. Safe to
    /// call repeatedly — `WorkspaceNotificationCenter` tracks
    /// its own has-requested flag.
    @MainActor
    static func requestAuthIfNeeded() {
        // Piggy-back on the existing global center's
        // auth-request plumbing by posting an empty preflight
        // notification request. The center requests auth on
        // first deliver(), so we simulate a no-op call to
        // trigger the prompt without actually posting anything.
        //
        // Cheaper: just call into UNUserNotificationCenter
        // directly — the center's private flag is not visible
        // from here.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    /// Attempt to raise a "task completed" notification. Runs
    /// the two-stage visibility check and suppresses if the user
    /// is already looking at the session. Safe to call from any
    /// thread — the first stage hops to the main actor.
    static func notifyTaskCompleted(session: AgentSessionSnapshot) {
        Task { @MainActor in
            // Stage 1: app-level check. If the session's terminal
            // app is frontmost, do the slow check off the main
            // queue. If not, deliver immediately.
            let frontmost = AgentTerminalVisibilityDetector
                .isTerminalFrontmostForSession(session)

            if !frontmost {
                deliver(session: session)
                return
            }

            // Stage 2: tab-level check on a background queue.
            DispatchQueue.global(qos: .userInitiated).async {
                let visible = AgentTerminalVisibilityDetector
                    .isSessionTabVisible(session)
                if visible { return }
                Task { @MainActor in
                    deliver(session: session)
                }
            }
        }
    }

    // MARK: - Private

    @MainActor
    private static func deliver(session: AgentSessionSnapshot) {
        let title = "Agent task completed"
        let body = "\(session.source) finished"
        WorkspaceNotificationCenter.shared.deliver(
            title: title,
            body: body
        )
    }
}
