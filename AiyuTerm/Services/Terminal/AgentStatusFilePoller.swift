//
//  AgentStatusFilePoller.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import CommonCrypto
import Foundation

/// Watches /tmp/aiyuterm-agent-status/ for status files written by Claude Code hooks.
/// Uses DispatchSource directory monitoring for near-instant (<100ms) detection,
/// with a 3s timer as fallback in case FSEvents misses an event.
@MainActor
final class AgentStatusFilePoller {

    private static let statusDir = "/tmp/aiyuterm-agent-status"

    /// Provide workspaces dynamically so we always scan current state.
    var workspacesProvider: (() -> [WorkspaceModel])?

    private var timer: Timer?
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1

    func startIfNeeded() {
        guard timer == nil else { return }
        // Primary: directory monitor for near-instant detection
        startDirectoryMonitor()
        // Fallback: 3s timer in case FSEvents misses an event
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopDirectoryMonitor()
    }

    // MARK: - Directory Monitor (DispatchSource)

    private func startDirectoryMonitor() {
        // Ensure directory exists
        try? FileManager.default.createDirectory(
            atPath: Self.statusDir,
            withIntermediateDirectories: true
        )

        let fd = open(Self.statusDir, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        directorySource = source
    }

    private func stopDirectoryMonitor() {
        directorySource?.cancel()
        directorySource = nil
        directoryFD = -1
    }

    // MARK: - Poll (shared by monitor and timer)

    private func poll() {
        guard let workspaces = workspacesProvider?() else { return }
        for workspace in workspaces where !workspace.settings.isTmuxManaged {
            for worktree in workspace.worktrees {
                let dirHash = Self.md5Prefix(worktree.path, length: 16)
                let path = "\(Self.statusDir)/\(dirHash)"
                guard let content = try? String(contentsOfFile: path, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines) else { continue }

                let status = Self.parseStatusValue(content)
                try? FileManager.default.removeItem(atPath: path)

                guard status != .none else { continue }
                if status == .taskCompleted {
                    workspace.markCompletionUnread(forWorktreePath: worktree.path)
                }
                if status == .permissionNeeded {
                    workspace.markPermissionUnread(forWorktreePath: worktree.path)
                }
                if status == .working {
                    workspace.markCompletionRead(forWorktreePath: worktree.path)
                    workspace.markPermissionRead(forWorktreePath: worktree.path)
                }
                workspace.setAgentStatus(status, forWorktreePath: worktree.path)
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
        case "working": return .working
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
