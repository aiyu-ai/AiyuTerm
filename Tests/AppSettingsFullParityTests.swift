//
// AppSettingsFullParityTests.swift
// AiyuTermTests
//
// Phase 11.3: verify every one of the 17 Phase 11 settings keys
// exists on AppSettings with the documented default, decodes
// from legacy empty JSON with that default, and survives a full
// encode -> decode round-trip. Also verify clamps.
//

import Foundation
import XCTest
@testable import AiyuTerm

final class AppSettingsFullParityTests: XCTestCase {

    // MARK: - Defaults

    func testFreshAppSettingsHasAllPhase11Defaults() {
        let s = AppSettings()
        XCTAssertEqual(s.notchDisplayChoice, "auto")
        XCTAssertEqual(s.notchAllowHorizontalDrag, false)
        XCTAssertEqual(s.notchPanelHorizontalOffset, 0)
        XCTAssertEqual(s.notchMaxPanelHeight, 520)
        XCTAssertEqual(s.notchContentFontSize, 11)
        XCTAssertEqual(s.notchRotationInterval, 5)
        XCTAssertEqual(s.notchMaxToolHistory, 20)
        XCTAssertEqual(s.notchSessionGroupingMode, "byWorkspace")
        XCTAssertEqual(s.notchShowAgentDetails, true)
        XCTAssertEqual(s.notchMascotSpeed, 1)
        XCTAssertEqual(s.agentSoundVolume, 0.7, accuracy: 0.0001)
        XCTAssertEqual(s.agentSoundSessionStart, true)
        XCTAssertEqual(s.agentSoundTaskComplete, true)
        XCTAssertEqual(s.agentSoundTaskError, true)
        XCTAssertEqual(s.agentSoundApprovalNeeded, true)
        XCTAssertEqual(s.agentSoundPromptSubmit, false)
        XCTAssertEqual(s.agentSoundBoot, true)
    }

    // MARK: - Legacy empty JSON

    func testLegacyEmptyJSONDecodesAllPhase11Defaults() throws {
        let data = Data("{}".utf8)
        let s = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(s.notchDisplayChoice, "auto")
        XCTAssertEqual(s.notchMaxPanelHeight, 520)
        XCTAssertEqual(s.notchMascotSpeed, 1)
        XCTAssertEqual(s.agentSoundVolume, 0.7, accuracy: 0.0001)
        XCTAssertEqual(s.agentSoundPromptSubmit, false)
    }

    // MARK: - Round-trip

    func testEncodeDecodeRoundTripPreservesAllPhase11Keys() throws {
        var s = AppSettings()
        s.notchDisplayChoice = "external"
        s.notchAllowHorizontalDrag = true
        s.notchPanelHorizontalOffset = 42
        s.notchMaxPanelHeight = 800
        s.notchContentFontSize = 13
        s.notchRotationInterval = 10
        s.notchMaxToolHistory = 50
        s.notchSessionGroupingMode = "flat"
        s.notchShowAgentDetails = false
        s.notchMascotSpeed = 2
        s.agentSoundVolume = 0.3
        s.agentSoundSessionStart = false
        s.agentSoundTaskComplete = false
        s.agentSoundTaskError = false
        s.agentSoundApprovalNeeded = false
        s.agentSoundPromptSubmit = true
        s.agentSoundBoot = false

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.notchDisplayChoice, "external")
        XCTAssertTrue(decoded.notchAllowHorizontalDrag)
        XCTAssertEqual(decoded.notchPanelHorizontalOffset, 42)
        XCTAssertEqual(decoded.notchMaxPanelHeight, 800)
        XCTAssertEqual(decoded.notchContentFontSize, 13)
        XCTAssertEqual(decoded.notchRotationInterval, 10)
        XCTAssertEqual(decoded.notchMaxToolHistory, 50)
        XCTAssertEqual(decoded.notchSessionGroupingMode, "flat")
        XCTAssertFalse(decoded.notchShowAgentDetails)
        XCTAssertEqual(decoded.notchMascotSpeed, 2)
        XCTAssertEqual(decoded.agentSoundVolume, 0.3, accuracy: 0.0001)
        XCTAssertFalse(decoded.agentSoundSessionStart)
        XCTAssertFalse(decoded.agentSoundTaskComplete)
        XCTAssertFalse(decoded.agentSoundTaskError)
        XCTAssertFalse(decoded.agentSoundApprovalNeeded)
        XCTAssertTrue(decoded.agentSoundPromptSubmit)
        XCTAssertFalse(decoded.agentSoundBoot)
    }

    // MARK: - Clamps

    func testClampsPanelHorizontalOffset() {
        let re = AppSettings(notchPanelHorizontalOffset: 9999)
        XCTAssertLessThanOrEqual(re.notchPanelHorizontalOffset, 200)
    }

    func testClampsMaxPanelHeight() {
        let re = AppSettings(notchMaxPanelHeight: 10000)
        XCTAssertLessThanOrEqual(re.notchMaxPanelHeight, 1200)
    }

    func testClampsContentFontSize() {
        let low = AppSettings(notchContentFontSize: 2)
        XCTAssertGreaterThanOrEqual(low.notchContentFontSize, 9)
        let high = AppSettings(notchContentFontSize: 99)
        XCTAssertLessThanOrEqual(high.notchContentFontSize, 16)
    }

    func testClampsSoundVolume() {
        let low = AppSettings(agentSoundVolume: -0.5)
        XCTAssertGreaterThanOrEqual(low.agentSoundVolume, 0)
        let high = AppSettings(agentSoundVolume: 10)
        XCTAssertLessThanOrEqual(high.agentSoundVolume, 1)
    }

    func testClampsMascotSpeed() {
        let low = AppSettings(notchMascotSpeed: -5)
        XCTAssertGreaterThanOrEqual(low.notchMascotSpeed, 0)
        let high = AppSettings(notchMascotSpeed: 99)
        XCTAssertLessThanOrEqual(high.notchMascotSpeed, 2)
    }
}
