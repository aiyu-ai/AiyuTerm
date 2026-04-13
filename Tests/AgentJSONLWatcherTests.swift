//
//  AgentJSONLWatcherTests.swift
//  AiyuTermTests
//
//  Tests for AgentJSONLWatcher: file event notifications,
//  unwatch cleanup, and LRU eviction at capacity.
//

import XCTest
@testable import AiyuTerm

final class AgentJSONLWatcherTests: XCTestCase {

    private var watcher: AgentJSONLWatcher!
    private var tempDir: String!

    override func setUp() {
        watcher = AgentJSONLWatcher()
        tempDir = NSTemporaryDirectory() + "AgentJSONLWatcherTests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        watcher.unwatchAll()
        watcher = nil
        try? FileManager.default.removeItem(atPath: tempDir)
        tempDir = nil
    }

    // MARK: - Helpers

    private func createFile(_ name: String) -> String {
        let path = tempDir + "/" + name
        FileManager.default.createFile(atPath: path, contents: Data())
        return path
    }

    // MARK: - 1. Fires onChange on write

    func testFiresOnChangeWhenFileIsWritten() {
        let path = createFile("test.jsonl")
        let expectation = expectation(description: "onChange fired")

        watcher.watch(sessionId: "s1", filePath: path) {
            expectation.fulfill()
        }

        // Write to the file after a brief delay to ensure the
        // dispatch source is active.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let data = Data(#"{"type":"tool_result"}"#.utf8)
            try? data.write(to: URL(fileURLWithPath: path))
        }

        waitForExpectations(timeout: 3.0)
    }

    // MARK: - 2. Unwatch stops notifications

    func testUnwatchStopsNotifications() {
        let path = createFile("test2.jsonl")
        var callCount = 0

        watcher.watch(sessionId: "s1", filePath: path) {
            callCount += 1
        }

        watcher.unwatch(sessionId: "s1")

        // Write after unwatching.
        let data = Data("test\n".utf8)
        try? data.write(to: URL(fileURLWithPath: path))

        // Wait briefly to confirm no callback fires.
        let noCallExpectation = expectation(description: "no onChange")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            noCallExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        XCTAssertEqual(callCount, 0)
    }

    // MARK: - 3. LRU eviction at max capacity

    func testLRUEvictionAtMaxCapacity() {
        // Create 20 watchers to fill the pool.
        for i in 0..<20 {
            let path = createFile("file\(i).jsonl")
            watcher.watch(sessionId: "s\(i)", filePath: path) {}
        }
        XCTAssertEqual(watcher.activeCount, 20)

        // Adding a 21st should evict the oldest (s0).
        let path21 = createFile("file20.jsonl")
        watcher.watch(sessionId: "s20", filePath: path21) {}

        XCTAssertEqual(watcher.activeCount, 20)
    }

    // MARK: - 4. Replacing existing watcher

    func testReplacingExistingWatcher() {
        let path1 = createFile("a.jsonl")
        let path2 = createFile("b.jsonl")

        watcher.watch(sessionId: "s1", filePath: path1) {}
        XCTAssertEqual(watcher.activeCount, 1)

        watcher.watch(sessionId: "s1", filePath: path2) {}
        XCTAssertEqual(watcher.activeCount, 1)
    }

    // MARK: - 5. UnwatchAll

    func testUnwatchAllClearsEverything() {
        for i in 0..<5 {
            let path = createFile("w\(i).jsonl")
            watcher.watch(sessionId: "w\(i)", filePath: path) {}
        }
        XCTAssertEqual(watcher.activeCount, 5)

        watcher.unwatchAll()
        XCTAssertEqual(watcher.activeCount, 0)
    }

    // MARK: - 6. Invalid path does not crash

    func testInvalidPathDoesNotCrash() {
        watcher.watch(sessionId: "bad", filePath: "/nonexistent/path.jsonl") {}
        XCTAssertEqual(watcher.activeCount, 0)
    }
}
