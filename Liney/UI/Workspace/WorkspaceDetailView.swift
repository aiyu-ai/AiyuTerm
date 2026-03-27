//
//  WorkspaceDetailView.swift
//  Liney
//
//  Author: wuwenrui
//

import AppKit
import SwiftUI

struct WorkspaceDetailView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject private var localization = LocalizationManager.shared

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        ZStack {
            WorkspaceBackdrop()

            Group {
                if let workspace = store.selectedWorkspace {
                    WorkspaceSessionDetailView(workspace: workspace)
                } else {
                    ContentUnavailableView(
                        localized("main.workspace.openWorkspace"),
                        systemImage: "folder.badge.plus",
                        description: Text(localized("main.workspace.openWorkspaceDescription"))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(6)
        }
        .background(LineyTheme.appBackground)
    }
}

private struct WorkspaceSessionDetailView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject var workspace: WorkspaceModel

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        VStack(spacing: 8) {
            if workspace.tabs.count > 1 {
                WorkspaceTabBarView(workspace: workspace)
            }

            Group {
                if let layout = workspace.layout {
                    SplitNodeView(workspace: workspace, sessionController: workspace.sessionController, node: layout)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "terminal")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(LineyTheme.mutedText)
                        Text(localized("main.workspace.noTerminalOpen"))
                            .font(.system(size: 14, weight: .semibold))
                        Button(localized("main.workspace.newSession")) {
                            store.createSession(in: workspace)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

private struct WorkspaceTabBarView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject var workspace: WorkspaceModel
    @FocusState private var isRenameFieldFocused: Bool
    @State private var editingTabID: UUID?
    @State private var dropInsertionIndex: Int?
    @State private var titleDraft = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tabInsertionMarker(for: 0)

                ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                    if editingTabID == tab.id {
                        WorkspaceTabRenameField(
                            title: $titleDraft,
                            isFocused: $isRenameFieldFocused,
                            onCommit: { commitRename(for: tab.id) },
                            onCancel: cancelRename
                        )
                    } else {
                        WorkspaceTabButton(
                            title: tab.title,
                            paneCount: workspace.paneCount(for: tab.id),
                            isSelected: workspace.activeTabID == tab.id,
                            canClose: workspace.tabs.count > 1,
                            canMoveLeft: canMoveTabLeft(tab.id),
                            canMoveRight: canMoveTabRight(tab.id),
                            onSelect: {
                                store.selectTab(in: workspace, tabID: tab.id)
                            },
                            onRename: {
                                beginRename(for: tab)
                            },
                            onMoveLeft: {
                                store.moveTabLeft(in: workspace, tabID: tab.id)
                            },
                            onMoveRight: {
                                store.moveTabRight(in: workspace, tabID: tab.id)
                            },
                            onClose: {
                                store.closeTab(in: workspace, tabID: tab.id)
                            }
                        )
                        .draggable(tab.id.uuidString)
                    }

                    tabInsertionMarker(for: index + 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .onChange(of: workspace.activeTabID) { _, _ in
            cancelRename()
        }
    }

    private func beginRename(for tab: WorkspaceTabStateRecord) {
        titleDraft = tab.title
        editingTabID = tab.id
        isRenameFieldFocused = true
    }

    private func commitRename(for tabID: UUID) {
        let normalized = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            store.renameTab(in: workspace, tabID: tabID, title: normalized)
        }
        cancelRename()
    }

    private func cancelRename() {
        editingTabID = nil
        titleDraft = ""
        isRenameFieldFocused = false
    }

    private func canMoveTabLeft(_ tabID: UUID) -> Bool {
        workspace.tabs.firstIndex(where: { $0.id == tabID }).map { $0 > 0 } ?? false
    }

    private func canMoveTabRight(_ tabID: UUID) -> Bool {
        workspace.tabs.firstIndex(where: { $0.id == tabID }).map { $0 < workspace.tabs.count - 1 } ?? false
    }

    @ViewBuilder
    private func tabInsertionMarker(for insertionSlot: Int) -> some View {
        WorkspaceTabInsertionMarker(isActive: dropInsertionIndex == insertionSlot)
            .dropDestination(for: String.self) { items, _ in
                handleDrop(items, insertionSlot: insertionSlot)
            } isTargeted: { isTargeted in
                withAnimation(.easeInOut(duration: 0.12)) {
                    dropInsertionIndex = isTargeted ? insertionSlot : (dropInsertionIndex == insertionSlot ? nil : dropInsertionIndex)
                }
            }
    }

    private func handleDrop(_ items: [String], insertionSlot: Int) -> Bool {
        defer { dropInsertionIndex = nil }

        guard let draggedValue = items.first,
              let draggedTabID = UUID(uuidString: draggedValue),
              let sourceIndex = workspace.tabs.firstIndex(where: { $0.id == draggedTabID }) else {
            return false
        }

        let finalIndex = sourceIndex < insertionSlot ? insertionSlot - 1 : insertionSlot
        guard finalIndex != sourceIndex else { return false }

        store.moveTab(in: workspace, tabID: draggedTabID, to: finalIndex)
        return true
    }
}

private struct WorkspaceTabButton: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let title: String
    let paneCount: Int
    let isSelected: Bool
    let canClose: Bool
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(paneCount)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? LineyTheme.accent : LineyTheme.mutedText)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(LineyTheme.subtleFill, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .padding(.trailing, canClose ? 34 : 12)
        .padding(.vertical, 8)
        .frame(width: WorkspaceTabSizing.width(for: title, paneCount: paneCount, canClose: canClose))
        .foregroundStyle(labelColor)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 1.15 : 1)
        )
        .overlay(alignment: .trailing) {
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(WorkspaceTabCloseButtonStyle(isSelected: isSelected, isTabHovered: isHovered, isCloseHovered: isCloseHovered))
                .onHover { hovering in
                    isCloseHovered = hovering
                }
                .padding(.trailing, 8)
            }
        }
        .overlay(alignment: .topLeading) {
            if isSelected {
                Capsule()
                    .fill(LineyTheme.accent)
                    .frame(width: 26, height: 2.5)
                    .padding(.top, 1)
                    .padding(.leading, 12)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: shadowColor, radius: isSelected ? 14 : (isHovered ? 8 : 0), y: isSelected || isHovered ? 4 : 0)
        .offset(y: isHovered ? -1 : 0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(paneCount) panes"))
        .accessibilityAddTraits(.isButton)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                isCloseHovered = false
            }
        }
        .contextMenu {
            Button(localized("main.tab.rename")) {
                onRename()
            }
            Button(localized("main.tab.moveLeft")) {
                onMoveLeft()
            }
            .disabled(!canMoveLeft)
            Button(localized("main.tab.moveRight")) {
                onMoveRight()
            }
            .disabled(!canMoveRight)
            Divider()
            Button(localized("main.tab.close")) {
                onClose()
            }
            .disabled(!canClose)
        }
    }
}

