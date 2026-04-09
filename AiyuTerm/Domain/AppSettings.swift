//
//  AppSettings.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import AppKit
import Carbon
import Foundation

nonisolated private func aiyuTermLocalizedSettingsString(_ key: String) -> String {
    LocalizationManager.stringForCurrentLanguage(key)
}

nonisolated enum SidebarIconFillStyle: String, Codable, Hashable, CaseIterable, Identifiable {
    case solid
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.style.solid")
        case .gradient:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.style.gradient")
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
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.blue")
        case .cyan:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.cyan")
        case .aqua:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.aqua")
        case .ice:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.ice")
        case .sky:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.sky")
        case .teal:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.teal")
        case .turquoise:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.turquoise")
        case .mint:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.mint")
        case .green:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.green")
        case .forest:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.forest")
        case .lime:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.lime")
        case .olive:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.olive")
        case .gold:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.gold")
        case .sand:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.sand")
        case .bronze:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.bronze")
        case .amber:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.amber")
        case .orange:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.orange")
        case .copper:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.copper")
        case .rust:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.rust")
        case .coral:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.coral")
        case .peach:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.peach")
        case .brick:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.brick")
        case .crimson:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.crimson")
        case .ruby:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.ruby")
        case .berry:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.berry")
        case .rose:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.rose")
        case .magenta:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.magenta")
        case .orchid:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.orchid")
        case .indigo:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.indigo")
        case .navy:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.navy")
        case .steel:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.steel")
        case .violet:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.violet")
        case .iris:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.iris")
        case .lavender:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.lavender")
        case .plum:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.plum")
        case .slate:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.slate")
        case .smoke:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.smoke")
        case .charcoal:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.charcoal")
        case .graphite:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.graphite")
        case .mocha:
            return aiyuTermLocalizedSettingsString("settings.sidebarIcon.palette.mocha")
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

    nonisolated static let groupDefault = SidebarItemIcon(
        symbolName: "folder.fill",
        palette: .slate,
        fillStyle: .gradient
    )
}

