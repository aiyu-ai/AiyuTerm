//
// AgentNotchScreenDetectorTests.swift
// AiyuTermTests
//
// Phase 8.1 tests for the pure geometry logic inside
// AgentNotchScreenDetector. The tests that touch real NSScreen /
// NSWorkspace live elsewhere as manual smoke tests; these unit
// tests exercise the autoPreferredIndex picker + the helper math.
//

import AppKit
import XCTest
@testable import AiyuTerm

final class AgentNotchScreenDetectorTests: XCTestCase {

    // MARK: - autoPreferredIndex

    func testReturnsNilForEmptyCandidates() {
        XCTAssertNil(AgentNotchScreenDetector.autoPreferredIndex(
            candidates: [],
            activeWindowBounds: nil
        ))
    }

    func testPicksCandidateContainingActiveWindowCenter() {
        let candidates: [AgentNotchScreenDetector.Candidate] = [
            .init(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: false),
            .init(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: true),
        ]
        // Center at (1500, 500) — inside the second candidate.
        let windowBounds = CGRect(x: 1400, y: 400, width: 200, height: 200)
        XCTAssertEqual(
            AgentNotchScreenDetector.autoPreferredIndex(
                candidates: candidates,
                activeWindowBounds: windowBounds
            ),
            1
        )
    }

    func testFallsBackToLargestOverlapWhenCenterMisses() {
        let candidates: [AgentNotchScreenDetector.Candidate] = [
            .init(frame: CGRect(x: 0, y: 0, width: 500, height: 500),
                  hasNotch: false, isMain: false),
            .init(frame: CGRect(x: 500, y: 0, width: 500, height: 500),
                  hasNotch: false, isMain: true),
        ]
        // Window straddles both screens with 80% of its area on the
        // second one.
        let windowBounds = CGRect(x: 400, y: 100, width: 500, height: 400)
        XCTAssertEqual(
            AgentNotchScreenDetector.autoPreferredIndex(
                candidates: candidates,
                activeWindowBounds: windowBounds
            ),
            1
        )
    }

    func testFallsBackToNotchScreenWhenNoActiveWindow() {
        let candidates: [AgentNotchScreenDetector.Candidate] = [
            .init(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: false),
            .init(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                  hasNotch: true,  isMain: true),
        ]
        XCTAssertEqual(
            AgentNotchScreenDetector.autoPreferredIndex(
                candidates: candidates,
                activeWindowBounds: nil
            ),
            1
        )
    }

    func testFallsBackToMainWhenNoNotchAvailable() {
        let candidates: [AgentNotchScreenDetector.Candidate] = [
            .init(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: false),
            .init(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: true),
        ]
        XCTAssertEqual(
            AgentNotchScreenDetector.autoPreferredIndex(
                candidates: candidates,
                activeWindowBounds: nil
            ),
            1
        )
    }

    func testFallsBackToFirstCandidateWhenNothingMatches() {
        let candidates: [AgentNotchScreenDetector.Candidate] = [
            .init(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: false),
            .init(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                  hasNotch: false, isMain: false),
        ]
        XCTAssertEqual(
            AgentNotchScreenDetector.autoPreferredIndex(
                candidates: candidates,
                activeWindowBounds: nil
            ),
            0
        )
    }

    // MARK: - fakeNotchWidth clamp

    func testFakeNotchWidthClampsSmallScreens() {
        // Width * 0.14 = 56 — clamped to the 160 minimum.
        XCTAssertEqual(AgentNotchScreenDetector.fakeNotchWidth(forFrameWidth: 400), 160)
    }

    func testFakeNotchWidthScalesMediumScreens() {
        // 1440 * 0.14 = 201.6 — sits inside the clamp range.
        XCTAssertEqual(
            AgentNotchScreenDetector.fakeNotchWidth(forFrameWidth: 1440),
            201.6,
            accuracy: 0.01
        )
    }

    func testFakeNotchWidthClampsLargeScreens() {
        // 5120 * 0.14 = 716.8 — clamped to the 240 maximum.
        XCTAssertEqual(AgentNotchScreenDetector.fakeNotchWidth(forFrameWidth: 5120), 240)
    }

    // MARK: - signature

    func testSignatureIsStableForIdenticalFrames() {
        let a = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let b = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(
            AgentNotchScreenDetector.signature(forFrame: a),
            AgentNotchScreenDetector.signature(forFrame: b)
        )
    }

    func testSignatureChangesWithFrame() {
        let a = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let b = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        XCTAssertNotEqual(
            AgentNotchScreenDetector.signature(forFrame: a),
            AgentNotchScreenDetector.signature(forFrame: b)
        )
    }

    func testSignatureEncodesAllFourAxes() {
        let sig = AgentNotchScreenDetector.signature(
            forFrame: CGRect(x: 100, y: 200, width: 300, height: 400)
        )
        XCTAssertEqual(sig, "100:200:300:400")
    }
}
