//
//  LineyDesktopApplication.swift
//  Liney
//
//  Author: wuwenrui
//

import AppKit
import SwiftUI

@MainActor
public final class LineyDesktopApplication: NSObject {
    private let store = WorkspaceStore()
    private var windowController: NSWindowController?

    public override init() {
        super.init()
    }

    public func launch() {
        LineyGhosttyBootstrap.initialize()
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        NSWindow.allowsAutomaticWindowTabbing = false

        if windowController == nil {
            let host = NSHostingController(
                rootView: MainWindowView()
                    .environmentObject(store)
                    .preferredColorScheme(.dark)
            )

            let window = NSWindow(contentViewController: host)
            window.title = "Liney"
            window.setContentSize(NSSize(width: 1440, height: 920))
            window.minSize = NSSize(width: 1120, height: 720)
            window.center()
            window.isOpaque = false
            window.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.06, blue: 0.075, alpha: 1)
            window.styleMask.remove(.fullSizeContentView)
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.toolbarStyle = .unifiedCompact
            window.tabbingMode = .disallowed
            window.isMovableByWindowBackground = false

            let controller = NSWindowController(window: window)
            controller.shouldCascadeWindows = true
            windowController = controller
        }

        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()

        Task { @MainActor in
            await store.loadIfNeeded()
        }
    }

    public func toggleCommandPalette() {
        store.dispatch(.toggleCommandPalette)
    }

    public func presentSettings() {
        store.presentSettings(for: store.selectedWorkspace)
    }

    public func checkForUpdates() {
        store.dispatch(.checkForUpdates)
    }

    public func createTabInSelectedWorkspace() {
        guard let workspace = store.selectedWorkspace else { return }
        store.createTab(in: workspace)
    }

    public func selectTab(number: Int) {
        guard (1...9).contains(number),
              let workspace = store.selectedWorkspace else { return }
        store.selectTab(in: workspace, index: number - 1)
    }

    public func selectNextTab() {
        guard let workspace = store.selectedWorkspace else { return }
        store.selectNextTab(in: workspace)
    }

    public func selectPreviousTab() {
        guard let workspace = store.selectedWorkspace else { return }
        store.selectPreviousTab(in: workspace)
    }

    public var hasSelectedWorkspace: Bool {
        store.selectedWorkspace != nil
    }

    public var selectedWorkspaceTabCount: Int {
        store.selectedWorkspace?.tabs.count ?? 0
    }
}
