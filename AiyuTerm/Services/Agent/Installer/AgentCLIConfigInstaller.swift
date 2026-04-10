//
// AgentCLIConfigInstaller.swift
// AiyuTerm
//
// Phase 5.2: writer / reader for agent CLI hook config files.
//
// This file implements the install-side of the Phase 5 multi-CLI
// integration. It owns the hook registration on disk but delegates
// the script body (bridge wrapper) to ClaudeCodeHooksService — the
// installer only rewrites JSON config files, not shell scripts.
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/ConfigInstaller.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Scope of this commit (Phase 5.2):
//   • JSONC stripper (comments out of the read path)
//   • parseJSONFile + safe write helpers
//   • containsOurHook / removeManagedHookEntries / hasStaleAsyncKey
//   • installClaude(cli:) — the .claude format writer
//   • isHooksInstalled(for:) detector for Phase 5.4's verifyAndRepair
//
// Out of scope here (coming in Phase 5.3+):
//   • .nested / .flat / .copilot writers
//   • install() / uninstall() / verifyAndRepair() top-level API
//   • Claude version gate `detectClaudeVersion`
//   • Settings UI
//

import Foundation
import os.log

/// Minimal abstraction over UserDefaults so tests can inject a
/// throwaway store and not pollute the host defaults database.
///
/// Protocol is Sendable so impls can cross actor boundaries without
/// triggering the Swift 6 MainActor-backdeploy deinit path that
/// tripped libmalloc during initial Phase 5.4 testing.
protocol AgentCLIEnablementStore: AnyObject, Sendable {
    func isCLIEnabled(source: String, defaultValue: Bool) -> Bool
    func setCLIEnabled(source: String, enabled: Bool)
}

/// Production impl backed by UserDefaults.standard with the
/// `aiyuterm.cli_enabled_<source>` key prefix. Stays name-spaced so
/// we never collide with a user's other tools.
final class UserDefaultsAgentCLIEnablementStore: AgentCLIEnablementStore, @unchecked Sendable {
    static let shared = UserDefaultsAgentCLIEnablementStore()

    private let defaults: UserDefaults
    private let keyPrefix = "aiyuterm.cli_enabled_"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isCLIEnabled(source: String, defaultValue: Bool) -> Bool {
        let key = keyPrefix + source
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.bool(forKey: key)
    }

    func setCLIEnabled(source: String, enabled: Bool) {
        defaults.set(enabled, forKey: keyPrefix + source)
    }
}

/// In-memory impl used by tests. Marked `@unchecked Sendable` and
/// wraps the dictionary in NSLock so there is no implicit MainActor
/// isolation on deinit — otherwise Swift 6's
/// `swift_task_deinitOnExecutorMainActorBackDeploy` path re-schedules
/// the deinit on the main executor and libmalloc crashes during
/// teardown of a test that created the store as a local let.
final class InMemoryAgentCLIEnablementStore: AgentCLIEnablementStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: [String: Bool] = [:]

    init() {}

    func isCLIEnabled(source: String, defaultValue: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return state[source] ?? defaultValue
    }

    func setCLIEnabled(source: String, enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        state[source] = enabled
    }
}

enum AgentCLIConfigInstaller {

    // MARK: - Public types

    /// Outcome of `installClaude(cli:)`. Let callers distinguish
    /// "no-op because already correct" from "wrote new content".
    enum InstallOutcome: Equatable {
        case alreadyInstalled
        case installed
        case failed(String)
    }

    /// Per-CLI status reported by `discoverCLIs()` — lets the
    /// settings UI render a three-way badge
    /// (not-installed / not-enabled / installed).
    struct CLIStatus: Equatable {
        let source: String
        let name: String
        /// True if the CLI directory (e.g. ~/.claude) exists on disk.
        let cliPresent: Bool
        /// True if the user has the CLI toggled on in AgentCLIEnablementStore.
        let userEnabled: Bool
        /// True if our hook entry is currently present in the CLI's
        /// config file. Independent of `cliPresent` and `userEnabled`
        /// so the UI can say things like "enabled but missing hooks".
        let hookInstalled: Bool
    }

