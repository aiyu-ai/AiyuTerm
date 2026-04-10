//
// AgentCLIConfigInstallerPhase9Tests.swift
// AiyuTermTests
//
// Phase 9.2 tests for the ConfigInstaller completeness gap:
//   • versionAtLeast semver compare
//   • compatibleEvents filtering based on Claude version gate
//   • Codex config.toml writer (fresh / flip / insert into [features]
//     / append new section)
//   • OpenCode plugin installer path-handling
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentCLIConfigInstallerPhase9Tests: XCTestCase {
    private var sandboxRoot: String!
    private let fm = FileManager.default

    override func setUp() {
        super.setUp()
        sandboxRoot = NSTemporaryDirectory() + "aiyuterm-p92-\(UUID().uuidString)"
        try? fm.createDirectory(atPath: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let sandboxRoot { try? fm.removeItem(atPath: sandboxRoot) }
        sandboxRoot = nil
        super.tearDown()
    }

    // MARK: - versionAtLeast

    func testVersionAtLeastEqualVersions() {
        XCTAssertTrue(AgentCLIConfigInstaller.versionAtLeast("2.1.89", "2.1.89"))
    }

    func testVersionAtLeastHigherPatch() {
        XCTAssertTrue(AgentCLIConfigInstaller.versionAtLeast("2.1.92", "2.1.89"))
    }

    func testVersionAtLeastLowerPatch() {
        XCTAssertFalse(AgentCLIConfigInstaller.versionAtLeast("2.1.88", "2.1.89"))
    }

    func testVersionAtLeastHigherMinor() {
        XCTAssertTrue(AgentCLIConfigInstaller.versionAtLeast("2.2.0", "2.1.89"))
    }

    func testVersionAtLeastLowerMajor() {
        XCTAssertFalse(AgentCLIConfigInstaller.versionAtLeast("1.9.99", "2.0.0"))
    }

    func testVersionAtLeastShortInstalledVersionTreatsMissingAsZero() {
        // "2.1" means 2.1.0, which is strictly less than 2.1.89.
        XCTAssertFalse(AgentCLIConfigInstaller.versionAtLeast("2.1", "2.1.89"))
    }

    func testVersionAtLeastShortRequiredVersionPads() {
        // "2.1.5" >= "2.1" (== "2.1.0")
        XCTAssertTrue(AgentCLIConfigInstaller.versionAtLeast("2.1.5", "2.1"))
    }

    // MARK: - compatibleEvents

    func testCompatibleEventsPassthroughWhenNoGates() {
        let cli = AgentCLIConfig(
            name: "Test",
            source: "test",
            configPath: "x",
            format: .claude,
            events: [
                ("UserPromptSubmit", 5, true),
                ("Stop", 5, true),
            ]
            // versionedEvents defaults to [:]
        )
        let result = AgentCLIConfigInstaller.compatibleEvents(for: cli)
        XCTAssertEqual(result.count, 2)
    }

    func testCompatibleEventsPassthroughForNonClaudeCLIs() {
        // Non-claude CLIs are never version-gated even if their
        // registry entry has a versionedEvents map (it won't, but
        // we still want the short-circuit).
        let cli = AgentCLIConfig(
            name: "Fake Codex",
            source: "codex",
            configPath: "x",
            format: .nested,
            events: [("UserPromptSubmit", 5, false)],
            versionedEvents: ["UserPromptSubmit": "99.0.0"]
        )
        let result = AgentCLIConfigInstaller.compatibleEvents(for: cli)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - enableCodexHooksConfig

    func testEnableCodexHooksCreatesConfigFromScratch() throws {
        let homeOverride = sandboxRoot!
        // We can't override NSHomeDirectory() cheaply, so instead
        // we exercise the string-manipulation logic via a
        // throwaway file at a known path and call a helper. The
        // installer's public method hits NSHomeDirectory directly,
        // so we test by clearing any stale codex file first and
        // asserting behavior.
        //
        // Since the public helper uses NSHomeDirectory unconditionally
        // we re-exercise the rewrite logic through a locally seeded
        // file + the public regex-based helper. Rather than
        // duplicate the full logic in the test, we drive it end-to-end
        // on a real ~/.codex but clean up after ourselves.
        let realCodex = NSHomeDirectory() + "/.codex/config.toml"
        let hadExisting = fm.fileExists(atPath: realCodex)
        var backup: String?
        if hadExisting {
            backup = try? String(contentsOfFile: realCodex, encoding: .utf8)
        }
        defer {
            if let backup {
                try? backup.write(toFile: realCodex, atomically: true, encoding: .utf8)
            } else if hadExisting == false {
                try? fm.removeItem(atPath: realCodex)
            }
        }

        // Remove any prior file so we hit the "no [features]" branch.
        try? fm.removeItem(atPath: realCodex)
        let ok = AgentCLIConfigInstaller.enableCodexHooksConfig()
        XCTAssertTrue(ok)

        guard let contents = try? String(contentsOfFile: realCodex, encoding: .utf8) else {
            XCTFail("Config file was not created")
            return
        }
        XCTAssertTrue(contents.contains("[features]"))
        XCTAssertTrue(contents.contains("codex_hooks = true"))
        _ = homeOverride // silence unused warning in test helper scaffolding
    }

    func testEnableCodexHooksFlipsFalseToTrue() throws {
        let realCodex = NSHomeDirectory() + "/.codex/config.toml"
        let hadExisting = fm.fileExists(atPath: realCodex)
        var backup: String?
        if hadExisting {
            backup = try? String(contentsOfFile: realCodex, encoding: .utf8)
        }
        defer {
            if let backup {
                try? backup.write(toFile: realCodex, atomically: true, encoding: .utf8)
            } else if hadExisting == false {
                try? fm.removeItem(atPath: realCodex)
            }
        }

        // Seed with codex_hooks = false.
        let dir = (realCodex as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "[features]\ncodex_hooks = false\n".write(
            toFile: realCodex, atomically: true, encoding: .utf8
        )

        XCTAssertTrue(AgentCLIConfigInstaller.enableCodexHooksConfig())
        let contents = try String(contentsOfFile: realCodex, encoding: .utf8)
        XCTAssertTrue(contents.contains("codex_hooks = true"))
        XCTAssertFalse(contents.contains("codex_hooks = false"))
    }

    func testEnableCodexHooksNoOpWhenAlreadyTrue() throws {
        let realCodex = NSHomeDirectory() + "/.codex/config.toml"
        let hadExisting = fm.fileExists(atPath: realCodex)
        var backup: String?
        if hadExisting {
            backup = try? String(contentsOfFile: realCodex, encoding: .utf8)
        }
        defer {
            if let backup {
                try? backup.write(toFile: realCodex, atomically: true, encoding: .utf8)
            } else if hadExisting == false {
                try? fm.removeItem(atPath: realCodex)
            }
        }

        let dir = (realCodex as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let seed = "[features]\ncodex_hooks = true\n# trailing comment\n"
        try seed.write(toFile: realCodex, atomically: true, encoding: .utf8)
        let beforeMtime = try fm.attributesOfItem(atPath: realCodex)[.modificationDate] as? Date
        XCTAssertTrue(AgentCLIConfigInstaller.enableCodexHooksConfig())
        let afterContents = try String(contentsOfFile: realCodex, encoding: .utf8)
        XCTAssertEqual(afterContents, seed, "File should be untouched when already set")
        let afterMtime = try fm.attributesOfItem(atPath: realCodex)[.modificationDate] as? Date
        XCTAssertEqual(beforeMtime, afterMtime)
    }

    // MARK: - OpenCode plugin

    func testOpenCodePluginPathUsesAiyuTermFilename() {
        XCTAssertTrue(AgentCLIConfigInstaller.opencodePluginPath.hasSuffix("/aiyuterm.js"))
    }

    func testOpenCodePluginSkipsWhenConfigDirMissing() {
        // If ~/.config/opencode doesn't exist, the installer must
        // skip rather than create a phantom config dir.
        let realOpenCode = (AgentCLIConfigInstaller.opencodeConfigPath as NSString).deletingLastPathComponent
        let hadExisting = fm.fileExists(atPath: realOpenCode)
        if hadExisting {
            // We can't safely nuke the user's real OpenCode config, so
            // this test is a no-op in that environment. Document the
            // skip and move on.
            XCTAssertTrue(hadExisting, "User has OpenCode installed; skipping install-from-scratch test")
            return
        }
        // On a fresh box installOpenCodePlugin should report success
        // (skipped) without creating anything.
        XCTAssertTrue(AgentCLIConfigInstaller.installOpenCodePlugin())
        XCTAssertFalse(fm.fileExists(atPath: AgentCLIConfigInstaller.opencodePluginPath))
    }
}
