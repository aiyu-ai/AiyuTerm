//
//  AppUpdaterController.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Combine
import Foundation
import Sparkle

enum AppUpdateState: Equatable {
    case none
    case available(version: String)
    case downloading(version: String)
    case readyToInstall(version: String)
}

@MainActor
private final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var updateChannel: ReleaseChannel = .stable
    weak var updateController: AppUpdaterController?

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        AppUpdaterController.resolveFeedURLString(infoDictionary: Bundle.main.infoDictionary)
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

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated {
            let version = item.displayVersionString ?? item.versionString
            updateController?.updateState = .available(version: version)
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated {
            let version = item.displayVersionString ?? item.versionString
            updateController?.updateState = .readyToInstall(version: version)
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        MainActor.assumeIsolated {
            let version = item.displayVersionString ?? item.versionString
            updateController?.updateState = .downloading(version: version)
        }
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        MainActor.assumeIsolated {
            let version = item.displayVersionString ?? item.versionString
            updateController?.updateState = .readyToInstall(version: version)
            updateController?.immediateInstallHandler = immediateInstallHandler
        }
        return true
    }
}

@MainActor
final class AppUpdaterController: ObservableObject {
    static let shared = AppUpdaterController()

    nonisolated static let repository = "AiyuAI/AiyuTerm"
    nonisolated static let releasesURL = URL(string: "https://github.com/\(repository)/releases")!
    nonisolated static let feedURLInfoPlistKey = "SUFeedURL"
    nonisolated static let defaultFeedURLString = "https://raw.githubusercontent.com/aiyu-ai/AiyuTerm/main/appcast.xml"
    static let sparkleKeyAccount = "aiyuterm"
    static let defaultPrivateKeyPath: String = {
        let releaseHome = ProcessInfo.processInfo.environment["AIYUTERM_RELEASE_HOME"] ?? "\(NSHomeDirectory())/.aiyuterm_release"
        return "\(releaseHome)/sparkle_private_key"
    }()

    @Published var updateState: AppUpdateState = .none
    var immediateInstallHandler: (() -> Void)?

    private let delegate = SparkleUpdaterDelegate()
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: !Self.defaultFeedURLString.isEmpty,
        updaterDelegate: delegate,
        userDriverDelegate: nil
    )

    private init() {
        delegate.updateController = self
    }

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

    func installUpdateNow() {
        if let handler = immediateInstallHandler {
            handler()
        } else {
            checkForUpdates()
        }
    }

    nonisolated static func resolveFeedURLString(infoDictionary: [String: Any]?) -> String {
        guard
            let value = infoDictionary?[feedURLInfoPlistKey] as? String,
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return defaultFeedURLString
        }
        return value
    }
}
