//
// AgentNotchAnimations.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/NotchAnimation.swift (78 lines)
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Spring animation constants + blur/fade transition + MorphText helper
// used throughout the notch panel UI. Renamed with `Agent`/`Pixel`
// prefixes so the types can live alongside the existing AiyuTerm
// animation helpers without collisions.
//

import SwiftUI

/// Shared spring animation presets for the notch panel.
enum AgentNotchAnimations {
    /// Panel open: slight bounce for a playful expand feel.
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Panel close: critical damping, no overshoot (prevents the
    /// panel shape bottom edge from slipping below the physical
    /// notch on retract).
    static let close = Animation.spring(response: 0.38, dampingFraction: 1.0)
    /// Notification pop: fast bouncy bump for completion/approval
    /// auto-expansion.
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.65)
    /// Micro interaction: hover, button highlight, tiny state flips.
    static let micro = Animation.easeOut(duration: 0.12)
}

// MARK: - Blur + Fade transition

private struct AgentBlurFadeModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .blur(radius: active ? 5 : 0)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    /// Blur out + fade — smoother than plain opacity for notch content
    /// switches. Ported from CodeIsland `AnyTransition.blurFade`.
    static var agentBlurFade: AnyTransition {
        .modifier(
            active: AgentBlurFadeModifier(active: true),
            identity: AgentBlurFadeModifier(active: false)
        )
    }
}

// MARK: - AgentMorphText — blur morph on text change

/// Text that briefly blurs when its content changes, creating a smooth
/// "morph" effect. Used for tool descriptions that update mid-task.
struct AgentMorphText: View {
    let text: String
    var font: Font = .system(size: 12)
    var color: Color = .white
    var lineLimit: Int? = 1

    @State private var displayed: String
    @State private var blur: CGFloat = 0
    @State private var generation = 0

    init(text: String, font: Font = .system(size: 12), color: Color = .white, lineLimit: Int? = 1) {
        self.text = text
        self.font = font
        self.color = color
        self.lineLimit = lineLimit
        _displayed = State(initialValue: text)
    }

    var body: some View {
        Text(displayed)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .blur(radius: blur * 4)
            .opacity(1 - blur * 0.15)
            .compositingGroup()
            .onChange(of: text) { _, newText in
                guard newText != displayed else { return }
                generation += 1
                let gen = generation
                withAnimation(.easeOut(duration: 0.1)) { blur = 1 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(60))
                    guard gen == generation else { return }
                    displayed = newText
                    withAnimation(.easeOut(duration: 0.15)) { blur = 0 }
                }
            }
    }
}
