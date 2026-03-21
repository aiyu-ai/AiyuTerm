//
//  GitRepositoryServiceTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class GitRepositoryServiceTests: XCTestCase {
    func testParseWorktreeListMarksMainAndLockedEntries() {
        let output = """
        worktree /tmp/repo
        HEAD abcdef1
        branch refs/heads/main

        worktree /tmp/repo-feature
        HEAD 1234567
        branch refs/heads/feature/demo
        locked manual cleanup
        """

        let worktrees = GitRepositoryService.parseWorktreeList(output, rootPath: "/tmp/repo")

        XCTAssertEqual(worktrees.count, 2)
        XCTAssertEqual(worktrees[0].path, "/tmp/repo")
        XCTAssertTrue(worktrees[0].isMainWorktree)
        XCTAssertEqual(worktrees[1].branch, "feature/demo")
        XCTAssertTrue(worktrees[1].isLocked)
        XCTAssertEqual(worktrees[1].lockReason, "manual cleanup")
    }

    func testParseAheadBehind() {
        let parsed = GitRepositoryService.parseAheadBehind("3\t7\n")
        XCTAssertEqual(parsed.behind, 3)
        XCTAssertEqual(parsed.ahead, 7)
    }

    func testParseRemoteBranchesFiltersHeadAlias() {
        let output = """
        origin/HEAD
        origin/main
        origin/feature/one
        """

        XCTAssertEqual(
            GitRepositoryService.parseRemoteBranchList(output),
            ["origin/feature/one", "origin/main"]
        )
    }
}
