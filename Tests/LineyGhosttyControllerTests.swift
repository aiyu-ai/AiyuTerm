//
//  LineyGhosttyControllerTests.swift
//  LineyTests
//
//  Author: Codex
//

import XCTest
import GhosttyKit
@testable import Liney

final class LineyGhosttyControllerTests: XCTestCase {
    func testCommandFinishedDoesNotReportProcessExit() {
        XCTAssertFalse(
            lineyGhosttyShouldReportProcessExitForCommandFinished(
                ghostty_action_command_finished_s(
                    exit_code: 0,
                    duration: 42
                )
            )
        )
    }

    func testSurfaceCloseWhileProcessIsAliveDoesNotReportProcessExit() {
        XCTAssertFalse(lineyGhosttyShouldReportProcessExitForSurfaceClose(processAlive: true))
    }

    func testSurfaceCloseAfterProcessExitReportsExit() {
        XCTAssertTrue(lineyGhosttyShouldReportProcessExitForSurfaceClose(processAlive: false))
    }
}
