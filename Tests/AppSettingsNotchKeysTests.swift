//
//  AppSettingsNotchKeysTests.swift
//  AiyuTermTests
//
//  Author: wuwenrui
//
//  Phase 10.4 — verify the 8 notch-panel configuration keys ported from
//  CodeIsland default to the expected values, decode safely from legacy
//  (pre-P10.4) settings JSON, decode explicitly-set values, and survive
//  an encode -> decode round trip.
//

import XCTest
@testable import AiyuTerm

final class AppSettingsNotchKeysTests: XCTestCase {
    func testDefaultsMatchP10SpecForNewNotchKeys() {
        let settings = AppSettings()

        XCTAssertEqual(settings.notchHideInFullscreen, true)
        XCTAssertEqual(settings.notchHideWhenNoSession, false)
        XCTAssertEqual(settings.notchSmartSuppress, true)
        XCTAssertEqual(settings.notchCollapseOnMouseLeave, true)
        XCTAssertEqual(settings.notchSessionTimeoutMinutes, 30)
        XCTAssertEqual(settings.notchMaxVisibleSessions, 8)
        XCTAssertEqual(settings.notchAiMessageLines, 3)
        XCTAssertEqual(settings.notchShowToolStatus, true)
    }

    func testLegacyEmptyJSONDecodesWithDefaults() throws {
        let legacyJSON = Data("{}".utf8)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacyJSON)

        XCTAssertEqual(decoded.notchHideInFullscreen, true)
        XCTAssertEqual(decoded.notchHideWhenNoSession, false)
        XCTAssertEqual(decoded.notchSmartSuppress, true)
        XCTAssertEqual(decoded.notchCollapseOnMouseLeave, true)
        XCTAssertEqual(decoded.notchSessionTimeoutMinutes, 30)
        XCTAssertEqual(decoded.notchMaxVisibleSessions, 8)
        XCTAssertEqual(decoded.notchAiMessageLines, 3)
        XCTAssertEqual(decoded.notchShowToolStatus, true)
    }

    func testExplicitNotchKeyValuesAreDecodedFromJSON() throws {
        let payload: [String: Any] = [
            "notchHideInFullscreen": false,
            "notchHideWhenNoSession": true,
            "notchSmartSuppress": false,
            "notchCollapseOnMouseLeave": false,
            "notchSessionTimeoutMinutes": 5,
            "notchMaxVisibleSessions": 12,
            "notchAiMessageLines": 6,
            "notchShowToolStatus": false
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(decoded.notchHideInFullscreen, false)
        XCTAssertEqual(decoded.notchHideWhenNoSession, true)
        XCTAssertEqual(decoded.notchSmartSuppress, false)
        XCTAssertEqual(decoded.notchCollapseOnMouseLeave, false)
        XCTAssertEqual(decoded.notchSessionTimeoutMinutes, 5)
        XCTAssertEqual(decoded.notchMaxVisibleSessions, 12)
        XCTAssertEqual(decoded.notchAiMessageLines, 6)
        XCTAssertEqual(decoded.notchShowToolStatus, false)
    }

    func testEncodeDecodeRoundTripPreservesNotchKeys() throws {
        var original = AppSettings()
        original.notchHideInFullscreen = false
        original.notchHideWhenNoSession = true
        original.notchSmartSuppress = false
        original.notchCollapseOnMouseLeave = false
        original.notchSessionTimeoutMinutes = 15
        original.notchMaxVisibleSessions = 20
        original.notchAiMessageLines = 4
        original.notchShowToolStatus = false

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.notchHideInFullscreen, false)
        XCTAssertEqual(decoded.notchHideWhenNoSession, true)
        XCTAssertEqual(decoded.notchSmartSuppress, false)
        XCTAssertEqual(decoded.notchCollapseOnMouseLeave, false)
        XCTAssertEqual(decoded.notchSessionTimeoutMinutes, 15)
        XCTAssertEqual(decoded.notchMaxVisibleSessions, 20)
        XCTAssertEqual(decoded.notchAiMessageLines, 4)
        XCTAssertEqual(decoded.notchShowToolStatus, false)
    }
}
