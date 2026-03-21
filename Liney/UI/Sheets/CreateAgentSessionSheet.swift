//
//  CreateAgentSessionSheet.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct CreateAgentSessionSheet: View {
    let request: CreateAgentSessionRequest
    let onCreate: (CreateAgentSessionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CreateAgentSessionDraft()
    @State private var selectedPresetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Agent Session")
                .font(.system(size: 18, weight: .semibold))

            Text("Launch an AI agent command inside \(request.workspaceName). Use one argument per line.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !request.presets.isEmpty {
                Picker("Preset", selection: Binding(
                    get: { selectedPresetID ?? request.preferredPresetID ?? request.presets.first?.id },
                    set: { newValue in
                        selectedPresetID = newValue
                        if let newValue,
                           let preset = request.presets.first(where: { $0.id == newValue }) {
                            draft.apply(preset: preset)
                        }
                    }
                )) {
                    ForEach(request.presets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
            }

            GroupBox("Executable") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Display name", text: $draft.name)
                    TextField("Launch path", text: $draft.launchPath)
                    TextField("Working directory override (optional)", text: $draft.workingDirectory)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
            }

            GroupBox("Arguments") {
                TextEditor(text: $draft.argumentsText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08)))
                    .padding(.top, 8)
            }

            GroupBox("Environment") {
                TextEditor(text: $draft.environmentText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 90)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08)))
                    .padding(.top, 8)
            }

            LabeledContent("Engine", value: TerminalEngineKind.libghosttyPreferred.displayName)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create Session") {
                    onCreate(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.configuration == nil)
            }
        }
        .padding(20)
        .frame(width: 560)
        .task {
            selectedPresetID = request.preferredPresetID ?? request.presets.first?.id
            if let selectedPresetID,
               let preset = request.presets.first(where: { $0.id == selectedPresetID }) {
                draft.apply(preset: preset)
            } else {
                draft.workingDirectory = request.defaultWorkingDirectory
            }
        }
    }
}
