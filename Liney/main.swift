//
//  main.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Cocoa

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
MainActor.assumeIsolated {
    app.delegate = delegate
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
