//
// AgentSoundManager.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/SoundManager.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Plays a short feedback sound when the AgentHookEventMapper relays
// a `.playSound(eventName)` side effect from the CodeIsland reducer
// (see AgentSessionSnapshot.swift). The upstream project bundles
// 8-bit WAV files under its SPM resource bundle; AiyuTerm
// deliberately ships no custom audio assets and instead falls back
// to macOS built-in system sounds via `NSSound(named:)`.
//
// Design points:
//
// • Singleton-free `enum` with `static` entry points so callers can
//   play sounds without touching any shared state beyond the
//   `isEnabled` gate and the sound cache. The gate is stored as a
//   `nonisolated(unsafe) static var` because the mapper runs on the
//   main actor while boot-time wiring in WorkspaceStore also touches
//   it — both from the main thread — and we want to keep the call
//   sites free of actor hops.
//
// • `NSSound` instances are cached per system sound name so replaying
//   the same event does not re-parse the audio file every time. The
//   cache is MainActor-isolated: all writes happen on the main actor
//   inside `play(_:)`, so no locking is required.
//
// • Unknown event names are a no-op rather than falling back to
//   `NSSound.beep()` — the goal is a calm sidebar, not a loud one.
//
// The volume is currently a compile-time constant (0.7). Wiring the
// volume to settings is deferred to a future phase when we ship a
// full audio preferences pane.
//

import AppKit
import Foundation

/// Plays feedback sounds for reducer `.playSound` side effects.
///
/// Entry points are `static` because there is no per-instance state:
/// the on/off gate and the sound cache are both process-wide.
@MainActor
enum AgentSoundManager {
    /// Default playback volume when the sound subsystem is enabled.
    /// Matches the upstream CodeIsland default (70%).
    static let defaultVolume: Float = 0.7

    /// Gate the entire subsystem. When `false`, `play(_:)` returns
    /// immediately without loading or playing anything. Wired to
    /// `AppSettings.agentSoundEnabled` at startup by WorkspaceStore
    /// and on every subsequent settings update.
    ///
    /// Marked `nonisolated(unsafe)` because it is only touched from
    /// the main thread (WorkspaceStore.loadIfNeeded +
    /// updateAppSettings, and AgentHookEventMapper.handleEvent),
    /// and we do not want Swift 6's strict concurrency checker to
    /// force actor hops for a single Bool read.
    nonisolated(unsafe) static var isEnabled: Bool = true

    /// Event name -> macOS system sound name.
    ///
    /// The keys cover every value that the reducer currently emits
    /// via `.playSound(eventName)` in AgentSessionSnapshot.swift:578,
    /// plus the aliases used in the task spec ("taskComplete",
    /// "sessionStart", etc.) so future callers can use either form.
    /// Missing keys map to no-op.
    static let eventSoundNames: [String: String] = [
        // Raw hook event names (what the reducer actually emits).
        "SessionStart": "Glass",
        "Stop": "Hero",
        "PostToolUseFailure": "Basso",
        "StopFailure": "Basso",
        "PermissionRequest": "Funk",
        "UserPromptSubmit": "Tink",
        "boot": "Submarine",

        // Semantic aliases referenced by the task spec / UI layer.
        "sessionStart": "Glass",
        "taskComplete": "Hero",
        "taskError": "Basso",
        "approvalNeeded": "Funk",
        "promptSubmit": "Tink",
    ]

    /// Cached NSSound instances keyed by system sound name so that
    /// repeated events do not re-parse the WAV on every play. All
    /// writes happen on the main actor.
    private static var soundCache: [String: NSSound] = [:]

    /// Play a sound for the given event name. The event name mirrors
    /// the string the reducer passes to `.playSound(_:)`. Unknown
    /// events and disabled subsystem are both no-ops. Safe to call
    /// from any main-actor context.
    static func play(_ eventName: String) {
        guard isEnabled else { return }
        guard let systemName = eventSoundNames[eventName] else { return }
        guard let sound = resolveSound(named: systemName) else { return }
        if sound.isPlaying { sound.stop() }
        sound.volume = defaultVolume
        sound.play()
    }

    /// Play the boot jingle. Wrapped in its own call so the startup
    /// path does not have to know about the "boot" key.
    static func playBoot() {
        play("boot")
    }

    /// Clear the in-memory sound cache. Exposed for tests so they
    /// can exercise the cold-load path on demand.
    static func _resetCacheForTesting() {
        soundCache.removeAll()
    }

    // MARK: - Private

    private static func resolveSound(named name: String) -> NSSound? {
        if let cached = soundCache[name] {
            return cached
        }
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            return nil
        }
        // NSSound(named:) returns a shared instance; take a copy so
        // simultaneous plays on different threads/events do not
        // race on its `isPlaying` state.
        let copy = sound.copy() as? NSSound ?? sound
        soundCache[name] = copy
        return copy
    }
}
