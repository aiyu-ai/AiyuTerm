//
//  AgentSoundManagerTests.swift
//  AiyuTermTests
//
//  Phase 10.2 tests for the AgentSoundManager port and the
//  AppSettings.agentSoundEnabled toggle wiring.
//
//  These tests intentionally do not audio-assert — `NSSound.play`
//  is fire-and-forget and there is no portable way to observe the
//  effect. What we can exercise safely is that:
//
//    1. Disabling the subsystem silences every entry point.
//    2. Every known reducer event name returns without throwing
//       or faulting.
//    3. Unknown event names are a no-op.
//    4. AppSettings.agentSoundEnabled defaults to true.
//    5. AppSettings decodes an empty / legacy payload with the
//       toggle defaulting to true.
//

import XCTest
@testable import AiyuTerm

@MainActor
final class AgentSoundManagerTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // Fresh cache and default enabled state so tests can
        // assume a known starting point regardless of ordering.
        AgentSoundManager._resetCacheForTesting()
        AgentSoundManager.isEnabled = true
    }

    override func tearDown() async throws {
        AgentSoundManager._resetCacheForTesting()
        AgentSoundManager.isEnabled = true
        try await super.tearDown()
    }

    // MARK: - play() behaviour

    func testPlayWithEnabledFalseIsNoOp() {
        AgentSoundManager.isEnabled = false
        // Should return cleanly without throwing or loading any
        // NSSound. We cannot observe the audio output directly, so
        // the assertion is simply "no fault, no crash".
        AgentSoundManager.play("taskComplete")
        AgentSoundManager.play("Stop")
        AgentSoundManager.play("UserPromptSubmit")
    }

    func testKnownEventNamesDoNotCrash() {
        AgentSoundManager.isEnabled = true
        let knownEventNames = [
            // Raw reducer event names emitted by AgentSessionSnapshot.
            "SessionStart",
            "Stop",
            "PostToolUseFailure",
            "StopFailure",
            "PermissionRequest",
            "UserPromptSubmit",
            "boot",
            // Semantic aliases documented in the AgentSoundManager
            // event map that callers may use in future phases.
            "sessionStart",
            "taskComplete",
            "taskError",
            "approvalNeeded",
            "promptSubmit",
        ]
        for name in knownEventNames {
            AgentSoundManager.play(name)
        }
    }

    func testUnknownEventNameNoOp() {
        AgentSoundManager.isEnabled = true
        AgentSoundManager.play("definitely-not-a-real-event")
        AgentSoundManager.play("")
        AgentSoundManager.play("UnknownCustomEvent42")
    }

    func testPlayBootRoutesThroughKnownKey() {
        AgentSoundManager.isEnabled = true
        AgentSoundManager.playBoot()
    }

    // MARK: - AppSettings integration

    func testAppSettingsDefaultEnabled() throws {
        // Fresh AppSettings with no overrides — the toggle should
        // default to true so upgrading users keep feedback sounds.
        let settings = AppSettings()
        XCTAssertTrue(settings.agentSoundEnabled)
    }

    func testAppSettingsDecodeLegacyWithoutKey() throws {
        // Minimal JSON that omits agentSoundEnabled entirely, so we
        // exercise the `decodeIfPresent ?? true` branch in the
        // Codable initializer. Every other field is allowed to
        // default via its own decodeIfPresent fallback.
        let legacyJSON = "{}".data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: legacyJSON)
        XCTAssertTrue(settings.agentSoundEnabled)
    }

    func testAppSettingsDecodePreservesExplicitFalse() throws {
        // Positive control: if the persisted payload explicitly
        // stores `false`, the decoder must respect it instead of
        // snapping back to the default.
        let payload = #"{"agentSoundEnabled": false}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: payload)
        XCTAssertFalse(settings.agentSoundEnabled)
    }
}
