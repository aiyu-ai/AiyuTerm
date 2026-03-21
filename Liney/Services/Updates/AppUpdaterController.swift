//
//  AppUpdaterController.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation
import Sparkle

@MainActor
private final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var updateChannel: ReleaseChannel = .stable

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        AppUpdaterController.feedURL.absoluteString
    }

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        MainActor.assumeIsolated {
            switch updateChannel {
            case .stable:
                return []
            case .preview:
                return ["preview"]
            }
        }
    }
}

@MainActor
final class AppUpdaterController {
    static let repository = "wuwenrui/liney"
    static let releasesURL = URL(string: "https://github.com/\(repository)/releases")!
    static let feedURL = URL(string: "https://raw.githubusercontent.com/\(repository)/main/appcast.xml")!
    static let sparkleKeyAccount = "liney"
    static let defaultPrivateKeyPath: String = {
        let releaseHome = ProcessInfo.processInfo.environment["LINEY_RELEASE_HOME"] ?? "\(NSHomeDirectory())/.liney_release"
        return "\(releaseHome)/sparkle_private_key"
    }()

    private let delegate = SparkleUpdaterDelegate()
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: delegate,
        userDriverDelegate: nil
    )

    func configure(
        updateChannel: ReleaseChannel,
        automaticallyChecks: Bool,
        automaticallyDownloads: Bool,
        checkInBackground: Bool
    ) {
        let updater = controller.updater
        delegate.updateChannel = updateChannel
        updater.automaticallyChecksForUpdates = automaticallyChecks
        updater.automaticallyDownloadsUpdates = automaticallyDownloads
        updater.updateCheckInterval = updateChannel == .preview ? 900 : 3600

        if checkInBackground, automaticallyChecks {
            updater.checkForUpdatesInBackground()
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
