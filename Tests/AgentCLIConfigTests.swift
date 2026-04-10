//
// AgentCLIConfigTests.swift
// AiyuTermTests
//
// Phase 5.1 tests: sanity-check the static CLI registry before the
// installer logic lands in Phase 5.2. Catches accidental drift in
// the config table — event counts, source-tag uniqueness, path
// shape, and the version-gate table.
//

import XCTest
@testable import AiyuTerm

final class AgentCLIConfigTests: XCTestCase {
    func testRegistryContainsEightCLIs() {
        // Phase 5 ships 8 CLIs; OpenCode is deferred because it
        // needs a JS plugin rather than a hook entry.
        XCTAssertEqual(AgentCLIRegistry.allCLIs.count, 8)
    }

    func testExternalCLIsExcludeClaude() {
        let externalSources = AgentCLIRegistry.externalCLIs.map(\.source)
        XCTAssertFalse(externalSources.contains("claude"))
        XCTAssertEqual(externalSources.count, 7)
    }

    func testEveryCLIHasUniqueSourceTag() {
        let sources = AgentCLIRegistry.allCLIs.map(\.source)
        XCTAssertEqual(Set(sources).count, sources.count,
                       "Source tags must be unique — conflict would break --source routing in the bridge")
    }

    func testEveryCLIHasAtLeastOneEvent() {
        for cli in AgentCLIRegistry.allCLIs {
            XCTAssertFalse(cli.events.isEmpty, "\(cli.name) must have at least one event")
        }
    }

    func testClaudeCodeHasExactlyThirteenEvents() {
        let claude = AgentCLIRegistry.cli(forSource: "claude")
        XCTAssertEqual(claude?.events.count, 13)
        XCTAssertEqual(claude?.format, .claude)
    }

    func testClaudeCodeVersionedEventsMatchUpstream() {
        let claude = AgentCLIRegistry.cli(forSource: "claude")
        XCTAssertEqual(claude?.versionedEvents["PermissionDenied"], "2.1.89")
        XCTAssertEqual(claude?.versionedEvents["PostToolUseFailure"], "2.1.89")
    }

    func testGeminiUsesMillisecondTimeouts() {
        let gemini = AgentCLIRegistry.cli(forSource: "gemini")
        for event in gemini?.events ?? [] {
            XCTAssertGreaterThanOrEqual(
                event.timeout, 1000,
                "Gemini timeouts are in ms; \(event.name) should be at least 1000"
            )
        }
    }

    func testCopilotUsesCopilotFormat() {
        let copilot = AgentCLIRegistry.cli(forSource: "copilot")
        XCTAssertEqual(copilot?.format, .copilot)
    }

    func testCursorUsesFlatFormat() {
        let cursor = AgentCLIRegistry.cli(forSource: "cursor")
        XCTAssertEqual(cursor?.format, .flat)
    }

    func testNestedFormatCLIsAreCodexAndGemini() {
        let nestedSources = AgentCLIRegistry.allCLIs
            .filter { $0.format == .nested }
            .map(\.source)
            .sorted()
        XCTAssertEqual(nestedSources, ["codex", "gemini"])
    }

    func testClaudeForksShareFormat() {
        // Qoder / Factory (droid) / CodeBuddy all use Claude's format.
        let forks = ["qoder", "droid", "codebuddy"]
        for source in forks {
            let cli = AgentCLIRegistry.cli(forSource: source)
            XCTAssertEqual(cli?.format, .claude, "\(source) should use .claude format")
        }
    }

    func testCopilotConfigPathUsesAiyuTermFilename() {
        let copilot = AgentCLIRegistry.cli(forSource: "copilot")
        // Renamed from codeisland.json during the port.
        XCTAssertTrue(copilot?.configPath.contains("aiyuterm.json") ?? false)
        XCTAssertFalse(copilot?.configPath.contains("codeisland") ?? true)
    }

    func testFullPathResolvesUnderHomeDirectory() {
        let claude = AgentCLIRegistry.cli(forSource: "claude")
        XCTAssertTrue(claude?.fullPath.hasPrefix(NSHomeDirectory()) ?? false)
        XCTAssertTrue(claude?.fullPath.hasSuffix("/.claude/settings.json") ?? false)
    }

    func testHookIdentifierRecognizesLegacyNames() {
        XCTAssertTrue(AgentHookIdentifier.isOurs("/path/to/aiyuterm-bridge"))
        XCTAssertTrue(AgentHookIdentifier.isOurs("/path/to/codeisland-bridge"))
        XCTAssertTrue(AgentHookIdentifier.isOurs("/path/to/VIBENOTCH-bridge"))
        XCTAssertFalse(AgentHookIdentifier.isOurs("/other/tool/script.sh"))
    }
}
