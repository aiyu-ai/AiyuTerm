//
//  AgentConversationParser.swift
//  AiyuTerm
//
//  Incremental offset-tracked parser for Claude Code JSONL
//  conversation files. Reads only new bytes since the last
//  call, extracts tool results, interrupt signals, and clear
//  commands.
//
//  The actor isolation guarantees safe concurrent access from
//  the poller and any callers that need parse results.
//

import Foundation

// MARK: - Data types

/// Result of an incremental JSONL parse pass.
struct AgentJSONLParseResult: Sendable {
    /// Tool IDs completed in this incremental read only.
    let newCompletedToolIds: Set<String>
    /// All tool IDs completed across every read for this session.
    let allCompletedToolIds: Set<String>
    /// Per-tool-ID result details (cumulative).
    let toolResults: [String: AgentToolResult]
    /// Whether an interrupt signal was detected in the new lines.
    let interruptDetected: Bool
    /// Whether a `/clear` command was detected in the new lines.
    let clearDetected: Bool
}

/// Extracted metadata for a single tool_result line.
struct AgentToolResult: Sendable {
    let toolUseId: String
    let toolName: String?
    let isError: Bool
    /// Content truncated to `maxContentPreviewLength`.
    let contentPreview: String
}

// MARK: - Parser actor

