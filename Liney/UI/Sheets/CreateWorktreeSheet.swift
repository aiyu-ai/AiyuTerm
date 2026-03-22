//
//  CreateWorktreeSheet.swift
//  Liney
//
//  Author: wuwenrui
//

import AppKit
import SwiftUI

struct CreateWorktreeSheet: View {
    let request: CreateWorktreeSheetRequest
    let onSubmit: (CreateWorktreeDraft) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CreateWorktreeDraft
    @State private var parentDirectoryPath: String
    @FocusState private var isBranchFieldFocused: Bool

    init(request: CreateWorktreeSheetRequest, onSubmit: @escaping (CreateWorktreeDraft) -> Bool) {
        self.request = request
        self.onSubmit = onSubmit

        let branchName = (request.repositoryRoot as NSString).lastPathComponent
        let parentDirectoryPath = URL(fileURLWithPath: request.repositoryRoot)
            .deletingLastPathComponent()
            .standardizedFileURL
            .path

        _draft = State(
            initialValue: CreateWorktreeDraft(
                directoryPath: URL(fileURLWithPath: parentDirectoryPath)
                    .appendingPathComponent(branchName)
                    .standardizedFileURL
                    .path,
                branchName: branchName
            )
        )
        _parentDirectoryPath = State(initialValue: parentDirectoryPath)
    }

    private var validationMessage: String? {
        if draft.normalizedDirectoryPath.isEmpty {
            return "Directory path is required."
        }
        if draft.normalizedBranchName.isEmpty {
            return "Branch name is required."
        }
        if draft.normalizedBranchName.contains(" ") {
            return "Branch names cannot contain spaces."
        }
        if FileManager.default.fileExists(atPath: draft.normalizedDirectoryPath) {
            return "This path already exists. Please keep adding to the branch name."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create Worktree")
                .font(.title2.weight(.semibold))

            Text(request.repositoryRoot.abbreviatedPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Directory Path")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 6) {
                        directoryActionButton(
                            systemImage: "folder.badge.gearshape",
                            help: "Choose parent directory",
                            action: chooseParentDirectory
                        )
                        directoryActionButton(
                            systemImage: "arrow.up.forward.app",
                            help: "Open in Finder",
                            action: openDirectoryInFinder
                        )
                        .disabled(draft.directoryPath.isEmpty)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target folder preview")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(draft.directoryPath.isEmpty ? "/path/to/new/worktree" : draft.directoryPath)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(draft.directoryPath.isEmpty ? .tertiary : .primary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .controlBackgroundColor).opacity(0.92),
                            Color(nsColor: .controlBackgroundColor).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                Text("Branch Name")
                    .font(.headline)
                TextField("feature/my-branch", text: $draft.branchName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isBranchFieldFocused)

                Toggle("Create new branch", isOn: $draft.createNewBranch)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    if onSubmit(draft) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validationMessage != nil)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.async {
                isBranchFieldFocused = true
                DispatchQueue.main.async {
                    moveBranchInsertionPointToEnd()
                }
            }
        }
        .onChange(of: draft.branchName) { _, newValue in
            updateSuggestedDirectoryPath(for: newValue)
        }
    }

    private func chooseParentDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: parentDirectoryPath)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        parentDirectoryPath = url.standardizedFileURL.path
        updateSuggestedDirectoryPath(for: draft.branchName)
    }

    private func updateSuggestedDirectoryPath(for branchName: String) {
        let trimmed = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draft.directoryPath = ""
        } else {
            let leafName = trimmed.replacingOccurrences(of: "/", with: "-")
            draft.directoryPath = URL(fileURLWithPath: parentDirectoryPath)
                .appendingPathComponent(leafName)
                .standardizedFileURL
                .path
        }
    }

    private func openDirectoryInFinder() {
        let normalizedPath = URL(fileURLWithPath: draft.directoryPath)
            .standardizedFileURL
            .path

        guard !normalizedPath.isEmpty else { return }

        let targetURL = URL(fileURLWithPath: normalizedPath)
        if FileManager.default.fileExists(atPath: normalizedPath) {
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            return
        }

        NSWorkspace.shared.open(targetURL.deletingLastPathComponent())
    }

    @ViewBuilder
    private func directoryActionButton(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .help(help)
    }

    private func moveBranchInsertionPointToEnd() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let location = (draft.branchName as NSString).length
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
    }
}
