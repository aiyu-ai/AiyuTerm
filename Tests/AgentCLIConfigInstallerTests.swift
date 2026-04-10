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

    func testRemoveManagedEntriesKeepsEntriesWithoutOurMarker() {
        // The identifier marker is 'aiyuterm-bridge'. An entry whose
        // command only contains 'aiyuterm' (e.g. the legacy
        // '~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh' path)
        // does NOT match AgentHookIdentifier.isOurs, so both entries
        // should survive removeManagedHookEntries.
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
        // Both entries stay: neither matches the `aiyuterm-bridge` marker.
        XCTAssertEqual(stopEntries?.count, 2,
                       "Neither command contains the 'aiyuterm-bridge' marker")
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
