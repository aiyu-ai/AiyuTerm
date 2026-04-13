//
// AgentClaudeMascotView.swift
// AiyuTerm
//
// Phase 11.3A — CodeIsland mascot port.
//
// Claude-specific mascot. CodeIsland upstream does not ship a dedicated
// Claude pixel-art view (it uses a static `ClaudeLogoShape` sunburst
// elsewhere in the app), so this file implements a minimal pulsing
// sunburst Shape in the same visual family as the other mascots.
//
// The design goal is to render as "more than just a colored dot": three
// animated sunburst rays + a solid core + status-specific color, all
// driven by the same TimelineView pattern and `agentMascotSpeed`
// environment the other mascot views consume.
//

import SwiftUI

/// AgentClaudeMascotView — Claude sunburst mascot rendered via Canvas.
/// Uses a 12-ray star shape inside a 16x16 pixel grid, pulsing gently in
/// idle and spinning faster while working. Color adapts to status:
/// Anthropic orange by default, pink during permissionNeeded, red on
/// error, and a softer amber when the task has just completed.
struct AgentClaudeMascotView: View {
    let status: AgentSessionStatus
    var size: CGFloat = 27
    @Environment(\.agentMascotSpeed) private var speed

    // Anthropic-ish palette
    private static let coreC       = Color(red: 0.85, green: 0.42, blue: 0.20) // rust orange
    private static let coreHot     = Color(red: 1.00, green: 0.55, blue: 0.26) // brighter flare
    private static let completedC  = Color(red: 0.96, green: 0.75, blue: 0.26) // amber
    private static let permissionC = Color(red: 0.96, green: 0.36, blue: 0.58) // pink
    private static let errorC      = Color(red: 0.98, green: 0.26, blue: 0.22) // red

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * speed.timeMultiplier
            canvas(t: t)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    private var baseColor: Color {
        switch status {
        case .none:              return Self.coreC.opacity(0.82)
        case .working:           return Self.coreHot
        case .compacting:        return Self.coreC.opacity(0.65)
        case .taskCompleted:     return Self.completedC
        case .permissionNeeded:  return Self.permissionC
        case .error:             return Self.errorC
        }
    }

    private var pulseRange: (lo: CGFloat, hi: CGFloat) {
        switch status {
        case .working:           return (0.88, 1.12)
        case .compacting:        return (0.93, 1.06)
        case .permissionNeeded:  return (0.80, 1.22)
        case .error:             return (0.85, 1.18)
        case .taskCompleted:     return (0.95, 1.06)
        case .none:              return (0.93, 1.04)
        }
    }

    private var spinPeriod: Double {
        switch status {
        case .working:           return 2.4
        case .compacting:        return 3.0
        case .permissionNeeded:  return 1.6
        case .error:             return 1.4
        case .taskCompleted:     return 3.6
        case .none:              return 5.2
        }
    }

    private func canvas(t: Double) -> some View {
        let pulse = (sin(t * 2 * .pi / 1.1) + 1) * 0.5 // 0...1
        let range = pulseRange
        let scale = range.lo + (range.hi - range.lo) * CGFloat(pulse)
        let angle = (t.truncatingRemainder(dividingBy: spinPeriod)) / spinPeriod * 2 * .pi

        return Canvas { ctx, sz in
            let cx = sz.width / 2
            let cy = sz.height / 2
            let r = min(sz.width, sz.height) / 2
            let rayInner = r * 0.32 * scale
            let rayOuter = r * 0.88 * scale
            let coreR = r * 0.36 * scale

            let rayCount = 12
            for i in 0..<rayCount {
                let theta = angle + Double(i) * 2 * .pi / Double(rayCount)
                let thick = r * (i % 2 == 0 ? 0.10 : 0.06)
                var path = Path()
                let dir = CGVector(dx: cos(theta), dy: sin(theta))
                let nrm = CGVector(dx: -dir.dy, dy: dir.dx)
                let p1 = CGPoint(x: cx + dir.dx * rayInner + nrm.dx * thick,
                                 y: cy + dir.dy * rayInner + nrm.dy * thick)
                let p2 = CGPoint(x: cx + dir.dx * rayInner - nrm.dx * thick,
                                 y: cy + dir.dy * rayInner - nrm.dy * thick)
                let p3 = CGPoint(x: cx + dir.dx * rayOuter - nrm.dx * thick * 0.25,
                                 y: cy + dir.dy * rayOuter - nrm.dy * thick * 0.25)
                let p4 = CGPoint(x: cx + dir.dx * rayOuter + nrm.dx * thick * 0.25,
                                 y: cy + dir.dy * rayOuter + nrm.dy * thick * 0.25)
                path.move(to: p1)
                path.addLine(to: p2)
                path.addLine(to: p3)
                path.addLine(to: p4)
                path.closeSubpath()
                let alpha = 0.55 + 0.35 * pulse
                ctx.fill(path, with: .color(baseColor.opacity(alpha)))
            }

            // Solid core disc
            let coreRect = CGRect(x: cx - coreR, y: cy - coreR,
                                  width: coreR * 2, height: coreR * 2)
            ctx.fill(Path(ellipseIn: coreRect), with: .color(baseColor))

            // Inner highlight for depth
            let hlR = coreR * 0.55
            let hlRect = CGRect(x: cx - hlR * 1.2, y: cy - hlR * 1.2,
                                width: hlR * 2, height: hlR * 2)
            ctx.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(0.18)))
        }
    }
}
