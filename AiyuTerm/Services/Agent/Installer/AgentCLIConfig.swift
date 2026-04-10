//
// AgentCLIConfig.swift
// AiyuTerm
//
// Phase 5 scaffolding: shared types for the multi-CLI hook installer.
// This file contains the pure-data description of the 9 supported
// agent CLIs (Claude / Codex / Gemini / Cursor / Qoder / Factory /
// CodeBuddy / Copilot — OpenCode is deferred pending the JS plugin).
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/ConfigInstaller.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//

import Foundation

// MARK: - Hook identifiers

/// Token embedded in every hook entry that AiyuTerm owns. Used to
/// find-and-replace our entries during re-install without touching
/// any other tools' hooks. Legacy names come from the CodeIsland
/// upstream chain plus AiyuTerm's own Phase 4 bridge marker so that
/// users migrating from either origin get a clean merge.
enum AgentHookIdentifier {
    static let current = "aiyuterm-bridge"
    static let legacyNames = [
        "codeisland",     // upstream CodeIsland
        "vibenotch",      // CodeIsland ancestor
        "vibe-island",
        "vibeisland",
    ]

    static func isOurs(_ command: String) -> Bool {
        let lower = command.lowercased()
        if lower.contains(current) { return true }
        return legacyNames.contains { lower.contains($0) }
    }
}

// MARK: - Hook format

/// The four hook-entry schemas supported across the agent CLIs we
/// install into. The Phase 5 installer picks the writer implementation
/// based on this enum.
enum AgentHookFormat: Equatable {
    /// Claude Code style:
    ///   [{matcher: "...", hooks: [{type, command, timeout, async}]}]
    case claude
    /// Codex / Gemini style (no matcher):
    ///   [{hooks: [{type, command, timeout}]}]
    case nested
    /// Cursor style (flat list, one command per entry):
    ///   [{command: "..."}]
    case flat
    /// GitHub Copilot CLI style (top-level `version` + hook entries):
    ///   [{type, bash, timeoutSec}]
    case copilot
}

// MARK: - CLI config

/// Immutable description of a single agent CLI's hook surface. No
/// installation logic lives here — this is the data layer that the
/// Phase 5 installer consumes.
struct AgentCLIConfig {
    /// Display name shown in settings UI (Phase 5 UI still TODO).
    let name: String

    /// Source tag passed through `--source` to the bridge binary.
    /// Matches the values `AgentSessionSnapshot.supportedSources`
    /// accepts, so events from this CLI survive the
    /// `normalizedSupportedSource()` guard in AgentHookServer.
    let source: String

    /// Config file path, relative to `NSHomeDirectory()`. The Phase 5
    /// installer resolves this with `fullPath` / `dirPath` below.
    let configPath: String

    /// Top-level JSON key containing the hook dictionary. All CLIs
    /// happen to use "hooks" today, but we keep this explicit so we
    /// can adapt if a new CLI uses a different schema.
    let configKey: String

    /// Hook entry schema for this CLI.
    let format: AgentHookFormat

    /// (eventName, timeout, async?) triples describing every hook
    /// event we install for this CLI. Timeout units follow the CLI's
    /// convention: Gemini uses milliseconds, everyone else uses
    /// seconds.
    let events: [(name: String, timeout: Int, async: Bool)]

    /// Optional per-event minimum CLI version gate. An event is
    /// installed only when `detectCLIVersion` returns a version
    /// greater than or equal to the one listed here. Used to avoid
    /// installing events on Claude Code builds older than 2.1.89.
    let versionedEvents: [String: String]

    init(
        name: String,
        source: String,
        configPath: String,
        configKey: String = "hooks",
        format: AgentHookFormat,
        events: [(name: String, timeout: Int, async: Bool)],
        versionedEvents: [String: String] = [:]
    ) {
        self.name = name
        self.source = source
        self.configPath = configPath
        self.configKey = configKey
        self.format = format
        self.events = events
        self.versionedEvents = versionedEvents
    }

    /// Absolute path to the config file on disk.
    var fullPath: String {
        "\(NSHomeDirectory())/\(configPath)"
    }

    /// Parent directory of `fullPath`, suitable for `createDirectory`.
    var dirPath: String {
        (fullPath as NSString).deletingLastPathComponent
    }

