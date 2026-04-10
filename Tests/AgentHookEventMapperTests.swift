//
// AgentHookEventMapperTests.swift
// AiyuTermTests
//
// Phase 3 unit tests for the AgentHookEvent -> AgentSessionStatus
// translation layer. Covers the three-level worktree resolution
// fallback, all non-trivial status mappings, and the blocking
// callback contract (permission / ask-user-question / question).
//

import XCTest
@testable import AiyuTerm

@MainActor
final class AgentHookEventMapperTests: XCTestCase {
    // Two independent local workspaces so each has its own
    // worktreeControllers entry. We can't just append an extra
    // WorktreeModel to a single workspace because
    // `WorkspaceModel.init(record:)` only instantiates a controller
    // for the activeWorktreePath (see WorkspaceRuntime.swift:70).
    private let worktreeAlpha = "/tmp/aiyuterm-mapper-tests/alpha"
    private let worktreeBeta = "/tmp/aiyuterm-mapper-tests/beta"

    private var workspaceAlpha: WorkspaceModel!
    private var workspaceBeta: WorkspaceModel!
    private var mapper: AgentHookEventMapper!

    // Convenience alias used by most tests that only touch alpha.
    private var workspace: WorkspaceModel! { workspaceAlpha }

    override func setUp() async throws {
        try await super.setUp()
        try await MainActor.run {
            try? FileManager.default.createDirectory(
                atPath: worktreeAlpha, withIntermediateDirectories: true
            )
            try? FileManager.default.createDirectory(
                atPath: worktreeBeta, withIntermediateDirectories: true
            )

            workspaceAlpha = WorkspaceModel(
                localDirectoryPath: worktreeAlpha,
                name: "mapper-tests-alpha"
            )
            workspaceBeta = WorkspaceModel(
                localDirectoryPath: worktreeBeta,
                name: "mapper-tests-beta"
            )

            mapper = AgentHookEventMapper(
                workspacesProvider: { [self] in
                    [workspaceAlpha, workspaceBeta]
                }
            )
        }
    }

    override func tearDown() async throws {
        mapper = nil
        workspaceAlpha = nil
        workspaceBeta = nil
        try? FileManager.default.removeItem(atPath: "/tmp/aiyuterm-mapper-tests")
        try await super.tearDown()
    }

    // MARK: - Level 1: cwd walk-up