nonisolated enum ExternalEditor: String, Codable, Hashable, CaseIterable, Identifiable {
    case cursor
    case iTerm2
    case terminal
    case ghostty
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
        case .iTerm2:
            return "iTerm2"
        case .terminal:
            return "Terminal"
        case .ghostty:
            return "Ghostty"
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
    var appLanguage: AppLanguage
    var autoRefreshEnabled: Bool
    var autoRefreshIntervalSeconds: Int
    var autoClosePaneOnProcessExit: Bool
    var confirmQuitWhenCommandsRunning: Bool
    var hotKeyWindowEnabled: Bool
    var hotKeyWindowShortcut: StoredShortcut
    var fileWatcherEnabled: Bool
    var githubIntegrationEnabled: Bool
    var autoCheckForUpdates: Bool
    var autoDownloadUpdates: Bool
    var systemNotificationsEnabled: Bool
    var showArchivedWorkspaces: Bool
    var uiScale: Double
    var terminalFontFamily: String?
    var terminalFontSize: Double?
    var sidebarShowsSecondaryLabels: Bool
    var sidebarShowsWorkspaceBadges: Bool
    var sidebarShowsWorktreeBadges: Bool
    var tmuxPanelCollapsed: Bool
    var tmuxSidebarSplitRatio: Double
    var sidebarActivityIndicatorPalette: SidebarIconPalette
    var defaultRepositoryIcon: SidebarItemIcon
    var defaultLocalTerminalIcon: SidebarItemIcon
    var defaultWorktreeIcon: SidebarItemIcon
    var preferredExternalEditor: ExternalEditor
    var quickCommandCategories: [QuickCommandCategory]
    var quickCommandPresets: [QuickCommandPreset]
    var quickCommandRecentIDs: [String]
    var releaseChannel: ReleaseChannel
    var commandPaletteRecents: [String: TimeInterval]
    var agentPresets: [AgentPreset]
    var preferredAgentPresetID: UUID?
    var sshPresets: [SSHPreset]
    var preferredSSHPresetID: UUID?
    var workspaceGroups: [WorkspaceGroup]
    var keyboardShortcutOverrides: [String: KeyboardShortcutOverride]

    init(
        appLanguage: AppLanguage = .english,
        autoRefreshEnabled: Bool = true,
        autoRefreshIntervalSeconds: Int = 30,
        autoClosePaneOnProcessExit: Bool = true,
        confirmQuitWhenCommandsRunning: Bool = true,
        hotKeyWindowEnabled: Bool = false,
        hotKeyWindowShortcut: StoredShortcut = StoredShortcut(key: " ", command: true, shift: true, option: false, control: false),
        fileWatcherEnabled: Bool = true,
        githubIntegrationEnabled: Bool = true,
        autoCheckForUpdates: Bool = true,
        autoDownloadUpdates: Bool = true,
        systemNotificationsEnabled: Bool = true,
        showArchivedWorkspaces: Bool = false,
        uiScale: Double = 1,
        terminalFontFamily: String? = nil,
        terminalFontSize: Double? = nil,
        sidebarShowsSecondaryLabels: Bool = true,
        sidebarShowsWorkspaceBadges: Bool = true,
        sidebarShowsWorktreeBadges: Bool = true,
        tmuxPanelCollapsed: Bool = true,
        tmuxSidebarSplitRatio: Double = 0.6,
        sidebarActivityIndicatorPalette: SidebarIconPalette = .amber,
        defaultRepositoryIcon: SidebarItemIcon = .repositoryDefault,
        defaultLocalTerminalIcon: SidebarItemIcon = .localTerminalDefault,
        defaultWorktreeIcon: SidebarItemIcon = .worktreeDefault,
        preferredExternalEditor: ExternalEditor = .cursor,
        quickCommandCategories: [QuickCommandCategory] = QuickCommandCatalog.defaultCategories,
        quickCommandPresets: [QuickCommandPreset] = QuickCommandCatalog.defaultCommands,
        quickCommandRecentIDs: [String] = [],
        releaseChannel: ReleaseChannel = .stable,
        commandPaletteRecents: [String: TimeInterval] = [:],
        agentPresets: [AgentPreset] = AgentPreset.builtInPresets,
        preferredAgentPresetID: UUID? = AgentPreset.claudeCode.id,
        sshPresets: [SSHPreset] = SSHPreset.builtInPresets,
        preferredSSHPresetID: UUID? = nil,
        workspaceGroups: [WorkspaceGroup] = [],
        keyboardShortcutOverrides: [String: KeyboardShortcutOverride] = [:]
    ) {
        let normalizedKeyboardShortcutOverrides = AiyuTermKeyboardShortcuts.normalizedOverrides(keyboardShortcutOverrides)
        let normalizedAgentPresets = aiyuTermNormalizedAgentPresets(agentPresets)
        let normalizedSSHPresets = aiyuTermNormalizedSSHPresets(sshPresets)

        self.appLanguage = appLanguage
        self.autoRefreshEnabled = autoRefreshEnabled
        self.autoRefreshIntervalSeconds = max(10, autoRefreshIntervalSeconds)
        self.autoClosePaneOnProcessExit = autoClosePaneOnProcessExit
        self.confirmQuitWhenCommandsRunning = confirmQuitWhenCommandsRunning
        self.hotKeyWindowEnabled = hotKeyWindowEnabled
        self.hotKeyWindowShortcut = hotKeyWindowShortcut
        self.fileWatcherEnabled = fileWatcherEnabled
        self.githubIntegrationEnabled = githubIntegrationEnabled
        self.autoCheckForUpdates = autoCheckForUpdates
        self.autoDownloadUpdates = autoDownloadUpdates
        self.systemNotificationsEnabled = systemNotificationsEnabled
        self.showArchivedWorkspaces = showArchivedWorkspaces
        self.uiScale = min(max(uiScale, 0.85), 1.5)
        self.terminalFontFamily = terminalFontFamily?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        self.terminalFontSize = terminalFontSize.map { min(max($0, 8), 32) }
        self.sidebarShowsSecondaryLabels = sidebarShowsSecondaryLabels
        self.sidebarShowsWorkspaceBadges = sidebarShowsWorkspaceBadges
        self.sidebarShowsWorktreeBadges = sidebarShowsWorktreeBadges
        self.tmuxPanelCollapsed = tmuxPanelCollapsed
        self.tmuxSidebarSplitRatio = tmuxSidebarSplitRatio
        self.sidebarActivityIndicatorPalette = sidebarActivityIndicatorPalette
        self.defaultRepositoryIcon = defaultRepositoryIcon
        self.defaultLocalTerminalIcon = defaultLocalTerminalIcon
        self.defaultWorktreeIcon = defaultWorktreeIcon
        self.preferredExternalEditor = preferredExternalEditor
        self.keyboardShortcutOverrides = normalizedKeyboardShortcutOverrides
        self.quickCommandCategories = QuickCommandCatalog.normalizedCategories(quickCommandCategories)
        self.quickCommandPresets = QuickCommandCatalog.normalizedCommands(
            quickCommandPresets,
            categories: self.quickCommandCategories,
            reservedShortcuts: AiyuTermKeyboardShortcuts.effectiveShortcuts(using: normalizedKeyboardShortcutOverrides)
        )
        self.quickCommandRecentIDs = QuickCommandCatalog.normalizedRecentCommandIDs(
            quickCommandRecentIDs,
            availableCommands: self.quickCommandPresets
        )
        self.releaseChannel = releaseChannel
        self.commandPaletteRecents = commandPaletteRecents
        self.agentPresets = normalizedAgentPresets
        if let preferredAgentPresetID,
           normalizedAgentPresets.contains(where: { $0.id == preferredAgentPresetID }) {
            self.preferredAgentPresetID = preferredAgentPresetID
        } else {
            self.preferredAgentPresetID = normalizedAgentPresets.first?.id
        }
        self.sshPresets = normalizedSSHPresets
        if let preferredSSHPresetID,
           normalizedSSHPresets.contains(where: { $0.id == preferredSSHPresetID }) {
            self.preferredSSHPresetID = preferredSSHPresetID
        } else {
            self.preferredSSHPresetID = nil
        }
        self.workspaceGroups = workspaceGroups
    }
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case appLanguage
        case autoRefreshEnabled
        case autoRefreshIntervalSeconds
        case autoClosePaneOnProcessExit
        case confirmQuitWhenCommandsRunning
        case hotKeyWindowEnabled
        case hotKeyWindowShortcut
        case fileWatcherEnabled
        case githubIntegrationEnabled
        case autoCheckForUpdates
        case autoDownloadUpdates
        case systemNotificationsEnabled
        case showArchivedWorkspaces
        case uiScale
        case terminalFontFamily
        case terminalFontSize
        case sidebarShowsSecondaryLabels
        case sidebarShowsWorkspaceBadges
        case sidebarShowsWorktreeBadges
        case tmuxPanelCollapsed
        case tmuxSidebarSplitRatio
        case sidebarActivityIndicatorPalette
        case defaultRepositoryIcon
        case defaultLocalTerminalIcon
        case defaultWorktreeIcon
        case preferredExternalEditor
        case quickCommandCategories
        case quickCommandPresets
        case quickCommandRecentIDs
        case releaseChannel
        case commandPaletteRecents
        case agentPresets
        case preferredAgentPresetID
        case sshPresets
        case preferredSSHPresetID
        case workspaceGroups
        case keyboardShortcutOverrides
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
            appLanguage: try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .english,
            autoRefreshEnabled: try container.decodeIfPresent(Bool.self, forKey: .autoRefreshEnabled) ?? true,
            autoRefreshIntervalSeconds: try container.decodeIfPresent(Int.self, forKey: .autoRefreshIntervalSeconds) ?? 30,
            autoClosePaneOnProcessExit: try container.decodeIfPresent(Bool.self, forKey: .autoClosePaneOnProcessExit) ?? true,
            confirmQuitWhenCommandsRunning: try container.decodeIfPresent(Bool.self, forKey: .confirmQuitWhenCommandsRunning) ?? true,
            hotKeyWindowEnabled: try container.decodeIfPresent(Bool.self, forKey: .hotKeyWindowEnabled) ?? false,
            hotKeyWindowShortcut: try container.decodeIfPresent(StoredShortcut.self, forKey: .hotKeyWindowShortcut)
                ?? StoredShortcut(key: " ", command: true, shift: true, option: false, control: false),
            fileWatcherEnabled: try container.decodeIfPresent(Bool.self, forKey: .fileWatcherEnabled) ?? true,
            githubIntegrationEnabled: try container.decodeIfPresent(Bool.self, forKey: .githubIntegrationEnabled) ?? true,
            autoCheckForUpdates: try container.decodeIfPresent(Bool.self, forKey: .autoCheckForUpdates) ?? true,
            autoDownloadUpdates: try container.decodeIfPresent(Bool.self, forKey: .autoDownloadUpdates) ?? true,
            systemNotificationsEnabled: try container.decodeIfPresent(Bool.self, forKey: .systemNotificationsEnabled) ?? true,
            showArchivedWorkspaces: try container.decodeIfPresent(Bool.self, forKey: .showArchivedWorkspaces) ?? false,
            uiScale: try container.decodeIfPresent(Double.self, forKey: .uiScale) ?? 1,
            terminalFontFamily: try container.decodeIfPresent(String.self, forKey: .terminalFontFamily),
            terminalFontSize: try container.decodeIfPresent(Double.self, forKey: .terminalFontSize),
            sidebarShowsSecondaryLabels: try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsSecondaryLabels) ?? true,
            sidebarShowsWorkspaceBadges: try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsWorkspaceBadges) ?? true,
            sidebarShowsWorktreeBadges: try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsWorktreeBadges) ?? true,
            tmuxPanelCollapsed: try container.decodeIfPresent(Bool.self, forKey: .tmuxPanelCollapsed) ?? true,
            tmuxSidebarSplitRatio: try container.decodeIfPresent(Double.self, forKey: .tmuxSidebarSplitRatio) ?? 0.6,
            sidebarActivityIndicatorPalette: try container.decodeIfPresent(SidebarIconPalette.self, forKey: .sidebarActivityIndicatorPalette) ?? .amber,
            defaultRepositoryIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .defaultRepositoryIcon) ?? .repositoryDefault,
            defaultLocalTerminalIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .defaultLocalTerminalIcon) ?? .localTerminalDefault,
            defaultWorktreeIcon: try container.decodeIfPresent(SidebarItemIcon.self, forKey: .defaultWorktreeIcon) ?? .worktreeDefault,
            preferredExternalEditor: preferredExternalEditor,
            quickCommandCategories: try container.decodeIfPresent([QuickCommandCategory].self, forKey: .quickCommandCategories) ?? QuickCommandCatalog.defaultCategories,
            quickCommandPresets: try container.decodeIfPresent([QuickCommandPreset].self, forKey: .quickCommandPresets) ?? QuickCommandCatalog.defaultCommands,
            quickCommandRecentIDs: try container.decodeIfPresent([String].self, forKey: .quickCommandRecentIDs) ?? [],
            releaseChannel: try container.decodeIfPresent(ReleaseChannel.self, forKey: .releaseChannel) ?? .stable,
            commandPaletteRecents: try container.decodeIfPresent([String: TimeInterval].self, forKey: .commandPaletteRecents) ?? [:],
            agentPresets: try container.decodeIfPresent([AgentPreset].self, forKey: .agentPresets) ?? AgentPreset.builtInPresets,
            preferredAgentPresetID: try container.decodeIfPresent(UUID.self, forKey: .preferredAgentPresetID) ?? AgentPreset.claudeCode.id,
            sshPresets: try container.decodeIfPresent([SSHPreset].self, forKey: .sshPresets) ?? SSHPreset.builtInPresets,
            preferredSSHPresetID: try container.decodeIfPresent(UUID.self, forKey: .preferredSSHPresetID),
            workspaceGroups: try container.decodeIfPresent([WorkspaceGroup].self, forKey: .workspaceGroups) ?? [],
            keyboardShortcutOverrides: try container.decodeIfPresent([String: KeyboardShortcutOverride].self, forKey: .keyboardShortcutOverrides) ?? [:]
        )
    }
}

