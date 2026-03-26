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

    private func localized(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        l10nFormat(localized(key), locale: Locale.current, arguments: arguments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("sheet.ssh.title"))
                .font(.system(size: 18, weight: .semibold))

            Text(localizedFormat("sheet.ssh.descriptionFormat", request.workspaceName))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            GroupBox(localized("sheet.ssh.connection")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(localized("sheet.ssh.host"), text: $draft.host)
                    TextField(localized("sheet.ssh.user"), text: $draft.user)
                    TextField(localized("sheet.ssh.port"), text: $draft.port)
                    TextField(localized("sheet.ssh.identityFile"), text: $draft.identityFilePath)
                    TextField(localized("sheet.ssh.remoteWorkingDirectory"), text: $draft.remoteWorkingDirectory)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
            }

            GroupBox(localized("sheet.ssh.command")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(localized("sheet.ssh.remoteCommand"), text: $draft.remoteCommand, axis: .vertical)
                    LabeledContent(localized("sheet.shared.engine"), value: TerminalEngineKind.libghosttyPreferred.displayName)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
            }

            HStack {
                Spacer()
                Button(localized("common.cancel")) {
                    dismiss()
                }
                Button(localized("sheet.ssh.create")) {
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
