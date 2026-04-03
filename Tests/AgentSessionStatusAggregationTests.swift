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
}
