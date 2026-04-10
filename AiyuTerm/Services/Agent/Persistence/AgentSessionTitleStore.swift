//
// AgentSessionTitleStore.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/SessionTitleStore.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Resolves user-facing session titles from the on-disk state
// maintained by Codex and Claude Code:
//   • Codex  — `~/.codex/session_index.jsonl` (newline-delimited
//              JSON, one entry per thread).
//   • Claude — `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl`,
//              which contains `"type":"custom-title"` and
//              `"type":"ai-title"` records. We read at most the
//              first 64 KiB + last 64 KiB of the file for speed.
//

import Foundation

struct AgentResolvedSessionTitle: Sendable, Equatable {
    let title: String
    let source: AgentSessionTitleSource
}

enum AgentSessionTitleStore {

    /// Which providers have a resolvable on-disk title?
    static func supports(provider: String) -> Bool {
        switch provider {
        case "codex", "claude": return true
        default: return false
        }
    }

    /// Top-level entry point. Returns `nil` if nothing can be
    /// resolved (file missing, no matching record, unsupported
    /// provider).
    static func title(
        for sessionId: String,
        provider: String,
        cwd: String? = nil
    ) -> AgentResolvedSessionTitle? {
        switch provider {
        case "codex":
            guard let title = codexThreadName(sessionId: sessionId) else { return nil }
            return AgentResolvedSessionTitle(
                title: title,
                source: .codexThreadName
            )
        case "claude":
            return claudeTitle(sessionId: sessionId, cwd: cwd)
        default:
            return nil
        }
    }

    // MARK: - Codex

    /// Read `~/.codex/session_index.jsonl` and pick the most
    /// recently updated `thread_name` for `sessionId`.
    static func codexThreadName(sessionId: String) -> String? {
        let path = NSHomeDirectory() + "/.codex/session_index.jsonl"
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return try? codexThreadName(sessionId: sessionId, indexContents: contents)
    }

    /// Pure parser for `session_index.jsonl`. Extracted so tests
    /// can drive it without touching the filesystem.
    static func codexThreadName(
        sessionId: String,
        indexContents: String
    ) throws -> String? {
        struct Entry: Decodable {
            let id: String
            let thread_name: String?
            let updated_at: String?
        }

        let decoder = JSONDecoder()
        let iso8601 = ISO8601DateFormatter()
        var latestMatch: (updatedAt: Date, title: String)?

        for line in indexContents.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let entry = try? decoder.decode(Entry.self, from: data),
                  entry.id == sessionId,
                  let rawTitle = entry.thread_name?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawTitle.isEmpty
            else { continue }

            let updatedAt = entry.updated_at.flatMap(iso8601.date(from:)) ?? .distantPast
            if let latestMatch, latestMatch.updatedAt > updatedAt { continue }
            latestMatch = (updatedAt, rawTitle)
        }

        return latestMatch?.title
    }

    // MARK: - Claude

    /// Read the Claude Code `<sessionId>.jsonl` file for `cwd` and
    /// return the most recent custom title (preferred) or AI
    /// title.
    static func claudeTitle(
        sessionId: String,
        cwd: String?
    ) -> AgentResolvedSessionTitle? {
        guard let cwd else { return nil }

        let projectDir = cwd.claudeProjectDirEncoded()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.claude/projects/\(projectDir)/\(sessionId).jsonl"

        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        let fileSize = handle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 65536)

        handle.seek(toFileOffset: 0)
        let headData = handle.readData(ofLength: Int(readSize))

        let tailData: Data
        if fileSize > readSize {
            handle.seek(toFileOffset: fileSize - readSize)
            tailData = handle.readDataToEndOfFile()
        } else {
            tailData = headData
        }

        guard let head = String(data: headData, encoding: .utf8),
              let tail = String(data: tailData, encoding: .utf8)
        else { return nil }

        return resolveClaudeTitleFromChunks(head: head, tail: tail)
    }

    /// Pure reducer over the two (head / tail) chunks we read
    /// from the Claude JSONL file. Kept separate from `claudeTitle`
    /// so tests can exercise it without touching the filesystem.
    static func resolveClaudeTitleFromChunks(
        head: String,
        tail: String
    ) -> AgentResolvedSessionTitle? {
        let tailTitles = latestClaudeTitles(in: tail)
        let headTitles = latestClaudeTitles(in: head)

        if let customTitle = tailTitles.custom ?? headTitles.custom {
            return AgentResolvedSessionTitle(
                title: customTitle,
                source: .claudeCustomTitle
            )
        }
        if let aiTitle = tailTitles.ai ?? headTitles.ai {
            return AgentResolvedSessionTitle(
                title: aiTitle,
                source: .claudeAiTitle
            )
        }
        return nil
    }

    /// Parse custom-title / ai-title records out of one chunk.
    static func latestClaudeTitles(
        in contents: String
    ) -> (custom: String?, ai: String?) {
        var latestCustomTitle: String?
        var latestAiTitle: String?

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String
            else { continue }

            switch type {
            case "custom-title":
                if let title = trimmedTitle(json["customTitle"]) {
                    latestCustomTitle = title
                }
            case "ai-title":
                if let title = trimmedTitle(json["aiTitle"]) {
                    latestAiTitle = title
                }
            default: continue
            }
        }

        return (latestCustomTitle, latestAiTitle)
    }

    private static func trimmedTitle(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Claude project dir encoding

extension String {
    /// Encode a path the same way Claude Code does for its project
    /// directory names: `/`, spaces, and non-ASCII → `-`.
    func claudeProjectDirEncoded() -> String {
        var result = ""
        for c in unicodeScalars {
            if c == "/" || c == " " || c.value > 127 {
                result.append("-")
            } else {
                result.append(Character(c))
            }
        }
        return result
    }
}
