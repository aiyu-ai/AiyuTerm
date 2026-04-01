//
//  TmuxServiceTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class TmuxServiceTests: XCTestCase {

    // MARK: - Session parsing with sessionID

    func testParseSessionsWithSessionID() {
        let output = "$0\tdev-server\t1\t3\n$1\tmonitoring\t0\t2\n$2\told-task\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].sessionID, "$0")
        XCTAssertEqual(sessions[0].name, "dev-server")
        XCTAssertEqual(sessions[0].isAttached, true)
        XCTAssertEqual(sessions[0].windowCount, 3)
        XCTAssertEqual(sessions[1].sessionID, "$1")
        XCTAssertEqual(sessions[1].name, "monitoring")
        XCTAssertEqual(sessions[1].isAttached, false)
        XCTAssertEqual(sessions[2].sessionID, "$2")
        XCTAssertEqual(sessions[2].windowCount, 1)
    }

    func testParseSessionsFromEmptyOutput() {
        let sessions = TmuxService.parseSessions(from: "")
        XCTAssertEqual(sessions, [])
    }

    func testParseSessionsSkipsMalformedLines() {
        let output = "$0\tgood\t1\t2\nbadline\n$1\tanother\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].sessionID, "$0")
        XCTAssertEqual(sessions[1].sessionID, "$1")
    }

    // MARK: - Attach arguments

    func testAttachArgumentsUsesSessionID() {
        let args = TmuxService.attachArguments(sessionID: "$0")
        XCTAssertEqual(args, ["-lc", "tmux set-option -g allow-passthrough on \\; set-option -g mouse on \\; attach -t '$0'"])
    }

    func testAttachArgumentsRejectsInvalidSessionID() {
        XCTAssertNil(TmuxService.attachArguments(sessionID: "not-an-id"))
        XCTAssertNil(TmuxService.attachArguments(sessionID: "$0; rm -rf /"))
        XCTAssertNil(TmuxService.attachArguments(sessionID: ""))
    }

    func testValidSessionIDs() {
        XCTAssertTrue(TmuxService.isValidSessionID("$0"))
        XCTAssertTrue(TmuxService.isValidSessionID("$123"))
        XCTAssertFalse(TmuxService.isValidSessionID("0"))
        XCTAssertFalse(TmuxService.isValidSessionID("$abc"))
        XCTAssertFalse(TmuxService.isValidSessionID(""))
    }

    // MARK: - Session name validation

    func testValidSessionNames() {
        XCTAssertTrue(TmuxSessionNameValidator.isValid("my-session"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("dev_server"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("task.123"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("ABC"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("a"))
    }

    func testInvalidSessionNames() {
        XCTAssertFalse(TmuxSessionNameValidator.isValid(""))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("has space"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("semi;colon"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("pipe|char"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("dollar$sign"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("back`tick"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("quote\"mark"))
    }
}
