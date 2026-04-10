//
// AgentDiagnosticsExporterTests.swift
// AiyuTermTests
//
// Phase 9.6 tests for AgentDiagnosticsExporter's pure helpers and
// the end-to-end `buildArchive` path using a throwaway temp dir.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentDiagnosticsExporterTests: XCTestCase {

    // MARK: - timestamp

    func testTimestampFormat() {
        let date = Date(timeIntervalSince1970: 1_712_745_600) // 2024-04-10 08:00:00 UTC
        let ts = AgentDiagnosticsHelpers.timestamp(date: date)
        // yyyyMMdd-HHmmss, 15 chars exactly
        XCTAssertEqual(ts.count, 15)
        XCTAssertTrue(ts.contains("-"))
        // The first 8 chars are digits (yyyyMMdd)
        XCTAssertTrue(ts.prefix(8).allSatisfy(\.isNumber))
    }

    // MARK: - metadataDict

    func testMetadataDictContainsCoreKeys() {
        let dict = AgentDiagnosticsHelpers.metadataDict()
        XCTAssertNotNil(dict["exportedAt"])
        XCTAssertNotNil(dict["appVersion"])
        XCTAssertNotNil(dict["buildNumber"])
        XCTAssertNotNil(dict["macOS"])
        XCTAssertNotNil(dict["locale"])
        XCTAssertNotNil(dict["timeZone"])
        XCTAssertNotNil(dict["socketPath"])
        XCTAssertNotNil(dict["buildConfiguration"])
    }

    func testMetadataDictSocketPathUsesAiyuTerm() {
        let dict = AgentDiagnosticsHelpers.metadataDict()
        let socketPath = dict["socketPath"] as? String
        XCTAssertNotNil(socketPath)
        XCTAssertTrue(
            socketPath?.contains("aiyuterm") == true,
            "socketPath should mention aiyuterm; got \(socketPath ?? "nil")"
        )
    }

    // MARK: - sessionDicts

    func testSessionDictsTruncatesSessionId() {
        var snap = AgentSessionSnapshot()
        snap.cwd = "/tmp/x"
        snap.source = "claude"
        snap.cliPid = 999

        let dicts = AgentDiagnosticsHelpers.sessionDicts(
            from: ["abcdefghijklmnopqrstuvwxyz": snap]
        )
        XCTAssertEqual(dicts.count, 1)
        XCTAssertEqual(dicts[0]["id"] as? String, "abcdefgh")
        XCTAssertEqual(dicts[0]["cwd"] as? String, "/tmp/x")
        XCTAssertEqual(dicts[0]["pid"] as? Int, 999)
        XCTAssertEqual(dicts[0]["source"] as? String, "claude")
    }

    func testSessionDictsIncludesOptionalFieldsOnlyWhenPresent() {
        var s1 = AgentSessionSnapshot()
        s1.source = "codex"
        // No cwd / tool / model / termApp / cliPid

        let dicts = AgentDiagnosticsHelpers.sessionDicts(from: ["sid-1": s1])
        XCTAssertEqual(dicts.count, 1)
        XCTAssertNil(dicts[0]["cwd"])
        XCTAssertNil(dicts[0]["currentTool"])
        XCTAssertNil(dicts[0]["model"])
        XCTAssertNil(dicts[0]["terminal"])
        XCTAssertNil(dicts[0]["pid"])
        // But counts are always present
        XCTAssertEqual(dicts[0]["subagentCount"] as? Int, 0)
        XCTAssertEqual(dicts[0]["toolHistoryCount"] as? Int, 0)
    }

    func testSessionDictsDeterministicOrder() {
        let a = AgentSessionSnapshot()
        let b = AgentSessionSnapshot()
        let dicts = AgentDiagnosticsHelpers.sessionDicts(
            from: ["zzzz": a, "aaaa": b]
        )
        XCTAssertEqual(dicts[0]["id"] as? String, "aaaa")
        XCTAssertEqual(dicts[1]["id"] as? String, "zzzz")
    }

    // MARK: - defaultConfigSources

    func testDefaultConfigSourcesIncludesNineCLIs() {
        let sources = AgentDiagnosticsHelpers.defaultConfigSources(
            home: "/Users/test"
        )
        // Claude, Codex-toml, Codex-hooks, Gemini, Cursor, Qoder,
        // Factory, CodeBuddy, OpenCode plugin, persisted-sessions
        // = 10 entries.
        XCTAssertEqual(sources.count, 10)

        let destNames = sources.map(\.dest)
        XCTAssertTrue(destNames.contains("configs/claude-settings.json"))
        XCTAssertTrue(destNames.contains("configs/codex-config.toml"))
        XCTAssertTrue(destNames.contains("configs/opencode-plugin.js"))
        XCTAssertTrue(destNames.contains("configs/persisted-sessions.json"))
    }

    func testDefaultConfigSourcesPersistedUsesDebugDir() {
        let sources = AgentDiagnosticsHelpers.defaultConfigSources(
            home: "/Users/test"
        )
        let persisted = sources.first { $0.dest == "configs/persisted-sessions.json" }
        XCTAssertNotNil(persisted)
        #if DEBUG
        XCTAssertTrue(
            persisted!.source.contains("/.aiyuterm-debug/"),
            "Debug build should read from .aiyuterm-debug"
        )
        #else
        XCTAssertTrue(persisted!.source.contains("/.aiyuterm/"))
        #endif
    }

    // MARK: - filterAndSortCrashReports

    func testFilterCrashReportsMatchesKeyword() {
        let urls: [URL] = [
            URL(fileURLWithPath: "/tmp/aiyuterm-2026-04-10.ips"),
            URL(fileURLWithPath: "/tmp/Finder.ips"),
            URL(fileURLWithPath: "/tmp/AiyuTerm-crash.ips"),
        ]
        let filtered = AgentDiagnosticsHelpers.filterAndSortCrashReports(
            urls: urls,
            keyword: "aiyuterm",
            limit: 10
        )
        XCTAssertEqual(filtered.count, 2)
        XCTAssertFalse(
            filtered.contains { $0.lastPathComponent == "Finder.ips" }
        )
    }

    func testFilterCrashReportsRespectsLimit() {
        let urls: [URL] = (0..<10).map {
            URL(fileURLWithPath: "/tmp/aiyuterm-\($0).ips")
        }
        let filtered = AgentDiagnosticsHelpers.filterAndSortCrashReports(
            urls: urls,
            keyword: "aiyuterm",
            limit: 5
        )
        XCTAssertEqual(filtered.count, 5)
    }

    func testFilterCrashReportsCaseInsensitive() {
        let urls: [URL] = [
            URL(fileURLWithPath: "/tmp/AIYUTERM_CRASH.ips"),
            URL(fileURLWithPath: "/tmp/other.ips"),
        ]
        let filtered = AgentDiagnosticsHelpers.filterAndSortCrashReports(
            urls: urls,
            keyword: "aiyuterm",
            limit: 10
        )
        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - writeJSON + copyIfExists round trip

    func testWriteJSONAndReadBack() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aiyuterm-diag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let target = tmpDir.appendingPathComponent("nested/metadata.json")
        AgentDiagnosticsHelpers.writeJSON(
            ["answer": 42, "greeting": "hi"] as [String: Any],
            to: target
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        let data = try Data(contentsOf: target)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(parsed?["answer"] as? Int, 42)
        XCTAssertEqual(parsed?["greeting"] as? String, "hi")
    }

    func testCopyIfExistsNoOpWhenMissing() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aiyuterm-diag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let destination = tmpDir.appendingPathComponent("nope/file.json")
        AgentDiagnosticsHelpers.copyIfExists(
            from: "/this/path/does/not/exist",
            to: destination
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: destination.path)
        )
    }

    func testCopyIfExistsCopiesWhenPresent() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aiyuterm-diag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let source = tmpDir.appendingPathComponent("source.txt")
        try "hello".write(to: source, atomically: true, encoding: .utf8)

        let destination = tmpDir.appendingPathComponent("nested/dest.txt")
        AgentDiagnosticsHelpers.copyIfExists(
            from: source.path,
            to: destination
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: destination.path)
        )
        XCTAssertEqual(
            try String(contentsOf: destination, encoding: .utf8),
            "hello"
        )
    }

    // MARK: - buildArchive end-to-end

    func testBuildArchiveCreatesZipFile() throws {
        // Full end-to-end: write a couple of sessions, run
        // buildArchive, assert the resulting zip exists and has
        // non-zero size. We don't crack the zip open here — the
        // purpose is to verify the happy path runs without
        // throwing and produces a real file.
        var s1 = AgentSessionSnapshot()
        s1.source = "claude"
        s1.cwd = "/tmp/project"
        var s2 = AgentSessionSnapshot()
        s2.source = "codex"

        let tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aiyuterm-diag-build-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmpRoot, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let destination = tmpRoot.appendingPathComponent("bundle.zip")
        let url = try AgentDiagnosticsExporter.buildArchive(
            sessions: ["sid-a": s1, "sid-b": s2],
            saveTo: destination
        )
        XCTAssertEqual(url, destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(size, 0, "Diagnostics zip should be non-empty")
    }
}
