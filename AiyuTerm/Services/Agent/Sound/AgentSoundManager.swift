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
// Phase 11.3B — this file grew a table-driven event entry so the
// Settings UI can expose a per-event toggle, a master gate, and a
// single volume slider. The previous dictionary-only mapping lives
// on as `eventSoundNames` so the existing tests and any external
// callers that rely on "sessionStart" / "taskComplete" aliases keep
// working.
//
// Design points:
//
// • Singleton-free `enum` with `static` entry points so callers can
//   play sounds without touching any shared state beyond the
//   `isEnabled` gate, the cached settings snapshot, and the sound
//   cache. The gate + snapshot are stored as
//   `nonisolated(unsafe) static var` because the mapper runs on the
//   main actor while boot-time wiring in WorkspaceStore also touches
//   them — both from the main thread — and we want to keep the call
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

import AppKit
import Foundation

/// One row of the CodeIsland feedback sound table.
///
/// Rows are pure value types so the same entry can be referenced by
/// the settings UI (via the localized `userFacingLabel`), by the
/// reducer event dispatch (via `eventName`), and by the Codable test
/// harness (via the `toggleKeyPath` into AppSettings).
struct AgentSoundEntry: Sendable {
    /// Raw hook event name, matching the string the reducer emits in
    /// `AgentSessionSnapshot.playSound(_:)`.
    let eventName: String
    /// macOS built-in sound name resolved via `NSSound(named:)`.
    let systemSoundName: String
    /// Key path into the per-event gate on AppSettings. Test code can
    /// assert the field exists by reading through this key path.
    let toggleKeyPath: WritableKeyPath<AppSettings, Bool>
    /// Short human-readable label shown in the settings UI.
    let userFacingLabel: String
}

/// Plays feedback sounds for reducer `.playSound` side effects.
///
/// Entry points are `static` because there is no per-instance state:
/// the on/off gate, the cached settings snapshot, and the sound cache
/// are all process-wide.
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

    /// Snapshot of the latest AppSettings the WorkspaceStore has
    /// handed us. `play(_:)` reads per-event toggles and the volume
    /// slider from here. Nil until the first `updateSettings(_:)`
    /// call, in which case we fall back to the static defaults and
    /// `isEnabled`.
    ///
    /// Marked `nonisolated(unsafe)` for the same reason as
    /// `isEnabled` above — it is only written from the main actor,
    /// and we want zero hops on the hot play path.
    nonisolated(unsafe) static var currentSettings: AppSettings?

    /// The full CodeIsland per-event feedback table. Order mirrors
    /// the upstream SoundManager layout so the settings UI can walk
    /// this list to render one toggle row per entry.
    static let allEntries: [AgentSoundEntry] = [
        AgentSoundEntry(
            eventName: "SessionStart",
            systemSoundName: "Glass",
            toggleKeyPath: \.agentSoundSessionStart,
            userFacingLabel: "Session start"
        ),
        AgentSoundEntry(
            eventName: "Stop",
            systemSoundName: "Hero",
            toggleKeyPath: \.agentSoundTaskComplete,
            userFacingLabel: "Task complete"
        ),
        AgentSoundEntry(
            eventName: "PostToolUseFailure",
            systemSoundName: "Basso",
            toggleKeyPath: \.agentSoundTaskError,
            userFacingLabel: "Task error"
        ),
        AgentSoundEntry(
            eventName: "PermissionRequest",
            systemSoundName: "Funk",
            toggleKeyPath: \.agentSoundApprovalNeeded,
            userFacingLabel: "Permission request"
        ),
        AgentSoundEntry(
            eventName: "UserPromptSubmit",
            systemSoundName: "Tink",
            toggleKeyPath: \.agentSoundPromptSubmit,
            userFacingLabel: "Prompt submit"
        ),
    ]

    /// Event name -> macOS system sound name. Preserved from the
    /// pre-P11.3B implementation so legacy callers (and the existing
    /// AgentSoundManagerTests suite) continue to resolve semantic
    /// aliases like "taskComplete" or "sessionStart" to the right
    /// NSSound without going through `allEntries`. Missing keys map
    /// to a no-op.
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

    /// Map from every alias in `eventSoundNames` back to the
    /// authoritative `AgentSoundEntry` (via raw event name). Allows
    /// `play("taskComplete")` to pick up the per-event gate of the
    /// `Stop` entry without forcing callers to know about the alias.
    private static let aliasToEntry: [String: AgentSoundEntry] = {
        var result: [String: AgentSoundEntry] = [:]
        for entry in allEntries {
            result[entry.eventName] = entry
        }
        // Semantic aliases: match on the system sound name because
        // the table is small and the upstream alias set is fixed.
        let aliasToSystemName: [String: String] = [
            "sessionStart": "Glass",
            "taskComplete": "Hero",
            "taskError": "Basso",
            "approvalNeeded": "Funk",
            "promptSubmit": "Tink",
            "StopFailure": "Basso",
        ]
        for (alias, systemName) in aliasToSystemName {
            if let entry = allEntries.first(where: { $0.systemSoundName == systemName }) {
                result[alias] = entry
            }
        }
        return result
    }()

    /// Update the cached settings snapshot and master gate in one
    /// atomic call. WorkspaceStore invokes this on first load and on
    /// every settings save so `play(_:)` sees the latest toggles and
    /// volume without a relaunch.
    static func updateSettings(_ settings: AppSettings) {
        isEnabled = settings.agentSoundEnabled
        currentSettings = settings
    }

    /// Play a sound for the given event name. The event name mirrors
    /// the string the reducer passes to `.playSound(_:)`. Unknown
    /// events and disabled subsystem are both no-ops. Safe to call
    /// from any main-actor context.
    static func play(_ eventName: String) {
        guard isEnabled else { return }

        // Per-event gate lookup — if we know the entry and the user
        // has turned off that specific event, skip entirely.
        if let entry = aliasToEntry[eventName],
           let settings = currentSettings,
           settings[keyPath: entry.toggleKeyPath] == false {
            return
        }

        guard let systemName = eventSoundNames[eventName] else { return }
        guard let sound = resolveSound(named: systemName) else { return }
        if sound.isPlaying { sound.stop() }
        sound.volume = resolvedVolume(for: eventName)
        sound.play()
    }

    /// Play the boot jingle. Wrapped in its own call so the startup
    /// path does not have to know about the "boot" key.
    ///
    /// Respects the dedicated `agentSoundBoot` gate — if the user
    /// turned it off the call is a no-op.
    static func playBoot() {
        guard isEnabled else { return }
        if let settings = currentSettings, settings.agentSoundBoot == false {
            return
        }
        guard let sound = resolveSound(named: "Submarine") else { return }
        if sound.isPlaying { sound.stop() }
        sound.volume = resolvedVolume(for: "boot")
        sound.play()
    }

    /// Clear the in-memory sound cache. Exposed for tests so they
    /// can exercise the cold-load path on demand.
    static func _resetCacheForTesting() {
        soundCache.removeAll()
    }

    // MARK: - Private

    private static func resolvedVolume(for eventName: String) -> Float {
        if let settings = currentSettings {
            return Float(max(0.0, min(settings.agentSoundVolume, 1.0)))
        }
        return defaultVolume
    }

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
