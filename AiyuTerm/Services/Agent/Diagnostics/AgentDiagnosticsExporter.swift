//
// AgentDiagnosticsExporter.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/DiagnosticsExporter.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// One-click diagnostics bundle exporter. Collects app metadata,
// live session snapshots, the CLI config files we inject hooks
// into, a socket-status dump, and recent unified logs into a
// `.zip` that the user can attach to a bug report.
//
// Compared to the upstream version this port:
//   • Uses `AgentHookSocketPath` instead of `SocketPath`.
//   • Honours the AiyuTerm Debug state-directory convention.
//   • Takes the live session map as an argument rather than
//     reading it off `AppDelegate.appState`, which decouples the
//     exporter from the workspace store and makes it unit-testable.
//   • Writes to `AiyuTerm-Diagnostics-<ts>.zip`.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum AgentDiagnosticsExporter {

    /// Show an `NSSavePanel` and, on confirm, spin up a background
    /// task that assembles the archive then reveals the resulting
    /// file in Finder. Errors are surfaced via `NSAlert`.
    @MainActor
    static func export(sessions: [String: AgentSessionSnapshot]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue =
            "AiyuTerm-Diagnostics-\(AgentDiagnosticsHelpers.timestamp()).zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let snapshot = sessions
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let zipURL = try buildArchive(
                    sessions: snapshot,
                    saveTo: url
                )
                DispatchQueue.main.async {
                    NSWorkspace.shared.activateFileViewerSelecting([zipURL])
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Archive builder

    /// Build the on-disk archive and return its URL. Extracted
    /// from `export` so callers (and tests) can drive the whole
    /// pipeline without going through NSSavePanel.
    static func buildArchive(
        sessions: [String: AgentSessionSnapshot],
        saveTo destination: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let tmp = fileManager.temporaryDirectory
            .appendingPathComponent(
                "AiyuTerm-Diag-\(UUID().uuidString)",
                isDirectory: true
            )
        let root = tmp.appendingPathComponent(
            "AiyuTerm-Diagnostics-\(AgentDiagnosticsHelpers.timestamp())",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: root, withIntermediateDirectories: true
        )

        // 1. Metadata
        AgentDiagnosticsHelpers.writeJSON(
            AgentDiagnosticsHelpers.metadataDict(),
            to: root.appendingPathComponent("metadata.json"),
            fileManager: fileManager
        )

        // 2. Session snapshots
        let sessionJSON = AgentDiagnosticsHelpers.sessionDicts(from: sessions)
        AgentDiagnosticsHelpers.writeJSON(
            sessionJSON,
            to: root.appendingPathComponent("state/sessions.json"),
            fileManager: fileManager
        )

        // 3. CLI config files
        let home = fileManager.homeDirectoryForCurrentUser.path
        for item in AgentDiagnosticsHelpers.defaultConfigSources(home: home) {
            AgentDiagnosticsHelpers.copyIfExists(
                from: item.source,
                to: root.appendingPathComponent(item.dest),
                fileManager: fileManager
            )
        }

        // 4. Socket status
        let socketPath = AgentHookSocketPath.path
        let socketExists = fileManager.fileExists(atPath: socketPath)
        let socketInfo = "path: \(socketPath)\nexists: \(socketExists)\n"
        try? fileManager.createDirectory(
            at: root.appendingPathComponent("state"),
            withIntermediateDirectories: true
        )
        try? socketInfo.write(
            to: root.appendingPathComponent("state/socket.txt"),
            atomically: true,
            encoding: .utf8
        )

        // 5. Unified logs (last 2 hours, best-effort)
        let logsDir = root.appendingPathComponent("logs")
        try? fileManager.createDirectory(
            at: logsDir, withIntermediateDirectories: true
        )
        let logOutput = AgentDiagnosticsHelpers.runCommand(
            "/usr/bin/log",
            args: [
                "show", "--style", "compact", "--info", "--debug",
                "--last", "2h",
                "--predicate", "subsystem CONTAINS \"aiyuterm\"",
            ]
        )
        try? logOutput.write(
            to: logsDir.appendingPathComponent("unified.log"),
            atomically: true,
            encoding: .utf8
        )

        // 6. sw_vers
        let swVers = AgentDiagnosticsHelpers.runCommand(
            "/usr/bin/sw_vers", args: []
        )
        try? swVers.write(
            to: logsDir.appendingPathComponent("sw_vers.txt"),
            atomically: true,
            encoding: .utf8
        )

        // 7. Recent crash reports
        AgentDiagnosticsHelpers.copyCrashReports(
            to: logsDir.appendingPathComponent(
                "crash-reports", isDirectory: true
            ),
            matching: "aiyuterm",
            fileManager: fileManager
        )

        // Zip the staged directory
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-c", "-k", "--keepParent", root.path, destination.path]
        try proc.run()
        proc.waitUntilExit()
        try? fileManager.removeItem(at: tmp)

        guard proc.terminationStatus == 0 else {
            throw NSError(
                domain: "AgentDiagnosticsExporter",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "ditto failed with exit code \(proc.terminationStatus)"
                ]
            )
        }
        return destination
    }
}

