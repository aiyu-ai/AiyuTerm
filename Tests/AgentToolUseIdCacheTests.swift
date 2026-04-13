//
//  AgentToolUseIdCacheTests.swift
//  AiyuTermTests
//
//  Tests for AgentToolUseIdCache: composite key generation, FIFO
//  ordering, removal, expiration sweep, and session isolation.
//

import XCTest
@testable import AiyuTerm

final class AgentToolUseIdCacheTests: XCTestCase {

    // MARK: - Composite key

    func testCompositeKeyIsDeterministic() {
        let key1 = AgentToolUseIdCache.buildCompositeKey(
            sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"]
        )
        let key2 = AgentToolUseIdCache.buildCompositeKey(
            sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"]
        )
        XCTAssertEqual(key1, key2)
    }

    func testCompositeKeyWithNilInput() {
        let key = AgentToolUseIdCache.buildCompositeKey(
            sessionId: "s1", toolName: "Read", toolInput: nil
        )
        XCTAssertTrue(key.hasSuffix(":{}"))
    }

    func testCompositeKeyWithNilToolName() {
        let key = AgentToolUseIdCache.buildCompositeKey(
            sessionId: "s1", toolName: nil, toolInput: nil
        )
        XCTAssertTrue(key.contains("s1::{}"))
    }

    func testCompositeKeyDiffersForDifferentInputs() {
        let key1 = AgentToolUseIdCache.buildCompositeKey(
            sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"]
        )
        let key2 = AgentToolUseIdCache.buildCompositeKey(
            sessionId: "s1", toolName: "Bash", toolInput: ["command": "pwd"]
        )
        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - FIFO ordering

    func testCacheFIFOOrdering() {
        var cache = AgentToolUseIdCache()
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"], toolUseId: "id-1")
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"], toolUseId: "id-2")

        XCTAssertEqual(
            cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"]),
            "id-1"
        )
        XCTAssertEqual(
            cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"]),
            "id-2"
        )
        XCTAssertNil(
            cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: ["command": "ls"])
        )
    }

    // MARK: - Remove by tool_use_id

    func testRemoveByToolUseId() {
        var cache = AgentToolUseIdCache()
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: nil, toolUseId: "id-1")
        cache.remove(toolUseId: "id-1")
        XCTAssertNil(cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: nil))
    }

    func testRemoveOnlyTargetedToolUseId() {
        var cache = AgentToolUseIdCache()
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: nil, toolUseId: "id-1")
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: nil, toolUseId: "id-2")
        cache.remove(toolUseId: "id-1")
        XCTAssertEqual(
            cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: nil),
            "id-2"
        )
    }

    // MARK: - Sweep expired

    func testSweepExpiredRemovesOldEntries() {
        var cache = AgentToolUseIdCache()
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: nil, toolUseId: "id-1")

        // Sweep with future threshold -- everything should be removed
        cache.sweepExpired(olderThan: Date().addingTimeInterval(31))
        XCTAssertNil(cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: nil))
    }

    func testSweepExpiredKeepsRecentEntries() {
        var cache = AgentToolUseIdCache()
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: nil, toolUseId: "id-1")

        // Sweep with past threshold -- nothing removed
        cache.sweepExpired(olderThan: Date().addingTimeInterval(-10))
        XCTAssertEqual(
            cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: nil),
            "id-1"
        )
    }

    // MARK: - Session isolation

    func testDifferentSessionsDontConflict() {
        var cache = AgentToolUseIdCache()
        cache.store(sessionId: "s1", toolName: "Bash", toolInput: nil, toolUseId: "id-1")
        cache.store(sessionId: "s2", toolName: "Bash", toolInput: nil, toolUseId: "id-2")

        XCTAssertEqual(
            cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: nil),
            "id-1"
        )
        XCTAssertEqual(
            cache.resolve(sessionId: "s2", toolName: "Bash", toolInput: nil),
            "id-2"
        )
    }

    func testResolveReturnsNilForEmptyCache() {
        var cache = AgentToolUseIdCache()
        XCTAssertNil(cache.resolve(sessionId: "s1", toolName: "Bash", toolInput: nil))
    }
}
