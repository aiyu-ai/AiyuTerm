//
//  AgentSessionStatusTransitionTests.swift
//  AiyuTermTests
//
//  Tests for AgentSessionStatus.canTransition(to:) validation matrix
//  and updated priority values (P12.1).
//
//  Author: wuwenrui
//

import XCTest
@testable import AiyuTerm

final class AgentSessionStatusTransitionTests: XCTestCase {

    // MARK: - Self-transition (always allowed)

    func testSelfTransitionAlwaysAllowed() {
        let allStatuses: [AgentSessionStatus] = [
            .none, .working, .compacting, .permissionNeeded, .taskCompleted, .error,
        ]
        for status in allStatuses {
            XCTAssertTrue(
                status.canTransition(to: status),
                "\(status) -> \(status) should be allowed"
            )
        }
    }

    // MARK: - .none -> anything (allowed)

    func testNoneCanTransitionToAnything() {
        let targets: [AgentSessionStatus] = [
            .working, .compacting, .permissionNeeded, .taskCompleted, .error,
        ]
        for target in targets {
            XCTAssertTrue(
                AgentSessionStatus.none.canTransition(to: target),
                ".none -> \(target) should be allowed"
            )
        }
    }

    // MARK: - .working -> anything (allowed)

    func testWorkingCanTransitionToAnything() {
        let targets: [AgentSessionStatus] = [
            .none, .compacting, .permissionNeeded, .taskCompleted, .error,
        ]
        for target in targets {
            XCTAssertTrue(
                AgentSessionStatus.working.canTransition(to: target),
                ".working -> \(target) should be allowed"
            )
        }
    }

    // MARK: - .compacting transitions

    func testCompactingAllowedTransitions() {
        let allowed: [AgentSessionStatus] = [.working, .taskCompleted, .error, .none]
        for target in allowed {
            XCTAssertTrue(
                AgentSessionStatus.compacting.canTransition(to: target),
                ".compacting -> \(target) should be allowed"
            )
        }
    }

    func testCompactingBlockedTransitions() {
        let blocked: [AgentSessionStatus] = [.permissionNeeded]
        for target in blocked {
            XCTAssertFalse(
                AgentSessionStatus.compacting.canTransition(to: target),
                ".compacting -> \(target) should be blocked"
            )
        }
    }

    // MARK: - .permissionNeeded transitions

    func testPermissionNeededAllowedTransitions() {
        let allowed: [AgentSessionStatus] = [.working, .none, .error]
        for target in allowed {
            XCTAssertTrue(
                AgentSessionStatus.permissionNeeded.canTransition(to: target),
                ".permissionNeeded -> \(target) should be allowed"
            )
        }
    }

    func testPermissionNeededBlockedTransitions() {
        let blocked: [AgentSessionStatus] = [.taskCompleted, .compacting]
        for target in blocked {
            XCTAssertFalse(
                AgentSessionStatus.permissionNeeded.canTransition(to: target),
                ".permissionNeeded -> \(target) should be blocked"
            )
        }
    }

    // MARK: - .taskCompleted transitions

    func testTaskCompletedAllowedTransitions() {
        let allowed: [AgentSessionStatus] = [.working, .none]
        for target in allowed {
            XCTAssertTrue(
                AgentSessionStatus.taskCompleted.canTransition(to: target),
                ".taskCompleted -> \(target) should be allowed"
            )
        }
    }

    func testTaskCompletedBlockedTransitions() {
        let blocked: [AgentSessionStatus] = [.compacting, .permissionNeeded, .error]
        for target in blocked {
            XCTAssertFalse(
                AgentSessionStatus.taskCompleted.canTransition(to: target),
                ".taskCompleted -> \(target) should be blocked"
            )
        }
    }

    // MARK: - .error transitions

    func testErrorAllowedTransitions() {
        let allowed: [AgentSessionStatus] = [.working, .none]
        for target in allowed {
            XCTAssertTrue(
                AgentSessionStatus.error.canTransition(to: target),
                ".error -> \(target) should be allowed"
            )
        }
    }

    func testErrorBlockedTransitions() {
        let blocked: [AgentSessionStatus] = [.compacting, .permissionNeeded, .taskCompleted]
        for target in blocked {
            XCTAssertFalse(
                AgentSessionStatus.error.canTransition(to: target),
                ".error -> \(target) should be blocked"
            )
        }
    }

    // MARK: - Priority ordering

    func testPriorityPermissionNeededIsHighest() {
        let statuses: [AgentSessionStatus] = [
            .none, .working, .compacting, .taskCompleted, .error, .permissionNeeded,
        ]
        XCTAssertEqual(AgentSessionStatus.highestPriority(in: statuses), .permissionNeeded)
    }

    func testPriorityErrorOverCompletedAndCompacting() {
        let statuses: [AgentSessionStatus] = [.compacting, .taskCompleted, .error]
        XCTAssertEqual(AgentSessionStatus.highestPriority(in: statuses), .error)
    }

    func testPriorityCompletedOverCompacting() {
        let statuses: [AgentSessionStatus] = [.compacting, .taskCompleted]
        XCTAssertEqual(AgentSessionStatus.highestPriority(in: statuses), .taskCompleted)
    }

    func testPriorityCompactingOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .compacting]
        XCTAssertEqual(AgentSessionStatus.highestPriority(in: statuses), .compacting)
    }

    func testPriorityWorkingOverNone() {
        let statuses: [AgentSessionStatus] = [.none, .working]
        XCTAssertEqual(AgentSessionStatus.highestPriority(in: statuses), .working)
    }

    // MARK: - Badge display state for compacting

    func testCompactingBadgeDisplayState() {
        XCTAssertEqual(
            AgentSessionStatus.compacting.badgeDisplayState(isUnread: true),
            .compacting
        )
        XCTAssertEqual(
            AgentSessionStatus.compacting.badgeDisplayState(isUnread: false),
            .compacting
        )
    }

    // MARK: - Computed properties for .compacting

    func testCompactingIsActionable() {
        XCTAssertTrue(AgentSessionStatus.compacting.isActionable)
    }

    func testCompactingIsVisible() {
        XCTAssertTrue(AgentSessionStatus.compacting.isVisible)
    }

    func testCompactingIsNotUserDismissible() {
        XCTAssertFalse(AgentSessionStatus.compacting.isUserDismissible)
    }

    func testCompactingIsNotReadableOnInteraction() {
        XCTAssertFalse(AgentSessionStatus.compacting.isReadableOnInteraction)
    }
}
