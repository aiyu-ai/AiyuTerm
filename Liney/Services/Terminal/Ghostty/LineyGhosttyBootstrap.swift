//
//  LineyGhosttyBootstrap.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation
import GhosttyKit

enum LineyGhosttyBootstrap {
    private static let initialized: Void = {
        let result = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard result == GHOSTTY_SUCCESS else {
            let message = """
            libghostty initialization failed before the app launched.
            This usually means the embedded Ghostty runtime could not initialize its global state.
            """
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }()

    static func initialize() {
        _ = initialized
    }
}
