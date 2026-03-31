//
//  TmuxModels.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

struct TmuxSession: Identifiable, Equatable {
    let name: String
    let isAttached: Bool
    let windowCount: Int
    var id: String { name }
}

struct TmuxWindow: Identifiable, Equatable {
    let sessionName: String
    let index: Int
    let name: String
    let isActive: Bool
    var id: String { "\(sessionName):\(index)" }
}

enum TmuxError: LocalizedError {
    case notInstalled
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "tmux is not installed"
        case .commandFailed(let message):
            return "tmux command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse tmux output: \(message)"
        }
    }
}
