//
//  AiyuTermTheme.swift
//  AiyuTerm
//
//  Author: everettjf
//

import AppKit
import SwiftUI

enum AiyuTermTheme {
    static let appBackground = Color(nsColor: NSColor(calibratedRed: 0.045, green: 0.05, blue: 0.062, alpha: 1))
    static let canvasBackground = Color(nsColor: NSColor(calibratedRed: 0.05, green: 0.055, blue: 0.069, alpha: 1))
    static let panelBackground = Color(nsColor: NSColor(calibratedRed: 0.067, green: 0.073, blue: 0.089, alpha: 1))
    static let panelRaised = Color(nsColor: NSColor(calibratedRed: 0.074, green: 0.081, blue: 0.099, alpha: 1))
    static let chromeBackground = Color(nsColor: NSColor(calibratedRed: 0.056, green: 0.062, blue: 0.076, alpha: 0.96))
    static let sidebarBackground = Color(nsColor: NSColor(calibratedRed: 0.058, green: 0.064, blue: 0.079, alpha: 1))
    static let sidebarSearchBackground = Color(nsColor: NSColor(calibratedRed: 0.078, green: 0.085, blue: 0.102, alpha: 1))
    static let paneBackground = Color(nsColor: NSColor(calibratedRed: 0.061, green: 0.068, blue: 0.083, alpha: 1))
    static let paneHeaderBackground = Color(nsColor: NSColor(calibratedRed: 0.072, green: 0.078, blue: 0.094, alpha: 1))
    static let backdropBlue = Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.47, alpha: 0.18))
    static let backdropTeal = Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.39, blue: 0.34, alpha: 0.14))
    static let border = Color.white.opacity(0.085)
    static let strongBorder = Color.white.opacity(0.16)
    static let accent = Color(nsColor: NSColor(calibratedRed: 0.25, green: 0.54, blue: 0.98, alpha: 1))
    static let accentMuted = Color(nsColor: NSColor(calibratedRed: 0.15, green: 0.27, blue: 0.42, alpha: 1))
    static let localAccent = Color(nsColor: NSColor(calibratedRed: 0.2, green: 0.72, blue: 0.63, alpha: 1))
    static let success = Color(nsColor: NSColor(calibratedRed: 0.31, green: 0.84, blue: 0.52, alpha: 1))
    static let warning = Color(nsColor: NSColor(calibratedRed: 0.94, green: 0.66, blue: 0.21, alpha: 1))
    static let danger = Color(nsColor: NSColor(calibratedRed: 0.92, green: 0.42, blue: 0.34, alpha: 1))
    static let mutedText = Color.white.opacity(0.58)
    static let secondaryText = Color.white.opacity(0.74)
    static let tertiaryText = Color.white.opacity(0.9)
    static let subtleFill = Color.white.opacity(0.05)
    static let subtleRaisedFill = Color.white.opacity(0.08)

    static let sidebarSelectionFill = NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.24, alpha: 1)
    static let sidebarSelectionStroke = NSColor(calibratedRed: 0.26, green: 0.45, blue: 0.78, alpha: 0.92)
    static let sidebarHoverFill = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1)
    static let dividerColor = NSColor(calibratedWhite: 1, alpha: 0.08)
}
