//
// AgentHookSocketPath.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandCore/SocketPath.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Provides the Unix domain socket path used by the AiyuTerm agent hook
// bridge. Rewritten from CodeIsland's /tmp/codeisland-<uid>.sock to live
// under ~/.aiyuterm/hook.sock so it co-locates with the rest of AiyuTerm's
// on-disk state.
//

import Darwin
import Foundation

enum AgentHookSocketPath {
    /// Environment variable name used to override the default socket path.
    /// Mostly useful for tests and local development.
    static let environmentOverrideKey = "AIYUTERM_HOOK_SOCKET"

    /// sun_path on macOS is limited to 104 bytes (including trailing null).
    /// We keep a safety margin of 100 to leave room for the null terminator.
    static let maximumSocketPathLength = 100

    /// State directory name. Debug builds use `.aiyuterm-debug` to
    /// stay isolated from a concurrently-running release build. The
    /// debug suffix must match `aiyuTermStateDirectoryName()` in
    /// `AppSettingsPersistence.swift` so the socket path and the
    /// on-disk hook scripts stay in lockstep.
    static var stateDirectoryName: String {
        #if DEBUG
        return ".aiyuterm-debug"
        #else
        return ".aiyuterm"
        #endif
    }

    /// Resolved socket path:
    /// 1. Environment override if set and non-empty.
    /// 2. `~/{stateDirectoryName}/hook.sock` (default).
    /// 3. `/tmp/aiyuterm-hook-<uid>.sock` fallback if the default path is
    ///    too long to fit into `sockaddr_un.sun_path`.
    static var path: String {
        if let override = ProcessInfo.processInfo.environment[environmentOverrideKey],
           !override.isEmpty
        {
            return override
        }

        let preferred = defaultHomePath()
        if preferred.utf8.count <= maximumSocketPathLength {
            return preferred
        }
        return tmpFallbackPath()
    }

    /// Returns true if the current resolved path fits into `sockaddr_un`.
    static var resolvedPathFitsSunPath: Bool {
        path.utf8.count <= maximumSocketPathLength
    }

    // MARK: - Internals

    private static func defaultHomePath() -> String {
        let home = NSHomeDirectory()
        return "\(home)/\(stateDirectoryName)/hook.sock"
    }

    private static func tmpFallbackPath() -> String {
        #if DEBUG
        return "/tmp/aiyuterm-hook-debug-\(getuid()).sock"
        #else
        return "/tmp/aiyuterm-hook-\(getuid()).sock"
        #endif
    }
}
