//
//  SleepPreventionSupport.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

nonisolated enum SleepPreventionDurationOption: String, CaseIterable, Identifiable, Hashable {
    case oneHour
    case twoHours
    case threeHours
    case sixHours
    case twelveHours
    case oneDay
    case threeDays
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneHour:
            return "1 Hour"
        case .twoHours:
            return "2 Hours"
        case .threeHours:
            return "3 Hours"
        case .sixHours:
            return "6 Hours"
        case .twelveHours:
            return "12 Hours"
        case .oneDay:
            return "1 Day"
        case .threeDays:
            return "3 Days"
        case .forever:
            return "Never Sleep"
        }
    }

    var compactTitle: String {
        switch self {
        case .oneHour:
            return "1h"
        case .twoHours:
            return "2h"
        case .threeHours:
            return "3h"
        case .sixHours:
            return "6h"
        case .twelveHours:
            return "12h"
        case .oneDay:
            return "1d"
        case .threeDays:
            return "3d"
        case .forever:
            return "Never"
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .oneHour:
            return 60 * 60
        case .twoHours:
            return 2 * 60 * 60
        case .threeHours:
            return 3 * 60 * 60
        case .sixHours:
            return 6 * 60 * 60
        case .twelveHours:
            return 12 * 60 * 60
        case .oneDay:
            return 24 * 60 * 60
        case .threeDays:
            return 3 * 24 * 60 * 60
        case .forever:
            return nil
        }
    }
}

nonisolated struct SleepPreventionSession: Equatable {
    let option: SleepPreventionDurationOption
    let startedAt: Date
    let expiresAt: Date?

    init(option: SleepPreventionDurationOption, startedAt: Date, expiresAt: Date?) {
        self.option = option
        self.startedAt = startedAt
        self.expiresAt = expiresAt
    }

    var isIndefinite: Bool {
        expiresAt == nil
    }

    func compactRemainingDescription(relativeTo now: Date) -> String {
        guard let expiresAt else {
            return "On"
        }
        let remaining = max(0, expiresAt.timeIntervalSince(now))
        return SleepPreventionFormat.duration(remaining)
    }

    func remainingDescription(relativeTo now: Date) -> String {
        let compact = compactRemainingDescription(relativeTo: now)
        return compact == "On" ? compact : "\(compact) left"
    }
}

nonisolated enum SleepPreventionStopReason: Equatable {
    case userInitiated
    case completed
    case failed(String)
}

nonisolated enum SleepPreventionControllerEvent: Equatable {
    case started(SleepPreventionSession)
    case stopped(SleepPreventionStopReason)
}

nonisolated enum SleepPreventionFormat {
    static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval.rounded(.down)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        var parts: [String] = []
        if days > 0 {
            parts.append("\(days)d")
        }
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if minutes > 0 && parts.count < 2 {
            parts.append("\(minutes)m")
        }

        if parts.isEmpty {
            return "under 1m"
        }
        return parts.prefix(2).joined(separator: " ")
    }
}

@MainActor
final class SleepPreventionController {
    var onEvent: ((SleepPreventionControllerEvent) -> Void)?

    private var process: Process?
    private var currentSession: SleepPreventionSession?

    deinit {
        process?.terminate()
    }

    func start(_ option: SleepPreventionDurationOption) throws {
        stopCurrentProcess(emitStoppedEvent: false)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

        var arguments = ["-dimsu"]
        if let duration = option.duration {
            arguments.append("-t")
            arguments.append(String(max(1, Int(duration.rounded(.up)))))
        }
        process.arguments = arguments

        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                guard let self,
                      self.process === process else { return }

                self.process = nil
                self.currentSession = nil

                if process.terminationReason == .exit, process.terminationStatus == 0 {
                    self.onEvent?(.stopped(.completed))
                } else {
                    self.onEvent?(.stopped(.failed("caffeinate exited with status \(process.terminationStatus).")))
                }
            }
        }

        try process.run()

        let startedAt = Date()
        let session = SleepPreventionSession(
            option: option,
            startedAt: startedAt,
            expiresAt: option.duration.map { startedAt.addingTimeInterval($0) }
        )

        self.process = process
        self.currentSession = session
        onEvent?(.started(session))
    }

    func stop() {
        stopCurrentProcess(emitStoppedEvent: true)
    }

    private func stopCurrentProcess(emitStoppedEvent: Bool) {
        let previousProcess = process
        let hadActiveSession = currentSession != nil

        process = nil
        currentSession = nil

        if emitStoppedEvent, hadActiveSession {
            onEvent?(.stopped(.userInitiated))
        }

        guard let previousProcess, previousProcess.isRunning else { return }
        previousProcess.terminate()
    }
}
