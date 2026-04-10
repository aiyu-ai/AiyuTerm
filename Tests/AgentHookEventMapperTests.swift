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

    // MARK: - Blocking callbacks (Phase 6.1 continuation model)

    func testPermissionRequestSuspendsUntilResolvedWithDeny() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "s13",
            toolName: "Bash",
            toolInput: ["command": "rm -rf /"],
            rawJSON: ["cwd": worktreeAlpha]
        )
        let mapper = self.mapper!
        let path = self.worktreeAlpha
        async let response = mapper.handlePermissionRequest(event)
        // Yield so the mapper can enqueue the pending request
        // before we assert on state + resolve.
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            XCTAssertNotNil(self.workspace.pendingPermissionRequests[path],
                            "Mapper should enqueue pending request before suspending")
            XCTAssertEqual(self.workspace.agentStatus(forWorktreePath: path), .permissionNeeded)
            mapper.resolvePermission(forWorktreePath: path, decision: .deny)
        }
        let data = await response
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"behavior\":\"deny\""))
        await MainActor.run {
            XCTAssertNil(self.workspace.pendingPermissionRequests[path],
                         "Pending request should be drained after resolve")
        }
    }

    func testPermissionRequestResolvesAllowOnceReturnsAllowJSON() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "s13b",
            toolName: "Bash",
            toolInput: ["command": "ls"],
            rawJSON: ["cwd": worktreeAlpha]
        )
        let mapper = self.mapper!
        let path = self.worktreeAlpha
        async let response = mapper.handlePermissionRequest(event)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            mapper.resolvePermission(forWorktreePath: path, decision: .allowOnce)
        }
        let data = await response
        XCTAssertTrue((String(data: data, encoding: .utf8) ?? "").contains("\"behavior\":\"allow\""))
        await MainActor.run {
            // After a positive resolution the badge should flip
            // back to .working so the user sees activity resume.
            XCTAssertEqual(self.workspace.agentStatus(forWorktreePath: path), .working)
            XCTAssertFalse(self.workspace.unreadPermissionWorktrees.contains(path))
        }
    }

    func testHandleAskUserQuestionEnqueuesQuestionRequest() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "s14",
            toolName: "AskUserQuestion",
            toolInput: [
                "questions": [
                    [
                        "question": "Should we proceed?",
                        "options": ["yes", "no"],
                        "header": "Confirm",
                    ],
                ],
            ],
            rawJSON: ["cwd": worktreeAlpha]
        )
        let mapper = self.mapper!
        let path = self.worktreeAlpha
        async let response = mapper.handleAskUserQuestion(event)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            XCTAssertNotNil(self.workspace.pendingQuestionRequests[path])
            XCTAssertEqual(self.workspace.pendingQuestionRequests[path]?.options, ["yes", "no"])
            mapper.resolveQuestion(forWorktreePath: path, option: "yes")
        }
        let data = await response
        let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let answers = jsonObj?["answers"] as? [[String: Any]]
        XCTAssertEqual(answers?.first?["answer"] as? String, "yes")
    }

    func testHandleQuestionEnqueuesFromNotificationPayload() async {
        let event = AgentHookEvent(
            eventName: "Notification",
            sessionId: "s15",
            rawJSON: [
                "cwd": worktreeAlpha,
                "question": "Continue?",
                "options": ["yes", "no"],
            ]
        )
        let mapper = self.mapper!
        let path = self.worktreeAlpha
        async let response = mapper.handleQuestion(event)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            XCTAssertEqual(self.workspace.pendingQuestionRequests[path]?.question, "Continue?")
            XCTAssertEqual(self.workspace.agentStatus(forWorktreePath: path), .permissionNeeded)
            XCTAssertTrue(self.workspace.unreadPermissionWorktrees.contains(path))
            // Skip the question (nil option).
            mapper.resolveQuestion(forWorktreePath: path, option: nil)
        }
        let data = await response
        XCTAssertTrue((String(data: data, encoding: .utf8) ?? "").contains("\"behavior\":\"deny\""))
    }

    // MARK: - Peer disconnect hygiene

    func testPeerDisconnectDrainsPendingPermission() async {
        let event = AgentHookEvent(
            eventName: "PermissionRequest",
            sessionId: "s16",
            toolName: "Bash",
            toolInput: ["command": "rm"],
            rawJSON: ["cwd": worktreeAlpha]
        )
        let mapper = self.mapper!
        let path = self.worktreeAlpha
        async let response = mapper.handlePermissionRequest(event)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            XCTAssertNotNil(self.workspace.pendingPermissionRequests[path])
            // Simulate bridge process dying mid-flight.
            mapper.handlePeerDisconnect(sessionId: "s16")
        }
        let data = await response
        XCTAssertTrue(
            (String(data: data, encoding: .utf8) ?? "").contains("\"behavior\":\"deny\""),
            "Peer disconnect must drain the continuation with a deny response"
        )
        await MainActor.run {
            XCTAssertNil(self.workspace.pendingPermissionRequests[path])
        }
    }
}
