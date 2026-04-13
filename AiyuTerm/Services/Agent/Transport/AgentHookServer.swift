//
// AgentHookServer.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIsland/HookServer.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Unix domain socket server that accepts hook events from the
// `aiyuterm-hook-bridge` helper binary (Phase 2) and dispatches them
// to an `AgentHookReceiver` (typically `WorkspaceStore`).
//
// Design points carried over from CodeIsland:
//   • NWListener with NWEndpoint.unix(path:) as transport.
//   • Single request / single response per connection. The bridge
//     half-closes (SHUT_WR) after sending, which produces EOF on our
//     side — that is the normal termination signal.
//   • The peer-disconnect monitor hooks `stateUpdateHandler` instead
//     of `receive(min:1, max:1)` so that EOF from a normal half-close
//     does NOT look like a peer disconnect. See the HookServer.swift
//     comment at line 172-180 for the history of this trap.
//   • `sendResponse` flips `ConnectionContext.responded = true`
//     BEFORE `connection.cancel()` so that our own teardown does not
//     masquerade as a peer disconnect.
//

import Foundation
import Network
import os.log

@MainActor
final class AgentHookServer {
    // MARK: - Public state

    weak var receiver: AgentHookReceiver?

    /// The resolved socket path in use. Mirrors `AgentHookSocketPath.path`
    /// but re-evaluated each time so tests can observe env overrides.
    /// `AgentHookSocketPath.path` itself is not actor-isolated — it just
    /// reads env + home dir — so we can call it from a nonisolated context.
    static var socketPath: String { AgentHookSocketPath.path }

    // MARK: - Private state

    /// `Logger` is Sendable and we need to read it from `@Sendable`
    /// Network.framework callbacks that are not MainActor-isolated,
    /// so mark the static constant `nonisolated`.
    private nonisolated static let logger = Logger(
        subsystem: "com.aiyuai.aiyuterm",
        category: "AgentHookServer"
    )

    private var listener: NWListener?

    /// Upper bound on request payload size. The bridge is trusted but
    /// we refuse to buffer more than 1 MB to protect against runaways.
    private static let maxPayloadSize = 1_048_576

    /// Tools that we allow to bypass the permission UI entirely. These
    /// are AiyuTerm / Claude Code internal primitives where user
    /// confirmation would be pure noise.
    ///
    /// Kept deliberately narrow in Phase 2. We only include the
    /// local TODO and plan-mode helpers; the CodeIsland Task* family
    /// is intentionally NOT in this list because AiyuTerm does not
    /// yet own the semantic understanding of those tools.
    private static let autoApproveTools: Set<String> = [
        "TodoRead", "TodoWrite",
        "EnterPlanMode", "ExitPlanMode",
    ]

    private final class ConnectionContext {
        var responded: Bool = false
    }

    private var connectionContexts: [ObjectIdentifier: ConnectionContext] = [:]

    /// FIFO cache that correlates `PreToolUse` tool_use_id values with
    /// subsequent `PermissionRequest` events that share the same
    /// (sessionId, toolName, toolInput) composite key.
    private var toolUseIdCache = AgentToolUseIdCache()

    // MARK: - Lifecycle

    init() {}

    /// Attach the receiver that will handle decoded events. Must be
    /// called before `start()`; calling twice replaces the previous
    /// receiver.
    func attach(receiver: AgentHookReceiver) {
        self.receiver = receiver
    }

