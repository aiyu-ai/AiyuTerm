//
// AgentStatusItemController.swift
// AiyuTerm
//
// Phase 11.3D.a: menu bar status item that mirrors the notch panel
// aggregated agent state.
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/StatusItemController.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Design rules:
//   • The controller owns a single `NSStatusItem` that lives for as
//     long as the notch panel is enabled. `WorkspaceStore` creates
//     it in `showNotchPanel()` and tears it down in
//     `hideNotchPanel()`, mirroring the panel lifecycle exactly.
//   • Left-click on the button toggles the notch panel via the
//     `onTogglePanel` closure injected at init time. The closure is
//     always called on the main actor.
//   • Right-click (or long-press) opens a context menu with three
//     items: Show Notch Panel, Export Diagnostics, Quit.
//   • The button icon + tooltip reflect the current aggregated
//     `AgentSessionStatus` plus the pending permission/question
//     count. `WorkspaceStore.refreshNotchPanelState()` forwards the
//     same aggregated state here via `update(status:pendingCount:)`.
//
// The controller is explicitly NOT a singleton: tests instantiate
// their own copies and verify `tearDown()` removes the status item
// from the system status bar. `WorkspaceStore` keeps a single
// instance per window context.
//

import AppKit

@MainActor
final class AgentStatusItemController: NSObject {

    // MARK: - Injection

    private let onTogglePanel: () -> Void
    private let onExportDiagnostics: () -> Void

    // MARK: - State

    private var statusItem: NSStatusItem?
    private var currentStatus: AgentSessionStatus = .none
    private var currentPendingCount: Int = 0

    // MARK: - Init

    init(
        onTogglePanel: @escaping () -> Void,
        onExportDiagnostics: @escaping () -> Void
    ) {
        self.onTogglePanel = onTogglePanel
        self.onExportDiagnostics = onExportDiagnostics
        super.init()
        installStatusItem()
    }

    deinit {
        // Do not touch MainActor-isolated state from deinit. Callers
        // must call tearDown() before releasing the last reference.
    }

    // MARK: - Public API

    /// True when the `NSStatusItem` has been created and is visible
    /// in the system status bar. Tests rely on this.
    var isInstalled: Bool {
        statusItem != nil
    }

    /// Apply a new aggregated agent state to the status bar icon +
    /// tooltip. Idempotent: no-op when nothing has changed.
    func update(status: AgentSessionStatus, pendingCount: Int) {
        let normalizedPending = max(0, pendingCount)
        if status == currentStatus, normalizedPending == currentPendingCount {
            return
        }
        currentStatus = status
        currentPendingCount = normalizedPending
        applyIconAndTooltip()
    }

    /// Remove the status item from the menu bar. After this call
    /// `isInstalled` is false and the controller can be released.
    func tearDown() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // MARK: - Installation

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imageScaling = .scaleProportionallyDown
        }
        statusItem = item
        applyIconAndTooltip()
    }

    // MARK: - Icon + tooltip

    private func applyIconAndTooltip() {
        guard let button = statusItem?.button else { return }
        let (symbolName, accessibility) = iconDescriptor()
        if let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibility
        ) {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        }
        button.toolTip = tooltipText()
    }

    /// Map aggregated state → SF Symbol + a11y label. Mirrors the
    /// sidebar badge semantics:
    ///   • permissionNeeded → key.fill (alert)
    ///   • working           → hourglass (progress)
    ///   • taskCompleted     → checkmark.circle.fill
    ///   • error             → exclamationmark.triangle.fill
    ///   • none              → circle (idle)
    private func iconDescriptor() -> (String, String) {
        if currentPendingCount > 0 || currentStatus == .permissionNeeded {
            return ("key.fill", "Agent needs permission")
        }
        switch currentStatus {
        case .working:
            return ("hourglass", "Agent working")
        case .taskCompleted:
            return ("checkmark.circle.fill", "Agent task complete")
        case .error:
            return ("exclamationmark.triangle.fill", "Agent error")
        case .permissionNeeded:
            return ("key.fill", "Agent needs permission")
        case .none:
            return ("circle", "AiyuTerm")
        }
    }

    private func tooltipText() -> String {
        let base = "AiyuTerm"
        switch currentStatus {
        case .none where currentPendingCount == 0:
            return base
        case .working:
            return "\(base) — working"
        case .permissionNeeded:
            return "\(base) — \(currentPendingCount) pending permission"
        case .taskCompleted:
            return "\(base) — task complete"
        case .error:
            return "\(base) — error"
        case .none:
            return "\(base) — \(currentPendingCount) pending"
        }
    }

    // MARK: - Click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onTogglePanel()
            return
        }
        switch event.type {
        case .rightMouseUp:
            presentContextMenu()
        case .leftMouseUp where event.modifierFlags.contains(.control):
            presentContextMenu()
        default:
            onTogglePanel()
        }
    }

    private func presentContextMenu() {
        guard let item = statusItem else { return }
        let menu = makeMenu()
        item.menu = menu
        // popUpMenu requires the menu to be attached for the click,
        // then cleared so the next left click toggles the panel
        // instead of re-opening the menu.
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let showTitle = LocalizationManager.shared.string("menu.statusItem.showNotchPanel")
        let showItem = NSMenuItem(
            title: showTitle,
            action: #selector(showNotchPanelMenuAction),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let exportTitle = LocalizationManager.shared.string("menu.help.exportAgentDiagnostics")
        let exportItem = NSMenuItem(
            title: exportTitle,
            action: #selector(exportDiagnosticsMenuAction),
            keyEquivalent: ""
        )
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(.separator())

        let quitTitle = LocalizationManager.shared.string("menu.statusItem.quit")
        let quitItem = NSMenuItem(
            title: quitTitle,
            action: #selector(quitAppMenuAction),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func showNotchPanelMenuAction() {
        onTogglePanel()
    }

    @objc private func exportDiagnosticsMenuAction() {
        onExportDiagnostics()
    }

    @objc private func quitAppMenuAction() {
        NSApp.terminate(nil)
    }
}
