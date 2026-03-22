//
//  AppDelegate.swift
//  Liney
//
//  Author: wuwenrui
//

import Cocoa
import Sentry

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let websiteURL = URL(string: "https://liney.dev")!
    private let repositoryURL = URL(string: "https://github.com/wuwenrui/liney")!

    @MainActor private var desktopApplication: LineyDesktopApplication?
    @MainActor private let applicationMenuController = ApplicationMenuController()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        
        SentrySDK.start { options in
            options.dsn = "https://d2856035f52ef60d4ae74f88e0194793@o4510180697636864.ingest.us.sentry.io/4511085450297344"
            options.debug = true // Enabling debug when first installing is always helpful

            // Adds IP for users.
            // For more information, visit: https://docs.sentry.io/platforms/apple/data-management/data-collected/
            options.sendDefaultPii = true
        }
        
        Task { @MainActor in
            applicationMenuController.installMainMenu(appName: applicationName(), target: self)
            let desktopApplication = LineyDesktopApplication()
            self.desktopApplication = desktopApplication
            desktopApplication.launch()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
            desktopApplication?.shutdown()
        }
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

    @objc func showAboutPanel(_ sender: Any?) {
        let appName = applicationName()
        let aboutOptions: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: appName,
            .applicationVersion: formattedApplicationVersion(),
            .credits: aboutCredits(),
        ]
        NSApp.orderFrontStandardAboutPanel(options: aboutOptions)
        NSApp.activate(ignoringOtherApps: true)
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

    @MainActor
    private func formattedApplicationVersion() -> String {
        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch (shortVersion?.isEmpty == false ? shortVersion : nil, buildVersion?.isEmpty == false ? buildVersion : nil) {
        case let (shortVersion?, buildVersion?) where shortVersion != buildVersion:
            return "Version \(shortVersion) (\(buildVersion))"
        case let (shortVersion?, _):
            return "Version \(shortVersion)"
        case let (_, buildVersion?):
            return "Build \(buildVersion)"
        default:
            return "Version 1.0.0"
        }
    }

    @MainActor
    private func aboutCredits() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 6

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .paragraphStyle: paragraphStyle,
        ]
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .paragraphStyle: paragraphStyle,
            .link: websiteURL,
        ]

        let credits = NSMutableAttributedString(
            string: "Native macOS terminal workspace.\n\n",
            attributes: baseAttributes
        )
        credits.append(
            NSAttributedString(
                string: "Website: \(websiteURL.absoluteString)\n",
                attributes: linkAttributes.merging([.link: websiteURL]) { _, newValue in newValue }
            )
        )
        credits.append(
            NSAttributedString(
                string: "GitHub: \(repositoryURL.absoluteString)",
                attributes: linkAttributes.merging([.link: repositoryURL]) { _, newValue in newValue }
            )
        )
        return credits
    }
}
