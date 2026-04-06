//
//  AgentSessionStatusDetector.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

enum AgentSessionStatusDetector {

    private struct Rule {
        let status: AgentSessionStatus
        let keywords: [String]
    }

    private static let notificationRules: [Rule] = [
        Rule(status: .permissionNeeded, keywords: [
            "needs your permission",
            "permission needed",
            "waiting for user to approve",
            "requires approval",
            "confirm to proceed",
        ]),
        Rule(status: .taskCompleted, keywords: [
            "task completed",
            "task finished",
            "completed successfully",
        ]),
        Rule(status: .error, keywords: [
            "error:",
            "failed",
            "error occurred",
        ]),
    ]

    static func detect(title: String, body: String?) -> AgentSessionStatus {
        guard let body, !body.isEmpty else { return .none }

        let lowercasedBody = body.lowercased()

        for rule in notificationRules {
            for keyword in rule.keywords {
                if lowercasedBody.contains(keyword) {
                    return rule.status
                }
            }
        }

        return .none
    }

    /// Claude Code terminal title prefixes:
    /// - Busy (agent working): animated braille dots U+2802 / U+2810 alternating
    /// - Idle: static U+2733 (eight-spoked asterisk)
    /// Title format: "<prefix> <session title>"
    static func detectFromTitle(_ title: String) -> AgentSessionStatus {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        // Busy: braille animation frames used by Claude Code when agent is thinking/executing
        if trimmed.hasPrefix("\u{2802}") || trimmed.hasPrefix("\u{2810}") {
            return .working
        }
        return .none
    }
}
