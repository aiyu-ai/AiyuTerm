//
//  AiyuTermGhosttyShellIntegration.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation

struct AiyuTermGhosttyResourcePaths: Equatable {
    var ghosttyResourcesDirectory: String?
    var terminfoDirectory: String?

    init(resourceRootURL: URL?, fileManager: FileManager = .default) {
        guard let resourceRootURL else {
            self.ghosttyResourcesDirectory = nil
            self.terminfoDirectory = nil
            return
        }

        let ghosttyURL = resourceRootURL.appendingPathComponent("ghostty", isDirectory: true)
        let terminfoURL = resourceRootURL.appendingPathComponent("terminfo", isDirectory: true)

        self.ghosttyResourcesDirectory = fileManager.fileExists(atPath: ghosttyURL.path)
            ? ghosttyURL.path
            : nil
        self.terminfoDirectory = fileManager.fileExists(atPath: terminfoURL.path)
            ? terminfoURL.path
            : nil
    }

    init(ghosttyResourcesDirectory: String?, terminfoDirectory: String?) {
        self.ghosttyResourcesDirectory = ghosttyResourcesDirectory
        self.terminfoDirectory = terminfoDirectory
    }

    static func bundleMain() -> AiyuTermGhosttyResourcePaths {
        AiyuTermGhosttyResourcePaths(resourceRootURL: Bundle.main.resourceURL)
    }
}

enum AiyuTermGhosttyShellIntegration {
    private static let defaultShellFeatures = ["ssh-env"]

    static func prepare(
        command: TerminalCommandDefinition,
        environment: [String: String],
        resourcePaths: AiyuTermGhosttyResourcePaths = .bundleMain()
    ) -> (command: TerminalCommandDefinition, environment: [String: String]) {
        var environment = environment

        environment["TERM"] = "xterm-ghostty"
        environment["COLORTERM"] = "truecolor"
        environment["GHOSTTY_SHELL_FEATURES"] = mergedShellFeatures(
            existing: environment["GHOSTTY_SHELL_FEATURES"],
            defaults: defaultShellFeatures
        )

        if let terminfoDirectory = resourcePaths.terminfoDirectory {
            environment["TERMINFO"] = terminfoDirectory
        }
        if let ghosttyResourcesDirectory = resourcePaths.ghosttyResourcesDirectory {
            environment["GHOSTTY_RESOURCES_DIR"] = ghosttyResourcesDirectory
        }

        guard let ghosttyResourcesDirectory = resourcePaths.ghosttyResourcesDirectory else {
            return (command, environment)
        }

        switch shellName(for: command.executablePath) {
        case "zsh":
            injectZsh(into: &environment, ghosttyResourcesDirectory: ghosttyResourcesDirectory)
        case "fish":
            injectFish(into: &environment, ghosttyResourcesDirectory: ghosttyResourcesDirectory)
        default:
            break
        }

        return (command, environment)
    }

    private static func mergedShellFeatures(
        existing: String?,
        defaults: [String]
    ) -> String {
        let existingFeatures = existing?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        var orderedFeatures = existingFeatures
        for feature in defaults where !orderedFeatures.contains(feature) {
            orderedFeatures.append(feature)
        }
        return orderedFeatures.joined(separator: ",")
    }

    private static func shellName(for executablePath: String) -> String {
        URL(fileURLWithPath: executablePath).lastPathComponent.lowercased()
    }

    private static func injectZsh(into environment: inout [String: String], ghosttyResourcesDirectory: String) {
        let integrationDirectory = URL(fileURLWithPath: ghosttyResourcesDirectory)
            .appendingPathComponent("shell-integration/zsh", isDirectory: true)
            .path

        if let existingZdotdir = environment["ZDOTDIR"], !existingZdotdir.isEmpty {
            environment["GHOSTTY_ZSH_ZDOTDIR"] = existingZdotdir
        }
        environment["ZDOTDIR"] = integrationDirectory
    }

    private static func injectFish(into environment: inout [String: String], ghosttyResourcesDirectory: String) {
        let integrationDirectory = URL(fileURLWithPath: ghosttyResourcesDirectory)
            .appendingPathComponent("shell-integration", isDirectory: true)
            .path

        environment["GHOSTTY_SHELL_INTEGRATION_XDG_DIR"] = integrationDirectory

        let existingDirectories = environment["XDG_DATA_DIRS"]?
            .split(separator: ":")
            .map(String.init) ?? []

        if existingDirectories.contains(integrationDirectory) {
            environment["XDG_DATA_DIRS"] = existingDirectories.joined(separator: ":")
            return
        }

        environment["XDG_DATA_DIRS"] = ([integrationDirectory] + existingDirectories)
            .joined(separator: ":")
    }
}
