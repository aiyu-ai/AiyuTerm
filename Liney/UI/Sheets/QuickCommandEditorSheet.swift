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

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Commands")
                    .font(.system(size: 20, weight: .semibold))

                Text("These snippets are inserted into the focused terminal and wait for you to press Return.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("Add Command") {
                            draftCommands.append(
                                QuickCommandPreset(
                                    title: "New Command",
                                    command: "",
                                    category: .codex
                                )
                            )
                        }

                        Button("Reset Defaults") {
                            draftCommands = QuickCommandCatalog.defaultCommands
                        }

                        Spacer()

                        Text("\(draftCommands.count) commands")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if draftCommands.isEmpty {
                        Text("No quick commands configured. Add one or restore the defaults.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)
                    } else {
                        ForEach(Array(draftCommands.indices), id: \.self) { index in
                            QuickCommandEditorCard(
                                command: $draftCommands[index],
                                canMoveUp: index > 0,
                                canMoveDown: index < draftCommands.count - 1,
                                onMoveUp: { moveCommand(from: index, to: index - 1) },
                                onMoveDown: { moveCommand(from: index, to: index + 1) },
                                onDelete: { draftCommands.removeAll { $0.id == draftCommands[index].id } }
                            )
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    store.updateQuickCommandPresets(draftCommands)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 760, height: 620)
        .task {
            draftCommands = store.quickCommandPresets
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
    }
}

private struct QuickCommandEditorCard: View {
    @Binding var command: QuickCommandPreset
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ToolbarFeatureIcon(
                    systemName: command.category.symbolName,
                    tint: tint
                )

                TextField("Title", text: $command.title)

                Picker("Category", selection: $command.category) {
                    ForEach(QuickCommandCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .frame(width: 140)

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

            VStack(alignment: .leading, spacing: 6) {
                Text("Command")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $command.command)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 82)
                    .padding(8)
                    .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(LineyTheme.border, lineWidth: 1)
                    )
            }

        }
        .padding(14)
        .background(LineyTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LineyTheme.border, lineWidth: 1)
        )
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
