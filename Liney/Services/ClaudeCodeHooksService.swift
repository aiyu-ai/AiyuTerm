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

    /// Returns true when both Stop and Notification hook arrays in
    /// ~/.claude/settings.json contain an entry whose command references
    /// "aiyuterm".
    static func isConfigured() -> Bool {
        guard let root = loadClaudeSettings() else { return false }
        guard let hooks = root["hooks"] as? [String: Any] else { return false }
        let stopConfigured = arrayContainsAiyuTerm(hooks["Stop"] as? [[String: Any]])
        let notificationConfigured = arrayContainsAiyuTerm(hooks["Notification"] as? [[String: Any]])
        return stopConfigured && notificationConfigured
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

        for key in ["Stop", "Notification"] {
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
  Stop) STATUS="completed" ;;
  Notification)
    NTYPE=$(echo "$INPUT" | grep -o '"notification_type":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    case "$NTYPE" in
      permission_prompt) STATUS="permission" ;;
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
