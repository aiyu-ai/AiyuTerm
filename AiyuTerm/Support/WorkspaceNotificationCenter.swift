//
//  WorkspaceNotificationCenter.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation
import UserNotifications

@MainActor
final class WorkspaceNotificationCenter {
    static let shared = WorkspaceNotificationCenter()

    private var hasRequestedAuthorization = false

    func deliver(title: String, body: String?) {
        let center = UNUserNotificationCenter.current()
        if !hasRequestedAuthorization {
            hasRequestedAuthorization = true
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        if let body, !body.isEmpty {
            content.body = body
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.aiyuterm.app.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
