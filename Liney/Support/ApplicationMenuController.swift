//
//  ApplicationMenuController.swift
//  Liney
//
//  Author: wuwenrui
//

import AppKit

@MainActor
final class ApplicationMenuController: NSObject {
    private let websiteURL = URL(string: "https://liney.dev")!
    private let feedbackURL = URL(string: "https://github.com/wuwenrui/liney/issues/new")!
    private let repositoryURL = URL(string: "https://github.com/wuwenrui/liney")!

    func installMainMenu(appName: String, target: AnyObject) {
        let mainMenu = NSMenu(title: "")

        let appMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")

        mainMenu.items = [
            appMenuItem,
            fileMenuItem,
            editMenuItem,
            viewMenuItem,
            windowMenuItem,
            helpMenuItem,
        ]

        let appMenu = NSMenu(title: appName)
        appMenuItem.submenu = appMenu
        let aboutItem = addItem(title: "About \(appName)", action: #selector(AppDelegate.showAboutPanel(_:)), keyEquivalent: "", to: appMenu)
        aboutItem.target = target
        let checkForUpdatesItem = addItem(title: "Check for Updates...", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "", to: appMenu)
        checkForUpdatesItem.target = target
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())
        addItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h", to: appMenu)

        let hideOthersItem = addItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h",
            to: appMenu
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]

        addItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "", to: appMenu)
        appMenu.addItem(.separator())
        let settingsItem = addItem(title: "Settings...", action: #selector(AppDelegate.openSettings(_:)), keyEquivalent: ",", to: appMenu)
        settingsItem.target = target
        appMenu.addItem(.separator())
        addItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q", to: appMenu)

        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        let newTabItem = addItem(title: "New Tab", action: #selector(AppDelegate.newTab(_:)), keyEquivalent: "t", to: fileMenu)
        newTabItem.target = target
        fileMenu.addItem(.separator())
        addItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w", to: fileMenu)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        addItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z", to: editMenu)

        let redoItem = addItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z", to: editMenu)
        redoItem.keyEquivalentModifierMask = [.command, .shift]

        editMenu.addItem(.separator())
        addItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x", to: editMenu)
        addItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c", to: editMenu)
        addItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v", to: editMenu)
        addItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a", to: editMenu)
        editMenu.addItem(.separator())
        addItem(title: "Find", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f", to: editMenu).tag = NSTextFinder.Action.showFindInterface.rawValue
        let findNextItem = addItem(title: "Find Next", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "g", to: editMenu)
        findNextItem.tag = NSTextFinder.Action.nextMatch.rawValue
        let findPreviousItem = addItem(title: "Find Previous", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "G", to: editMenu)
        findPreviousItem.keyEquivalentModifierMask = [.command, .shift]
        findPreviousItem.tag = NSTextFinder.Action.previousMatch.rawValue
        addItem(title: "Hide Find", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "e", to: editMenu).tag = NSTextFinder.Action.hideFindInterface.rawValue

        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        let commandPaletteItem = addItem(title: "Command Palette", action: #selector(AppDelegate.toggleCommandPalette(_:)), keyEquivalent: "p", to: viewMenu)
        commandPaletteItem.target = target
        let nextTabItem = addItem(title: "Next Tab", action: #selector(AppDelegate.selectNextTab(_:)), keyEquivalent: "]", to: viewMenu)
        nextTabItem.target = target
        let previousTabItem = addItem(title: "Previous Tab", action: #selector(AppDelegate.selectPreviousTab(_:)), keyEquivalent: "[", to: viewMenu)
        previousTabItem.target = target
        viewMenu.addItem(.separator())
        for index in 1...9 {
            let item = addItem(
                title: "Select Tab \(index)",
                action: #selector(AppDelegate.selectTabNumber(_:)),
                keyEquivalent: "\(index)",
                to: viewMenu
            )
            item.target = target
            item.tag = index
        }
        viewMenu.addItem(.separator())
        let fullScreenItem = addItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f", to: viewMenu)
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        addItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m", to: windowMenu)
        addItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "", to: windowMenu)
        windowMenu.addItem(.separator())
        addItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "", to: windowMenu)
        NSApp.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        addItem(title: "Visit liney.dev", action: #selector(openWebsite(_:)), keyEquivalent: "", to: helpMenu)
        addItem(title: "Star Source Code", action: #selector(openRepository(_:)), keyEquivalent: "", to: helpMenu)
        addItem(title: "Submit Feedback", action: #selector(submitFeedback(_:)), keyEquivalent: "", to: helpMenu)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func openWebsite(_ sender: Any?) {
        NSWorkspace.shared.open(websiteURL)
    }

    @objc private func submitFeedback(_ sender: Any?) {
        NSWorkspace.shared.open(feedbackURL)
    }

    @objc private func openRepository(_ sender: Any?) {
        NSWorkspace.shared.open(repositoryURL)
    }

    @discardableResult
    private func addItem(title: String, action: Selector?, keyEquivalent: String, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        if action == #selector(openWebsite(_:)) || action == #selector(submitFeedback(_:)) || action == #selector(openRepository(_:)) {
            item.target = self
        }
        menu.addItem(item)
        return item
    }
}
