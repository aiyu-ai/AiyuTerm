//
//  QuickCommandSupportTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class QuickCommandSupportTests: XCTestCase {
    func testLegacySettingsDecodeDefaultsQuickCommands() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(settings.quickCommandPresets, QuickCommandCatalog.defaultCommands)
        XCTAssertTrue(settings.quickCommandRecentIDs.isEmpty)
    }

    func testQuickCommandNormalizationTrimsAndDropsDuplicates() {
        let commands = [
            QuickCommandPreset(
                id: "dup",
                title: "  ",
                command: "  ls -la  ",
                category: .linux
            ),
            QuickCommandPreset(
                id: "dup",
                title: "Other",
                command: "pwd",
                category: .linux
            ),
            QuickCommandPreset(
                id: "empty",
                title: "Empty",
                command: "   ",
                category: .codex
            ),
        ]

        let normalized = QuickCommandCatalog.normalizedCommands(commands)

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized[0].id, "dup")
        XCTAssertEqual(normalized[0].title, "ls -la")
        XCTAssertEqual(normalized[0].command, "ls -la")
    }

    func testRecentQuickCommandsArePrunedAndDeduplicated() {
        let commands = [
            QuickCommandPreset(id: "a", title: "A", command: "a", category: .codex),
            QuickCommandPreset(id: "b", title: "B", command: "b", category: .cloud),
        ]

        let normalized = QuickCommandCatalog.normalizedRecentCommandIDs(
            ["missing", "a", "a", "b", "c"],
            availableCommands: commands
        )

        XCTAssertEqual(normalized, ["a", "b"])
    }
}
