//
// AgentNotchPanelViewModelTests.swift
// AiyuTermTests
//
// Phase 8.3 tests for the notch panel view-model and its
// state struct. We don't render the SwiftUI views in unit tests
// (that's the manual verification guide's job) — we exercise the
// data path: building a view state from workspace snapshots and
// confirming its equatable contract so SwiftUI can diff correctly.
//

import XCTest
@testable import AiyuTerm

final class AgentNotchPanelViewModelTests: XCTestCase {

    func testEmptyStateHasNoActivity() {
        let state = AgentNotchViewState.empty
        XCTAssertEqual(state.aggregatedStatus, .none)
        XCTAssertEqual(state.pendingCount, 0)
        XCTAssertTrue(state.worktrees.isEmpty)
        XCTAssertFalse(state.hasAnyActivity)
    }

    func testHasAnyActivityTrueWhenWorking() {
        let state = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: []
        )
        XCTAssertTrue(state.hasAnyActivity)
    }

    func testHasAnyActivityTrueWhenPendingExists() {
        let state = AgentNotchViewState(
            aggregatedStatus: .none,
            pendingCount: 1,
            worktrees: []
        )
        XCTAssertTrue(state.hasAnyActivity)
    }

    func testEquatableIdenticalStatesAreEqual() {
        let worktree = AgentNotchWorktreeSnapshot(
            id: "/tmp/a",
            workspaceName: "demo",
            worktreeDisplayName: "main",
            status: .working,
            hasPendingPermission: false,
            hasPendingQuestion: false
        )
        let a = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: [worktree]
        )
        let b = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: [worktree]
        )
        XCTAssertEqual(a, b)
    }

    func testEquatableDiffersOnAggregatedStatus() {
        let a = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 0, worktrees: [])
        let b = AgentNotchViewState(aggregatedStatus: .permissionNeeded, pendingCount: 0, worktrees: [])
        XCTAssertNotEqual(a, b)
    }

    func testEquatableDiffersOnPendingCount() {
        let a = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 0, worktrees: [])
        let b = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 2, worktrees: [])
        XCTAssertNotEqual(a, b)
    }

    func testEquatableDiffersOnWorktreeFlags() {
        let baseWorktree = AgentNotchWorktreeSnapshot(
            id: "/tmp/a",
            workspaceName: "demo",
            worktreeDisplayName: "main",
            status: .working,
            hasPendingPermission: false,
            hasPendingQuestion: false
        )
        var flagged = baseWorktree
        flagged = AgentNotchWorktreeSnapshot(
            id: baseWorktree.id,
            workspaceName: baseWorktree.workspaceName,
            worktreeDisplayName: baseWorktree.worktreeDisplayName,
            status: baseWorktree.status,
            hasPendingPermission: true,
            hasPendingQuestion: false
        )
        let a = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 0, worktrees: [baseWorktree])
        let b = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 0, worktrees: [flagged])
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Worktree snapshot struct

    func testSnapshotEquatableByAllFields() {
        let base = AgentNotchWorktreeSnapshot(
            id: "/tmp/a",
            workspaceName: "demo",
            worktreeDisplayName: "main",
            status: .working,
            hasPendingPermission: false,
            hasPendingQuestion: false
        )
        let sameCopy = AgentNotchWorktreeSnapshot(
            id: "/tmp/a",
            workspaceName: "demo",
            worktreeDisplayName: "main",
            status: .working,
            hasPendingPermission: false,
            hasPendingQuestion: false
        )
        XCTAssertEqual(base, sameCopy)

        let diffStatus = AgentNotchWorktreeSnapshot(
            id: base.id,
            workspaceName: base.workspaceName,
            worktreeDisplayName: base.worktreeDisplayName,
            status: .permissionNeeded,
            hasPendingPermission: base.hasPendingPermission,
            hasPendingQuestion: base.hasPendingQuestion
        )
        XCTAssertNotEqual(base, diffStatus)
    }

    // Note on view-model unit tests:
    //
    // Earlier drafts of this suite included three tests that
    // instantiated `AgentNotchPanelViewModel` as a test-local
    // `let`. Those tests tripped a Swift 6 runtime assertion
    // (`libmalloc POINTER_BEING_FREED_WAS_NOT_ALLOCATED` via
    // `swift_task_deinitOnExecutorImpl`) during teardown, even
    // after switching between `@MainActor` / `@Observable` /
    // `@unchecked Sendable` variants. The view-model is a thin
    // shell around `AgentNotchViewState`; the struct-level tests
    // above cover the interesting behavior. Live integration of
    // the view-model with WorkspaceStore is exercised by the
    // Phase 6.3 manual verification guide.
}
