//
//  TmuxServiceTests.swift
//  LineyTests
//
//  Author: everettjf
//

import XCTest
@testable import Liney

final class TmuxServiceTests: XCTestCase {

    func testParseSessionsFromTypicalOutput() {
        let output = "dev-server\t1\t3\nmonitoring\t0\t2\nold-task\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].name, "dev-server")
        XCTAssertEqual(sessions[0].isAttached, true)
        XCTAssertEqual(sessions[0].windowCount, 3)
        XCTAssertEqual(sessions[1].name, "monitoring")
        XCTAssertEqual(sessions[1].isAttached, false)
        XCTAssertEqual(sessions[1].windowCount, 2)
        XCTAssertEqual(sessions[2].name, "old-task")
        XCTAssertEqual(sessions[2].isAttached, false)
        XCTAssertEqual(sessions[2].windowCount, 1)
    }

    func testParseSessionsFromEmptyOutput() {
        let sessions = TmuxService.parseSessions(from: "")
        XCTAssertEqual(sessions, [])
    }

    func testParseSessionsSkipsMalformedLines() {
        let output = "good-session\t1\t2\nbadline\n\nanother-good\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].name, "good-session")
        XCTAssertEqual(sessions[1].name, "another-good")
    }

    func testParseWindowsFromTypicalOutput() {
        let output = "0\teditor\t0\n1\tserver\t1\n2\tlogs\t0\n"
        let windows = TmuxService.parseWindows(from: output, sessionName: "dev-server")
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows[0].sessionName, "dev-server")
        XCTAssertEqual(windows[0].index, 0)
        XCTAssertEqual(windows[0].name, "editor")
        XCTAssertEqual(windows[0].isActive, false)
        XCTAssertEqual(windows[1].index, 1)
        XCTAssertEqual(windows[1].name, "server")
        XCTAssertEqual(windows[1].isActive, true)
        XCTAssertEqual(windows[2].index, 2)
        XCTAssertEqual(windows[2].name, "logs")
        XCTAssertEqual(windows[2].isActive, false)
    }

    func testParseWindowsFromEmptyOutput() {
        let windows = TmuxService.parseWindows(from: "", sessionName: "test")
        XCTAssertEqual(windows, [])
    }

    func testParseWindowsSkipsMalformedLines() {
        let output = "0\teditor\t1\nbadline\n2\tlogs\t0\n"
        let windows = TmuxService.parseWindows(from: output, sessionName: "s")
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].index, 0)
        XCTAssertEqual(windows[1].index, 2)
    }

    func testAttachCommandForSessionAndWindow() {
        let args = TmuxService.attachArguments(session: "dev-server", windowIndex: 1)
        XCTAssertEqual(args, ["-lc", "tmux attach -t dev-server \\; select-window -t 1"])
    }

    func testAttachCommandEscapesSessionName() {
        let args = TmuxService.attachArguments(session: "my session", windowIndex: 0)
        XCTAssertEqual(args, ["-lc", "tmux attach -t 'my session' \\; select-window -t 0"])
    }
}
