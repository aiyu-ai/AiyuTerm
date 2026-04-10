//
// AgentTerminalVisibilityHelpersTests.swift
// AiyuTermTests
//
// Phase 9.4 tests for the pure helpers extracted from
// AgentTerminalVisibilityDetector. These cover the routing
// logic, WezTerm/Kitty JSON parsing, tmux pane-id translation,
// and the app-level frontmost match.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentTerminalVisibilityHelpersTests: XCTestCase {

    // MARK: - routeTabCheck

    func testRouteTabCheckByBundleIdGhostty() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: "com.mitchellh.ghostty",
                termApp: nil
            ),
            .ghostty
        )
    }

    func testRouteTabCheckByBundleIdIterm() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: "com.googlecode.iterm2",
                termApp: nil
            ),
            .iTerm
        )
    }

    func testRouteTabCheckByBundleIdTerminalApp() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: "com.apple.terminal",
                termApp: "Apple_Terminal"
            ),
            .terminalApp
        )
    }

    func testRouteTabCheckWezTermByBundleId() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: "com.github.wez.wezterm",
                termApp: nil
            ),
            .wezterm
        )
    }

    func testRouteTabCheckKittyByBundleId() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: "net.kovidgoyal.kitty",
                termApp: nil
            ),
            .kitty
        )
    }

    func testRouteTabCheckFallsBackToTermApp() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: nil,
                termApp: "iTerm.app"
            ),
            .iTerm
        )
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: nil,
                termApp: "ghostty"
            ),
            .ghostty
        )
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: nil,
                termApp: "WezTerm"
            ),
            .wezterm
        )
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: nil,
                termApp: "kitty"
            ),
            .kitty
        )
    }

    func testRouteTabCheckDoesNotRouteWarpToTerminalApp() {
        // Warp sets TERM_PROGRAM=Apple_Terminal, so if we routed by
        // TERM_PROGRAM we'd misclassify it. The fallback must NOT
        // match "terminal" — only bundle ID == com.apple.terminal
        // returns .terminalApp.
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: nil,
                termApp: "Apple_Terminal"
            ),
            .unknown
        )
    }

    func testRouteTabCheckUnknown() {
        XCTAssertEqual(
            AgentTerminalVisibilityHelpers.routeTabCheck(
                termBundleId: nil,
                termApp: "Rio"
            ),
            .unknown
        )
    }

    // MARK: - matchesFrontmost

    private func snapshot(
        termBundleId: String? = nil,
        termApp: String? = nil
    ) -> AgentSessionSnapshot {
        var s = AgentSessionSnapshot()
        s.termBundleId = termBundleId
        s.termApp = termApp
        return s
    }

    func testMatchesFrontmostBundleIdExclusive() {
        // Warp scenario: termBundleId is Warp, TERM_PROGRAM would be
        // Apple_Terminal. We only consult the bundle ID.
        let session = snapshot(
            termBundleId: "dev.warp.Warp-Stable",
            termApp: "Apple_Terminal"
        )
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.matchesFrontmost(
                session: session,
                frontBundleId: "dev.warp.Warp-Stable",
                frontLocalizedName: "Warp"
            )
        )
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.matchesFrontmost(
                session: session,
                frontBundleId: "com.apple.Terminal",
                frontLocalizedName: "Terminal"
            )
        )
    }

    func testMatchesFrontmostFallsBackToTermApp() {
        let session = snapshot(termBundleId: nil, termApp: "iTerm.app")
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.matchesFrontmost(
                session: session,
                frontBundleId: "com.googlecode.iterm2",
                frontLocalizedName: "iTerm"
            )
        )
    }

    func testMatchesFrontmostFailsWhenFrontmostIsOther() {
        let session = snapshot(termBundleId: "com.mitchellh.ghostty")
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.matchesFrontmost(
                session: session,
                frontBundleId: "com.apple.Finder",
                frontLocalizedName: "Finder"
            )
        )
    }

    func testMatchesFrontmostReturnsFalseWhenNoTerminalInfo() {
        let session = snapshot(termBundleId: nil, termApp: nil)
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.matchesFrontmost(
                session: session,
                frontBundleId: "com.mitchellh.ghostty",
                frontLocalizedName: "Ghostty"
            )
        )
    }

    // MARK: - wezTermActivePaneMatches

    func testWezTermActivePaneMatchesByTty() {
        let panes: [[String: Any]] = [
            ["is_active": false, "tty_name": "/dev/ttys000"],
            ["is_active": true, "tty_name": "/dev/ttys001", "cwd": "/Users/me"],
        ]
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.wezTermActivePaneMatches(
                panes: panes,
                expectedTty: "/dev/ttys001",
                expectedCwd: nil
            )
        )
    }

    func testWezTermActivePaneFailsWhenTtyDiffers() {
        let panes: [[String: Any]] = [
            ["is_active": true, "tty_name": "/dev/ttys000"],
        ]
        // When TTY is supplied and differs, the CWD fallback is
        // NOT consulted — we trust the TTY exclusively.
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.wezTermActivePaneMatches(
                panes: panes,
                expectedTty: "/dev/ttys999",
                expectedCwd: "/Users/me"
            )
        )
    }

    func testWezTermActivePaneMatchesByCwd() {
        let panes: [[String: Any]] = [
            ["is_active": true, "cwd": "/Users/me/project"],
        ]
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.wezTermActivePaneMatches(
                panes: panes,
                expectedTty: nil,
                expectedCwd: "/Users/me/project"
            )
        )
    }

    func testWezTermActivePaneMatchesFileUrlCwd() {
        let panes: [[String: Any]] = [
            ["is_active": true, "cwd": "file:///Users/me/project"],
        ]
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.wezTermActivePaneMatches(
                panes: panes,
                expectedTty: nil,
                expectedCwd: "/Users/me/project"
            )
        )
    }

    func testWezTermActivePaneNoActive() {
        let panes: [[String: Any]] = [
            ["is_active": false, "cwd": "/Users/me"],
        ]
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.wezTermActivePaneMatches(
                panes: panes,
                expectedTty: "/dev/ttys000",
                expectedCwd: "/Users/me"
            )
        )
    }

    // MARK: - kittyFocusedWindowMatches

    func testKittyFocusedWindowMatchesById() {
        let osWindows: [[String: Any]] = [
            [
                "is_focused": true,
                "tabs": [
                    [
                        "is_focused": true,
                        "windows": [
                            ["is_focused": true, "id": 42],
                        ],
                    ]
                ],
            ]
        ]
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.kittyFocusedWindowMatches(
                osWindows: osWindows,
                expectedWindowId: "42"
            )
        )
    }

    func testKittyFocusedWindowFailsWhenIdDiffers() {
        let osWindows: [[String: Any]] = [
            [
                "is_focused": true,
                "tabs": [
                    [
                        "is_focused": true,
                        "windows": [
                            ["is_focused": true, "id": 42],
                        ],
                    ]
                ],
            ]
        ]
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.kittyFocusedWindowMatches(
                osWindows: osWindows,
                expectedWindowId: "99"
            )
        )
    }

    func testKittyFocusedWindowFailsWhenNoFocusedWindow() {
        let osWindows: [[String: Any]] = [
            [
                "is_focused": false,
                "tabs": [],
            ]
        ]
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.kittyFocusedWindowMatches(
                osWindows: osWindows,
                expectedWindowId: "42"
            )
        )
    }

    // MARK: - tmuxPaneMatches

    func testTmuxPaneMatchesDirectId() {
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.tmuxPaneMatches(
                pane: "main:1.0",
                activePaneId: "main:1.0",
                listPanesOutput: ""
            )
        )
    }

    func testTmuxPaneTranslatesPercentToFriendly() {
        let listOutput = """
        %0 main:0.0
        %1 main:1.0
        %2 main:1.1
        """
        XCTAssertTrue(
            AgentTerminalVisibilityHelpers.tmuxPaneMatches(
                pane: "%1",
                activePaneId: "main:1.0",
                listPanesOutput: listOutput
            )
        )
    }

    func testTmuxPaneDoesNotMatchDifferentPane() {
        let listOutput = """
        %0 main:0.0
        %1 main:1.0
        """
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.tmuxPaneMatches(
                pane: "%0",
                activePaneId: "main:1.0",
                listPanesOutput: listOutput
            )
        )
    }

    func testTmuxPaneFallsBackToDirectCompareWhenNotInList() {
        // Unrelated pane not in the list — fall back to comparing
        // the strings directly.
        XCTAssertFalse(
            AgentTerminalVisibilityHelpers.tmuxPaneMatches(
                pane: "%99",
                activePaneId: "main:1.0",
                listPanesOutput: "%0 main:0.0"
            )
        )
    }
}
