//
// AgentMiniAgentIcon.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/NotchPanelView.swift
// (struct MiniAgentIcon, lines 1928-1973)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// An 8-bit pixel-art robot head used as a tiny status dot for
// subagents. Ported 1:1; the only edit is the Agent prefix on
// the struct name.
//

import SwiftUI

/// 8-bit robot head rendered on a 7x7 grid. Green when `active`,
/// desaturated gray when idle.
struct AgentMiniAgentIcon: View {
    let active: Bool
    var size: CGFloat = 12

    // 0=empty, 1=body, 2=eye, 3=antenna tip, 4=highlight, 5=shadow
    private let grid: [[Int]] = [
        [0, 0, 0, 3, 0, 0, 0],  // antenna tip (glows)
        [0, 0, 0, 1, 0, 0, 0],  // antenna stem
        [0, 4, 1, 1, 1, 5, 0],  // head top
        [0, 1, 2, 1, 2, 1, 0],  // eyes
        [0, 1, 1, 1, 1, 1, 0],  // face
        [0, 5, 1, 0, 1, 5, 0],  // mouth
        [0, 0, 1, 0, 1, 0, 0],  // legs
    ]

    var body: some View {
        let base = active ? Color.green : Color.gray
        let bright = active ? Color(red: 0.5, green: 1.0, blue: 0.5) : Color(white: 0.7)
        let dark = active ? Color(red: 0.1, green: 0.5, blue: 0.15) : Color(white: 0.35)
        let eye = active ? Color.white : Color(white: 0.85)
        let glow = active ? Color(red: 0.4, green: 1.0, blue: 0.4) : Color(white: 0.6)

        Canvas { ctx, sz in
            let px = sz.width / 7
            for row in 0..<7 {
                for col in 0..<7 {
                    let v = grid[row][col]
                    guard v != 0 else { continue }
                    let color: Color = switch v {
                    case 2: eye
                    case 3: glow
                    case 4: bright
                    case 5: dark
                    default: base
                    }
                    ctx.fill(
                        Path(CGRect(x: CGFloat(col) * px, y: CGFloat(row) * px, width: px, height: px)),
                        with: .color(color)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: active ? .green.opacity(0.4) : .clear, radius: 2)
    }
}