private func aiyuTermNormalizedAgentPresets(_ presets: [AgentPreset]) -> [AgentPreset] {
    let builtInsByID = Dictionary(uniqueKeysWithValues: AgentPreset.builtInPresets.map { ($0.id, $0) })
    let filtered = presets
        .filter { $0.id != AgentPreset.deprecatedAiderPresetID }
        .map { builtInsByID[$0.id] ?? $0 }
    if filtered.isEmpty {
        return AgentPreset.builtInPresets
    }

    var seenIDs = Set<UUID>()
    return filtered.filter { preset in
        seenIDs.insert(preset.id).inserted
    }
}

private func aiyuTermNormalizedSSHPresets(_ presets: [SSHPreset]) -> [SSHPreset] {
    let builtInsByID = Dictionary(uniqueKeysWithValues: SSHPreset.builtInPresets.map { ($0.id, $0) })
    let filtered = presets.map { builtInsByID[$0.id] ?? $0 }

    var seenIDs = Set<UUID>()
    return filtered.filter { preset in
        seenIDs.insert(preset.id).inserted
    }
}

nonisolated struct StoredShortcut: Codable, Hashable {
    var key: String
    var command: Bool
    var shift: Bool
    var option: Bool
    var control: Bool

    var displayString: String {
        modifierDisplayString + keyDisplayString
    }

    var modifierDisplayString: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        return parts.joined()
    }

    var keyDisplayString: String {
        switch key {
        case "\t":
            return "TAB"
        case "\r":
            return "↩"
        case " ":
            return "SPACE"
        default:
            return key.uppercased()
        }
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if command { flags.insert(.command) }
        if shift { flags.insert(.shift) }
        if option { flags.insert(.option) }
        if control { flags.insert(.control) }
        return flags
    }

    var menuItemKeyEquivalent: String? {
        switch key {
        case "←":
            guard let scalar = UnicodeScalar(NSLeftArrowFunctionKey) else { return nil }
            return String(Character(scalar))
        case "→":
            guard let scalar = UnicodeScalar(NSRightArrowFunctionKey) else { return nil }
            return String(Character(scalar))
        case "↑":
            guard let scalar = UnicodeScalar(NSUpArrowFunctionKey) else { return nil }
            return String(Character(scalar))
        case "↓":
            guard let scalar = UnicodeScalar(NSDownArrowFunctionKey) else { return nil }
            return String(Character(scalar))
        case "\t":
            return "\t"
        case "\r":
            return "\r"
        case " ":
            return " "
        default:
            let lowered = key.lowercased()
            guard lowered.count == 1 else { return nil }
            return lowered
        }
    }

    func withKey(_ key: String) -> StoredShortcut {
        StoredShortcut(
            key: key,
            command: command,
            shift: shift,
            option: option,
            control: control
        )
    }

    static func from(event: NSEvent) -> StoredShortcut? {
        guard let key = storedKey(from: event) else { return nil }

        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function])

        let shortcut = StoredShortcut(
            key: key,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )

        guard shortcut.command || shortcut.shift || shortcut.option || shortcut.control else {
            return nil
        }
        return shortcut
    }

    private static func storedKey(from event: NSEvent) -> String? {
        switch event.keyCode {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 48: return "\t"
        case 36, 76: return "\r"
        case 49: return " "
        case 33: return "["
        case 30: return "]"
        case 27: return "-"
        case 24: return "="
        case 43: return ","
        case 47: return "."
        case 44: return "/"
        case 41: return ";"
        case 39: return "'"
        case 50: return "`"
        case 42: return "\\"
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let char = chars.first else {
            return nil
        }

        if char.isLetter || char.isNumber {
            return String(char)
        }
        return nil
    }
}

