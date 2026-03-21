//
//  CommandPaletteTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class CommandPaletteTests: XCTestCase {
    func testPrefixMatchBeatsSubtitleOnlyMatch() {
        let direct = CommandPaletteItem(
            id: "direct",
            title: "Open Workspace Overview",
            subtitle: "Dashboard",
            group: .navigation,
            keywords: ["overview"],
            isGlobal: true,
            kind: .command(.toggleOverview)
        )
        let indirect = CommandPaletteItem(
            id: "indirect",
            title: "Open Settings",
            subtitle: "overview controls",
            group: .navigation,
            keywords: ["settings"],
            isGlobal: true,
            kind: .command(.presentSettings)
        )

        XCTAssertGreaterThan(direct.score(query: "open work", recency: nil) ?? 0, indirect.score(query: "open work", recency: nil) ?? 0)
    }

    func testRecentItemGetsBoostWhenQueryEmpty() {
        let stale: TimeInterval = 1_000
        let recent: TimeInterval = 2_000
        let item = CommandPaletteItem(
            id: "recent",
            title: "Refresh All Repositories",
            subtitle: nil,
            group: .automation,
            keywords: ["refresh"],
            isGlobal: true,
            kind: .command(.refreshAllRepositories)
        )

        XCTAssertGreaterThan(item.score(query: "", recency: recent) ?? 0, item.score(query: "", recency: stale) ?? 0)
    }

    func testGitHubBatchFactoryAddsExpectedCommandPaletteItems() {
        let readyTargets = [
            WorkspaceGitHubTarget(workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, worktreePath: "/tmp/demo-ready")
        ]
        let behindTargets = [
            WorkspaceGitHubTarget(workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, worktreePath: "/tmp/demo-behind")
        ]

        let items = GitHubBatchCommandPaletteFactory.makeItems(
            readyTargets: readyTargets,
            behindTargets: behindTargets,
            releasableTargets: readyTargets
        )

        let itemIDs = Set(items.map(\.id))
        XCTAssertTrue(itemIDs.contains("github-batch-queue-ready"), "\(itemIDs)")
        XCTAssertTrue(itemIDs.contains("github-batch-update-behind"), "\(itemIDs)")
        XCTAssertTrue(itemIDs.contains("github-batch-release-notes"), "\(itemIDs)")
    }
}
