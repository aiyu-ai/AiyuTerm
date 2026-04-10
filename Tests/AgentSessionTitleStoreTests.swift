//
// AgentSessionTitleStoreTests.swift
// AiyuTermTests
//
// Phase 9.5 tests for AgentSessionTitleStore's pure parsers.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentSessionTitleStoreTests: XCTestCase {

    // MARK: - supports

    func testSupportsClaudeAndCodex() {
        XCTAssertTrue(AgentSessionTitleStore.supports(provider: "claude"))
        XCTAssertTrue(AgentSessionTitleStore.supports(provider: "codex"))
    }

    func testSupportsRejectsOtherProviders() {
        XCTAssertFalse(AgentSessionTitleStore.supports(provider: "gemini"))
        XCTAssertFalse(AgentSessionTitleStore.supports(provider: "opencode"))
        XCTAssertFalse(AgentSessionTitleStore.supports(provider: ""))
    }

    // MARK: - Codex parser

    func testCodexParserReturnsMatchingThreadName() throws {
        let contents = """
        {"id":"sid-1","thread_name":"First","updated_at":"2026-04-10T10:00:00Z"}
        {"id":"sid-2","thread_name":"Other","updated_at":"2026-04-10T11:00:00Z"}
        """
        let result = try AgentSessionTitleStore.codexThreadName(
            sessionId: "sid-1",
            indexContents: contents
        )
        XCTAssertEqual(result, "First")
    }

    func testCodexParserPicksMostRecentEntry() throws {
        // Two entries for the same sessionId — we should pick the
        // one with the highest updated_at.
        let contents = """
        {"id":"sid-1","thread_name":"Old","updated_at":"2026-04-10T10:00:00Z"}
        {"id":"sid-1","thread_name":"New","updated_at":"2026-04-10T12:00:00Z"}
        {"id":"sid-1","thread_name":"Mid","updated_at":"2026-04-10T11:00:00Z"}
        """
        let result = try AgentSessionTitleStore.codexThreadName(
            sessionId: "sid-1",
            indexContents: contents
        )
        XCTAssertEqual(result, "New")
    }

    func testCodexParserSkipsEmptyTitles() throws {
        let contents = """
        {"id":"sid-1","thread_name":"   ","updated_at":"2026-04-10T10:00:00Z"}
        {"id":"sid-1","thread_name":"Actual","updated_at":"2026-04-10T11:00:00Z"}
        """
        let result = try AgentSessionTitleStore.codexThreadName(
            sessionId: "sid-1",
            indexContents: contents
        )
        XCTAssertEqual(result, "Actual")
    }

    func testCodexParserReturnsNilWhenNoMatch() throws {
        let contents = """
        {"id":"sid-2","thread_name":"Other","updated_at":"2026-04-10T10:00:00Z"}
        """
        let result = try AgentSessionTitleStore.codexThreadName(
            sessionId: "sid-1",
            indexContents: contents
        )
        XCTAssertNil(result)
    }

    func testCodexParserIgnoresMalformedLines() throws {
        let contents = """
        not json
        {"id":"sid-1","thread_name":"Good","updated_at":"2026-04-10T10:00:00Z"}
        {broken
        """
        let result = try AgentSessionTitleStore.codexThreadName(
            sessionId: "sid-1",
            indexContents: contents
        )
        XCTAssertEqual(result, "Good")
    }

    // MARK: - Claude parser

    func testClaudeTitlesParsesCustomAndAi() {
        let contents = """
        {"type":"custom-title","customTitle":"Custom!"}
        {"type":"ai-title","aiTitle":"AI suggested"}
        {"type":"other","whatever":1}
        """
        let titles = AgentSessionTitleStore.latestClaudeTitles(in: contents)
        XCTAssertEqual(titles.custom, "Custom!")
        XCTAssertEqual(titles.ai, "AI suggested")
    }

    func testClaudeTitlesPreferLatestCustom() {
        let contents = """
        {"type":"custom-title","customTitle":"First"}
        {"type":"custom-title","customTitle":"Second"}
        """
        let titles = AgentSessionTitleStore.latestClaudeTitles(in: contents)
        XCTAssertEqual(titles.custom, "Second")
    }

    func testClaudeTitlesTrimsWhitespace() {
        let contents = """
        {"type":"custom-title","customTitle":"   "}
        {"type":"custom-title","customTitle":"   Valid   "}
        """
        let titles = AgentSessionTitleStore.latestClaudeTitles(in: contents)
        XCTAssertEqual(titles.custom, "Valid")
    }

    func testClaudeTitlesIgnoresMalformed() {
        let contents = """
        broken line
        {"type":"custom-title","customTitle":"Good"}
        """
        let titles = AgentSessionTitleStore.latestClaudeTitles(in: contents)
        XCTAssertEqual(titles.custom, "Good")
    }

    // MARK: - resolveClaudeTitleFromChunks

    func testResolveClaudeCustomBeatsAi() {
        let head = ""
        let tail = """
        {"type":"custom-title","customTitle":"Custom wins"}
        {"type":"ai-title","aiTitle":"AI loses"}
        """
        let result = AgentSessionTitleStore.resolveClaudeTitleFromChunks(
            head: head, tail: tail
        )
        XCTAssertEqual(result?.title, "Custom wins")
        XCTAssertEqual(result?.source, .claudeCustomTitle)
    }

    func testResolveClaudeFallsBackToAiTitle() {
        let head = ""
        let tail = """
        {"type":"ai-title","aiTitle":"Only AI"}
        """
        let result = AgentSessionTitleStore.resolveClaudeTitleFromChunks(
            head: head, tail: tail
        )
        XCTAssertEqual(result?.title, "Only AI")
        XCTAssertEqual(result?.source, .claudeAiTitle)
    }

    func testResolveClaudePrefersTailOverHead() {
        let head = """
        {"type":"custom-title","customTitle":"HeadCustom"}
        """
        let tail = """
        {"type":"custom-title","customTitle":"TailCustom"}
        """
        let result = AgentSessionTitleStore.resolveClaudeTitleFromChunks(
            head: head, tail: tail
        )
        XCTAssertEqual(result?.title, "TailCustom")
    }

    func testResolveClaudeUsesHeadWhenTailEmpty() {
        let head = """
        {"type":"custom-title","customTitle":"HeadOnly"}
        """
        let tail = ""
        let result = AgentSessionTitleStore.resolveClaudeTitleFromChunks(
            head: head, tail: tail
        )
        XCTAssertEqual(result?.title, "HeadOnly")
    }

    func testResolveClaudeNilWhenNothing() {
        XCTAssertNil(
            AgentSessionTitleStore.resolveClaudeTitleFromChunks(
                head: "", tail: ""
            )
        )
    }

    // MARK: - String.claudeProjectDirEncoded

    func testClaudeProjectDirEncodedBasic() {
        XCTAssertEqual(
            "/Users/me/project".claudeProjectDirEncoded(),
            "-Users-me-project"
        )
    }

    func testClaudeProjectDirEncodedReplacesSpaces() {
        XCTAssertEqual(
            "/Users/me/My Docs".claudeProjectDirEncoded(),
            "-Users-me-My-Docs"
        )
    }

    func testClaudeProjectDirEncodedReplacesNonAscii() {
        XCTAssertEqual(
            "/Users/项目".claudeProjectDirEncoded(),
            "-Users---"
        )
    }
}
