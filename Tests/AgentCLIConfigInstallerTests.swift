//
// AgentCLIConfigInstallerTests.swift
// AiyuTermTests
//
// Phase 5.2 tests for the .claude format writer and the JSONC
// stripper. Uses a sandboxed FileManager scratch directory so the
// tests never touch the real ~/.claude/settings.json.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AgentCLIConfigInstallerTests: XCTestCase {

    private var sandboxRoot: String!
    private let fm = FileManager.default

    override func setUp() {
        super.setUp()
        sandboxRoot = NSTemporaryDirectory() + "aiyuterm-installer-\(UUID().uuidString)"
        try? fm.createDirectory(atPath: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let sandboxRoot { try? fm.removeItem(atPath: sandboxRoot) }
        sandboxRoot = nil
        super.tearDown()
    }

    // MARK: - stripJSONComments

    func testStripLineCommentsLeavesContent() {
        let input = """
        // top
        {
          "a": 1, // trailing
          "b": 2
        }
        """
        let stripped = AgentCLIConfigInstaller.stripJSONComments(input)
        XCTAssertFalse(stripped.contains("// top"))
        XCTAssertFalse(stripped.contains("// trailing"))
        // JSON should still parse
        let data = stripped.data(using: .utf8)!
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["a"] as? Int, 1)
        XCTAssertEqual(obj?["b"] as? Int, 2)
    }

    func testStripBlockComments() {
        let input = """
        {
          /* header
             multi-line */
          "x": "y" /* trailing */
        }
        """
        let stripped = AgentCLIConfigInstaller.stripJSONComments(input)
        XCTAssertFalse(stripped.contains("/*"))
        XCTAssertFalse(stripped.contains("*/"))
        let data = stripped.data(using: .utf8)!
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["x"] as? String, "y")
    }

    func testStripPreservesStringLiteralsWithCommentSequences() {
        // The stripper must NOT strip slashes inside string literals.
        let input = #"{"url": "https://example.com/path"}"#
        let stripped = AgentCLIConfigInstaller.stripJSONComments(input)
        XCTAssertEqual(stripped, input)
    }

    func testStripPreservesEscapedQuotesInsideStrings() {
        let input = #"{"msg": "She said \"hi\" // not a comment"}"#
        let stripped = AgentCLIConfigInstaller.stripJSONComments(input)
        XCTAssertEqual(stripped, input)
    }

    // MARK: - containsOurHook

    func testContainsOurHookClaudeFormat() {
        let entry: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": "/tmp/aiyuterm-bridge/foo.sh"],
            ],
        ]
        XCTAssertTrue(AgentCLIConfigInstaller.containsOurHook(entry))
    }

    func testContainsOurHookFlatFormat() {
        let entry: [String: Any] = [
            "command": "/tmp/codeisland-bridge",
        ]
        XCTAssertTrue(AgentCLIConfigInstaller.containsOurHook(entry))
    }

    func testContainsOurHookCopilotFormat() {
        let entry: [String: Any] = [
            "type": "bash",
            "bash": "~/bin/aiyuterm-bridge --source copilot",
            "timeoutSec": 5,
        ]
        XCTAssertTrue(AgentCLIConfigInstaller.containsOurHook(entry))
    }

    func testContainsOurHookRejectsOtherTools() {
        let entry: [String: Any] = [
            "hooks": [["command": "/usr/local/bin/other-tool.sh"]],
        ]
        XCTAssertFalse(AgentCLIConfigInstaller.containsOurHook(entry))
    }

    // MARK: - removeManagedHookEntries

    func testRemoveManagedEntriesDropsAiyuTermDebugBridgeHook() {
        // The product-name marker 'aiyuterm' matches any path under
        // ~/.aiyuterm or ~/.aiyuterm-debug, so the Phase 4 bridge
        // hook script must be cleaned out during re-install.
        let hooks: [String: Any] = [
            "Stop": [
                [
                    "matcher": "",
                    "hooks": [["command": "~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh"]],
                ],
                [
                    "matcher": "",
                    "hooks": [["command": "/usr/local/bin/other-tool"]],
                ],
            ],
        ]
        let cleaned = AgentCLIConfigInstaller.removeManagedHookEntries(from: hooks)
        let stopEntries = cleaned["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopEntries?.count, 1,
                       "Phase 4 bridge hook should be swept out; other-tool stays")
        let cmd = ((stopEntries?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String
        XCTAssertEqual(cmd, "/usr/local/bin/other-tool")
    }

    func testRemoveManagedEntriesDropsCurrentMarker() {
        let hooks: [String: Any] = [
            "Stop": [
                [
                    "matcher": "",
                    "hooks": [["command": "/path/to/aiyuterm-bridge-hook.sh"]],
                ],
                [
                    "matcher": "",
                    "hooks": [["command": "/usr/local/bin/other-tool"]],
                ],
            ],
        ]
        let cleaned = AgentCLIConfigInstaller.removeManagedHookEntries(from: hooks)
        let stopEntries = cleaned["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopEntries?.count, 1, "Only other-tool should survive")
        let cmd = ((stopEntries?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String
        XCTAssertEqual(cmd, "/usr/local/bin/other-tool")
    }

    func testRemoveManagedEntriesDropsBridgeHook() {
        let hooks: [String: Any] = [
            "Stop": [
                [
                    "matcher": "",
                    "hooks": [["command": "/path/aiyuterm-bridge"]],
                ],
                [
                    "matcher": "",
                    "hooks": [["command": "/usr/local/bin/other-tool"]],
                ],
            ],
        ]
        let cleaned = AgentCLIConfigInstaller.removeManagedHookEntries(from: hooks)
        let stopEntries = cleaned["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopEntries?.count, 1)
        let remainingCmd = ((stopEntries?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String
        XCTAssertEqual(remainingCmd, "/usr/local/bin/other-tool")
    }

    func testRemoveManagedEntriesRemovesEmptyEvents() {
        let hooks: [String: Any] = [
            "UserPromptSubmit": [
                [
                    "matcher": "",
                    "hooks": [["command": "/path/codeisland-hook.sh"]],
                ],
            ],
        ]
        let cleaned = AgentCLIConfigInstaller.removeManagedHookEntries(from: hooks)
        XCTAssertNil(cleaned["UserPromptSubmit"],
                     "Empty event arrays should be removed from the dict")
    }

    // MARK: - parseJSONFile

    func testParseJSONFileHandlesJSONC() throws {
        let path = sandboxRoot + "/settings-jsonc.json"
        let body = """
        // Managed by AiyuTerm
        {
          "hooks": {
            "Stop": [] /* empty */
          }
        }
        """
        try body.write(toFile: path, atomically: true, encoding: .utf8)
        let parsed = AgentCLIConfigInstaller.parseJSONFile(at: path)
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["hooks"])
    }

    func testParseJSONFileReturnsNilForMissingFile() {
        let result = AgentCLIConfigInstaller.parseJSONFile(at: sandboxRoot + "/does-not-exist.json")
        XCTAssertNil(result)
    }

    func testParseJSONFileReturnsNilForMalformedJSON() throws {
        let path = sandboxRoot + "/malformed.json"
        try "{ this is not json".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertNil(AgentCLIConfigInstaller.parseJSONFile(at: path))
    }

    // MARK: - installClaudeAt (sandbox-safe variant)

    /// Three standard events used by all installClaudeAt tests.
    private let sandboxEvents: [(name: String, timeout: Int, async: Bool)] = [
        ("UserPromptSubmit", 5, true),
        ("Stop", 5, true),
        ("Notification", 86400, false),
    ]

    private func sandboxFullPath(filename: String = "claude-settings.json") -> String {
        sandboxRoot + "/" + filename
    }

    private func installAt(
        fullPath: String,
        hookCommand: String = "/tmp/fake/aiyuterm-bridge-hook.sh"
    ) -> AgentCLIConfigInstaller.InstallOutcome {
        AgentCLIConfigInstaller.installClaudeAt(
            events: sandboxEvents,
            configKey: "hooks",
            fullPath: fullPath,
            dirPath: (fullPath as NSString).deletingLastPathComponent,
            format: .claude,
            debugName: "sandbox-claude",
            hookCommand: hookCommand
        )
    }

    func testInstallClaudeWritesHookEntries() throws {
        let path = sandboxFullPath()
        let outcome = installAt(fullPath: path)
        XCTAssertEqual(outcome, .installed)

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = root?["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks)

        for event in sandboxEvents {
            guard let entries = hooks?[event.name] as? [[String: Any]] else {
                XCTFail("Missing event \(event.name)")
                continue
            }
            XCTAssertEqual(entries.count, 1)
            let hookList = entries[0]["hooks"] as? [[String: Any]]
            XCTAssertEqual(hookList?.first?["command"] as? String,
                           "/tmp/fake/aiyuterm-bridge-hook.sh")
            XCTAssertEqual(hookList?.first?["timeout"] as? Int, event.timeout)
            // Sync flag preserved
            if event.async {
                XCTAssertEqual(hookList?.first?["async"] as? Bool, true,
                               "async flag missing for \(event.name)")
            } else {
                XCTAssertNil(hookList?.first?["async"],
                             "async flag should not be set for \(event.name)")
            }
        }
    }

    func testInstallClaudeIsIdempotent() throws {
        let path = sandboxFullPath()
        XCTAssertEqual(installAt(fullPath: path), .installed)
        XCTAssertEqual(installAt(fullPath: path), .alreadyInstalled,
                       "Re-run should no-op")
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        XCTAssertNotNil(attrs[.modificationDate])
    }

    func testInstallClaudePreservesForeignHookEntries() throws {
        let path = sandboxFullPath()

        let seed: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [
                            ["type": "command",
                             "command": "/usr/local/bin/other-tool"],
                        ],
                    ],
                ],
                "OtherEvent": [
                    [
                        "matcher": "x",
                        "hooks": [["command": "/usr/local/bin/yet-another"]],
                    ],
                ],
            ],
            "someOtherKey": "value",
        ]
        let data = try JSONSerialization.data(
            withJSONObject: seed,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: URL(fileURLWithPath: path))

        _ = installAt(fullPath: path)

        let after = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: path))
        ) as? [String: Any]

        XCTAssertEqual(after?["someOtherKey"] as? String, "value")

        let hooks = after?["hooks"] as? [String: Any]
        let otherEvent = hooks?["OtherEvent"] as? [[String: Any]]
        XCTAssertEqual(otherEvent?.count, 1)

        let stop = hooks?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 2, "Foreign + new aiyuterm entry")
    }

    func testInstallClaudeReplacesLegacyCodeIslandEntries() throws {
        let path = sandboxFullPath()

        let seed: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [
                            ["type": "command",
                             "command": "/old/codeisland-bridge"],
                        ],
                    ],
                ],
            ],
        ]
        let data = try JSONSerialization.data(
            withJSONObject: seed,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: URL(fileURLWithPath: path))

        _ = installAt(fullPath: path)

        let after = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: path))
        ) as? [String: Any]
        let stop = (after?["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 1, "Legacy entry replaced, not appended")
        let cmd = ((stop?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String
        XCTAssertEqual(cmd, "/tmp/fake/aiyuterm-bridge-hook.sh")
    }

    // MARK: - isHooksInstalledAt

    func testIsHooksInstalledTrueAfterInstall() {
        let path = sandboxFullPath()
        _ = installAt(fullPath: path)
        XCTAssertTrue(AgentCLIConfigInstaller.isHooksInstalledAt(
            fullPath: path,
            configKey: "hooks",
            events: sandboxEvents
        ))
    }

    func testIsHooksInstalledFalseWhenFileMissing() {
        XCTAssertFalse(AgentCLIConfigInstaller.isHooksInstalledAt(
            fullPath: sandboxFullPath(),
            configKey: "hooks",
            events: sandboxEvents
        ))
    }

    // MARK: - installExternalAt - .nested format (Codex / Gemini)

    private let nestedEvents: [(name: String, timeout: Int, async: Bool)] = [
        ("SessionStart", 5, false),
        ("UserPromptSubmit", 5, false),
        ("PreToolUse", 5, false),
    ]

    func testInstallNestedWritesEntries() throws {
        let path = sandboxRoot + "/codex-hooks.json"
        let outcome = AgentCLIConfigInstaller.installExternalAt(
            format: .nested,
            source: "codex",
            events: nestedEvents,
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot,
            debugName: "Codex",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertEqual(outcome, .installed)

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = root?["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks)

        for event in nestedEvents {
            let entries = hooks?[event.name] as? [[String: Any]]
            XCTAssertEqual(entries?.count, 1)
            // Nested format has NO 'matcher' key; commands live in
            // entry.hooks[].command.
            XCTAssertNil(entries?.first?["matcher"],
                         "Nested format must not emit 'matcher'")
            let inner = entries?.first?["hooks"] as? [[String: Any]]
            XCTAssertEqual(inner?.first?["command"] as? String,
                           "/usr/local/bin/aiyuterm-hook-bridge --source codex")
            XCTAssertEqual(inner?.first?["timeout"] as? Int, event.timeout)
        }
    }

    func testInstallNestedIsIdempotent() throws {
        let path = sandboxRoot + "/codex-hooks.json"
        let first = AgentCLIConfigInstaller.installExternalAt(
            format: .nested,
            source: "codex",
            events: nestedEvents,
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot,
            debugName: "Codex",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertEqual(first, .installed)
        let second = AgentCLIConfigInstaller.installExternalAt(
            format: .nested,
            source: "codex",
            events: nestedEvents,
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot,
            debugName: "Codex",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertEqual(second, .alreadyInstalled)
    }

    func testInstallNestedQuotesBridgePathWithSpaces() throws {
        let path = sandboxRoot + "/gemini-settings.json"
        _ = AgentCLIConfigInstaller.installExternalAt(
            format: .nested,
            source: "gemini",
            events: [("BeforeTool", 5000, false)],
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot,
            debugName: "Gemini",
            bridgeBinaryPath: "/Applications/AiyuTerm 1.app/Contents/Helpers/aiyuterm-hook-bridge"
        )

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = (root?["hooks"] as? [String: Any])?["BeforeTool"] as? [[String: Any]]
        let cmd = (entries?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        XCTAssertEqual(
            cmd,
            "\"/Applications/AiyuTerm 1.app/Contents/Helpers/aiyuterm-hook-bridge\" --source gemini",
            "Bridge paths with spaces must be quoted"
        )
    }

    // MARK: - installExternalAt - .flat format (Cursor)

    func testInstallFlatWritesSingleCommandEntry() throws {
        let path = sandboxRoot + "/cursor-hooks.json"
        let outcome = AgentCLIConfigInstaller.installExternalAt(
            format: .flat,
            source: "cursor",
            events: [
                ("beforeSubmitPrompt", 5, false),
                ("afterAgentResponse", 5, false),
            ],
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot,
            debugName: "Cursor",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertEqual(outcome, .installed)

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = root?["hooks"] as? [String: Any]

        let entries = hooks?["beforeSubmitPrompt"] as? [[String: Any]]
        XCTAssertEqual(entries?.count, 1)
        // Flat format: entry is just {command: ...} — no nesting.
        XCTAssertEqual(entries?.first?["command"] as? String,
                       "/usr/local/bin/aiyuterm-hook-bridge --source cursor")
        XCTAssertNil(entries?.first?["hooks"],
                     "Flat format must not emit nested 'hooks'")
    }

    // MARK: - installExternalAt - .copilot format

    func testInstallCopilotSkipsWhenParentMissing() {
        // Do NOT pre-create a .copilot parent — the installer must
        // treat this as 'Copilot not onboarded' and return
        // .alreadyInstalled (a no-op).
        let path = sandboxRoot + "/missing-copilot/hooks/aiyuterm.json"
        let outcome = AgentCLIConfigInstaller.installExternalAt(
            format: .copilot,
            source: "copilot",
            events: [("sessionStart", 5, false)],
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot + "/missing-copilot/hooks",
            debugName: "Copilot",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertEqual(outcome, .alreadyInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testInstallCopilotCreatesVersionedFileWhenParentExists() throws {
        // Pre-create ~/.copilot analog inside sandbox.
        let copilotRoot = sandboxRoot + "/dot-copilot"
        let hooksDir = copilotRoot + "/hooks"
        try FileManager.default.createDirectory(
            atPath: copilotRoot, withIntermediateDirectories: true
        )
        let path = hooksDir + "/aiyuterm.json"

        let outcome = AgentCLIConfigInstaller.installExternalAt(
            format: .copilot,
            source: "copilot",
            events: [
                ("sessionStart", 5, false),
                ("postToolUse", 5, true),
            ],
            configKey: "hooks",
            fullPath: path,
            dirPath: hooksDir,
            debugName: "Copilot",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertEqual(outcome, .installed)

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // Top-level 'version' must be present for Copilot.
        XCTAssertEqual(root?["version"] as? Int, 1)

        let entries = (root?["hooks"] as? [String: Any])?["sessionStart"] as? [[String: Any]]
        XCTAssertEqual(entries?.count, 1)
        // Copilot entry shape: {type, bash, timeoutSec}.
        XCTAssertEqual(entries?.first?["type"] as? String, "command")
        XCTAssertEqual(
            entries?.first?["bash"] as? String,
            "/usr/local/bin/aiyuterm-hook-bridge --source copilot --event sessionStart",
            "Copilot bash command must include --event suffix"
        )
        XCTAssertEqual(entries?.first?["timeoutSec"] as? Int, 5)
    }

    // MARK: - uninstallAt

    func testUninstallRemovesManagedEntries() throws {
        let path = sandboxRoot + "/uninstall.json"
        // Install first.
        _ = AgentCLIConfigInstaller.installExternalAt(
            format: .flat,
            source: "cursor",
            events: [("beforeSubmitPrompt", 5, false)],
            configKey: "hooks",
            fullPath: path,
            dirPath: sandboxRoot,
            debugName: "Cursor",
            bridgeBinaryPath: "/usr/local/bin/aiyuterm-hook-bridge"
        )
        XCTAssertTrue(AgentCLIConfigInstaller.uninstallAt(
            configKey: "hooks",
            fullPath: path
        ))
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // The hooks key should be gone entirely because the only
        // entry was ours.
        XCTAssertNil(root?["hooks"])
    }

    func testUninstallPreservesForeignEntries() throws {
        let path = sandboxRoot + "/foreign.json"
        // Seed with a mixed file: one foreign entry + one managed.
        let seed: [String: Any] = [
            "hooks": [
                "Stop": [
                    ["command": "/usr/local/bin/other-tool"],
                    ["command": "/path/aiyuterm-bridge --source cursor"],
                ],
            ],
        ]
        let data = try JSONSerialization.data(
            withJSONObject: seed,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: URL(fileURLWithPath: path))

        _ = AgentCLIConfigInstaller.uninstallAt(configKey: "hooks", fullPath: path)

        let after = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: path))
        ) as? [String: Any]
        let stop = (after?["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 1)
        XCTAssertEqual(stop?.first?["command"] as? String, "/usr/local/bin/other-tool")
    }

    func testIsHooksInstalledFalseWhenPartial() throws {
        let path = sandboxFullPath()
        let seed: [String: Any] = [
            "hooks": [
                "Stop": [
                    ["matcher": "",
                     "hooks": [["type": "command",
                                "command": "/tmp/fake/aiyuterm-bridge-hook.sh",
                                "timeout": 5]]],
                ],
            ],
        ]
        let data = try JSONSerialization.data(
            withJSONObject: seed,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: URL(fileURLWithPath: path))
        XCTAssertFalse(AgentCLIConfigInstaller.isHooksInstalledAt(
            fullPath: path,
            configKey: "hooks",
            events: sandboxEvents
        ))
    }
}
