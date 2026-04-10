//
// AgentNotchPanelView.swift
// AiyuTerm
//
// Phase 8.3: SwiftUI content for the notch activity panel.
//
// Two views live here:
//   • AgentNotchCollapsedView — the always-on pill that sits
//     inside the notch region, rendering the aggregated agent
//     status + a count badge for pending permission / question
//     requests.
//   • AgentNotchExpandedView — a larger card listing every
//     worktree with an active badge. Phase 8.3 keeps this simple;
//     future phases can add per-worktree action shortcuts that
//     mirror the sidebar bubble, a "jump to terminal" button,
//     etc.
//
// Data source: a small observable VM class wraps the
// WorkspaceStore so the SwiftUI tree only sees a stable struct.
// This keeps the view layer loosely coupled to WorkspaceStore and
// makes Phase 8.3 unit testable via a fake VM factory.
//

import AppKit
import Combine
import SwiftUI

// MARK: - View model

/// Observable snapshot of the per-worktree activity the notch
/// panel cares about. Built from a `WorkspaceStore` by the
/// `AgentNotchPanelViewModel` but can also be constructed
/// directly in tests.
struct AgentNotchWorktreeSnapshot: Identifiable, Equatable {
    let id: String // worktree path
    let workspaceName: String
    let worktreeDisplayName: String
    let status: AgentSessionStatus
    let hasPendingPermission: Bool
    let hasPendingQuestion: Bool
}

/// Aggregated view state that the notch panel renders. Equatable
/// so SwiftUI can diff without re-rendering identical snapshots.
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
}

/// Observable view-model consumed by AgentNotchCollapsedView +
/// AgentNotchExpandedView. Production builds obtain one via
/// `WorkspaceStore.makeNotchPanelViewModel()`; tests can construct
/// one directly with a fixed state.
///
/// Uses the Swift Observation framework (`@Observable`, macOS 14+)
/// instead of the older `ObservableObject` + `@Published`
/// combination. The reason is a Swift 6 runtime trap: an
/// `@ObservableObject` class that owns `@Published` properties
/// trips `swift_task_deinitOnExecutorMainActorBackDeploy` ->
/// `libmalloc POINTER_BEING_FREED_WAS_NOT_ALLOCATED` when a
/// test-local instance goes out of scope. We hit the same trap in
/// Phase 5.4 with `InMemoryAgentCLIEnablementStore`. The
/// `@Observable` macro generates a different observation storage
/// shape that avoids the Combine + MainActor-backdeploy collision.
@Observable
final class AgentNotchPanelViewModel: @unchecked Sendable {
    private(set) var state: AgentNotchViewState

    /// Closure invoked when the user clicks the collapsed pill.
    /// Phase 8.2's panel controller drives the toggle.
    @ObservationIgnored
    var onTogglePanel: (() -> Void)?

    init(state: AgentNotchViewState = .empty) {
        self.state = state
    }

    func update(state: AgentNotchViewState) {
        self.state = state
    }
}

// MARK: - Content router

/// Binary-state router: when the view-model's state is idle we
/// render the pill; otherwise the expanded card. Phase 8.3 keeps
/// this decision inside the view so the panel controller does not
/// need to re-anchor its frame — both states share the notch
/// rect horizontally. A future phase can animate the panel's
/// actual NSPanel frame.
struct AgentNotchPanelView: View {
    let viewModel: AgentNotchPanelViewModel
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            if isExpanded {
                AgentNotchExpandedView(state: viewModel.state) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded = false
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                AgentNotchCollapsedView(state: viewModel.state) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Collapsed view

/// The always-on pill. Width hugs its content so the panel
/// controller can size the NSPanel frame to match.
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
                        .background(
                            Capsule().fill(pendingBadgeColor)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.black.opacity(0.86))
            )
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

// MARK: - Expanded view

/// Larger card that lists every worktree. Phase 8.3 keeps the
/// interactions minimal — just a label per worktree + a close
/// button. Phase 8.4+ can add per-worktree permission shortcuts.
struct AgentNotchExpandedView: View {
    let state: AgentNotchViewState
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if state.worktrees.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.worktrees) { worktree in
                            worktreeRow(worktree)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 380, height: 260)
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

    @ViewBuilder
    private func worktreeRow(_ worktree: AgentNotchWorktreeSnapshot) -> some View {
        HStack(spacing: 8) {
            statusDot(worktree.status, hasPending: worktree.hasPendingPermission || worktree.hasPendingQuestion)
            VStack(alignment: .leading, spacing: 0) {
                Text(worktree.workspaceName)
                    .font(.system(size: 11, weight: .medium))
                Text(worktree.worktreeDisplayName)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if worktree.hasPendingPermission {
                Text("permission")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.pink)
            } else if worktree.hasPendingQuestion {
                Text("question")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func statusDot(_ status: AgentSessionStatus, hasPending: Bool) -> some View {
        Circle()
            .fill(dotColor(for: status, hasPending: hasPending))
            .frame(width: 8, height: 8)
    }

    private func dotColor(for status: AgentSessionStatus, hasPending: Bool) -> Color {
        if hasPending { return .pink }
        switch status {
        case .working: return .blue
        case .permissionNeeded: return .pink
        case .taskCompleted: return .green
        case .error: return .red
        case .none: return .secondary
        }
    }
}
