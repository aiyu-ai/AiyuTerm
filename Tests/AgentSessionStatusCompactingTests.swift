//
//  AgentSessionStatusCompactingTests.swift
//  AiyuTermTests
//
//  Tests for PreCompact/PostCompact event mapping in
//  AgentHookEventMapper (P12.3).
//
//  Author: wuwenrui
//

import XCTest
@testable import AiyuTerm

@MainActor
final class AgentSessionStatusCompactingTests: XCTestCase {

    private let worktreePath = "/tmp/aiyuterm-compacting-tests/repo"

    private var workspace: WorkspaceModel!
    private var mapper: AgentHookEventMapper!

    override func setUp() async throws {
        try await super.setUp()
        try await MainActor.run {
            try? FileManager.default.createDirectory(
                atPath: worktreePath, withIntermediateDirectories: true
            )
            workspace = WorkspaceModel(
                localDirectoryPath: worktreePath,
                name: "compacting-tests"
            )
            mapper = AgentHookEventMapper(
                workspacesProvider: { [self] in [workspace] }
            )
        }
    }

    override func tearDown() async throws {
        mapper = nil
        workspace = nil
        try? FileManager.default.removeItem(atPath: "/tmp/aiyuterm-compacting-tests")
        try await super.tearDown()
    }

    // MARK: - PreCompact sets .compacting

    func testPreCompactSetsCompactingStatus() {
        // First establish a working session so the mapper can resolve worktree
        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .working)

        // Fire PreCompact
        mapper.handleEvent(AgentHookEvent(
            eventName: "PreCompact",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .compacting)
    }

    // MARK: - PostCompact restores .working

    func testPostCompactRestoresWorkingStatus() {
        // Establish working, then compacting
        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        mapper.handleEvent(AgentHookEvent(
            eventName: "PreCompact",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .compacting)

        // Fire PostCompact
        mapper.handleEvent(AgentHookEvent(
            eventName: "PostCompact",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .working)
    }

    // MARK: - PreCompact is no longer silent

    func testPreCompactIsNotSilent() {
        // If PreCompact were silent, it would map to .none and the
        // applyStatus would skip it, leaving the status as .working.
        mapper.handleEvent(AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        mapper.handleEvent(AgentHookEvent(
            eventName: "PreCompact",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        ))
        // If PreCompact were still silent, status would remain .working
        XCTAssertNotEqual(workspace.agentStatus(forWorktreePath: worktreePath), .working)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .compacting)
    }

    // MARK: - SessionStart remains silent

    func testSessionStartRemainsSilent() {
        mapper.handleEvent(AgentHookEvent(
            eventName: "SessionStart",
            sessionId: "s2",
            rawJSON: ["cwd": worktreePath]
        ))
        // SessionStart is silent, so status should remain .none
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .none)
    }
}
