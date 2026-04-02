//
//  ReleaseModels.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

enum ReleaseChannel: String, Codable, CaseIterable, Hashable, Identifiable {
    case stable
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable:
            return "Stable"
        case .preview:
            return "Preview"
        }
    }
}
