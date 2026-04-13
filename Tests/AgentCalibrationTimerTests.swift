//
//  AgentCalibrationTimerTests.swift
//  AiyuTermTests
//
//  Phase 12.15-17 tests for PID liveness checks, calibration
//  timer behaviour, and JSONL reconciliation wiring.
//

import XCTest
@testable import AiyuTerm

@MainActor
final class AgentCalibrationTimerTests: XCTestCase {
    private let worktreePath = "/tmp/aiyuterm-calibration-tests/repo"
    private var workspace: WorkspaceModel!
    private var mapper: AgentHookEventMapper!

    override func setUp() async throws {
        try await super.setUp()
        try await MainActor.run {
            try? FileManager.default.createDirectory(
                atPath: worktreePath,
                withIntermediateDirectories: true
            )
            workspace = WorkspaceModel(
                localDirectoryPath: worktreePath,
                name: "calibration-tests"
            )
            mapper = AgentHookEventMapper(
                workspacesProvider: { [self] in [workspace] }
            )
        }
    }

    override func tearDown() async throws {
        mapper.stopCalibration()
        mapper = nil
        workspace = nil
        try? FileManager.default.removeItem(atPath: "/tmp/aiyuterm-calibration-tests")
        try await super.tearDown()
    }

    // MARK: - PID liveness (Task 15 + 16)

    func testPidDeathClearsWorkingStatus() async throws {
        // Use a PID that definitely doesn't exist (99999999).
        let prompt = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath, "prompt": "go", "pid": 99999999]
        )
        mapper.handleEvent(prompt)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .working)

        // Run calibration -- PID 99999999 should fail kill(pid, 0).
        mapper.runCalibration()

        // Allow async tasks to complete.
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .none)
    }

    func testPidDeathDoesNotClearCompletedStatus() async throws {
        let prompt = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath, "prompt": "go", "pid": 99999999]
        )
        mapper.handleEvent(prompt)

        let stop = AgentHookEvent(
            eventName: "Stop",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        )
        mapper.handleEvent(stop)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .taskCompleted)

        mapper.runCalibration()
        try await Task.sleep(for: .milliseconds(200))

        // .taskCompleted should NOT be cleared by a dead PID.
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .taskCompleted)
    }

    func testPidDeathClearsCompactingStatus() async throws {
        let prompt = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath, "prompt": "go", "pid": 99999999]
        )
        mapper.handleEvent(prompt)

        let compact = AgentHookEvent(
            eventName: "PreCompact",
            sessionId: "s1",
            rawJSON: ["cwd": worktreePath]
        )
        mapper.handleEvent(compact)
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .compacting)

        mapper.runCalibration()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(workspace.agentStatus(forWorktreePath: worktreePath), .none)
    }

    // MARK: - PID / CWD tracking (Task 15)

    func testCwdAndPidTrackedFromEvent() {
        let event = AgentHookEvent(
            eventName: "UserPromptSubmit",
            sessionId: "s1",
            rawJSON: ["cwd": "/some/path", "prompt": "hi", "pid": 12345]
        )
        // Should not crash; mapper stores pid and cwd internally.
        mapper.handleEvent(event)
    }

    // MARK: - Empty state (Task 16)

    func testCalibrationWithNoSessionsIsNoOp() {
        // Should not crash on empty state.
        mapper.runCalibration()
    }

    func testCalibrationStartStopIdempotent() {
        // startCalibration is idempotent; calling twice should not crash.
        mapper.startCalibration()
        mapper.startCalibration()
        // stopCalibration is also safe when already stopped.
        mapper.stopCalibration()
        mapper.stopCalibration()
    }
}
