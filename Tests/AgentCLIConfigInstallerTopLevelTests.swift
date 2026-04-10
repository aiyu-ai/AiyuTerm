//
// AgentCLIConfigInstallerTopLevelTests.swift
// AiyuTermTests
//
// Phase 5.4 tests: cover install() / uninstallAll() /
// verifyAndRepair() / discoverCLIs() / setCLIEnabled().
//
// These tests inject a sandboxed registry and an in-memory
// enablement store so they never touch the host ~/.claude or
// UserDefaults.standard.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentCLIConfigInstallerTopLevelTests: XCTestCase {

    private var sandboxRoot: String!
    private var store: InMemoryAgentCLIEnablementStore!
    private let fm = FileManager.default

    // Fake bridge artifacts — we don't need them to actually exist
    // on disk for the writer tests; the writer only embeds the path
    // string into JSON.
    private let fakeClaudeHookCommand = "/tmp/fake/aiyuterm-bridge-hook.sh"
    private let fakeBridgeBinary = "/tmp/fake/aiyuterm-hook-bridge"

    override func setUp() {
        super.setUp()
        sandboxRoot = NSTemporaryDirectory() + "aiyuterm-toplevel-\(UUID().uuidString)"
        try? fm.createDirectory(atPath: sandboxRoot, withIntermediateDirectories: true)
        store = InMemoryAgentCLIEnablementStore()
    }

    override func tearDown() {
        if let sandboxRoot { try? fm.removeItem(atPath: sandboxRoot) }
        sandboxRoot = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Sandbox registry helpers

    /// Build an AgentCLIConfig whose `configPath` resolves to a file
    /// inside sandboxRoot. Uses symlink trickery through a relative
    /// path against NSHomeDirectory() to sidestep App Sandbox's
    /// home-escape restriction — we pre-create a link inside
    /// $HOME/Library/Caches/... pointing at sandbox, then express
    /// configPath relative to that.
    ///
    /// Simpler reality: we set configPath to a path under an
    /// "aiyuterm-test-root" directory we create inside the cache
    /// folder so everything the installer touches ends up under
    /// the sandbox writable area.
    ///
    /// For this test suite we use an even simpler approach: create
    /// the CLI with a configPath computed relative to the cache
    /// directory within $HOME, which is always writable.
    private func makeSandboxCLI(
        name: String,
        source: String,
        format: AgentHookFormat,
        events: [(name: String, timeout: Int, async: Bool)],
        filename: String
    ) -> (AgentCLIConfig, dirPath: String, fullPath: String) {
        let relative = "Library/Caches/com.aiyuai.aiyuterm.tests/\(source)-\(UUID().uuidString)"
        let absoluteDir = NSHomeDirectory() + "/" + relative
        try? fm.createDirectory(atPath: absoluteDir, withIntermediateDirectories: true)
        let fullPath = absoluteDir + "/" + filename
        let cli = AgentCLIConfig(
            name: name,
            source: source,
            configPath: relative + "/" + filename,
            format: format,
            events: events
        )
        return (cli, absoluteDir, fullPath)
    }

    // MARK: - install()

    func testInstallSkipsDisabledCLIs() {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: false)

        let installed = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(installed, [])
        XCTAssertFalse(fm.fileExists(atPath: claudePath),
                       "Disabled CLI must not create its config file")
    }

    func testInstallInstallsEnabledClaude() {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: true)

        let installed = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(installed, ["Claude Code"])
        XCTAssertTrue(fm.fileExists(atPath: claudePath))
    }

    func testInstallSkipsExternalCLIWhenDirMissing() {
        // Create a CLI whose configPath dir does NOT exist on disk.
        // `looksInstalledOnDisk` returns false so install() should
        // skip it entirely.
        let relative = "Library/Caches/com.aiyuai.aiyuterm.tests/missing-\(UUID().uuidString)"
        // Note: we deliberately do NOT create the directory.
        let cli = AgentCLIConfig(
            name: "Codex Unonboarded",
            source: "codex",
            configPath: relative + "/hooks.json",
            format: .nested,
            events: [("Stop", 5, false)]
        )
        store.setCLIEnabled(source: "codex", enabled: true)

        let installed = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [cli],
            enablementStore: store
        )
        XCTAssertEqual(installed, [])
    }

    func testInstallAlreadyInstalledIsExcludedFromReturn() {
        let (claudeCLI, _, _) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: true)

        let first = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(first, ["Claude Code"])

        let second = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(second, [],
                       "Re-run should see .alreadyInstalled for every CLI")
    }

    // MARK: - uninstallAll()

    func testUninstallAllRewritesInstalledCLIs() {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: true)

        _ = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertTrue(fm.fileExists(atPath: claudePath))

        let rewritten = AgentCLIConfigInstaller.uninstallAll(registry: [claudeCLI])
        XCTAssertEqual(rewritten, ["Claude Code"])

        // File still exists but with hooks key removed (or empty
        // top-level dict).
        XCTAssertTrue(fm.fileExists(atPath: claudePath))
        let data = try! Data(contentsOf: URL(fileURLWithPath: claudePath))
        let root = try! JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(root?["hooks"])
    }

    func testUninstallAllIgnoresMissingFiles() {
        let (claudeCLI, _, _) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "never-created.json"
        )
        // Don't install — file doesn't exist.
        let rewritten = AgentCLIConfigInstaller.uninstallAll(registry: [claudeCLI])
        XCTAssertEqual(rewritten, [])
    }

    // MARK: - verifyAndRepair()

    func testVerifyAndRepairDoesNothingWhenAllInstalled() {
        let (claudeCLI, _, _) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: true)
        _ = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )

        let repaired = AgentCLIConfigInstaller.verifyAndRepair(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(repaired, [])
    }

    func testVerifyAndRepairReinstallsDriftedConfig() throws {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: true)

        // Write a config that's missing our hook entry entirely.
        let driftedSeed: [String: Any] = [
            "hooks": ["Stop": [[ "matcher": "", "hooks": [
                ["type": "command", "command": "/usr/local/bin/some-other-tool"],
            ]]]],
        ]
        let data = try JSONSerialization.data(withJSONObject: driftedSeed, options: [.prettyPrinted])
        try data.write(to: URL(fileURLWithPath: claudePath))

        let repaired = AgentCLIConfigInstaller.verifyAndRepair(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(repaired, ["Claude Code"])

        // After repair the Stop event should have BOTH entries:
        // the original other-tool + our newly injected bridge hook.
        let after = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: claudePath))
        ) as? [String: Any]
        let stop = (after?["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 2)
    }

    func testVerifyAndRepairSkipsDisabledCLI() throws {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        store.setCLIEnabled(source: "claude", enabled: false)

        let repaired = AgentCLIConfigInstaller.verifyAndRepair(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(repaired, [])
        XCTAssertFalse(fm.fileExists(atPath: claudePath))
    }

    // MARK: - discoverCLIs()

    func testDiscoverCLIsReportsClaudeAsEnabledByDefault() {
        let (claudeCLI, _, _) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        // Note: we intentionally do NOT touch the store; Claude
        // should default to enabled.
        let status = AgentCLIConfigInstaller.discoverCLIs(
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertEqual(status.count, 1)
        XCTAssertEqual(status[0].source, "claude")
        XCTAssertTrue(status[0].userEnabled, "Claude should default to enabled")
        XCTAssertTrue(status[0].cliPresent,
                      "Sandbox dir was created in setUp helper")
        XCTAssertFalse(status[0].hookInstalled)
    }

    func testDiscoverCLIsReportsCodexDefaultDisabled() {
        // Create a sandbox CLI directory so cliPresent=true but
        // leave enablement unset.
        let (codexCLI, _, _) = makeSandboxCLI(
            name: "Codex",
            source: "codex",
            format: .nested,
            events: [("Stop", 5, false)],
            filename: "hooks.json"
        )
        let status = AgentCLIConfigInstaller.discoverCLIs(
            registry: [codexCLI],
            enablementStore: store
        )
        XCTAssertEqual(status.count, 1)
        XCTAssertEqual(status[0].source, "codex")
        XCTAssertFalse(status[0].userEnabled,
                       "Non-Claude CLIs should default to disabled")
    }

    // MARK: - setCLIEnabled()

    func testSetCLIEnabledInstallsWhenFlippingOn() {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        // Start disabled
        store.setCLIEnabled(source: "claude", enabled: false)
        XCTAssertFalse(fm.fileExists(atPath: claudePath))

        let result = AgentCLIConfigInstaller.setCLIEnabled(
            source: "claude",
            enabled: true,
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertTrue(result, "Flipping on should return installed=true")
        XCTAssertTrue(fm.fileExists(atPath: claudePath))
        XCTAssertTrue(store.isCLIEnabled(source: "claude", defaultValue: false))
    }

    func testSetCLIEnabledUninstallsWhenFlippingOff() throws {
        let (claudeCLI, _, claudePath) = makeSandboxCLI(
            name: "Claude Code",
            source: "claude",
            format: .claude,
            events: [("Stop", 5, true)],
            filename: "settings.json"
        )
        // Install first
        store.setCLIEnabled(source: "claude", enabled: true)
        _ = AgentCLIConfigInstaller.install(
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertTrue(fm.fileExists(atPath: claudePath))

        let result = AgentCLIConfigInstaller.setCLIEnabled(
            source: "claude",
            enabled: false,
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [claudeCLI],
            enablementStore: store
        )
        XCTAssertFalse(result, "Flipping off should return installed=false")
        XCTAssertFalse(store.isCLIEnabled(source: "claude", defaultValue: true))
        // File still exists; hooks removed inside.
        let data = try Data(contentsOf: URL(fileURLWithPath: claudePath))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(root?["hooks"])
    }

    func testSetCLIEnabledReturnsFalseForUnknownSource() {
        let result = AgentCLIConfigInstaller.setCLIEnabled(
            source: "nonexistent",
            enabled: true,
            claudeHookCommand: fakeClaudeHookCommand,
            externalBridgeBinaryPath: fakeBridgeBinary,
            registry: [],
            enablementStore: store
        )
        XCTAssertFalse(result)
    }

    // MARK: - InMemoryAgentCLIEnablementStore

    func testInMemoryStoreDefaultValue() {
        let s = InMemoryAgentCLIEnablementStore()
        XCTAssertTrue(s.isCLIEnabled(source: "unset", defaultValue: true))
        XCTAssertFalse(s.isCLIEnabled(source: "unset", defaultValue: false))
    }

    func testInMemoryStoreStoresAndRecallsValue() {
        let s = InMemoryAgentCLIEnablementStore()
        s.setCLIEnabled(source: "claude", enabled: true)
        XCTAssertTrue(s.isCLIEnabled(source: "claude", defaultValue: false))
        s.setCLIEnabled(source: "claude", enabled: false)
        XCTAssertFalse(s.isCLIEnabled(source: "claude", defaultValue: true))
    }
}
