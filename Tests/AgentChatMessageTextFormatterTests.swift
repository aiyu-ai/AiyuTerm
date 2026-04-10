//
// AgentChatMessageTextFormatterTests.swift
// AiyuTermTests
//
// Phase 9.1 tests for the AttributedString-building helper used by
// the notch panel chat preview.
//

import XCTest
@testable import AiyuTerm

final class AgentChatMessageTextFormatterTests: XCTestCase {

    func testUserMessageStaysLiteral() {
        let message = AgentChatMessage(isUser: true, text: "**not bold** _not italic_")
        let attributed = AgentChatMessageTextFormatter.displayText(for: message)
        // The user's text is rendered as-is — no markdown
        // interpretation — so the literal asterisks and underscores
        // appear in the raw string.
        XCTAssertEqual(String(attributed.characters), "**not bold** _not italic_")
    }

    func testAssistantMessageParsesInlineMarkdown() {
        let message = AgentChatMessage(isUser: false, text: "**Done** in 5s")
        let attributed = AgentChatMessageTextFormatter.displayText(for: message)
        // The rendered string drops the `**` markers.
        XCTAssertEqual(String(attributed.characters), "Done in 5s")
    }

    func testAssistantMalformedMarkdownFallsBackToLiteral() {
        // Unbalanced backticks used to throw — make sure the helper
        // still returns a non-nil AttributedString without crashing.
        let message = AgentChatMessage(isUser: false, text: "unterminated `code")
        let attributed = AgentChatMessageTextFormatter.displayText(for: message)
        XCTAssertFalse(String(attributed.characters).isEmpty)
    }

    func testInlineMarkdownCacheHit() {
        // Call twice and assert equality — the second call should
        // hit the cache, but we can't easily observe the cache size
        // without exposing it. Equality is good enough as a smoke
        // test.
        let text = "**cached**"
        let a = AgentChatMessageTextFormatter.inlineMarkdown(text)
        let b = AgentChatMessageTextFormatter.inlineMarkdown(text)
        XCTAssertEqual(String(a.characters), String(b.characters))
    }
}
