//
//  PendingWorktreeRemovalTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class PendingWorktreeRemovalTests: XCTestCase {
    override func tearDown() {
        LocalizationManager.shared.updateSelectedLanguage(.automatic)
        super.tearDown()
    }

    func testDetailMessageIncludesActiveDirtyAndAheadWarnings() {
        LocalizationManager.shared.updateSelectedLanguage(.english)

        let request = PendingWorktreeRemoval(
            workspaceID: UUID(),
            worktreePaths: ["/tmp/repo-feature"],
            worktreeNames: ["feature"],
            activePaneCount: 2,
            includesActiveWorktree: true,
            dirtyWorktreeNames: ["feature"],
            dirtyFileCount: 3,
            aheadWorktreeNames: ["feature"],
            aheadCommitCount: 2
        )

        XCTAssertTrue(request.detailMessage.contains("switch back to the main checkout first"))
        XCTAssertTrue(request.detailMessage.contains("2 running pane(s)"))
        XCTAssertTrue(request.detailMessage.contains("Uncommitted changes detected in feature (3 file(s))"))
        XCTAssertTrue(request.detailMessage.contains("Unpushed commits detected in feature (2 commit(s) ahead)"))
        XCTAssertTrue(request.allowsForceRemove)
    }

    func testForceRemoveOnlyAppearsForDirtyWorktrees() {
        let request = PendingWorktreeRemoval(
            workspaceID: UUID(),
            worktreePaths: ["/tmp/repo-feature"],
            worktreeNames: ["feature"],
            activePaneCount: 0,
            includesActiveWorktree: false,
            dirtyWorktreeNames: [],
            dirtyFileCount: 0,
            aheadWorktreeNames: ["feature"],
            aheadCommitCount: 1
        )

        XCTAssertFalse(request.allowsForceRemove)
    }

    func testDetailMessageLocalizesToSimplifiedChinese() {
        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)

        let request = PendingWorktreeRemoval(
            workspaceID: UUID(),
            worktreePaths: ["/tmp/repo-feature"],
            worktreeNames: ["feature"],
            activePaneCount: 2,
            includesActiveWorktree: true,
            dirtyWorktreeNames: ["feature"],
            dirtyFileCount: 3,
            aheadWorktreeNames: ["feature"],
            aheadCommitCount: 2
        )

        XCTAssertTrue(request.detailMessage.contains("会先切回主检出目录"))
        XCTAssertTrue(request.detailMessage.contains("2 个运行中面板"))
        XCTAssertTrue(request.detailMessage.contains("未提交更改"))
        XCTAssertTrue(request.detailMessage.contains("未推送提交"))
    }
}
