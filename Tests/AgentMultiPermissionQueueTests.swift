//
// AgentMultiPermissionQueueTests.swift
// AiyuTermTests
//
// Phase 12.9-11 tests for the multi-permission FIFO queue that
// replaced the single-slot permission continuation model.
//
// Key behavioral changes validated here:
//   1. Second permission does NOT auto-deny the first (queues behind)
//   2. resolvePermission dequeues head and promotes next
//   3. resolvePermission with empty queue is safe (no-op)
//   4. Peer disconnect drains the entire queue
//   5. Stale cleanup drains old entries by threshold
//

import XCTest
@testable import AiyuTerm

@MainActor
final class AgentMultiPermissionQueueTests: XCTestCase {

    private let worktreePath = "/tmp/aiyuterm-mpq-tests-\(UUID().uuidString)"
    private var workspace: WorkspaceModel!
    private var mapper: AgentHookEventMapper!

    override func setUp() async throws {
        try await super.setUp()
        try? FileManager.default.createDirectory(
            atPath: worktreePath,
            withIntermediateDirectories: true
        )
        workspace = WorkspaceModel(
            localDirectoryPath: worktreePath,
            name: "mpq-tests"
        )
        mapper = AgentHookEventMapper(
            workspacesProvider: { [self] in [workspace] }
        )
    }

    override func tearDown() async throws {
        mapper = nil
        workspace = nil
        try? FileManager.default.removeItem(atPath: worktreePath)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makePermissionEvent(
        sessionId: String = "mpq-session",
        command: String = "ls"
    ) -> AgentHookEvent {
        AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: sessionId,
            toolName: "Bash",
            toolInput: ["command": command],
            rawJSON: ["cwd": worktreePath]
        )
    }

