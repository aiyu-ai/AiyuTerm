//
//  AppSettings.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

nonisolated enum SidebarIconFillStyle: String, Codable, Hashable, CaseIterable, Identifiable {
    case solid
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid:
            return "Solid"
        case .gradient:
            return "Gradient"
        }
    }
}

nonisolated enum SidebarIconPalette: String, Codable, Hashable, CaseIterable, Identifiable {
    case blue
    case cyan
    case aqua
    case ice
    case sky
    case teal
    case turquoise
    case mint
    case green
    case forest
    case lime
    case olive
    case gold
    case sand
    case bronze
    case amber
    case orange
    case copper
    case rust
    case coral
    case peach
    case brick
    case crimson
    case ruby
    case berry
    case rose
    case magenta
    case orchid
    case indigo
    case navy
    case steel
    case violet
    case iris
    case lavender
    case plum
    case slate
    case smoke
    case charcoal
    case graphite
    case mocha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue:
            return "Blue"
        case .cyan:
            return "Cyan"
        case .aqua:
            return "Aqua"
        case .ice:
            return "Ice"
        case .sky:
            return "Sky"
        case .teal:
            return "Teal"
        case .turquoise:
            return "Turquoise"
        case .mint:
            return "Mint"
        case .green:
            return "Green"
        case .forest:
            return "Forest"
        case .lime:
            return "Lime"
        case .olive:
            return "Olive"
        case .gold:
            return "Gold"
        case .sand:
            return "Sand"
        case .bronze:
            return "Bronze"
        case .amber:
            return "Amber"
        case .orange:
            return "Orange"
        case .copper:
            return "Copper"
        case .rust:
            return "Rust"
        case .coral:
            return "Coral"
        case .peach:
            return "Peach"
        case .brick:
            return "Brick"
        case .crimson:
            return "Crimson"
        case .ruby:
            return "Ruby"
        case .berry:
            return "Berry"
        case .rose:
            return "Rose"
        case .magenta:
            return "Magenta"
        case .orchid:
            return "Orchid"
        case .indigo:
            return "Indigo"
        case .navy:
            return "Navy"
        case .steel:
            return "Steel"
        case .violet:
            return "Violet"
        case .iris:
            return "Iris"
        case .lavender:
            return "Lavender"
        case .plum:
            return "Plum"
        case .slate:
            return "Slate"
        case .smoke:
            return "Smoke"
        case .charcoal:
            return "Charcoal"
        case .graphite:
            return "Graphite"
        case .mocha:
            return "Mocha"
        }
    }
}

nonisolated struct SidebarItemIcon: Codable, Hashable {
    var symbolName: String
    var palette: SidebarIconPalette
    var fillStyle: SidebarIconFillStyle

    init(
        symbolName: String,
        palette: SidebarIconPalette,
        fillStyle: SidebarIconFillStyle = .gradient
    ) {
        self.symbolName = symbolName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "square.grid.2x2.fill"
        self.palette = palette
        self.fillStyle = fillStyle
    }
}

extension SidebarItemIcon {
    nonisolated static let repositoryDefault = SidebarItemIcon(
        symbolName: "arrow.triangle.branch",
        palette: .blue,
        fillStyle: .gradient
    )

    nonisolated static let localTerminalDefault = SidebarItemIcon(
        symbolName: "terminal.fill",
        palette: .teal,
        fillStyle: .solid
    )

    nonisolated static let worktreeDefault = SidebarItemIcon(
        symbolName: "circle.fill",
        palette: .mint,
        fillStyle: .solid
    )
}

nonisolated enum ExternalEditor: String, Codable, Hashable, CaseIterable, Identifiable {
    case cursor
    case zed
    case visualStudioCode
    case visualStudioCodeInsiders
    case windsurf
    case fleet
    case xcode
    case nova
    case sublimeText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor:
            return "Cursor"
        case .zed:
            return "Zed"
        case .visualStudioCode:
            return "VS Code"
        case .visualStudioCodeInsiders:
            return "VS Code Insiders"
        case .windsurf:
            return "Windsurf"
        case .fleet:
            return "Fleet"
        case .xcode:
            return "Xcode"
        case .nova:
            return "Nova"
        case .sublimeText:
            return "Sublime Text"
        }
    }
}

