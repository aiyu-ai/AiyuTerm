//
// AgentMascotEnvironment.swift
// AiyuTerm
//
// Phase 11.3A — CodeIsland mascot port.
//
// Defines the SwiftUI environment key that lets call sites override the
// animation speed multiplier used by the per-CLI pixel-art mascot views.
// Mirrors CodeIsland upstream `@Environment(\.mascotSpeed)` so the ported
// `AgentXxxView` files can read a single value without each one owning its
// own settings plumbing.
//
// The value is a multiplier applied to the time parameter passed into each
// mascot's TimelineView — higher multiplier = faster animation. `frameInterval`
// is exposed for any future call site that wants to drive manual rendering.
//

import SwiftUI

enum AgentMascotSpeed: Int, CaseIterable, Codable, Sendable {
    case slow = 0
    case normal = 1
    case fast = 2

    /// Preferred per-frame tick interval for mascots that want to throttle
    /// their own TimelineView beyond the hard-coded upstream defaults.
    /// Exposed as a property so external code (settings UI, tests) can reason
    /// about the concrete values without reaching into private constants.
    var frameInterval: TimeInterval {
        switch self {
        case .slow: return 0.8
        case .normal: return 0.5
        case .fast: return 0.25
        }
    }

    /// Multiplier applied to `TimelineView` time parameters so upstream
    /// mascot code that reads `@Environment(\.agentMascotSpeed)` can scale
    /// its phase math uniformly.
    var timeMultiplier: Double {
        switch self {
        case .slow: return 0.5
        case .normal: return 1.0
        case .fast: return 2.0
        }
    }
}

private struct AgentMascotSpeedKey: EnvironmentKey {
    static let defaultValue: AgentMascotSpeed = .normal
}

extension EnvironmentValues {
    /// Animation speed multiplier for notch-panel mascot views. Prefer this
    /// over hard-coded TimelineView intervals so the whole panel can be
    /// slowed down for accessibility or speed up for demos from one place.
    var agentMascotSpeed: AgentMascotSpeed {
        get { self[AgentMascotSpeedKey.self] }
        set { self[AgentMascotSpeedKey.self] = newValue }
    }
}
