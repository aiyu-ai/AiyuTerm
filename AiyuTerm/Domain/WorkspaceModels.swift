//
//  WorkspaceModels.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

struct WorkspaceGroup: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var icon: SidebarItemIcon
    var workspaceIDs: [UUID]
    var isExpanded: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: SidebarItemIcon = .groupDefault,
        workspaceIDs: [UUID] = [],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.workspaceIDs = workspaceIDs
        self.isExpanded = isExpanded
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, workspaceIDs, isExpanded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
            icon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .icon) ?? .groupDefault,
            workspaceIDs: try container.decodeIfPresent([UUID].self, forKey: .workspaceIDs) ?? [],
            isExpanded: try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        )
    }
}

private func aiyuTermLocalizedWorkflowString(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

private func aiyuTermLocalizedModelString(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

private func aiyuTermLocalizedModelFormat(_ key: String, _ arguments: CVarArg...) -> String {
    l10nFormat(aiyuTermLocalizedModelString(key), locale: .current, arguments: arguments)
}

enum WorkspaceKind: String, Codable {
    case repository
    case localTerminal

    var displayName: String {
        switch self {
        case .repository:
            return aiyuTermLocalizedModelString("workspace.kind.repository")
        case .localTerminal:
            return aiyuTermLocalizedModelString("workspace.kind.localTerminal")
        }
    }
}

enum TerminalEngineKind: String, Codable, CaseIterable {
    case libghosttyPreferred

    var displayName: String {
        "libghostty"
    }
}

enum SessionBackendKind: String, Codable, CaseIterable {
    case localShell
    case ssh
    case agent

    var displayName: String {
        switch self {
        case .localShell:
            return aiyuTermLocalizedModelString("session.backend.localShell")
        case .ssh:
            return aiyuTermLocalizedModelString("session.backend.ssh")
        case .agent:
            return aiyuTermLocalizedModelString("session.backend.agent")
        }
    }
}

struct LocalShellSessionConfiguration: Codable, Hashable {
    var shellPath: String
    var shellArguments: [String]

    static let legacyDefault = LocalShellSessionConfiguration(
        shellPath: "/bin/zsh",
        shellArguments: ["-l"]
    )

    static var `default`: LocalShellSessionConfiguration {
        fromLoginShellPath(CurrentUserLoginShell.path())
    }

    static func fromLoginShellPath(_ shellPath: String?) -> LocalShellSessionConfiguration {
        let normalizedShellPath = shellPath?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedShellPath, !normalizedShellPath.isEmpty {
            return LocalShellSessionConfiguration(
                shellPath: normalizedShellPath,
                shellArguments: legacyDefault.shellArguments
            )
        }

        return legacyDefault
    }

    var isLegacyDefault: Bool {
        self == Self.legacyDefault
    }

    func resolvingLegacyDefault(
        using loginShellPath: String?
    ) -> LocalShellSessionConfiguration {
        guard isLegacyDefault else { return self }
        return Self.fromLoginShellPath(loginShellPath)
    }
}

struct SSHSessionConfiguration: Codable, Hashable {
    var host: String
    var user: String?
    var port: Int?
    var identityFilePath: String?
    var remoteWorkingDirectory: String?
    var remoteCommand: String?

    var destination: String {
        guard let user, !user.isEmpty else { return host }
        return "\(user)@\(host)"
    }
}

struct AgentSessionConfiguration: Codable, Hashable {
    var name: String
    var launchPath: String
    var arguments: [String]
    var environment: [String: String]
    var workingDirectory: String?
}

struct AgentPreset: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var launchPath: String
    var arguments: [String]
    var environment: [String: String]
    var workingDirectory: String?

    init(
        id: UUID = UUID(),
        name: String,
        launchPath: String,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.name = name
        self.launchPath = launchPath
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
    }

    private static func builtInID(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue)!
    }

    static let claudeCode = AgentPreset(
        id: builtInID("B0A9A6D8-7A85-4B87-A5D0-6E6A8F50C002"),
        name: "Claude Code",
        launchPath: "/usr/bin/env",
        arguments: ["claude"]
    )

    static let codex = AgentPreset(
        id: builtInID("B0A9A6D8-7A85-4B87-A5D0-6E6A8F50C001"),
        name: "Codex",
        launchPath: "/usr/bin/env",
        arguments: ["codex"]
    )

    static let openCode = AgentPreset(
        id: builtInID("B0A9A6D8-7A85-4B87-A5D0-6E6A8F50C003"),
        name: "OpenCode",
        launchPath: "/usr/bin/env",
        arguments: ["opencode"]
    )

    static let cursorAgent = AgentPreset(
        id: builtInID("B0A9A6D8-7A85-4B87-A5D0-6E6A8F50C004"),
        name: "Cursor Agent",
        launchPath: "/usr/bin/env",
        arguments: ["cursor-agent"]
    )

    static let geminiCli = AgentPreset(
        id: builtInID("B0A9A6D8-7A85-4B87-A5D0-6E6A8F50C005"),
        name: "Gemini CLI",
        launchPath: "/usr/bin/env",
        arguments: ["gemini"]
    )

    static let deprecatedAiderPresetID = builtInID("B0A9A6D8-7A85-4B87-A5D0-6E6A8F50C006")

    static let builtInPresets: [AgentPreset] = [
        .claudeCode,
        .codex,
        .openCode,
        .cursorAgent,
        .geminiCli,
    ]

    var configuration: AgentSessionConfiguration {
        AgentSessionConfiguration(
            name: name,
            launchPath: launchPath,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory
        )
    }
}