extension StoredShortcut {
    private static let keyCodeByStoredKey: [String: UInt32] = [
        "a": UInt32(kVK_ANSI_A),
        "b": UInt32(kVK_ANSI_B),
        "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D),
        "e": UInt32(kVK_ANSI_E),
        "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G),
        "h": UInt32(kVK_ANSI_H),
        "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K),
        "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M),
        "n": UInt32(kVK_ANSI_N),
        "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P),
        "q": UInt32(kVK_ANSI_Q),
        "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S),
        "t": UInt32(kVK_ANSI_T),
        "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V),
        "w": UInt32(kVK_ANSI_W),
        "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y),
        "z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9),
        " ": UInt32(kVK_Space),
        "\t": UInt32(kVK_Tab),
        "\r": UInt32(kVK_Return),
        "[": UInt32(kVK_ANSI_LeftBracket),
        "]": UInt32(kVK_ANSI_RightBracket),
        "-": UInt32(kVK_ANSI_Minus),
        "=": UInt32(kVK_ANSI_Equal),
        ",": UInt32(kVK_ANSI_Comma),
        ".": UInt32(kVK_ANSI_Period),
        "/": UInt32(kVK_ANSI_Slash),
        ";": UInt32(kVK_ANSI_Semicolon),
        "'": UInt32(kVK_ANSI_Quote),
        "`": UInt32(kVK_ANSI_Grave),
        "\\": UInt32(kVK_ANSI_Backslash),
        "←": UInt32(kVK_LeftArrow),
        "→": UInt32(kVK_RightArrow),
        "↑": UInt32(kVK_UpArrow),
        "↓": UInt32(kVK_DownArrow),
    ]

