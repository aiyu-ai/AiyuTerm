//
//  RenameWorkspaceSheet.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct RenameWorkspaceSheet: View {
    let request: RenameWorkspaceRequest
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    private func localized(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localized("sheet.renameWorkspace.title"))
                .font(.title2.weight(.semibold))

            TextField(localized("sheet.renameWorkspace.placeholder"), text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(localized("common.cancel")) {
                    dismiss()
                }
                Button(localized("common.save")) {
                    onSubmit(name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            name = request.currentName
        }
    }
}