struct SSHPreset: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var host: String?
    var user: String?
    var port: Int?
    var identityFilePath: String?
    var remoteWorkingDirectory: String?
    var remoteCommand: String

    init(
        id: UUID = UUID(),
        name: String,
        host: String? = nil,
        user: String? = nil,
        port: Int? = nil,
        identityFilePath: String? = nil,
        remoteWorkingDirectory: String? = nil,
        remoteCommand: String
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.host = host?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.user = user?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.port = port
        self.identityFilePath = identityFilePath?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.remoteWorkingDirectory = remoteWorkingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.remoteCommand = remoteCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension SSHPreset {
    private nonisolated static func builtInID(_ uuidString: String) -> UUID {
        UUID(uuidString: uuidString) ?? UUID()
    }

    static let shell = SSHPreset(
        id: builtInID("A14A10C9-B50E-45D9-8CFA-A74095E8A001"),
        name: "Shell",
        remoteCommand: ""
    )

    static let lazygit = SSHPreset(
        id: builtInID("A14A10C9-B50E-45D9-8CFA-A74095E8A002"),
        name: "Lazygit",
        remoteCommand: "lazygit"
    )

    static let yazi = SSHPreset(
        id: builtInID("A14A10C9-B50E-45D9-8CFA-A74095E8A003"),
        name: "Yazi",
        remoteCommand: "yazi"
    )

    static let btop = SSHPreset(
        id: builtInID("A14A10C9-B50E-45D9-8CFA-A74095E8A004"),
        name: "Btop",
        remoteCommand: "btop"
    )

    static let builtInPresets: [SSHPreset] = [
        .shell,
        .lazygit,
        .yazi,
        .btop,
    ]
}

struct RemoteWorkspaceTarget: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var ssh: SSHSessionConfiguration
    var sshPresetID: UUID?
    var agentPresetID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        ssh: SSHSessionConfiguration,
        sshPresetID: UUID? = nil,
        agentPresetID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.ssh = ssh
        self.sshPresetID = sshPresetID
        self.agentPresetID = agentPresetID
    }
}

struct WorkspaceSettings: Codable, Hashable {
    var isPinned: Bool
    var isArchived: Bool
    var workspaceIcon: SidebarItemIcon?
    var worktreeIconOverrides: [String: SidebarItemIcon]
    var runScript: String
    var setupScript: String
    var agentPresets: [AgentPreset]
    var preferredAgentPresetID: UUID?
    var remoteTargets: [RemoteWorkspaceTarget]
    var workflows: [WorkspaceWorkflow]
    var preferredWorkflowID: UUID?
    var tmuxSessionID: String?
    var todoLists: [String: WorkspaceTodoList]

    var isTmuxManaged: Bool { tmuxSessionID != nil }

    init(
        isPinned: Bool = false,
        isArchived: Bool = false,
        workspaceIcon: SidebarItemIcon? = nil,
        worktreeIconOverrides: [String: SidebarItemIcon] = [:],
        runScript: String = "",
        setupScript: String = "",
        agentPresets: [AgentPreset] = AgentPreset.builtInPresets,
        preferredAgentPresetID: UUID? = AgentPreset.claudeCode.id,
        remoteTargets: [RemoteWorkspaceTarget] = [],
        workflows: [WorkspaceWorkflow] = [],
        preferredWorkflowID: UUID? = nil,
        tmuxSessionID: String? = nil,
        todoLists: [String: WorkspaceTodoList] = [:]
    ) {
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.workspaceIcon = workspaceIcon
        self.worktreeIconOverrides = worktreeIconOverrides
        self.runScript = runScript
        self.setupScript = setupScript
        self.agentPresets = agentPresets
        self.preferredAgentPresetID = preferredAgentPresetID
        self.remoteTargets = remoteTargets
        self.workflows = workflows
        self.preferredWorkflowID = preferredWorkflowID
        self.tmuxSessionID = tmuxSessionID
        self.todoLists = todoLists
    }

    private enum CodingKeys: String, CodingKey {
        case isPinned
        case isArchived
        case workspaceIcon
        case worktreeIconOverrides
        case runScript
        case setupScript
        case agentPresets
        case preferredAgentPresetID
        case remoteTargets
        case workflows
        case preferredWorkflowID
        case tmuxSessionID
        case todoLists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isPinned: try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false,
            isArchived: try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false,
            workspaceIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .workspaceIcon),
            worktreeIconOverrides: try container.decodeIfPresent([String: SidebarItemIcon].self, forKey: .worktreeIconOverrides) ?? [:],
            runScript: try container.decodeIfPresent(String.self, forKey: .runScript) ?? "",
            setupScript: try container.decodeIfPresent(String.self, forKey: .setupScript) ?? "",
            agentPresets: try container.decodeIfPresent([AgentPreset].self, forKey: .agentPresets) ?? AgentPreset.builtInPresets,
            preferredAgentPresetID: try container.decodeIfPresent(UUID.self, forKey: .preferredAgentPresetID) ?? AgentPreset.claudeCode.id,
            remoteTargets: try container.decodeIfPresent([RemoteWorkspaceTarget].self, forKey: .remoteTargets) ?? [],
            workflows: try container.decodeIfPresent([WorkspaceWorkflow].self, forKey: .workflows) ?? [],
            preferredWorkflowID: try container.decodeIfPresent(UUID.self, forKey: .preferredWorkflowID),
            tmuxSessionID: try container.decodeIfPresent(String.self, forKey: .tmuxSessionID),
            todoLists: try container.decodeIfPresent([String: WorkspaceTodoList].self, forKey: .todoLists) ?? [:]
        )
    }
}

