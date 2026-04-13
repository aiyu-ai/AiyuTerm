//
//  AgentJSONLWatcher.swift
//  AiyuTerm
//
//  File-system event watcher for JSONL conversation files.
//  Uses GCD dispatch sources to monitor write/extend events
//  and invokes a callback when new data is appended.
//
//  Enforces a maximum of 20 concurrent watchers with LRU
//  eviction to avoid exhausting file descriptors.
//

import Foundation

final class AgentJSONLWatcher {

    // MARK: - Types

    private struct WatchEntry {
        let sessionId: String
        let source: DispatchSourceFileSystemObject
        let fileDescriptor: Int32
        let createdAt: Date
    }

    // MARK: - State

    private var watchers: [String: WatchEntry] = [:]
    private let maxWatchers = 20
    private let queue = DispatchQueue(
        label: "com.aiyuai.aiyuterm.jsonl-watcher",
        qos: .userInteractive
    )

    /// Number of currently active watchers.
    var activeCount: Int { watchers.count }

    // MARK: - Public API

    /// Start watching a JSONL file for write/extend events.
    /// Replaces any existing watcher for the same `sessionId`.
    /// Evicts the oldest watcher when the pool is full.
    func watch(
        sessionId: String,
        filePath: String,
        onChange: @escaping () -> Void
    ) {
        unwatch(sessionId: sessionId)

        // LRU eviction if at capacity.
        if watchers.count >= maxWatchers {
            if let oldest = watchers.min(by: { $0.value.createdAt < $1.value.createdAt }) {
                unwatch(sessionId: oldest.key)
            }
        }

        let fd = open(filePath, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )
        source.setEventHandler {
            DispatchQueue.main.async { onChange() }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()

        watchers[sessionId] = WatchEntry(
            sessionId: sessionId,
            source: source,
            fileDescriptor: fd,
            createdAt: Date()
        )
    }

    /// Stop watching the file for a given session.
    func unwatch(sessionId: String) {
        guard let entry = watchers.removeValue(forKey: sessionId) else { return }
        entry.source.cancel()
    }

    /// Stop all active watchers and release file descriptors.
    func unwatchAll() {
        for entry in watchers.values {
            entry.source.cancel()
        }
        watchers.removeAll()
    }

    deinit {
        unwatchAll()
    }
}
