//
//  UIState.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

enum LineyFeatureFlags {
    // TODO: Re-enable after the SSH / agent session flows have a defined QA plan.
    static let showsRemoteSessionCreationUI = false
}

struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum WorkspaceStatusTone {
    case neutral
    case success
    case warning
}

struct WorkspaceStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let tone: WorkspaceStatusTone
}

struct WorkspaceSettingsRequest: Identifiable {
    let id = UUID()
    let workspaceID: UUID?
}

enum SidebarIconCustomizationTarget: Hashable {
    case workspace(UUID)
    case worktree(workspaceID: UUID, worktreePath: String)
    case appDefaultRepository
    case appDefaultLocalTerminal
    case appDefaultWorktree
}

struct SidebarIconCustomizationRequest: Identifiable {
    let id = UUID()
    let target: SidebarIconCustomizationTarget
}

struct RenameWorkspaceRequest: Identifiable {
    let id = UUID()
    let workspaceID: UUID
    let currentName: String
}

struct CreateWorktreeSheetRequest: Identifiable {
    let id = UUID()
    let workspaceID: UUID
    let workspaceName: String
    let repositoryRoot: String
    let localBranches: [String]
    let remoteBranches: [String]
}

struct CreateSSHSessionRequest: Identifiable {
    let id = UUID()
    let workspaceID: UUID
    let workspaceName: String
    let defaultWorkingDirectory: String
}

struct CreateAgentSessionRequest: Identifiable {
    // TODO: Keep the request models wired while the UI entry points stay hidden behind the feature flag above.
    let id = UUID()
    let workspaceID: UUID
    let workspaceName: String
    let defaultWorkingDirectory: String
    let presets: [AgentPreset]
    let preferredPresetID: UUID?
}

struct PendingWorktreeSwitch: Identifiable {
    let id = UUID()
    let workspaceID: UUID
    let targetPath: String
    let targetName: String
    let runningPaneCount: Int
    let requestedAction: PendingWorktreeAction
}

struct PendingWorktreeRemoval: Identifiable {
    let id = UUID()
    let workspaceID: UUID
    let worktreePaths: [String]
    let worktreeNames: [String]
    let activePaneCount: Int
    let includesActiveWorktree: Bool
    let dirtyWorktreeNames: [String]
    let dirtyFileCount: Int
    let aheadWorktreeNames: [String]
    let aheadCommitCount: Int

    var itemCount: Int {
        worktreePaths.count
    }

    var summaryName: String {
        if itemCount == 1 {
            return worktreeNames.first ?? "worktree"
        }
        return "\(itemCount) worktrees"
    }

    var allowsForceRemove: Bool {
        dirtyFileCount > 0
    }

    var detailMessage: String {
        var parts = [
            "This removes \(summaryName) from disk with `git worktree remove`."
        ]

        if includesActiveWorktree {
            parts.append("Liney will switch back to the main checkout first.")
        }
        if activePaneCount > 0 {
            parts.append("\(activePaneCount) running pane(s) in the selected worktree path(s) will be terminated first.")
        }
        if dirtyFileCount > 0 {
            parts.append("Uncommitted changes detected in \(formattedNames(dirtyWorktreeNames)) (\(dirtyFileCount) file(s)).")
        }
        if aheadCommitCount > 0 {
            parts.append("Unpushed commits detected in \(formattedNames(aheadWorktreeNames)) (\(aheadCommitCount) commit(s) ahead).")
        }

        return parts.joined(separator: " ")
    }

    private func formattedNames(_ names: [String]) -> String {
        let uniqueNames = Array(Set(names)).sorted()
        if uniqueNames.isEmpty {
            return "the selected worktree(s)"
        }
        if uniqueNames.count == 1 {
            return uniqueNames[0]
        }
        if uniqueNames.count == 2 {
            return "\(uniqueNames[0]) and \(uniqueNames[1])"
        }
        return "\(uniqueNames[0]), \(uniqueNames[1]), and \(uniqueNames.count - 2) more"
    }
}

struct CreateWorktreeDraft {
    var directoryPath: String = ""
    var branchName: String = ""
    var createNewBranch: Bool = true
    var createFromRemoteBranch: Bool = false

    var normalizedBranchName: String {
        branchName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedDirectoryPath: String {
        directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CreateSSHSessionDraft {
    var host: String = ""
    var user: String = ""
    var port: String = ""
    var identityFilePath: String = ""
    var remoteWorkingDirectory: String = ""
    var remoteCommand: String = ""
    var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var configuration: SSHSessionConfiguration? {
        let host = normalizedHost
        guard !host.isEmpty else { return nil }
        return SSHSessionConfiguration(
            host: host,
            user: user.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            port: Int(port.trimmingCharacters(in: .whitespacesAndNewlines)),
            identityFilePath: identityFilePath.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            remoteWorkingDirectory: remoteWorkingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            remoteCommand: remoteCommand.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}

struct CreateAgentSessionDraft {
    var name: String = "Agent"
    var launchPath: String = "/usr/bin/env"
    var argumentsText: String = "codex\nresume"
    var environmentText: String = ""
    var workingDirectory: String = ""
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Agent"
    }

    var normalizedLaunchPath: String {
        launchPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedWorkingDirectory: String? {
        workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var arguments: [String] {
        argumentsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var environment: [String: String] {
        environmentText
            .split(whereSeparator: \.isNewline)
            .reduce(into: [:]) { result, line in
                let value = String(line)
                guard let separatorIndex = value.firstIndex(of: "=") else { return }
                let key = String(value[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let environmentValue = String(value[value.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return }
                result[key] = environmentValue
            }
    }

    var configuration: AgentSessionConfiguration? {
        let launchPath = normalizedLaunchPath
        guard !launchPath.isEmpty else { return nil }
        return AgentSessionConfiguration(
            name: normalizedName,
            launchPath: launchPath,
            arguments: arguments,
            environment: environment,
            workingDirectory: normalizedWorkingDirectory
        )
    }

    mutating func apply(preset: AgentPreset) {
        name = preset.name
        launchPath = preset.launchPath
        argumentsText = preset.arguments.joined(separator: "\n")
        environmentText = preset.environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
        workingDirectory = preset.workingDirectory ?? ""
    }
}

enum PendingWorktreeAction: String, Codable {
    case none
    case newSession
    case splitVertical
    case splitHorizontal

    var displayLabel: String {
        switch self {
        case .none:
            return "switch worktree"
        case .newSession:
            return "open a new session"
        case .splitVertical:
            return "split right"
        case .splitHorizontal:
            return "split down"
        }
    }
}