private struct WorkspaceTabRenameField: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @Binding var title: String
    var isFocused: FocusState<Bool>.Binding
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        TextField(localization.string("main.tab.namePlaceholder"), text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .onExitCommand(perform: onCancel)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: WorkspaceTabSizing.width(for: title.isEmpty ? localization.string("main.tab.namePlaceholder") : title, paneCount: 1, canClose: false))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LineyTheme.panelRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LineyTheme.accent.opacity(0.45), lineWidth: 1)
            )
            .focused(isFocused)
            .onSubmit(onCommit)
            .background(
                RenameCancelMonitor(onCancel: onCancel)
            )
    }
}

private extension WorkspaceTabButton {
    var backgroundFill: Color {
        if isSelected {
            return LineyTheme.panelRaised
        }
        if isHovered {
            return LineyTheme.paneHeaderBackground.opacity(0.98)
        }
        return LineyTheme.paneHeaderBackground.opacity(0.78)
    }

    var borderColor: Color {
        if isSelected {
            return LineyTheme.accent.opacity(0.42)
        }
        if isHovered {
            return LineyTheme.strongBorder
        }
        return LineyTheme.border
    }

    var labelColor: Color {
        if isSelected {
            return .white
        }
        if isHovered {
            return LineyTheme.tertiaryText
        }
        return LineyTheme.secondaryText
    }

    var shadowColor: Color {
        if isSelected {
            return LineyTheme.accent.opacity(0.16)
        }
        if isHovered {
            return Color.black.opacity(0.18)
        }
        return .clear
    }
}

private struct WorkspaceTabInsertionMarker: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Color.clear

            Capsule()
                .fill(LineyTheme.accent)
                .frame(width: isActive ? 3 : 1.5, height: isActive ? 20 : 12)
                .opacity(isActive ? 1 : 0)
                .shadow(color: LineyTheme.accent.opacity(0.28), radius: 8, y: 1)
        }
        .frame(width: 10, height: 34)
        .animation(.easeInOut(duration: 0.12), value: isActive)
    }
}

private struct WorkspaceTabCloseButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isTabHovered: Bool
    let isCloseHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(4)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        if configurationStateIsHot {
            return .white
        }
        return isSelected ? LineyTheme.secondaryText : LineyTheme.mutedText
    }

    private var backgroundColor: Color {
        if configurationStateIsHot {
            return LineyTheme.danger.opacity(0.78)
        }
        if isSelected || isTabHovered {
            return Color.white.opacity(0.06)
        }
        return .clear
    }

    private var configurationStateIsHot: Bool {
        isCloseHovered
    }
}

private enum WorkspaceTabSizing {
    private static let titleFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    private static let countFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)

    static func width(for title: String, paneCount: Int, canClose: Bool) -> CGFloat {
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: titleFont]).width)
        let countWidth = ceil(("\(paneCount)" as NSString).size(withAttributes: [.font: countFont]).width)
        let horizontalChrome = canClose ? 84.0 : 58.0
        let badgeWidth = countWidth + 20
        return min(max(titleWidth + badgeWidth + horizontalChrome, 112), 280)
    }
}

private struct RenameCancelMonitor: NSViewRepresentable {
    let onCancel: () -> Void

    func makeNSView(context: Context) -> RenameCancelView {
        let view = RenameCancelView()
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: RenameCancelView, context: Context) {
        nsView.onCancel = onCancel
    }
}

final class RenameCancelView: NSView {
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

private struct WorkspaceBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [LineyTheme.appBackground, LineyTheme.canvasBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(LineyTheme.backdropBlue)
                    .frame(width: proxy.size.width * 0.34)
                    .blur(radius: 76)
                    .offset(x: proxy.size.width * 0.24, y: -proxy.size.height * 0.18)

                Circle()
                    .fill(LineyTheme.backdropTeal)
                    .frame(width: proxy.size.width * 0.24)
                    .blur(radius: 64)
                    .offset(x: -proxy.size.width * 0.2, y: proxy.size.height * 0.25)
            }
            .ignoresSafeArea()
        }
    }
}
