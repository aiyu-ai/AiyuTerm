//
//  TitleBarVersionView.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import SwiftUI

struct TitleBarVersionView: View {
    let currentVersion: String
    let updateState: AppUpdateState
    let onInstall: () -> Void

    @State private var isHovering = false

    var body: some View {
        Group {
            switch updateState {
            case .none:
                Text("AiyuTerm - \(currentVersion)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

            case .available(let version):
                updateButton(label: "v\(version) available", color: .orange) {
                    onInstall()
                }

            case .downloading(let version):
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Downloading v\(version)...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

            case .readyToInstall(let version):
                updateButton(label: "v\(version) ready - restart to update", color: .green) {
                    onInstall()
                }
            }
        }
    }

    private func updateButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color.opacity(isHovering ? 0.15 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
