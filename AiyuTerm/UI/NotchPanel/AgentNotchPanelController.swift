//
// AgentNotchPanelController.swift
// AiyuTerm
//
// Phase 8.2: NSPanel host for the agent activity notch panel.
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/PanelWindowController.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// This file deliberately ships a *minimal* NSPanel skeleton:
//   • `KeyableNotchPanel` — an NSPanel subclass that always returns
//     `canBecomeKey = true` so buttons in the hosted SwiftUI tree
//     can respond to the first click.
//   • `NotchHostingView` — an NSHostingView wrapper that guards
//     against AppKit's "setNeedsUpdateConstraints re-entrancy"
//     crash by deferring the setter onto the next run-loop turn.
//     This is the same workaround CodeIsland landed after shipping
//     v1.0.30.
//   • `AgentNotchPanelController` — lifecycle controller that
//     creates the panel on `show()`, resizes it to follow the
//     preferred screen's notch rect, re-anchors on
//     `NSApplication.didChangeScreenParametersNotification`, and
//     tears down on `hide()`.
//
// Screen-hop animation, hover-to-expand, and global click-outside
// handling are intentionally deferred to Phase 8.3 so this commit
// stays focused on a single compilable, testable unit.
//

import AppKit
import Combine
import os.log
import SwiftUI

// MARK: - KeyableNotchPanel

/// NSPanel subclass that is allowed to become the key window so
/// SwiftUI buttons inside the hosted view can receive the first
/// click without requiring the user to hit the panel twice.
final class KeyableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - NotchHostingView

/// `NSHostingView` subclass that guards against two known AppKit
/// hazards documented by the CodeIsland upstream:
///
///   1. First-click activation on a `nonactivatingPanel` is
///      otherwise consumed for key-window focus rather than
///      delivered to SwiftUI buttons. We override `mouseDown` to
///      `makeKey()` first.
///   2. During AppKit's display cycle (constraint-update or layout
///      phases), calling `needsUpdateConstraints = true`
///      synchronously re-enters `_postWindowNeedsUpdateConstraints`
///      which AppKit forbids. We defer the setter onto the next
///      run-loop turn using DispatchQueue.main.async.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    private var applyingDeferred = false

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var needsUpdateConstraints: Bool {
        get { super.needsUpdateConstraints }
        set {
            if applyingDeferred {
                super.needsUpdateConstraints = newValue
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.applySuperNeedsUpdateConstraints(newValue)
            }
        }
    }

    private func applySuperNeedsUpdateConstraints(_ value: Bool) {
        applyingDeferred = true
        super.needsUpdateConstraints = value
        applyingDeferred = false
    }

    override var needsLayout: Bool {
        get { super.needsLayout }
        set {
            if applyingDeferred {
                super.needsLayout = newValue
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.applySuperNeedsLayout(newValue)
            }
        }
    }

    private func applySuperNeedsLayout(_ value: Bool) {
        applyingDeferred = true
        super.needsLayout = value
        applyingDeferred = false
    }
}

// MARK: - AgentNotchPanelController

/// Generic NSPanel controller that hosts any SwiftUI content in
/// the notch area. Phase 8.3 will feed it the real
/// `AgentNotchPanelView`; this file stays decoupled from the view
/// layer so the lifecycle and geometry code can be unit-tested
/// against a trivial placeholder.
///
/// Public surface (Phase 8.2):
///   • `show()` — create & present the panel. No-op if visible.
///   • `hide()` — tear down & unhook notifications.
///   • `isVisible` — inspection for tests + UI toggle.
///   • `repositionForCurrentScreen()` — force a re-anchor (called
///     from the screen-parameter observer and as a manual hook).
///
/// The controller intentionally does NOT own the SwiftUI content
/// closure as `@escaping`; instead it takes a view-building factory
/// closure at init time, matching the pattern WorkspaceStore uses
/// for other NSPanel-backed UIs.
@MainActor
final class AgentNotchPanelController<Content: View>: NSObject {

    // MARK: - Dependencies

