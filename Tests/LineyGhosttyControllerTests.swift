//
//  AiyuTermGhosttyControllerTests.swift
//  AiyuTermTests
//
//  Author: Codex
//

import XCTest
import GhosttyKit
@testable import AiyuTerm

final class AiyuTermGhosttyControllerTests: XCTestCase {
    func testCommandFinishedDoesNotReportProcessExit() {
        XCTAssertFalse(
            aiyuTermGhosttyShouldReportProcessExitForCommandFinished(
                ghostty_action_command_finished_s(
                    exit_code: 0,
                    duration: 42
                )
            )
        )
    }

    func testSurfaceCloseWhileProcessIsAliveDoesNotReportProcessExit() {
        XCTAssertFalse(aiyuTermGhosttyShouldReportProcessExitForSurfaceClose(processAlive: true))
    }

    func testSurfaceCloseAfterProcessExitReportsExit() {
        XCTAssertTrue(aiyuTermGhosttyShouldReportProcessExitForSurfaceClose(processAlive: false))
    }

    func testSurfaceRefreshRunsWhenDisplayMetricsChange() {
        let previous = AiyuTermGhosttySurfaceMetricsSignature(
            width: 800,
            height: 600,
            scale: 2,
            displayID: 1
        )
        let next = AiyuTermGhosttySurfaceMetricsSignature(
            width: 800,
            height: 600,
            scale: 1,
            displayID: 2
        )

        XCTAssertTrue(aiyuTermGhosttyShouldRefreshSurface(after: previous, next: next))
        XCTAssertFalse(aiyuTermGhosttyShouldRefreshSurface(after: next, next: next))
    }
}
