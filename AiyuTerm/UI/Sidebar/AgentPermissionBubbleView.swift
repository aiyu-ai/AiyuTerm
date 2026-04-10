//
// AgentPermissionBubbleView.swift
// AiyuTerm
//
// Phase 6.2 SwiftUI layer: sidebar bubble that drains pending
// permission and question requests from WorkspaceModel.
//
// The bubble renders beneath the worktree row whenever
// `pendingPermissionRequests[worktreePath]` or
// `pendingQuestionRequests[worktreePath]` is non-nil. Clicking an
// action button calls into WorkspaceStore, which routes through
// AgentHookEventMapper and resumes the suspended continuation inside
// AgentHookServer so the bridge binary finally responds to Claude
// Code. This is what removes the need to tab back into the terminal
// to answer "Allow this command?".
//

import SwiftUI

// MARK: - Permission bubble

/// Compact card shown under a worktree row when there is a pending
/// PermissionRequest. Three actions: Deny, Allow (once), Always.
struct AgentPermissionBubbleView: View {
    let request: AgentPermissionRequest
    let onApproveOnce: () -> Void
    let onApproveAlways: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            body(text: bodyText)
            actionRow
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.pink.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Private subviews

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pink)
            Text(request.toolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func body(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.secondary)
            .lineLimit(3)
            .truncationMode(.middle)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            Button(role: .destructive, action: onDeny) {
                Text("Deny")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Button(action: onApproveOnce) {
                Text("Allow")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            .tint(.pink)

            Button(action: onApproveAlways) {
                Text("Always")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Spacer(minLength: 0)
        }
    }

    private var bodyText: String {
        if let description = request.toolDescription, !description.isEmpty {
            return description
        }
        return request.toolName + " is waiting for permission"
    }

    private var accessibilityLabel: String {
        "Permission requested for \(request.toolName). \(request.toolDescription ?? "")"
    }
}

// MARK: - Question bubble

/// Compact card shown under a worktree row when there is a pending
/// AskUserQuestion / Notification question. Renders the question
/// plus each option as a separate button.
struct AgentQuestionBubbleView: View {
    let request: AgentQuestionRequest
    let onAnswer: (String) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(request.question)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let options = request.options, !options.isEmpty {
                optionList(options: options)
            } else {
                skipRow
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.blue)
            Text(request.header ?? "Question")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func optionList(options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    onAnswer(option)
                } label: {
                    HStack {
                        Text(option)
                            .font(.system(size: 10, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            Button("Skip", action: onSkip)
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
        }
    }

    private var skipRow: some View {
        HStack {
            Button("Skip", action: onSkip)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            Spacer(minLength: 0)
        }
    }
}
