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
        XCTAssertEqual(
            QuickCommandCatalog.defaultCommands.first(where: { $0.id == "codex-resume" })?.command,
            "codex resume"
        )
        XCTAssertEqual(
            LineyKeyboardShortcuts.effectiveShortcut(for: .closeWindow, in: settings),
            StoredShortcut(key: "w", command: true, shift: false, option: false, control: true)
        )
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

    func testShortcutAssignmentDisablesConflictingAction() {
        var settings = AppSettings()
        let shortcut = StoredShortcut(key: "p", command: true, shift: false, option: false, control: false)

        LineyKeyboardShortcuts.setShortcut(shortcut, for: .openDiff, in: &settings)

        XCTAssertEqual(LineyKeyboardShortcuts.effectiveShortcut(for: .openDiff, in: settings), shortcut)
        XCTAssertNil(LineyKeyboardShortcuts.effectiveShortcut(for: .toggleCommandPalette, in: settings))
        XCTAssertEqual(LineyKeyboardShortcuts.state(for: .toggleCommandPalette, in: settings), .disabled)
    }

    func testShortcutResetRestoresDefaultBinding() {
        var settings = AppSettings()

        LineyKeyboardShortcuts.disableShortcut(for: .closePane, in: &settings)
        XCTAssertNil(LineyKeyboardShortcuts.effectiveShortcut(for: .closePane, in: settings))

        LineyKeyboardShortcuts.resetShortcut(for: .closePane, in: &settings)

        XCTAssertEqual(
            LineyKeyboardShortcuts.effectiveShortcut(for: .closePane, in: settings),
            StoredShortcut(key: "w", command: true, shift: true, option: false, control: false)
        )
    }

    func testNumberedTabShortcutNormalizesToDigitTemplate() {
        var settings = AppSettings()
        let shortcut = StoredShortcut(key: "7", command: true, shift: false, option: false, control: false)

        LineyKeyboardShortcuts.setShortcut(shortcut, for: .selectTabByNumber, in: &settings)

        XCTAssertEqual(
            LineyKeyboardShortcuts.effectiveShortcut(for: .selectTabByNumber, in: settings),
            StoredShortcut(key: "1", command: true, shift: false, option: false, control: false)
        )
        XCTAssertEqual(
            LineyKeyboardShortcuts.displayString(for: .selectTabByNumber, in: settings),
            "⌘1…9"
        )
    }
}
