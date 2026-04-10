//
// AgentPixelKitEnvironment.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/MascotView.swift (env key fragment)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// SwiftUI environment hooks for the ported PixelKit. Phase 11.3C
// introduces the mascot speed key under an AiyuTerm-specific name so
// it does not collide with the parallel CLI-mascot porting worktree.
// A post-merge unification pass can rename this into a shared
// `agentMascotSpeed` env once both worktrees land.
//

import SwiftUI

// MARK: - Mascot animation speed

/// Multiplies the wall-clock time feeding the pixel mascot animations.
/// 1.0 = real time, 0.5 = half speed, 2.0 = double speed. Values must
/// be positive; clamp defensively when reading, the reducer treats 0
/// as "pause".
private struct PixelKitMascotSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    /// Mascot animation speed multiplier used by the ported
    /// `AgentClawdView` and sibling mascot views under `PixelKit/`.
    var pixelKitMascotSpeed: Double {
        get { self[PixelKitMascotSpeedKey.self] }
        set { self[PixelKitMascotSpeedKey.self] = newValue }
    }
}
