//
//  ShellCommandRunner.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

struct ShellCommandResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

enum ShellCommandError: LocalizedError {
    case executableNotFound(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let executable):
            return "Executable not found: \(executable)"
        case .failed(let message):
            return message
        }
    }
}

actor ShellCommandRunner {
    func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async throws -> ShellCommandResult {
        guard FileManager.default.isExecutableFile(atPath: executable) || executable.contains("/") == false else {
            throw ShellCommandError.executableNotFound(executable)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let currentDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
            }
            if let environment {
                process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(
                    returning: ShellCommandResult(
                        stdout: String(decoding: stdoutData, as: UTF8.self),
                        stderr: String(decoding: stderrData, as: UTF8.self),
                        exitCode: process.terminationStatus
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ShellCommandError.failed(error.localizedDescription))
            }
        }
    }
}
