//
//  TmuxModels.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

struct TmuxSession: Identifiable, Equatable {
    let sessionID: String
    let name: String
    let isAttached: Bool
    let windowCount: Int
    var id: String { sessionID }
}

enum TmuxError: LocalizedError {
    case notInstalled
    case noServerRunning
    case commandFailed(String)
    case parseError(String)
    case invalidSessionName(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "tmux is not installed"
        case .noServerRunning:
            return "No tmux server running"
        case .commandFailed(let message):
            return "tmux command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse tmux output: \(message)"
        case .invalidSessionName(let name):
            return "Invalid session name: \(name). Only alphanumeric, dash, underscore, and dot allowed."
        }
    }
}

enum TmuxSessionNameValidator {
    static func isValid(_ name: String) -> Bool {
        let pattern = "^[a-zA-Z0-9._-]+$"
        return !name.isEmpty && name.range(of: pattern, options: .regularExpression) != nil
    }
}