    /// True iff an executable exists at this CLI's expected binary
    /// location. The Phase 5 installer uses this to skip CLIs that
    /// the user hasn't installed. For now we simply check whether
    /// the config directory exists — a fast proxy that avoids
    /// probing $PATH and works for every CLI in the table.
    var looksInstalledOnDisk: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - CLI registry

/// Single source of truth for the 9 agent CLIs AiyuTerm knows about.
/// Ordered so the UI presents Claude first (our primary target) and
/// the rest alphabetically.
enum AgentCLIRegistry {
    static let allCLIs: [AgentCLIConfig] = [
        // Claude Code — 13 events, two of which are version-gated
        // behind 2.1.89.
        AgentCLIConfig(
            name: "Claude Code",
            source: "claude",
            configPath: ".claude/settings.json",
            format: .claude,
            events: [
                ("UserPromptSubmit", 5, true),
                ("PreToolUse", 5, false),
                ("PostToolUse", 5, true),
                ("PostToolUseFailure", 5, true),
                ("PermissionRequest", 86400, false),
                ("PermissionDenied", 5, true),
                ("Stop", 5, true),
                ("SubagentStart", 5, true),
                ("SubagentStop", 5, true),
                ("SessionStart", 5, false),
                ("SessionEnd", 5, true),
                ("Notification", 86400, false),
                ("PreCompact", 5, true),
            ],
            versionedEvents: [
                "PermissionDenied": "2.1.89",
                "PostToolUseFailure": "2.1.89",
            ]
        ),

        // Codex
        AgentCLIConfig(
            name: "Codex",
            source: "codex",
            configPath: ".codex/hooks.json",
            format: .nested,
            events: [
                ("SessionStart", 5, false),
                ("UserPromptSubmit", 5, false),
                ("PreToolUse", 5, false),
                ("PostToolUse", 5, false),
                ("Stop", 5, false),
            ]
        ),

        // Gemini — timeouts in MILLISECONDS. Do not normalize.
        AgentCLIConfig(
            name: "Gemini",
            source: "gemini",
            configPath: ".gemini/settings.json",
            format: .nested,
            events: [
                ("SessionStart", 5000, false),
                ("SessionEnd", 5000, false),
                ("BeforeTool", 5000, false),
                ("AfterTool", 5000, false),
                ("BeforeAgent", 5000, false),
                ("AfterAgent", 5000, false),
            ]
        ),

        // Cursor
        AgentCLIConfig(
            name: "Cursor",
            source: "cursor",
            configPath: ".cursor/hooks.json",
            format: .flat,
            events: [
                ("beforeSubmitPrompt", 5, false),
                ("beforeShellExecution", 5, false),
                ("afterShellExecution", 5, false),
                ("beforeReadFile", 5, false),
                ("afterFileEdit", 5, false),
                ("beforeMCPExecution", 5, false),
                ("afterMCPExecution", 5, false),
                ("afterAgentThought", 5, false),
                ("afterAgentResponse", 5, false),
                ("stop", 5, false),
            ]
        ),

        // Qoder — Claude Code fork
        AgentCLIConfig(
            name: "Qoder",
            source: "qoder",
            configPath: ".qoder/settings.json",
            format: .claude,
            events: [
                ("UserPromptSubmit", 5, true),
                ("PreToolUse", 5, false),
                ("PostToolUse", 5, true),
                ("SessionStart", 5, false),
                ("SessionEnd", 5, true),
                ("Stop", 5, true),
                ("SubagentStart", 5, true),
                ("SubagentStop", 5, true),
                ("Notification", 86400, false),
                ("PreCompact", 5, true),
            ]
        ),

        // Factory — Claude Code fork, uses `droid` as source tag.
        AgentCLIConfig(
            name: "Factory",
            source: "droid",
            configPath: ".factory/settings.json",
            format: .claude,
            events: [
                ("UserPromptSubmit", 5, true),
                ("PreToolUse", 5, false),
                ("PostToolUse", 5, true),
                ("SessionStart", 5, false),
                ("SessionEnd", 5, true),
                ("Stop", 5, true),
                ("SubagentStart", 5, true),
                ("SubagentStop", 5, true),
                ("Notification", 86400, false),
                ("PreCompact", 5, true),
            ]
        ),

        // CodeBuddy — Claude Code fork
        AgentCLIConfig(
            name: "CodeBuddy",
            source: "codebuddy",
            configPath: ".codebuddy/settings.json",
            format: .claude,
            events: [
                ("UserPromptSubmit", 5, true),
                ("PreToolUse", 5, false),
                ("PostToolUse", 5, true),
                ("SessionStart", 5, false),
                ("SessionEnd", 5, true),
                ("Stop", 5, true),
                ("SubagentStart", 5, true),
                ("SubagentStop", 5, true),
                ("Notification", 86400, false),
                ("PreCompact", 5, true),
            ]
        ),

        // GitHub Copilot CLI
        AgentCLIConfig(
            name: "Copilot",
            source: "copilot",
            // Renamed from codeisland.json -> aiyuterm.json so the
            // filename itself identifies our ownership at a glance.
            configPath: ".copilot/hooks/aiyuterm.json",
            format: .copilot,
            events: [
                ("sessionStart", 5, false),
                ("sessionEnd", 5, true),
                ("userPromptSubmitted", 5, false),
                ("preToolUse", 5, false),
                ("postToolUse", 5, true),
                ("errorOccurred", 5, true),
            ]
        ),
    ]

    /// All CLIs except Claude Code. Phase 5.2 will install Claude
    /// Code via the existing ClaudeCodeHooksService and route this
    /// subset through the generic installer.
    static var externalCLIs: [AgentCLIConfig] {
        allCLIs.filter { $0.source != "claude" }
    }

    /// Look up a CLI by its source tag.
    static func cli(forSource source: String) -> AgentCLIConfig? {
        allCLIs.first { $0.source == source }
    }
}
