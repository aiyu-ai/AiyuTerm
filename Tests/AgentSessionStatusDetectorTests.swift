//
//  AgentSessionStatusDetectorTests.swift
//  LineyTests
//
//  Author: everettjf
//

import XCTest
@testable import Liney

final class AgentSessionStatusDetectorTests: XCTestCase {

    func testDetectsPermissionNeededFromClaudeCodeNotification() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Permission needed to execute command"
        )
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testDetectsPermissionNeededCaseInsensitive() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "PERMISSION NEEDED to run shell command"
        )
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testDetectsPermissionNeededFromApproveKeyword() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Waiting for user to approve tool use"
        )
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testDetectsTaskCompletedFromClaudeCodeNotification() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Task completed successfully"
        )
        XCTAssertEqual(result, .taskCompleted)
    }

    func testDetectsTaskCompletedFromFinishedKeyword() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Task finished"
        )
        XCTAssertEqual(result, .taskCompleted)
    }

    func testDetectsErrorFromClaudeCodeNotification() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Error: failed to read file"
        )
        XCTAssertEqual(result, .error)
    }

    func testDetectsErrorFromFailedKeyword() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Command failed with exit code 1"
        )
        XCTAssertEqual(result, .error)
    }

    func testReturnsNoneForUnrelatedNotification() {
        let result = AgentSessionStatusDetector.detect(
            title: "Terminal",
            body: "Process exited normally"
        )
        XCTAssertEqual(result, .none)
    }

    func testReturnsNoneForNilBody() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: nil
        )
        XCTAssertEqual(result, .none)
    }

    func testReturnsNoneForEmptyBody() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: ""
        )
        XCTAssertEqual(result, .none)
    }

    func testPermissionTakesPriorityOverError() {
        let result = AgentSessionStatusDetector.detect(
            title: "Claude Code",
            body: "Permission needed: error occurred but awaiting approval"
        )
        XCTAssertEqual(result, .permissionNeeded)
    }
}
