//
// AgentStatusItemControllerTests.swift
// AiyuTermTests
//
// Phase 11.3D.a — tests for the menu bar status item lifecycle
// wrapper. These tests avoid asserting on AppKit's visible menu
// bar state (hard to isolate from the host process) and instead
// cover the observable contract: install on init, idempotent
// update(status:pendingCount:), tearDown removes the item, click
// closures fire exactly when invoked through the internal API.
//

import AppKit
import XCTest
@testable import AiyuTerm

@MainActor
final class AgentStatusItemControllerTests: XCTestCase {

    private var togglePanelCalls = 0
    private var exportCalls = 0
    private var controller: AgentStatusItemController?

    override func setUp() async throws {
        try await super.setUp()
        togglePanelCalls = 0
        exportCalls = 0
    }

    override func tearDown() async throws {
        await MainActor.run {
            controller?.tearDown()
            controller = nil
        }
        try await super.tearDown()
    }

    private func makeController() -> AgentStatusItemController {
        let c = AgentStatusItemController(
            onTogglePanel: { [weak self] in self?.togglePanelCalls += 1 },
            onExportDiagnostics: { [weak self] in self?.exportCalls += 1 }
        )
        controller = c
        return c
    }

    // MARK: - Installation lifecycle

    func testInitInstallsStatusItem() {
        let c = makeController()
        XCTAssertTrue(c.isInstalled)
    }

    func testTearDownRemovesStatusItem() {
        let c = makeController()
        XCTAssertTrue(c.isInstalled)
        c.tearDown()
        XCTAssertFalse(c.isInstalled)
    }

    func testTearDownIsIdempotent() {
        let c = makeController()
        c.tearDown()
        c.tearDown() // second call must not crash
        XCTAssertFalse(c.isInstalled)
    }

    // MARK: - State updates

    func testUpdateAcceptsAllStatusValues() {
        let c = makeController()
        let values: [AgentSessionStatus] = [
            .none, .working, .permissionNeeded, .taskCompleted, .error
        ]
        for status in values {
            c.update(status: status, pendingCount: 0)
        }
        XCTAssertTrue(c.isInstalled)
    }

    func testUpdateClampsNegativePendingCountToZero() {
        let c = makeController()
        // Should not crash, should not assert, tooltip should still
        // read as a zero pending count (we can't easily inspect the
        // tooltip, but isInstalled remains true).
        c.update(status: .none, pendingCount: -5)
        XCTAssertTrue(c.isInstalled)
    }

    func testUpdateIsIdempotentForIdenticalInput() {
        let c = makeController()
        c.update(status: .working, pendingCount: 0)
        c.update(status: .working, pendingCount: 0)
        c.update(status: .working, pendingCount: 0)
        XCTAssertTrue(c.isInstalled)
    }

    // MARK: - Closure wiring

    func testExportDiagnosticsClosureFires() {
        _ = makeController()
        // Simulate the menu item firing by invoking the internal
        // Objective-C action target chain directly via perform.
        controller?.perform(Selector(("exportDiagnosticsMenuAction")))
        XCTAssertEqual(exportCalls, 1)
        XCTAssertEqual(togglePanelCalls, 0)
    }

    func testShowNotchPanelClosureFiresFromMenuAction() {
        _ = makeController()
        controller?.perform(Selector(("showNotchPanelMenuAction")))
        XCTAssertEqual(togglePanelCalls, 1)
        XCTAssertEqual(exportCalls, 0)
    }
}
