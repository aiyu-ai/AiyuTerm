//
// AgentTerminalActivator.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/TerminalActivator.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Activates the terminal window/tab running a specific agent
// session. Tab-level switching is supported for Ghostty / iTerm2
// / Terminal.app / WezTerm / kitty; everything else falls back to
// app-level activation.
//
// All pure/testable helpers live in
// `AgentTerminalActivatorHelpers.swift`. This file is responsible
// for the side-effects: NSWorkspace, Process, AppleScript.
//

import AppKit
import Foundation

enum AgentTerminalActivator {

    /// Activate the terminal hosting `session`. `sessionId` is
    /// optional and used as a tie-breaker in title matching.
    static func activate(session: AgentSessionSnapshot, sessionId: String? = nil) {
        // Native app by bundle ID (e.g. Codex APP vs Codex CLI)
        if let bundleId = session.termBundleId,
           AgentTerminalActivatorHelpers.nativeAppBundles[bundleId] != nil {
            activateByBundleId(bundleId)
            return
        }

        // IDE integrated terminal: bring the IDE to front (no
        // tab-level switching — IDEs don't expose a tab-routing
        // AppleScript dictionary in a portable way).
        if session.isIDETerminal,
           let bundleId = session.termBundleId {
            activateByBundleId(bundleId)
            return
        }

        // Resolve target terminal.
        let termApp = AgentTerminalActivatorHelpers.resolveTerminalName(
            termBundleId: session.termBundleId,
            termApp: session.termApp,
            detectFallback: { detectRunningTerminal() }
        )
        let lower = termApp.lowercased()

        // --- tmux: switch pane first, then fall through to
        // terminal-specific activation ---
        if let pane = session.tmuxPane, !pane.isEmpty {
            activateTmux(pane: pane, tmuxEnv: session.tmuxEnv)
        }

        let effectiveTty = AgentTerminalActivatorHelpers.effectiveTty(
            tmuxPane: session.tmuxPane,
            tmuxClientTty: session.tmuxClientTty,
            ttyPath: session.ttyPath
        )

        // --- Tab-level switching (5 terminals) ---

        if lower.contains("iterm") {
            if let itermId = session.itermSessionId, !itermId.isEmpty {
                activateITerm(sessionId: itermId)
            } else {
                activateITermByTtyOrCwd(tty: effectiveTty, cwd: session.cwd)
            }
            return
        }

        if lower == "ghostty" {
            activateGhostty(
                cwd: session.cwd,
                sessionId: sessionId,
                source: session.source,
                tmuxPane: session.tmuxPane,
                tmuxEnv: session.tmuxEnv
            )
            return
        }

        // Match Terminal.app by bundle ID only — Warp sets
        // TERM_PROGRAM=Apple_Terminal, which would false-positive
        // without the bundle check.
        if session.termBundleId == "com.apple.Terminal"
            || (session.termBundleId == nil && lower == "terminal") {
            activateTerminalApp(ttyPath: effectiveTty, cwd: session.cwd)
            return
        }

        if lower.contains("wezterm") || lower.contains("wez") {
            activateWezTerm(ttyPath: effectiveTty, cwd: session.cwd)
            return
        }

        if lower.contains("kitty") {
            activateKitty(
                windowId: session.kittyWindowId,
                cwd: session.cwd,
                source: session.source
            )
            return
        }

        // --- App-level only (Alacritty, Warp, Hyper, Tabby, Rio, etc.) ---
        bringToFront(termApp)
    }

    // MARK: - Ghostty (AppleScript match by tmux title / CWD / title)