    var carbonKeyCode: UInt32? {
        Self.keyCodeByStoredKey[key.lowercased()]
    }

    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if command { flags |= UInt32(cmdKey) }
        if shift { flags |= UInt32(shiftKey) }
        if option { flags |= UInt32(optionKey) }
        if control { flags |= UInt32(controlKey) }
        return flags
    }
}

struct KeyboardShortcutOverride: Codable, Hashable {
    var shortcut: StoredShortcut?
}

enum AiyuTermShortcutCategory: String, CaseIterable, Hashable, Identifiable {
    case general
    case workspace
    case tabs
    case panes
    case window

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.category.general")
        case .workspace:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.category.workspace")
        case .tabs:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.category.tabs")
        case .panes:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.category.panes")
        case .window:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.category.window")
        }
    }
}

enum AiyuTermShortcutAction: String, CaseIterable, Hashable, Identifiable {
    case hideApp
    case hideOtherApps
    case quitApp
    case newWindow
    case openSettings
    case undo
    case redo
    case cut
    case copy
    case paste
    case selectAll
    case find
    case findNext
    case findPrevious
    case hideFind
    case toggleCommandPalette
    case toggleSidebar
    case toggleOverview
    case openDiff
    case refreshSelectedWorkspace
    case refreshAllRepositories
    case newTab
    case closeTab
    case nextTab
    case previousTab
    case selectTabByNumber
    case focusPaneLeft
    case focusPaneRight
    case focusPaneUp
    case focusPaneDown
    case splitRight
    case splitDown
    case duplicatePane
    case togglePaneZoom
    case closePane
    case minimizeWindow
    case closeWindow
    case enterFullScreen

    var id: String { rawValue }

    var category: AiyuTermShortcutCategory {
        switch self {
        case .hideApp,
             .hideOtherApps,
             .quitApp,
             .openSettings,
             .undo,
             .redo,
             .cut,
             .copy,
             .paste,
             .selectAll,
             .find,
             .findNext,
             .findPrevious,
             .hideFind,
             .toggleCommandPalette,
             .toggleSidebar,
             .toggleOverview,
             .openDiff:
            return .general
        case .refreshSelectedWorkspace,
             .refreshAllRepositories:
            return .workspace
        case .newTab,
             .closeTab,
             .nextTab,
             .previousTab,
             .selectTabByNumber:
            return .tabs
        case .focusPaneLeft,
             .focusPaneRight,
             .focusPaneUp,
             .focusPaneDown,
             .splitRight,
             .splitDown,
             .duplicatePane,
             .togglePaneZoom,
             .closePane:
            return .panes
        case .newWindow,
             .minimizeWindow,
             .closeWindow,
             .enterFullScreen:
            return .window
        }
    }

