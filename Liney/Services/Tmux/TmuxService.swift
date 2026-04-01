//
//  TmuxService.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

enum TmuxService {

    private static let runner = ShellCommandRunner()

    // MARK: - Query

    static func isTmuxAvailable() async -> Bool {
        do {
            let result = try await runner.run(executable: "/usr/bin/env", arguments: ["which", "tmux"])
            return result.exitCode == 0
        } catch {
            return false
        }
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
        guard isValidSessionID(sessionID) else { return nil }
        return ["-lc", "tmux set-option -g allow-passthrough on \\; set-option -g mouse on \\; attach -t '\(sessionID)'"]
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

    // MARK: - Internal

    @discardableResult
    private static func runTmux(arguments: [String]) async throws -> ShellCommandResult {
        let result: ShellCommandResult
        do {
            result = try await runner.run(executable: "/usr/bin/env", arguments: ["tmux"] + arguments)
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
