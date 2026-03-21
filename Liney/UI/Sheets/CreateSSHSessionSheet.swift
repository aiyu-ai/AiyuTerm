//
//  CreateSSHSessionSheet.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct CreateSSHSessionSheet: View {
    let request: CreateSSHSessionRequest
    let onCreate: (CreateSSHSessionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CreateSSHSessionDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New SSH Session")
                .font(.system(size: 18, weight: .semibold))

            Text("Create a remote session attached to \(request.workspaceName).")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            GroupBox("Connection") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Host", text: $draft.host)
                    TextField("User (optional)", text: $draft.user)
                    TextField("Port (optional)", text: $draft.port)
                    TextField("Identity file (optional)", text: $draft.identityFilePath)
                    TextField("Remote working directory (optional)", text: $draft.remoteWorkingDirectory)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
            }

            GroupBox("Command") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Remote command (optional)", text: $draft.remoteCommand, axis: .vertical)
                    LabeledContent("Engine", value: TerminalEngineKind.libghosttyPreferred.displayName)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
            }

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
        .frame(width: 520)
    }
}
