//
//  AppSettingsPersistence.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation

private let aiyuTermPersistenceIsDebugBuild: Bool = {
#if DEBUG
    true
#else
    false
#endif
}()

func aiyuTermStateDirectoryName(isDebugBuild: Bool = aiyuTermPersistenceIsDebugBuild) -> String {
    isDebugBuild ? ".aiyuterm-debug" : ".aiyuterm"
}

func aiyuTermStateDirectoryURL(fileManager: FileManager = .default) -> URL {
    fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
        aiyuTermStateDirectoryName(),
        isDirectory: true
    )
}

struct AppSettingsPersistence {
    private let fileManager = FileManager.default

    func load() -> AppSettings {
        let url = resolvedSettingsFileURL()
        guard let data = try? Data(contentsOf: url) else {
            return AppSettings()
        }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save(_ settings: AppSettings) throws {
        let directory = stateDirectoryURL()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsFileURL(), options: Data.WritingOptions.atomic)
    }

    private func stateDirectoryURL() -> URL {
        aiyuTermStateDirectoryURL(fileManager: fileManager)
    }

    private func settingsFileURL() -> URL {
        stateDirectoryURL().appendingPathComponent("settings.json")
    }

    private func resolvedSettingsFileURL() -> URL {
        let preferredURL = settingsFileURL()
        if fileManager.fileExists(atPath: preferredURL.path) {
            return preferredURL
        }

        let legacyURL = legacySettingsFileURL()
        if fileManager.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }

        return preferredURL
    }

    private func legacySettingsFileURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("AiyuTerm", isDirectory: true)
            .appendingPathComponent("settings.json")
    }
}
