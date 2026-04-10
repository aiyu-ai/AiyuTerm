//
// AgentSoundManagerTableTests.swift
// AiyuTermTests
//
// Phase 11.4: AgentSoundManager must expose a full 5-entry
// table mapping hook event names to system sound names + per-
// event toggle key paths. Read/play flow must honor the master
// gate, per-event toggles, and volume setting.
//

import Foundation
import XCTest
@testable import AiyuTerm

@MainActor
final class AgentSoundManagerTableTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to a known state so tests are independent.
        AgentSoundManager.updateSettings(AppSettings())
    }

    func testAllEntriesCoverFivePlusBoot() {
        XCTAssertEqual(AgentSoundManager.allEntries.count, 5)
        let names = Set(AgentSoundManager.allEntries.map(\.eventName))
        XCTAssertTrue(names.contains("SessionStart"))
        XCTAssertTrue(names.contains("Stop"))
        XCTAssertTrue(names.contains("PostToolUseFailure"))
        XCTAssertTrue(names.contains("PermissionRequest"))
        XCTAssertTrue(names.contains("UserPromptSubmit"))
    }

    func testEachEntryHasNonEmptyFields() {
        for entry in AgentSoundManager.allEntries {
            XCTAssertFalse(entry.eventName.isEmpty)
            XCTAssertFalse(entry.systemSoundName.isEmpty)
            XCTAssertFalse(entry.userFacingLabel.isEmpty)
        }
    }

    func testPlayWhenMasterDisabledIsNoOp() {
        var settings = AppSettings()
        settings.agentSoundEnabled = false
        AgentSoundManager.updateSettings(settings)
        // Should not crash and return fast.
        AgentSoundManager.play("Stop")
    }

    func testPlayWhenEventToggleOffIsNoOp() {
        var settings = AppSettings()
        settings.agentSoundEnabled = true
        settings.agentSoundTaskComplete = false
        AgentSoundManager.updateSettings(settings)
        AgentSoundManager.play("Stop")
    }

    func testPlayBootHonoursBootToggle() {
        var settings = AppSettings()
        settings.agentSoundEnabled = true
        settings.agentSoundBoot = false
        AgentSoundManager.updateSettings(settings)
        AgentSoundManager.playBoot()
    }

    func testUpdateSettingsPropagatesGate() {
        var settings = AppSettings()
        settings.agentSoundEnabled = false
        AgentSoundManager.updateSettings(settings)
        XCTAssertFalse(AgentSoundManager.isEnabled)

        settings.agentSoundEnabled = true
        AgentSoundManager.updateSettings(settings)
        XCTAssertTrue(AgentSoundManager.isEnabled)
    }
}
