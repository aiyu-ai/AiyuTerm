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

    private var sheetTitle: String {
        if request.isGroupCreation {
            return localized("sheet.createGroup.title")
        } else if request.isGroupRename {
            return localized("sheet.renameGroup.title")
        }
        return localized("sheet.renameWorkspace.title")
    }

    private var sheetPlaceholder: String {
        if request.isGroupCreation || request.isGroupRename {
            return localized("sheet.groupName.placeholder")
        }
        return localized("sheet.renameWorkspace.placeholder")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(sheetTitle)
                .font(.title2.weight(.semibold))

            TextField(sheetPlaceholder, text: $name)
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
