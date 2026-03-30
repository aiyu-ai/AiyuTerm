//
//  AgentSessionStatusDetector.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

enum AgentSessionStatusDetector {

    private struct Rule {
        let status: AgentSessionStatus
        let keywords: [String]
    }

    private static let rules: [Rule] = [
        Rule(status: .permissionNeeded, keywords: [
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

        for rule in rules {
            for keyword in rule.keywords {
                if lowercasedBody.contains(keyword) {
                    return rule.status
                }
            }
        }

        return .none
    }
}