    private static func activateGhostty(
        cwd: String?,
        sessionId: String?,
        source: String,
        tmuxPane: String?,
        tmuxEnv: String?
    ) {
        guard let cwd = cwd, !cwd.isEmpty else { bringToFront("Ghostty"); return }
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.mitchellh.ghostty"
        }) {
            if app.isHidden { app.unhide() }
            app.activate()
        }

        // Resolve tmux title prefix when running inside tmux.
        var tmuxKey = ""
        var tmuxSession = ""
        if let pane = tmuxPane?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pane.isEmpty,
           let tmuxBin = AgentTerminalActivatorHelpers.findBinary(named: "tmux") {
            let formats = [
                "#{session_name}:#{window_index}:#{window_name}",
                "#{session_name}",
            ]
            for fmt in formats {
                if let data = runProcess(
                    tmuxBin,
                    args: ["display-message", "-p", "-t", pane, "-F", fmt],
                    env: AgentTerminalActivatorHelpers.tmuxProcessEnv(tmuxEnv)
                ),
                    let result = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    !result.isEmpty {
                    if fmt.contains("window_index") {
                        tmuxKey = result
                        if let first = result.split(separator: ":").first {
                            tmuxSession = String(first)
                        }
                    } else {
                        tmuxSession = result
                    }
                    break
                }
            }
        }

        let trimmedCwd = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        let cwd1 = AgentTerminalActivatorHelpers.stripTrailingSlashes(trimmedCwd)
        let cwd2 = AgentTerminalActivatorHelpers.stripTrailingSlashes(
            URL(fileURLWithPath: cwd1).resolvingSymlinksInPath().path
        )
        let dirName = (cwd1 as NSString).lastPathComponent
        let tildeCwd = AgentTerminalActivatorHelpers.tildePath(
            forCwd: cwd1,
            home: NSHomeDirectory()
        )

        let escape = AgentTerminalActivatorHelpers.escapeAppleScript
        let escapedCwd1 = escape(cwd1)
        let escapedCwd2 = escape(cwd2)
        let escapedDir = escape(dirName)
        let escapedTilde = escape(tildeCwd)
        let escapedTmux = escape(tmuxKey)
        let escapedTmuxSession = escape(tmuxSession)

        let idFilter: String
        if let sid = sessionId, !sid.isEmpty {
            let escapedSid = escape(String(sid.prefix(8)))
            idFilter = """
                repeat with t in matches
                    if name of t contains "\(escapedSid)" then
                        focus t
                        activate
                        return
                    end if
                end repeat
            """
        } else {
            idFilter = ""
        }
        let keyword = escape(source)
        let script = """
        tell application "Ghostty"
            set allTerms to terminals

            -- 1) tmux: match by tmux title prefix first
            set tmuxKey to "\(escapedTmux)"
            set tmuxSession to "\(escapedTmuxSession)"

            if tmuxKey is not "" then
                repeat with t in allTerms
                    try
                        if name of t contains tmuxKey then
                            focus t
                            activate
                            return
                        end if
                    end try
                end repeat
            end if

            if tmuxSession is not "" then
                repeat with t in allTerms
                    try
                        set tname to (name of t as text)
                        if tname starts with (tmuxSession & ":") then
                            focus t
                            activate
                            return
                        end if
                    end try
                end repeat
            end if

            -- 2) Exact CWD match on Ghostty's working-directory property
            set matches to {}
            set cwd1 to "\(escapedCwd1)"
            set cwd2 to "\(escapedCwd2)"
            if cwd1 is not "" then
                try
                    set matches to (every terminal whose working directory is cwd1)
                end try
            end if
            if (count of matches) = 0 and cwd2 is not "" and cwd2 is not cwd1 then
                try
                    set matches to (every terminal whose working directory is cwd2)
                end try
            end if

            -- 3) Title-based fallback
            if (count of matches) = 0 then
                set dirName to "\(escapedDir)"
                set tildeCwd to "\(escapedTilde)"
                repeat with t in allTerms
                    try
                        set tname to (name of t as text)
                        if (tildeCwd is not "" and tname contains tildeCwd) or (cwd1 is not "" and tname contains cwd1) or (dirName is not "" and tname contains dirName) then
                            set end of matches to t
                        end if
                    end try
                end repeat
            end if

            \(idFilter)
            repeat with t in matches
                if name of t contains "\(keyword)" then
                    focus t
                    activate
                    return
                end if
            end repeat
            if (count of matches) > 0 then
                focus (item 1 of matches)
            end if
            activate
        end tell
        """
        runOsaScript(script)
    }

    // MARK: - iTerm2

    private static func activateITermByTtyOrCwd(tty: String?, cwd: String?) {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.googlecode.iterm2"
        }) {
            if app.isHidden { app.unhide() }
            app.activate()
        }
        let escape = AgentTerminalActivatorHelpers.escapeAppleScript
        if let tty = tty, !tty.isEmpty {
            let fullTty = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
            let script = """
            try
                tell application "iTerm2"
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                try
                                    if tty of s is "\(escape(fullTty))" then
                                        select t
                                        select s
                                        set index of w to 1
                                        return
                                    end if
                                end try
                            end repeat
                        end repeat
                    end repeat
                end tell
            end try
            """
            runAppleScript(script)
            return
        }
        guard let cwd = cwd, !cwd.isEmpty else { return }
        let dirName = (cwd as NSString).lastPathComponent
        let script = """
        try
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            try
                                if name of s contains "\(escape(dirName))" or path of s contains "\(escape(dirName))" then
                                    select t
                                    select s
                                    set index of w to 1
                                    return
                                end if
                            end try
                        end repeat
                    end repeat
                end tell
            end try
        """
        runAppleScript(script)
    }

    private static func activateITerm(sessionId: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.googlecode.iterm2"
        }) {
            if app.isHidden { app.unhide() }
            app.activate()
        }
        let escape = AgentTerminalActivatorHelpers.escapeAppleScript
        let script = """
        try
            tell application "iTerm2"
                repeat with aWindow in windows
                    if miniaturized of aWindow then set miniaturized of aWindow to false
                    repeat with aTab in tabs of aWindow
                        repeat with aSession in sessions of aTab
                            if unique ID of aSession is "\(escape(sessionId))" then
                                set miniaturized of aWindow to false
                                select aTab
                                select aSession
                                return
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
        end try
        """
        runAppleScript(script)
    }

    // MARK: - Terminal.app

    private static func activateTerminalApp(ttyPath: String?, cwd: String?) {
        let escape = AgentTerminalActivatorHelpers.escapeAppleScript
        if let tty = ttyPath, !tty.isEmpty {
            let escaped = escape(tty)
            let script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(escaped)" then
                            if miniaturized of w then set miniaturized of w to false
                            set selected tab of w to t
                            set index of w to 1
                        end if
                    end repeat
                end repeat
                activate
            end tell
            """
            runAppleScript(script)
            return
        }
        if let cwd = cwd, !cwd.isEmpty {
            let dirName = escape((cwd as NSString).lastPathComponent)
            let script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            if custom title of t contains "\(dirName)" then
                                if miniaturized of w then set miniaturized of w to false
                                set selected tab of w to t
                                set index of w to 1
                                activate
                                return
                            end if
                        end try
                    end repeat
                end repeat
                activate
            end tell
            """
            runAppleScript(script)
            return
        }
        bringToFront("Terminal")
    }

    // MARK: - WezTerm

    private static func activateWezTerm(ttyPath: String?, cwd: String?) {
        bringToFront("WezTerm")
        guard let bin = AgentTerminalActivatorHelpers.findBinary(named: "wezterm") else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let json = runProcess(bin, args: ["cli", "list", "--format", "json"]),
                  let panes = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]]
            else { return }

            var tabId: Int?
            if let tty = ttyPath {
                tabId = panes.first(where: { ($0["tty_name"] as? String) == tty })?["tab_id"] as? Int
            }
            if tabId == nil, let cwd = cwd {
                let cwdUrl = "file://" + cwd
                tabId = panes.first(where: {
                    guard let paneCwd = $0["cwd"] as? String else { return false }
                    return paneCwd == cwdUrl || paneCwd == cwd
                })?["tab_id"] as? Int
            }

            if let id = tabId {
                _ = runProcess(bin, args: ["cli", "activate-tab", "--tab-id", "\(id)"])
            }
        }
    }

    // MARK: - kitty

    private static func activateKitty(windowId: String?, cwd: String?, source: String) {
        bringToFront("kitty")
        guard let bin = AgentTerminalActivatorHelpers.findBinary(named: "kitten") else { return }

        if let windowId = windowId, !windowId.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                _ = runProcess(bin, args: ["@", "focus-window", "--match", "id:\(windowId)"])
            }
            return
        }
        guard let cwd = cwd, !cwd.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if runProcess(bin, args: ["@", "focus-tab", "--match", "cwd:\(cwd)"]) == nil {
                _ = runProcess(bin, args: ["@", "focus-tab", "--match", "title:\(source)"])
            }
        }
    }

    // MARK: - tmux

    private static func activateTmux(pane: String, tmuxEnv: String?) {
        guard let bin = AgentTerminalActivatorHelpers.findBinary(named: "tmux") else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = runProcess(
                bin,
                args: ["select-window", "-t", pane],
                env: AgentTerminalActivatorHelpers.tmuxProcessEnv(tmuxEnv)
            )
            _ = runProcess(
                bin,
                args: ["select-pane", "-t", pane],
                env: AgentTerminalActivatorHelpers.tmuxProcessEnv(tmuxEnv)
            )
        }
    }

    // MARK: - Bundle ID activation

    private static func activateByBundleId(_ bundleId: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleId
        }) {
            if app.isHidden { app.unhide() }
            app.activate()
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    // MARK: - Generic app activation

    private static func bringToFront(_ termApp: String) {
        let name = AgentTerminalActivatorHelpers.canonicalAppName(from: termApp)

        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == name
                || ($0.bundleIdentifier ?? "").localizedCaseInsensitiveContains(name)
        }) {
            if app.isHidden { app.unhide() }
            app.activate()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", name]
            try? proc.run()
        }
    }

    // MARK: - Process / AppleScript helpers

    private static func detectRunningTerminal() -> String {
        let running = NSWorkspace.shared.runningApplications
        for entry in AgentTerminalActivatorHelpers.knownTerminals {
            if running.contains(where: { $0.bundleIdentifier == entry.bundleId }) {
                return entry.name
            }
        }
        return "Terminal"
    }

    private static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }

    private static func runOsaScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", source]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
        }
    }

    @discardableResult
    private static func runProcess(
        _ path: String,
        args: [String],
        env: [String: String]? = nil
    ) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        if let env {
            var merged = ProcessInfo.processInfo.environment
            for (k, v) in env { merged[k] = v }
            proc.environment = merged
        }
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            // Read BEFORE wait to avoid a deadlock if the pipe
            // buffer fills up.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return proc.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }
}
