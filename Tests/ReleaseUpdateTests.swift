//
//  ReleaseUpdateTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class ReleaseUpdateTests: XCTestCase {
    func testAppSettingsDecodesLegacyPayloadWithUpdateDefaults() throws {
        let data = Data(
            """
            {
              "autoRefreshEnabled": false,
              "autoRefreshIntervalSeconds": 60,
              "fileWatcherEnabled": false,
              "githubIntegrationEnabled": true,
              "systemNotificationsEnabled": false,
              "showArchivedWorkspaces": true,
              "commandPaletteRecents": {
                "office": 123
              }
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertFalse(decoded.autoRefreshEnabled)
        XCTAssertEqual(decoded.autoRefreshIntervalSeconds, 60)
        XCTAssertTrue(decoded.autoCheckForUpdates)
        XCTAssertFalse(decoded.autoDownloadUpdates)
        XCTAssertFalse(decoded.showRemoteBranchesInCreateWorktree)
        XCTAssertTrue(decoded.sidebarShowsSecondaryLabels)
        XCTAssertTrue(decoded.sidebarShowsWorkspaceBadges)
        XCTAssertTrue(decoded.sidebarShowsWorktreeBadges)
        XCTAssertEqual(decoded.defaultRepositoryIcon, .repositoryDefault)
        XCTAssertEqual(decoded.defaultLocalTerminalIcon, .localTerminalDefault)
        XCTAssertEqual(decoded.defaultWorktreeIcon, .worktreeDefault)
        XCTAssertEqual(decoded.releaseChannel, .stable)
    }
}
