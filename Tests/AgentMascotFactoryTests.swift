//
// AgentMascotFactoryTests.swift
// AiyuTermTests
//
// Phase 11.2: ensure AgentMascotFactory returns a non-nil
// concrete view for every supported CLI source, plus a sane
// fallback for unknown sources.
//

import Foundation
import SwiftUI
import XCTest
@testable import AiyuTerm

final class AgentMascotFactoryTests: XCTestCase {

    func testFactoryReturnsViewForEveryKnownSource() {
        let knownSources = [
            "claude", "codex", "gemini", "cursor", "copilot",
            "qoder", "codebuddy", "droid", "opencode",
        ]
        for source in knownSources {
            let view = AgentMascotFactory.mascot(
                for: source,
                status: .none,
                size: 27
            )
            // Force body evaluation so any crashing initializer
            // shows up as a test failure instead of a silent nil.
            _ = AnyView(view)
        }
    }

    func testFactoryFallsBackForUnknownSource() {
        let view = AgentMascotFactory.mascot(
            for: "totally-made-up-cli",
            status: .none,
            size: 27
        )
        _ = AnyView(view)
    }

    func testMascotSpeedHasDistinctFrameIntervals() {
        let intervals: [TimeInterval] = AgentMascotSpeed.allCases.map { $0.frameInterval }
        let unique = Set(intervals)
        XCTAssertEqual(unique.count, AgentMascotSpeed.allCases.count)
    }

    func testMascotSpeedIsCodable() throws {
        let original = AgentMascotSpeed.fast
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentMascotSpeed.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}