enum WorkspaceWorkflowLocalSessionMode: String, Codable, Hashable, CaseIterable, Identifiable {
    case reuseFocused
    case newSession
    case splitRight
    case splitDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reuseFocused:
            return aiyuTermLocalizedWorkflowString("settings.workflow.localSession.reuseFocused")
        case .newSession:
            return aiyuTermLocalizedWorkflowString("settings.workflow.localSession.newSession")
        case .splitRight:
            return aiyuTermLocalizedWorkflowString("settings.workflow.localSession.splitRight")
        case .splitDown:
            return aiyuTermLocalizedWorkflowString("settings.workflow.localSession.splitDown")
        }
    }
}

enum WorkspaceWorkflowAgentMode: String, Codable, Hashable, CaseIterable, Identifiable {
    case none
    case newSession
    case splitRight
    case splitDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return aiyuTermLocalizedWorkflowString("settings.workflow.agent.none")
        case .newSession:
            return aiyuTermLocalizedWorkflowString("settings.workflow.agent.newSession")
        case .splitRight:
            return aiyuTermLocalizedWorkflowString("settings.workflow.agent.splitRight")
        case .splitDown:
            return aiyuTermLocalizedWorkflowString("settings.workflow.agent.splitDown")
        }
    }
}

struct WorkspaceWorkflow: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var localSessionMode: WorkspaceWorkflowLocalSessionMode
    var runSetupScript: Bool
    var runWorkspaceScript: Bool
    var agentPresetID: UUID?
    var agentMode: WorkspaceWorkflowAgentMode

    init(
        id: UUID = UUID(),
        name: String,
        localSessionMode: WorkspaceWorkflowLocalSessionMode = .reuseFocused,
        runSetupScript: Bool = true,
        runWorkspaceScript: Bool = true,
        agentPresetID: UUID? = nil,
        agentMode: WorkspaceWorkflowAgentMode = .none
    ) {
        self.id = id
        self.name = name
        self.localSessionMode = localSessionMode
        self.runSetupScript = runSetupScript
        self.runWorkspaceScript = runWorkspaceScript
        self.agentPresetID = agentPresetID
        self.agentMode = agentMode
    }
}

enum WorkspaceActivityKind: String, Codable, Hashable, CaseIterable {
    case workflow
    case command
    case agent
    case remote
    case github
    case release

    var displayName: String {
        switch self {
        case .workflow:
            return aiyuTermLocalizedModelString("activity.kind.workflow")
        case .command:
            return aiyuTermLocalizedModelString("activity.kind.command")
        case .agent:
            return aiyuTermLocalizedModelString("activity.kind.agent")
        case .remote:
            return aiyuTermLocalizedModelString("activity.kind.remote")
        case .github:
            return aiyuTermLocalizedModelString("activity.kind.github")
        case .release:
            return aiyuTermLocalizedModelString("activity.kind.release")
        }
    }
}

enum WorkspaceReplayKind: String, Codable, Hashable {
    case runWorkspaceScript
    case runSetupScript
    case runWorkflow
    case createSession
    case openPullRequest
    case markPullRequestReady
    case openLatestRun
}

struct WorkspaceReplayAction: Codable, Hashable {
    var kind: WorkspaceReplayKind
    var workflowID: UUID?
    var worktreePath: String?
    var backendConfiguration: SessionBackendConfiguration?
    var workingDirectory: String?

    static func runWorkflow(_ workflowID: UUID) -> WorkspaceReplayAction {
        WorkspaceReplayAction(
            kind: .runWorkflow,
            workflowID: workflowID,
            worktreePath: nil,
            backendConfiguration: nil,
            workingDirectory: nil
        )
    }

    static func createSession(
        backendConfiguration: SessionBackendConfiguration,
        workingDirectory: String
    ) -> WorkspaceReplayAction {
        WorkspaceReplayAction(
            kind: .createSession,
            workflowID: nil,
            worktreePath: nil,
            backendConfiguration: backendConfiguration,
            workingDirectory: workingDirectory
        )
    }

    static func gitHub(_ kind: WorkspaceReplayKind, worktreePath: String) -> WorkspaceReplayAction {
        WorkspaceReplayAction(
            kind: kind,
            workflowID: nil,
            worktreePath: worktreePath,
            backendConfiguration: nil,
            workingDirectory: nil
        )
    }
}

struct WorkspaceActivityEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var timestamp: TimeInterval
    var kind: WorkspaceActivityKind
    var title: String
    var detail: String
    var worktreePath: String?
    var replayAction: WorkspaceReplayAction?

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        kind: WorkspaceActivityKind,
        title: String,
        detail: String,
        worktreePath: String? = nil,
        replayAction: WorkspaceReplayAction? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.detail = detail
        self.worktreePath = worktreePath
        self.replayAction = replayAction
    }
}

struct SessionBackendConfiguration: Codable, Hashable {
    var kind: SessionBackendKind
    var localShell: LocalShellSessionConfiguration?
    var ssh: SSHSessionConfiguration?
    var agent: AgentSessionConfiguration?

