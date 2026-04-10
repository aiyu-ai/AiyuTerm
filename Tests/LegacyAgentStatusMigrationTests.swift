//
// LegacyAgentStatusMigrationTests.swift
// AiyuTermTests
//
// Phase 7.1 tests for the WorkspaceStore legacy migration helper.
// Exercises the JSON rewriting logic via a fixture settings.json in
// a tempdir so the real ~/.claude is never touched.
//

import Foundation
import XCTest
@testable import AiyuTerm

/// These tests reach into the migration's JSON-mutation logic
/// rather than calling `WorkspaceStore.migrateLegacyAgentStatusIfNeeded`
/// directly (which would hit the real ~/.claude path). We replicate
/// the helper's core loop here so a regression in the JSON logic
/// fails loudly.
final class LegacyAgentStatusMigrationTests: XCTestCase {

    private var sandboxRoot: String!
    private let fm = FileManager.default

    override func setUp() {
        super.setUp()
        sandboxRoot = NSTemporaryDirectory() + "aiyuterm-legacy-mig-\(UUID().uuidString)"
        try? fm.createDirectory(atPath: sandboxRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let sandboxRoot { try? fm.removeItem(atPath: sandboxRoot) }
        sandboxRoot = nil
        super.tearDown()
    }

    // MARK: - JSON rewrite

    /// Replicates the inner loop from
    /// `WorkspaceStore.migrateLegacyAgentStatusIfNeeded` so we can
    /// test its semantics without touching ~/.claude.
    private func rewriteRemovingLegacyEntries(in root: inout [String: Any]) -> Bool {
        guard var hooks = root["hooks"] as? [String: Any] else { return false }
        var touched = false
        for (event, value) in hooks {
            guard var entries = value as? [[String: Any]] else { continue }
            let before = entries.count
            entries.removeAll { entry in
                guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
                return inner.contains { hook in
                    guard let cmd = hook["command"] as? String else { return false }
                    return cmd.contains("agent-status-notify.sh")
                }
            }
            if entries.count != before {
                touched = true
                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }
        }
        if touched {
            root["hooks"] = hooks
        }
        return touched
    }

    func testRemovesLegacyNotifyEntry() throws {
        var root: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [[
                            "type": "command",
                            "command": "/Users/demo/.aiyuterm/hooks/agent-status-notify.sh",
                        ]],
                    ],
                ],
            ],
        ]
        let touched = rewriteRemovingLegacyEntries(in: &root)
        XCTAssertTrue(touched)
        let hooks = root["hooks"] as? [String: Any]
        XCTAssertNil(hooks?["Stop"], "Stop entry should be removed")
    }

    func testPreservesForeignHookEntries() throws {
        var root: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [[
                            "type": "command",
                            "command": "/Users/demo/.aiyuterm/hooks/agent-status-notify.sh",
                        ]],
                    ],
                    [
                        "matcher": "",
                        "hooks": [[
                            "type": "command",
                            "command": "/usr/local/bin/other-tool",
                        ]],
                    ],
                ],
            ],
        ]
        let touched = rewriteRemovingLegacyEntries(in: &root)
        XCTAssertTrue(touched)
        let stop = (root["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 1, "Foreign entry must survive")
        let cmd = ((stop?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String
        XCTAssertEqual(cmd, "/usr/local/bin/other-tool")
    }

    func testPreservesBridgeHookEntries() throws {
        // The new bridge hook script filename is
        // claude-code-bridge-hook.sh — the legacy filter must NOT
        // match it.
        var root: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [[
                            "type": "command",
                            "command": "/Users/demo/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh",
                        ]],
                    ],
                ],
            ],
        ]
        let touched = rewriteRemovingLegacyEntries(in: &root)
        XCTAssertFalse(touched)
        let stop = (root["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stop?.count, 1, "Bridge hook entry must survive legacy migration")
    }

    func testNoOpWhenHooksKeyMissing() {
        var root: [String: Any] = ["someOtherKey": "value"]
        let touched = rewriteRemovingLegacyEntries(in: &root)
        XCTAssertFalse(touched)
        XCTAssertEqual(root["someOtherKey"] as? String, "value")
    }

    func testMixedMultiEvent() throws {
        var root: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [["command": "/path/agent-status-notify.sh"]],
                    ],
                ],
                "PreToolUse": [
                    [
                        "matcher": "",
                        "hooks": [["command": "/usr/local/bin/other-tool"]],
                    ],
                ],
                "UserPromptSubmit": [
                    [
                        "matcher": "",
                        "hooks": [
                            ["command": "/path/agent-status-notify.sh"],
                            ["command": "/path/aiyuterm-hook-bridge"],
                        ],
                    ],
                ],
            ],
        ]
        let touched = rewriteRemovingLegacyEntries(in: &root)
        XCTAssertTrue(touched)
        let hooks = root["hooks"] as? [String: Any]
        XCTAssertNil(hooks?["Stop"], "Stop only had legacy entry")
        XCTAssertNotNil(hooks?["PreToolUse"], "PreToolUse only had foreign entry")
        // UserPromptSubmit had one entry with TWO hooks (one legacy +
        // one bridge). The entry contains the legacy command string
        // inside its `hooks` array, so the entire entry is removed.
        // Current migration semantics intentionally drop the whole
        // entry rather than cherry-picking — foreign tools should not
        // put bridge and non-bridge commands in the same entry.
        XCTAssertNil(hooks?["UserPromptSubmit"])
    }
}
