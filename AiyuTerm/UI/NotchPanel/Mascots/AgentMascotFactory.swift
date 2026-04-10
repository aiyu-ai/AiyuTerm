//
// AgentMascotFactory.swift
// AiyuTerm
//
// Phase 11.3A — CodeIsland mascot port.
//
// Maps a session source tag (e.g. "claude", "codex", "codebuddy") to the
// matching mascot SwiftUI view. Unknown sources fall back to a generic
// rounded-rect marker so the expanded notch card always has SOMETHING
// to render. Matches the mascot keys used by `AgentCLIAccent` in
// `AgentNotchPanelView.swift` so the mascot and the coloured tag line
// up visually.
//

import SwiftUI

enum AgentMascotFactory {
    @ViewBuilder
    static func mascot(
        for source: String,
        status: AgentSessionStatus,
        size: CGFloat = 27
    ) -> some View {
        switch source.lowercased() {
        case "claude":
            AgentClaudeMascotView(status: status, size: size)
        case "codex":
            AgentDexView(status: status, size: size)
        case "gemini":
            AgentGeminiView(status: status, size: size)
        case "cursor":
            AgentCursorView(status: status, size: size)
        case "copilot":
            AgentCopilotView(status: status, size: size)
        case "qoder":
            AgentQoderView(status: status, size: size)
        case "codebuddy":
            AgentBuddyView(status: status, size: size)
        case "droid":
            AgentDroidView(status: status, size: size)
        case "opencode":
            AgentOpenCodeView(status: status, size: size)
        default:
            AgentGenericMascotView(source: source, status: status, size: size)
        }
    }
}