// MARK: - Pure helpers

/// Pure helper namespace used by the exporter. Extracted so
/// tests can cover the interesting string / filtering / mapping
/// logic without touching ditto, NSSavePanel, or NSAlert.
enum AgentDiagnosticsHelpers {

    /// yyyyMMdd-HHmmss — matches the upstream filename scheme.
    static func timestamp(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Build the metadata dictionary. Pulls version info from
    /// `Bundle.main` and a minimal slice of `UserDefaults`.
    static func metadataDict() -> [String: Any] {
        let shortVersion =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown"
        let build =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "unknown"

        #if DEBUG
        let buildConfig = "Debug"
        #else
        let buildConfig = "Release"
        #endif

        return [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "appVersion": shortVersion,
            "buildNumber": build,
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "locale": Locale.current.identifier,
            "timeZone": TimeZone.current.identifier,
            "socketPath": AgentHookSocketPath.path,
            "buildConfiguration": buildConfig,
        ]
    }

    /// Convert the live sessions map into a list of dictionaries
    /// suitable for `JSONSerialization`. Truncates `sessionId` to
    /// 8 chars so the bug report can be shared publicly without
    /// leaking the full identifier.
    static func sessionDicts(
        from sessions: [String: AgentSessionSnapshot]
    ) -> [[String: Any]] {
        sessions
            .sorted { $0.key < $1.key }
            .map { entry -> [String: Any] in
                let s = entry.value
                var dict: [String: Any] = [
                    "id": String(entry.key.prefix(8)),
                    "status": String(describing: s.status),
                    "source": s.source,
                    "lastActivity": ISO8601DateFormatter().string(from: s.lastActivity),
                ]
                if let cwd = s.cwd { dict["cwd"] = cwd }
                if let tool = s.currentTool { dict["currentTool"] = tool }
                if let model = s.model { dict["model"] = model }
                if let term = s.termApp { dict["terminal"] = term }
                if let pid = s.cliPid { dict["pid"] = Int(pid) }
                dict["subagentCount"] = s.subagents.count
                dict["toolHistoryCount"] = s.toolHistory.count
                return dict
            }
    }

    /// The CLI config paths we copy into the bundle. Pure so a
    /// test can verify the full list for regression safety.
    static func defaultConfigSources(home: String) -> [(source: String, dest: String)] {
        #if DEBUG
        let stateDirName = ".aiyuterm-debug"
        #else
        let stateDirName = ".aiyuterm"
        #endif
        return [
            ("\(home)/.claude/settings.json", "configs/claude-settings.json"),
            ("\(home)/.codex/config.toml", "configs/codex-config.toml"),
            ("\(home)/.codex/hooks.json", "configs/codex-hooks.json"),
            ("\(home)/.gemini/settings.json", "configs/gemini-settings.json"),
            ("\(home)/.cursor/hooks.json", "configs/cursor-hooks.json"),
            ("\(home)/.qoder/settings.json", "configs/qoder-settings.json"),
            ("\(home)/.factory/settings.json", "configs/factory-settings.json"),
            ("\(home)/.codebuddy/settings.json", "configs/codebuddy-settings.json"),
            ("\(home)/.config/opencode/plugin/aiyuterm.js", "configs/opencode-plugin.js"),
            ("\(home)/\(stateDirName)/agent-sessions.json", "configs/persisted-sessions.json"),
        ]
    }

    // MARK: File helpers

    static func writeJSON(
        _ obj: Any,
        to url: URL,
        fileManager: FileManager = .default
    ) {
        try? fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONSerialization.data(
            withJSONObject: obj,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func copyIfExists(
        from path: String,
        to url: URL,
        fileManager: FileManager = .default
    ) {
        guard fileManager.fileExists(atPath: path) else { return }
        try? fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.copyItem(atPath: path, toPath: url.path)
    }

    static func runCommand(
        _ executable: String,
        args: [String]
    ) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }

    /// Copy the 5 most recent matching crash reports from
    /// `~/Library/Logs/DiagnosticReports` into `dir`.
    static func copyCrashReports(
        to dir: URL,
        matching keyword: String,
        fileManager: FileManager = .default
    ) {
        let diagDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")
        guard let files = try? fileManager.contentsOfDirectory(
            at: diagDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let filtered = filterAndSortCrashReports(
            urls: files,
            keyword: keyword,
            limit: 5
        )
        guard !filtered.isEmpty else { return }
        try? fileManager.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        for file in filtered {
            try? fileManager.copyItem(
                at: file,
                to: dir.appendingPathComponent(file.lastPathComponent)
            )
        }
    }

    /// Pure filter/sort for crash reports — extracted so tests
    /// can exercise the keyword match and recency limit without
    /// touching the filesystem or relying on actual mtimes.
    static func filterAndSortCrashReports(
        urls: [URL],
        keyword: String,
        limit: Int
    ) -> [URL] {
        let lowered = keyword.lowercased()
        let filtered = urls.filter {
            $0.lastPathComponent.lowercased().contains(lowered)
        }
        let sorted = filtered.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return d1 > d2
        }
        return Array(sorted.prefix(limit))
    }
}
