//
//  TerminalPaneView.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct TerminalPaneView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var sessionController: WorkspaceSessionController
    @ObservedObject var session: ShellSession
    let paneID: UUID

    @FocusState private var searchFieldFocused: Bool
    @State private var isSearchPresented = false
    @State private var searchDraft = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var autoCloseTask: Task<Void, Never>?

    private var isFocused: Bool {
        sessionController.focusedPaneID == paneID
    }

    private var directoryLabel: String {
        session.effectiveWorkingDirectory.lastPathComponentValue
    }

    private var searchStatusLabel: String? {
        guard let total = session.surfaceStatus.searchTotal else { return nil }
        let selected = max(session.surfaceStatus.searchSelected ?? 0, 0)
        if total <= 0 {
            return "0 matches"
        }
        return "\(selected + 1)/\(total)"
    }

    private var viewportLabel: String? {
        guard let progress = session.surfaceStatus.viewport?.progress else { return nil }
        if progress <= 0.02 {
            return "top"
        }
        if progress >= 0.98 {
            return "bottom"
        }
        return "\(Int(progress * 100))%"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.hasActiveProcess ? LineyTheme.success : LineyTheme.warning)
                    .frame(width: 7, height: 7)

                Text(session.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LineyTheme.tertiaryText)
                    .lineLimit(1)

                PaneTag(text: directoryLabel, tone: .neutral)

                if let exitCode = session.exitCode, session.lifecycle == .exited {
                    PaneTag(text: "exit \(exitCode)", tone: .warning)
                } else if isFocused {
                    PaneTag(text: "active", tone: .accent)
                }

                if session.surfaceStatus.isReadOnly {
                    PaneTag(text: "read only", tone: .warning)
                }

                Spacer()

                PaneHeaderButton(systemName: "magnifyingglass") {
                    workspace.focusPane(paneID)
                    presentSearch()
                }

                PaneHeaderButton(systemName: session.surfaceStatus.isReadOnly ? "lock.fill" : "lock.open") {
                    workspace.focusPane(paneID)
                    session.toggleReadOnly()
                }

                PaneHeaderButton(systemName: workspace.zoomedPaneID == paneID ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    workspace.focusPane(paneID)
                    store.toggleZoom(in: workspace, paneID: paneID)
                }

                PaneHeaderButton(systemName: "xmark") {
                    store.closePane(in: workspace, paneID: paneID)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isFocused ? LineyTheme.panelRaised : LineyTheme.paneHeaderBackground)

            if isSearchPresented {
                PaneSearchBar(
                    text: $searchDraft,
                    isFocused: $searchFieldFocused,
                    resultLabel: searchStatusLabel,
                    onNext: {
                        workspace.focusPane(paneID)
                        session.searchNext()
                    },
                    onPrevious: {
                        workspace.focusPane(paneID)
                        session.searchPrevious()
                    },
                    onClose: closeSearch
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .background(isFocused ? LineyTheme.panelRaised : LineyTheme.paneHeaderBackground)
            }

            TerminalHostView(session: session, shouldRestoreFocus: isFocused)
                .background(LineyTheme.paneBackground)
                .onTapGesture {
                    workspace.focusPane(paneID)
                }

            PaneStatusStrip(
                backendLabel: session.backendLabel,
                sizeLabel: "\(session.cols)x\(session.rows)",
                viewportLabel: viewportLabel,
                rendererHealthy: session.surfaceStatus.rendererHealthy,
                searchLabel: searchStatusLabel
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? LineyTheme.accent.opacity(0.46) : LineyTheme.border, lineWidth: isFocused ? 1.2 : 1)
        )
        .background(LineyTheme.paneBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(isFocused ? 0.12 : 0.05), radius: isFocused ? 5 : 2, y: 2)
        .contextMenu {
            Button("Split Right") {
                workspace.focusPane(paneID)
                store.splitFocusedPane(in: workspace, axis: .vertical)
            }
            Button("Split Down") {
                workspace.focusPane(paneID)
                store.splitFocusedPane(in: workspace, axis: .horizontal)
            }
            Divider()
            Button("Duplicate Pane") {
                workspace.focusPane(paneID)
                store.duplicateFocusedPane(in: workspace)
            }
            Button(workspace.zoomedPaneID == paneID ? "Unzoom Pane" : "Zoom Pane") {
                workspace.focusPane(paneID)
                store.toggleZoom(in: workspace, paneID: paneID)
            }
            Button("Restart Session") {
                workspace.focusPane(paneID)
                session.restart()
            }
            Button("Find") {
                workspace.focusPane(paneID)
                presentSearch()
            }
            Button(session.surfaceStatus.isReadOnly ? "Disable Read Only" : "Enable Read Only") {
                workspace.focusPane(paneID)
                session.toggleReadOnly()
            }
            Button("Clear") {
                workspace.focusPane(paneID)
                session.clear()
            }
            Divider()
            Button("Close Pane") {
                store.closePane(in: workspace, paneID: paneID)
            }
        }
        .onAppear {
            syncSearchState(with: session.surfaceStatus.searchQuery)
            scheduleAutoCloseIfNeeded()
        }
        .onChange(of: session.surfaceStatus.searchQuery) { _, newValue in
            syncSearchState(with: newValue)
        }
        .onChange(of: session.lifecycle) { _, _ in
            scheduleAutoCloseIfNeeded()
        }
        .onChange(of: store.appSettings.autoClosePaneOnProcessExit) { _, _ in
            scheduleAutoCloseIfNeeded()
        }
        .onChange(of: searchDraft) { _, newValue in
            guard isSearchPresented else { return }
            scheduleSearchUpdate(newValue)
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            autoCloseTask?.cancel()
            autoCloseTask = nil
        }
    }

    private func presentSearch() {
        isSearchPresented = true
        if searchDraft.isEmpty {
            searchDraft = session.surfaceStatus.searchQuery ?? ""
        }
        session.beginSearch()
        searchFieldFocused = true
    }

    private func closeSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearchPresented = false
        session.endSearch()
        searchFieldFocused = false
    }

    private func syncSearchState(with query: String?) {
        if let query {
            isSearchPresented = true
            if query != searchDraft {
                searchDraft = query
            }
        } else {
            searchTask?.cancel()
            searchTask = nil
            isSearchPresented = false
            searchFieldFocused = false
        }
    }

    private func scheduleSearchUpdate(_ query: String) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            session.updateSearch(query)
        }
    }

    private func scheduleAutoCloseIfNeeded() {
        autoCloseTask?.cancel()
        autoCloseTask = nil

        guard store.appSettings.autoClosePaneOnProcessExit,
              session.lifecycle == .exited else { return }

        autoCloseTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled,
                  store.appSettings.autoClosePaneOnProcessExit,
                  session.lifecycle == .exited else { return }
            store.closePane(in: workspace, paneID: paneID)
        }
    }
}