    // MARK: - Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.aiyuai.aiyuterm",
        category: "AgentCLIConfigInstaller"
    )

    // MARK: - Top-level orchestration

    /// Install hooks for every enabled CLI that AiyuTerm knows about.
    /// CLIs that are disabled or whose config directory is missing
    /// are skipped silently. Returns the list of CLI display names
    /// for which a fresh write happened (as opposed to a no-op
    /// `.alreadyInstalled` outcome or a skipped CLI).
    ///
    /// The `claudeHookCommand` is the absolute path to the bridge
    /// wrapper script (Phase 4's `claude-code-bridge-hook.sh`). All
    /// other CLIs call the bridge binary directly using
    /// `externalBridgeBinaryPath`.
    @discardableResult
    static func install(
        claudeHookCommand: String,
        externalBridgeBinaryPath: String,
        registry: [AgentCLIConfig] = AgentCLIRegistry.allCLIs,
        enablementStore: AgentCLIEnablementStore = UserDefaultsAgentCLIEnablementStore.shared,
        fileManager: FileManager = .default
    ) -> [String] {
        var installed: [String] = []
        for cli in registry {
            guard enablementStore.isCLIEnabled(source: cli.source, defaultValue: cli.source == "claude") else {
                continue
            }
            // Skip CLIs whose state directory doesn't exist on disk
            // unless it's Claude Code (which we auto-onboard because
            // AiyuTerm's primary target is Claude Code).
            if cli.source != "claude" && !cli.looksInstalledOnDisk {
                continue
            }

            let outcome: InstallOutcome
            switch cli.format {
            case .claude:
                outcome = installClaude(
                    cli: cli,
                    hookCommand: claudeHookCommand,
                    fileManager: fileManager
                )
            case .nested, .flat, .copilot:
                outcome = installExternal(
                    cli: cli,
                    bridgeBinaryPath: externalBridgeBinaryPath,
                    fileManager: fileManager
                )
            }

            switch outcome {
            case .installed:
                installed.append(cli.name)
            case .alreadyInstalled:
                break
            case .failed(let reason):
                logger.warning("install failed for \(cli.name, privacy: .public): \(reason, privacy: .public)")
            }
        }
        return installed
    }

    /// Uninstall every managed hook entry across the full registry.
    /// Foreign tool entries are left alone (see `removeManagedHookEntries`).
    /// Returns the list of CLI display names that had their config
    /// file rewritten.
    @discardableResult
    static func uninstallAll(
        registry: [AgentCLIConfig] = AgentCLIRegistry.allCLIs,
        fileManager: FileManager = .default
    ) -> [String] {
        var rewritten: [String] = []
        for cli in registry {
            guard fileManager.fileExists(atPath: cli.fullPath) else { continue }
            if uninstall(cli: cli, fileManager: fileManager) {
                rewritten.append(cli.name)
            }
        }
        return rewritten
    }

    /// Scan every enabled CLI whose directory exists on disk, and
    /// re-install our hook if it's missing or stale. Used at app
    /// startup to self-heal configs that the user or a CLI upgrade
    /// may have clobbered.
    ///
    /// Returns the list of CLI display names that were repaired.
    @discardableResult
    static func verifyAndRepair(
        claudeHookCommand: String,
        externalBridgeBinaryPath: String,
        registry: [AgentCLIConfig] = AgentCLIRegistry.allCLIs,
        enablementStore: AgentCLIEnablementStore = UserDefaultsAgentCLIEnablementStore.shared,
        fileManager: FileManager = .default
    ) -> [String] {
        var repaired: [String] = []
        for cli in registry {
            guard enablementStore.isCLIEnabled(source: cli.source, defaultValue: cli.source == "claude") else {
                continue
            }
            // Skip CLIs the user hasn't onboarded, except Claude
            // which we always target.
            if cli.source != "claude" && !cli.looksInstalledOnDisk {
                continue
            }
            if isHooksInstalled(for: cli, fileManager: fileManager) {
                continue
            }

            let outcome: InstallOutcome
            switch cli.format {
            case .claude:
                outcome = installClaude(
                    cli: cli,
                    hookCommand: claudeHookCommand,
                    fileManager: fileManager
                )
            case .nested, .flat, .copilot:
                outcome = installExternal(
                    cli: cli,
                    bridgeBinaryPath: externalBridgeBinaryPath,
                    fileManager: fileManager
                )
            }
            if case .installed = outcome {
                repaired.append(cli.name)
            }
        }
        return repaired
    }

    /// Report the install/enabled/on-disk status of every CLI in the
    /// registry. The settings UI consumes this to render the agents
    /// panel; tests use it to assert install-side effects.
    static func discoverCLIs(
        registry: [AgentCLIConfig] = AgentCLIRegistry.allCLIs,
        enablementStore: AgentCLIEnablementStore = UserDefaultsAgentCLIEnablementStore.shared,
        fileManager: FileManager = .default
    ) -> [CLIStatus] {
        registry.map { cli in
            CLIStatus(
                source: cli.source,
                name: cli.name,
                cliPresent: cli.looksInstalledOnDisk,
                userEnabled: enablementStore.isCLIEnabled(
                    source: cli.source,
                    defaultValue: cli.source == "claude"
                ),
                hookInstalled: isHooksInstalled(for: cli, fileManager: fileManager)
            )
        }
    }

    /// Toggle a specific CLI on or off. When enabling, runs install
    /// for that CLI immediately so the user sees hooks become
    /// active. When disabling, runs uninstall for that CLI.
    ///
    /// Returns the post-toggle `isHooksInstalled` state.
    @discardableResult
    static func setCLIEnabled(
        source: String,
        enabled: Bool,
        claudeHookCommand: String,
        externalBridgeBinaryPath: String,
        registry: [AgentCLIConfig] = AgentCLIRegistry.allCLIs,
        enablementStore: AgentCLIEnablementStore = UserDefaultsAgentCLIEnablementStore.shared,
        fileManager: FileManager = .default
    ) -> Bool {
        enablementStore.setCLIEnabled(source: source, enabled: enabled)
        guard let cli = registry.first(where: { $0.source == source }) else {
            return false
        }

        if enabled {
            // Allow enabling Claude Code even if ~/.claude doesn't
            // exist yet — we'll create the directory ourselves on
            // first install. Other CLIs need the user to have
            // onboarded them first.
            if cli.source != "claude" && !cli.looksInstalledOnDisk {
                return false
            }
            let outcome: InstallOutcome
            switch cli.format {
            case .claude:
                outcome = installClaude(
                    cli: cli,
                    hookCommand: claudeHookCommand,
                    fileManager: fileManager
                )
            case .nested, .flat, .copilot:
                outcome = installExternal(
                    cli: cli,
                    bridgeBinaryPath: externalBridgeBinaryPath,
                    fileManager: fileManager
                )
            }
            switch outcome {
            case .installed, .alreadyInstalled:
                return isHooksInstalled(for: cli, fileManager: fileManager)
            case .failed:
                return false
            }
        } else {
            _ = uninstall(cli: cli, fileManager: fileManager)
            return false
        }
    }

    // MARK: - Claude format writer

    /// Install AiyuTerm's hook into a Claude-format config file
    /// (Claude Code / Qoder / Factory / CodeBuddy all share this
    /// format).
    ///
    /// The command string pointed to is the bridge wrapper script
    /// that ClaudeCodeHooksService owns. This installer only cares
    /// about the JSON structure; it leaves the script body to
    /// ClaudeCodeHooksService.ensureBridgeHookScript().
    @discardableResult
    static func installClaude(
        cli: AgentCLIConfig,
        hookCommand: String,
        fileManager: FileManager = .default
    ) -> InstallOutcome {
        installClaudeAt(
            events: cli.events,
            configKey: cli.configKey,
            fullPath: cli.fullPath,
            dirPath: cli.dirPath,
            format: cli.format,
            debugName: cli.name,
            hookCommand: hookCommand,
            fileManager: fileManager
        )
    }

    /// Path-explicit variant of `installClaude` for tests and for
    /// future multi-install-root scenarios. `fullPath` / `dirPath`
    /// are taken as-is (no `NSHomeDirectory()` anchoring), so
    /// sandboxed test targets can point them at a writable tmp
    /// directory.
    @discardableResult
    static func installClaudeAt(
        events: [(name: String, timeout: Int, async: Bool)],
        configKey: String,
        fullPath: String,
        dirPath: String,
        format: AgentHookFormat,
        debugName: String,
        hookCommand: String,
        fileManager: FileManager = .default
    ) -> InstallOutcome {
        precondition(format == .claude,
                     "installClaudeAt called on non-.claude CLI \(debugName)")

        // 1) Ensure parent dir exists.
        if !fileManager.fileExists(atPath: dirPath) {
            do {
                try fileManager.createDirectory(
                    atPath: dirPath,
                    withIntermediateDirectories: true
                )
            } catch {
                logger.error("Failed to create dir \(dirPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return .failed("mkdir: \(error.localizedDescription)")
            }
        }

        // 2) Read existing settings (JSONC-tolerant).
        var settings: [String: Any] = [:]
        if let existing = parseJSONFile(at: fullPath, fileManager: fileManager) {
            settings = existing
        }

        var hooks = settings[configKey] as? [String: Any] ?? [:]

        // 3) Fast-path: detect an already-correct installation.
        let wantedEventNames = events.map(\.name)
        let alreadyAllPresent = wantedEventNames.allSatisfy { event in
            guard let entries = hooks[event] as? [[String: Any]] else { return false }
            return entries.contains { entry in
                guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
                return inner.contains { ($0["command"] as? String) == hookCommand }
            }
        }
        if alreadyAllPresent && !hasStaleAsyncKey(hooks) {
            return .alreadyInstalled
        }

        // 4) Sweep out any previous managed entries then re-inject.
        hooks = removeManagedHookEntries(from: hooks)

        for event in events {
            var arr = hooks[event.name] as? [[String: Any]] ?? []
            var hookEntry: [String: Any] = [
                "type": "command",
                "command": hookCommand,
                "timeout": event.timeout,
            ]
            if event.async {
                hookEntry["async"] = true
            }
            arr.append([
                "matcher": "",
                "hooks": [hookEntry],
            ])
            hooks[event.name] = arr
        }

        settings[configKey] = hooks

        guard let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return .failed("serialize")
        }

        let url = URL(fileURLWithPath: fullPath)
        do {
            try data.write(to: url, options: [.atomic])
            return .installed
        } catch {
            logger.error("Failed to write \(fullPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed("write: \(error.localizedDescription)")
        }
    }

    // MARK: - External format writers (.nested / .flat / .copilot)

    /// Install hooks into a non-Claude CLI's config file. Dispatches
    /// on `cli.format` and calls the bridge binary directly
    /// (no intermediate shell wrapper) using the bridge command
    /// string the caller provides.
    ///
    /// The bridge command should be the absolute path to the
    /// `aiyuterm-hook-bridge` binary (or a quoted variant when the
    /// path contains spaces). Callers are responsible for appending
    /// any `--source` flag; we do that here based on `cli.source`.
    @discardableResult
    static func installExternal(
        cli: AgentCLIConfig,
        bridgeBinaryPath: String,
        fileManager: FileManager = .default
    ) -> InstallOutcome {
        installExternalAt(
            format: cli.format,
            source: cli.source,
            events: cli.events,
            configKey: cli.configKey,
            fullPath: cli.fullPath,
            dirPath: cli.dirPath,
            debugName: cli.name,
            bridgeBinaryPath: bridgeBinaryPath,
            fileManager: fileManager
        )
    }

    /// Path-explicit variant of `installExternal`. Same contract as
    /// `installClaudeAt` — tests inject a sandbox path.
    @discardableResult
    static func installExternalAt(
        format: AgentHookFormat,
        source: String,
        events: [(name: String, timeout: Int, async: Bool)],
        configKey: String,
        fullPath: String,
        dirPath: String,
        debugName: String,
        bridgeBinaryPath: String,
        fileManager: FileManager = .default
    ) -> InstallOutcome {
        precondition(format != .claude,
                     "installExternalAt must not be called on .claude CLI \(debugName)")

        // 1) Ensure parent dir. For .copilot we additionally require
        //    ~/.copilot itself to exist so we don't manufacture a
        //    phantom install root for a user who hasn't onboarded
        //    Copilot yet.
        if format == .copilot {
            let copilotRoot = (dirPath as NSString).deletingLastPathComponent
            guard fileManager.fileExists(atPath: copilotRoot) else {
                return .alreadyInstalled // treat as no-op
            }
        }
        if !fileManager.fileExists(atPath: dirPath) {
            do {
                try fileManager.createDirectory(
                    atPath: dirPath,
                    withIntermediateDirectories: true
                )
            } catch {
                logger.error("mkdir failed for \(dirPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return .failed("mkdir: \(error.localizedDescription)")
            }
        }

        // 2) Read existing config (JSONC-tolerant).
        var root: [String: Any] = [:]
        if let existing = parseJSONFile(at: fullPath, fileManager: fileManager) {
            root = existing
        }

        var hooks = root[configKey] as? [String: Any] ?? [:]

        // 3) Build the base command. Quote the bridge path if it
        //    contains spaces so shell hosts that re-tokenize the
        //    string still end up with the right argv[0].
        let quotedBridge = bridgeBinaryPath.contains(" ")
            ? "\"\(bridgeBinaryPath)\""
            : bridgeBinaryPath
        let baseCommand = "\(quotedBridge) --source \(source)"

        // 4) Fast-path detection: for every event, verify an entry
        //    exists that carries our base command verbatim. If all
        //    match, the install is a no-op.
        let allMatch = events.allSatisfy { event in
            guard let entries = hooks[event.name] as? [[String: Any]] else { return false }
            return entries.contains { entry in
                containsBaseCommand(entry, baseCommand: baseCommand, format: format, eventName: event.name)
            }
        }
        if allMatch && !hasStaleAsyncKey(hooks) {
            return .alreadyInstalled
        }

        // 5) Sweep stale managed entries and re-inject.
        for event in events {
            var eventEntries = hooks[event.name] as? [[String: Any]] ?? []
            eventEntries.removeAll(where: containsOurHook)

            let entry: [String: Any]
            switch format {
            case .claude:
                preconditionFailure("unreachable — filtered above")
            case .nested:
                entry = [
                    "hooks": [[
                        "type": "command",
                        "command": baseCommand,
                        "timeout": event.timeout,
                    ]],
                ]
            case .flat:
                entry = ["command": baseCommand]
            case .copilot:
                // Copilot stdin lacks session_id / hook_event_name,
                // so we pass the event name via --event and let the
                // bridge reconstruct the canonical JSON before
                // forwarding.
                let copilotCommand = "\(baseCommand) --event \(event.name)"
                entry = [
                    "type": "command",
                    "bash": copilotCommand,
                    "timeoutSec": event.timeout,
                ]
            }

            eventEntries.append(entry)
            hooks[event.name] = eventEntries
        }

        root[configKey] = hooks

        // 6) Copilot requires a top-level "version" field — if it's
        //    absent from the existing file, set it now.
        if format == .copilot, root["version"] == nil {
            root["version"] = 1
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return .failed("serialize")
        }

        let url = URL(fileURLWithPath: fullPath)
        do {
            try data.write(to: url, options: [.atomic])
            return .installed
        } catch {
            logger.error("Failed to write \(fullPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed("write: \(error.localizedDescription)")
        }
    }

    /// Detect whether a hook entry already carries our `baseCommand`.
    /// Checks the format-specific command field.
    private static func containsBaseCommand(
        _ entry: [String: Any],
        baseCommand: String,
        format: AgentHookFormat,
        eventName: String
    ) -> Bool {
        switch format {
        case .nested:
            guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
            return inner.contains { ($0["command"] as? String) == baseCommand }
        case .flat:
            return (entry["command"] as? String) == baseCommand
        case .copilot:
            // Copilot entries include the --event suffix so we
            // compare with the matching event name.
            let expected = "\(baseCommand) --event \(eventName)"
            return (entry["bash"] as? String) == expected
        case .claude:
            return false
        }
    }

    // MARK: - Uninstall

    /// Remove all managed hook entries from a CLI's config file and
    /// write the result back. Non-managed entries are left alone.
    /// Returns true if the file was rewritten (or was already clean).
    @discardableResult
    static func uninstall(
        cli: AgentCLIConfig,
        fileManager: FileManager = .default
    ) -> Bool {
        uninstallAt(
            configKey: cli.configKey,
            fullPath: cli.fullPath,
            fileManager: fileManager
        )
    }

    @discardableResult
    static func uninstallAt(
        configKey: String,
        fullPath: String,
        fileManager: FileManager = .default
    ) -> Bool {
        guard var root = parseJSONFile(at: fullPath, fileManager: fileManager) else {
            return true
        }
        guard var hooks = root[configKey] as? [String: Any] else {
            return true
        }
        hooks = removeManagedHookEntries(from: hooks)

        if hooks.isEmpty {
            root.removeValue(forKey: configKey)
        } else {
            root[configKey] = hooks
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return false
        }
        do {
            try data.write(to: URL(fileURLWithPath: fullPath), options: [.atomic])
            return true
        } catch {
            logger.error("uninstall write failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Install detection

    /// Returns true if the on-disk config file already contains a
    /// managed hook entry under every event in `cli.events`. Used by
    /// Phase 5.4's verifyAndRepair logic to decide whether to re-run
    /// the writer.
    static func isHooksInstalled(
        for cli: AgentCLIConfig,
        fileManager: FileManager = .default
    ) -> Bool {
        isHooksInstalledAt(
            fullPath: cli.fullPath,
            configKey: cli.configKey,
            events: cli.events,
            fileManager: fileManager
        )
    }

    /// Path-explicit variant of `isHooksInstalled` for tests and
    /// alternate install roots.
    static func isHooksInstalledAt(
        fullPath: String,
        configKey: String,
        events: [(name: String, timeout: Int, async: Bool)],
        fileManager: FileManager = .default
    ) -> Bool {
        guard let root = parseJSONFile(at: fullPath, fileManager: fileManager),
              let hooks = root[configKey] as? [String: Any]
        else {
            return false
        }
        let allPresent = events.allSatisfy { event in
            guard let entries = hooks[event.name] as? [[String: Any]] else { return false }
            return entries.contains(where: containsOurHook)
        }
        guard allPresent else { return false }
        if hasStaleAsyncKey(hooks) { return false }
        return true
    }

    // MARK: - JSONC support

    /// Parses a JSONC (or plain JSON) file, stripping `//` and
    /// `/* */` comments before invoking `JSONSerialization`. Claude
    /// Code's settings.json is technically strict JSON, but some
    /// CLI forks (Qoder in particular) ship JSONC samples to users,
    /// so we accept both to avoid clobbering hand-edited configs.
    ///
    /// Returns nil when the file is missing, unreadable, or fails
    /// to parse even after stripping.
    static func parseJSONFile(
        at path: String,
        fileManager: FileManager = .default
    ) -> [String: Any]? {
        guard fileManager.fileExists(atPath: path),
              let data = fileManager.contents(atPath: path),
              let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        let stripped = stripJSONComments(text)
        guard let parsedData = stripped.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: parsedData)
        else {
            return nil
        }
        return obj as? [String: Any]
    }

    /// Strip `//` and `/* */` comments from a JSONC string while
    /// preserving string literals (including escaped quotes).
    /// Adapted verbatim (state machine + index walking) from
    /// ConfigInstaller.swift:384-433 of upstream CodeIsland.
    static func stripJSONComments(_ input: String) -> String {
        var result = ""
        result.reserveCapacity(input.count)
        var i = input.startIndex
        let end = input.endIndex

        while i < end {
            let c = input[i]
            if c == "\"" {
                // String literal: copy as-is until matching quote,
                // respecting escaped characters.
                result.append(c)
                i = input.index(after: i)
                while i < end {
                    let sc = input[i]
                    result.append(sc)
                    if sc == "\\" {
                        i = input.index(after: i)
                        if i < end {
                            result.append(input[i])
                        }
                    } else if sc == "\"" {
                        break
                    }
                    i = input.index(after: i)
                }
                if i < end { i = input.index(after: i) }
                continue
            }

            let next = input.index(after: i)
            if c == "/" && next < end {
                let nc = input[next]
                if nc == "/" {
                    // Line comment: skip until newline.
                    i = input.index(after: next)
                    while i < end && input[i] != "\n" {
                        i = input.index(after: i)
                    }
                    continue
                } else if nc == "*" {
                    // Block comment: skip until closing */.
                    i = input.index(after: next)
                    while i < end {
                        let bi = input.index(after: i)
                        if input[i] == "*" && bi < end && input[bi] == "/" {
                            i = input.index(after: bi)
                            break
                        }
                        i = input.index(after: i)
                    }
                    continue
                }
            }

            result.append(c)
            i = input.index(after: i)
        }
        return result
    }

    // MARK: - Managed entry predicates

    /// Walks a hook dictionary and strips out every entry that
    /// belongs to AiyuTerm (current or legacy marker). Empty event
    /// arrays are removed so the resulting dictionary stays clean.
    static func removeManagedHookEntries(from hooks: [String: Any]) -> [String: Any] {
        var cleaned = hooks
        for (event, value) in cleaned {
            guard var entries = value as? [[String: Any]] else { continue }
            entries.removeAll(where: containsOurHook)
            if entries.isEmpty {
                cleaned.removeValue(forKey: event)
            } else {
                cleaned[event] = entries
            }
        }
        return cleaned
    }

    /// Detect whether a single hook entry (of any format) belongs to
    /// AiyuTerm. Matches the three command-field shapes used by
    /// Claude/nested (entry.hooks[].command), flat (entry.command),
    /// and Copilot (entry.bash).
    static func containsOurHook(_ entry: [String: Any]) -> Bool {
        if let inner = entry["hooks"] as? [[String: Any]] {
            return inner.contains {
                let cmd = ($0["command"] as? String) ?? ""
                return AgentHookIdentifier.isOurs(cmd)
            }
        }
        if let cmd = entry["command"] as? String, AgentHookIdentifier.isOurs(cmd) {
            return true
        }
        if let cmd = entry["bash"] as? String, AgentHookIdentifier.isOurs(cmd) {
            return true
        }
        return false
    }

    /// Detect legacy `async` field smuggled into hook entries. Older
    /// CodeIsland builds added `async: true` at the inner hook level
    /// which caused Claude Code to reject the entry. We treat any
    /// managed entry with a stale async field as "not installed" so
    /// that verifyAndRepair rewrites it clean.
    static func hasStaleAsyncKey(_ hooks: [String: Any]) -> Bool {
        for (_, value) in hooks {
            guard let entries = value as? [[String: Any]] else { continue }
            for entry in entries where containsOurHook(entry) {
                if let inner = entry["hooks"] as? [[String: Any]] {
                    // CodeIsland's async flag lived at the inner
                    // hook level, not at the outer entry level.
                    // Anything with a boolean "async" here is stale
                    // from our perspective UNLESS it matches the
                    // value we would write today. We normalize by
                    // always treating stale entries as rewrite-
                    // candidates when the key exists on hooks that
                    // upstream considered non-async; the writer
                    // flattens the distinction on re-install.
                    if inner.contains(where: { $0["async"] is Bool }) {
                        // Only count as stale if the async flag
                        // differs from what our registry would
                        // produce for this event. The cheap cut:
                        // treat any async flag on an entry whose
                        // command path doesn't match ours as stale.
                        let cmds = inner.compactMap { $0["command"] as? String }
                        if !cmds.contains(where: AgentHookIdentifier.isOurs) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
}
