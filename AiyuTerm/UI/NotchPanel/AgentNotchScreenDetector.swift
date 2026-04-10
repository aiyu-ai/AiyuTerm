//
// AgentNotchScreenDetector.swift
// AiyuTerm
//
// Phase 8.1: screen detection + notch geometry for the agent
// activity panel.
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/ScreenDetector.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Responsibilities:
//   • Pick the "preferred" screen to host the notch panel —
//     biased toward whichever screen currently owns the frontmost
//     foreign app, then to the built-in display with a real notch,
//     then to NSScreen.main, finally to anything.
//   • Report the notch rect / height / width for a given screen,
//     with a simulated notch width on screens that don't have one.
//   • Provide a stable signature string so the panel controller
//     can detect screen topology changes and re-anchor itself.
//

import AppKit

enum AgentNotchScreenDetector {

    // MARK: - Candidate model

    struct Candidate: Equatable {
        let frame: CGRect
        let hasNotch: Bool
        let isMain: Bool
    }

    // MARK: - Preferred screen selection

    /// Picks the best screen to host the notch panel:
    ///   1. A screen whose frame contains the center of the frontmost
    ///      foreign app's main window.
    ///   2. A screen with the largest overlap against that window.
    ///   3. The first screen with a real MacBook notch.
    ///   4. NSScreen.main.
    ///   5. The first screen in `NSScreen.screens`.
    static var preferredScreen: NSScreen {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return NSScreen.main ?? NSScreen()
        }
        let mainScreen = NSScreen.main
        let candidates = screens.map { screen in
            Candidate(
                frame: screen.frame,
                hasNotch: screenHasNotch(screen),
                isMain: mainScreen == screen
            )
        }
        if let index = autoPreferredIndex(
            candidates: candidates,
            activeWindowBounds: frontmostApplicationWindowBounds()
        ), index < screens.count {
            return screens[index]
        }
        return mainScreen ?? screens.first ?? NSScreen()
    }

    /// Pure index-picking logic extracted so tests can drive it with
    /// synthetic candidate lists without touching AppKit.
    static func autoPreferredIndex(
        candidates: [Candidate],
        activeWindowBounds: CGRect?
    ) -> Int? {
        guard !candidates.isEmpty else { return nil }

        if let activeWindowBounds {
            let center = CGPoint(x: activeWindowBounds.midX, y: activeWindowBounds.midY)
            if let index = candidates.firstIndex(where: { $0.frame.contains(center) }) {
                return index
            }
            let bestOverlap = candidates.enumerated()
                .map { offset, candidate in
                    (offset, overlapArea(lhs: candidate.frame, rhs: activeWindowBounds))
                }
                .max { lhs, rhs in lhs.1 < rhs.1 }
            if let bestOverlap, bestOverlap.1 > 0 {
                return bestOverlap.0
            }
        }
        if let notchIndex = candidates.firstIndex(where: \.hasNotch) {
            return notchIndex
        }
        if let mainIndex = candidates.firstIndex(where: \.isMain) {
            return mainIndex
        }
        return candidates.indices.first
    }

    // MARK: - Notch geometry

    static var hasNotch: Bool {
        screenHasNotch(preferredScreen)
    }

    static func screenHasNotch(_ screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.auxiliaryTopLeftArea != nil || screen.auxiliaryTopRightArea != nil
        }
        return false
    }

    static var notchHeight: CGFloat {
        topBarHeight(for: preferredScreen)
    }

    /// Height of the topmost "bar" area. On real-notch screens this
    /// is the notch height itself (the OS exposes it via
    /// safeAreaInsets.top). On non-notch screens we fall back to
    /// the menu bar height, or 25pt as a last resort.
    static func topBarHeight(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let real = screen.safeAreaInsets.top
            if real > 0 { return real }
        }
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if menuBarHeight > 5 { return menuBarHeight }
        if let main = NSScreen.main {
            let mainMenuBar = main.frame.maxY - main.visibleFrame.maxY
            if mainMenuBar > 5 { return mainMenuBar }
        }
        return 25
    }

    static var notchWidth: CGFloat {
        notchWidth(for: preferredScreen)
    }

    static func notchWidth(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            if leftWidth > 0 || rightWidth > 0 {
                return screen.frame.width - leftWidth - rightWidth
            }
        }
        return fakeNotchWidth(for: screen)
    }

    /// Simulated notch width for non-notch screens. Scales with the
    /// physical screen width so the panel looks proportional on
    /// both a 13" MacBook and a 27" external monitor.
    static func fakeNotchWidth(for screen: NSScreen) -> CGFloat {
        fakeNotchWidth(forFrameWidth: screen.frame.width)
    }

    /// Pure overload that takes the raw width, so tests can drive
    /// the clamp math without instantiating NSScreen (subclassing
    /// NSScreen crashes at runtime because the initializer is
    /// private).
    static func fakeNotchWidth(forFrameWidth width: CGFloat) -> CGFloat {
        min(max(width * 0.14, 160), 240)
    }

    // MARK: - Panel rect helpers

    /// Absolute CGRect describing the notch region on the given
    /// screen. The bottom edge of the rect sits exactly at
    /// `screen.frame.maxY - topBarHeight(for:)`.
    static func notchFrame(for screen: NSScreen) -> CGRect {
        let width = notchWidth(for: screen)
        let height = topBarHeight(for: screen)
        let origin = CGPoint(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    /// Frame for the expanded panel. Anchored to the notch bottom
    /// edge, centered horizontally.
    static func expandedFrame(
        for screen: NSScreen,
        size: CGSize
    ) -> CGRect {
        let notch = notchFrame(for: screen)
        return CGRect(
            x: notch.midX - size.width / 2,
            y: notch.minY - size.height,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Signature

    /// Stable hash-like signature string for a screen, used by the
    /// panel controller to detect layout changes from
    /// `NSApplication.didChangeScreenParametersNotification`.
    static func signature(for screen: NSScreen) -> String {
        signature(forFrame: screen.frame)
    }

    /// Pure overload for tests — avoids NSScreen subclassing.
    static func signature(forFrame frame: CGRect) -> String {
        let integral = frame.integral
        return "\(Int(integral.origin.x)):\(Int(integral.origin.y)):\(Int(integral.width)):\(Int(integral.height))"
    }

    // MARK: - Private

    private static func overlapArea(lhs: CGRect, rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }

    /// Finds the bounds of the frontmost foreign app's primary
    /// window using CGWindowList. Returns nil if AiyuTerm itself
    /// is frontmost or nothing suitable is visible.
    private static func frontmostApplicationWindowBounds() -> CGRect? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let preferredPID: pid_t? = frontApp.processIdentifier == ownPID ? nil : frontApp.processIdentifier

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  rect.width > 0,
                  rect.height > 0
            else { continue }
            guard pid != ownPID else { continue }
            if let preferredPID, pid != preferredPID { continue }
            return rect
        }

        guard preferredPID != nil else { return nil }

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  pid != ownPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  rect.width > 0,
                  rect.height > 0
            else { continue }
            return rect
        }

        return nil
    }
}
