//
//  LineyGhosttyShellIntegration.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

struct LineyGhosttyResourcePaths: Equatable {
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

    static func bundleMain() -> LineyGhosttyResourcePaths {
        LineyGhosttyResourcePaths(resourceRootURL: Bundle.main.resourceURL)
    }
}

enum LineyGhosttyShellIntegration {
    static func prepare(
        command: TerminalCommandDefinition,
        environment: [String: String],
        resourcePaths: LineyGhosttyResourcePaths = .bundleMain()
    ) -> (command: TerminalCommandDefinition, environment: [String: String]) {
        var environment = environment

        environment["TERM"] = "xterm-ghostty"
        environment["COLORTERM"] = "truecolor"

        if let terminfoDirectory = resourcePaths.terminfoDirectory {
            environment["TERMINFO"] = terminfoDirectory
        }
        if let ghosttyResourcesDirectory = resourcePaths.ghosttyResourcesDirectory {
            environment["GHOSTTY_RESOURCES_DIR"] = ghosttyResourcesDirectory
        }

        guard let ghosttyResourcesDirectory = resourcePaths.ghosttyResourcesDirectory else {
            return (command, environment)
        }

        if shellName(for: command.executablePath) == "zsh" {
            injectZsh(into: &environment, ghosttyResourcesDirectory: ghosttyResourcesDirectory)
        }

        return (command, environment)
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
}