    static func local(
        shellPath: String? = nil,
        shellArguments: [String]? = nil
    ) -> SessionBackendConfiguration {
        let defaultShell = LocalShellSessionConfiguration.default
        return SessionBackendConfiguration(
            kind: .localShell,
            localShell: LocalShellSessionConfiguration(
                shellPath: shellPath ?? defaultShell.shellPath,
                shellArguments: shellArguments ?? defaultShell.shellArguments
            ),
            ssh: nil,
            agent: nil
        )
    }

    static func ssh(_ configuration: SSHSessionConfiguration) -> SessionBackendConfiguration {
        SessionBackendConfiguration(
            kind: .ssh,
            localShell: nil,
            ssh: configuration,
            agent: nil
        )
    }

    static func agent(_ configuration: AgentSessionConfiguration) -> SessionBackendConfiguration {
        SessionBackendConfiguration(
            kind: .agent,
            localShell: nil,
            ssh: nil,
            agent: configuration
        )
    }

    var displayName: String {
        switch kind {
        case .localShell:
            return kind.displayName
        case .ssh:
            return ssh?.destination ?? kind.displayName
        case .agent:
            return agent?.name ?? kind.displayName
        }
    }

    func resolvedLocalShellConfiguration(
        defaultConfiguration: LocalShellSessionConfiguration = .default
    ) -> LocalShellSessionConfiguration {
        (localShell ?? defaultConfiguration)
            .resolvingLegacyDefault(using: defaultConfiguration.shellPath)
    }

    var localShellConfiguration: LocalShellSessionConfiguration {
        resolvedLocalShellConfiguration()
    }
}

struct WorktreeModel: Codable, Hashable, Identifiable {
    var id: String { path }
    var path: String
    var branch: String?
    var head: String
    var isMainWorktree: Bool
    var isLocked: Bool
    var lockReason: String?

    var displayName: String {
        if let branch, !branch.isEmpty {
            return branch
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var branchLabel: String {
        branch ?? aiyuTermLocalizedModelString("worktree.detached")
    }
}

struct WorkspaceCanvasCardLayoutRecord: Codable, Hashable, Identifiable {
    var id: UUID { tabID }
    var tabID: UUID
    var centerX: Double
    var centerY: Double
    var width: Double
    var height: Double
}

struct WorkspaceCanvasStateRecord: Codable, Hashable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var cardLayouts: [WorkspaceCanvasCardLayoutRecord]

    init(
        scale: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0,
        cardLayouts: [WorkspaceCanvasCardLayoutRecord] = []
    ) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.cardLayouts = cardLayouts
    }

    func pruned(to validTabIDs: Set<UUID>) -> WorkspaceCanvasStateRecord {
        WorkspaceCanvasStateRecord(
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            cardLayouts: cardLayouts.filter { validTabIDs.contains($0.tabID) }
        )
    }
}

struct GlobalCanvasCardID: Codable, Hashable, Identifiable {
    var workspaceID: UUID
    var worktreePath: String
    var tabID: UUID

    var id: String {
        "\(workspaceID.uuidString)::\(worktreePath)::\(tabID.uuidString)"
    }
}

enum GlobalCanvasColorGroup: String, Codable, Hashable, CaseIterable, Identifiable {
    case none
    case blue
    case teal
    case green
    case amber
    case rose
    case slate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return aiyuTermLocalizedModelString("canvas.color.none")
        case .blue:
            return aiyuTermLocalizedModelString("canvas.color.blue")
        case .teal:
            return aiyuTermLocalizedModelString("canvas.color.teal")
        case .green:
            return aiyuTermLocalizedModelString("canvas.color.green")
        case .amber:
            return aiyuTermLocalizedModelString("canvas.color.amber")
        case .rose:
            return aiyuTermLocalizedModelString("canvas.color.rose")
        case .slate:
            return aiyuTermLocalizedModelString("canvas.color.slate")
        }
    }
}

struct GlobalCanvasCardLayoutRecord: Codable, Hashable, Identifiable {
    var workspaceID: UUID
    var worktreePath: String
    var tabID: UUID
    var centerX: Double
    var centerY: Double
    var width: Double
    var height: Double
    var isMinimized: Bool
    var isPinned: Bool
    var colorGroup: GlobalCanvasColorGroup

    private enum CodingKeys: String, CodingKey {
        case workspaceID
        case worktreePath
        case tabID
        case centerX
        case centerY
        case width
        case height
        case isMinimized
        case isPinned
        case colorGroup
    }

    init(
        workspaceID: UUID,
        worktreePath: String,
        tabID: UUID,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        isMinimized: Bool = false,
        isPinned: Bool = false,
        colorGroup: GlobalCanvasColorGroup = .none
    ) {
        self.workspaceID = workspaceID
        self.worktreePath = worktreePath
        self.tabID = tabID
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.isMinimized = isMinimized
        self.isPinned = isPinned
        self.colorGroup = colorGroup
    }

    var id: String {
        cardID.id
    }

    var cardID: GlobalCanvasCardID {
        GlobalCanvasCardID(
            workspaceID: workspaceID,
            worktreePath: worktreePath,
            tabID: tabID
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspaceID = try container.decode(UUID.self, forKey: .workspaceID)
        worktreePath = try container.decode(String.self, forKey: .worktreePath)
        tabID = try container.decode(UUID.self, forKey: .tabID)
        centerX = try container.decode(Double.self, forKey: .centerX)
        centerY = try container.decode(Double.self, forKey: .centerY)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        isMinimized = try container.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        colorGroup = try container.decodeIfPresent(GlobalCanvasColorGroup.self, forKey: .colorGroup) ?? .none
    }
}

struct GlobalCanvasStateRecord: Codable, Hashable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var cardLayouts: [GlobalCanvasCardLayoutRecord]