    var title: String {
        switch self {
        case .hideApp:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.hideApp.title")
        case .hideOtherApps:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.hideOtherApps.title")
        case .quitApp:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.quitApp.title")
        case .newWindow:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.newWindow.title")
        case .openSettings:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.openSettings.title")
        case .undo:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.undo.title")
        case .redo:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.redo.title")
        case .cut:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.cut.title")
        case .copy:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.copy.title")
        case .paste:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.paste.title")
        case .selectAll:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.selectAll.title")
        case .find:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.find.title")
        case .findNext:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.findNext.title")
        case .findPrevious:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.findPrevious.title")
        case .hideFind:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.hideFind.title")
        case .toggleCommandPalette:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.toggleCommandPalette.title")
        case .toggleSidebar:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.toggleSidebar.title")
        case .toggleOverview:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.toggleOverview.title")
        case .openDiff:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.openDiff.title")
        case .refreshSelectedWorkspace:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.refreshSelectedWorkspace.title")
        case .refreshAllRepositories:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.refreshAllRepositories.title")
        case .newTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.newTab.title")
        case .closeTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.closeTab.title")
        case .nextTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.nextTab.title")
        case .previousTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.previousTab.title")
        case .selectTabByNumber:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.selectTabByNumber.title")
        case .focusPaneLeft:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneLeft.title")
        case .focusPaneRight:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneRight.title")
        case .focusPaneUp:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneUp.title")
        case .focusPaneDown:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneDown.title")
        case .splitRight:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.splitRight.title")
        case .splitDown:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.splitDown.title")
        case .duplicatePane:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.duplicatePane.title")
        case .togglePaneZoom:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.togglePaneZoom.title")
        case .closePane:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.closePane.title")
        case .minimizeWindow:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.minimizeWindow.title")
        case .closeWindow:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.closeWindow.title")
        case .enterFullScreen:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.enterFullScreen.title")
        }
    }

    var subtitle: String {
        switch self {
        case .hideApp:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.hideApp.subtitle")
        case .hideOtherApps:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.hideOtherApps.subtitle")
        case .quitApp:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.quitApp.subtitle")
        case .newWindow:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.newWindow.subtitle")
        case .openSettings:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.openSettings.subtitle")
        case .undo:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.undo.subtitle")
        case .redo:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.redo.subtitle")
        case .cut:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.cut.subtitle")
        case .copy:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.copy.subtitle")
        case .paste:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.paste.subtitle")
        case .selectAll:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.selectAll.subtitle")
        case .find:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.find.subtitle")
        case .findNext:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.findNext.subtitle")
        case .findPrevious:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.findPrevious.subtitle")
        case .hideFind:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.hideFind.subtitle")
        case .toggleCommandPalette:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.toggleCommandPalette.subtitle")
        case .toggleSidebar:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.toggleSidebar.subtitle")
        case .toggleOverview:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.toggleOverview.subtitle")
        case .openDiff:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.openDiff.subtitle")
        case .refreshSelectedWorkspace:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.refreshSelectedWorkspace.subtitle")
        case .refreshAllRepositories:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.refreshAllRepositories.subtitle")
        case .newTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.newTab.subtitle")
        case .closeTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.closeTab.subtitle")
        case .nextTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.nextTab.subtitle")
        case .previousTab:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.previousTab.subtitle")
        case .selectTabByNumber:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.selectTabByNumber.subtitle")
        case .focusPaneLeft:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneLeft.subtitle")
        case .focusPaneRight:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneRight.subtitle")
        case .focusPaneUp:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneUp.subtitle")
        case .focusPaneDown:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.focusPaneDown.subtitle")
        case .splitRight:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.splitRight.subtitle")
        case .splitDown:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.splitDown.subtitle")
        case .duplicatePane:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.duplicatePane.subtitle")
        case .togglePaneZoom:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.togglePaneZoom.subtitle")
        case .closePane:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.closePane.subtitle")
        case .minimizeWindow:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.minimizeWindow.subtitle")
        case .closeWindow:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.closeWindow.subtitle")
        case .enterFullScreen:
            return aiyuTermLocalizedSettingsString("settings.shortcuts.action.enterFullScreen.subtitle")
        }
    }

