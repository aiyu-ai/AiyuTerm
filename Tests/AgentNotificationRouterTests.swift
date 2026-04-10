//
// AgentNotificationRouterTests.swift
// AiyuTermTests
//
// Phase 10.1.c smoke tests for the smart-suppress notification
// router. The router's actual delivery is unobservable in a unit
// test (no UNNotificationCenter harness), so this suite focuses
// on the pure paths that don't depend on NSWorkspace state:
// request-auth and notify-task-completed must be callable on a
// freshly-built snapshot without crashing.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentNotificationRouterTests: XCTestCase {

    func testRequestAuthIfNeededDoesNotCrash() {
        // Runs on the main actor by signature; we wrap in a
        // blocking expectation so the UNUserNotificationCenter
        // callback (which fires asynchronously) is observable.
        let expectation = expectation(description: "requestAuth returns")
        Task { @MainActor in
            AgentNotificationRouter.requestAuthIfNeeded()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testNotifyTaskCompletedRunsWithoutThrowing() {
        // Construct a minimal snapshot. The test runner is not a
        // terminal app, so the visibility check will return
        // false and the router will attempt to deliver — which
        // is fine, UNUserNotificationCenter silently drops the
        // request when auth hasn't been granted.
        var snapshot = AgentSessionSnapshot(startTime: Date())
        snapshot.source = "claude"
        snapshot.cwd = "/tmp/aiyuterm-test"

        // The router dispatches to main + background queues
        // asynchronously, so we just verify the call site does
        // not crash synchronously.
        AgentNotificationRouter.notifyTaskCompleted(session: snapshot)

        // Give the async work a moment to complete so any
        // crash in the background stage surfaces before the
        // test tears down.
        let done = expectation(description: "async work settles")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
    }

    func testVisibilityDetectorFrontmostCheckReturnsBoolForEmptySnapshot() {
        // The underlying detector compares against the current
        // frontmost app. In a test runner, that's xctest — which
        // does not match any terminal app, so the check should
        // return false without crashing.
        var snapshot = AgentSessionSnapshot(startTime: Date())
        snapshot.source = "claude"
        Task { @MainActor in
            let result = AgentTerminalVisibilityDetector
                .isTerminalFrontmostForSession(snapshot)
            XCTAssertFalse(result, "test runner is not a terminal app")
        }
    }
}
