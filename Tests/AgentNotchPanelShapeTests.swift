//
// AgentNotchPanelShapeTests.swift
// AiyuTermTests
//
// Phase 10.5 tests for AgentNotchPanelShape, AgentCLIAccent
// lookup, and AgentNotchDisplayOptions.
//

import Foundation
import SwiftUI
import XCTest
@testable import AiyuTerm

final class AgentNotchPanelShapeTests: XCTestCase {

    // MARK: - AgentNotchPanelShape

    func testNotchPanelShapeProducesNonEmptyPath() {
        let shape = AgentNotchPanelShape(topInverseRadius: 8, bottomRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 420, height: 360)
        let path = shape.path(in: rect)
        XCTAssertFalse(path.isEmpty)
    }

    func testNotchPanelShapeBoundingRectFits() {
        // The shape should render within the supplied rect
        // (plus a tiny control-point slop from the quad curves).
        let shape = AgentNotchPanelShape(topInverseRadius: 8, bottomRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 420, height: 360)
        let bounds = shape.path(in: rect).boundingRect
        XCTAssertEqual(bounds.origin.x, 0, accuracy: 1)
        XCTAssertEqual(bounds.origin.y, 0, accuracy: 1)
        XCTAssertLessThanOrEqual(bounds.maxX, rect.maxX + 1)
        XCTAssertLessThanOrEqual(bounds.maxY, rect.maxY + 1)
    }

    func testNotchPanelShapeRespectsDifferentRadii() {
        let smallRadii = AgentNotchPanelShape(topInverseRadius: 2, bottomRadius: 4)
        let largeRadii = AgentNotchPanelShape(topInverseRadius: 16, bottomRadius: 24)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)

        // Both produce non-empty paths without crashing.
        XCTAssertFalse(smallRadii.path(in: rect).isEmpty)
        XCTAssertFalse(largeRadii.path(in: rect).isEmpty)
    }

    func testNotchPanelShapeHandlesZeroRect() {
        // Zero-size rects shouldn't crash the shape builder.
        let shape = AgentNotchPanelShape(topInverseRadius: 8, bottomRadius: 14)
        _ = shape.path(in: CGRect.zero)
    }

    // MARK: - AgentCLIAccent

    func testAccentLookupForClaude() {
        let accent = AgentCLIAccent.accent(for: "claude")
        XCTAssertEqual(accent.displayName, "CLAUDE")
        XCTAssertEqual(accent.iconSystemName, "sparkle")
    }

    func testAccentLookupCaseInsensitive() {
        let lower = AgentCLIAccent.accent(for: "codex")
        let upper = AgentCLIAccent.accent(for: "CODEX")
        let mixed = AgentCLIAccent.accent(for: "Codex")
        XCTAssertEqual(lower.displayName, upper.displayName)
        XCTAssertEqual(mixed.displayName, upper.displayName)
    }

    func testAccentLookupUnknownSourceFallsBack() {
        let accent = AgentCLIAccent.accent(for: "unknowncli")
        XCTAssertEqual(accent.displayName, "UNKNOWNCLI")
        XCTAssertEqual(accent.iconSystemName, "terminal.fill")
    }

    func testAccentTableCoversAll9CLIs() {
        let expectedSources = [
            "claude", "codex", "gemini", "cursor", "copilot",
            "qoder", "codebuddy", "droid", "opencode",
        ]
        for source in expectedSources {
            XCTAssertNotNil(
                AgentCLIAccent.knownAccents[source],
                "Missing accent for \(source)"
            )
        }
    }

    // MARK: - AgentNotchDisplayOptions

    func testDisplayOptionsDefault() {
        let d = AgentNotchDisplayOptions.default
        XCTAssertEqual(d.maxVisibleSessions, 8)
        XCTAssertEqual(d.aiMessageLines, 3)
        XCTAssertTrue(d.showToolStatus)
        XCTAssertTrue(d.collapseOnMouseLeave)
        XCTAssertTrue(d.hideInFullscreen)
        XCTAssertFalse(d.hideWhenNoSession)
    }

    func testDisplayOptionsEquatable() {
        let a = AgentNotchDisplayOptions.default
        var b = AgentNotchDisplayOptions.default
        XCTAssertEqual(a, b)
        b.maxVisibleSessions = 16
        XCTAssertNotEqual(a, b)
    }

    // MARK: - View state caps worktrees by maxVisibleSessions

    func testSortedWorktreesRespectsMaxVisibleCap() {
        // Create 10 snapshots, cap at 3, assert we only see 3.
        let snapshots = (0..<10).map { i in
            AgentNotchWorktreeSnapshot(
                id: "/tmp/w\(i)",
                workspaceName: "ws",
                worktreeDisplayName: "wt",
                status: .working,
                source: "claude",
                model: nil,
                cwd: nil,
                currentTool: nil,
                toolDescription: nil,
                lastAssistantMessage: nil,
                lastUserPrompt: nil,
                permissionRequest: nil,
                questionRequest: nil,
                resolvedTitle: nil
            )
        }
        var display = AgentNotchDisplayOptions.default
        display.maxVisibleSessions = 3
        let state = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: snapshots,
            display: display
        )
        XCTAssertEqual(state.sortedWorktrees.count, 3)
    }

    func testSortedWorktreesDoesNotExpandWhenUnderCap() {
        let snapshots = [
            AgentNotchWorktreeSnapshot(
                id: "/tmp/a",
                workspaceName: "ws",
                worktreeDisplayName: "wt",
                status: .working,
                source: "claude",
                model: nil,
                cwd: nil,
                currentTool: nil,
                toolDescription: nil,
                lastAssistantMessage: nil,
                lastUserPrompt: nil,
                permissionRequest: nil,
                questionRequest: nil,
                resolvedTitle: nil
            ),
        ]
        var display = AgentNotchDisplayOptions.default
        display.maxVisibleSessions = 30
        let state = AgentNotchViewState(
            aggregatedStatus: .working,
            pendingCount: 0,
            worktrees: snapshots,
            display: display
        )
        XCTAssertEqual(state.sortedWorktrees.count, 1)
    }
}