struct AppSettings: Codable, Hashable {
    var autoRefreshEnabled: Bool
    var autoRefreshIntervalSeconds: Int
    var autoClosePaneOnProcessExit: Bool
    var fileWatcherEnabled: Bool
    var githubIntegrationEnabled: Bool
    var autoCheckForUpdates: Bool
    var autoDownloadUpdates: Bool
    var systemNotificationsEnabled: Bool
    var showArchivedWorkspaces: Bool
    var sidebarShowsSecondaryLabels: Bool
    var sidebarShowsWorkspaceBadges: Bool
    var sidebarShowsWorktreeBadges: Bool
    var defaultRepositoryIcon: SidebarItemIcon
    var defaultLocalTerminalIcon: SidebarItemIcon
    var defaultWorktreeIcon: SidebarItemIcon
    var preferredExternalEditor: ExternalEditor
    var quickCommandPresets: [QuickCommandPreset]
    var quickCommandRecentIDs: [String]
    var releaseChannel: ReleaseChannel
    var commandPaletteRecents: [String: TimeInterval]

    init(
        autoRefreshEnabled: Bool = true,
        autoRefreshIntervalSeconds: Int = 30,
        autoClosePaneOnProcessExit: Bool = true,
        fileWatcherEnabled: Bool = true,
        githubIntegrationEnabled: Bool = true,
        autoCheckForUpdates: Bool = true,
        autoDownloadUpdates: Bool = false,
        systemNotificationsEnabled: Bool = true,
        showArchivedWorkspaces: Bool = false,
        sidebarShowsSecondaryLabels: Bool = true,
        sidebarShowsWorkspaceBadges: Bool = true,
        sidebarShowsWorktreeBadges: Bool = true,
        defaultRepositoryIcon: SidebarItemIcon = .repositoryDefault,
        defaultLocalTerminalIcon: SidebarItemIcon = .localTerminalDefault,
        defaultWorktreeIcon: SidebarItemIcon = .worktreeDefault,
        preferredExternalEditor: ExternalEditor = .cursor,
        quickCommandPresets: [QuickCommandPreset] = QuickCommandCatalog.defaultCommands,
        quickCommandRecentIDs: [String] = [],
        releaseChannel: ReleaseChannel = .stable,
        commandPaletteRecents: [String: TimeInterval] = [:]
    ) {
        self.autoRefreshEnabled = autoRefreshEnabled
        self.autoRefreshIntervalSeconds = max(10, autoRefreshIntervalSeconds)
        self.autoClosePaneOnProcessExit = autoClosePaneOnProcessExit
        self.fileWatcherEnabled = fileWatcherEnabled
        self.githubIntegrationEnabled = githubIntegrationEnabled
        self.autoCheckForUpdates = autoCheckForUpdates
        self.autoDownloadUpdates = autoDownloadUpdates
        self.systemNotificationsEnabled = systemNotificationsEnabled
        self.showArchivedWorkspaces = showArchivedWorkspaces
        self.sidebarShowsSecondaryLabels = sidebarShowsSecondaryLabels
        self.sidebarShowsWorkspaceBadges = sidebarShowsWorkspaceBadges
        self.sidebarShowsWorktreeBadges = sidebarShowsWorktreeBadges
        self.defaultRepositoryIcon = defaultRepositoryIcon
        self.defaultLocalTerminalIcon = defaultLocalTerminalIcon
        self.defaultWorktreeIcon = defaultWorktreeIcon
        self.preferredExternalEditor = preferredExternalEditor
        self.quickCommandPresets = QuickCommandCatalog.normalizedCommands(quickCommandPresets)
        self.quickCommandRecentIDs = QuickCommandCatalog.normalizedRecentCommandIDs(
            quickCommandRecentIDs,
            availableCommands: self.quickCommandPresets
        )
        self.releaseChannel = releaseChannel
        self.commandPaletteRecents = commandPaletteRecents
    }
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case autoRefreshEnabled
        case autoRefreshIntervalSeconds
        case autoClosePaneOnProcessExit
        case fileWatcherEnabled
        case githubIntegrationEnabled
        case autoCheckForUpdates
        case autoDownloadUpdates
        case systemNotificationsEnabled
        case showArchivedWorkspaces
        case sidebarShowsSecondaryLabels
        case sidebarShowsWorkspaceBadges
        case sidebarShowsWorktreeBadges
        case defaultRepositoryIcon
        case defaultLocalTerminalIcon
        case defaultWorktreeIcon
        case preferredExternalEditor
        case quickCommandPresets
        case quickCommandRecentIDs
        case releaseChannel
        case commandPaletteRecents
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preferredExternalEditor: ExternalEditor
        if let rawValue = try container.decodeIfPresent(String.self, forKey: .preferredExternalEditor),
           let decoded = ExternalEditor(rawValue: rawValue) {
            preferredExternalEditor = decoded
        } else {
            preferredExternalEditor = .cursor
        }
        self.init(
            autoRefreshEnabled: try container.decodeIfPresent(Bool.self, forKey: .autoRefreshEnabled) ?? true,
            autoRefreshIntervalSeconds: try container.decodeIfPresent(Int.self, forKey: .autoRefreshIntervalSeconds) ?? 30,
            autoClosePaneOnProcessExit: try container.decodeIfPresent(Bool.self, forKey: .autoClosePaneOnProcessExit) ?? true,
            fileWatcherEnabled: try container.decodeIfPresent(Bool.self, forKey: .fileWatcherEnabled) ?? true,
            githubIntegrationEnabled: try container.decodeIfPresent(Bool.self, forKey: .githubIntegrationEnabled) ?? true,
            autoCheckForUpdates: try container.decodeIfPresent(Bool.self, forKey: .autoCheckForUpdates) ?? true,
            autoDownloadUpdates: try container.decodeIfPresent(Bool.self, forKey: .autoDownloadUpdates) ?? false,
            systemNotificationsEnabled: try container.decodeIfPresent(Bool.self, forKey: .systemNotificationsEnabled) ?? true,
            showArchivedWorkspaces: try container.decodeIfPresent(Bool.self, forKey: .showArchivedWorkspaces) ?? false,
            sidebarShowsSecondaryLabels: try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsSecondaryLabels) ?? true,
            sidebarShowsWorkspaceBadges: try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsWorkspaceBadges) ?? true,
            sidebarShowsWorktreeBadges: try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsWorktreeBadges) ?? true,
            defaultRepositoryIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .defaultRepositoryIcon) ?? .repositoryDefault,
            defaultLocalTerminalIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .defaultLocalTerminalIcon) ?? .localTerminalDefault,
            defaultWorktreeIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .defaultWorktreeIcon) ?? .worktreeDefault,
            preferredExternalEditor: preferredExternalEditor,
            quickCommandPresets: try container.decodeIfPresent([QuickCommandPreset].self, forKey: .quickCommandPresets) ?? QuickCommandCatalog.defaultCommands,
            quickCommandRecentIDs: try container.decodeIfPresent([String].self, forKey: .quickCommandRecentIDs) ?? [],
            releaseChannel: try container.decodeIfPresent(ReleaseChannel.self, forKey: .releaseChannel) ?? .stable,
            commandPaletteRecents: try container.decodeIfPresent([String: TimeInterval].self, forKey: .commandPaletteRecents) ?? [:]
        )
    }
}

