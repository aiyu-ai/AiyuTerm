//
// AgentTerminalVisibilityDetector.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/TerminalVisibilityDetector.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Detects whether a session's terminal tab/pane is currently the
// frontmost/visible one. Used by the smart-suppress path to avoid
// raising a notification when the user is already looking at the
// session in question.
//
// Two detection levels:
//   • App-level (`isTerminalFrontmostForSession`)
//     Fast, main-thread safe. Just compares bundle IDs /
//     TERM_PROGRAM values against NSWorkspace.frontmostApplication.
//   • Tab-level (`isSessionTabVisible`)
//     Precise, may block 50-200ms via AppleScript or CLI calls —
//     MUST be called from a background thread.
//

import AppKit
import Foundation

enum AgentTerminalVisibilityDetector {

    // MARK: - App-level check (main-thread safe)

    /// Fast check: is the session's terminal app the frontmost
    /// application? Safe to call from the main thread — no
    /// AppleScript or subprocess calls.
    static func isTerminalFrontmostForSession(_ session: AgentSessionSnapshot) -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        return AgentTerminalVisibilityHelpers.matchesFrontmost(
            session: session,
            frontBundleId: frontApp.bundleIdentifier,
            frontLocalizedName: frontApp.localizedName
        )
    }

    // MARK: - Tab-level check (background thread only)

    /// Full check: is the session's specific tab/pane currently
    /// visible? **Call from a background thread only** — may
    /// block 50-200ms.
    static func isSessionTabVisible(_ session: AgentSessionSnapshot) -> Bool {
        guard isTerminalFrontmostForSession(session) else { return false }

        // Native app mode: the app IS the session, so if it's
        // frontmost we're "looking at it".
        if session.isNativeAppMode { return true }

        // IDE integrated terminals: tab state isn't queryable, so
        // default to "not visible" — show the notification rather
        // than suppress it while the user edits code.
        if session.isIDETerminal { return false }

        // tmux priority — if the session runs inside a tmux pane,
        // check that pane regardless of the wrapping terminal.
        if let pane = session.tmuxPane, !pane.isEmpty {
            return isTmuxPaneActive(pane)
        }

        let route = AgentTerminalVisibilityHelpers.routeTabCheck(
            termBundleId: session.termBundleId,
            termApp: session.termApp
        )
        switch route {
        case .iTerm: return isITermSessionActive(session)
        case .ghostty: return isGhosttyTabActive(session)
        case .terminalApp: return isTerminalAppTabActive(session)
        case .wezterm: return isWezTermTabActive(session)
        case .kitty: return isKittyWindowActive(session)
        case .unknown: return false
        }
    }

    // MARK: - iTerm2

    private static func isITermSessionActive(_ session: AgentSessionSnapshot) -> Bool {
        guard let sessionId = session.itermSessionId, !sessionId.isEmpty else {
            return false
        }
        let escaped = AgentTerminalActivatorHelpers.escapeAppleScript(sessionId)
        let script = """
        tell application "iTerm2"
            try
                set s to current session of current tab of current window
                if unique ID of s is "\(escaped)" then return "true"
            end try
            return "false"
        end tell
        """
        return runAppleScriptSync(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    // MARK: - Ghostty

    private static func isGhosttyTabActive(_ session: AgentSessionSnapshot) -> Bool {
        guard let cwd = session.cwd, !cwd.isEmpty else { return false }
        let dirName = AgentTerminalActivatorHelpers.escapeAppleScript(
            (cwd as NSString).lastPathComponent
        )
        let sourceKeyword = AgentTerminalActivatorHelpers.escapeAppleScript(
            session.source
        )
        let script = """
        tell application "System Events"
            tell process "Ghostty"
                try
                    set winTitle to name of front window
                    if winTitle contains "\(dirName)" and winTitle contains "\(sourceKeyword)" then return "true"
                end try
            end tell
        end tell
        return "false"
        """
        return runAppleScriptSync(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    // MARK: - Terminal.app

    private static func isTerminalAppTabActive(_ session: AgentSessionSnapshot) -> Bool {
        guard let tty = session.ttyPath, !tty.isEmpty else { return false }
        let escaped = AgentTerminalActivatorHelpers.escapeAppleScript(tty)
        let script = """
        tell application "Terminal"
            try
                if tty of selected tab of front window is "\(escaped)" then return "true"
            end try
            return "false"
        end tell
        """
        return runAppleScriptSync(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    // MARK: - WezTerm

    private static func isWezTermTabActive(_ session: AgentSessionSnapshot) -> Bool {
        guard let bin = AgentTerminalActivatorHelpers.findBinary(named: "wezterm") else {
            return false
        }
        guard let json = runProcess(bin, args: ["cli", "list", "--format", "json"]),
              let panes = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]]
        else { return false }

        return AgentTerminalVisibilityHelpers.wezTermActivePaneMatches(
            panes: panes,
            expectedTty: session.ttyPath,
            expectedCwd: session.cwd
        )
    }

    // MARK: - kitty

    private static func isKittyWindowActive(_ session: AgentSessionSnapshot) -> Bool {
        guard let bin = AgentTerminalActivatorHelpers.findBinary(named: "kitten") else {
            return false
        }
        guard let json = runProcess(bin, args: ["@", "ls"]),
              let osTabs = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]]
        else { return false }

        return AgentTerminalVisibilityHelpers.kittyFocusedWindowMatches(
            osWindows: osTabs,
            expectedWindowId: session.kittyWindowId
        )
    }

    // MARK: - tmux

    private static func isTmuxPaneActive(_ pane: String) -> Bool {
        guard let bin = AgentTerminalActivatorHelpers.findBinary(named: "tmux") else {
            return false
        }
        guard let data = runProcess(
                bin,
                args: ["display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}"]
              ),
              let activePaneId = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !activePaneId.isEmpty
        else { return false }

        guard let listData = runProcess(
                bin,
                args: ["list-panes", "-a", "-F", "#{pane_id} #{session_name}:#{window_index}.#{pane_index}"]
              ),
              let listStr = String(data: listData, encoding: .utf8)
        else { return pane == activePaneId }

        return AgentTerminalVisibilityHelpers.tmuxPaneMatches(
            pane: pane,
            activePaneId: activePaneId,
            listPanesOutput: listStr
        )
    }

    // MARK: - Process / AppleScript helpers

    private static func runAppleScriptSync(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return result.stringValue
    }

    @discardableResult
    private static func runProcess(_ path: String, args: [String]) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return proc.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }
}

