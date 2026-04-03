//
//  SleepPreventionSupportTests.swift
//  AiyuTermTests
//
//  Author: wuwenrui
//

import XCTest
@testable import AiyuTerm

final class SleepPreventionSupportTests: XCTestCase {
    func testSleepPreventionDurationsMatchExpectedSeconds() {
        XCTAssertEqual(SleepPreventionDurationOption.oneHour.duration, 3_600)
        XCTAssertEqual(SleepPreventionDurationOption.twelveHours.duration, 43_200)
        XCTAssertEqual(SleepPreventionDurationOption.threeDays.duration, 259_200)
        XCTAssertNil(SleepPreventionDurationOption.forever.duration)
    }

    func testDurationFormattingUsesLargestUnits() {
        let duration: TimeInterval = 95_400

        XCTAssertEqual(SleepPreventionFormat.duration(duration), "1d 2h")
    }

    func testForeverSessionUsesOnStatus() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = SleepPreventionSession(option: .forever, startedAt: now, expiresAt: nil)

        XCTAssertEqual(session.remainingDescription(relativeTo: now), "On")
    }
}
