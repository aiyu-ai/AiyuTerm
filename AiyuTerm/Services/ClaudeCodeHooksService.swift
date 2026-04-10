//
//  ClaudeCodeHooksService.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

/// Manages Claude Code hook script generation and settings.json integration.
///
/// The service provides two capabilities:
/// 1. Generating a hook script that forwards Claude Code events to AiyuTerm
///    via tmux pane options and /tmp status files.
/// 2. Injecting hook entries into ~/.claude/settings.json so Claude Code
///    invokes the script on Stop and Notification events.
enum ClaudeCodeHooksService {

    // MARK: - Public API

    /// Ensures the hook script exists at the expected path, creating or
    /// overwriting it to keep the latest version. Called on app launch.
    static func ensureHookScript() {
        let scriptURL = hookScriptURL()
        let directory = scriptURL.deletingLastPathComponent()
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try hookScriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            // chmod +x
            try fm.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            print("[ClaudeCodeHooksService] Failed to write hook script: \(error)")
        }
    }

    /// All Claude Code hook events that AiyuTerm needs to receive via
    /// the legacy shell-script / file-polling path.
    private static let requiredHookEvents = [
        "UserPromptSubmit",  // -> working (agent starts processing)
        "Stop",              // -> completed (agent finished responding)
        "StopFailure",       // -> error (agent encountered an error)
        "Notification",      // -> permission (via notification_type: permission_prompt)
    ]

    /// Extended event list covered by the Phase 4 bridge hook. Adds the
    /// tool-use and permission-request events that Phase 3's mapper can
    /// consume to produce richer badge transitions.
    private static let bridgeHookEvents: [(name: String, timeout: Int)] = [
        ("UserPromptSubmit",    5),
        ("PreToolUse",          5),
        ("PostToolUse",         5),
        ("PostToolUseFailure",  5),
        ("Stop",                5),
        ("StopFailure",         5),
        ("Notification",        86400),
        ("PermissionRequest",   86400),
        ("PermissionDenied",    5),
        ("SessionStart",        5),
        ("SessionEnd",          5),
    ]

    /// Returns true when all required hook events in ~/.claude/settings.json
    /// contain an entry whose command references "aiyuterm".
    static func isConfigured() -> Bool {
        guard let root = loadClaudeSettings() else { return false }
        guard let hooks = root["hooks"] as? [String: Any] else { return false }
        return requiredHookEvents.allSatisfy { event in
            arrayContainsAiyuTerm(hooks[event] as? [[String: Any]])
        }
    }

    /// Injects AiyuTerm hook entries into ~/.claude/settings.json.
    /// Returns true on success.
    @discardableResult
    static func injectHooks() -> Bool {
        let settingsURL = claudeSettingsURL()
        let fm = FileManager.default

        // Ensure ~/.claude/ directory exists
        let claudeDir = settingsURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        } catch {
            print("[ClaudeCodeHooksService] Failed to create .claude directory: \(error)")
            return false
        }

        // Backup existing settings before modification
        let backupURL = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.aiyuterm-backup")
        if fm.fileExists(atPath: settingsURL.path) {
            try? fm.copyItem(at: settingsURL, to: backupURL)
        }

        var root: [String: Any]
        if let existing = loadClaudeSettings() {
            root = existing
        } else {
            root = [:]
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let scriptPath = hookScriptURL().path
        let entry: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": scriptPath, "timeout": 5]
            ]
        ]

        for key in requiredHookEvents {
            var arr = hooks[key] as? [[String: Any]] ?? []
            if !arrayContainsAiyuTerm(arr) {
                arr.append(entry)
            }
            hooks[key] = arr
        }

        root["hooks"] = hooks

        do {
            let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
            let data = try JSONSerialization.data(withJSONObject: root, options: options)
            try data.write(to: settingsURL, options: .atomic)
            return true
        } catch {
            print("[ClaudeCodeHooksService] Failed to write settings.json: \(error)")
            return false
        }
    }

    // MARK: - Phase 4: Bridge hook installation

    /// Version tag embedded in the bridge hook script. Bump this when
    /// the script content changes so `ensureBridgeHookScript()` knows
    /// to overwrite existing copies on disk.
    static let bridgeHookScriptVersion = 1

    /// Path to the small bash wrapper that invokes the bridge binary.
    static func bridgeHookScriptURL() -> URL {
        aiyuTermStateDirectoryURL()
            .appendingPathComponent("hooks", isDirectory: true)
            .appendingPathComponent("claude-code-bridge-hook.sh")
    }

    /// Path to the aiyuterm-hook-bridge binary inside the app bundle.
    /// The Phase 2 Copy Files build phase embeds it here.
    static func bridgeBinaryURL() -> URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/aiyuterm-hook-bridge")
    }

    /// Writes the bridge wrapper script if missing or out-of-date.
    /// Idempotent: subsequent calls only touch disk when the on-disk
    /// file is absent, stale, or has drifted from the version string
    /// we embed.
    static func ensureBridgeHookScript() {
        let url = bridgeHookScriptURL()
        let dir = url.deletingLastPathComponent()
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("[ClaudeCodeHooksService] Failed to create bridge hook dir: \(error)")
            return
        }

        let content = bridgeHookScriptContent
        if let existing = try? String(contentsOf: url, encoding: .utf8),
           existing == content
        {
            return
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: url.path
            )
        } catch {
            print("[ClaudeCodeHooksService] Failed to write bridge hook: \(error)")
        }
    }

    /// Injects the bridge hook into ~/.claude/settings.json alongside
    /// the legacy hook entries. Both sets of entries coexist during the
    /// Phase 4 dual-write period so that users upgrading from the old
    /// file-polling path don't see a badge blackout. Returns true if
    /// settings.json was written successfully (including the no-op
    /// case where all bridge entries were already present).
    @discardableResult
    static func injectBridgeHooks() -> Bool {
        let settingsURL = claudeSettingsURL()
        let fm = FileManager.default

        do {
            try fm.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            print("[ClaudeCodeHooksService] Failed to create .claude dir: \(error)")
            return false
        }

        // Atomic backup before mutation. Overwrites the previous
        // backup so a broken settings.json from a past run cannot
        // masquerade as the current baseline.
        let backupURL = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.aiyuterm-bridge-backup")
        if fm.fileExists(atPath: settingsURL.path) {
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: settingsURL, to: backupURL)
        }

        var root = loadClaudeSettings() ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        let scriptPath = bridgeHookScriptURL().path

        for (eventName, timeout) in bridgeHookEvents {
            var arr = hooks[eventName] as? [[String: Any]] ?? []
            // Strip any prior bridge entries for this event (identified
            // by command path containing the bridge script filename)
            // so we can safely rewrite them with updated timeouts.
            arr = arr.compactMap { entry -> [String: Any]? in
                guard let inner = entry["hooks"] as? [[String: Any]] else { return entry }
                let filtered = inner.filter { hook in
                    guard let cmd = hook["command"] as? String else { return true }
                    return !cmd.contains("claude-code-bridge-hook.sh")
                }
                if filtered.isEmpty { return nil }
                var copy = entry
                copy["hooks"] = filtered
                return copy
            }
            // Append our fresh entry.
            let entry: [String: Any] = [
                "matcher": "",
                "hooks": [
                    [
                        "type": "command",
                        "command": scriptPath,
                        "timeout": timeout,
                    ]
                ],
            ]
            arr.append(entry)
            hooks[eventName] = arr
        }

        root["hooks"] = hooks

        do {
            let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
            let data = try JSONSerialization.data(withJSONObject: root, options: options)
            try data.write(to: settingsURL, options: .atomic)
            return true
        } catch {
            print("[ClaudeCodeHooksService] Failed to write settings.json: \(error)")
            return false
        }
    }

    /// Body of the bridge wrapper script. Keeps it minimal so that
    /// users inspecting the installed file immediately understand the
    /// indirection — the wrapper only forwards stdin into the native
    /// helper, with an nc-based socket fallback if the binary happens
    /// to be missing after a botched re-install.
    ///
    /// The socket path in the fallback branch matches
    /// `AgentHookSocketPath.path` and is written with the same
    /// `.aiyuterm` / `.aiyuterm-debug` prefix used by the running
    /// build so debug and release never cross-talk.
    private static var bridgeHookScriptContent: String {
        let bridgePath = bridgeBinaryURL().path
        let stateDir = AgentHookSocketPath.stateDirectoryName
        return """
        #!/bin/bash
        # AiyuTerm Claude Code bridge hook v\(bridgeHookScriptVersion)
        # Forwards stdin into the native aiyuterm-hook-bridge helper,
        # which enriches the payload with terminal env and sends it
        # over the Unix socket at $HOME/\(stateDir)/hook.sock.
        BRIDGE="\(bridgePath)"
        if [ -x "$BRIDGE" ]; then
          exec "$BRIDGE" "$@"
        fi
        # Fallback: the binary is missing (e.g. user reinstalled
        # AiyuTerm and the copy-files phase didn't run). Try to deliver
        # the event via nc so we don't lose it entirely.
        SOCK="$HOME/\(stateDir)/hook.sock"
        [ -S "$SOCK" ] || exit 0
        INPUT=$(cat)
        echo "$INPUT" | nc -U -w 2 "$SOCK" 2>/dev/null || true
        exit 0
        """
    }

    // MARK: - Paths

    private static func hookScriptURL() -> URL {
        let stateDir = aiyuTermStateDirectoryURL()
        return stateDir
            .appendingPathComponent("hooks", isDirectory: true)
            .appendingPathComponent("agent-status-notify.sh")
    }

    private static func claudeSettingsURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    // MARK: - Helpers

    private static func loadClaudeSettings() -> [String: Any]? {
        let url = claudeSettingsURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return obj as? [String: Any]
    }

    /// Checks whether any entry in the hook array has a command containing
    /// "aiyuterm" (case-insensitive).
    private static func arrayContainsAiyuTerm(_ entries: [[String: Any]]?) -> Bool {
        guard let entries else { return false }
        for entry in entries {
            guard let hooks = entry["hooks"] as? [[String: Any]] else { continue }
            for hook in hooks {
                if let command = hook["command"] as? String,
                   command.localizedCaseInsensitiveContains("aiyuterm") {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Hook Script

    // swiftlint:disable:next line_length
    private static let hookScriptContent = """
#!/bin/bash
set -euo pipefail
INPUT=$(cat)
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
case "$EVENT" in
  UserPromptSubmit) STATUS="working" ;;
  Stop) STATUS="completed" ;;
  StopFailure) STATUS="error" ;;
  Notification)
    NTYPE=$(echo "$INPUT" | grep -o '"notification_type":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    case "$NTYPE" in
      permission_prompt|idle_prompt) STATUS="permission" ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac
TIMESTAMP=$(date +%s)
if [ -n "${TMUX:-}" ]; then
  tmux set-option -p @aiyuterm_agent_status "${STATUS}:${TIMESTAMP}" 2>/dev/null || true
fi
CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
if [ -z "$CWD" ]; then CWD="$PWD"; fi
DIR_HASH=$(echo -n "$CWD" | md5 | head -c 16)
mkdir -p /tmp/aiyuterm-agent-status
echo "${STATUS}:${TIMESTAMP}" > "/tmp/aiyuterm-agent-status/${DIR_HASH}"
exit 0
"""
}
