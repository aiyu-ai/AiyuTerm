//
//  QuickCommandSupport.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

nonisolated enum QuickCommandCategory: String, Codable, Hashable, CaseIterable, Identifiable {
    case codex
    case claude
    case cloud
    case linux

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        case .cloud:
            return "Cloud"
        case .linux:
            return "Linux"
        }
    }

    var symbolName: String {
        switch self {
        case .codex:
            return "command"
        case .claude:
            return "text.bubble"
        case .cloud:
            return "cloud.fill"
        case .linux:
            return "terminal"
        }
    }
}

nonisolated struct QuickCommandPreset: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var command: String
    var category: QuickCommandCategory

    init(
        id: String = UUID().uuidString,
        title: String,
        command: String,
        category: QuickCommandCategory
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? UUID().uuidString
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.command = command
        self.category = category
    }

    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? fallbackTitle
    }

    var normalizedCommand: String {
        command.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fallbackTitle: String {
        normalizedCommand
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? category.title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case command
        case category
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            command: try container.decodeIfPresent(String.self, forKey: .command) ?? "",
            category: try container.decodeIfPresent(QuickCommandCategory.self, forKey: .category) ?? .codex
        )
    }
}

enum QuickCommandCatalog {
    static let maxRecentCount = 6

    static let defaultCommands: [QuickCommandPreset] = [
        QuickCommandPreset(
            id: "codex",
            title: "codex",
            command: "codex",
            category: .codex
        ),
        QuickCommandPreset(
            id: "codex-bypass",
            title: "codex --dangerously-bypass-approvals-and-sandbox",
            command: "codex --dangerously-bypass-approvals-and-sandbox",
            category: .codex
        ),
        QuickCommandPreset(
            id: "codex-resume",
            title: "codex resume",
            command: "codex resume",
            category: .codex
        ),
        QuickCommandPreset(
            id: "claude",
            title: "claude",
            command: "claude",
            category: .claude
        ),
        QuickCommandPreset(
            id: "claude-skip-permissions",
            title: "claude --dangerously-skip-permissions",
            command: "claude --dangerously-skip-permissions",
            category: .claude
        ),
        QuickCommandPreset(
            id: "claude-resume",
            title: "claude --resume",
            command: "claude --resume",
            category: .claude
        ),
    ]

    static func normalizedCommands(_ commands: [QuickCommandPreset]) -> [QuickCommandPreset] {
        var seenIDs = Set<String>()

        return commands.compactMap { command in
            let normalizedCommand = command.normalizedCommand
            guard !normalizedCommand.isEmpty else { return nil }

            let normalizedID = command.id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? UUID().uuidString
            guard seenIDs.insert(normalizedID).inserted else { return nil }

            return QuickCommandPreset(
                id: normalizedID,
                title: command.normalizedTitle,
                command: normalizedCommand,
                category: command.category
            )
        }
    }

    static func normalizedRecentCommandIDs(
        _ recentIDs: [String],
        availableCommands: [QuickCommandPreset]
    ) -> [String] {
        let validIDs = Set(availableCommands.map(\.id))
        var deduplicated: [String] = []
        var seenIDs = Set<String>()

        for id in recentIDs {
            guard validIDs.contains(id), seenIDs.insert(id).inserted else { continue }
            deduplicated.append(id)
            if deduplicated.count == maxRecentCount {
                break
            }
        }

        return deduplicated
    }
}
