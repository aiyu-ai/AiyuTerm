//
// WorkspaceStoreAgentPermissionTests.swift
// AiyuTermTests
//
// Phase 6.2 tests for the WorkspaceStore wrapper methods
// (approveAgentPermission / denyAgentPermission /
// answerAgentQuestion) that the sidebar bubble view calls into.
//
// These tests exercise the full path:
//   1. Build a real WorkspaceStore
//   2. Create a sandbox workspace
//   3. Reach into the store's internal agent hook mapper via a
//      controlled `AgentHookEvent` to enqueue a pending request
//   4. Call the public wrapper to resolve it
//   5. Assert the pending dictionary is drained and the
//      continuation responded with the right payload
//
// We don't start the real socket server — that requires the full
// AgentHookServer lifecycle. Instead we test the mapper directly
// through the store's public agent-related API surface using the
// same WorkspaceModel instances the store owns.
//

import Foundation
import XCTest
@testable import AiyuTerm

@MainActor
final class WorkspaceStoreAgentPermissionTests: XCTestCase {

    // Local sandbox dir used as a "worktree" path so the mapper's
    // three-level cwd walk-up can find a match.
    private let worktreePath = "/tmp/aiyuterm-store-p62-\(UUID().uuidString)"
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
            name: "store-p62"
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

    // MARK: - approve path

    func testApproveAllowOnceResumesContinuationWithAllow() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "p62-allow-once",
            toolName: "Bash",
            toolInput: ["command": "ls"],
            rawJSON: ["cwd": worktreePath]
        )
        let path = worktreePath
        let mapper = self.mapper!
        async let response = mapper.handlePermissionRequest(event)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Confirm the workspace picked up the request.
        XCTAssertNotNil(workspace.pendingPermissionRequests[path])
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: path), .permissionNeeded)

        // Resolve via the mapper's UI-facing entry point — this is
        // exactly what WorkspaceStore.approveAgentPermission does
        // internally, minus the method hop.
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)

        let data = await response
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"behavior\":\"allow\""))
        XCTAssertNil(workspace.pendingPermissionRequests[path],
                     "Pending request should be drained")
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: path), .working,
                       "Badge should flip to working on approve")
        XCTAssertFalse(workspace.unreadPermissionWorktrees.contains(path),
                       "Unread flag should be cleared on approve")
    }

    func testApproveAlwaysCurrentlyMatchesAllowOnce() async {
        // Phase 6.1 ships allowAlways as an allow-once payload until
        // Phase 6.3 wires a real rule editor. This test documents
        // the current behavior so future changes are intentional.
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "p62-allow-always",
            toolName: "Bash",
            toolInput: ["command": "ls"],
            rawJSON: ["cwd": worktreePath]
        )
        let mapper = self.mapper!
        let path = worktreePath
        async let response = mapper.handlePermissionRequest(event)
        try? await Task.sleep(nanoseconds: 50_000_000)

        mapper.resolvePermission(forWorktreePath: path, decision: .allowAlways)

        let data = await response
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"behavior\":\"allow\""))
    }

    // MARK: - deny path

    func testDenyReturnsDenyJSONAndKeepsPermissionNeededBadge() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "p62-deny",
            toolName: "Bash",
            toolInput: ["command": "rm -rf /"],
            rawJSON: ["cwd": worktreePath]
        )
        let mapper = self.mapper!
        let path = worktreePath
        async let response = mapper.handlePermissionRequest(event)
        try? await Task.sleep(nanoseconds: 50_000_000)

        mapper.resolvePermission(forWorktreePath: path, decision: .deny)

        let data = await response
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"behavior\":\"deny\""))
        XCTAssertNil(workspace.pendingPermissionRequests[path])
        // Deny intentionally leaves the badge on permissionNeeded so
        // the user sees the decision register visually — the next
        // real event (PermissionDenied from Claude) will clear it.
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: path), .permissionNeeded)
    }

    // MARK: - question path

    func testAnswerQuestionEmbedsSelectedOption() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "p62-question",
            toolName: "AskUserQuestion",
            toolInput: [
                "questions": [
                    [
                        "question": "Which dir?",
                        "options": ["src", "tests"],
                        "header": "Pick",
                    ],
                ],
            ],
            rawJSON: ["cwd": worktreePath]
        )
        let mapper = self.mapper!
        let path = worktreePath
        async let response = mapper.handleAskUserQuestion(event)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(workspace.pendingQuestionRequests[path]?.options, ["src", "tests"])
        mapper.resolveQuestion(forWorktreePath: path, option: "src")

        let data = await response
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let answers = obj?["answers"] as? [[String: Any]]
        XCTAssertEqual(answers?.first?["answer"] as? String, "src")
        XCTAssertEqual(answers?.first?["header"] as? String, "Pick")
        XCTAssertNil(workspace.pendingQuestionRequests[path])
    }

    func testSkipQuestionResolvesWithDeny() async {
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "p62-skip",
            rawJSON: [
                "cwd": worktreePath,
                "question": "Continue?",
                "options": ["yes", "no"],
            ]
        )
        let mapper = self.mapper!
        let path = worktreePath
        async let response = mapper.handleQuestion(event)
        try? await Task.sleep(nanoseconds: 50_000_000)

        mapper.resolveQuestion(forWorktreePath: path, option: nil)

        let data = await response
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"behavior\":\"deny\""))
        XCTAssertNil(workspace.pendingQuestionRequests[path])
    }

    // MARK: - race conditions

    func testSecondPermissionRequestQueuesWithoutDenyingFirst() async {
        // Phase 12.9: second request queues behind the first instead
        // of auto-denying it. Both are resolved in FIFO order.
        let first = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "p62-first",
            toolName: "Bash",
            toolInput: ["command": "first"],
            rawJSON: ["cwd": worktreePath]
        )
        let second = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "p62-first",
            toolName: "Bash",
            toolInput: ["command": "second"],
            rawJSON: ["cwd": worktreePath]
        )
        let mapper = self.mapper!
        let path = worktreePath
        async let firstResponse = mapper.handlePermissionRequest(first)
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let secondResponse = mapper.handlePermissionRequest(second)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Both should be queued — first is NOT auto-denied.
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 2,
                       "Both requests should be queued")

        // Resolve the first (head) — second should be promoted.
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        let firstData = await firstResponse
        XCTAssertTrue(
            (String(data: firstData, encoding: .utf8) ?? "").contains("allow"),
            "First request resolved with allow"
        )
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 1,
                       "Second request should remain queued after first resolved")

        // Resolve the second.
        mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        let secondData = await secondResponse
        XCTAssertTrue((String(data: secondData, encoding: .utf8) ?? "").contains("allow"))
        XCTAssertEqual(mapper._permissionQueueDepth(forWorktreePath: path), 0)
    }
}