nonisolated struct GitHubAuthStatus: Codable, Hashable {
    var username: String
    var host: String
}

nonisolated struct GitHubPullRequestActor: Codable, Hashable, Identifiable {
    var login: String

    var id: String { login }
}

nonisolated struct GitHubPullRequestReviewSummary: Codable, Hashable, Identifiable {
    var author: GitHubPullRequestActor?
    var state: String
    var submittedAt: String?

    var id: String {
        [author?.login ?? "", state, submittedAt ?? ""].joined(separator: "|")
    }

    var normalizedState: String {
        state.uppercased()
    }
}

nonisolated struct GitHubPullRequestSummary: Codable, Hashable {
    var number: Int
    var title: String
    var url: String
    var state: String
    var isDraft: Bool
    var headRefName: String?
    var mergeStateStatus: String?
    var reviewDecision: String?
    var reviewRequests: [GitHubPullRequestActor]
    var latestReviews: [GitHubPullRequestReviewSummary]
    var assignees: [GitHubPullRequestActor]

    var isOpen: Bool {
        state.uppercased() == "OPEN"
    }

    var mergeReadiness: GitHubMergeReadiness {
        guard isOpen else { return .closed }
        if isDraft {
            return .draft
        }

        let review = (reviewDecision ?? "").uppercased()
        if review == "CHANGES_REQUESTED" {
            return .changesRequested
        }

        switch (mergeStateStatus ?? "").uppercased() {
        case "CLEAN", "HAS_HOOKS":
            return .ready
        case "BEHIND":
            return .behind
        case "BLOCKED":
            return .blocked
        case "DIRTY":
            return .conflicted
        case "UNKNOWN", "":
            return .checking
        default:
            return .blocked
        }
    }

    var requestedReviewerLogins: [String] {
        Self.uniqueLogins(reviewRequests.map(\.login))
    }

    var assigneeLogins: [String] {
        Self.uniqueLogins(assignees.map(\.login))
    }

    var changesRequestedByLogins: [String] {
        Self.uniqueLogins(
            latestReviews.compactMap { review in
                review.normalizedState == "CHANGES_REQUESTED" ? review.author?.login : nil
            }
        )
    }

    var approvedByLogins: [String] {
        Self.uniqueLogins(
            latestReviews.compactMap { review in
                review.normalizedState == "APPROVED" ? review.author?.login : nil
            }
        )
    }

    var needsReviewerAttention: Bool {
        !requestedReviewerLogins.isEmpty || !changesRequestedByLogins.isEmpty
    }

    private static func uniqueLogins(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }
}

