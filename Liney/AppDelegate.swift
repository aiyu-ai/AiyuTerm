//
//  AppDelegate.swift
//  Liney
//
//  Author: wuwenrui
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    @MainActor private var desktopApplication: LineyDesktopApplication?
    @MainActor private let applicationMenuController = ApplicationMenuController()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Task { @MainActor in
            applicationMenuController.installMainMenu(appName: applicationName(), target: self)
            let desktopApplication = LineyDesktopApplication()
            self.desktopApplication = desktopApplication
            desktopApplication.launch()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func openSettings(_ sender: Any?) {
        Task { @MainActor in
            desktopApplication?.presentSettings()
        }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        Task { @MainActor in
            desktopApplication?.checkForUpdates()
        }
    }

    @objc func toggleCommandPalette(_ sender: Any?) {
        Task { @MainActor in
            desktopApplication?.toggleCommandPalette()
        }
    }

    @objc func newTab(_ sender: Any?) {
        Task { @MainActor in
            desktopApplication?.createTabInSelectedWorkspace()
        }
    }

    @objc func selectNextTab(_ sender: Any?) {
        Task { @MainActor in
            desktopApplication?.selectNextTab()
        }
    }

    @objc func selectPreviousTab(_ sender: Any?) {
        Task { @MainActor in
            desktopApplication?.selectPreviousTab()
        }
    }

    @objc func selectTabNumber(_ sender: NSMenuItem) {
        Task { @MainActor in
            desktopApplication?.selectTab(number: sender.tag)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let desktopApplication else { return false }

        switch menuItem.action {
        case #selector(newTab(_:)):
            return desktopApplication.hasSelectedWorkspace
        case #selector(selectNextTab(_:)), #selector(selectPreviousTab(_:)):
            return desktopApplication.selectedWorkspaceTabCount > 1
        case #selector(selectTabNumber(_:)):
            return menuItem.tag >= 1 && menuItem.tag <= desktopApplication.selectedWorkspaceTabCount
        default:
            return true
        }
    }

    @MainActor
    private func applicationName() -> String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return "Liney"
    }
}
