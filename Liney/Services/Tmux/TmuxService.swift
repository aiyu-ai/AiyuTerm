//
//  TmuxService.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

enum TmuxService {

    static let tmuxExecutablePath = "/usr/bin/env"

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
        let result = try await runTmux(arguments: [
            "list-sessions", "-F", "#{session_name}\t#{session_attached}\t#{session_windows}"
        ])
        return parseSessions(from: result.stdout)
    }

    static func listWindows(session: String) async throws -> [TmuxWindow] {
        let result = try await runTmux(arguments: [
            "list-windows", "-t", session, "-F", "#{window_index}\t#{window_name}\t#{window_active}"
        ])
        return parseWindows(from: result.stdout, sessionName: session)
    }

    // MARK: - Session operations

    static func createSession(name: String) async throws {
        try await runTmux(arguments: ["new-session", "-d", "-s", name])
    }

    static func killSession(name: String) async throws {
        try await runTmux(arguments: ["kill-session", "-t", name])
    }

    static func renameSession(oldName: String, newName: String) async throws {
        try await runTmux(arguments: ["rename-session", "-t", oldName, newName])
    }

    static func detachSession(name: String) async throws {
        try await runTmux(arguments: ["detach-client", "-t", name])
    }

    // MARK: - Window operations

    static func createWindow(session: String, name: String?) async throws {
        var args = ["new-window", "-t", session]
        if let name, !name.isEmpty {
            args += ["-n", name]
        }
        try await runTmux(arguments: args)
    }

    static func killWindow(session: String, index: Int) async throws {
        try await runTmux(arguments: ["kill-window", "-t", "\(session):\(index)"])
    }

    static func renameWindow(session: String, index: Int, newName: String) async throws {
        try await runTmux(arguments: ["rename-window", "-t", "\(session):\(index)", newName])
    }

    static func moveWindow(session: String, index: Int, targetSession: String) async throws {
        try await runTmux(arguments: ["move-window", "-s", "\(session):\(index)", "-t", targetSession])
    }

    // MARK: - Attach helpers

    static func attachArguments(session: String, windowIndex: Int) -> [String] {
        let escapedSession = session.contains(" ") ? "'\(session)'" : session
        return ["-lc", "tmux attach -t \(escapedSession) \\; select-window -t \(windowIndex)"]
    }

    // MARK: - Parsing

    static func parseSessions(from output: String) -> [TmuxSession] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let attached = Int(parts[1]),
                  let windowCount = Int(parts[2]) else { return nil }
            return TmuxSession(name: parts[0], isAttached: attached > 0, windowCount: windowCount)
        }
    }

    static func parseWindows(from output: String, sessionName: String) -> [TmuxWindow] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let index = Int(parts[0]),
                  let active = Int(parts[2]) else { return nil }
            return TmuxWindow(sessionName: sessionName, index: index, name: parts[1], isActive: active > 0)
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
            if message.contains("no server running") || message.contains("not found") {
                throw TmuxError.notInstalled
            }
            throw TmuxError.commandFailed(message)
        }
        return result
    }
}
