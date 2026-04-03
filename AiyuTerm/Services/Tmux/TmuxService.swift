//
//  TmuxService.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

enum TmuxService {

    private static let runner = ShellCommandRunner()

    private static let tmuxSearchPaths = [
        "/opt/homebrew/bin/tmux",
        "/usr/local/bin/tmux",
        "/usr/bin/tmux",
    ]

    private static var resolvedTmuxPath: String?

    // MARK: - Query

    static func isTmuxAvailable() async -> Bool {
        if resolvedTmuxPath != nil { return true }
        for path in tmuxSearchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                resolvedTmuxPath = path
                return true
            }
        }
        // Fallback: try shell lookup (works when launched from terminal)
        do {
            let result = try await runner.run(executable: "/usr/bin/env", arguments: ["which", "tmux"])
            if result.exitCode == 0 {
                let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty {
                    resolvedTmuxPath = path
                    return true
                }
            }
        } catch {}
        return false
    }

    static func listSessions() async throws -> [TmuxSession] {
        do {
            let result = try await runTmux(arguments: [
                "list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_attached}\t#{session_windows}"
            ])
            return parseSessions(from: result.stdout)
        } catch TmuxError.noServerRunning {
            return []
        }
    }

    // MARK: - Session operations

    static func createSession(name: String) async throws {
        guard TmuxSessionNameValidator.isValid(name) else {
            throw TmuxError.invalidSessionName(name)
        }
        try await runTmux(arguments: ["new-session", "-d", "-s", name])
    }

    static func killSession(sessionID: String) async throws {
        try await runTmux(arguments: ["kill-session", "-t", sessionID])
    }

    static func renameSession(sessionID: String, newName: String) async throws {
        guard TmuxSessionNameValidator.isValid(newName) else {
            throw TmuxError.invalidSessionName(newName)
        }
        try await runTmux(arguments: ["rename-session", "-t", sessionID, newName])
    }

    static func detachSession(sessionID: String) async throws {
        try await runTmux(arguments: ["detach-client", "-t", sessionID])
    }

    // MARK: - Attach

    static func attachArguments(sessionID: String) -> [String]? {
        guard isValidSessionID(sessionID), let tmuxPath = resolvedTmuxPath else { return nil }
        return ["-lc", "\(tmuxPath) set-option -g allow-passthrough on \\; set-option -g mouse on \\; attach -t '\(sessionID)'"]
    }

    static func isValidSessionID(_ id: String) -> Bool {
        id.range(of: #"^\$\d+$"#, options: .regularExpression) != nil
    }

    // MARK: - Parsing

    static func parseSessions(from output: String) -> [TmuxSession] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 3).map(String.init)
            guard parts.count == 4,
                  let attached = Int(parts[2]),
                  let windowCount = Int(parts[3]) else { return nil }
            return TmuxSession(
                sessionID: parts[0],
                name: parts[1],
                isAttached: attached > 0,
                windowCount: windowCount
            )
        }
    }

    // MARK: - Pane Inspection

    /// Captures the visible pane content (no scrollback history).
    static func capturePaneContent(sessionID: String) async throws -> String {
        guard isValidSessionID(sessionID) else { throw TmuxError.commandFailed("Invalid session ID") }
        let result = try await runTmux(arguments: ["capture-pane", "-p", "-t", sessionID])
        return result.stdout
    }

    /// Reads a user-defined pane option set by Claude Code hooks.
    static func paneOption(sessionID: String, option: String) async throws -> String? {
        guard isValidSessionID(sessionID) else { return nil }
        let result = try await runTmux(arguments: [
            "display-message", "-p", "-t", sessionID, "#{@\(option)}"
        ])
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Clears a user-defined pane option.
    static func clearPaneOption(sessionID: String, option: String) async throws {
        guard isValidSessionID(sessionID) else { return }
        try await runTmux(arguments: ["set-option", "-up", "-t", sessionID, "@\(option)"])
    }

    // MARK: - Internal

    @discardableResult
    private static func runTmux(arguments: [String]) async throws -> ShellCommandResult {
        guard let tmuxPath = resolvedTmuxPath else {
            throw TmuxError.notInstalled
        }
        let result: ShellCommandResult
        do {
            result = try await runner.run(executable: tmuxPath, arguments: arguments)
        } catch {
            throw TmuxError.commandFailed(error.localizedDescription)
        }
        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("no server running") || message.contains("No such file or directory") {
                throw TmuxError.noServerRunning
            }
            if message.contains("not found") {
                throw TmuxError.notInstalled
            }
            throw TmuxError.commandFailed(message)
        }
        return result
    }
}
