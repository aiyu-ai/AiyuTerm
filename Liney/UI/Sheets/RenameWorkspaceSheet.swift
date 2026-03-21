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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename Workspace")
                .font(.title2.weight(.semibold))

            TextField("Workspace Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
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