    init(
        scale: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0,
        cardLayouts: [GlobalCanvasCardLayoutRecord] = []
    ) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.cardLayouts = cardLayouts
    }

    func pruned(to validCardIDs: Set<GlobalCanvasCardID>) -> GlobalCanvasStateRecord {
        GlobalCanvasStateRecord(
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            cardLayouts: cardLayouts.filter { validCardIDs.contains($0.cardID) }
        )
    }
}

struct RepositoryStatusSnapshot: Codable, Hashable {
    var hasUncommittedChanges: Bool
    var changedFileCount: Int
    var aheadCount: Int
    var behindCount: Int
    var localBranches: [String]
    var remoteBranches: [String]
}

struct RepositorySnapshot: Codable, Hashable {
    var rootPath: String
    var currentBranch: String
    var head: String
    var worktrees: [WorktreeModel]
    var status: RepositoryStatusSnapshot
}

struct PaneSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var preferredWorkingDirectory: String
    var preferredEngine: TerminalEngineKind
    var backendConfiguration: SessionBackendConfiguration

    private enum CodingKeys: String, CodingKey {
        case id
        case preferredWorkingDirectory
        case preferredEngine
        case backendConfiguration
        case shellPath
        case shellArguments
    }

    init(
        id: UUID,
        preferredWorkingDirectory: String,
        preferredEngine: TerminalEngineKind,
        backendConfiguration: SessionBackendConfiguration
    ) {
        self.id = id
        self.preferredWorkingDirectory = preferredWorkingDirectory
        self.preferredEngine = preferredEngine
        self.backendConfiguration = backendConfiguration
    }

    static func makeDefault(id: UUID = UUID(), cwd: String) -> PaneSnapshot {
        PaneSnapshot(
            id: id,
            preferredWorkingDirectory: cwd,
            preferredEngine: .libghosttyPreferred,
            backendConfiguration: .local()
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        preferredWorkingDirectory = try container.decode(String.self, forKey: .preferredWorkingDirectory)
        if let preferredEngineRawValue = try container.decodeIfPresent(String.self, forKey: .preferredEngine) {
            preferredEngine = TerminalEngineKind(rawValue: preferredEngineRawValue) ?? .libghosttyPreferred
        } else {
            preferredEngine = .libghosttyPreferred
        }

        if let backendConfiguration = try container.decodeIfPresent(SessionBackendConfiguration.self, forKey: .backendConfiguration) {
            self.backendConfiguration = backendConfiguration
        } else {
            let shellPath = try container.decodeIfPresent(String.self, forKey: .shellPath) ?? LocalShellSessionConfiguration.default.shellPath
            let shellArguments = try container.decodeIfPresent([String].self, forKey: .shellArguments) ?? LocalShellSessionConfiguration.default.shellArguments
            backendConfiguration = .local(shellPath: shellPath, shellArguments: shellArguments)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(preferredWorkingDirectory, forKey: .preferredWorkingDirectory)
        try container.encode(preferredEngine, forKey: .preferredEngine)
        try container.encode(backendConfiguration, forKey: .backendConfiguration)
    }
}

struct WorkspaceTabStateRecord: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var isManuallyNamed: Bool
    var layout: SessionLayoutNode?
    var panes: [PaneSnapshot]
    var focusedPaneID: UUID?
    var zoomedPaneID: UUID?

    init(
        id: UUID = UUID(),
        title: String = aiyuTermLocalizedModelString("tab.defaultTitle"),
        isManuallyNamed: Bool = false,
        layout: SessionLayoutNode?,
        panes: [PaneSnapshot],
        focusedPaneID: UUID?,
        zoomedPaneID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.isManuallyNamed = isManuallyNamed
        self.layout = layout
        self.panes = panes
        self.focusedPaneID = focusedPaneID
        self.zoomedPaneID = zoomedPaneID
    }

    static func makeDefault(
        for worktreePath: String,
        title: String = aiyuTermLocalizedModelFormat("tab.defaultIndexedFormat", 1)
    ) -> WorkspaceTabStateRecord {
        let initialPane = PaneSnapshot.makeDefault(cwd: worktreePath)
        return WorkspaceTabStateRecord(
            title: title,
            layout: .pane(PaneLeaf(paneID: initialPane.id)),
            panes: [initialPane],
            focusedPaneID: initialPane.id,
            zoomedPaneID: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isManuallyNamed
        case layout
        case panes
        case focusedPaneID
        case zoomedPaneID
    }
}

extension WorkspaceTabStateRecord {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? aiyuTermLocalizedModelString("tab.defaultTitle")
        isManuallyNamed = try container.decodeIfPresent(Bool.self, forKey: .isManuallyNamed) ?? false
        layout = try container.decodeIfPresent(SessionLayoutNode.self, forKey: .layout)
        panes = try container.decodeIfPresent([PaneSnapshot].self, forKey: .panes) ?? []
        focusedPaneID = try container.decodeIfPresent(UUID.self, forKey: .focusedPaneID)
        zoomedPaneID = try container.decodeIfPresent(UUID.self, forKey: .zoomedPaneID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isManuallyNamed, forKey: .isManuallyNamed)
        try container.encode(layout, forKey: .layout)
        try container.encode(panes, forKey: .panes)
        try container.encode(focusedPaneID, forKey: .focusedPaneID)
        try container.encode(zoomedPaneID, forKey: .zoomedPaneID)
    }
}

