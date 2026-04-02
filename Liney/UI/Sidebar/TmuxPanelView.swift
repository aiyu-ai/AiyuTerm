//
//  TmuxPanelView.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct TmuxPanelView: View {
    @ObservedObject var store: TmuxPanelStore
    let coordinator: TmuxAttachCoordinator
    let onAttachSession: (String) -> Void
    let agentStatusForSession: (String) -> AgentSessionStatus
    @Binding var isCollapsed: Bool
    let onCollapseChange: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TmuxHeaderView(store: store, isCollapsed: $isCollapsed, onCollapseChange: onCollapseChange)

            if !isCollapsed {
                if !store.isAvailable {
                    TmuxNotInstalledView()
                } else if let error = store.errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(LineyTheme.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else if store.sessions.isEmpty && !store.isLoading {
                    Text("No sessions")
                        .font(.system(size: 10))
                        .foregroundStyle(LineyTheme.mutedText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(store.sessions) { session in
                                TmuxSessionRow(
                                    session: session,
                                    store: store,
                                    coordinator: coordinator,
                                    onAttach: { onAttachSession(session.sessionID) },
                                    agentStatus: agentStatusForSession(session.sessionID)
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .background(LineyTheme.sidebarBackground)
        .onAppear {
            store.checkAvailabilityAndRefresh()
        }
    }
}

// MARK: - Header

private struct TmuxHeaderView: View {
    @ObservedObject var store: TmuxPanelStore
    @ObservedObject private var localization = LocalizationManager.shared
    @Binding var isCollapsed: Bool
    let onCollapseChange: () -> Void
    @State private var showNewSessionPrompt = false
    @State private var newSessionName = ""

    @State private var refreshHover = false
    @State private var plusHover = false

    var body: some View {
        HStack(spacing: 6) {
            // Left side: tappable to toggle collapse
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    .frame(width: 12)

                Text("TMUX")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))

                if !store.sessions.isEmpty {
                    Text("\(store.sessions.count)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.15), in: Capsule())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
                onCollapseChange()
            }

            Spacer()

            if !isCollapsed {
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Button(action: { store.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(refreshHover ? 1 : 0.6))
                    }
                    .buttonStyle(.plain)
                    .onHover { refreshHover = $0 }
                }

                Button(action: { showNewSessionPrompt = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(plusHover ? 1 : 0.6))
                }
                .buttonStyle(.plain)
                .onHover { plusHover = $0 }
                .popover(isPresented: $showNewSessionPrompt) {
                    VStack(spacing: 8) {
                        Text(localized("tmux.newSession.title"))
                            .font(.system(size: 11, weight: .semibold))
                        TextField(localized("tmux.newSession.placeholder"), text: $newSessionName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .frame(width: 160)
                            .onSubmit { submitNewSession() }
                        HStack {
                            Button(localized("common.cancel")) { showNewSessionPrompt = false }
                                .buttonStyle(.plain)
                                .font(.system(size: 10))
                            Spacer()
                            Button(localized("common.create")) { submitNewSession() }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                        }
                    }
                    .padding(12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    private func submitNewSession() {
        let name = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.createSession(name: name)
        newSessionName = ""
        showNewSessionPrompt = false
    }
}

// MARK: - Not Installed

private struct TmuxNotInstalledView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("tmux not installed")
                .font(.system(size: 10))
                .foregroundStyle(LineyTheme.mutedText)
            Text("brew install tmux")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LineyTheme.mutedText.opacity(0.6))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row

private struct TmuxSessionRow: View {
    let session: TmuxSession
    let store: TmuxPanelStore
    let coordinator: TmuxAttachCoordinator
    let onAttach: () -> Void
    let agentStatus: AgentSessionStatus
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showKillConfirm = false

    var body: some View {
        HStack(spacing: 8) {
            if agentStatus.isActionable {
                AgentStatusOverlayBadge(status: agentStatus, size: 16)
            }

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("name", text: $renameText, onCommit: {
                        if !renameText.isEmpty && renameText != session.name {
                            store.renameSession(sessionID: session.sessionID, newName: renameText)
                        }
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(session.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }

                Text("\(session.isAttached ? "attached" : "detached") \u{00B7} \(session.windowCount) win")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering && !isRenaming {
                HStack(spacing: 3) {
                    TmuxInlineButton(systemName: "pencil") {
                        renameText = session.name
                        isRenaming = true
                    }
                    if session.isAttached {
                        TmuxInlineButton(systemName: "eject") {
                            store.detachSession(sessionID: session.sessionID)
                        }
                    }
                    TmuxInlineButton(systemName: "xmark", isDanger: true) {
                        showKillConfirm = true
                    }
                }
            } else {
                Circle()
                    .fill(session.isAttached ? LineyTheme.success : LineyTheme.mutedText.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRenaming { onAttach() }
        }
        .onHover { isHovering = $0 }
        .alert("Kill session '\(session.name)'?", isPresented: $showKillConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Kill", role: .destructive) {
                store.killSession(sessionID: session.sessionID)
            }
        } message: {
            Text("This will terminate all windows and processes.")
        }
    }
}

// MARK: - Inline Button

private struct TmuxInlineButton: View {
    let systemName: String
    var isDanger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDanger ? LineyTheme.danger : LineyTheme.secondaryText)
        .background(
            (isDanger ? LineyTheme.danger.opacity(0.1) : Color.white.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
    }
}
