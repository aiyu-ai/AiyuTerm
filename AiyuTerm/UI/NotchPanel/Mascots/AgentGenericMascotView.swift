//
// AgentGenericMascotView.swift
// AiyuTerm
//
// Phase 11.3A — CodeIsland mascot port.
//
// Fallback mascot rendered for unknown CLI sources. Shows a rounded
// square with the first letter of the source name so the notch panel's
// session card always has SOMETHING to render, even for custom CLIs the
// user added via config that don't match one of the eight shipped
// mascots. The status color mirrors the existing dot palette used on
// the sidebar so visual language stays consistent.
//

import SwiftUI

struct AgentGenericMascotView: View {
    let source: String
    let status: AgentSessionStatus
    var size: CGFloat = 27

    var body: some View {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let letter = trimmed.first.map { String($0).uppercased() } ?? "?"

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(background)
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(border, lineWidth: 1)
            Text(letter)
                .font(.system(size: size * 0.52, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
    }

    private var background: Color {
        switch status {
        case .working:           return Color.blue.opacity(0.85)
        case .permissionNeeded:  return Color.pink.opacity(0.85)
        case .taskCompleted:     return Color.green.opacity(0.80)
        case .error:             return Color.red.opacity(0.85)
        case .none:              return Color.secondary.opacity(0.55)
        }
    }

    private var border: Color {
        background.opacity(0.55)
    }
}
