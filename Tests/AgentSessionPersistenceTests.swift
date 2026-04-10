//
// AgentSessionPersistenceTests.swift
// AiyuTermTests
//
// Phase 9.5 tests for AgentSessionPersistence.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentSessionPersistenceTests: XCTestCase {

    // MARK: - buildPersisted

    func testBuildPersistedSortsBySessionId() {
        var a = AgentSessionSnapshot(startTime: Date(timeIntervalSince1970: 100))
        a.cwd = "/tmp/a"
        var b = AgentSessionSnapshot(startTime: Date(timeIntervalSince1970: 200))
        b.cwd = "/tmp/b"

        let sessions = ["zzzz": a, "aaaa": b]
        let persisted = AgentSessionPersistence.buildPersisted(from: sessions)
        XCTAssertEqual(persisted.map(\.sessionId), ["aaaa", "zzzz"])
        XCTAssertEqual(persisted[0].cwd, "/tmp/b")
    }

    func testBuildPersistedCopiesAllFields() {
        var s = AgentSessionSnapshot(startTime: Date(timeIntervalSince1970: 100))
        s.cwd = "/Users/me/project"
        s.model = "claude-sonnet-4-20250929"
        s.source = "claude"
        s.sessionTitle = "My session"
        s.sessionTitleSource = .claudeCustomTitle
        s.providerSessionId = "abc-123"
        s.lastUserPrompt = "Hello"
        s.lastAssistantMessage = "Hi"
        s.termApp = "iTerm.app"
        s.itermSessionId = "iterm-xyz"
        s.ttyPath = "/dev/ttys001"
        s.kittyWindowId = "42"
        s.tmuxPane = "%1"
        s.tmuxClientTty = "/dev/ttys000"
        s.tmuxEnv = "/private/tmp/tmux-501/default,12345,0"
        s.termBundleId = "com.googlecode.iterm2"
        s.cliPid = 54321
        s.cliStartTime = Date(timeIntervalSince1970: 50)
        s.lastActivity = Date(timeIntervalSince1970: 300)

        let persisted = AgentSessionPersistence.buildPersisted(
            from: ["sid-1": s]
        )
        XCTAssertEqual(persisted.count, 1)
        let p = persisted[0]
        XCTAssertEqual(p.sessionId, "sid-1")
        XCTAssertEqual(p.cwd, "/Users/me/project")
        XCTAssertEqual(p.model, "claude-sonnet-4-20250929")
        XCTAssertEqual(p.source, "claude")
        XCTAssertEqual(p.sessionTitle, "My session")
        XCTAssertEqual(p.sessionTitleSource, .claudeCustomTitle)
        XCTAssertEqual(p.providerSessionId, "abc-123")
        XCTAssertEqual(p.lastUserPrompt, "Hello")
        XCTAssertEqual(p.lastAssistantMessage, "Hi")
        XCTAssertEqual(p.termApp, "iTerm.app")
        XCTAssertEqual(p.itermSessionId, "iterm-xyz")
        XCTAssertEqual(p.ttyPath, "/dev/ttys001")
        XCTAssertEqual(p.kittyWindowId, "42")
        XCTAssertEqual(p.tmuxPane, "%1")
        XCTAssertEqual(p.tmuxClientTty, "/dev/ttys000")
        XCTAssertEqual(p.tmuxEnv, "/private/tmp/tmux-501/default,12345,0")
        XCTAssertEqual(p.termBundleId, "com.googlecode.iterm2")
        XCTAssertEqual(p.cliPid, 54321)
        XCTAssertEqual(p.cliStartTime, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(p.lastActivity, Date(timeIntervalSince1970: 300))
    }

    func testBuildPersistedEmptyMap() {
        XCTAssertTrue(
            AgentSessionPersistence.buildPersisted(from: [:]).isEmpty
        )
    }

    // MARK: - save / load round trip

    func testSaveAndLoadRoundTrip() throws {
        // We can't override the on-disk path without more
        // plumbing; just clean up any existing file first and
        // restore afterwards.
        let path = AgentSessionPersistence.filePath
        let fm = FileManager.default
        var backup: Data?
        if fm.fileExists(atPath: path) {
            backup = try Data(contentsOf: URL(fileURLWithPath: path))
        }
        defer {
            if let backup {
                try? backup.write(to: URL(fileURLWithPath: path), options: .atomic)
            } else {
                try? fm.removeItem(atPath: path)
            }
        }

        var s = AgentSessionSnapshot(startTime: Date(timeIntervalSince1970: 100))
        s.cwd = "/tmp/x"
        s.source = "codex"
        s.sessionTitle = "Trip test"
        s.sessionTitleSource = .codexThreadName
        s.lastActivity = Date(timeIntervalSince1970: 200)

        AgentSessionPersistence.save(["round-trip": s])
        let loaded = AgentSessionPersistence.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.sessionId, "round-trip")
        XCTAssertEqual(loaded.first?.source, "codex")
        XCTAssertEqual(loaded.first?.sessionTitle, "Trip test")
        XCTAssertEqual(loaded.first?.sessionTitleSource, .codexThreadName)
    }

    func testLoadReturnsEmptyWhenFileMissing() throws {
        let path = AgentSessionPersistence.filePath
        let fm = FileManager.default
        var backup: Data?
        if fm.fileExists(atPath: path) {
            backup = try Data(contentsOf: URL(fileURLWithPath: path))
            try fm.removeItem(atPath: path)
        }
        defer {
            if let backup {
                try? backup.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }

        XCTAssertTrue(AgentSessionPersistence.load().isEmpty)
    }

    // MARK: - directory location uses debug suffix

    func testFilePathHonoursDebugStateDir() {
        #if DEBUG
        XCTAssertTrue(
            AgentSessionPersistence.filePath.contains("/.aiyuterm-debug/"),
            "Debug build should persist to .aiyuterm-debug"
        )
        #else
        XCTAssertTrue(
            AgentSessionPersistence.filePath.contains("/.aiyuterm/"),
            "Release build should persist to .aiyuterm"
        )
        #endif
    }
}
