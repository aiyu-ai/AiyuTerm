//
//  AgentConversationParserTests.swift
//  AiyuTermTests
//
//  Tests for AgentConversationParser: incremental offset-tracked
//  parsing of Claude Code JSONL conversation files covering tool
//  results, interrupts, clear commands, truncation, and edge cases.
//

import XCTest
@testable import AiyuTerm

final class AgentConversationParserTests: XCTestCase {

    private var parser: AgentConversationParser!
    private var tempDir: String!

    override func setUp() async throws {
        parser = AgentConversationParser()
        tempDir = NSTemporaryDirectory() + "AgentConversationParserTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDir)
        parser = nil
        tempDir = nil
    }

    // MARK: - Helpers

    private func filePath(_ name: String = "conv.jsonl") -> String {
        tempDir + "/" + name
    }

    private func writeJSONL(_ lines: [String], to path: String) {
        let content = lines.joined(separator: "\n") + "\n"
        FileManager.default.createFile(atPath: path, contents: Data(content.utf8))
    }

    private func appendJSONL(_ lines: [String], to path: String) {
        let content = lines.joined(separator: "\n") + "\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(Data(content.utf8))
            handle.closeFile()
        }
    }

    // MARK: - 1. Tool result detection

    func testDetectsToolResult() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_001","content":"ok"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.newCompletedToolIds.contains("tu_001"))
        XCTAssertTrue(result!.allCompletedToolIds.contains("tu_001"))
        XCTAssertEqual(result!.toolResults["tu_001"]?.contentPreview, "ok")
        XCTAssertEqual(result!.toolResults["tu_001"]?.isError, false)
    }

    // MARK: - 2. User interrupt

    func testDetectsUserInterrupt() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"user","content":"[Request interrupted by user]"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.interruptDetected)
    }

    // MARK: - 3. Tool result interrupt

    func testDetectsToolResultInterrupt() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_002","is_error":true,"content":"Interrupted by user"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.interruptDetected)
        XCTAssertTrue(result!.toolResults["tu_002"]!.isError)
    }

    func testDetectsUserDoesntWantToProceed() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_003","is_error":true,"content":"user doesn't want to proceed"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.interruptDetected)
    }

    // MARK: - 4. Interrupted flag

    func testDetectsInterruptedFlag() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"assistant","interrupted":true,"content":"partial response"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.interruptDetected)
    }

    // MARK: - 5. Clear command

    func testDetectsClearCommand() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_010","content":"done"}"#,
            #"{"type":"user","content":"<command-name>/clear</command-name>"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.clearDetected)
        // Clear resets cumulative state, so tu_010 should be gone.
        XCTAssertFalse(result!.allCompletedToolIds.contains("tu_010"))
    }

    // MARK: - 6. Incremental parsing

    func testIncrementalParsing() async {
        let path = filePath()

        // First write: tool1
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_100","content":"first"}"#
        ], to: path)

        let result1 = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1!.newCompletedToolIds, Set(["tu_100"]))
        XCTAssertEqual(result1!.allCompletedToolIds, Set(["tu_100"]))

        // Append: tool2
        appendJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_101","content":"second"}"#
        ], to: path)

        let result2 = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)
        XCTAssertNotNil(result2)
        // Only tu_101 is new.
        XCTAssertEqual(result2!.newCompletedToolIds, Set(["tu_101"]))
        // Both are in cumulative.
        XCTAssertEqual(result2!.allCompletedToolIds, Set(["tu_100", "tu_101"]))
    }

    // MARK: - 7. Content truncation

    func testContentTruncationTo2KB() async {
        let path = filePath()
        let longContent = String(repeating: "A", count: 4096)
        let line = #"{"type":"tool_result","tool_use_id":"tu_200","content":""# + longContent + #""}"#
        writeJSONL([line], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        let preview = result!.toolResults["tu_200"]!.contentPreview
        XCTAssertEqual(preview.count, AgentConversationParser.maxContentPreviewLength)
    }

    // MARK: - 8. File truncation resets state

    func testFileTruncationResetsOffset() async {
        let path = filePath()

        // First write with multiple lines.
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_300","content":"a"}"#,
            #"{"type":"tool_result","tool_use_id":"tu_301","content":"b"}"#
        ], to: path)

        let result1 = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1!.allCompletedToolIds.count, 2)

        // Truncate file (write smaller content).
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_302","content":"c"}"#
        ], to: path)

        let result2 = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)
        XCTAssertNotNil(result2)
        // After truncation, cumulative state resets. Only tu_302 remains.
        XCTAssertEqual(result2!.allCompletedToolIds, Set(["tu_302"]))
        XCTAssertFalse(result2!.allCompletedToolIds.contains("tu_300"))
    }

    // MARK: - 9. Malformed lines skipped

    func testMalformedLinesAreSkipped() async {
        let path = filePath()
        writeJSONL([
            "not json at all",
            #"{"type":"tool_result","tool_use_id":"tu_400","content":"ok"}"#,
            "{malformed",
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.allCompletedToolIds, Set(["tu_400"]))
    }

    // MARK: - 10. Partial line handling

    func testPartialLineIsDiscarded() async {
        let path = filePath()
        // Write content without trailing newline on last line.
        let content = #"{"type":"tool_result","tool_use_id":"tu_500","content":"done"}"# + "\n"
            + #"{"type":"tool_result","tool_use_id":"tu_501","content":"partial"#
        FileManager.default.createFile(atPath: path, contents: Data(content.utf8))

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        // Only tu_500 should be parsed; tu_501 is partial.
        XCTAssertTrue(result!.allCompletedToolIds.contains("tu_500"))
        XCTAssertFalse(result!.allCompletedToolIds.contains("tu_501"))
    }

    // MARK: - 11. Empty file

    func testEmptyFileReturnsNil() async {
        let path = filePath()
        FileManager.default.createFile(atPath: path, contents: Data())

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)
        XCTAssertNil(result)
    }

    // MARK: - 12. Non-existent file

    func testNonExistentFileReturnsNil() async {
        let result = await parser.parseIncremental(
            sessionId: "s1",
            jsonlFilePath: "/tmp/does-not-exist-\(UUID().uuidString).jsonl"
        )
        XCTAssertNil(result)
    }

    // MARK: - 13. resetSession clears state

    func testResetSessionClearsCumulativeState() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_600","content":"x"}"#
        ], to: path)

        _ = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)
        let toolIdsBefore = await parser.currentToolIds(for: "s1")
        XCTAssertEqual(toolIdsBefore, Set(["tu_600"]))

        await parser.resetSession("s1")

        let toolIdsAfter = await parser.currentToolIds(for: "s1")
        XCTAssertTrue(toolIdsAfter.isEmpty)

        let offsetAfter = await parser.currentOffset(for: "s1")
        XCTAssertEqual(offsetAfter, 0)
    }

    // MARK: - Content extraction (array format)

    func testContentExtractionFromArray() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_700","content":[{"text":"hello"},{"text":"world"}]}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.toolResults["tu_700"]?.contentPreview, "hello world")
    }

    // MARK: - Tool name extraction

    func testToolNameExtraction() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_800","tool_name":"Bash","content":"output"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.toolResults["tu_800"]?.toolName, "Bash")
    }

    // MARK: - No interrupt when not present

    func testNoInterruptWhenAbsent() async {
        let path = filePath()
        writeJSONL([
            #"{"type":"tool_result","tool_use_id":"tu_900","content":"normal output"}"#
        ], to: path)

        let result = await parser.parseIncremental(sessionId: "s1", jsonlFilePath: path)

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.interruptDetected)
        XCTAssertFalse(result!.clearDetected)
    }
}
