//
// AgentSessionPersistence.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/SessionPersistence.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Encodes/decodes the subset of `AgentSessionSnapshot` that we
// want to survive an AiyuTerm restart. We persist enough metadata
// to re-populate the notch panel on launch (so the user doesn't
// lose their session list when the app is quit and relaunched)
// without restoring the full tool history / recent messages.
//
// Storage location honours the AiyuTerm state directory
// convention so Debug builds write to `~/.aiyuterm-debug/` and
// don't clobber Release state.
//

import Foundation

// MARK: - Persisted model

/// A Codable snapshot of the fields we persist from
/// `AgentSessionSnapshot`. Everything is optional where possible
/// so older files can still decode as the schema evolves.
struct AgentPersistedSession: Codable, Equatable {
    var sessionId: String
    var cwd: String?
    var source: String
    var model: String?
    var sessionTitle: String?
    var sessionTitleSource: AgentSessionTitleSource?
    var providerSessionId: String?
    var lastUserPrompt: String?
    var lastAssistantMessage: String?
    var termApp: String?
    var itermSessionId: String?
    var ttyPath: String?
    var kittyWindowId: String?
    var tmuxPane: String?
    var tmuxClientTty: String?
    var tmuxEnv: String?
    var termBundleId: String?
    var cliPid: Int32?
    var cliStartTime: Date?
    var startTime: Date
    var lastActivity: Date
}

// MARK: - Persistence service

enum AgentSessionPersistence {
    /// Parent directory name — `.aiyuterm` in Release, `.aiyuterm-debug`
    /// in Debug. Matches the `stateDirectoryName` used by the
    /// hook socket path helper.
    private static var stateDirectoryName: String {
        #if DEBUG
        return ".aiyuterm-debug"
        #else
        return ".aiyuterm"
        #endif
    }

    /// Absolute path to the directory that holds `sessions.json`.
    static var directoryPath: String {
        FileManager.default.homeDirectoryForCurrentUser.path
            + "/" + stateDirectoryName
    }

    /// Absolute path to the persisted sessions file.
    static var filePath: String {
        directoryPath + "/agent-sessions.json"
    }

    // MARK: save / load / clear

    /// Serialize the live session map to disk. Errors are
    /// swallowed — persistence is best-effort and should never
    /// fail a user action.
    static func save(_ sessions: [String: AgentSessionSnapshot]) {
        let persisted = buildPersisted(from: sessions)
        do {
            try FileManager.default.createDirectory(
                atPath: directoryPath,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(persisted)
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
            // Intentionally swallowed — see above.
        }
    }

    /// Read whatever's on disk. Missing file / decode failure
    /// returns an empty array so callers always get a stable type.
    static func load() -> [AgentPersistedSession] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AgentPersistedSession].self, from: data)) ?? []
    }

    /// Delete the persisted sessions file. Safe to call even if
    /// the file doesn't exist.
    static func clear() {
        try? FileManager.default.removeItem(atPath: filePath)
    }

    // MARK: - Pure mapping (extracted for tests)

    /// Convert the live `[sessionId: snapshot]` map to the
    /// persisted array. Pure — no I/O.
    static func buildPersisted(
        from sessions: [String: AgentSessionSnapshot]
    ) -> [AgentPersistedSession] {
        sessions
            .sorted { $0.key < $1.key }
            .map { entry -> AgentPersistedSession in
                let s = entry.value
                return AgentPersistedSession(
                    sessionId: entry.key,
                    cwd: s.cwd,
                    source: s.source,
                    model: s.model,
                    sessionTitle: s.sessionTitle,
                    sessionTitleSource: s.sessionTitleSource,
                    providerSessionId: s.providerSessionId,
                    lastUserPrompt: s.lastUserPrompt,
                    lastAssistantMessage: s.lastAssistantMessage,
                    termApp: s.termApp,
                    itermSessionId: s.itermSessionId,
                    ttyPath: s.ttyPath,
                    kittyWindowId: s.kittyWindowId,
                    tmuxPane: s.tmuxPane,
                    tmuxClientTty: s.tmuxClientTty,
                    tmuxEnv: s.tmuxEnv,
                    termBundleId: s.termBundleId,
                    cliPid: s.cliPid.map { Int32($0) },
                    cliStartTime: s.cliStartTime,
                    startTime: s.startTime,
                    lastActivity: s.lastActivity
                )
            }
    }
}
