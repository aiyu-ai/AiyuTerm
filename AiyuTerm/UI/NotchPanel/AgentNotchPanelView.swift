//
// AgentNotchPanelView.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/NotchPanelView.swift (2045 LOC)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Phase 9.7 extends the Phase 8.3 skeleton into a full functional
// port of CodeIsland's notch panel. We intentionally keep the
// visual language plain (material card, system fonts) rather than
// porting CodeIsland's pixel-art components (ClaudeLogoShape,
// PixelText, MiniAgentIcon, etc.) — those are decorative and
// specific to CodeIsland's aesthetic. What we DO port:
//
//   • Collapsed pill w/ aggregated status + pending badge
//   • Expanded card w/ per-session rows
//   • Inline approval bar (approve-once / approve-always / deny)
//   • Inline question bar (one option per row)
//   • Session metadata (source tag, model, cwd, current tool)
//   • Recent messages block using AgentChatMessageTextFormatter
//   • Jump-to-terminal button (AgentTerminalActivator)
//
// The view-model now carries rich per-worktree snapshots plus
// action callbacks that the `WorkspaceStore` wires up at the
// panel's birth. Tests drive the view-model directly.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Per-worktree snapshot

/// Rich snapshot of the activity on one worktree that the notch
/// panel cares about. Built from a `WorkspaceModel` by
/// `WorkspaceStore.currentNotchViewState()` but can also be
/// constructed directly in tests.
struct AgentNotchWorktreeSnapshot: Identifiable, Equatable {
    let id: String // worktree path
    let workspaceName: String
    let worktreeDisplayName: String
    let status: AgentSessionStatus
    /// Source tag (`claude`, `codex`, `gemini`, …).
    let source: String
    /// `model` from the last session snapshot, if any.
    let model: String?
    /// Current working directory reported by the bridge.
    let cwd: String?
    /// Human-readable current tool name (only set during
    /// `.working`).
    let currentTool: String?
    /// Tool description / preview (e.g. the Bash command).
    let toolDescription: String?
    /// Most recent assistant message from the agent (for preview).
    let lastAssistantMessage: String?
    /// Most recent user prompt (shown dimmed above the assistant
    /// message).
    let lastUserPrompt: String?
    /// Pending permission request waiting on a UI decision.
    let permissionRequest: AgentPermissionRequest?
    /// Pending question waiting on an answer.
    let questionRequest: AgentQuestionRequest?
    /// Phase 10.1.b: human-friendly session title resolved from
    /// the provider's on-disk state (Claude custom/ai title, Codex
    /// thread name). Nil when no title is available, in which case
    /// the card falls back to the workspace name.
    let resolvedTitle: String?

    var hasPendingPermission: Bool { permissionRequest != nil }
    var hasPendingQuestion: Bool { questionRequest != nil }

    init(
        id: String,
        workspaceName: String,
        worktreeDisplayName: String,
        status: AgentSessionStatus,
        source: String,
        model: String? = nil,
        cwd: String? = nil,
        currentTool: String? = nil,
        toolDescription: String? = nil,
        lastAssistantMessage: String? = nil,
        lastUserPrompt: String? = nil,
        permissionRequest: AgentPermissionRequest? = nil,
        questionRequest: AgentQuestionRequest? = nil,
        resolvedTitle: String? = nil
    ) {
        self.id = id
        self.workspaceName = workspaceName
        self.worktreeDisplayName = worktreeDisplayName
        self.status = status
        self.source = source
        self.model = model
        self.cwd = cwd
        self.currentTool = currentTool
        self.toolDescription = toolDescription
        self.lastAssistantMessage = lastAssistantMessage
        self.lastUserPrompt = lastUserPrompt
        self.permissionRequest = permissionRequest
        self.questionRequest = questionRequest
        self.resolvedTitle = resolvedTitle
    }
}

// MARK: - Aggregated view state

