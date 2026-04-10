//
// AgentPixelKitEnvironment.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/MascotView.swift (env key fragment)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Phase 11.1.5 — UNIFIED mascot env key.
//
// Two Wave 3 agents independently created env keys for mascot
// animation speed in parallel worktrees:
//   - `AgentMascotEnvironment.swift` — canonical, typed
//     `agentMascotSpeed: AgentMascotSpeed` (slow / normal / fast)
//   - `AgentPixelKitEnvironment.swift` (this file) — legacy
//     `pixelKitMascotSpeed: Double` multiplier
//
// The canonical API is `agentMascotSpeed`. This file now exposes
// `pixelKitMascotSpeed` as a computed accessor that bridges the
// Double surface to the typed enum, so existing pixel-kit files
// that were written against the Double API keep compiling
// without modification. New code should read `agentMascotSpeed`
// directly.
//

import SwiftUI

extension EnvironmentValues {
    /// Deprecated mascot animation speed multiplier used by the
    /// original pixel-kit draft. Internally derived from
    /// `agentMascotSpeed` so both APIs stay in sync — writes
    /// snap the nearest enum case.
    var pixelKitMascotSpeed: Double {
        get { agentMascotSpeed.timeMultiplier }
        set {
            // Map the legacy Double back to the nearest enum
            // case. Anything < 0.75 is slow, > 1.5 is fast,
            // everything else snaps to normal.
            if newValue < 0.75 {
                agentMascotSpeed = .slow
            } else if newValue > 1.5 {
                agentMascotSpeed = .fast
            } else {
                agentMascotSpeed = .normal
            }
        }
    }
}
