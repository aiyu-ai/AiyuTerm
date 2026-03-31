//
//  TmuxPanelView.swift
//  Liney
//
//  Author: everettjf
//
//  NOTE: This file is a temporary stub during Task 2 migration.
//  It will be fully rewritten in Task 6.
//

import SwiftUI

struct TmuxPanelView: View {
    @ObservedObject var store: TmuxPanelStore
    @Binding var isCollapsed: Bool
    let onAttachWindow: (SessionBackendConfiguration) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LineyTheme.border)
                .frame(height: 1)

            TmuxPanelHeaderView(
                store: store,
                isCollapsed: $isCollapsed
            )

            if !isCollapsed {
                TmuxPanelContentView(
                    store: store,
                    onAttachWindow: onAttachWindow
                )
            }
        }
        .background(LineyTheme.sidebarBackground)
        .onAppear {
            store.checkAvailability()
        }
    }
}

// MARK: - Header

private struct TmuxPanelHeaderView: View {
    @ObservedObject var store: TmuxPanelStore
    @Binding var isCollapsed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() } }) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    .frame(width: 12)
            }
            .buttonStyle(.plain)

            Text("TMUX")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LineyTheme.mutedText)

            if !store.sessions.isEmpty {
                Text("\(store.sessions.count)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.15), in: Capsule())
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
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { store.createSession(name: "new-\(Int.random(in: 100...999))") }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Content

private struct TmuxPanelContentView: View {
    @ObservedObject var store: TmuxPanelStore

    let onAttachWindow: (SessionBackendConfiguration) -> Void

    var body: some View {
        if !store.isAvailable {
            TmuxNotInstalledView()
        } else if let error = store.errorMessage {
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(LineyTheme.danger)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        } else if store.sessions.isEmpty {
            Text("No sessions")
                .font(.system(size: 10))
                .foregroundStyle(LineyTheme.mutedText)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(store.sessions) { session in
                        TmuxSessionRowView(
                            session: session,
                            store: store,
                            onAttachWindow: onAttachWindow
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 200)
        }
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
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row

private struct TmuxSessionRowView: View {
    let session: TmuxSession
    let store: TmuxPanelStore
    let onAttachWindow: (SessionBackendConfiguration) -> Void
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showKillConfirm = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(session.isAttached ? LineyTheme.success : LineyTheme.mutedText.opacity(0.4))
                .frame(width: 6, height: 6)

            if isRenaming {
                TextField("name", text: $renameText, onCommit: {
                    if !renameText.isEmpty && renameText != session.name {
                        store.renameSession(sessionID: session.sessionID, newName: renameText)
                    }
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .onExitCommand { isRenaming = false }
            } else {
                Text(session.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(session.isAttached ? Color.white.opacity(0.9) : LineyTheme.mutedText)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        renameText = session.name
                        isRenaming = true
                    }
                    .onTapGesture(count: 1) {
                        if let config = store.attachConfiguration(sessionID: session.sessionID) {
                            onAttachWindow(config)
                        }
                    }
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
            } else if !isHovering {
                Text("\(session.windowCount)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText.opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovering ? Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
        .alert("Kill session '\(session.name)'?", isPresented: $showKillConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Kill", role: .destructive) {
                store.killSession(sessionID: session.sessionID)
            }
        } message: {
            Text("This will terminate all windows and processes in this session.")
        }
    }
}

// MARK: - Inline Button

private struct TmuxInlineButton: View {
    let systemName: String
    var size: CGFloat = 8
    var isDanger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 15, height: 15)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDanger ? LineyTheme.danger : LineyTheme.secondaryText)
        .background(
            (isDanger ? LineyTheme.danger.opacity(0.1) : Color.white.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 3, style: .continuous)
        )
    }
}
