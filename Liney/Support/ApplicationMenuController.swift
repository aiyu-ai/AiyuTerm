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

    private var shortcutItemsByAction: [LineyShortcutAction: [NSMenuItem]] = [:]

    private func localized(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        l10nFormat(localized(key), locale: Locale.current, arguments: arguments)
    }

    func installMainMenu(appName: String, target: AnyObject, settings: AppSettings) {
        shortcutItemsByAction = [:]

        let mainMenu = NSMenu(title: "")

        let appMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        let fileMenuItem = NSMenuItem(title: localized("menu.file"), action: nil, keyEquivalent: "")
        let editMenuItem = NSMenuItem(title: localized("menu.edit"), action: nil, keyEquivalent: "")
        let viewMenuItem = NSMenuItem(title: localized("menu.view"), action: nil, keyEquivalent: "")
        let workspaceMenuItem = NSMenuItem(title: localized("menu.workspace"), action: nil, keyEquivalent: "")
        let windowMenuItem = NSMenuItem(title: localized("menu.window"), action: nil, keyEquivalent: "")
        let helpMenuItem = NSMenuItem(title: localized("menu.help"), action: nil, keyEquivalent: "")

        mainMenu.items = [
            appMenuItem,
            fileMenuItem,
            editMenuItem,
            viewMenuItem,
            workspaceMenuItem,
            windowMenuItem,
            helpMenuItem,
        ]

        let appMenu = NSMenu(title: appName)
        appMenuItem.submenu = appMenu
        let aboutItem = addItem(
            title: localizedFormat("menu.app.aboutFormat", appName),
            action: #selector(AppDelegate.showAboutPanel(_:)),
            keyEquivalent: "",
            to: appMenu
        )
        aboutItem.target = target
        let checkForUpdatesItem = addItem(
            title: localized("menu.app.checkForUpdates"),
            action: #selector(AppDelegate.checkForUpdates(_:)),
            keyEquivalent: "",
            to: appMenu
        )
        checkForUpdatesItem.target = target
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: localized("menu.app.services"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: localized("menu.app.services"))
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())
        addItem(
            title: localizedFormat("menu.app.hideFormat", appName),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h",
            to: appMenu
        )

        let hideOthersItem = addItem(
            title: localized("menu.app.hideOthers"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h",
            to: appMenu
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]

        addItem(title: localized("menu.app.showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "", to: appMenu)
        appMenu.addItem(.separator())
        addShortcutItem(title: localized("menu.app.settings"), shortcutAction: .openSettings, to: appMenu, target: target)
        appMenu.addItem(.separator())
        addItem(
            title: localizedFormat("menu.app.quitFormat", appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q",
            to: appMenu
        )

        let fileMenu = NSMenu(title: localized("menu.file"))
        fileMenuItem.submenu = fileMenu
        addShortcutItem(title: localized("menu.file.newWindow"), shortcutAction: .newWindow, to: fileMenu, target: target)
        addShortcutItem(title: localized("menu.file.newTab"), shortcutAction: .newTab, to: fileMenu, target: target)
        fileMenu.addItem(.separator())
        addShortcutItem(title: localized("menu.file.splitRight"), shortcutAction: .splitRight, to: fileMenu, target: target)
        addShortcutItem(title: localized("menu.file.splitDown"), shortcutAction: .splitDown, to: fileMenu, target: target)
        addShortcutItem(title: localized("menu.file.duplicatePane"), shortcutAction: .duplicatePane, to: fileMenu, target: target)
        fileMenu.addItem(.separator())
        addShortcutItem(title: localized("menu.file.closeTab"), shortcutAction: .closeTab, to: fileMenu, target: target)
        addShortcutItem(title: localized("menu.file.closePane"), shortcutAction: .closePane, to: fileMenu, target: target)

        let editMenu = NSMenu(title: localized("menu.edit"))
        editMenuItem.submenu = editMenu
        addItem(title: localized("menu.edit.undo"), action: Selector(("undo:")), keyEquivalent: "z", to: editMenu)

        let redoItem = addItem(title: localized("menu.edit.redo"), action: Selector(("redo:")), keyEquivalent: "Z", to: editMenu)
        redoItem.keyEquivalentModifierMask = [.command, .shift]

        editMenu.addItem(.separator())
        addItem(title: localized("menu.edit.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x", to: editMenu)
        addItem(title: localized("menu.edit.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c", to: editMenu)
        addItem(title: localized("menu.edit.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v", to: editMenu)
        addItem(title: localized("menu.edit.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a", to: editMenu)
        editMenu.addItem(.separator())
        addItem(title: localized("menu.edit.find"), action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f", to: editMenu).tag = NSTextFinder.Action.showFindInterface.rawValue
        let findNextItem = addItem(title: localized("menu.edit.findNext"), action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "g", to: editMenu)
        findNextItem.tag = NSTextFinder.Action.nextMatch.rawValue
        let findPreviousItem = addItem(title: localized("menu.edit.findPrevious"), action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "G", to: editMenu)
        findPreviousItem.keyEquivalentModifierMask = [.command, .shift]
        findPreviousItem.tag = NSTextFinder.Action.previousMatch.rawValue
        addItem(title: localized("menu.edit.hideFind"), action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "e", to: editMenu).tag = NSTextFinder.Action.hideFindInterface.rawValue

        let viewMenu = NSMenu(title: localized("menu.view"))
        viewMenuItem.submenu = viewMenu
        addShortcutItem(title: localized("menu.view.toggleSidebar"), shortcutAction: .toggleSidebar, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.commandPalette"), shortcutAction: .toggleCommandPalette, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.workspaceOverview"), shortcutAction: .toggleOverview, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.openDiff"), shortcutAction: .openDiff, to: viewMenu, target: target)
        viewMenu.addItem(.separator())
        addShortcutItem(title: localized("menu.view.nextTab"), shortcutAction: .nextTab, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.previousTab"), shortcutAction: .previousTab, to: viewMenu, target: target)
        for index in 1...9 {
            let item = addShortcutItem(
                title: localizedFormat("menu.view.selectTabFormat", index),
                shortcutAction: .selectTabByNumber,
                to: viewMenu,
                target: target
            )
            item.tag = index
        }
        viewMenu.addItem(.separator())
        addShortcutItem(title: localized("menu.view.focusPaneLeft"), shortcutAction: .focusPaneLeft, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.focusPaneRight"), shortcutAction: .focusPaneRight, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.focusPaneUp"), shortcutAction: .focusPaneUp, to: viewMenu, target: target)
        addShortcutItem(title: localized("menu.view.focusPaneDown"), shortcutAction: .focusPaneDown, to: viewMenu, target: target)
        viewMenu.addItem(.separator())
        addShortcutItem(title: localized("menu.view.enterFullScreen"), shortcutAction: .enterFullScreen, to: viewMenu, target: target)

        let workspaceMenu = NSMenu(title: localized("menu.workspace"))
        workspaceMenuItem.submenu = workspaceMenu
        addShortcutItem(title: localized("menu.workspace.refreshSelected"), shortcutAction: .refreshSelectedWorkspace, to: workspaceMenu, target: target)
        addShortcutItem(title: localized("menu.workspace.refreshAll"), shortcutAction: .refreshAllRepositories, to: workspaceMenu, target: target)

        let windowMenu = NSMenu(title: localized("menu.window"))
        windowMenuItem.submenu = windowMenu
        addItem(title: localized("menu.window.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m", to: windowMenu)
        addItem(title: localized("menu.window.zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "", to: windowMenu)
        addShortcutItem(title: localized("menu.window.closeWindow"), shortcutAction: .closeWindow, to: windowMenu, target: target)
        windowMenu.addItem(.separator())
        addItem(title: localized("menu.window.showTabBar"), action: #selector(NSWindow.toggleTabBar(_:)), keyEquivalent: "", to: windowMenu)
        addItem(title: localized("menu.window.moveTabToNewWindow"), action: #selector(NSWindow.moveTabToNewWindow(_:)), keyEquivalent: "", to: windowMenu)
        addItem(title: localized("menu.window.mergeAllWindows"), action: #selector(NSWindow.mergeAllWindows(_:)), keyEquivalent: "", to: windowMenu)
        windowMenu.addItem(.separator())
        addItem(title: localized("menu.window.bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "", to: windowMenu)
        NSApp.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: localized("menu.help"))
        helpMenuItem.submenu = helpMenu
        addItem(title: localized("menu.help.visitWebsite"), action: #selector(openWebsite(_:)), keyEquivalent: "", to: helpMenu)
        addItem(title: localized("menu.help.starSourceCode"), action: #selector(openRepository(_:)), keyEquivalent: "", to: helpMenu)
        addItem(title: localized("menu.help.submitFeedback"), action: #selector(submitFeedback(_:)), keyEquivalent: "", to: helpMenu)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
        applySettings(settings)
    }

    func applySettings(_ settings: AppSettings) {
        for action in LineyShortcutAction.allCases {
            guard let items = shortcutItemsByAction[action] else { continue }

            if action == .selectTabByNumber {
                let shortcut = LineyKeyboardShortcuts.effectiveShortcut(for: action, in: settings)
                for item in items {
                    guard let shortcut else {
                        clearShortcut(on: item)
                        continue
                    }
                    applyShortcut(shortcut.withKey("\(item.tag)"), to: item)
                }
                continue
            }

            let shortcut = LineyKeyboardShortcuts.effectiveShortcut(for: action, in: settings)
            for item in items {
                guard let shortcut else {
                    clearShortcut(on: item)
                    continue
                }
                applyShortcut(shortcut, to: item)
            }
        }
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

    @discardableResult
    private func addShortcutItem(
        title: String,
        shortcutAction: LineyShortcutAction,
        to menu: NSMenu,
        target: AnyObject
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(AppDelegate.performShortcutAction(_:)), keyEquivalent: "")
        item.target = target
        item.representedObject = shortcutAction.rawValue
        menu.addItem(item)
        shortcutItemsByAction[shortcutAction, default: []].append(item)
        return item
    }

    private func applyShortcut(_ shortcut: StoredShortcut, to item: NSMenuItem) {
        guard let keyEquivalent = shortcut.menuItemKeyEquivalent else {
            clearShortcut(on: item)
            return
        }
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = shortcut.modifierFlags
    }

    private func clearShortcut(on item: NSMenuItem) {
        item.keyEquivalent = ""
        item.keyEquivalentModifierMask = []
    }
}
