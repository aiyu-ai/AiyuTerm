//
// AgentTerminalActivatorHelpers.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/TerminalActivator.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Pure helpers extracted from `AgentTerminalActivator` so the
// string-manipulation + lookup logic can be unit-tested without
// launching AppleScript, NSWorkspace or real terminal apps.
//
// Everything here must stay side-effect-free (no Process, no
// NSWorkspace, no file I/O). Side-effectful work lives in
// `AgentTerminalActivator`.
//

import Foundation

enum AgentTerminalActivatorHelpers {

    // MARK: - Known terminals

    /// Bundle-ID ↔ display-name table used to resolve the target
    /// terminal when the hook event doesn't carry TERM_PROGRAM.
    static let knownTerminals: [(name: String, bundleId: String)] = [
        ("cmux", "com.cmuxterm.app"),
        ("Ghostty", "com.mitchellh.ghostty"),
        ("iTerm2", "com.googlecode.iterm2"),
        ("WezTerm", "com.github.wez.wezterm"),
        ("kitty", "net.kovidgoyal.kitty"),
        ("Alacritty", "org.alacritty"),
        ("Warp", "dev.warp.Warp-Stable"),
        ("Terminal", "com.apple.Terminal"),
    ]

    /// Bundle IDs for CLIs that ship with both an APP and CLI mode.
    /// When we see one of these bundle IDs we activate the app
    /// directly rather than trying to find its terminal tab.
    static let nativeAppBundles: [String: String] = [
        "com.openai.codex": "Codex",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.qoder.ide": "Qoder",
        "com.factory.app": "Factory",
        "com.tencent.codebuddy": "CodeBuddy",
        "ai.opencode.desktop": "OpenCode",
    ]

    // MARK: - AppleScript escaping

    /// Escape a string for safe interpolation into AppleScript
    /// double-quoted literals. Only backslashes and double quotes
    /// are meaningful.
    static func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - CWD normalization

    /// Trim trailing slashes except for root ("/").
    static func stripTrailingSlashes(_ path: String) -> String {
        var p = path
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// Return `"~"` or `"~/subpath"` when `cwd` is under `home`,
    /// otherwise the empty string. Used to build title-match
    /// fallbacks for Ghostty.
    static func tildePath(forCwd cwd: String, home: String) -> String {
        if cwd == home { return "~" }
        if cwd.hasPrefix(home + "/") {
            return "~" + String(cwd.dropFirst(home.count))
        }
        return ""
    }

    // MARK: - Terminal resolution

    /// Resolve the terminal name we should drive given the hook
    /// event's bundle ID + TERM_PROGRAM value. `detectFallback` is
    /// called when neither field is usable (e.g. `TERM_PROGRAM=tmux`).
    static func resolveTerminalName(
        termBundleId: String?,
        termApp: String?,
        detectFallback: () -> String
    ) -> String {
        if let bundleId = termBundleId,
           let resolved = knownTerminals.first(where: { $0.bundleId == bundleId })?.name {
            return resolved
        }
        let raw = termApp ?? ""
        let lower = raw.lowercased()
        if raw.isEmpty || lower == "tmux" || lower == "screen" {
            return detectFallback()
        }
        return raw
    }

    /// Canonical display name used by `bringToFront`. This keeps
    /// the string-matching table out of the mutator function so we
    /// can unit-test it.
    static func canonicalAppName(from termApp: String) -> String {
        let lower = termApp.lowercased()
        if lower.contains("cmux") { return "cmux" }
        if lower == "ghostty" { return "Ghostty" }
        if lower.contains("iterm") { return "iTerm2" }
        if lower.contains("terminal") || lower.contains("apple_terminal") { return "Terminal" }
        if lower.contains("wezterm") || lower.contains("wez") { return "WezTerm" }
        if lower.contains("alacritty") || lower.contains("lacritty") { return "Alacritty" }
        if lower.contains("kitty") { return "kitty" }
        if lower.contains("warp") { return "Warp" }
        if lower.contains("hyper") { return "Hyper" }
        if lower.contains("tabby") { return "Tabby" }
        if lower.contains("rio") { return "Rio" }
        return termApp
    }

    // MARK: - Effective TTY

    /// Inside tmux, Ghostty/iTerm/Terminal.app see the client tty
    /// rather than the inner pane's tty. Prefer `tmuxClientTty`
    /// when we're inside a tmux pane.
    static func effectiveTty(
        tmuxPane: String?,
        tmuxClientTty: String?,
        ttyPath: String?
    ) -> String? {
        let inTmux = (tmuxPane ?? "").isEmpty == false
        if inTmux, let tmuxClientTty, !tmuxClientTty.isEmpty {
            return tmuxClientTty
        }
        return ttyPath
    }

    // MARK: - Binary lookup

    /// Common paths where we look for a CLI binary. Kept out of
    /// the `activate` functions so tests can use a custom list.
    static let defaultBinarySearchPaths: [String] = [
        "/opt/homebrew/bin/",
        "/usr/local/bin/",
        "/usr/bin/",
    ]

    /// Find the first existing + executable `name` under any of
    /// the supplied `paths`.
    static func findBinary(
        named name: String,
        in paths: [String] = defaultBinarySearchPaths,
        fileManager: FileManager = .default
    ) -> String? {
        for base in paths {
            let fullPath = base.hasSuffix("/") ? "\(base)\(name)" : "\(base)/\(name)"
            if fileManager.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    // MARK: - tmux env

    /// Convert the captured `TMUX` env var into the process-env
    /// dictionary we pass to `tmux` invocations. Returns nil when
    /// there is nothing to add, so the caller can skip merging.
    static func tmuxProcessEnv(_ tmuxEnv: String?) -> [String: String]? {
        guard let tmuxEnv = tmuxEnv?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tmuxEnv.isEmpty else { return nil }
        return ["TMUX": tmuxEnv]
    }
}
