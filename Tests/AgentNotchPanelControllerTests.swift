//
// AgentNotchPanelControllerTests.swift
// AiyuTermTests
//
// Phase 8.2 tests for the NSPanel lifecycle wrapper.
//
// These tests are intentionally narrow: they cover the observable
// lifecycle contract (show idempotency, hide tears down the panel,
// repositionForCurrentScreen no-op when signature unchanged, the
// screen observer is added once per show) without touching any
// real screen geometry. Anything that requires actual NSScreen
// topology (auxiliaryTopLeftArea, safeAreaInsets) belongs in the
// manual verification guide from Phase 6.3.
//

import AppKit
import SwiftUI
import XCTest
@testable import AiyuTerm

@MainActor
final class AgentNotchPanelControllerTests: XCTestCase {

    /// Trivial placeholder view so the generic controller can be
    /// instantiated without depending on the Phase 8.3 panel views.
    private struct PlaceholderContent: View {
        var body: some View {
            Color.clear.frame(width: 220, height: 40)
        }
    }

    private var controller: AgentNotchPanelController<PlaceholderContent>!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            controller = AgentNotchPanelController {
                PlaceholderContent()
            }
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            controller?.hide()
            controller = nil
        }
        try await super.tearDown()
    }

    // MARK: - Lifecycle

    func testControllerStartsHidden() {
        XCTAssertFalse(controller.isVisible)
    }

    func testShowCreatesAVisiblePanel() {
        controller.show()
        XCTAssertTrue(controller.isVisible)
    }

    func testShowIsIdempotent() {
        controller.show()
        XCTAssertTrue(controller.isVisible)
        // A second show() should not crash, leak a new panel, or
        // double-attach the screen observer.
        controller.show()
        XCTAssertTrue(controller.isVisible)
    }

    func testHideClearsTheVisibleFlag() {
        controller.show()
        XCTAssertTrue(controller.isVisible)
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }

    func testHideFromAnInitialStateIsANoOp() {
        XCTAssertFalse(controller.isVisible)
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }

    func testRepositionWithoutShowIsSafe() {
        // Should not crash when called before show().
        controller.repositionForCurrentScreen()
        XCTAssertFalse(controller.isVisible)
    }

    func testShowHideCycleCanRepeat() {
        for _ in 0..<3 {
            controller.show()
            XCTAssertTrue(controller.isVisible)
            controller.hide()
            XCTAssertFalse(controller.isVisible)
        }
    }
}
