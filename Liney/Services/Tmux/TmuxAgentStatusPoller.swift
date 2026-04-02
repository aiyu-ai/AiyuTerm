//
//  TmuxAgentStatusPoller.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

/// Polls tmux pane content to detect Claude Code permission prompts.
/// OSC 9 desktop notifications do not pass through tmux to Ghostty,
/// so this poller provides an alternative detection mechanism.
@MainActor
final class TmuxAgentStatusPoller {

    private struct Registration {
        weak var workspace: WorkspaceModel?
        let sessionID: String
    }

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
                let content = try await TmuxService.capturePaneContent(sessionID: registration.sessionID)
                let hasPermissionPrompt = Self.hasActivePermissionPrompt(in: content)
                var changed = false
                for session in workspace.sessionController.sessions.values {
                    if hasPermissionPrompt && session.agentStatus != .permissionNeeded {
                        session.agentStatus = .permissionNeeded
                        changed = true
                    } else if !hasPermissionPrompt && session.agentStatus == .permissionNeeded {
                        session.agentStatus = .none
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

    /// Only check the bottom of the visible pane.
    /// Permission prompts are active when they appear near the cursor (bottom).
    /// Old prompts that scrolled up are historical and should be ignored.
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