    var defaultShortcut: StoredShortcut? {
        switch self {
        case .hideApp:
            return StoredShortcut(key: "h", command: true, shift: false, option: false, control: false)
        case .hideOtherApps:
            return StoredShortcut(key: "h", command: true, shift: false, option: true, control: false)
        case .quitApp:
            return StoredShortcut(key: "q", command: true, shift: false, option: false, control: false)
        case .newWindow:
            return StoredShortcut(key: "n", command: true, shift: false, option: false, control: false)
        case .openSettings:
            return StoredShortcut(key: ",", command: true, shift: false, option: false, control: false)
        case .undo:
            return StoredShortcut(key: "z", command: true, shift: false, option: false, control: false)
        case .redo:
            return StoredShortcut(key: "z", command: true, shift: true, option: false, control: false)
        case .cut:
            return StoredShortcut(key: "x", command: true, shift: false, option: false, control: false)
        case .copy:
            return StoredShortcut(key: "c", command: true, shift: false, option: false, control: false)
        case .paste:
            return StoredShortcut(key: "v", command: true, shift: false, option: false, control: false)
        case .selectAll:
            return StoredShortcut(key: "a", command: true, shift: false, option: false, control: false)
        case .find:
            return StoredShortcut(key: "f", command: true, shift: false, option: false, control: false)
        case .findNext:
            return StoredShortcut(key: "g", command: true, shift: false, option: false, control: false)
        case .findPrevious:
            return StoredShortcut(key: "g", command: true, shift: true, option: false, control: false)
        case .hideFind:
            return StoredShortcut(key: "e", command: true, shift: false, option: false, control: false)
        case .toggleCommandPalette:
            return StoredShortcut(key: "p", command: true, shift: false, option: false, control: false)
        case .toggleSidebar:
            return StoredShortcut(key: "b", command: true, shift: false, option: false, control: false)
        case .toggleOverview:
            return StoredShortcut(key: "o", command: true, shift: true, option: false, control: false)
        case .openDiff:
            return StoredShortcut(key: ".", command: true, shift: true, option: false, control: false)
        case .refreshSelectedWorkspace:
            return StoredShortcut(key: "r", command: true, shift: false, option: false, control: false)
        case .refreshAllRepositories:
            return StoredShortcut(key: "r", command: true, shift: true, option: false, control: false)
        case .newTab:
            return StoredShortcut(key: "t", command: true, shift: false, option: false, control: false)
        case .closeTab:
            return StoredShortcut(key: "w", command: true, shift: false, option: false, control: false)
        case .nextTab:
            return StoredShortcut(key: "\t", command: false, shift: false, option: false, control: true)
        case .previousTab:
            return StoredShortcut(key: "\t", command: false, shift: true, option: false, control: true)
        case .selectTabByNumber:
            return StoredShortcut(key: "1", command: true, shift: false, option: false, control: false)
        case .focusPaneLeft:
            return StoredShortcut(key: "←", command: true, shift: false, option: true, control: false)
        case .focusPaneRight:
            return StoredShortcut(key: "→", command: true, shift: false, option: true, control: false)
        case .focusPaneUp:
            return StoredShortcut(key: "↑", command: true, shift: false, option: true, control: false)
        case .focusPaneDown:
            return StoredShortcut(key: "↓", command: true, shift: false, option: true, control: false)
        case .splitRight:
            return StoredShortcut(key: "d", command: true, shift: false, option: false, control: false)
        case .splitDown:
            return StoredShortcut(key: "d", command: true, shift: true, option: false, control: false)
        case .duplicatePane:
            return StoredShortcut(key: "d", command: true, shift: false, option: true, control: false)
        case .togglePaneZoom:
            return StoredShortcut(key: "\r", command: true, shift: false, option: false, control: false)
        case .closePane:
            return StoredShortcut(key: "w", command: true, shift: false, option: true, control: false)
        case .minimizeWindow:
            return StoredShortcut(key: "m", command: true, shift: false, option: false, control: false)
        case .closeWindow:
            return StoredShortcut(key: "w", command: true, shift: true, option: false, control: false)
        case .enterFullScreen:
            return StoredShortcut(key: "f", command: true, shift: false, option: false, control: true)
        }
    }

    var usesNumberedDigitMatching: Bool {
        self == .selectTabByNumber
    }

    func normalizedRecordedShortcut(_ shortcut: StoredShortcut) -> StoredShortcut? {
        guard usesNumberedDigitMatching else { return shortcut }
        guard let digit = Int(shortcut.key), (1...9).contains(digit) else {
            return nil
        }
        return shortcut.withKey("1")
    }

    func displayedShortcutString(for shortcut: StoredShortcut) -> String {
        if usesNumberedDigitMatching {
            return shortcut.modifierDisplayString + "1…9"
        }
        return shortcut.displayString
    }
}

enum AiyuTermKeyboardShortcutState: Equatable {
    case `default`
    case custom
    case disabled
}

enum AiyuTermKeyboardShortcuts {
    private enum Candidate {
        case inheritDefault
        case custom(StoredShortcut)
        case disabled
    }

    static func effectiveShortcut(for action: AiyuTermShortcutAction, in settings: AppSettings) -> StoredShortcut? {
        if let override = settings.keyboardShortcutOverrides[action.rawValue] {
            return override.shortcut
        }
        return action.defaultShortcut
    }

    static func state(for action: AiyuTermShortcutAction, in settings: AppSettings) -> AiyuTermKeyboardShortcutState {
        guard let override = settings.keyboardShortcutOverrides[action.rawValue] else {
            return .default
        }
        return override.shortcut == nil ? .disabled : .custom
    }

    static func displayString(for action: AiyuTermShortcutAction, in settings: AppSettings) -> String {
        guard let shortcut = effectiveShortcut(for: action, in: settings) else {
            return "Not Set"
        }
        return action.displayedShortcutString(for: shortcut)
    }