    /// Start listening on the resolved socket path. Throws if the
    /// path exceeds the 104-byte sun_path limit or if `NWListener`
    /// construction fails.
    func start() throws {
        let path = AgentHookServer.socketPath

        // Ensure the parent directory exists. For the default path
        // this is ~/.aiyuterm, which may not exist on first launch.
        let parent = (path as NSString).deletingLastPathComponent
        if !parent.isEmpty {
            try? FileManager.default.createDirectory(
                atPath: parent,
                withIntermediateDirectories: true
            )
        }

        // Enforce the sun_path limit before handing the path off to
        // Network.framework; the error NWListener produces otherwise
        // is cryptic.
        guard path.utf8.count <= AgentHookSocketPath.maximumSocketPathLength else {
            throw AgentHookServerError.socketPathTooLong(path)
        }

        // Clean up any stale socket left behind by a previous run.
        unlink(path)

        let params = NWParameters()
        params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
        params.requiredLocalEndpoint = NWEndpoint.unix(path: path)

        let newListener: NWListener
        do {
            newListener = try NWListener(using: params)
        } catch {
            throw AgentHookServerError.listenerStartFailed(error)
        }
        listener = newListener

        newListener.newConnectionHandler = { [weak self] connection in
            // Copy the weak reference into a local `let` so that the
            // @Sendable Task closure can capture it. Capturing the outer
            // `self` directly is a warning today and an error in Swift 6.
            let weakServer = self
            Task { @MainActor in
                weakServer?.handleConnection(connection)
            }
        }

        newListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // Restrict to owner-only access (rwx------). The
                // bridge runs as the same uid so this is sufficient.
                chmod(path, 0o700)
                Self.logger.info("AgentHookServer listening on \(path, privacy: .public)")
            case let .failed(error):
                Self.logger.error("AgentHookServer failed: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }

        newListener.start(queue: .main)
    }

    /// Stop listening and remove the socket file.
    func stop() {
        listener?.cancel()
        listener = nil
        unlink(AgentHookServer.socketPath)
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receiveAll(connection: connection, accumulated: Data())
    }

    /// Recursively receive until EOF or error, then dispatch.
    private func receiveAll(connection: NWConnection, accumulated: Data) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536
        ) { [weak self] content, _, isComplete, error in
            let weakServer = self
            Task { @MainActor in
                guard let server = weakServer else { return }

                if error != nil && accumulated.isEmpty && content == nil {
                    connection.cancel()
                    return
                }

                var data = accumulated
                if let content { data.append(content) }

                if data.count > AgentHookServer.maxPayloadSize {
                    AgentHookServer.logger.warning("Payload too large (\(data.count) bytes), dropping connection")
                    connection.cancel()
                    return
                }

                if isComplete || error != nil {
                    server.processRequest(data: data, connection: connection)
                } else {
                    server.receiveAll(connection: connection, accumulated: data)
                }
            }
        }
    }

    // MARK: - Request dispatch

    private func processRequest(data: Data, connection: NWConnection) {
        guard let event = AgentHookEvent(from: data) else {
            sendResponse(connection: connection, data: Data(#"{"error":"parse_failed"}"#.utf8))
            return
        }

        // Drop events from non-whitelisted sources silently.
        if let rawSource = event.rawJSON["_source"] as? String,
           AgentSessionSnapshot.normalizedSupportedSource(rawSource) == nil
        {
            sendResponse(connection: connection, data: Data("{}".utf8))
            return
        }

        guard let receiver = receiver else {
            // Phase 2 stub safety net: if no receiver is attached we
            // still ack with {} so the bridge completes cleanly. This
            // is also the code path exercised during Phase 2 end-to-end
            // verification (`nc -U ... < test.json`).
            sendResponse(connection: connection, data: Data("{}".utf8))
            return
        }

        // -- tool_use_id correlation cache management --
        let normalizedName = AgentHookEventNormalizer.normalize(event.eventName)
        let cacheSessionId = event.sessionId ?? "default"

        if normalizedName == "PreToolUse",
           let toolUseId = event.rawJSON["tool_use_id"] as? String
        {
            toolUseIdCache.store(
                sessionId: cacheSessionId,
                toolName: event.toolName,
                toolInput: event.toolInput,
                toolUseId: toolUseId
            )
        } else if normalizedName == "PostToolUse",
                  let toolUseId = event.rawJSON["tool_use_id"] as? String
        {
            toolUseIdCache.remove(toolUseId: toolUseId)
        }

        toolUseIdCache.sweepExpired(olderThan: Date().addingTimeInterval(-30))

        // Resolve tool_use_id for permission requests so downstream
        // handlers can correlate the permission with its originating
        // PreToolUse event.
        var mutableEvent = event
        if event.eventName == "PermissionRequest" {
            mutableEvent.resolvedToolUseId = toolUseIdCache.resolve(
                sessionId: cacheSessionId,
                toolName: event.toolName,
                toolInput: event.toolInput
            )
        }

        if mutableEvent.eventName == "PermissionRequest" {
            let sessionId = mutableEvent.sessionId ?? "default"

            // Auto-approve internal helpers without a round-trip to
            // the UI layer.
            if let toolName = mutableEvent.toolName, Self.autoApproveTools.contains(toolName) {
                let response = #"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}"#
                sendResponse(connection: connection, data: Data(response.utf8))
                return
            }

            // `AskUserQuestion` is a structured question, not a
            // permission — route it to the question handler.
            if mutableEvent.toolName == "AskUserQuestion" {
                monitorPeerDisconnect(connection: connection, sessionId: sessionId)
                let weakServer: AgentHookServer? = self
                let capturedEvent = mutableEvent
                Task { @MainActor in
                    guard let server = weakServer else { return }
                    let responseBody = await receiver.handleAskUserQuestion(capturedEvent)
                    server.sendResponse(connection: connection, data: responseBody)
                }
                return
            }

            monitorPeerDisconnect(connection: connection, sessionId: sessionId)
            let weakServerPerm: AgentHookServer? = self
            let capturedPermEvent = mutableEvent
            Task { @MainActor in
                guard let server = weakServerPerm else { return }
                let responseBody = await receiver.handlePermissionRequest(capturedPermEvent)
                server.sendResponse(connection: connection, data: responseBody)
            }
        } else if AgentHookEventNormalizer.normalize(mutableEvent.eventName) == "Notification",
                  AgentQuestionPayload.from(event: mutableEvent) != nil
        {
            let questionSessionId = mutableEvent.sessionId ?? "default"
            monitorPeerDisconnect(connection: connection, sessionId: questionSessionId)
            let weakServerQ: AgentHookServer? = self
            let capturedQEvent = mutableEvent
            Task { @MainActor in
                guard let server = weakServerQ else { return }
                let responseBody = await receiver.handleQuestion(capturedQEvent)
                server.sendResponse(connection: connection, data: responseBody)
            }
        } else {
            receiver.handleEvent(mutableEvent)
            sendResponse(connection: connection, data: Data("{}".utf8))
        }
    }

    // MARK: - Peer disconnect monitor

    /// Watch for bridge process disconnect. Only real socket teardown
    /// (`.cancelled` / `.failed`) counts — the normal `SHUT_WR`
    /// half-close does not fire these transitions.
    private func monitorPeerDisconnect(connection: NWConnection, sessionId: String) {
        let context = ConnectionContext()
        connectionContexts[ObjectIdentifier(connection)] = context

        connection.stateUpdateHandler = { [weak self] state in
            let weakServer = self
            Task { @MainActor in
                guard let server = weakServer else { return }
                switch state {
                case .cancelled, .failed:
                    if !context.responded {
                        server.receiver?.handlePeerDisconnect(sessionId: sessionId)
                    }
                    server.connectionContexts.removeValue(forKey: ObjectIdentifier(connection))
                default:
                    break
                }
            }
        }
    }

    // MARK: - Response helper

    private func sendResponse(connection: NWConnection, data: Data) {
        // Mark as responded BEFORE cancel() so the disconnect monitor
        // ignores our own teardown.
        if let context = connectionContexts[ObjectIdentifier(connection)] {
            context.responded = true
        }
        connection.send(
            content: data,
            completion: .contentProcessed { _ in
                connection.cancel()
            }
        )
    }
}

// MARK: - AgentToolUseIdCache

/// FIFO cache that correlates `PreToolUse` events (which carry a
/// `tool_use_id`) with subsequent `PermissionRequest` events that
/// share the same (sessionId, toolName, toolInput) tuple but lack
/// their own `tool_use_id`.
///
/// Entries are stored on `PreToolUse` and consumed (FIFO) on
/// `PermissionRequest.resolve()`. `PostToolUse` removes by exact
/// `toolUseId` so that completed tools don't linger.
struct AgentToolUseIdCache {

    // MARK: - Types

    private struct Entry {
        let toolUseId: String
        let storedAt: Date
    }

    // MARK: - State

    /// Keyed by composite string: "sessionId:toolName:sortedInputJSON"
    private var cache: [String: [Entry]] = [:]

    // MARK: - Composite key

    /// Build a deterministic composite key from session, tool name,
    /// and tool input. The input dictionary is serialized with sorted
    /// keys so that key ordering differences across JSON encoders do
    /// not produce distinct cache keys.
    static func buildCompositeKey(
        sessionId: String,
        toolName: String?,
        toolInput: [String: Any]?
    ) -> String {
        let sortedInput: String
        if let input = toolInput,
           let data = try? JSONSerialization.data(
               withJSONObject: input,
               options: .sortedKeys
           ),
           let str = String(data: data, encoding: .utf8)
        {
            sortedInput = str
        } else {
            sortedInput = "{}"
        }
        return "\(sessionId):\(toolName ?? ""):\(sortedInput)"
    }

    // MARK: - Mutations

    /// Store a tool_use_id from a `PreToolUse` event. Multiple
    /// entries with the same composite key are kept in FIFO order.
    mutating func store(
        sessionId: String,
        toolName: String?,
        toolInput: [String: Any]?,
        toolUseId: String
    ) {
        let key = Self.buildCompositeKey(
            sessionId: sessionId,
            toolName: toolName,
            toolInput: toolInput
        )
        cache[key, default: []].append(
            Entry(toolUseId: toolUseId, storedAt: Date())
        )
    }

    /// Consume the oldest tool_use_id matching the composite key
    /// (FIFO). Returns `nil` if no entry matches.
    mutating func resolve(
        sessionId: String,
        toolName: String?,
        toolInput: [String: Any]?
    ) -> String? {
        let key = Self.buildCompositeKey(
            sessionId: sessionId,
            toolName: toolName,
            toolInput: toolInput
        )
        guard var entries = cache[key], !entries.isEmpty else {
            return nil
        }
        let first = entries.removeFirst()
        cache[key] = entries.isEmpty ? nil : entries
        return first.toolUseId
    }

    /// Remove a specific tool_use_id (called on `PostToolUse` so
    /// completed tools don't linger in the cache).
    mutating func remove(toolUseId: String) {
        for (key, var entries) in cache {
            entries.removeAll { $0.toolUseId == toolUseId }
            cache[key] = entries.isEmpty ? nil : entries
        }
    }

    /// Remove all entries older than `threshold`. Called on every
    /// `processRequest` with a 30-second window to prevent unbounded
    /// growth from orphaned PreToolUse events.
    mutating func sweepExpired(olderThan threshold: Date) {
        for (key, var entries) in cache {
            entries.removeAll { $0.storedAt < threshold }
            cache[key] = entries.isEmpty ? nil : entries
        }
    }
}
