//
//  AgentSessionStatusAggregationTests.swift
//  AiyuTermTests
//
//  Author: wuwenrui
//

import XCTest
@testable import AiyuTerm

final class AgentSessionStatusAggregationTests: XCTestCase {

    func testHighestPriorityStatusReturnsPermissionOverCompleted() {
        let statuses: [AgentSessionStatus] = [.taskCompleted, .permissionNeeded, .none]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testHighestPriorityStatusReturnsErrorOverCompleted() {
        let statuses: [AgentSessionStatus] = [.taskCompleted, .error, .none]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .error)
    }

    func testHighestPriorityStatusReturnsPermissionOverError() {
        let statuses: [AgentSessionStatus] = [.error, .permissionNeeded]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testHighestPriorityStatusReturnsNoneWhenAllNone() {
        let statuses: [AgentSessionStatus] = [.none, .none]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .none)
    }

    func testHighestPriorityStatusReturnsNoneForEmptyCollection() {
        let statuses: [AgentSessionStatus] = []
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .none)
    }

    func testHighestPriorityStatusReturnsCompletedOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .taskCompleted]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .taskCompleted)
    }

    func testHighestPriorityStatusReturnsErrorOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .error]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .error)
    }

    func testHighestPriorityStatusReturnsPermissionOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .permissionNeeded]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testWorkingIsNotUserDismissible() {
        XCTAssertFalse(AgentSessionStatus.working.isUserDismissible)
    }

    func testNoneIsNotUserDismissible() {
        XCTAssertFalse(AgentSessionStatus.none.isUserDismissible)
    }

    func testTaskCompletedIsNotUserDismissible() {
        // Only .error is user-dismissible (WorkspaceModels.swift:1456).
        // .taskCompleted and .permissionNeeded are "readable on interaction"
        // (shrink badge) but not fully dismissible to .none.
        XCTAssertFalse(AgentSessionStatus.taskCompleted.isUserDismissible)
    }

    func testPermissionNeededIsNotUserDismissible() {
        XCTAssertFalse(AgentSessionStatus.permissionNeeded.isUserDismissible)
    }

    func testErrorIsUserDismissible() {
        XCTAssertTrue(AgentSessionStatus.error.isUserDismissible)
    }

    func testWorkingIsVisible() {
        XCTAssertTrue(AgentSessionStatus.working.isVisible)
    }

    func testNoneIsNotVisible() {
        XCTAssertFalse(AgentSessionStatus.none.isVisible)
    }

    func testBadgeDisplayStateSpinnerForWorking() {
        XCTAssertEqual(AgentSessionStatus.working.badgeDisplayState(isUnread: false), .spinner)
    }

    func testBadgeDisplayStateCompletedUnreadWhenUnread() {
        XCTAssertEqual(AgentSessionStatus.taskCompleted.badgeDisplayState(isUnread: true), .completedUnread)
    }

    func testBadgeDisplayStateCompletedReadWhenRead() {
        XCTAssertEqual(AgentSessionStatus.taskCompleted.badgeDisplayState(isUnread: false), .completedRead)
    }

    func testBadgeDisplayStateHiddenForNone() {
        XCTAssertEqual(AgentSessionStatus.none.badgeDisplayState(isUnread: false), .hidden)
    }

    func testBadgeDisplayStatePermissionNeededRead() {
        // When isUnread is false, .permissionNeeded maps to .permissionNeededRead
        XCTAssertEqual(AgentSessionStatus.permissionNeeded.badgeDisplayState(isUnread: false), .permissionNeededRead)
    }

    func testBadgeDisplayStatePermissionNeededUnread() {
        XCTAssertEqual(AgentSessionStatus.permissionNeeded.badgeDisplayState(isUnread: true), .permissionNeeded)
    }

    func testBadgeDisplayStateError() {
        XCTAssertEqual(AgentSessionStatus.error.badgeDisplayState(isUnread: false), .error)
    }

    // MARK: - Compacting aggregation tests (P12.2)

    func testHighestPriorityStatusReturnsCompactingOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .compacting]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .compacting)
    }

    func testHighestPriorityStatusReturnsCompletedOverCompacting() {
        let statuses: [AgentSessionStatus] = [.compacting, .taskCompleted]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .taskCompleted)
    }

    func testCompactingBadgeDisplayStateIgnoresUnread() {
        // .compacting always maps to .compacting regardless of unread flag
        XCTAssertEqual(
            AgentSessionStatus.compacting.badgeDisplayState(isUnread: true),
            .compacting
        )
        XCTAssertEqual(
            AgentSessionStatus.compacting.badgeDisplayState(isUnread: false),
            .compacting
        )
    }
}
