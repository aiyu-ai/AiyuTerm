//
//  LineyGhosttyClipboardSupport.swift
//  Liney
//
//  Author: wuwenrui
//

import AppKit
import Foundation
import GhosttyKit

@MainActor
func lineyGhosttyPasteboard(for location: ghostty_clipboard_e) -> NSPasteboard? {
    switch location {
    case GHOSTTY_CLIPBOARD_STANDARD:
        return .general
    case GHOSTTY_CLIPBOARD_SELECTION:
        return NSPasteboard(name: NSPasteboard.Name("com.liney.selection"))
    default:
        return nil
    }
}

struct LineyGhosttyClipboardPayload: Sendable {
    let mimeType: String
    let text: String

    nonisolated var isPlainText: Bool {
        mimeType == "text/plain"
            || mimeType == "text/plain;charset=utf-8"
            || mimeType == "public.utf8-plain-text"
            || mimeType == NSPasteboard.PasteboardType.string.rawValue
    }

    nonisolated var pasteboardType: NSPasteboard.PasteboardType? {
        if isPlainText {
            return .string
        }
        return NSPasteboard.PasteboardType(rawValue: mimeType)
    }
}

@MainActor
func lineyGhosttyWriteClipboard(_ items: [LineyGhosttyClipboardPayload], to pasteboard: NSPasteboard) {
    let supportedTypes = items.compactMap(\.pasteboardType)
    guard !supportedTypes.isEmpty else { return }

    pasteboard.clearContents()
    pasteboard.declareTypes(supportedTypes, owner: nil)
    for item in items {
        guard let type = item.pasteboardType else { continue }
        pasteboard.setString(item.text, forType: type)
    }
}

extension NSPasteboard {
    var lineyGhosttyBestString: String? {
        string(forType: .string)
            ?? string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
    }
}