struct WorktreeSessionStateRecord: Codable, Hashable, Identifiable {
    var id: String { worktreePath }
    var worktreePath: String
    var tabs: [WorkspaceTabStateRecord]
    var selectedTabID: UUID?
    var layout: SessionLayoutNode?
    var panes: [PaneSnapshot]
    var focusedPaneID: UUID?
    var zoomedPaneID: UUID?
    var canvasState: WorkspaceCanvasStateRecord

    private enum CodingKeys: String, CodingKey {
        case worktreePath
        case tabs
        case selectedTabID
        case layout
        case panes
        case focusedPaneID
        case zoomedPaneID
        case canvasState
    }

    init(
        worktreePath: String,
        layout: SessionLayoutNode?,
        panes: [PaneSnapshot],
        focusedPaneID: UUID?,
        zoomedPaneID: UUID? = nil,
        canvasState: WorkspaceCanvasStateRecord = WorkspaceCanvasStateRecord(),
        tabs: [WorkspaceTabStateRecord]? = nil,
        selectedTabID: UUID? = nil
    ) {
        self.worktreePath = worktreePath
        self.layout = layout
        self.panes = panes
        self.focusedPaneID = focusedPaneID
        self.zoomedPaneID = zoomedPaneID
        self.canvasState = canvasState

        if let tabs, !tabs.isEmpty {
            self.tabs = tabs
            self.selectedTabID = selectedTabID ?? tabs.first?.id
        } else if !panes.isEmpty || layout != nil || focusedPaneID != nil || zoomedPaneID != nil {
            let title = Self.defaultTitle(index: 1)
            let tab = WorkspaceTabStateRecord(
                id: selectedTabID ?? UUID(),
                title: title,
                isManuallyNamed: false,
                layout: layout,
                panes: panes,
                focusedPaneID: focusedPaneID ?? panes.first?.id,
                zoomedPaneID: zoomedPaneID
            )
            self.tabs = [tab]
            self.selectedTabID = tab.id
        } else {
            let tab = WorkspaceTabStateRecord.makeDefault(for: worktreePath)
            self.tabs = [tab]
            self.selectedTabID = tab.id
        }

        syncLegacyFields()
    }

    static func makeDefault(for worktreePath: String) -> WorktreeSessionStateRecord {
        return WorktreeSessionStateRecord(
            worktreePath: worktreePath,
            layout: nil,
            panes: [],
            focusedPaneID: nil,
            zoomedPaneID: nil
        )
    }

    var selectedTab: WorkspaceTabStateRecord? {
        guard !tabs.isEmpty else { return nil }
        if let selectedTabID,
           let match = tabs.first(where: { $0.id == selectedTabID }) {
            return match
        }
        return tabs.first
    }

    mutating func ensureTabs() {
        if tabs.isEmpty {
            let fallback = WorkspaceTabStateRecord(
                id: selectedTabID ?? UUID(),
                title: Self.defaultTitle(index: 1),
                layout: layout,
                panes: panes.isEmpty ? WorktreeSessionStateRecord.makeDefault(for: worktreePath).tabs.first?.panes ?? [] : panes,
                focusedPaneID: focusedPaneID ?? panes.first?.id,
                zoomedPaneID: zoomedPaneID
            )
            tabs = [fallback]
        }
        if selectedTabID == nil || tabs.contains(where: { $0.id == selectedTabID }) == false {
            selectedTabID = tabs.first?.id
        }
        syncLegacyFields()
    }

    mutating func setSelectedTabID(_ id: UUID?) {
        ensureTabs()
        if let id,
           tabs.contains(where: { $0.id == id }) {
            selectedTabID = id
        } else {
            selectedTabID = tabs.first?.id
        }
        syncLegacyFields()
    }

    func tabID(at index: Int) -> UUID? {
        guard tabs.indices.contains(index) else { return nil }
        return tabs[index].id
    }

    mutating func upsertTab(_ tab: WorkspaceTabStateRecord, selecting: Bool) {
        ensureTabs()
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index] = tab
        } else {
            tabs.append(tab)
        }
        if selecting {
            selectedTabID = tab.id
        }
        syncLegacyFields()
    }

    mutating func renameTab(_ id: UUID, title: String) {
        ensureTabs()
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        tabs[index].title = normalized
        tabs[index].isManuallyNamed = true
        syncLegacyFields()
    }

    mutating func moveTab(_ id: UUID, to destinationIndex: Int) {
        ensureTabs()
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        let clampedDestination = min(max(destinationIndex, 0), tabs.count - 1)
        guard sourceIndex != clampedDestination else { return }

        let item = tabs.remove(at: sourceIndex)
        let adjustedDestination = min(max(clampedDestination, 0), tabs.count)
        tabs.insert(item, at: adjustedDestination)
        syncLegacyFields()
    }

    mutating func moveTab(_ id: UUID, by offset: Int) {
        ensureTabs()
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        moveTab(id, to: sourceIndex + offset)
    }

    mutating func removeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTabID == id {
            selectedTabID = tabs.first?.id
        }
        syncLegacyFields()
    }

    private mutating func syncLegacyFields() {
        let selected = selectedTab ?? tabs.first
        layout = selected?.layout
        panes = selected?.panes ?? []
        focusedPaneID = selected?.focusedPaneID
        zoomedPaneID = selected?.zoomedPaneID
        canvasState = canvasState.pruned(to: Set(tabs.map(\.id)))
    }

    private static func defaultTitle(index: Int) -> String {
        aiyuTermLocalizedModelFormat("tab.defaultIndexedFormat", index)
    }
}

