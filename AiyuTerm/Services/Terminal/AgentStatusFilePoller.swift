//
//  AgentStatusFilePoller.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import CommonCrypto
import Foundation

/// Polls /tmp/aiyuterm-agent-status/<dir-hash> files written by Claude Code hooks.
/// Matches status files to workspaces by hashing the working directory path.
@MainActor
final class AgentStatusFilePoller {

    private static let statusDir = "/tmp/aiyuterm-agent-status"

    /// Provide workspaces dynamically so we always scan current state.
    var workspacesProvider: (() -> [WorkspaceModel])?
    private var timer: Timer?

    func startIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let workspaces = workspacesProvider?() else { return }
        for workspace in workspaces where !workspace.settings.isTmuxManaged {
            let dirHash = Self.md5Prefix(workspace.activeWorktreePath, length: 16)
            let path = "\(Self.statusDir)/\(dirHash)"
            guard let content = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) else { continue }

            let status = Self.parseStatusValue(content)
            // Remove file after reading to avoid stale re-reads
            try? FileManager.default.removeItem(atPath: path)

            guard status != .none else { continue }
            for session in workspace.sessionController.sessions.values where session.agentStatus != status {
                session.agentStatus = status
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

    /// First 16 chars of MD5 hex digest, matching the hook script's `md5 | head -c 16`.
    private static func md5Prefix(_ string: String, length: Int) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(length))
    }
}
