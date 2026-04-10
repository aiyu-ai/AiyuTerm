//
// AgentSessionSnapshot.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandCore/SessionSnapshot.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Per-session snapshot plus the pure reducer that consumes
// `AgentHookEvent`s and produces side effects for the caller to
// execute. AiyuTerm renames the types to avoid colliding with the
// existing `AgentSessionStatus` enum in WorkspaceModels.swift, but
// the reducer semantics are preserved bit-for-bit so that we can
// update it when CodeIsland upstream fixes bugs.
//
// Notes on the AiyuTerm adaptation:
//   • `AgentSessionSnapshot.appBundleNames` adds AiyuTerm bundle IDs
//     (`com.aiyuai.aiyuterm` and `.debug`) so that sessions running
//     inside AiyuTerm's own terminal surface are recognized.
//   • Ghostty is already recognized via its bundle ID
//     `com.mitchellh.ghostty` in the upstream table.
//   • The `playSound` side effect is preserved for interface parity;
//     AiyuTerm's mapper (Phase 3) simply discards it.
//

import Foundation

// MARK: - Session title source

enum AgentSessionTitleSource: String, Sendable, Codable {
    case codexThreadName
    case claudeCustomTitle
    case claudeAiTitle
}

// MARK: - Snapshot

struct AgentSessionSnapshot {
    /// Source tags we are willing to accept. Any unknown source is
    /// stripped rather than persisted, to prevent typo-driven state
    /// drift across the reducer.
    static let supportedSources: Set<String> = [
        "claude",
        "codex",
        "gemini",
        "cursor",
        "copilot",
        "qoder",
        "droid",
        "codebuddy",
        "opencode",
    ]

    var status: AgentHookStatus = .idle
    var currentTool: String?
    var toolDescription: String?
    var lastActivity: Date = Date()
    var cwd: String?
    var model: String?
    var permissionMode: String?
    var toolHistory: [AgentToolHistoryEntry] = []
    var subagents: [String: AgentSubagentState] = [:]
    var startTime: Date = Date()
    var lastUserPrompt: String?
    var lastAssistantMessage: String?
    /// Recent chat messages (max 3) for preview
    var recentMessages: [AgentChatMessage] = []
    // Terminal info for window activation
    var termApp: String?       // "iTerm.app", "Apple_Terminal", etc.
    var itermSessionId: String? // iTerm2 session ID for direct activation
    var ttyPath: String?       // /dev/ttys00X
    var kittyWindowId: String? // Kitty window ID for precise focus
    var tmuxPane: String?      // tmux pane identifier (%0, %1, etc.)
    var tmuxClientTty: String? // tmux client TTY for real terminal detection
    var tmuxEnv: String?       // raw TMUX env var (socket info for non-default tmux server)
    var termBundleId: String?  // __CFBundleIdentifier for precise terminal ID
    var cliPid: pid_t?          // CLI process PID (from bridge _ppid)
    var cliStartTime: Date?     // Start time of the tracked CLI PID (guards PID reuse)
    var source: String = "claude"
    var interrupted: Bool = false
    var sessionTitle: String?
    var sessionTitleSource: AgentSessionTitleSource?
    var providerSessionId: String?
    /// nil = unchecked, false = not YOLO, true = YOLO
    var isYoloMode: Bool?

    init(startTime: Date = Date()) {
        self.startTime = startTime
    }

    static func normalizedSupportedSource(_ source: String?) -> String? {
        guard let source else { return nil }
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, supportedSources.contains(normalized) else { return nil }
        return normalized
    }

    var activeSubagentCount: Int {
        subagents.values.filter { $0.status != .idle }.count
    }

    mutating func addRecentMessage(_ msg: AgentChatMessage, maxCount: Int = 3) {
        recentMessages.append(msg)
        if recentMessages.count > maxCount {
            recentMessages.removeFirst(recentMessages.count - maxCount)
        }
    }

    mutating func insertRecentMessage(_ msg: AgentChatMessage, at index: Int, maxCount: Int = 3) {
        recentMessages.insert(msg, at: index)
        if recentMessages.count > maxCount {
            recentMessages.removeFirst(recentMessages.count - maxCount)
        }
    }

    mutating func recordTool(
        _ tool: String,
        description: String?,
        success: Bool,
        agentType: String?,
        maxHistory: Int
    ) {
        let entry = AgentToolHistoryEntry(
            tool: tool,
            description: description,
            timestamp: Date(),
            success: success,
            agentType: agentType
        )
        toolHistory.append(entry)
        if toolHistory.count > maxHistory {
            toolHistory.removeFirst()
        }
    }

