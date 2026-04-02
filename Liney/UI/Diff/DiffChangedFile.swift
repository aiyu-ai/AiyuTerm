//
//  DiffChangedFile.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation

enum DiffFileStatus: String, CaseIterable, Hashable, Sendable {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case unknown

    nonisolated var symbol: String {
        switch self {
        case .modified:
            return "M"
        case .added:
            return "A"
        case .deleted:
            return "D"
        case .renamed:
            return "R"
        case .copied:
            return "C"
        case .unknown:
            return "?"
        }
    }

    static func fromGitCode(_ code: String) -> DiffFileStatus {
        guard let marker = code.first else { return .unknown }
        switch marker {
        case "M":
            return .modified
        case "A":
            return .added
        case "D":
            return .deleted
        case "R":
            return .renamed
        case "C":
            return .copied
        default:
            return .unknown
        }
    }
}

struct DiffChangedFile: Identifiable, Hashable, Sendable {
    let status: DiffFileStatus
    let oldPath: String?
    let newPath: String?

    nonisolated var id: String {
        "\(status.rawValue):\(oldPath ?? ""):\(newPath ?? "")"
    }

    nonisolated var displayPath: String {
        newPath ?? oldPath ?? ""
    }

    nonisolated var displayName: String {
        URL(fileURLWithPath: displayPath).lastPathComponent
    }

    nonisolated var directoryPath: String {
        let directory = URL(fileURLWithPath: displayPath).deletingLastPathComponent().path
        return directory == "." ? "" : directory
    }

    nonisolated var statusSymbol: String {
        status.symbol
    }

    static func parseNameStatus(_ output: String) -> [DiffChangedFile] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { rawLine in
                let components = rawLine.split(separator: "\t", omittingEmptySubsequences: false)
                guard let rawStatus = components.first.map(String.init) else { return nil }
                let status = DiffFileStatus.fromGitCode(rawStatus)

                switch status {
                case .renamed, .copied:
                    guard components.count >= 3 else { return nil }
                    return DiffChangedFile(
                        status: status,
                        oldPath: String(components[1]),
                        newPath: String(components[2])
                    )
                case .deleted:
                    guard components.count >= 2 else { return nil }
                    return DiffChangedFile(
                        status: status,
                        oldPath: String(components[1]),
                        newPath: nil
                    )
                case .added, .modified, .unknown:
                    guard components.count >= 2 else { return nil }
                    let path = String(components[1])
                    return DiffChangedFile(
                        status: status,
                        oldPath: status == .added ? nil : path,
                        newPath: path
                    )
                }
            }
    }
}
