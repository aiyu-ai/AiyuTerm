//
// AgentTerminalActivatorHelpersTests.swift
// AiyuTermTests
//
// Phase 9.3 tests for the pure helpers extracted from
// AgentTerminalActivator. These verify the string manipulation +
// lookup logic without touching NSWorkspace, Process, or
// AppleScript.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentTerminalActivatorHelpersTests: XCTestCase {

    // MARK: - escapeAppleScript

    func testEscapeAppleScriptDoublesBackslashesFirst() {
        // The order matters: backslashes must be escaped BEFORE
        // quotes, otherwise the escape sequences we add for quotes
        // get double-escaped.
        let input = #"C:\Users\"Me""#
        let expected = #"C:\\Users\\\"Me\""#
        XCTAssertEqual(AgentTerminalActivatorHelpers.escapeAppleScript(input), expected)
    }

    func testEscapeAppleScriptPassthroughForSafeText() {
        let input = "/Users/me/project"
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.escapeAppleScript(input),
            input
        )
    }

    func testEscapeAppleScriptEmptyString() {
        XCTAssertEqual(AgentTerminalActivatorHelpers.escapeAppleScript(""), "")
    }

    // MARK: - stripTrailingSlashes

    func testStripTrailingSlashesPreservesRoot() {
        XCTAssertEqual(AgentTerminalActivatorHelpers.stripTrailingSlashes("/"), "/")
    }

    func testStripTrailingSlashesRemovesSingle() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.stripTrailingSlashes("/Users/me/"),
            "/Users/me"
        )
    }

    func testStripTrailingSlashesRemovesMultiple() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.stripTrailingSlashes("/Users/me///"),
            "/Users/me"
        )
    }

    func testStripTrailingSlashesNoOpWithoutSlash() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.stripTrailingSlashes("/Users/me"),
            "/Users/me"
        )
    }

    // MARK: - tildePath

    func testTildePathExactHome() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.tildePath(
                forCwd: "/Users/me",
                home: "/Users/me"
            ),
            "~"
        )
    }

    func testTildePathUnderHome() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.tildePath(
                forCwd: "/Users/me/project",
                home: "/Users/me"
            ),
            "~/project"
        )
    }

    func testTildePathOutsideHome() {
        // /tmp is not under /Users/me, so we return the empty string
        // (caller uses empty to skip the title fallback).
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.tildePath(
                forCwd: "/tmp/foo",
                home: "/Users/me"
            ),
            ""
        )
    }

    func testTildePathHomePrefixWithoutSlashDoesNotMatch() {
        // "/Users/meeting" must NOT be considered "under" "/Users/me"
        // — we only match the "<home>/" prefix.
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.tildePath(
                forCwd: "/Users/meeting",
                home: "/Users/me"
            ),
            ""
        )
    }

    // MARK: - resolveTerminalName

    func testResolveTerminalNameByBundleId() {
        let result = AgentTerminalActivatorHelpers.resolveTerminalName(
            termBundleId: "com.mitchellh.ghostty",
            termApp: "tmux",
            detectFallback: { "Terminal" }
        )
        XCTAssertEqual(result, "Ghostty")
    }

    func testResolveTerminalNameFallsBackOnEmptyTermApp() {
        var called = false
        let result = AgentTerminalActivatorHelpers.resolveTerminalName(
            termBundleId: nil,
            termApp: "",
            detectFallback: {
                called = true
                return "iTerm2"
            }
        )
        XCTAssertEqual(result, "iTerm2")
        XCTAssertTrue(called)
    }

    func testResolveTerminalNameFallsBackOnTmux() {
        let result = AgentTerminalActivatorHelpers.resolveTerminalName(
            termBundleId: nil,
            termApp: "tmux",
            detectFallback: { "WezTerm" }
        )
        XCTAssertEqual(result, "WezTerm")
    }

    func testResolveTerminalNameFallsBackOnScreen() {
        let result = AgentTerminalActivatorHelpers.resolveTerminalName(
            termBundleId: nil,
            termApp: "screen",
            detectFallback: { "Ghostty" }
        )
        XCTAssertEqual(result, "Ghostty")
    }

    func testResolveTerminalNameReturnsRawWhenUsable() {
        // Unknown raw terminal name, no bundle ID — we return it as-is.
        let result = AgentTerminalActivatorHelpers.resolveTerminalName(
            termBundleId: nil,
            termApp: "UnknownTerm",
            detectFallback: { XCTFail("should not be called"); return "?" }
        )
        XCTAssertEqual(result, "UnknownTerm")
    }

    // MARK: - canonicalAppName

    func testCanonicalAppNameITerm() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "iTerm.app"),
            "iTerm2"
        )
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "iTerm2"),
            "iTerm2"
        )
    }

    func testCanonicalAppNameAppleTerminal() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "Apple_Terminal"),
            "Terminal"
        )
    }

    func testCanonicalAppNameWezTerm() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "WezTerm"),
            "WezTerm"
        )
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "wez"),
            "WezTerm"
        )
    }

    func testCanonicalAppNameWarp() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "WarpTerminal"),
            "Warp"
        )
    }

    func testCanonicalAppNameGhostty() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "ghostty"),
            "Ghostty"
        )
    }

    func testCanonicalAppNamePassesThroughUnknown() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.canonicalAppName(from: "FancyTerm"),
            "FancyTerm"
        )
    }

    // MARK: - effectiveTty

    func testEffectiveTtyUsesPaneInnerWhenNotInTmux() {
        let result = AgentTerminalActivatorHelpers.effectiveTty(
            tmuxPane: nil,
            tmuxClientTty: "/dev/ttys001",
            ttyPath: "/dev/ttys002"
        )
        XCTAssertEqual(result, "/dev/ttys002")
    }

    func testEffectiveTtyUsesClientWhenInTmux() {
        let result = AgentTerminalActivatorHelpers.effectiveTty(
            tmuxPane: "%1",
            tmuxClientTty: "/dev/ttys001",
            ttyPath: "/dev/ttys002"
        )
        XCTAssertEqual(result, "/dev/ttys001")
    }

    func testEffectiveTtyFallsBackToTtyPathWhenNoClientInTmux() {
        let result = AgentTerminalActivatorHelpers.effectiveTty(
            tmuxPane: "%1",
            tmuxClientTty: nil,
            ttyPath: "/dev/ttys002"
        )
        XCTAssertEqual(result, "/dev/ttys002")
    }

    func testEffectiveTtyNilWhenEverythingEmpty() {
        let result = AgentTerminalActivatorHelpers.effectiveTty(
            tmuxPane: nil,
            tmuxClientTty: nil,
            ttyPath: nil
        )
        XCTAssertNil(result)
    }

    // MARK: - findBinary

    func testFindBinaryReturnsNilWhenNotFound() {
        let tmpDir = NSTemporaryDirectory() + "aiyuterm-bin-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(
            atPath: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        XCTAssertNil(
            AgentTerminalActivatorHelpers.findBinary(
                named: "definitely-not-installed",
                in: [tmpDir]
            )
        )
    }

    func testFindBinaryLocatesExecutable() throws {
        let tmpDir = NSTemporaryDirectory() + "aiyuterm-bin-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(
            atPath: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let binPath = tmpDir + "myfaketool"
        try "#!/bin/sh\necho ok\n".write(
            toFile: binPath, atomically: true, encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: binPath
        )

        let result = AgentTerminalActivatorHelpers.findBinary(
            named: "myfaketool",
            in: [tmpDir]
        )
        XCTAssertEqual(result, binPath)
    }

    func testFindBinarySearchesAllPathsInOrder() throws {
        let tmpDirA = NSTemporaryDirectory() + "aiyuterm-bin-a-\(UUID().uuidString)/"
        let tmpDirB = NSTemporaryDirectory() + "aiyuterm-bin-b-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: tmpDirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: tmpDirB, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tmpDirA)
            try? FileManager.default.removeItem(atPath: tmpDirB)
        }

        // Only tmpDirB contains the tool.
        let binPath = tmpDirB + "thetool"
        try "#!/bin/sh\n".write(toFile: binPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: binPath
        )

        let result = AgentTerminalActivatorHelpers.findBinary(
            named: "thetool",
            in: [tmpDirA, tmpDirB]
        )
        XCTAssertEqual(result, binPath)
    }

    // MARK: - tmuxProcessEnv

    func testTmuxProcessEnvNilWhenEmpty() {
        XCTAssertNil(AgentTerminalActivatorHelpers.tmuxProcessEnv(nil))
        XCTAssertNil(AgentTerminalActivatorHelpers.tmuxProcessEnv(""))
        XCTAssertNil(AgentTerminalActivatorHelpers.tmuxProcessEnv("   "))
    }

    func testTmuxProcessEnvSetsTMUXVar() {
        let result = AgentTerminalActivatorHelpers.tmuxProcessEnv(
            "/private/tmp/tmux-501/default,12345,0"
        )
        XCTAssertEqual(
            result?["TMUX"],
            "/private/tmp/tmux-501/default,12345,0"
        )
    }

    // MARK: - nativeAppBundles table

    func testNativeAppBundlesIncludesCodex() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.nativeAppBundles["com.openai.codex"],
            "Codex"
        )
    }

    func testNativeAppBundlesIncludesOpenCode() {
        XCTAssertEqual(
            AgentTerminalActivatorHelpers.nativeAppBundles["ai.opencode.desktop"],
            "OpenCode"
        )
    }

    func testKnownTerminalsIncludesGhostty() {
        XCTAssertTrue(
            AgentTerminalActivatorHelpers.knownTerminals.contains {
                $0.bundleId == "com.mitchellh.ghostty" && $0.name == "Ghostty"
            }
        )
    }
}