    /// Display name: project folder, or short session ID.
    var displayName: String {
        if let cwd = cwd {
            let last = (cwd as NSString).lastPathComponent
            // If last component is a timestamp/numeric ID (e.g. CodeBuddy "20260406010126"),
            // show the parent directory name instead.
            if last.count >= 8 && last.allSatisfy(\.isNumber) {
                let parent = ((cwd as NSString).deletingLastPathComponent as NSString).lastPathComponent
                if !parent.isEmpty && parent != "/" { return parent }
            }
            return last
        }
        return "Session"
    }

    func displayTitle(sessionId: String) -> String {
        sessionLabel ?? sessionId
    }

    func displaySessionId(sessionId: String) -> String {
        if let providerSessionId {
            let trimmed = providerSessionId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return sessionId
    }

    var projectDisplayName: String { displayName }

    var sessionLabel: String? {
        guard let sessionTitle else { return nil }
        let trimmed = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Shortened model name: "claude-opus-4-6" -> "opus".
    var shortModelName: String? {
        guard let model = model else { return nil }
        let lower = model.lowercased()
        if lower.contains("opus") { return "opus" }
        if lower.contains("sonnet") { return "sonnet" }
        if lower.contains("haiku") { return "haiku" }
        if lower.contains("gemini") { return "gemini" }
        if let last = model.split(separator: "-").last, last.count <= 8 {
            return String(last)
        }
        return String(model.prefix(8))
    }

    /// Source label for display.
    var sourceLabel: String {
        switch source {
        case "claude": return "Claude"
        case "codex": return "Codex"
        case "gemini": return "Gemini"
        case "cursor": return "Cursor"
        case "qoder": return "Qoder"
        case "droid": return "Factory"
        case "codebuddy": return "CodeBuddy"
        case "opencode": return "OpenCode"
        default: return source.capitalized
        }
    }

    var isCodex: Bool { source == "codex" }
    var isClaude: Bool { source == "claude" }

    /// True when the session runs inside a native app in APP mode
    /// (Cursor agent, Codex APP, etc.) — the app IS the agent, not
    /// just a terminal hosting a CLI. Requires both bundle ID AND
    /// source to match.
    var isNativeAppMode: Bool {
        guard let bid = termBundleId else { return false }
        guard let expectedSource = Self.appBundleSources[bid] else { return false }
        return source == expectedSource
    }

    /// True when the session runs inside an IDE's integrated terminal.
    var isIDETerminal: Bool {
        guard let bid = termBundleId else { return false }
        if isNativeAppMode { return false }
        if Self.appBundleNames[bid] != nil { return true }
        let lower = bid.lowercased()
        return lower.contains("vscode") || lower.contains("vscodium")
            || lower == "com.trae.app"
            || lower.contains("windsurf") || lower.contains("codeium")
            || lower.contains("jetbrains")
            || lower.contains("zed")
            || lower.contains("xcode") || lower == "com.apple.dt.xcode"
            || lower.contains("panic.nova")
            || lower.contains("android.studio")
            || lower.contains("antigravity")
    }

    /// Bundle IDs of native apps (not terminals). AiyuTerm's own
    /// bundle IDs are intentionally omitted here because AiyuTerm is
    /// a terminal host, not a native agent.
    private static let appBundleNames: [String: String] = [
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.qoder.ide": "Qoder",
        "com.factory.app": "Factory",
        "com.tencent.codebuddy": "CodeBuddy",
        "com.openai.codex": "Codex",
        "ai.opencode.desktop": "OpenCode",
    ]

    /// Maps native app bundle IDs to their expected source identifier.
    /// Used by `isNativeAppMode`.
    private static let appBundleSources: [String: String] = [
        "com.todesktop.230313mzl4w4u92": "cursor",
        "com.qoder.ide": "qoder",
        "com.factory.app": "droid",
        "com.tencent.codebuddy": "codebuddy",
        "com.openai.codex": "codex",
        "ai.opencode.desktop": "opencode",
    ]

    /// Short terminal/app name for display tag.
    var terminalName: String? {
        // If termBundleId is a known app, show app name (APP mode).
        if let bid = termBundleId, let name = Self.appBundleNames[bid] {
            return name
        }
        if let bid = termBundleId {
            let lower = bid.lowercased()
            if lower.contains("cmux") { return "cmux" }
            if lower.contains("warp") { return "Warp" }
            if lower == "com.mitchellh.ghostty" { return "Ghostty" }
            if lower == "com.aiyuai.aiyuterm" || lower == "com.aiyuai.aiyuterm.debug" { return "AiyuTerm" }
            if lower.contains("iterm2") { return "iTerm2" }
            if lower.contains("kitty") { return "Kitty" }
            if lower.contains("alacritty") { return "Alacritty" }
            if lower.contains("wezterm") { return "WezTerm" }
            // IDE integrated terminals
            if lower.contains("vscode") || lower.contains("vscodium") { return "VS Code" }
            if lower == "com.trae.app" { return "Trae" }
            if lower.contains("windsurf") { return "Windsurf" }
            if lower.contains("jetbrains") {
                if lower.contains("intellij") { return "IDEA" }
                if lower.contains("pycharm") { return "PyCharm" }
                if lower.contains("webstorm") { return "WebStorm" }
                if lower.contains("goland") { return "GoLand" }
                if lower.contains("clion") { return "CLion" }
                if lower.contains("rider") { return "Rider" }
                if lower.contains("rubymine") { return "RubyMine" }
                if lower.contains("phpstorm") { return "PhpStorm" }
                if lower.contains("datagrip") { return "DataGrip" }
                return "JetBrains"
            }
            if lower.contains("zed") { return "Zed" }
            if lower.contains("xcode") || lower == "com.apple.dt.xcode" { return "Xcode" }
            if lower.contains("panic.nova") { return "Nova" }
            if lower.contains("android.studio") { return "Android Studio" }
            if lower.contains("antigravity") { return "Antigravity" }
        }
        guard let app = termApp else { return nil }
        let lower = app.lowercased()
        if lower.contains("cmux") { return "cmux" }
        if lower == "ghostty" { return "Ghostty" }
        if lower.contains("iterm") { return "iTerm2" }
        if lower.contains("warp") { return "Warp" }
        if lower.contains("alacritty") { return "Alacritty" }
        if lower.contains("kitty") { return "Kitty" }
        if lower.contains("terminal") { return "Terminal" }
        return app
    }

    /// Subtitle: cwd path or model info.
    var subtitle: String? {
        if let cwd = cwd {
            let parts = cwd.split(separator: "/")
            if parts.count >= 2 {
                return "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
            }
            return cwd
        }
        return model
    }
}

// MARK: - Session summary

struct AgentSessionSummary {
    let status: AgentHookStatus
    let primarySource: String
    let activeSessionCount: Int
    let totalSessionCount: Int

    init(status: AgentHookStatus, primarySource: String, activeSessionCount: Int, totalSessionCount: Int) {
        self.status = status
        self.primarySource = primarySource
        self.activeSessionCount = activeSessionCount
        self.totalSessionCount = totalSessionCount
    }
}

func deriveAgentSessionSummary(from sessions: [String: AgentSessionSnapshot]) -> AgentSessionSummary {
    var highestStatus: AgentHookStatus = .idle
    var source = "claude"
    var active = 0
    var mostRecentIdleSource: (source: String, time: Date)?

    for session in sessions.values {
        if session.status != .idle {
            active += 1
        } else if mostRecentIdleSource == nil || session.lastActivity > mostRecentIdleSource!.time {
            mostRecentIdleSource = (session.source, session.lastActivity)
        }

        switch session.status {
        case .waitingApproval:
            highestStatus = .waitingApproval
            source = session.source
        case .waitingQuestion:
            if highestStatus != .waitingApproval {
                highestStatus = .waitingQuestion
                source = session.source
            }
        case .running:
            if highestStatus == .idle || highestStatus == .processing {
                highestStatus = .running
                source = session.source
            }
        case .processing:
            if highestStatus == .idle {
                highestStatus = .processing
                source = session.source
            }
        case .idle:
            break
        }
    }

    if highestStatus == .idle, let idleSource = mostRecentIdleSource?.source {
        source = idleSource
    }

    return AgentSessionSummary(
        status: highestStatus,
        primarySource: source,
        activeSessionCount: active,
        totalSessionCount: sessions.count
    )
}

// MARK: - Side effects

/// Side effects emitted by the reducer. AiyuTerm's mapper consumes
/// these on the main actor and either forwards them to the UI layer
/// or discards them (e.g. `playSound`).
enum AgentSessionSideEffect: Equatable {
    case playSound(String)
    case tryMonitorSession(sessionId: String)
    case stopMonitor(sessionId: String)
    case removeSession(sessionId: String)
    case enqueueCompletion(sessionId: String)
    case setActiveSession(sessionId: String?)
}

// MARK: - Pure reducer

/// Pure reducer: mutates sessions, returns side effects for the caller
/// to execute. Intentionally side-effect free so that tests can pin
/// behaviour by value comparison.
func reduceAgentHookEvent(
    sessions: inout [String: AgentSessionSnapshot],
    event: AgentHookEvent,
    maxHistory: Int
) -> [AgentSessionSideEffect] {
    let sessionId = event.sessionId ?? "default"
    let eventName = AgentHookEventNormalizer.normalize(event.eventName)
    var effects: [AgentSessionSideEffect] = []

    // Ensure session exists
    if sessions[sessionId] == nil {
        sessions[sessionId] = AgentSessionSnapshot()
    }

    // Always update metadata from every event
    extractAgentSessionMetadata(into: &sessions, sessionId: sessionId, event: event)

    // Route subagent-specific events
    if let agentId = event.agentId {
        let handled = handleAgentSubagentEvent(
            sessions: &sessions,
            sessionId: sessionId,
            agentId: agentId,
            eventName: eventName,
            event: event,
            maxHistory: maxHistory,
            effects: &effects
        )
        if handled { return effects }
    }

    // Preserve actionable states: don't let activity updates overwrite waiting states
    let isWaiting = sessions[sessionId]?.status == .waitingApproval
        || sessions[sessionId]?.status == .waitingQuestion

    switch eventName {
    case "UserPromptSubmit":
        sessions[sessionId]?.interrupted = false
        sessions[sessionId]?.status = .processing
        sessions[sessionId]?.currentTool = nil
        sessions[sessionId]?.toolDescription = nil
        let prompt = event.rawJSON["prompt"] as? String
            ?? event.rawJSON["user_prompt"] as? String
            ?? event.rawJSON["message"] as? String
            ?? event.rawJSON["input"] as? String
            ?? event.rawJSON["content"] as? String
        if let prompt {
            sessions[sessionId]?.lastUserPrompt = prompt
            if sessions[sessionId]?.recentMessages.last?.isUser == true {
                sessions[sessionId]?.recentMessages.removeLast()
            }
            sessions[sessionId]?.addRecentMessage(AgentChatMessage(isUser: true, text: prompt))
        }
    case "PreToolUse":
        if !isWaiting {
            sessions[sessionId]?.status = .running
            sessions[sessionId]?.currentTool = event.toolName
            sessions[sessionId]?.toolDescription = event.toolDescription
        }
    case "PostToolUse":
        if let tool = sessions[sessionId]?.currentTool {
            let desc = sessions[sessionId]?.toolDescription
            sessions[sessionId]?.recordTool(tool, description: desc, success: true, agentType: nil, maxHistory: maxHistory)
        }
        if !isWaiting {
            sessions[sessionId]?.status = .processing
            sessions[sessionId]?.currentTool = nil
            sessions[sessionId]?.toolDescription = nil
        }
    case "PostToolUseFailure":
        if let tool = sessions[sessionId]?.currentTool {
            let desc = sessions[sessionId]?.toolDescription
            sessions[sessionId]?.recordTool(tool, description: desc, success: false, agentType: nil, maxHistory: maxHistory)
        }
        if !isWaiting {
            sessions[sessionId]?.status = .processing
            sessions[sessionId]?.currentTool = nil
            sessions[sessionId]?.toolDescription = nil
        }
    case "PermissionDenied":
        if !isWaiting {
            sessions[sessionId]?.status = .processing
            sessions[sessionId]?.currentTool = nil
            sessions[sessionId]?.toolDescription = nil
        }
    case "SubagentStart":
        if !isWaiting {
            sessions[sessionId]?.status = .running
            sessions[sessionId]?.currentTool = "Agent"
            sessions[sessionId]?.toolDescription = event.rawJSON["agent_type"] as? String
        }
    case "SubagentStop":
        if !isWaiting {
            sessions[sessionId]?.status = .processing
            sessions[sessionId]?.currentTool = nil
            sessions[sessionId]?.toolDescription = nil
        }
    case "AfterAgentResponse":
        if let text = event.rawJSON["text"] as? String, !text.isEmpty {
            sessions[sessionId]?.lastAssistantMessage = text
            sessions[sessionId]?.addRecentMessage(AgentChatMessage(isUser: false, text: text))
        }
        sessions[sessionId]?.status = .processing
    case "Stop":
        let stopReason = event.rawJSON["stop_reason"] as? String ?? ""
        sessions[sessionId]?.interrupted = (stopReason == "user" || stopReason == "interrupted")
        sessions[sessionId]?.status = .idle
        sessions[sessionId]?.currentTool = nil
        sessions[sessionId]?.toolDescription = nil
        let assistantMsg = event.rawJSON["last_assistant_message"] as? String
            ?? event.rawJSON["text"] as? String
            ?? event.rawJSON["message"] as? String
        if let msg = assistantMsg {
            sessions[sessionId]?.lastAssistantMessage = msg
            sessions[sessionId]?.addRecentMessage(AgentChatMessage(isUser: false, text: msg))
        } else if sessions[sessionId]?.lastAssistantMessage == nil,
                  sessions[sessionId]?.recentMessages.last?.isUser == true
        {
            sessions[sessionId]?.addRecentMessage(AgentChatMessage(isUser: false, text: "[Reply complete]"))
        }
        if sessions[sessionId]?.lastUserPrompt == nil {
            if let prompt = event.rawJSON["last_user_message"] as? String {
                sessions[sessionId]?.lastUserPrompt = prompt
                let insertAt = max(0, (sessions[sessionId]?.recentMessages.count ?? 1) - 1)
                sessions[sessionId]?.insertRecentMessage(AgentChatMessage(isUser: true, text: prompt), at: insertAt)
            }
        }
        effects.append(.enqueueCompletion(sessionId: sessionId))
    case "SessionStart":
        effects.append(.stopMonitor(sessionId: sessionId))
        sessions[sessionId] = AgentSessionSnapshot(startTime: Date())
        // Re-apply metadata from this event (common extraction above wrote to the old session)
        if let cwd = event.rawJSON["cwd"] as? String, !cwd.isEmpty { sessions[sessionId]?.cwd = cwd }
        if let model = event.rawJSON["model"] as? String, !model.isEmpty { sessions[sessionId]?.model = model }
        if let ppid = event.rawJSON["_ppid"] as? Int, ppid > 0 {
            sessions[sessionId]?.cliPid = pid_t(ppid)
            sessions[sessionId]?.cliStartTime = nil
        }
        if let source = AgentSessionSnapshot.normalizedSupportedSource(event.rawJSON["_source"] as? String) {
            sessions[sessionId]?.source = source
        }
        if let app = event.rawJSON["_term_app"] as? String, !app.isEmpty { sessions[sessionId]?.termApp = app }
        if let bundle = event.rawJSON["_term_bundle"] as? String, !bundle.isEmpty { sessions[sessionId]?.termBundleId = bundle }
        if let ses = event.rawJSON["_iterm_session"] as? String, !ses.isEmpty { sessions[sessionId]?.itermSessionId = ses }
        if let tty = event.rawJSON["_tty"] as? String, !tty.isEmpty { sessions[sessionId]?.ttyPath = tty }
        if let kitty = event.rawJSON["_kitty_window"] as? String, !kitty.isEmpty { sessions[sessionId]?.kittyWindowId = kitty }
        if let pane = event.rawJSON["_tmux_pane"] as? String, !pane.isEmpty { sessions[sessionId]?.tmuxPane = pane }
        if let tmuxTty = event.rawJSON["_tmux_client_tty"] as? String, !tmuxTty.isEmpty { sessions[sessionId]?.tmuxClientTty = tmuxTty }
        if let tmux = event.rawJSON["_tmux"] as? String, !tmux.isEmpty { sessions[sessionId]?.tmuxEnv = tmux }
        if let mode = event.rawJSON["permission_mode"] as? String { sessions[sessionId]?.permissionMode = mode }
        if let roots = event.rawJSON["workspace_roots"] as? [String], let first = roots.first, !first.isEmpty {
            sessions[sessionId]?.cwd = first
        }
        effects.append(.tryMonitorSession(sessionId: sessionId))
    case "SessionEnd":
        effects.append(.removeSession(sessionId: sessionId))
        return effects
    case "Notification":
        if let msg = event.rawJSON["message"] as? String {
            sessions[sessionId]?.toolDescription = msg
        }
        if AgentQuestionPayload.from(event: event) != nil {
            sessions[sessionId]?.status = .waitingQuestion
        }
    case "PreCompact":
        sessions[sessionId]?.status = .processing
        sessions[sessionId]?.toolDescription = "Compacting context\u{2026}"
    default:
        break
    }

    sessions[sessionId]?.lastActivity = Date()

    if sessions[sessionId]?.cwd != nil {
        effects.append(.tryMonitorSession(sessionId: sessionId))
    }

    effects.append(.playSound(eventName))

    if eventName == "Stop" {
        // Stop event: keep activeSessionId on completed session
        // (set by enqueueCompletion)
    } else if sessions[sessionId]?.status != .idle {
        effects.append(.setActiveSession(sessionId: sessionId))
    }

    return effects
}

// MARK: - Metadata extraction

func extractAgentSessionMetadata(
    into sessions: inout [String: AgentSessionSnapshot],
    sessionId: String,
    event: AgentHookEvent
) {
    if let cwd = event.rawJSON["cwd"] as? String, !cwd.isEmpty {
        sessions[sessionId]?.cwd = cwd
    } else if sessions[sessionId]?.cwd == nil,
              let roots = event.rawJSON["workspace_roots"] as? [String],
              let first = roots.first, !first.isEmpty
    {
        sessions[sessionId]?.cwd = first
    } else if sessions[sessionId]?.cwd == nil,
              let tp = event.rawJSON["transcript_path"] as? String, !tp.isEmpty
    {
        // Cursor: extract project dir from transcript_path
        let parts = tp.split(separator: "/")
        if let idx = parts.firstIndex(of: "projects"), idx + 1 < parts.count {
            let projectName = String(parts[idx + 1])
            sessions[sessionId]?.cwd = "/\(parts[...idx].joined(separator: "/"))/\(projectName)"
        }
    }
    if let model = event.rawJSON["model"] as? String, !model.isEmpty {
        sessions[sessionId]?.model = model
    }
    if let mode = event.rawJSON["permission_mode"] as? String {
        sessions[sessionId]?.permissionMode = mode
    }
    if let app = event.rawJSON["_term_app"] as? String, !app.isEmpty, app != "unknown" {
        sessions[sessionId]?.termApp = app
    }
    if let ses = event.rawJSON["_iterm_session"] as? String, !ses.isEmpty {
        sessions[sessionId]?.itermSessionId = ses
    }
    if let tty = event.rawJSON["_tty"] as? String, !tty.isEmpty {
        sessions[sessionId]?.ttyPath = tty
    }
    if let kitty = event.rawJSON["_kitty_window"] as? String, !kitty.isEmpty {
        sessions[sessionId]?.kittyWindowId = kitty
    }
    if let pane = event.rawJSON["_tmux_pane"] as? String, !pane.isEmpty {
        sessions[sessionId]?.tmuxPane = pane
    }
    if let tmuxTty = event.rawJSON["_tmux_client_tty"] as? String, !tmuxTty.isEmpty {
        sessions[sessionId]?.tmuxClientTty = tmuxTty
    }
    if let tmux = event.rawJSON["_tmux"] as? String, !tmux.isEmpty {
        sessions[sessionId]?.tmuxEnv = tmux
    }
    if let bundle = event.rawJSON["_term_bundle"] as? String, !bundle.isEmpty {
        sessions[sessionId]?.termBundleId = bundle
    }
    if let env = event.rawJSON["_env"] as? [String: String] {
        if sessions[sessionId]?.termApp == nil,
           let app = env["TERM_PROGRAM"], !app.isEmpty
        {
            sessions[sessionId]?.termApp = app
        }
        if sessions[sessionId]?.termBundleId == nil,
           let bundle = env["__CFBundleIdentifier"], !bundle.isEmpty
        {
            sessions[sessionId]?.termBundleId = bundle
        }
        if sessions[sessionId]?.itermSessionId == nil,
           let ses = env["ITERM_SESSION_ID"], !ses.isEmpty
        {
            if let colonIdx = ses.firstIndex(of: ":") {
                sessions[sessionId]?.itermSessionId = String(ses[ses.index(after: colonIdx)...])
            } else {
                sessions[sessionId]?.itermSessionId = ses
            }
        }
        if sessions[sessionId]?.kittyWindowId == nil,
           let kitty = env["KITTY_WINDOW_ID"], !kitty.isEmpty
        {
            sessions[sessionId]?.kittyWindowId = kitty
        }
        if sessions[sessionId]?.tmuxPane == nil,
           let pane = env["TMUX_PANE"], !pane.isEmpty
        {
            sessions[sessionId]?.tmuxPane = pane
        }
    }
    if let ppid = event.rawJSON["_ppid"] as? Int, ppid > 0 {
        sessions[sessionId]?.cliPid = pid_t(ppid)
        sessions[sessionId]?.cliStartTime = nil
    }
    if let source = AgentSessionSnapshot.normalizedSupportedSource(event.rawJSON["_source"] as? String) {
        sessions[sessionId]?.source = source
    }
}

// MARK: - Subagent event handling

/// Handle subagent events. Returns true if the event was consumed.
private func handleAgentSubagentEvent(
    sessions: inout [String: AgentSessionSnapshot],
    sessionId: String,
    agentId: String,
    eventName: String,
    event: AgentHookEvent,
    maxHistory: Int,
    effects: inout [AgentSessionSideEffect]
) -> Bool {
    switch eventName {
    case "SubagentStart":
        let agentType = event.rawJSON["agent_type"] as? String ?? "Agent"
        sessions[sessionId]?.subagents[agentId] = AgentSubagentState(
            agentId: agentId,
            agentType: agentType
        )
        if sessions[sessionId]?.status == .idle || sessions[sessionId]?.status == .processing {
            sessions[sessionId]?.status = .running
            sessions[sessionId]?.currentTool = "Agent"
            sessions[sessionId]?.toolDescription = agentType
        }
        sessions[sessionId]?.lastActivity = Date()
        effects.append(.setActiveSession(sessionId: sessionId))
        return true

    case "SubagentStop":
        sessions[sessionId]?.subagents.removeValue(forKey: agentId)
        if sessions[sessionId]?.subagents.isEmpty == true {
            if sessions[sessionId]?.status == .running && sessions[sessionId]?.currentTool == "Agent" {
                sessions[sessionId]?.status = .processing
                sessions[sessionId]?.currentTool = nil
                sessions[sessionId]?.toolDescription = nil
            }
        }
        sessions[sessionId]?.lastActivity = Date()
        return true

    case "PreToolUse":
        sessions[sessionId]?.subagents[agentId]?.status = .running
        sessions[sessionId]?.subagents[agentId]?.currentTool = event.toolName
        sessions[sessionId]?.subagents[agentId]?.toolDescription = event.toolDescription
        sessions[sessionId]?.subagents[agentId]?.lastActivity = Date()
        if sessions[sessionId]?.status != .waitingApproval && sessions[sessionId]?.status != .waitingQuestion {
            sessions[sessionId]?.status = .running
        }
        sessions[sessionId]?.lastActivity = Date()
        return true

    case "PostToolUse":
        if let tool = sessions[sessionId]?.subagents[agentId]?.currentTool {
            let agentType = sessions[sessionId]?.subagents[agentId]?.agentType
            let desc = sessions[sessionId]?.subagents[agentId]?.toolDescription
            sessions[sessionId]?.recordTool(tool, description: desc, success: true, agentType: agentType, maxHistory: maxHistory)
        }
        sessions[sessionId]?.subagents[agentId]?.status = .processing
        sessions[sessionId]?.subagents[agentId]?.currentTool = nil
        sessions[sessionId]?.subagents[agentId]?.toolDescription = nil
        sessions[sessionId]?.subagents[agentId]?.lastActivity = Date()
        sessions[sessionId]?.lastActivity = Date()
        return true

    case "PostToolUseFailure":
        if let tool = sessions[sessionId]?.subagents[agentId]?.currentTool {
            let agentType = sessions[sessionId]?.subagents[agentId]?.agentType
            let desc = sessions[sessionId]?.subagents[agentId]?.toolDescription
            sessions[sessionId]?.recordTool(tool, description: desc, success: false, agentType: agentType, maxHistory: maxHistory)
        }
        sessions[sessionId]?.subagents[agentId]?.status = .processing
        sessions[sessionId]?.subagents[agentId]?.currentTool = nil
        sessions[sessionId]?.subagents[agentId]?.toolDescription = nil
        sessions[sessionId]?.lastActivity = Date()
        return true

    default:
        return false
    }
}
