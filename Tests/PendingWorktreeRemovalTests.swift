//
//  PendingWorktreeRemovalTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class PendingWorktreeRemovalTests: XCTestCase {
    func testDetailMessageIncludesActiveDirtyAndAheadWarnings() {
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
}