extension WorktreeSessionStateRecord {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let worktreePath = try container.decode(String.self, forKey: .worktreePath)
        let tabs = try container.decodeIfPresent([WorkspaceTabStateRecord].self, forKey: .tabs)
        let selectedTabID = try container.decodeIfPresent(UUID.self, forKey: .selectedTabID)
        let layout = try container.decodeIfPresent(SessionLayoutNode.self, forKey: .layout)
        let panes = try container.decodeIfPresent([PaneSnapshot].self, forKey: .panes) ?? []
        let focusedPaneID = try container.decodeIfPresent(UUID.self, forKey: .focusedPaneID)
        let zoomedPaneID = try container.decodeIfPresent(UUID.self, forKey: .zoomedPaneID)
        let canvasState = try container.decodeIfPresent(WorkspaceCanvasStateRecord.self, forKey: .canvasState) ?? WorkspaceCanvasStateRecord()

        self.init(
            worktreePath: worktreePath,
            layout: layout,
            panes: panes,
            focusedPaneID: focusedPaneID,
            zoomedPaneID: zoomedPaneID,
            canvasState: canvasState,
            tabs: tabs,
            selectedTabID: selectedTabID
        )
    }

    func encode(to encoder: Encoder) throws {
        var copy = self
        copy.ensureTabs()

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(copy.worktreePath, forKey: .worktreePath)
        try container.encode(copy.tabs, forKey: .tabs)
        try container.encode(copy.selectedTabID, forKey: .selectedTabID)
        try container.encode(copy.layout, forKey: .layout)
        try container.encode(copy.panes, forKey: .panes)
        try container.encode(copy.focusedPaneID, forKey: .focusedPaneID)
        try container.encode(copy.zoomedPaneID, forKey: .zoomedPaneID)
        try container.encode(copy.canvasState, forKey: .canvasState)
    }
}

struct WorkspaceRecord: Codable, Identifiable {
    var id: UUID
    var kind: WorkspaceKind
    var name: String
    var repositoryRoot: String
    var activeWorktreePath: String
    var worktreeStates: [WorktreeSessionStateRecord]
    var isSidebarExpanded: Bool
    var worktrees: [WorktreeModel]
    var settings: WorkspaceSettings
    var activityLog: [WorkspaceActivityEntry]

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case name
        case repositoryRoot
        case activeWorktreePath
        case worktreeStates
        case isSidebarExpanded
        case worktrees
        case settings
        case activityLog
        case layout
        case panes
        case focusedPaneID
    }

    init(
        id: UUID,
        kind: WorkspaceKind,
        name: String,
        repositoryRoot: String,
        activeWorktreePath: String,
        worktreeStates: [WorktreeSessionStateRecord],
        isSidebarExpanded: Bool,
        worktrees: [WorktreeModel] = [],
        settings: WorkspaceSettings = WorkspaceSettings(),
        activityLog: [WorkspaceActivityEntry] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.activeWorktreePath = activeWorktreePath
        self.worktreeStates = worktreeStates
        self.isSidebarExpanded = isSidebarExpanded
        self.worktrees = worktrees
        self.settings = settings
        self.activityLog = activityLog
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decodeIfPresent(WorkspaceKind.self, forKey: .kind) ?? .repository
        name = try container.decode(String.self, forKey: .name)
        repositoryRoot = try container.decode(String.self, forKey: .repositoryRoot)
        activeWorktreePath = try container.decode(String.self, forKey: .activeWorktreePath)
        isSidebarExpanded = try container.decodeIfPresent(Bool.self, forKey: .isSidebarExpanded) ?? false
        worktrees = try container.decodeIfPresent([WorktreeModel].self, forKey: .worktrees) ?? []
        settings = try container.decodeIfPresent(WorkspaceSettings.self, forKey: .settings) ?? WorkspaceSettings()
        activityLog = try container.decodeIfPresent([WorkspaceActivityEntry].self, forKey: .activityLog) ?? []

        if let states = try container.decodeIfPresent([WorktreeSessionStateRecord].self, forKey: .worktreeStates), !states.isEmpty {
            worktreeStates = states
        } else {
            let legacyLayout = try container.decodeIfPresent(SessionLayoutNode.self, forKey: .layout)
            let legacyPanes = try container.decodeIfPresent([PaneSnapshot].self, forKey: .panes) ?? []
            let legacyFocusedPaneID = try container.decodeIfPresent(UUID.self, forKey: .focusedPaneID)
            worktreeStates = [
                WorktreeSessionStateRecord(
                    worktreePath: activeWorktreePath,
                    layout: legacyLayout,
                    panes: legacyPanes.isEmpty ? WorktreeSessionStateRecord.makeDefault(for: activeWorktreePath).panes : legacyPanes,
                    focusedPaneID: legacyFocusedPaneID ?? legacyPanes.first?.id
                )
            ]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(repositoryRoot, forKey: .repositoryRoot)
        try container.encode(activeWorktreePath, forKey: .activeWorktreePath)
        try container.encode(worktreeStates, forKey: .worktreeStates)
        try container.encode(isSidebarExpanded, forKey: .isSidebarExpanded)
        try container.encode(worktrees, forKey: .worktrees)
        try container.encode(settings, forKey: .settings)
        try container.encode(activityLog, forKey: .activityLog)
    }
}