    /// Prime the session -> worktree cache so the mapper can resolve
    /// the worktree from sessionId alone.
    private func primeSession(_ sessionId: String) {
        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: sessionId,
            rawJSON: ["cwd": worktreePath, "prompt": "init"]
        ))
    }

    // MARK: - Test 1: Second permission does NOT auto-deny the first

    func testSecondPermissionQueuesWithoutDenyingFirst() async {
        let mapper = self.mapper!
        let path = self.worktreePath

        let first = makePermissionEvent(command: "first")
        let second = makePermissionEvent(command: "second")

        async let firstResponse = mapper.handlePermissionRequest(first)
        try? await Task.sleep(nanoseconds: 50_000_000)

        async let secondResponse = mapper.handlePermissionRequest(second)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Both should be queued.
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 2,
                       "Both requests must be queued, not auto-denied")

        // Only the first (head) should be visible in the UI.
        XCTAssertNotNil(workspace.pendingPermissionRequests[path],
                        "Head request should be enqueued in workspace")
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: path), .permissionNeeded)

        // Resolve first.
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        let firstData = await firstResponse
        XCTAssertTrue(
            (String(data: firstData, encoding: .utf8) ?? "").contains("allow"),
            "First request should resolve with allow, NOT deny"
        )

        // Second should now be the head.
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 1)
        XCTAssertNotNil(workspace.pendingPermissionRequests[path],
                        "Second request should be promoted to UI")

        // Resolve second.
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        let secondData = await secondResponse
        XCTAssertTrue((String(data: secondData, encoding: .utf8) ?? "").contains("allow"))
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 0)
    }

    // MARK: - Test 2: resolvePermission dequeues head and shows next

    func testResolvePromotesNextQueueEntry() async {
        let mapper = self.mapper!
        let path = self.worktreePath

        async let r1 = mapper.handlePermissionRequest(makePermissionEvent(command: "cmd1"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let r2 = mapper.handlePermissionRequest(makePermissionEvent(command: "cmd2"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let r3 = mapper.handlePermissionRequest(makePermissionEvent(command: "cmd3"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 3)

        // Resolve head: queue should shrink to 2 and next promoted.
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        _ = await r1
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 2)
        // Status should stay permissionNeeded because there are more.
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: path), .permissionNeeded)
        XCTAssertTrue(workspace.unreadPermissionWorktrees.contains(path),
                      "Next entry should mark unread")

        // Resolve second.
        mapper.resolvePermission(forWorktreePath: path, decision: .deny)
        _ = await r2
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 1)

        // Resolve third (last).
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        _ = await r3
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 0)
        // Badge should flip to working now that queue is empty.
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: path), .working)
    }

    // MARK: - Test 3: resolvePermission with empty queue is safe

    func testResolveOnEmptyQueueIsNoop() {
        // Should not crash or panic.
        mapper.resolvePermission(forWorktreePath: worktreePath, decision: .allowOnce)
        mapper.resolvePermission(forWorktreePath: "/nonexistent", decision: .deny)
        // If we get here without crash, the test passes.
    }

    // MARK: - Test 4: Peer disconnect drains entire queue

    func testPeerDisconnectDrainsEntireQueue() async {
        let mapper = self.mapper!
        let path = self.worktreePath
        let sessionId = "mpq-session"

        async let r1 = mapper.handlePermissionRequest(makePermissionEvent(command: "a"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let r2 = mapper.handlePermissionRequest(makePermissionEvent(command: "b"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 2)

        // Simulate bridge dying.
        mapper.handlePeerDisconnect(sessionId: sessionId)

        let d1 = await r1
        let d2 = await r2

        // Both must be drained with deny.
        XCTAssertTrue((String(data: d1, encoding: .utf8) ?? "").contains("deny"))
        XCTAssertTrue((String(data: d2, encoding: .utf8) ?? "").contains("deny"))
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 0)
        XCTAssertNil(workspace.pendingPermissionRequests[path])
    }

    // MARK: - Test 5: Stale cleanup drains old entries

    func testDrainStalePermissionsRemovesOldEntries() async {
        let mapper = self.mapper!
        let path = self.worktreePath

        // Enqueue two requests — they'll have enqueuedAt ~ now.
        async let r1 = mapper.handlePermissionRequest(makePermissionEvent(command: "old1"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let r2 = mapper.handlePermissionRequest(makePermissionEvent(command: "old2"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 2)

        // Drain everything older than 1 second in the future (i.e. all).
        let future = Date().addingTimeInterval(1)
        mapper.drainStalePermissions(olderThan: future)

        let d1 = await r1
        let d2 = await r2

        XCTAssertTrue((String(data: d1, encoding: .utf8) ?? "").contains("deny"))
        XCTAssertTrue((String(data: d2, encoding: .utf8) ?? "").contains("deny"))
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 0)
        XCTAssertNil(workspace.pendingPermissionRequests[path])
    }

    func testDrainStalePermissionsKeepsRecentEntries() async {
        let mapper = self.mapper!
        let path = self.worktreePath

        async let r1 = mapper.handlePermissionRequest(makePermissionEvent(command: "recent"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 1)

        // Drain with a threshold in the past (nothing should match).
        let past = Date().addingTimeInterval(-60)
        mapper.drainStalePermissions(olderThan: past)

        // Queue should still have the entry.
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 1)

        // Clean up by resolving it.
        mapper.resolvePermission(forWorktreePath: path, decision: .deny)
        _ = await r1
    }

    // MARK: - toolUseId propagation

    func testToolUseIdIsPassedThroughToRequest() async {
        let mapper = self.mapper!
        let path = self.worktreePath

        var event = makePermissionEvent(command: "with-tool-use-id")
        event.resolvedToolUseId = "toolu_abc123"

        async let response = mapper.handlePermissionRequest(event)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // The request visible in the workspace should carry the toolUseId.
        let pending = workspace.pendingPermissionRequests[path]
        XCTAssertEqual(pending?.toolUseId, "toolu_abc123")

        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        _ = await response
    }
}
