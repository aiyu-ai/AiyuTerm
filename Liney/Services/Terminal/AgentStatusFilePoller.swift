//
//  AgentStatusFilePoller.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

/// Polls /tmp/liney-agent-status/<tty> files written by Claude Code hooks.
/// Used for regular (non-tmux) workspaces where OSC 9 is the primary detection,
/// but hooks provide more reliable task completion notifications.
@MainActor
final class AgentStatusFilePoller {

    private static let statusDir = "/tmp/liney-agent-status"

    private struct Registration {
        weak var session: ShellSession?
        let pid: Int32
    }

    private var registrations: [UUID: Registration] = [:]
    private var timer: Timer?

    func register(session: ShellSession) {
        guard let pid = session.pid else { return }
        registrations[session.id] = Registration(session: session, pid: pid)
        ensureTimerRunning()
    }

    func unregister(sessionID: UUID) {
        registrations.removeValue(forKey: sessionID)
        if registrations.isEmpty {
            timer?.invalidate()
            timer = nil
        }
    }

    private func ensureTimerRunning() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    private func poll() {
        for (_, registration) in registrations {
            guard let session = registration.session else { continue }
            guard let ttyName = Self.ttyName(forPID: registration.pid) else { continue }
            let path = "\(Self.statusDir)/\(ttyName)"
            guard let content = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) else { continue }

            let status = Self.parseStatusValue(content)
            if status != .none && status != session.agentStatus {
                session.agentStatus = status
                // Remove file after reading to avoid stale state
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    /// Parse "status:timestamp" format written by the hook script.
    private static func parseStatusValue(_ value: String) -> AgentSessionStatus {
        let parts = value.split(separator: ":", maxSplits: 1)
        let statusString = parts.first.map(String.init) ?? value

        if parts.count == 2, let timestamp = TimeInterval(parts[1]) {
            let age = Date().timeIntervalSince1970 - timestamp
            if age > 30 { return .none }
        }

        switch statusString {
        case "permission": return .permissionNeeded
        case "completed": return .taskCompleted
        case "error": return .error
        default: return .none
        }
    }

    /// Get the TTY name for a PID (e.g., "ttys042").
    private static func ttyName(forPID pid: Int32) -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "tty="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard let data = try? pipe.fileHandleForReading.availableData,
              let output = String(data: data, encoding: .utf8) else { return nil }
        let tty = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return tty.isEmpty || tty == "??" ? nil : tty
    }
}
