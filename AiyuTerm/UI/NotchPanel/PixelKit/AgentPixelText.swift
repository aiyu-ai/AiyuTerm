//
// AgentPixelText.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/NotchPanelView.swift
// (private struct PixelText, lines 1736-1820)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// 5x7 dot-matrix pixel font renderer implemented with SwiftUI Canvas,
// plus the companion `AgentLineShape` helper. Hoisted out of the
// monolithic upstream NotchPanelView.swift so it can be reused from
// AiyuTerm's own panel and tests.
//

import SwiftUI

/// Pixel-art text renderer using a 5x7 dot matrix font.
struct AgentPixelText: View {
    let text: String
    let color: Color
    var pixelSize: CGFloat = 2

    private static let W = 5  // glyph width
    private static let H = 7  // glyph height

    // 5x7 bitmaps — each row is 5 bits, 7 rows per glyph
    private static let glyphs: [Character: [UInt8]] = [
        "0": [0,1,1,1,0, 1,0,0,1,1, 1,0,1,0,1, 1,1,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "1": [0,0,1,0,0, 0,1,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "2": [0,1,1,1,0, 1,0,0,0,1, 0,0,1,1,0, 0,1,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0],
        "3": [0,1,1,1,0, 1,0,0,0,1, 0,0,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "4": [0,0,0,1,0, 0,0,1,1,0, 0,1,0,1,0, 1,1,1,1,1, 0,0,0,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "5": [1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,0, 0,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "6": [0,1,1,1,0, 1,0,0,0,0, 1,1,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "7": [1,1,1,1,1, 0,0,0,0,1, 0,0,0,1,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "8": [0,1,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "9": [0,1,1,1,0, 1,0,0,0,1, 0,1,1,1,1, 0,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "A": [0,0,1,0,0, 0,1,0,1,0, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "B": [1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "C": [0,1,1,1,0, 1,0,0,0,1, 1,0,0,0,0, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "D": [1,1,1,1,0, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "E": [1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,0, 1,0,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0],
        "F": [1,1,1,1,1, 1,0,0,0,0, 1,1,1,1,0, 1,0,0,0,0, 1,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "G": [0,1,1,1,0, 1,0,0,0,0, 1,0,0,1,1, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "H": [1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "I": [0,1,1,1,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "K": [1,0,0,1,0, 1,0,1,0,0, 1,1,0,0,0, 1,0,1,0,0, 1,0,0,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "L": [1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0],
        "N": [1,0,0,0,1, 1,1,0,0,1, 1,0,1,0,1, 1,0,0,1,1, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "O": [0,1,1,1,0, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "P": [1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,0,0, 1,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "R": [1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,1,0, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "S": [0,1,1,1,1, 1,0,0,0,0, 0,1,1,1,0, 0,0,0,0,1, 1,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "T": [1,1,1,1,1, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "U": [1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 0,1,1,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "W": [1,0,0,0,1, 1,0,0,0,1, 1,0,1,0,1, 1,0,1,0,1, 0,1,0,1,0, 0,0,0,0,0, 0,0,0,0,0],
        "X": [1,0,0,0,1, 0,1,0,1,0, 0,0,1,0,0, 0,1,0,1,0, 1,0,0,0,1, 0,0,0,0,0, 0,0,0,0,0],
        "/": [0,0,0,0,1, 0,0,0,1,0, 0,0,1,0,0, 0,1,0,0,0, 1,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        "-": [0,0,0,0,0, 0,0,0,0,0, 1,1,1,1,1, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
        " ": [0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0],
    ]

    var body: some View {
        let chars = Array(text.uppercased())
        let px = pixelSize
        let gap: CGFloat = px

        Canvas { ctx, _ in
            var xOff: CGFloat = 0
            for ch in chars {
                guard let glyph = Self.glyphs[ch] else {
                    xOff += 3 * px
                    continue
                }
                for row in 0..<Self.H {
                    for col in 0..<Self.W {
                        if glyph[row * Self.W + col] == 1 {
                            let rect = CGRect(x: xOff + CGFloat(col) * px, y: CGFloat(row) * px, width: px, height: px)
                            ctx.fill(Path(rect), with: .color(color))
                        }
                    }
                }
                xOff += CGFloat(Self.W) * px + gap
            }
        }
        .frame(width: charWidth(chars.count), height: CGFloat(Self.H) * pixelSize)
    }

    private func charWidth(_ count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let px = pixelSize
        return CGFloat(count) * (CGFloat(Self.W) * px + px) - px
    }
}

/// Horizontal line shape used as a visual separator (ported from
/// upstream `Line` inside NotchPanelView.swift).
struct AgentLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
