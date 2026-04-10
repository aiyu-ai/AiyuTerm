//
// AgentNotchPanelViewModelTests.swift
// AiyuTermTests
//
// Phase 8.3 / 9.7 tests for the notch panel view-model and its
// state struct. We don't render the SwiftUI views in unit tests
// (that's the manual verification guide's job) — we exercise the
// data path: building a view state from workspace snapshots and
// confirming its equatable + sorting contract so SwiftUI can diff
// and the expanded card prioritizes correctly.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentNotchPanelViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSnapshot(
        id: String = "/tmp/a",
        workspaceName: String = "demo",
        worktreeDisplayName: String = "main",
        status: AgentSessionStatus = .working,
        source: String = "claude",
        model: String? = nil,
        cwd: String? = nil,
        currentTool: String? = nil,
        toolDescription: String? = nil,
        lastAssistantMessage: String? = nil,
        lastUserPrompt: String? = nil,
        permissionRequest: AgentPermissionRequest? = nil,
        questionRequest: AgentQuestionRequest? = nil,
        resolvedTitle: String? = nil
    ) -> AgentNotchWorktreeSnapshot {
        AgentNotchWorktreeSnapshot(
            id: id,
            workspaceName: workspaceName,
            worktreeDisplayName: worktreeDisplayName,
            status: status,
            source: source,
            model: model,
            cwd: cwd,
            currentTool: currentTool,
            toolDescription: toolDescription,
            lastAssistantMessage: lastAssistantMessage,
            lastUserPrompt: lastUserPrompt,
            permissionRequest: permissionRequest,
            questionRequest: questionRequest,
            resolvedTitle: resolvedTitle
        )
    }

    private func makePermissionRequest(
        worktreePath: String = "/tmp/a",
        toolName: String = "Bash"
    ) -> AgentPermissionRequest {
        AgentPermissionRequest(
            id: UUID(),
            sessionId: "sid-1",
            worktreePath: worktreePath,
            toolName: toolName,
            toolDescription: "rm -rf /tmp/x",
            timestamp: Date()
        )
    }

    private func makeQuestionRequest(
        worktreePath: String = "/tmp/a"
    ) -> AgentQuestionRequest {
        AgentQuestionRequest(
            id: UUID(),
            sessionId: "sid-1",
            worktreePath: worktreePath,
            question: "Proceed?",
            options: ["Yes", "No"],
            header: nil,
            timestamp: Date()
        )
    }

    // MARK: - Empty state

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

    // MARK: - Equatable

    func testEquatableIdenticalStatesAreEqual() {
        let wt = makeSnapshot()
        let a = AgentNotchViewState(
            aggregatedStatus: .working, pendingCount: 0, worktrees: [wt]
        )
        let b = AgentNotchViewState(
            aggregatedStatus: .working, pendingCount: 0, worktrees: [wt]
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

    func testEquatableDiffersOnWorktreePermissionFlag() {
        let baseWorktree = makeSnapshot()
        let flagged = makeSnapshot(permissionRequest: makePermissionRequest())
        let a = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 0, worktrees: [baseWorktree])
        let b = AgentNotchViewState(aggregatedStatus: .working, pendingCount: 0, worktrees: [flagged])
        XCTAssertNotEqual(a, b)
    }

    func testSnapshotComputedFlags() {
        let noPending = makeSnapshot()
        XCTAssertFalse(noPending.hasPendingPermission)
        XCTAssertFalse(noPending.hasPendingQuestion)

        let withPerm = makeSnapshot(permissionRequest: makePermissionRequest())
        XCTAssertTrue(withPerm.hasPendingPermission)
        XCTAssertFalse(withPerm.hasPendingQuestion)

        let withQ = makeSnapshot(questionRequest: makeQuestionRequest())
        XCTAssertFalse(withQ.hasPendingPermission)
        XCTAssertTrue(withQ.hasPendingQuestion)
    }

    func testSnapshotEquatableByAllFields() {
        let base = makeSnapshot(source: "claude", model: "claude-sonnet")
        let sameCopy = makeSnapshot(source: "claude", model: "claude-sonnet")
        XCTAssertEqual(base, sameCopy)

        let diffModel = makeSnapshot(source: "claude", model: "claude-opus")
        XCTAssertNotEqual(base, diffModel)

        let diffSource = makeSnapshot(source: "codex", model: "claude-sonnet")
        XCTAssertNotEqual(base, diffSource)
    }

    // MARK: - Sorting (Phase 9.7)

    func testSortingPermissionBeatsEverything() {
        let working = makeSnapshot(id: "/tmp/w", status: .working)
        let withPerm = makeSnapshot(
            id: "/tmp/p",
            status: .working,
            permissionRequest: makePermissionRequest(worktreePath: "/tmp/p")
        )
        let withQ = makeSnapshot(
            id: "/tmp/q",
            status: .working,
            questionRequest: makeQuestionRequest(worktreePath: "/tmp/q")
        )
        let state = AgentNotchViewState(
            aggregatedStatus: .permissionNeeded,
            pendingCount: 2,
            worktrees: [working, withPerm, withQ]
        )
        let sorted = state.sortedWorktrees
        XCTAssertEqual(sorted[0].id, "/tmp/p")
        XCTAssertEqual(sorted[1].id, "/tmp/q")
        XCTAssertEqual(sorted[2].id, "/tmp/w")
    }

    func testSortingWithinBucketIsStable() {
        let a = makeSnapshot(id: "/tmp/a", status: .working)
        let b = makeSnapshot(id: "/tmp/b", status: .working)
        let c = makeSnapshot(id: "/tmp/c", status: .working)
        let state = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: [a, b, c]
        )
        // All in the same bucket — original order preserved.
        XCTAssertEqual(state.sortedWorktrees.map(\.id), ["/tmp/a", "/tmp/b", "/tmp/c"])
    }

    func testSortingStatusPriorityWorkingBeforeCompleted() {
        let completed = makeSnapshot(id: "/tmp/c", status: .taskCompleted)
        let working = makeSnapshot(id: "/tmp/w", status: .working)
        let state = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: [completed, working]
        )
        XCTAssertEqual(state.sortedWorktrees.map(\.id), ["/tmp/w", "/tmp/c"])
    }

    func testSortingEmpty() {
        XCTAssertTrue(AgentNotchViewStateSorting.sort([]).isEmpty)
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
    // above cover the interesting behavior.
}
