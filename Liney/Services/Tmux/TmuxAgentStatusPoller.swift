//
//  TmuxAgentStatusPoller.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

/// Polls tmux pane content and hook-set pane options to detect Claude Code status.
/// OSC 9 desktop notifications do not pass through tmux to Ghostty,
/// so this poller provides an alternative detection mechanism.
@MainActor
final class TmuxAgentStatusPoller {

    private struct Registration {
        weak var workspace: WorkspaceModel?
        let sessionID: String
    }

    private static let paneOptionKey = "aiyuterm_agent_status"

    private static let permissionKeywords = [
        "Do you want to proceed?",
        "Esc to cancel",
    ]

    private var registrations: [String: Registration] = [:]
    private var timer: Timer?
    var onStatusChange: (() -> Void)?

    func register(sessionID: String, workspace: WorkspaceModel) {
        registrations[sessionID] = Registration(workspace: workspace, sessionID: sessionID)
        ensureTimerRunning()
    }

    func unregister(sessionID: String) {
        registrations.removeValue(forKey: sessionID)
        if registrations.isEmpty {
            timer?.invalidate()
            timer = nil
        }
    }

    private func ensureTimerRunning() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.poll()
            }
        }
    }

    private func poll() async {
        for (_, registration) in registrations {
            guard let workspace = registration.workspace else { continue }
            do {
                let status = try await detectStatus(for: registration.sessionID)
                var changed = false
                for session in workspace.sessionController.sessions.values {
                    if status != session.agentStatus {
                        session.agentStatus = status
                        changed = true
                    }
                }
                if changed {
                    onStatusChange?()
                }
            } catch {
                // Session may have been killed; silently ignore
            }
        }
    }

    /// Detect agent status from hook pane option first, then fall back to content scanning.
    private func detectStatus(for sessionID: String) async throws -> AgentSessionStatus {
        // Priority 1: Hook-set pane option (most reliable, set by Claude Code hooks)
        if let hookValue = try await TmuxService.paneOption(sessionID: sessionID, option: Self.paneOptionKey) {
            let status = Self.parseHookValue(hookValue)
            if status != .none {
                // Clear the option after reading so it doesn't persist stale state
                try? await TmuxService.clearPaneOption(sessionID: sessionID, option: Self.paneOptionKey)
                return status
            }
        }

        // Priority 2: Pane content scanning (fallback for sessions without hooks configured)
        let content = try await TmuxService.capturePaneContent(sessionID: sessionID)
        if Self.hasActivePermissionPrompt(in: content) {
            return .permissionNeeded
        }

        return .none
    }

    /// Parse the hook value format: "status:timestamp"
    private static func parseHookValue(_ value: String) -> AgentSessionStatus {
        let parts = value.split(separator: ":", maxSplits: 1)
        let statusString = parts.first.map(String.init) ?? value

        // Check staleness: ignore values older than 30 seconds
        if parts.count == 2, let timestamp = TimeInterval(parts[1]) {
            let age = Date().timeIntervalSince1970 - timestamp
            if age > 30 { return .none }
        }

        switch statusString {
        case "permission": return .permissionNeeded
        case "completed": return .taskCompleted
        case "error": return .error
        default: return .none
        }
    }

    /// Only check the bottom of the visible pane.
    private static func hasActivePermissionPrompt(in content: String) -> Bool {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let bottomLines = lines.suffix(15)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .suffix(8)
        let bottomText = bottomLines.joined(separator: "\n")
        return permissionKeywords.contains { bottomText.contains($0) }
    }
}