    private let contentFactory: @MainActor () -> Content

    // MARK: - State

    private var panel: KeyableNotchPanel?
    private var hostingView: NotchHostingView<Content>?
    private var screenParamObserver: NSObjectProtocol?

    /// Cached signature of the screen currently hosting the panel.
    /// Used to skip no-op repositions when screen parameters fire
    /// without actually changing the preferred screen (e.g. a
    /// brightness adjustment).
    private var lastChosenScreenSignature: String = ""

    nonisolated private static var logger: Logger {
        Logger(subsystem: "com.aiyuai.aiyuterm", category: "AgentNotchPanelController")
    }

    // MARK: - Init

    init(@ViewBuilder content: @escaping @MainActor () -> Content) {
        self.contentFactory = content
        super.init()
    }

    deinit {
        // NSNotificationCenter observers are torn down when the
        // controller is deallocated. We intentionally do not touch
        // MainActor-isolated state from deinit to avoid a Swift 6
        // task-dispatch hop during teardown.
    }

    // MARK: - Public API

    var isVisible: Bool {
        panel?.isVisible == true
    }

    /// Present the panel on the preferred screen. Idempotent.
    func show() {
        if panel?.isVisible == true { return }
        let newPanel = createPanelIfNeeded()
        let screen = AgentNotchScreenDetector.preferredScreen
        let frame = collapsedFrame(for: screen)
        newPanel.setFrame(frame, display: false)
        lastChosenScreenSignature = AgentNotchScreenDetector.signature(for: screen)
        newPanel.orderFrontRegardless()
        attachScreenObserverIfNeeded()
    }

    /// Hide the panel and tear down the window + observer. The
    /// SwiftUI view tree is destroyed; next `show()` rebuilds it.
    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        detachScreenObserver()
        lastChosenScreenSignature = ""
    }

    /// Force a re-anchor to the current preferred screen, skipping
    /// the update if the signature hasn't changed.
    func repositionForCurrentScreen(animated: Bool = false) {
        guard let panel else { return }
        let screen = AgentNotchScreenDetector.preferredScreen
        let signature = AgentNotchScreenDetector.signature(for: screen)
        if signature == lastChosenScreenSignature { return }
        lastChosenScreenSignature = signature
        let frame = collapsedFrame(for: screen)
        panel.setFrame(frame, display: true, animate: animated)
    }

    // MARK: - Panel construction

    private func createPanelIfNeeded() -> KeyableNotchPanel {
        if let existing = panel {
            return existing
        }
        let view = contentFactory()
        let hosting = NotchHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]

        let newPanel = KeyableNotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.level = .statusBar
        newPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
        ]
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.ignoresMouseEvents = false
        newPanel.contentView = hosting

        panel = newPanel
        hostingView = hosting
        return newPanel
    }

    /// Collapsed-mode frame: sits directly under the notch region
    /// on the preferred screen, centered on its horizontal midline.
    /// Phase 8.3 will add an `expandedFrame(for:)` counterpart on
    /// top of the same anchoring math.
    private func collapsedFrame(for screen: NSScreen) -> NSRect {
        // The collapsed panel matches the notch rect width + a
        // small vertical height so the hosted SwiftUI pill can
        // render "inside" the notch on MacBook Pro displays.
        let notch = AgentNotchScreenDetector.notchFrame(for: screen)
        // The notch rect's .minY already sits at
        // `screen.frame.maxY - topBarHeight`. Place the panel so
        // its top edge aligns with the screen top edge and its
        // height matches topBarHeight, mirroring the visual
        // behavior CodeIsland ships.
        return notch
    }

    // MARK: - Screen observer

    private func attachScreenObserverIfNeeded() {
        guard screenParamObserver == nil else { return }
        screenParamObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionForCurrentScreen(animated: true)
            }
        }
    }

    private func detachScreenObserver() {
        if let token = screenParamObserver {
            NotificationCenter.default.removeObserver(token)
            screenParamObserver = nil
        }
    }
}
