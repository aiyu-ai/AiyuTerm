//
//  AiyuTermGhosttyConfig.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation
import GhosttyKit

enum AiyuTermGhosttyConfigManager {
    static func buildConfig(
        settings: AppSettings,
        fileManager: FileManager = .default
    ) throws -> ghostty_config_t {
        guard let config = ghostty_config_new() else {
            throw CocoaError(.coderInvalidValue)
        }

        ghostty_config_load_default_files(config)

        let managedConfigURL = try writeManagedConfig(settings: settings, fileManager: fileManager)
        managedConfigURL.path.withCString { path in
            ghostty_config_load_file(config, path)
        }
        ghostty_config_finalize(config)
        return config
    }

    static func writeManagedConfig(
        settings: AppSettings,
        fileManager: FileManager = .default
    ) throws -> URL {
        let fileURL = managedConfigFileURL(fileManager: fileManager)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try managedConfigContents(settings: settings)
            .write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static func managedConfigContents(settings: AppSettings) -> String {
        var lines = [
            "# Managed by AiyuTerm. Manual edits will be overwritten.",
            "scrollbar-visible = false"
        ]

        if let terminalFontFamily = settings.terminalFontFamily {
            lines.append("font-family = \(quotedValue(terminalFontFamily))")
        }

        if let terminalFontSize = settings.terminalFontSize {
            lines.append("font-size = \(Int(terminalFontSize.rounded()))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func managedConfigFileURL(fileManager: FileManager = .default) -> URL {
        aiyuTermStateDirectoryURL(fileManager: fileManager)
            .appendingPathComponent("ghostty", isDirectory: true)
            .appendingPathComponent("aiyuterm-managed.config")
    }

    private static func quotedValue(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
