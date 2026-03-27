//
//  QuickCommandEditorSheet.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct QuickCommandEditorSheet: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @State private var draftCommands: [QuickCommandPreset] = []
    @State private var selectedCommandID: String?

    private func localized(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        l10nFormat(localized(key), locale: Locale.current, arguments: arguments)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                sidebar

                Divider()

                detailPane
            }

            Divider()

            footer
        }
        .frame(width: 980, height: 680)
        .task {
            draftCommands = store.quickCommandPresets
            syncSelection()
        }
        .onChange(of: draftCommands.map(\.id)) { _, _ in
            syncSelection()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(localized("sheet.quickCommands.title"))
                    .font(.system(size: 24, weight: .semibold))

                Spacer()

                Text(localizedFormat("sheet.quickCommands.countFormat", draftCommands.count))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LineyTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LineyTheme.subtleFill, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(LineyTheme.border, lineWidth: 1)
                    )
            }

            Text(localized("sheet.quickCommands.subtitle"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [
                    LineyTheme.backdropBlue.opacity(0.32),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Button(localized("sheet.quickCommands.add")) {
                    addCommand()
                }
                .buttonStyle(.borderedProminent)

                Button(localized("sheet.quickCommands.resetDefaults")) {
                    resetCommands()
                }
                .buttonStyle(.bordered)
            }

            Text(localized("sheet.quickCommands.shortcutHint"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LineyTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            if draftCommands.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("sheet.quickCommands.empty"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LineyTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(LineyTheme.subtleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LineyTheme.border, lineWidth: 1)
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(draftCommands) { command in
                            QuickCommandListItem(
                                command: command,
                                isSelected: command.id == selectedCommandID,
                                onSelect: { selectedCommandID = command.id }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 320)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(LineyTheme.panelBackground.opacity(0.55))
    }

    private var detailPane: some View {
        Group {
            if let commandBinding = selectedCommandBinding {
                QuickCommandDetailPanel(
                    command: commandBinding,
                    canMoveUp: canMoveSelectedUp,
                    canMoveDown: canMoveSelectedDown,
                    onMoveUp: moveSelectedUp,
                    onMoveDown: moveSelectedDown,
                    onDelete: deleteSelectedCommand,
                    localized: localized
                )
                .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localized("sheet.quickCommands.empty"))
                        .font(.system(size: 18, weight: .semibold))

                    Text(localized("sheet.quickCommands.subtitle"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LineyTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LineyTheme.appBackground.opacity(0.35))
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button(localized("common.cancel")) {
                dismiss()
            }

            Button(localized("common.save")) {
                store.updateQuickCommandPresets(draftCommands)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var selectedCommandBinding: Binding<QuickCommandPreset>? {
        guard let selectedCommandID,
              draftCommands.contains(where: { $0.id == selectedCommandID }) else {
            return nil
        }

        return Binding(
            get: {
                draftCommands.first(where: { $0.id == selectedCommandID })!
            },
            set: { updated in
                guard let index = draftCommands.firstIndex(where: { $0.id == selectedCommandID }) else { return }
                draftCommands[index] = updated
            }
        )
    }

    private var selectedIndex: Int? {
        guard let selectedCommandID else { return nil }
        return draftCommands.firstIndex(where: { $0.id == selectedCommandID })
    }

    private var canMoveSelectedUp: Bool {
        guard let selectedIndex else { return false }
        return selectedIndex > 0
    }

    private var canMoveSelectedDown: Bool {
        guard let selectedIndex else { return false }
        return selectedIndex < draftCommands.count - 1
    }

    private func syncSelection() {
        if let selectedCommandID,
           draftCommands.contains(where: { $0.id == selectedCommandID }) {
            return
        }

        selectedCommandID = draftCommands.first?.id
    }

    private func addCommand() {
        let newCommand = QuickCommandPreset(
            title: localized("sheet.quickCommands.defaultName"),
            command: "",
            category: .codex
        )
        draftCommands.append(newCommand)
        selectedCommandID = newCommand.id
    }

    private func resetCommands() {
        draftCommands = QuickCommandCatalog.defaultCommands
        selectedCommandID = draftCommands.first?.id
    }

    private func moveSelectedUp() {
        guard let selectedIndex, selectedIndex > 0 else { return }
        moveCommand(from: selectedIndex, to: selectedIndex - 1)
    }

    private func moveSelectedDown() {
        guard let selectedIndex, selectedIndex < draftCommands.count - 1 else { return }
        moveCommand(from: selectedIndex, to: selectedIndex + 1)
    }

    private func deleteSelectedCommand() {
        guard let selectedIndex else { return }

        draftCommands.remove(at: selectedIndex)

        if draftCommands.indices.contains(selectedIndex) {
            selectedCommandID = draftCommands[selectedIndex].id
        } else {
            selectedCommandID = draftCommands.last?.id
        }
    }

    private func moveCommand(from source: Int, to destination: Int) {
        guard draftCommands.indices.contains(source),
              draftCommands.indices.contains(destination),
              source != destination else {
            return
        }

        let item = draftCommands.remove(at: source)
        draftCommands.insert(item, at: destination)
        selectedCommandID = item.id
    }
}

private struct QuickCommandListItem: View {
    let command: QuickCommandPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                ToolbarFeatureIcon(
                    systemName: command.category.symbolName,
                    tint: tint
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(command.normalizedTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LineyTheme.tertiaryText)
                        .lineLimit(1)

                    Text(command.normalizedCommand.nilIfEmpty ?? " ")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LineyTheme.mutedText)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        QuickCommandMetaTag(title: command.category.title, tint: tint)

                        if let shortcut = command.shortcut {
                            QuickCommandMetaTag(title: shortcut.displayString, tint: LineyTheme.secondaryText)
                        }

                        if command.submitsReturn {
                            QuickCommandMetaTag(title: "Return", tint: LineyTheme.success)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundShape.fill(backgroundColor))
            .overlay(
                backgroundShape
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    private var backgroundColor: Color {
        isSelected ? tint.opacity(0.16) : LineyTheme.subtleFill
    }

    private var borderColor: Color {
        isSelected ? tint.opacity(0.55) : LineyTheme.border
    }

    private var tint: Color {
        switch command.category {
        case .codex:
            return LineyTheme.accent
        case .claude:
            return LineyTheme.warning
        case .cloud:
            return LineyTheme.localAccent
        case .linux:
            return LineyTheme.secondaryText
        }
    }
}

private struct QuickCommandDetailPanel: View {
    @Binding var command: QuickCommandPreset
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let localized: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                ToolbarFeatureIcon(
                    systemName: command.category.symbolName,
                    tint: tint
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(command.normalizedTitle)
                        .font(.system(size: 22, weight: .semibold))

                    Text(command.category.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!canMoveUp)

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(!canMoveDown)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 18) {
                detailField(title: localized("sheet.quickCommands.commandTitle")) {
                    TextField(localized("sheet.quickCommands.commandTitle"), text: $command.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .medium))
                }

                HStack(alignment: .top, spacing: 16) {
                    detailField(title: localized("sheet.quickCommands.category")) {
                        Picker(localized("sheet.quickCommands.category"), selection: $command.category) {
                            ForEach(QuickCommandCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    detailField(title: localized("sheet.quickCommands.shortcutPlaceholder")) {
                        ShortcutRecorderField(
                            shortcut: $command.shortcut,
                            fallbackShortcut: StoredShortcut(key: "k", command: true, shift: false, option: false, control: false),
                            emptyTitle: localized("sheet.quickCommands.shortcutPlaceholder"),
                            displayString: { $0.displayString },
                            transformRecordedShortcut: { $0 }
                        )
                    }
                }

                detailField(title: localized("sheet.quickCommands.commandBody")) {
                    TextEditor(text: $command.command)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 240)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(LineyTheme.border, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(localized("sheet.quickCommands.autoReturn"), isOn: $command.submitsReturn)
                        .toggleStyle(.switch)
                        .font(.system(size: 13, weight: .semibold))

                    Text(
                        command.submitsReturn
                        ? localized("sheet.quickCommands.autoReturnEnabledDetail")
                        : localized("sheet.quickCommands.autoReturnDisabledDetail")
                    )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LineyTheme.mutedText)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LineyTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LineyTheme.border, lineWidth: 1)
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LineyTheme.panelRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LineyTheme.border, lineWidth: 1)
        )
    }

    private func detailField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LineyTheme.secondaryText)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tint: Color {
        switch command.category {
        case .codex:
            return LineyTheme.accent
        case .claude:
            return LineyTheme.warning
        case .cloud:
            return LineyTheme.localAccent
        case .linux:
            return LineyTheme.secondaryText
        }
    }
}

private struct QuickCommandMetaTag: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