/// Top-level snapshot the notch panel renders. Equatable so
/// SwiftUI can skip re-renders when the store pushes an
/// unchanged state.
struct AgentNotchViewState: Equatable {
    let aggregatedStatus: AgentSessionStatus
    let pendingCount: Int
    let worktrees: [AgentNotchWorktreeSnapshot]

    static let empty = AgentNotchViewState(
        aggregatedStatus: .none,
        pendingCount: 0,
        worktrees: []
    )

    var hasAnyActivity: Bool {
        aggregatedStatus != .none || pendingCount > 0
    }

    /// The worktree snapshots, sorted so pending items come
    /// first (permission > question), then working items, then
    /// everything else. Used by the expanded card to surface the
    /// most urgent sessions at the top.
    var sortedWorktrees: [AgentNotchWorktreeSnapshot] {
        AgentNotchViewStateSorting.sort(worktrees)
    }
}

// MARK: - Pure sorter (testable)

enum AgentNotchViewStateSorting {
    /// Pending permission → pending question → working →
    /// taskCompleted → error → rest. Stable within each bucket.
    static func sort(_ items: [AgentNotchWorktreeSnapshot]) -> [AgentNotchWorktreeSnapshot] {
        items
            .enumerated()
            .sorted { a, b in
                let p1 = priority(for: a.element)
                let p2 = priority(for: b.element)
                if p1 != p2 { return p1 < p2 }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    private static func priority(for snapshot: AgentNotchWorktreeSnapshot) -> Int {
        if snapshot.hasPendingPermission { return 0 }
        if snapshot.hasPendingQuestion { return 1 }
        switch snapshot.status {
        case .working: return 2
        case .taskCompleted: return 3
        case .error: return 4
        case .permissionNeeded: return 5
        case .none: return 6
        }
    }
}

// MARK: - View model

/// Observable view-model consumed by the SwiftUI tree.
/// Production builds obtain one from
/// `WorkspaceStore.makeNotchPanelViewModel()`; tests can
/// construct one directly.
///
/// Uses the Swift Observation framework (`@Observable`, macOS
/// 14+) rather than the older `ObservableObject` + `@Published`
/// pair because the latter trips the libmalloc
/// `POINTER_BEING_FREED_WAS_NOT_ALLOCATED` trap on deinit under
/// Swift 6 strict concurrency (see `InMemoryAgentCLIEnablementStore`
/// for the same workaround).
@Observable
final class AgentNotchPanelViewModel: @unchecked Sendable {
    private(set) var state: AgentNotchViewState

    // MARK: Action callbacks
    //
    // All closures are `@ObservationIgnored` so assigning them
    // doesn't trigger a SwiftUI re-render — only `state` changes
    // should drive updates.

    @ObservationIgnored
    var onTogglePanel: (() -> Void)?

    /// Invoked when the user picks "Allow Once" / "Allow Always"
    /// in the inline approval bar. `worktreePath` uniquely
    /// identifies the pending request.
    @ObservationIgnored
    var onApprovePermission: ((String, AgentPermissionDecision) -> Void)?

    /// Invoked when the user clicks Deny on the inline approval
    /// bar.
    @ObservationIgnored
    var onDenyPermission: ((String) -> Void)?

    /// Invoked with the selected answer text when the user picks
    /// an option in the inline question bar.
    @ObservationIgnored
    var onAnswerQuestion: ((String, String) -> Void)?

    /// Invoked when the user clicks "Jump to terminal" on a
    /// session row — hooks into `AgentTerminalActivator`.
    @ObservationIgnored
    var onJumpToTerminal: ((AgentNotchWorktreeSnapshot) -> Void)?

    init(state: AgentNotchViewState = .empty) {
        self.state = state
    }

    func update(state: AgentNotchViewState) {
        self.state = state
    }
}

// MARK: - Top-level router

/// When the state is idle and there are no worktrees we render
/// the pill; any activity expands the card automatically. The
/// user can also toggle expansion by clicking the pill.
struct AgentNotchPanelView: View {
    let viewModel: AgentNotchPanelViewModel
    @State private var isUserExpanded = false

    private var autoExpand: Bool {
        // Pending work auto-expands the card so the user
        // doesn't miss an approval request.
        viewModel.state.worktrees.contains {
            $0.hasPendingPermission || $0.hasPendingQuestion
        }
    }

    private var isExpanded: Bool { isUserExpanded || autoExpand }

    var body: some View {
        ZStack {
            if isExpanded {
                AgentNotchExpandedView(
                    state: viewModel.state,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isUserExpanded = false
                        }
                    },
                    onApprove: { path, mode in
                        viewModel.onApprovePermission?(path, mode)
                    },
                    onDeny: { path in
                        viewModel.onDenyPermission?(path)
                    },
                    onAnswer: { path, answer in
                        viewModel.onAnswerQuestion?(path, answer)
                    },
                    onJumpToTerminal: { snapshot in
                        viewModel.onJumpToTerminal?(snapshot)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                AgentNotchCollapsedView(state: viewModel.state) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isUserExpanded = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Collapsed pill

struct AgentNotchCollapsedView: View {
    let state: AgentNotchViewState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                statusIcon
                if state.pendingCount > 0 {
                    Text("\(state.pendingCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(pendingBadgeColor))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.86)))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state.aggregatedStatus {
        case .working:
            ProgressView()
                .controlSize(.mini)
                .tint(Color.white)
                .frame(width: 12, height: 12)
        case .permissionNeeded:
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pink)
        case .taskCompleted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.red)
        case .none:
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private var pendingBadgeColor: Color {
        switch state.aggregatedStatus {
        case .permissionNeeded: return .pink
        case .error: return .red
        case .taskCompleted: return .green
        default: return .blue
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        switch state.aggregatedStatus {
        case .working: parts.append("agent working")
        case .permissionNeeded: parts.append("permission needed")
        case .taskCompleted: parts.append("task completed")
        case .error: parts.append("error")
        case .none: parts.append("idle")
        }
        if state.pendingCount > 0 {
            parts.append("\(state.pendingCount) pending")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Expanded card

struct AgentNotchExpandedView: View {
    let state: AgentNotchViewState
    let onClose: () -> Void
    let onApprove: (String, AgentPermissionDecision) -> Void
    let onDeny: (String) -> Void
    let onAnswer: (String, String) -> Void
    let onJumpToTerminal: (AgentNotchWorktreeSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if state.worktrees.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(state.sortedWorktrees) { worktree in
                            SessionCardView(
                                snapshot: worktree,
                                onApprove: onApprove,
                                onDeny: onDeny,
                                onAnswer: onAnswer,
                                onJumpToTerminal: onJumpToTerminal
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 420, height: 360)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var header: some View {
        HStack {
            Text("AiyuTerm Agents")
                .font(.system(size: 12, weight: .semibold))
            if state.pendingCount > 0 {
                Text("\(state.pendingCount) pending")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.pink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.pink.opacity(0.12))
                    )
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.secondary)
            Text("No active agents")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Session card

/// Per-session card inside the expanded panel. Shows the
/// workspace / worktree name, source tag, current tool, recent
/// chat messages, and either an inline approval/question bar or
/// a jump-to-terminal button depending on the session state.
struct SessionCardView: View {
    let snapshot: AgentNotchWorktreeSnapshot
    let onApprove: (String, AgentPermissionDecision) -> Void
    let onDeny: (String) -> Void
    let onAnswer: (String, String) -> Void
    let onJumpToTerminal: (AgentNotchWorktreeSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            metadataLine
            if let tool = snapshot.currentTool, !tool.isEmpty {
                toolLine(tool: tool, detail: snapshot.toolDescription)
            }
            if let last = snapshot.lastAssistantMessage, !last.isEmpty {
                messagePreview(last)
            }
            actionArea
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Title + metadata

    private var titleRow: some View {
        HStack(spacing: 8) {
            statusDot
            VStack(alignment: .leading, spacing: 0) {
                if let title = snapshot.resolvedTitle,
                   !title.isEmpty {
                    // Phase 10.1.b: provider-resolved title takes
                    // the headline slot; the workspace name
                    // shrinks to a secondary sub-line.
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(snapshot.workspaceName)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(snapshot.workspaceName)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(snapshot.worktreeDisplayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            sourceTag
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
    }

    private var dotColor: Color {
        if snapshot.hasPendingPermission { return .pink }
        if snapshot.hasPendingQuestion { return .blue }
        switch snapshot.status {
        case .working: return .blue
        case .permissionNeeded: return .pink
        case .taskCompleted: return .green
        case .error: return .red
        case .none: return .secondary
        }
    }

    private var sourceTag: some View {
        Text(snapshot.source.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(sourceColor(for: snapshot.source))
            )
    }

    private func sourceColor(for source: String) -> Color {
        switch source.lowercased() {
        case "claude": return .orange
        case "codex": return .purple
        case "gemini": return .blue
        case "cursor": return .teal
        case "copilot": return .indigo
        case "qoder": return .cyan
        case "codebuddy": return .green
        case "droid": return .red
        case "opencode": return .pink
        default: return .gray
        }
    }

    @ViewBuilder
    private var metadataLine: some View {
        let parts: [String] = [snapshot.model, snapshot.cwd.map {
            ($0 as NSString).lastPathComponent
        }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        if !parts.isEmpty {
            Text(parts.joined(separator: " • "))
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Tool line

    private func toolLine(tool: String, detail: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.blue)
            Text(tool)
                .font(.system(size: 10, weight: .medium))
            if let detail, !detail.isEmpty {
                Text("— \(detail)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - Message preview

    private func messagePreview(_ message: String) -> some View {
        let attributed = AgentChatMessageTextFormatter.inlineMarkdown(message)
        return Text(attributed)
            .font(.system(size: 11))
            .foregroundStyle(Color.primary)
            .lineLimit(3)
            .truncationMode(.tail)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        if let req = snapshot.permissionRequest {
            ApprovalBar(
                request: req,
                onApprove: { mode in onApprove(snapshot.id, mode) },
                onDeny: { onDeny(snapshot.id) }
            )
        } else if let q = snapshot.questionRequest {
            QuestionBar(
                request: q,
                onAnswer: { answer in onAnswer(snapshot.id, answer) }
            )
        } else {
            jumpToTerminalButton
        }
    }

    private var jumpToTerminalButton: some View {
        HStack {
            Spacer()
            Button(action: { onJumpToTerminal(snapshot) }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                    Text("Jump to terminal")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.blue.opacity(0.16))
                )
                .foregroundStyle(Color.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Approval bar

struct ApprovalBar: View {
    let request: AgentPermissionRequest
    let onApprove: (AgentPermissionDecision) -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.pink)
                Text("Permission request")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.pink)
                Spacer()
            }
            Text(request.toolName)
                .font(.system(size: 11, weight: .medium))
            if let desc = request.toolDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            HStack(spacing: 6) {
                Button("Allow Once") { onApprove(.allowOnce) }
                    .buttonStyle(PillButtonStyle(color: .green))
                Button("Allow Always") { onApprove(.allowAlways) }
                    .buttonStyle(PillButtonStyle(color: .blue))
                Spacer()
                Button("Deny") { onDeny() }
                    .buttonStyle(PillButtonStyle(color: .red))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.pink.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.pink.opacity(0.25), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Question bar

struct QuestionBar: View {
    let request: AgentQuestionRequest
    let onAnswer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.blue)
                Text(request.header ?? "Question")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.blue)
                Spacer()
            }
            Text(request.question)
                .font(.system(size: 11))
                .lineLimit(3)
            if let options = request.options, !options.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(options, id: \.self) { opt in
                        Button(action: { onAnswer(opt) }) {
                            HStack {
                                Text(opt)
                                    .font(.system(size: 10))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.blue.opacity(0.08))
                            )
                            .foregroundStyle(Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Button style

private struct PillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(configuration.isPressed ? 0.32 : 0.18))
            )
            .foregroundStyle(color)
    }
}
