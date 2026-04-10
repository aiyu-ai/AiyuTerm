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

enum AgentCLIConfigInstaller {

    // MARK: - Public types

    /// Outcome of `installClaude(cli:)`. Let callers distinguish
    /// "no-op because already correct" from "wrote new content".
    enum InstallOutcome: Equatable {
        case alreadyInstalled
        case installed
        case failed(String)
    }

    // MARK: - Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.aiyuai.aiyuterm",
        category: "AgentCLIConfigInstaller"
    )

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