struct PersistedWorkspaceState: Codable {
    var selectedWorkspaceID: UUID?
    var workspaces: [WorkspaceRecord]
    var globalCanvasState: GlobalCanvasStateRecord

    private enum CodingKeys: String, CodingKey {
        case selectedWorkspaceID
        case workspaces
        case globalCanvasState
    }

    init(
        selectedWorkspaceID: UUID?,
        workspaces: [WorkspaceRecord],
        globalCanvasState: GlobalCanvasStateRecord = GlobalCanvasStateRecord()
    ) {
        self.selectedWorkspaceID = selectedWorkspaceID
        self.workspaces = workspaces
        self.globalCanvasState = globalCanvasState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedWorkspaceID = try container.decodeIfPresent(UUID.self, forKey: .selectedWorkspaceID)
        workspaces = try container.decodeIfPresent([WorkspaceRecord].self, forKey: .workspaces) ?? []
        if let storedCanvasState = try container.decodeIfPresent(GlobalCanvasStateRecord.self, forKey: .globalCanvasState) {
            globalCanvasState = storedCanvasState
        } else {
            globalCanvasState = Self.migratedGlobalCanvasState(
                from: workspaces,
                selectedWorkspaceID: selectedWorkspaceID
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedWorkspaceID, forKey: .selectedWorkspaceID)
        try container.encode(workspaces, forKey: .workspaces)
        try container.encode(globalCanvasState, forKey: .globalCanvasState)
    }
}

private extension PersistedWorkspaceState {
    static func migratedGlobalCanvasState(
        from workspaces: [WorkspaceRecord],
        selectedWorkspaceID: UUID?
    ) -> GlobalCanvasStateRecord {
        let preferredCanvasState = preferredLegacyCanvasState(
            from: workspaces,
            selectedWorkspaceID: selectedWorkspaceID
        )

        var seen = Set<GlobalCanvasCardID>()
        var cardLayouts: [GlobalCanvasCardLayoutRecord] = []

        for workspace in workspaces {
            for worktreeState in workspace.worktreeStates {
                for legacyLayout in worktreeState.canvasState.cardLayouts {
                    let cardID = GlobalCanvasCardID(
                        workspaceID: workspace.id,
                        worktreePath: worktreeState.worktreePath,
                        tabID: legacyLayout.tabID
                    )
                    guard seen.insert(cardID).inserted else { continue }
                    cardLayouts.append(
                        GlobalCanvasCardLayoutRecord(
                            workspaceID: workspace.id,
                            worktreePath: worktreeState.worktreePath,
                            tabID: legacyLayout.tabID,
                            centerX: legacyLayout.centerX,
                            centerY: legacyLayout.centerY,
                            width: legacyLayout.width,
                            height: legacyLayout.height
                        )
                    )
                }
            }
        }

        return GlobalCanvasStateRecord(
            scale: preferredCanvasState?.scale ?? 1,
            offsetX: preferredCanvasState?.offsetX ?? 0,
            offsetY: preferredCanvasState?.offsetY ?? 0,
            cardLayouts: cardLayouts
        )
    }

    static func preferredLegacyCanvasState(
        from workspaces: [WorkspaceRecord],
        selectedWorkspaceID: UUID?
    ) -> WorkspaceCanvasStateRecord? {
        if let selectedWorkspaceID,
           let workspace = workspaces.first(where: { $0.id == selectedWorkspaceID }),
           let selectedState = workspace.worktreeStates.first(where: { $0.worktreePath == workspace.activeWorktreePath }),
           !selectedState.canvasState.cardLayouts.isEmpty {
            return selectedState.canvasState
        }

        return workspaces
            .flatMap(\.worktreeStates)
            .first(where: { !$0.canvasState.cardLayouts.isEmpty })?
            .canvasState
    }
}

enum AgentSessionStatus: Equatable {
    case none
    case working
    case permissionNeeded
    case taskCompleted
    case error

    var isActionable: Bool {
        self != .none
    }

    /// Whether the badge should be displayed in the sidebar.
    var isVisible: Bool {
        self != .none
    }

    /// Whether user interaction (keyboard) should fully dismiss this status to .none.
    var isUserDismissible: Bool {
        self == .error
    }

    /// Whether keyboard activity should mark this status as "read" (shrink badge).
    /// Both permission and completed shrink on keyboard, clear only when working resumes.
    var isReadableOnInteraction: Bool {
        self == .permissionNeeded || self == .taskCompleted
    }

    private var priority: Int {
        switch self {
        case .permissionNeeded: return 4
        case .error: return 3
        case .taskCompleted: return 2
        case .working: return 1
        case .none: return 0
        }
    }

    static func highestPriority(in statuses: [AgentSessionStatus]) -> AgentSessionStatus {
        statuses.max(by: { $0.priority < $1.priority }) ?? .none
    }

    func badgeDisplayState(isUnread: Bool) -> AgentBadgeDisplayState {
        switch self {
        case .none: return .hidden
        case .working: return .spinner
        case .taskCompleted: return isUnread ? .completedUnread : .completedRead
        case .permissionNeeded: return isUnread ? .permissionNeeded : .permissionNeededRead
        case .error: return .error
        }
    }
}

enum AgentBadgeDisplayState: Equatable {
    case hidden
    case spinner
    case completedUnread
    case completedRead
    case error
    case permissionNeeded
    case permissionNeededRead
}
