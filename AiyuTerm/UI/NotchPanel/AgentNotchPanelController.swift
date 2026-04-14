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
import Foundation
import os.log
import SwiftUI

// MARK: - Collapse request notification

extension Notification.Name {
    /// Phase 11.3D.b: posted by the controller when the mouse
    /// leaves the panel's tracking area and
    /// `AgentNotchDisplayOptions.collapseOnMouseLeave == true`. The
    /// SwiftUI view layer can observe this to collapse the expanded
    /// card without the controller touching view state directly.
    static let agentNotchPanelCollapseRequested = Notification.Name(
        "AgentNotchPanelCollapseRequested"
    )
}

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

    // Explicit deinit works around a Swift 6.2 compiler crash in the
    // EarlyPerfInliner pass on the auto-generated deinit of generic
    // NSHostingView subclasses (rdar://FB16XXXXXX).
    deinit {}

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
    private var fullscreenEnterObserver: NSObjectProtocol?
    private var fullscreenExitObserver: NSObjectProtocol?

    /// Cached signature of the screen currently hosting the panel.
    /// Used to skip no-op repositions when screen parameters fire
    /// without actually changing the preferred screen (e.g. a
    /// brightness adjustment).
    private var lastChosenScreenSignature: String = ""

    // Phase 11.3D.b: reactive display options.
    //
    // `lastDisplayOptions` holds the settings pushed from the
    // store so `setDisplayOptions` can detect changes and attach or
    // detach tracking areas without thrashing AppKit resources.
    //
    // `lastAggregatedStatus` / `lastPendingCount` let the
    // controller re-evaluate `hideWhenNoSession` on both setting
    // changes AND state refreshes.
    //
    // `isHiddenByDisplayOptions` is `true` when the panel has been
    // ordered out by a display-options rule (fullscreen / no-
    // session). Distinct from `hide()` which is the full-
    // lifecycle teardown.
    private var lastDisplayOptions: AgentNotchDisplayOptions = .default
    private var lastAggregatedStatus: AgentSessionStatus = .none
    private var lastPendingCount: Int = 0
    private var isHiddenByDisplayOptions: Bool = false
    // Phase 11.6.2 / P11.0.3 fix: the mouse-exit tracker is now a
    // private NSView subclass (`NotchMouseTrackerView`) added as a
    // subview of `hostingView` so we can react to exits without
    // making the controller inherit from NSResponder.
    private var mouseTracker: NotchMouseTrackerView?

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
        detachFullscreenObservers()
        removeTrackingArea()
        lastChosenScreenSignature = ""
        isHiddenByDisplayOptions = false
    }

    /// Phase 11.3D.b: push new display options + current aggregated
    /// state into the controller. The caller (WorkspaceStore)
    /// invokes this from `refreshNotchPanelState()` so the three
    /// reactive knobs — `hideInFullscreen`, `collapseOnMouseLeave`,
    /// `hideWhenNoSession` — take effect without requiring a
    /// restart.
    ///
    /// This method is idempotent: calling it with the same options
    /// is a no-op apart from the `hideWhenNoSession` re-evaluation
    /// which always runs because the aggregated state may have
    /// changed independently of the options.
    func setDisplayOptions(
        _ options: AgentNotchDisplayOptions,
        aggregatedStatus: AgentSessionStatus,
        pendingCount: Int
    ) {
        let optionsChanged = options != lastDisplayOptions
        lastDisplayOptions = options
        lastAggregatedStatus = aggregatedStatus
        lastPendingCount = pendingCount

        // Fullscreen observer attach/detach must only run when
        // `hideInFullscreen` actually changes so we don't churn
        // NotificationCenter registrations on every state push.
        if optionsChanged {
            if options.hideInFullscreen {
                attachFullscreenObserversIfNeeded()
            } else {
                detachFullscreenObservers()
                if isHiddenByDisplayOptions, panel != nil {
                    panel?.orderFrontRegardless()
                    isHiddenByDisplayOptions = false
                }
            }
            if options.collapseOnMouseLeave {
                installTrackingAreaIfNeeded()
            } else {
                removeTrackingArea()
            }
        }

        applyVisibilityRules()
    }

    /// Exposed for tests: the last display options pushed into the
    /// controller via `setDisplayOptions(_:aggregatedStatus:pendingCount:)`.
    var currentDisplayOptions: AgentNotchDisplayOptions {
        lastDisplayOptions
    }

    /// Exposed for tests: `true` when the panel has been ordered
    /// out by a display-options rule (fullscreen / no-session).
    var isHiddenByDisplayOptionsForTests: Bool {
        isHiddenByDisplayOptions
    }

    /// Exposed for tests: `true` when a mouse-exit tracker view
    /// has been installed on the hosting view for mouse-leave
    /// detection.
    var hasMouseLeaveTrackingAreaForTests: Bool {
        mouseTracker != nil
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

    // MARK: - Phase 11.3D.b: reactive visibility

    /// Evaluate the three display-option rules against the current
    /// state and show/hide the panel accordingly. Order matters:
    ///
    ///   1. `hideInFullscreen` wins if any app is fullscreen on the
    ///      preferred screen. Nothing else matters while fullscreen
    ///      is active.
    ///   2. `hideWhenNoSession` hides the collapsed pill if the
    ///      aggregated state is idle AND no pending permission/
    ///      question exists.
    ///   3. Otherwise the panel is visible.
    private func applyVisibilityRules() {
        guard let panel else { return }

        let shouldHideForFullscreen = lastDisplayOptions.hideInFullscreen
            && Self.isAnyScreenInFullscreen()

        let shouldHideForNoSession = lastDisplayOptions.hideWhenNoSession
            && lastAggregatedStatus == .none
            && lastPendingCount == 0

        let shouldHide = shouldHideForFullscreen || shouldHideForNoSession

        if shouldHide {
            if panel.isVisible {
                panel.orderOut(nil)
            }
            isHiddenByDisplayOptions = true
        } else if isHiddenByDisplayOptions {
            panel.orderFrontRegardless()
            isHiddenByDisplayOptions = false
        }
    }

    // MARK: - Fullscreen detection

    /// Heuristic: on macOS, when any app is in fullscreen mode on
    /// the main screen, the menu bar auto-hides and the visible
    /// frame becomes equal to the full frame. This is cheaper and
    /// more reliable than walking the window list.
    static func isAnyScreenInFullscreen() -> Bool {
        guard let main = NSScreen.main else { return false }
        // When the menu bar is hidden, visibleFrame.height equals
        // frame.height (minus a dock if docked on the side/bottom).
        // We just compare the TOP edge: if visibleFrame.maxY ==
        // frame.maxY (no menu bar gap), someone's in fullscreen.
        return abs(main.visibleFrame.maxY - main.frame.maxY) < 0.5
    }

    private func attachFullscreenObserversIfNeeded() {
        if fullscreenEnterObserver == nil {
            fullscreenEnterObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyVisibilityRules()
                }
            }
        }
        if fullscreenExitObserver == nil {
            fullscreenExitObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyVisibilityRules()
                }
            }
        }
    }

    private func detachFullscreenObservers() {
        if let token = fullscreenEnterObserver {
            NotificationCenter.default.removeObserver(token)
            fullscreenEnterObserver = nil
        }
        if let token = fullscreenExitObserver {
            NotificationCenter.default.removeObserver(token)
            fullscreenExitObserver = nil
        }
    }

    // MARK: - Mouse-leave tracking

    /// Install an `NSTrackingArea` on the panel's content view so
    /// we get a `mouseExited(with:)` callback when the pointer
    /// leaves. The callback posts
    /// `agentNotchPanelCollapseRequested`, which the view layer
    /// consumes to collapse an expanded card (wired in a later
    /// phase).
    ///
    /// Note: `AgentNotchPanelController` inherits from `NSObject`,
    /// not `NSResponder`, so it cannot override `mouseExited`
    /// itself. Instead, we install a private `NSView` subclass
    /// (`NotchMouseTrackerView`, defined below) that owns the
    /// tracking area and forwards the exit event via a closure.
    private func installTrackingAreaIfNeeded() {
        guard mouseTracker == nil, let hostingView else { return }
        let tracker = NotchMouseTrackerView(frame: hostingView.bounds)
        tracker.autoresizingMask = [.width, .height]
        tracker.onMouseExited = { [weak self] in
            guard let self,
                  self.lastDisplayOptions.collapseOnMouseLeave else { return }
            self.postCollapseRequestNotification()
        }
        hostingView.addSubview(tracker, positioned: .below, relativeTo: nil)
        mouseTracker = tracker
    }

    private func removeTrackingArea() {
        mouseTracker?.removeFromSuperview()
        mouseTracker = nil
    }

    /// Exposed so tests can drive the collapse request path
    /// without synthesizing an NSEvent.
    func handleMouseExitedForTests() {
        if lastDisplayOptions.collapseOnMouseLeave {
            postCollapseRequestNotification()
        }
    }

    private func postCollapseRequestNotification() {
        NotificationCenter.default.post(
            name: .agentNotchPanelCollapseRequested,
            object: self
        )
    }
}

/// Private NSView subclass that owns the tracking area for the
/// notch panel. Added to the hosting view as a transparent
/// sibling below the SwiftUI content so it doesn't intercept
/// clicks — it only exists to deliver `mouseExited` events to
/// the controller via `onMouseExited`.
private final class NotchMouseTrackerView: NSView {
    var onMouseExited: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExited?()
    }

    // Make the tracker transparent to clicks so the actual
    // SwiftUI hosting view keeps receiving them.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
