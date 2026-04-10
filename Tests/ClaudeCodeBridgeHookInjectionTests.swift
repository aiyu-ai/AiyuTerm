//
// ClaudeCodeBridgeHookInjectionTests.swift
// AiyuTermTests
//
// Phase 4 tests: cover the bridge hook script generator and the
// settings.json mutation logic that dual-writes bridge + legacy
// hook entries.
//
// These tests don't exercise ClaudeCodeHooksService.injectBridgeHooks
// directly because it writes into ~/.claude which is shared with the
// user's real Claude Code installation. Instead they assert that:
//   1. bridgeHookScriptURL() points at the active debug/release state
//      directory so debug and release builds cannot cross-talk.
//   2. bridgeBinaryURL() points at Contents/Helpers.
//   3. ensureBridgeHookScript() writes the expected script body into
//      the expected directory when called in isolation.
//   4. The installed script's socket fallback path matches the
//      resolved AgentHookSocketPath.
//

import XCTest
@testable import AiyuTerm

final class ClaudeCodeBridgeHookInjectionTests: XCTestCase {
    func testBridgeHookScriptURLLivesUnderActiveStateDirectory() {
        let url = ClaudeCodeHooksService.bridgeHookScriptURL()
        let expectedSuffix: String = {
            #if DEBUG
            return "/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh"
            #else
            return "/.aiyuterm/hooks/claude-code-bridge-hook.sh"
            #endif
        }()
        XCTAssertTrue(
            url.path.hasSuffix(expectedSuffix),
            "Bridge hook script path should end with \(expectedSuffix), got: \(url.path)"
        )
    }

    func testBridgeBinaryURLPointsIntoAppBundleHelpers() {
        let url = ClaudeCodeHooksService.bridgeBinaryURL()
        XCTAssertTrue(
            url.path.hasSuffix("/Contents/Helpers/aiyuterm-hook-bridge"),
            "Bridge binary path should end with /Contents/Helpers/aiyuterm-hook-bridge, got: \(url.path)"
        )
    }

    func testEnsureBridgeHookScriptWritesExecutableFile() throws {
        // Call the installer and then assert on the on-disk state.
        ClaudeCodeHooksService.ensureBridgeHookScript()

        let url = ClaudeCodeHooksService.bridgeHookScriptURL()
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Bridge hook script should exist after ensureBridgeHookScript()"
        )

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0
        // 0o755 = 493 decimal
        XCTAssertEqual(perms, 0o755, "Bridge hook script should be chmod 755")

        let body = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(body.hasPrefix("#!/bin/bash"))
        XCTAssertTrue(body.contains("aiyuterm-hook-bridge"))
        XCTAssertTrue(body.contains("exec "))
    }

    func testBridgeHookScriptContentsPointAtCurrentSocketStateDir() throws {
        ClaudeCodeHooksService.ensureBridgeHookScript()
        let url = ClaudeCodeHooksService.bridgeHookScriptURL()
        let body = try String(contentsOf: url, encoding: .utf8)
        let expectedSocketFragment = "$HOME/\(AgentHookSocketPath.stateDirectoryName)/hook.sock"
        XCTAssertTrue(
            body.contains(expectedSocketFragment),
            "Bridge hook fallback should reference \(expectedSocketFragment), body was:\n\(body)"
        )
    }

    func testEnsureBridgeHookScriptIsIdempotent() throws {
        ClaudeCodeHooksService.ensureBridgeHookScript()
        let url = ClaudeCodeHooksService.bridgeHookScriptURL()
        let firstMtime = try FileManager.default
            .attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertNotNil(firstMtime)

        // Sleep briefly so a second write would produce a different
        // mtime, then re-run. The guard inside ensureBridgeHookScript()
        // should skip the write because the on-disk content is already
        // current.
        Thread.sleep(forTimeInterval: 0.05)
        ClaudeCodeHooksService.ensureBridgeHookScript()
        let secondMtime = try FileManager.default
            .attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(firstMtime, secondMtime,
                       "Idempotent installer should not rewrite identical files")
    }
}
