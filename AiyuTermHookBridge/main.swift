// ============================================================
// aiyuterm-hook-bridge — Native agent hook event forwarder
// ============================================================
// Replaces shell hook + nc with a 86KB native binary that:
//   • Parses JSON properly (no regex)
//   • Enriches events with deep terminal env (tmux, Kitty, iTerm,
//     Ghostty) so the AgentHookServer can correlate sessions back
//     to worktrees.
//   • Talks Unix-domain socket with a short 3s timeout for non-
//     blocking events and up to 86400s for blocking permission
//     requests.
//   • Drops events without session_id instead of poisoning state.
//   • Honors AIYUTERM_HOOK_SKIP (emergency bypass) and
//     AIYUTERM_HOOK_DEBUG (per-invocation trace log).
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandBridge/main.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// NOTE on dependencies: this target is a standalone command-line tool
// and intentionally does NOT import the AiyuTerm app module. The 8-line
// socket-path resolver below is a duplicate of
// `AiyuTerm/Services/Agent/HookProtocol/AgentHookSocketPath.swift` so
// that both sides agree on the path without either depending on the
// other. If you change the default path or the env override name,
// update BOTH files.
// ============================================================

import Darwin
import Foundation

// MARK: - Signal handlers

// Never let a broken pipe kill the bridge — just fail the write silently.
signal(SIGPIPE, SIG_IGN)

// Hard deadline: if anything hangs beyond the arming window, bail out
// cleanly. Non-blocking events get 8s; blocking events disarm the
// alarm before waiting for user interaction.
signal(SIGALRM) { _ in
    _exit(0)
}

// MARK: - Socket path resolver (mirrors AgentHookSocketPath.swift)

enum HookBridgeSocketPath {
    static let environmentOverrideKey = "AIYUTERM_HOOK_SOCKET"
    static let maximumSocketPathLength = 100

    static var path: String {
        if let override = ProcessInfo.processInfo.environment[environmentOverrideKey],
           !override.isEmpty
        {
            return override
        }
        let preferred = "\(NSHomeDirectory())/.aiyuterm/hook.sock"
        if preferred.utf8.count <= maximumSocketPathLength {
            return preferred
        }
        return "/tmp/aiyuterm-hook-\(getuid()).sock"
    }
}

// MARK: - Helper functions

func detectTTY() -> String {
    let fd = open("/dev/tty", O_RDONLY | O_NOCTTY)
    if fd >= 0 {
        if let name = ttyname(fd) {
            close(fd)
            return String(cString: name)
        }
        close(fd)
    }
    return ""
}

func findBinary(_ name: String) -> String? {
    // GUI-launched apps strip PATH, so probe the usual absolute
    // locations instead of relying on `which`.
    let searchPaths = [
        "/opt/homebrew/bin/\(name)",
        "/usr/local/bin/\(name)",
        "/usr/bin/\(name)",
    ]
    return searchPaths.first { access($0, X_OK) == 0 }
}

func runCommand(_ path: String, args: [String]) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: path)
    proc.arguments = args
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let str = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (str?.isEmpty == false) ? str : nil
    } catch {
        return nil
    }
}

func debugLog(_ message: String) {
    guard ProcessInfo.processInfo.environment["AIYUTERM_HOOK_DEBUG"] != nil else { return }
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(message)\n"
    let path = "/tmp/aiyuterm-hook-bridge.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: Data(line.utf8))
    }
}

func nonEmptyString(_ value: Any?) -> String? {
    guard let raw = value as? String else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func connectSocket(_ path: String) -> Int32? {
    let sock = socket(AF_UNIX, SOCK_STREAM, 0)
    guard sock >= 0 else { return nil }

    // Suppress per-write SIGPIPE on this socket (belt-and-suspenders
    // with the global SIG_IGN above).
    var on: Int32 = 1
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
        path.withCString { _ = strcpy(ptr, $0) }
    }

    // Non-blocking connect with 3s timeout — prevents hanging if the
    // listener is stuck on something else.
    let origFlags = fcntl(sock, F_GETFL)
    _ = fcntl(sock, F_SETFL, origFlags | O_NONBLOCK)

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(sock, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    if result != 0 && errno != EINPROGRESS {
        close(sock)
        return nil
    }

    if result != 0 {
        var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
        let ready = poll(&pfd, 1, 3000) // 3 seconds
        if ready <= 0 {
            close(sock)
            return nil
        }
        var sockErr: Int32 = 0
        var errLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(sock, SOL_SOCKET, SO_ERROR, &sockErr, &errLen)
        if sockErr != 0 {
            close(sock)
            return nil
        }
    }

    // Restore blocking mode for send/recv.
    _ = fcntl(sock, F_SETFL, origFlags)
    return sock
}

func sendAll(_ sock: Int32, data: Data) {
    data.withUnsafeBytes { buf in
        guard let base = buf.baseAddress else { return }
        var sent = 0
        while sent < buf.count {
            let n = send(sock, base + sent, buf.count - sent, 0)
            if n < 0 {
                if errno == EINTR { continue }
                break
            }
            if n == 0 { break }
            sent += n
        }
    }
}

func recvAll(_ sock: Int32) -> Data {
    var response = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = recv(sock, &buf, buf.count, 0)
        if n < 0 {
            if errno == EINTR { continue }
            break
        }
        if n == 0 { break }
        response.append(contentsOf: buf[..<n])
    }
    return response
}

// MARK: - Main

let socketPath = HookBridgeSocketPath.path
let env = ProcessInfo.processInfo.environment
let args = CommandLine.arguments

// Parse --source flag (e.g. --source codex)
var sourceTag: String? = nil
if let idx = args.firstIndex(of: "--source"), idx + 1 < args.count {
    sourceTag = args[idx + 1]
}

