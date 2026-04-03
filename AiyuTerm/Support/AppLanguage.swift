//
//  AppLanguage.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation

nonisolated enum AppLanguage: String, Codable, Hashable, CaseIterable, Identifiable {
    case automatic
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}
