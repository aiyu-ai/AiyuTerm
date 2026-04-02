//
//  TmuxAttachCoordinatorTests.swift
//  AiyuTermTests
//
//  Author: everettjf
//

import XCTest
@testable import Liney

@MainActor
final class TmuxAttachCoordinatorTests: XCTestCase {

    func testRegisterAndLookup() async {
        let coordinator = TmuxAttachCoordinator()
        let storeID = UUID()
        let shellID = UUID()
        coordinator.register(sessionID: "$0", storeID: storeID, shellSessionID: shellID)
        XCTAssertTrue(coordinator.isAttached("$0"))
        XCTAssertEqual(coordinator.shellSessionID(for: "$0"), shellID)
        XCTAssertEqual(coordinator.storeID(for: "$0"), storeID)
    }

    func testUnregister() async {
        let coordinator = TmuxAttachCoordinator()
        coordinator.register(sessionID: "$0", storeID: UUID(), shellSessionID: UUID())
        coordinator.unregister(sessionID: "$0")
        XCTAssertFalse(coordinator.isAttached("$0"))
        XCTAssertNil(coordinator.shellSessionID(for: "$0"))
    }

    func testIsAttachedReturnsFalseForUnknown() async {
        let coordinator = TmuxAttachCoordinator()
        XCTAssertFalse(coordinator.isAttached("$99"))
    }

    func testCleanupRemovesStaleEntries() async {
        let coordinator = TmuxAttachCoordinator()
        coordinator.register(sessionID: "$0", storeID: UUID(), shellSessionID: UUID())
        coordinator.register(sessionID: "$1", storeID: UUID(), shellSessionID: UUID())
        let activeSessions: Set<String> = ["$1"]
        coordinator.cleanup(activeSessionIDs: activeSessions)
        XCTAssertFalse(coordinator.isAttached("$0"))
        XCTAssertTrue(coordinator.isAttached("$1"))
    }
}