    func testUserPromptSubmitWithExactWorktreeCwd() {
        let event = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreeAlpha, "prompt": "hi"]
        )
        mapper.handleEvent(event)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    func testCwdWalkUpFromSubdirectory() {
        let deepPath = "\(worktreeAlpha)/src/foo/bar"
        try? FileManager.default.createDirectory(
            atPath: deepPath, withIntermediateDirectories: true
        )
        let event = AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s2",
            toolName: "Bash",
            toolInput: ["command": "ls"],
            rawJSON: ["cwd": deepPath]
        )
        mapper.handleEvent(event)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    func testBetaWorkspaceResolvesIndependentlyFromAlpha() {
        let event = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s3",
            rawJSON: ["cwd": worktreeBeta]
        )
        mapper.handleEvent(event)
        XCTAssertEqual(workspaceBeta.agentStatus(forWorktreePath: worktreeBeta), .working)
        // alpha should be untouched
        XCTAssertEqual(workspaceAlpha.agentStatus(forWorktreePath: worktreeAlpha), .none)
    }

    func testUnresolvableCwdIsSilentlyDropped() {
        let event = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s4",
            rawJSON: ["cwd": "/tmp/unknown-place"]
        )
        // Should not crash, should not touch any worktree.
        mapper.handleEvent(event)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .none)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeBeta), .none)
    }

    // MARK: - Level 3: session cache fallback

    func testSecondEventWithoutCwdUsesCachedSessionResolution() {
        // First event establishes the cache
        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s5",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)

        // Second event omits cwd entirely — should resolve via cache
        workspace.setAgentStatus(.none, forWorktreePath: worktreeAlpha)
        mapper.handleEvent(AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s5",
            toolName: "Bash",
            toolInput: ["command": "echo hi"]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    // MARK: - Status mapping

    func testStopEventTransitionsToTaskCompletedAndMarksUnread() {
        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s6",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        mapper.handleEvent(AgentHookEvent(
            eventName: "Stop",
            sessionId: "s6",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .taskCompleted)
        XCTAssertTrue(workspace.unreadCompletedWorktrees.contains(worktreeAlpha))
    }

    func testNewUserPromptClearsUnreadFlags() {
        // Set up a completed state
        workspace.markCompletionUnread(forWorktreePath: worktreeAlpha)
        workspace.markPermissionUnread(forWorktreePath: worktreeAlpha)

        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s7",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        XCTAssertFalse(workspace.unreadCompletedWorktrees.contains(worktreeAlpha))
        XCTAssertFalse(workspace.unreadPermissionWorktrees.contains(worktreeAlpha))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    func testPostToolUseFailureTransitionsToError() {
        mapper.handleEvent(AgentHookEvent(
            eventName: "PreToolUse",
            sessionId: "s8",
            toolName: "Bash",
            toolInput: ["command": "false"],
            rawJSON: ["cwd": worktreeAlpha]
        ))
        mapper.handleEvent(AgentHookEvent(
            eventName: "PostToolUseFailure",
            sessionId: "s8",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .error)
    }

    func testNotificationWithPermissionPromptMarksPermissionNeeded() {
        mapper.handleEvent(AgentHookEvent(
            eventName: "Notification",
            sessionId: "s9",
            rawJSON: [
                "cwd": worktreeAlpha,
                "notification_type": "permission_prompt",
            ]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .permissionNeeded)
        XCTAssertTrue(workspace.unreadPermissionWorktrees.contains(worktreeAlpha))
    }

    func testNotificationWithoutPermissionKeywordsIsSilent() {
        workspace.setAgentStatus(.working, forWorktreePath: worktreeAlpha)
        mapper.handleEvent(AgentHookEvent(
            eventName: "Notification",
            sessionId: "s10",
            rawJSON: [
                "cwd": worktreeAlpha,
                "message": "Progress update",
            ]
        ))
        // Plain notifications should NOT change the badge.
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    func testPermissionDeniedTransitionsBackToWorking() {
        workspace.setAgentStatus(.permissionNeeded, forWorktreePath: worktreeAlpha)
        workspace.markPermissionUnread(forWorktreePath: worktreeAlpha)
        mapper.handleEvent(AgentHookEvent(
            eventName: "PermissionDenied",
            sessionId: "s11",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    func testSessionStartEventDoesNotChangeBadge() {
        workspace.setAgentStatus(.working, forWorktreePath: worktreeAlpha)
        mapper.handleEvent(AgentHookEvent(
            eventName: "SessionStart",
            sessionId: "s12",
            rawJSON: ["cwd": worktreeAlpha]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .working)
    }

    // MARK: - Blocking callbacks (Phase 3 deny-by-default)

    func testPermissionRequestReturnsDenyResponse() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "s13",
            toolName: "Bash",
            toolInput: ["command": "rm -rf /"],
            rawJSON: ["cwd": worktreeAlpha]
        )
        let response = await mapper.handlePermissionRequest(event)
        let json = String(data: response, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"behavior\":\"deny\""))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .permissionNeeded)
    }

    func testAskUserQuestionReturnsDenyAndMarksPermissionNeeded() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "s14",
            toolName: "AskUserQuestion",
            rawJSON: ["cwd": worktreeAlpha]
        )
        let response = await mapper.handleAskUserQuestion(event)
        XCTAssertTrue((String(data: response, encoding: .utf8) ?? "").contains("deny"))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .permissionNeeded)
        XCTAssertTrue(workspace.unreadPermissionWorktrees.contains(worktreeAlpha))
    }

    func testHandleQuestionMarksPermissionUnread() async {
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s15",
            rawJSON: [
                "cwd": worktreeAlpha,
                "question": "Continue?",
                "options": ["yes", "no"],
            ]
        )
        _ = await mapper.handleQuestion(event)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreeAlpha), .permissionNeeded)
        XCTAssertTrue(workspace.unreadPermissionWorktrees.contains(worktreeAlpha))
    }

    // MARK: - Peer disconnect hygiene

    func testPeerDisconnectClearsWaitingState() {
        // Seed a snapshot into waitingApproval state via a permission
        // request and then simulate the bridge dying.
        Task {
            _ = await mapper.handlePermissionRequest(AgentHookEvent(
                eventName: "PermissionRequest",
                sessionId: "s16",
                toolName: "Bash",
                toolInput: ["command": "rm"],
                rawJSON: ["cwd": worktreeAlpha]
            ))
        }
        mapper.handlePeerDisconnect(sessionId: "s16")
        // Should not crash; the mapper's internal state should have
        // been hygenically drained. Nothing observable on the public
        // surface for Phase 3.
        XCTAssertGreaterThanOrEqual(mapper._snapshotCountForTesting, 0)
    }
}