    static func effectiveShortcuts(in settings: AppSettings) -> Set<StoredShortcut> {
        effectiveShortcuts(using: settings.keyboardShortcutOverrides)
    }

    static func effectiveShortcuts(using overrides: [String: KeyboardShortcutOverride]) -> Set<StoredShortcut> {
        Set(
            AiyuTermShortcutAction.allCases.compactMap { action in
                if let override = overrides[action.rawValue] {
                    return override.shortcut
                }
                return action.defaultShortcut
            }
        )
    }

    static func setShortcut(_ shortcut: StoredShortcut, for action: AiyuTermShortcutAction, in settings: inout AppSettings) {
        guard let normalizedShortcut = action.normalizedRecordedShortcut(shortcut) else { return }

        for otherAction in AiyuTermShortcutAction.allCases where otherAction != action {
            if effectiveShortcut(for: otherAction, in: settings) == normalizedShortcut {
                settings.keyboardShortcutOverrides[otherAction.rawValue] = KeyboardShortcutOverride(shortcut: nil)
            }
        }

        if normalizedShortcut == action.defaultShortcut {
            settings.keyboardShortcutOverrides.removeValue(forKey: action.rawValue)
        } else {
            settings.keyboardShortcutOverrides[action.rawValue] = KeyboardShortcutOverride(shortcut: normalizedShortcut)
        }

        settings.keyboardShortcutOverrides = normalizedOverrides(settings.keyboardShortcutOverrides)
    }

    static func disableShortcut(for action: AiyuTermShortcutAction, in settings: inout AppSettings) {
        settings.keyboardShortcutOverrides[action.rawValue] = KeyboardShortcutOverride(shortcut: nil)
        settings.keyboardShortcutOverrides = normalizedOverrides(settings.keyboardShortcutOverrides)
    }

    static func resetShortcut(for action: AiyuTermShortcutAction, in settings: inout AppSettings) {
        settings.keyboardShortcutOverrides.removeValue(forKey: action.rawValue)
        settings.keyboardShortcutOverrides = normalizedOverrides(settings.keyboardShortcutOverrides)
    }

    static func resetAll(in settings: inout AppSettings) {
        settings.keyboardShortcutOverrides = [:]
    }

    static func normalizedOverrides(_ overrides: [String: KeyboardShortcutOverride]) -> [String: KeyboardShortcutOverride] {
        var candidates: [AiyuTermShortcutAction: Candidate] = [:]

        for action in AiyuTermShortcutAction.allCases {
            guard let override = overrides[action.rawValue] else { continue }

            if let shortcut = override.shortcut {
                guard let normalizedShortcut = action.normalizedRecordedShortcut(shortcut) else { continue }
                if normalizedShortcut == action.defaultShortcut {
                    continue
                }
                candidates[action] = .custom(normalizedShortcut)
            } else {
                candidates[action] = .disabled
            }
        }

        var normalized: [String: KeyboardShortcutOverride] = [:]
        var seenShortcuts = Set<StoredShortcut>()

        for action in AiyuTermShortcutAction.allCases {
            let candidate = candidates[action] ?? .inheritDefault

            let effectiveShortcut: StoredShortcut?
            switch candidate {
            case .inheritDefault:
                effectiveShortcut = action.defaultShortcut
            case .custom(let shortcut):
                effectiveShortcut = shortcut
            case .disabled:
                effectiveShortcut = nil
            }

            if let effectiveShortcut {
                if seenShortcuts.contains(effectiveShortcut) {
                    normalized[action.rawValue] = KeyboardShortcutOverride(shortcut: nil)
                    continue
                }
                seenShortcuts.insert(effectiveShortcut)

                if case .custom(let shortcut) = candidate {
                    normalized[action.rawValue] = KeyboardShortcutOverride(shortcut: shortcut)
                }
            } else if case .disabled = candidate {
                normalized[action.rawValue] = KeyboardShortcutOverride(shortcut: nil)
            }
        }

        return normalized
    }
}

struct AiyuTermShortcutMatch: Equatable {
    var action: AiyuTermShortcutAction
    var tabNumber: Int?
}

func aiyuTermShortcutMatch(for event: NSEvent, in settings: AppSettings) -> AiyuTermShortcutMatch? {
    guard let recordedShortcut = StoredShortcut.from(event: event) else { return nil }

    for action in AiyuTermShortcutAction.allCases {
        guard let effectiveShortcut = AiyuTermKeyboardShortcuts.effectiveShortcut(for: action, in: settings) else {
            continue
        }

        if action.usesNumberedDigitMatching {
            guard let tabNumber = Int(recordedShortcut.key),
                  (1...9).contains(tabNumber),
                  action.normalizedRecordedShortcut(recordedShortcut) == effectiveShortcut else {
                continue
            }
            return AiyuTermShortcutMatch(action: action, tabNumber: tabNumber)
        }

        if recordedShortcut == effectiveShortcut {
            return AiyuTermShortcutMatch(action: action, tabNumber: nil)
        }
    }

    return nil
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
