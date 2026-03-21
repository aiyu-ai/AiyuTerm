//
//  MainWindowView.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isCanvasPresented = false

    private var hasSelectedWorkspace: Bool {
        store.selectedWorkspace != nil
    }

    private var hasFocusedPane: Bool {
        store.selectedWorkspace?.sessionController.focusedPaneID != nil
    }

    private var selectedWorkspaceSupportsGit: Bool {
        store.selectedWorkspace?.supportsRepositoryFeatures == true
    }

    private func dismissCanvas(restoreFocus: Bool = true) {
        isCanvasPresented = false
        guard restoreFocus,
              let workspace = store.selectedWorkspace,
              let focusedPaneID = workspace.sessionController.focusedPaneID else {
            return
        }
        DispatchQueue.main.async {
            workspace.sessionController.focus(focusedPaneID)
        }
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                WorkspaceSidebarView()
                    .navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 320)
            } detail: {
                if isCanvasPresented {
                    Color.clear
                } else {
                    WorkspaceDetailView()
                }
            }
            .navigationSplitViewStyle(.balanced)

            if store.isOverviewPresented {
                OverviewView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.isOverviewPresented = false
                    }
                }
                .environmentObject(store)
                .transition(.opacity)
                .zIndex(1)
            }

            if isCanvasPresented {
                GlobalCanvasView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismissCanvas()
                    }
                }
                .environmentObject(store)
                .transition(.opacity)
                .zIndex(1)
            }

            if store.isCommandPalettePresented {
                CommandPaletteView()
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(3)
            }

            VStack {
                if let statusMessage = store.statusMessage {
                    StatusBanner(message: statusMessage)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .zIndex(2)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
                    )
                } label: {
                    Image(systemName: "sidebar.leading")
                        .padding(4)
                }
                .accessibilityLabel("Toggle Sidebar")
                .help("Toggle Sidebar")
            }

            ToolbarItemGroup(placement: .confirmationAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        dismissCanvas(restoreFocus: false)
                        store.isOverviewPresented.toggle()
                    }
                } label: {
                    Image(systemName: store.isOverviewPresented ? "building.2.fill" : "building.2")
                        .padding(4)
                }
                .accessibilityLabel("Overview")
                .help("Overview")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isOverviewPresented = false
                        if isCanvasPresented {
                            dismissCanvas()
                        } else {
                            isCanvasPresented = true
                        }
                    }
                } label: {
                    Image(systemName: isCanvasPresented ? "square.grid.3x2.fill" : "square.grid.3x2")
                        .padding(4)
                }
                .accessibilityLabel("Canvas")
                .help(isCanvasPresented ? "Hide Canvas" : "Show Canvas")

                Button {
                    openDiffWindow()
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .padding(4)
                }
                .accessibilityLabel("Diff")
                .help("Open Diff")

                Button {
                    store.dispatch(.toggleCommandPalette)
                } label: {
                    Image(systemName: "command")
                        .padding(4)
                }
                .accessibilityLabel("Command Palette")
                .help("Command Palette")

                Button {
                    guard let workspace = store.selectedWorkspace else { return }
                    store.createSession(in: workspace)
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .padding(4)
                }
                .disabled(!hasSelectedWorkspace)
                .accessibilityLabel("New Session")
                .help("New Session")

                Button {
                    guard let workspace = store.selectedWorkspace else { return }
                    store.splitFocusedPane(in: workspace, axis: .vertical)
                } label: {
                    Image(systemName: "rectangle.split.2x1.fill")
                        .padding(4)
                }
                .disabled(!hasFocusedPane)
                .accessibilityLabel("Split Right")
                .help("Split Right")

                Button {
                    guard let workspace = store.selectedWorkspace else { return }
                    store.splitFocusedPane(in: workspace, axis: .horizontal)
                } label: {
                    Image(systemName: "rectangle.split.1x2.fill")
                        .padding(4)
                }
                .disabled(!hasFocusedPane)
                .accessibilityLabel("Split Down")
                .help("Split Down")

                Button {
                    guard let workspace = store.selectedWorkspace else { return }
                    store.createTab(in: workspace)
                } label: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .padding(4)
                }
                .disabled(!hasSelectedWorkspace)
                .accessibilityLabel("New Tab")
                .help("New Tab")

                Menu {
                    Button("Restart Focused Session") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.restartFocusedSession(in: workspace)
                    }
                    .disabled(!hasFocusedPane)

                    Button("Restart All Sessions") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.restartAllSessions(in: workspace)
                    }
                    .disabled(!hasSelectedWorkspace)

                    Button("Run Workspace Script") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.dispatch(.runWorkspaceScript(workspace.id))
                    }
                    .disabled(!(store.selectedWorkspace?.runScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false))

                    Button("Run Setup Script") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.dispatch(.runSetupScript(workspace.id))
                    }
                    .disabled(!(store.selectedWorkspace?.setupScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false))

                    Button("Run Preferred Workflow") {
                        guard let workspace = store.selectedWorkspace,
                              let workflow = workspace.preferredWorkflow else { return }
                        store.dispatch(.runWorkflow(workspace.id, workflow.id))
                    }
                    .disabled(store.selectedWorkspace?.preferredWorkflow == nil)

                    Divider()

                    Button("Equalize Splits") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.equalizeSplits(in: workspace)
                    }
                    .disabled(!hasSelectedWorkspace)

                    Button("Toggle Zoom") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.toggleZoom(in: workspace)
                    }
                    .disabled(!hasFocusedPane)

                    Button("Reset Layout") {
                        guard let workspace = store.selectedWorkspace else { return }
                        store.resetLayout(in: workspace)
                    }
                    .disabled(!hasSelectedWorkspace)

                    if selectedWorkspaceSupportsGit {
                        Divider()

                        Button("Create Worktree") {
                            guard let workspace = store.selectedWorkspace else { return }
                            store.presentCreateWorktree(for: workspace)
                        }
                        .disabled(!selectedWorkspaceSupportsGit)

                        Button("Refresh Repo") {
                            store.refreshSelectedWorkspace()
                        }
                        .disabled(!selectedWorkspaceSupportsGit)
                    }

                    Divider()

                    Button(store.isOverviewPresented ? "Close Workspace Overview" : "Open Workspace Overview") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            dismissCanvas(restoreFocus: false)
                            store.dispatch(.toggleOverview)
                        }
                    }

                    Button(isCanvasPresented ? "Hide Canvas" : "Show Canvas") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.isOverviewPresented = false
                            if isCanvasPresented {
                                dismissCanvas()
                            } else {
                                isCanvasPresented = true
                            }
                        }
                    }

                    Button("Open Diff") {
                        openDiffWindow()
                    }
                    Divider()

                    Button("Settings") {
                        store.presentSettings(for: store.selectedWorkspace)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More Actions")
            }
        }
        .onChange(of: store.selectedWorkspaceID) { _, newValue in
            if newValue == nil {
                isCanvasPresented = false
            }
        }
        .sheet(item: $store.renameWorkspaceRequest) { request in
            RenameWorkspaceSheet(request: request) { name in
                store.renameWorkspace(id: request.workspaceID, to: name)
            }
        }
        .sheet(item: $store.createWorktreeRequest) { request in
            CreateWorktreeSheet(request: request) { draft in
                store.createWorktree(workspaceID: request.workspaceID, draft: draft)
            }
        }
        .sheet(item: $store.createSSHSessionRequest) { request in
            CreateSSHSessionSheet(request: request) { draft in
                store.createSSHSession(workspaceID: request.workspaceID, draft: draft)
            }
        }
        .sheet(item: $store.createAgentSessionRequest) { request in
            CreateAgentSessionSheet(request: request) { draft in
                store.createAgentSession(workspaceID: request.workspaceID, draft: draft)
            }
        }
        .sheet(item: $store.settingsRequest) { request in
            SettingsSheet(request: request)
                .environmentObject(store)
        }
        .sheet(item: $store.sidebarIconCustomizationRequest) { request in
            SidebarIconCustomizationSheet(request: request)
                .environmentObject(store)
        }
        .alert(item: $store.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $store.pendingWorktreeSwitch) { request in
            Alert(
                title: Text("Switch worktree and restart panes?"),
                message: Text("Switching to \(request.targetName) restarts \(request.runningPaneCount) running pane(s) so their cwd matches the selected worktree and then \(request.requestedAction.displayLabel)."),
                primaryButton: .destructive(Text("Switch")) {
                    store.confirmPendingWorktreeSwitch()
                },
                secondaryButton: .cancel {
                    store.pendingWorktreeSwitch = nil
                }
            )
        }
        .confirmationDialog(
            store.pendingWorktreeRemoval?.itemCount == 1 ? "Remove worktree?" : "Remove selected worktrees?",
            isPresented: Binding(
                get: { store.pendingWorktreeRemoval != nil },
                set: { isPresented in
                    if !isPresented {
                        store.pendingWorktreeRemoval = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: store.pendingWorktreeRemoval
        ) { request in
            Button("Remove", role: .destructive) {
                store.confirmPendingWorktreeRemoval()
            }
            if request.allowsForceRemove {
                Button("Force Remove", role: .destructive) {
                    store.confirmPendingWorktreeRemoval(force: true)
                }
            }
            Button("Cancel", role: .cancel) {
                store.pendingWorktreeRemoval = nil
            }
        } message: { request in
            Text(request.detailMessage)
        }
        .animation(.easeInOut(duration: 0.18), value: store.statusMessage?.id)
        .animation(.easeInOut(duration: 0.18), value: store.isCommandPalettePresented)
    }

    private func openDiffWindow() {
        let workspace = store.selectedWorkspace
        let supportsDiff = workspace?.supportsRepositoryFeatures == true
        DiffWindowManager.shared.show(
            worktreePath: supportsDiff ? workspace?.activeWorktreePath : nil,
            branchName: workspace?.activeWorktree?.branchLabel ?? workspace?.currentBranch ?? "",
            emptyStateMessage: diffEmptyStateMessage(for: workspace, supportsDiff: supportsDiff)
        )
    }

    private func diffEmptyStateMessage(for workspace: WorkspaceModel?, supportsDiff: Bool) -> String {
        guard let workspace else {
            return "Select a workspace to inspect changes."
        }
        if supportsDiff {
            return "Working directory is clean."
        }
        return "\(workspace.name) does not have a git diff context."
    }
}

private struct StatusBanner: View {
    let message: WorkspaceStatusMessage

    private var tint: Color {
        switch message.tone {
        case .neutral:
            return LineyTheme.secondaryText
        case .success:
            return LineyTheme.success
        case .warning:
            return LineyTheme.warning
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(message.text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LineyTheme.canvasBackground.opacity(0.96), in: Capsule())
        .overlay(Capsule().stroke(LineyTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}