// Parse --event flag (e.g. --event sessionStart) for CLIs that lack
// hook_event_name in stdin (GitHub Copilot CLI).
var eventTag: String? = nil
if let idx = args.firstIndex(of: "--event"), idx + 1 < args.count {
    eventTag = args[idx + 1]
}

// Emergency bypass.
guard env["AIYUTERM_HOOK_SKIP"] == nil else { exit(0) }

// Quick exit: socket doesn't exist or isn't a socket (AiyuTerm not running).
var statBuf = stat()
guard stat(socketPath, &statBuf) == 0,
      (statBuf.st_mode & S_IFMT) == S_IFSOCK
else {
    exit(0)
}

// Arm a short alarm before reading stdin so a hung parent cannot
// freeze the bridge forever.
alarm(5)
let input = FileHandle.standardInput.readDataToEndOfFile()
alarm(0) // stdin done, cancel preliminary alarm

guard !input.isEmpty,
      var json = try? JSONSerialization.jsonObject(with: input) as? [String: Any]
else {
    exit(0)
}

// Copilot CLI adaptation: its stdin JSON lacks session_id and
// hook_event_name; normalize its camelCase payload.
if sourceTag == "copilot" {
    if json["hook_event_name"] == nil, let event = eventTag {
        json["hook_event_name"] = event
    }
    if json["session_id"] == nil, let sessionId = nonEmptyString(json["sessionId"]) {
        json["session_id"] = sessionId
    }
    if let toolName = json["toolName"] as? String {
        json["tool_name"] = toolName
    }
    if let toolArgsStr = json["toolArgs"] as? String,
       let argsData = toolArgsStr.data(using: .utf8),
       let argsObj = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
    {
        json["tool_input"] = argsObj
    }
}

// Validate: must have non-empty session_id.
guard let sessionId = json["session_id"] as? String, !sessionId.isEmpty else {
    debugLog("no session_id, dropping")
    exit(0)
}

// Event type detection — drives alarm arming.
let eventName = json["hook_event_name"] as? String ?? ""
let isPermission = eventName == "PermissionRequest"
let isQuestion = (eventName == "Notification" || eventName == "afterAgentThought")
    && json["question"] as? String != nil
let isBlocking = isPermission || isQuestion

debugLog("event=\(eventName) session=\(sessionId) permission=\(isPermission) question=\(isQuestion)")

// Arm deadline covering env collection + connect + send. Blocking
// events disarm this just before the long recvAll wait.
alarm(8)

// --- Deep terminal env collection (only add fields if present) ---

if let termApp = env["TERM_PROGRAM"], !termApp.isEmpty {
    json["_term_app"] = termApp
}
if let termBundle = env["__CFBundleIdentifier"], !termBundle.isEmpty {
    json["_term_bundle"] = termBundle
}

// iTerm2 session — extract GUID after "w0t0p0:" prefix.
if let iterm = env["ITERM_SESSION_ID"], !iterm.isEmpty {
    if let colonIdx = iterm.firstIndex(of: ":") {
        json["_iterm_session"] = String(iterm[iterm.index(after: colonIdx)...])
    } else {
        json["_iterm_session"] = iterm
    }
}

// Kitty window.
if let kitty = env["KITTY_WINDOW_ID"], !kitty.isEmpty {
    json["_kitty_window"] = kitty
}

// tmux deep detection.
if let tmux = env["TMUX"], !tmux.isEmpty {
    json["_tmux"] = tmux
    if let pane = env["TMUX_PANE"], !pane.isEmpty {
        json["_tmux_pane"] = pane
        // Resolve client TTY via tmux — the PATH hooks see may not
        // include homebrew, so use an absolute path.
        if let tmuxBin = findBinary("tmux"),
           let clientTTY = runCommand(
               tmuxBin,
               args: ["display-message", "-p", "-t", pane, "-F", "#{client_tty}"]
           )
        {
            json["_tmux_client_tty"] = clientTTY
        }
    }
}

// TTY path.
let tty = detectTTY()
if !tty.isEmpty {
    json["_tty"] = tty
}

// Source tag from --source flag.
if let source = sourceTag {
    json["_source"] = source
}

// Parent PID — the CLI process that spawned this hook.
json["_ppid"] = getppid()

// --- Serialize enriched payload ---

guard let enriched = try? JSONSerialization.data(withJSONObject: json) else { exit(1) }

// --- Connect to Unix socket ---

guard let sock = connectSocket(socketPath) else {
    debugLog("socket connect failed")
    exit(0)
}

// Socket timeouts. Blocking events get a day (effectively unlimited);
// non-blocking events get 3s to leave room for main-thread scheduling.
var sendTv = timeval(tv_sec: isBlocking ? 86400 : 3, tv_usec: 0)
setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &sendTv, socklen_t(MemoryLayout<timeval>.size))
var recvTv = timeval(tv_sec: isBlocking ? 86400 : 3, tv_usec: 0)
setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &recvTv, socklen_t(MemoryLayout<timeval>.size))

// Send enriched payload.
sendAll(sock, data: enriched)

// Half-close the write side → server sees EOF.
shutdown(sock, SHUT_WR)

// Blocking events wait for user interaction — disarm the deadline
// now that we've successfully sent.
if isBlocking {
    alarm(0)
}

// Wait for server response. Without this, close() races ahead of
// NWListener's main-thread handler and the event is lost.
let response = recvAll(sock)

// Blocking events: forward response to stdout for Claude Code to read.
if isBlocking && !response.isEmpty {
    FileHandle.standardOutput.write(response)
}

close(sock)
exit(0)
