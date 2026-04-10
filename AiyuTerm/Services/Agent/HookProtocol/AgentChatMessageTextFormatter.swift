//
// AgentChatMessageTextFormatter.swift
// AiyuTerm
//
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandCore/ChatMessageTextFormatter.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
//
// Renders `AgentChatMessage` instances into `AttributedString` for
// the notch panel's chat preview and any future sidebar chat
// scrollback. User messages stay literal so agents can't inject
// markdown into the UI; assistant messages go through inline-only
// markdown so `**bold**` / `_italic_` / backtick code spans render.
//
// A small LRU-ish cache in front of `AttributedString(markdown:)`
// avoids re-parsing identical messages when the view rebuilds.
//

import Foundation

enum AgentChatMessageTextFormatter {
    /// Thread-safe cache. The original CodeIsland code used a plain
    /// dictionary under the assumption that all access was on the
    /// main thread. Swift 6 strict concurrency pushes us to lock
    /// explicitly so the type can be called from anywhere.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var markdownCache: [String: AttributedString] = [:]
    private static let markdownCacheLimit = 128

    static func displayText(for message: AgentChatMessage) -> AttributedString {
        message.isUser ? literalText(message.text) : inlineMarkdown(message.text)
    }

    static func literalText(_ text: String) -> AttributedString {
        AttributedString(text)
    }

    static func inlineMarkdown(_ text: String) -> AttributedString {
        cacheLock.lock()
        if let cached = markdownCache[text] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let result: AttributedString
        if let attr = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            result = attr
        } else {
            result = AttributedString(text)
        }

        cacheLock.lock()
        if markdownCache.count >= markdownCacheLimit {
            markdownCache.removeAll(keepingCapacity: true)
        }
        markdownCache[text] = result
        cacheLock.unlock()
        return result
    }
}
