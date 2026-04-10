//
// AgentMascotViewShell.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/MascotView.swift (49 lines)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Routes a CLI source identifier to the correct pixel mascot view.
// Phase 11.3C ports only the `AgentClawdView` mascot (see
// `AgentPixelCharacterView.swift`); the parallel `phase11/cli-mascots`
// worktree is porting the Codex/Gemini/Cursor/Copilot/Qoder/Droid/
// CodeBuddy/OpenCode siblings. Until those land we fall back to
// Clawd for every source, and the Agent prefix keeps this shell safe
// to live next to the existing `AgentClawdView` without colliding
// with the other worktree's types.
//

import SwiftUI

/// Routes a CLI source identifier (`"claude"`, `"codex"`, …) to the
/// correct pixel mascot view. Until sibling mascots land from the
/// parallel porting worktree this falls back to `AgentClawdView` for
/// every source.
struct AgentMascotViewShell: View {
    let source: String
    let status: AgentHookStatus
    var size: CGFloat = 27

    // TODO(AiyuTerm integration): swap to settings-backed speed once
    // the notch panel settings land. For now default to 1.0.
    private let speedPct: Int = 100

    var body: some View {
        Group {
            switch source {
            // TODO(AiyuTerm integration): route codex/gemini/cursor/
            // copilot/qoder/droid/codebuddy/opencode to their own
            // mascot views once the phase11/cli-mascots worktree
            // lands its Agent-prefixed variants.
            default:
                AgentClawdView(status: status, size: size)
            }
        }
        .environment(\.pixelKitMascotSpeed, Double(speedPct) / 100.0)
    }
}