// MARK: - Pure helpers

/// Pure helpers extracted from `AgentTerminalVisibilityDetector`
/// so their branching logic can be unit-tested without touching
/// NSWorkspace, AppleScript, or the filesystem.
enum AgentTerminalVisibilityHelpers {

    /// Which tab-level check should we route to for a given
    /// terminal identification?
    enum TabCheckRoute: Equatable {
        case iTerm
        case ghostty
        case terminalApp
        case wezterm
        case kitty
        case unknown
    }

    /// Decide the tab-check route. `termBundleId` takes precedence
    /// over `termApp`; the `termApp` branch never returns
    /// `.terminalApp` because Warp sets `TERM_PROGRAM=Apple_Terminal`.
    static func routeTabCheck(termBundleId: String?, termApp: String?) -> TabCheckRoute {
        let bid = (termBundleId ?? "").lowercased()
        if bid.contains("iterm2") || bid.contains("iterm") { return .iTerm }
        if bid.contains("ghostty") { return .ghostty }
        if bid == "com.apple.terminal" { return .terminalApp }
        if bid.contains("wezterm") { return .wezterm }
        if bid.contains("kitty") { return .kitty }

        if let termApp {
            let lower = termApp.lowercased()
                .replacingOccurrences(of: ".app", with: "")
                .replacingOccurrences(of: "apple_", with: "")
            if lower.contains("iterm") { return .iTerm }
            if lower == "ghostty" { return .ghostty }
            if lower.contains("wezterm") || lower.contains("wez") { return .wezterm }
            if lower.contains("kitty") { return .kitty }
            // Intentionally NOT matching "terminal" here — Warp
            // sets TERM_PROGRAM=Apple_Terminal so we'd misroute.
        }
        return .unknown
    }

    /// App-level match: does `frontBundleId` / `frontLocalizedName`
    /// identify the session's terminal app? Extracted for unit
    /// testing — the real implementation just hands in the values
    /// it read from NSWorkspace.
    static func matchesFrontmost(
        session: AgentSessionSnapshot,
        frontBundleId: String?,
        frontLocalizedName: String?
    ) -> Bool {
        if let termBundleId = session.termBundleId?.lowercased(),
           !termBundleId.isEmpty {
            return (frontBundleId?.lowercased() ?? "") == termBundleId
        }

        guard let termApp = session.termApp else { return false }

        let frontName = (frontLocalizedName ?? "").lowercased()
        let bundleId = (frontBundleId ?? "").lowercased()
        let term = termApp.lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .replacingOccurrences(of: "apple_", with: "")
        let normalizedFront = frontName.replacingOccurrences(of: ".app", with: "")

        return normalizedFront.contains(term)
            || term.contains(normalizedFront)
            || bundleId.contains(term)
    }

    /// Does the active pane in `panes` (parsed `wezterm cli list
    /// --format json` output) match the expected TTY/CWD?
    static func wezTermActivePaneMatches(
        panes: [[String: Any]],
        expectedTty: String?,
        expectedCwd: String?
    ) -> Bool {
        guard let activePane = panes.first(where: {
            ($0["is_active"] as? Bool) == true
        }) else { return false }

        if let tty = expectedTty, !tty.isEmpty,
           let paneTty = activePane["tty_name"] as? String {
            return paneTty == tty
        }

        if let cwd = expectedCwd,
           let paneCwd = activePane["cwd"] as? String {
            if paneCwd == cwd || paneCwd == "file://" + cwd { return true }
        }
        return false
    }

    /// Does the focused window in `osWindows` (parsed `kitten @ ls`
    /// output) match the expected Kitty window ID?
    static func kittyFocusedWindowMatches(
        osWindows: [[String: Any]],
        expectedWindowId: String?
    ) -> Bool {
        for osWindow in osWindows {
            let isFocused = (osWindow["is_focused"] as? Bool) == true
            guard isFocused, let tabs = osWindow["tabs"] as? [[String: Any]] else { continue }
            for tab in tabs {
                let isActive = (tab["is_focused"] as? Bool) == true
                guard isActive, let windows = tab["windows"] as? [[String: Any]] else { continue }
                for window in windows {
                    let winFocused = (window["is_focused"] as? Bool) == true
                    guard winFocused else { continue }
                    if let expectedWindowId,
                       let winId = window["id"] as? Int,
                       "\(winId)" == expectedWindowId { return true }
                    return false
                }
            }
        }
        return false
    }

    /// Does `pane` (either `%N` or `session:win.pane`) match the
    /// `activePaneId` reported by `tmux display-message`? Uses the
    /// output of `tmux list-panes -a -F "#{pane_id} …"` as a
    /// translation table when `pane` is in the `%N` format.
    static func tmuxPaneMatches(
        pane: String,
        activePaneId: String,
        listPanesOutput: String
    ) -> Bool {
        for line in listPanesOutput.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2, String(parts[0]) == pane {
                return String(parts[1]) == activePaneId
            }
        }
        return pane == activePaneId
    }
}