private struct PaneTag: View {
    enum Tone {
        case neutral
        case accent
        case warning
    }

    let text: String
    let tone: Tone

    private var foreground: Color {
        switch tone {
        case .neutral:
            return LineyTheme.mutedText
        case .accent:
            return LineyTheme.accent
        case .warning:
            return LineyTheme.warning
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(LineyTheme.subtleFill, in: Capsule())
    }
}

private struct PaneHeaderButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(LineyTheme.secondaryText)
        .background(LineyTheme.subtleFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct PaneSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let resultLabel: String?
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Search terminal", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .focused(isFocused)
                .onExitCommand(perform: onClose)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(LineyTheme.subtleFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            if let resultLabel {
                PaneTag(text: resultLabel, tone: .neutral)
            }

            PaneHeaderButton(systemName: "chevron.up") {
                onPrevious()
            }

            PaneHeaderButton(systemName: "chevron.down") {
                onNext()
            }

            PaneHeaderButton(systemName: "xmark") {
                onClose()
            }
        }
    }
}

private struct PaneStatusStrip: View {
    let backendLabel: String
    let sizeLabel: String
    let viewportLabel: String?
    let rendererHealthy: Bool
    let searchLabel: String?

    var body: some View {
        HStack(spacing: 8) {
            PaneTag(text: backendLabel, tone: .neutral)
            PaneTag(text: sizeLabel, tone: .neutral)

            if let viewportLabel {
                PaneTag(text: viewportLabel, tone: .neutral)
            }

            if let searchLabel {
                PaneTag(text: searchLabel, tone: .accent)
            }

            if !rendererHealthy {
                PaneTag(text: "renderer", tone: .warning)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(LineyTheme.panelRaised.opacity(0.72))
    }
}