actor AgentConversationParser {

    // MARK: - Internal state

    private var fileOffsets: [String: UInt64] = [:]
    private var cumulativeToolIds: [String: Set<String>] = [:]
    private var cumulativeToolResults: [String: [String: AgentToolResult]] = [:]

    // MARK: - Constants

    static let maxContentPreviewLength = 2048
    private static let largeFileThreshold: UInt64 = 128 * 1024
    private static let tailReadSize: UInt64 = 64 * 1024

    // MARK: - Public API

    /// Parse new bytes appended to the JSONL file since the last call.
    /// Returns `nil` when the file doesn't exist, is empty, or no
    /// new complete lines are available.
    func parseIncremental(
        sessionId: String,
        jsonlFilePath: String
    ) -> AgentJSONLParseResult? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonlFilePath) else { return nil }

        guard let attrs = try? fm.attributesOfItem(atPath: jsonlFilePath),
              let fileSize = (attrs[.size] as? NSNumber)?.uint64Value else {
            return nil
        }

        if fileSize == 0 { return nil }

        let storedOffset = fileOffsets[sessionId] ?? 0

        // File truncation guard: file shrank since last read.
        if fileSize < storedOffset {
            fileOffsets[sessionId] = 0
            cumulativeToolIds[sessionId] = nil
            cumulativeToolResults[sessionId] = nil
            // Re-parse from beginning.
            return parseIncremental(sessionId: sessionId, jsonlFilePath: jsonlFilePath)
        }

        // Determine read range.
        var readOffset = storedOffset
        if storedOffset == 0 && fileSize > Self.largeFileThreshold {
            // Large file first parse: skip to last 64 KB.
            readOffset = fileSize - Self.tailReadSize
        }

        if readOffset >= fileSize { return nil }

        guard let fileHandle = FileHandle(forReadingAtPath: jsonlFilePath) else {
            return nil
        }
        defer { fileHandle.closeFile() }

        fileHandle.seek(toFileOffset: readOffset)
        let data = fileHandle.readData(ofLength: Int(fileSize - readOffset))
        if data.isEmpty { return nil }

        guard var text = String(data: data, encoding: .utf8) else { return nil }

        // When reading from a mid-file offset on a large file first parse,
        // discard the first partial line.
        if storedOffset == 0 && readOffset > 0 {
            if let firstNewline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewline)...])
            } else {
                // No complete line in the chunk.
                return nil
            }
        }

        // Split into lines, keeping track of byte positions.
        let lines = text.components(separatedBy: "\n")

        // Discard last element if the data did not end with a newline
        // (incomplete line that will be re-read next call).
        let endsWithNewline = data.last == UInt8(ascii: "\n")
        let completeLines: [String]
        if endsWithNewline {
            completeLines = lines.filter { !$0.isEmpty }
        } else {
            // Drop last (partial) element.
            let allButLast = lines.dropLast()
            completeLines = allButLast.filter { !$0.isEmpty }
        }

        if completeLines.isEmpty {
            // Advance offset only if we ended with a newline (nothing to re-read).
            if endsWithNewline {
                fileOffsets[sessionId] = fileSize
            }
            return nil
        }

        // Calculate byte offset of complete lines consumed.
        let completeText = completeLines.joined(separator: "\n") + "\n"
        let completeBytes = UInt64(completeText.utf8.count)

        // The new offset is readOffset + bytes consumed through complete lines.
        // But we need to account for the skipped partial first line in large files.
        let newOffset: UInt64
        if endsWithNewline {
            newOffset = fileSize
        } else {
            // We consumed completeBytes starting from where we began reading
            // (after any partial first-line skip).
            let textStartOffset: UInt64
            if storedOffset == 0 && readOffset > 0 {
                // We skipped readOffset bytes, then the first partial line.
                let originalText = String(data: data, encoding: .utf8) ?? ""
                if let firstNewline = originalText.firstIndex(of: "\n") {
                    let skippedPrefix = originalText[...firstNewline]
                    textStartOffset = readOffset + UInt64(skippedPrefix.utf8.count)
                } else {
                    textStartOffset = readOffset
                }
            } else {
                textStartOffset = readOffset
            }
            newOffset = textStartOffset + completeBytes
        }

        fileOffsets[sessionId] = newOffset

        // Parse lines.
        var newToolIds = Set<String>()
        var interruptDetected = false
        var clearDetected = false
        var existingToolIds = cumulativeToolIds[sessionId] ?? []
        var existingResults = cumulativeToolResults[sessionId] ?? [:]

        for line in completeLines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue  // Skip malformed lines.
            }

            // Check for /clear command in any text content.
            if detectClear(in: json) {
                clearDetected = true
                existingToolIds.removeAll()
                existingResults.removeAll()
                newToolIds.removeAll()
            }

            // Check for interrupted flag.
            if json["interrupted"] as? Bool == true {
                interruptDetected = true
            }

            let lineType = json["type"] as? String

            // Tool result.
            if lineType == "tool_result", let toolUseId = json["tool_use_id"] as? String {
                let isError = json["is_error"] as? Bool ?? false
                let content = extractContent(from: json)
                let toolName = json["tool_name"] as? String

                // Check for interrupt patterns in tool_result.
                if isError && containsInterruptPattern(content) {
                    interruptDetected = true
                }

                let preview = truncate(content, to: Self.maxContentPreviewLength)
                let result = AgentToolResult(
                    toolUseId: toolUseId,
                    toolName: toolName,
                    isError: isError,
                    contentPreview: preview
                )

                if !existingToolIds.contains(toolUseId) {
                    newToolIds.insert(toolUseId)
                }
                existingToolIds.insert(toolUseId)
                existingResults[toolUseId] = result
            }

            // User interrupt.
            if lineType == "user" {
                let content = extractContent(from: json)
                if content.contains("[Request interrupted by user]") {
                    interruptDetected = true
                }
            }
        }

        cumulativeToolIds[sessionId] = existingToolIds
        cumulativeToolResults[sessionId] = existingResults

        return AgentJSONLParseResult(
            newCompletedToolIds: newToolIds,
            allCompletedToolIds: existingToolIds,
            toolResults: existingResults,
            interruptDetected: interruptDetected,
            clearDetected: clearDetected
        )
    }

    /// Clear all tracked state for a session.
    func resetSession(_ sessionId: String) {
        fileOffsets.removeValue(forKey: sessionId)
        cumulativeToolIds.removeValue(forKey: sessionId)
        cumulativeToolResults.removeValue(forKey: sessionId)
    }

    // MARK: - Test helpers

    /// Expose current offset for test verification.
    func currentOffset(for sessionId: String) -> UInt64 {
        fileOffsets[sessionId] ?? 0
    }

    /// Expose cumulative tool IDs for test verification.
    func currentToolIds(for sessionId: String) -> Set<String> {
        cumulativeToolIds[sessionId] ?? []
    }

    // MARK: - Private helpers

    /// Extract text content from a JSON line. Content may be a plain
    /// string or an array of `{"text": "..."}` objects.
    private func extractContent(from json: [String: Any]) -> String {
        if let content = json["content"] as? String {
            return content
        }
        if let arr = json["content"] as? [[String: Any]] {
            return arr.compactMap { $0["text"] as? String }.joined(separator: " ")
        }
        return ""
    }

    /// Detect `/clear` command in any text field of the JSON line.
    private func detectClear(in json: [String: Any]) -> Bool {
        let content = extractContent(from: json)
        return content.contains("<command-name>/clear</command-name>")
    }

    /// Check whether content contains interrupt patterns from tool results.
    private func containsInterruptPattern(_ content: String) -> Bool {
        content.contains("Interrupted by user")
            || content.contains("user doesn't want to proceed")
    }

    /// Truncate a string to the given byte-safe character count.
    private func truncate(_ string: String, to maxLength: Int) -> String {
        if string.count <= maxLength { return string }
        return String(string.prefix(maxLength))
    }
}
