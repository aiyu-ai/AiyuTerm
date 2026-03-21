//
//  PathFormatting.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

extension String {
    nonisolated var abbreviatedPath: String {
        let home = NSHomeDirectory()
        if hasPrefix(home) {
            return "~" + dropFirst(home.count)
        }
        return self
    }

    nonisolated var lastPathComponentValue: String {
        URL(fileURLWithPath: self).lastPathComponent
    }

    nonisolated var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