nonisolated enum GitHubMergeReadiness: String, Codable, Hashable {
    case ready
    case draft
    case changesRequested
    case behind
    case conflicted
    case blocked
    case checking
    case closed

    var label: String {
        switch self {
        case .ready:
            return "ready"
        case .draft:
            return "draft"
        case .changesRequested:
            return "changes"
        case .behind:
            return "behind"
        case .conflicted:
            return "conflict"
        case .blocked:
            return "blocked"
        case .checking:
            return "checking"
        case .closed:
            return "closed"
        }
    }
}

nonisolated struct GitHubPullRequestCheck: Codable, Hashable, Identifiable {
    var id: String { [name, workflow ?? "", state, link ?? ""].joined(separator: "|") }
    var name: String
    var workflow: String?
    var state: String
    var bucket: String
    var link: String?
    var description: String?

    var isFailing: Bool {
        bucket == "fail" || bucket == "cancel"
    }

    var isPending: Bool {
        bucket == "pending"
    }
}

nonisolated struct GitHubPullRequestChecksSummary: Codable, Hashable {
    var passingCount: Int
    var failingCount: Int
    var pendingCount: Int
    var skippedCount: Int
    var failingChecks: [GitHubPullRequestCheck]

    static let empty = GitHubPullRequestChecksSummary(
        passingCount: 0,
        failingCount: 0,
        pendingCount: 0,
        skippedCount: 0,
        failingChecks: []
    )

    var compactLabel: String? {
        let parts = [
            failingCount > 0 ? "\(failingCount)f" : nil,
            pendingCount > 0 ? "\(pendingCount)p" : nil,
            passingCount > 0 ? "\(passingCount)ok" : nil,
        ].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }
}

nonisolated struct GitHubWorkflowRunSummary: Codable, Hashable {
    var id: Int
    var name: String
    var title: String
    var status: String
    var conclusion: String?
    var url: String?

    var statusLabel: String {
        if let conclusion, !conclusion.isEmpty {
            return conclusion.uppercased()
        }
        return status.uppercased()
    }

    var isFailing: Bool {
        let normalized = (conclusion ?? "").lowercased()
        return normalized == "failure" || normalized == "cancelled" || normalized == "timed_out"
    }

    var isPending: Bool {
        let normalizedStatus = status.lowercased()
        return normalizedStatus == "queued" || normalizedStatus == "in_progress" || normalizedStatus == "waiting"
    }
}

nonisolated struct GitHubWorktreeStatus: Codable, Hashable {
    var pullRequest: GitHubPullRequestSummary?
    var checksSummary: GitHubPullRequestChecksSummary?
    var latestRun: GitHubWorkflowRunSummary?
}

enum GitHubIntegrationState: Hashable {
    case unknown
    case disabled
    case unavailable
    case unauthorized
    case authorized(GitHubAuthStatus)

    var summary: String {
        switch self {
        case .unknown:
            return "Checking GitHub"
        case .disabled:
            return "GitHub disabled"
        case .unavailable:
            return "`gh` unavailable"
        case .unauthorized:
            return "`gh` not logged in"
        case .authorized(let auth):
            return "\(auth.username)@\(auth.host)"
        }
    }
}
