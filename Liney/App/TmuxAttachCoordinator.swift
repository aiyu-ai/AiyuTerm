//
//  TmuxAttachCoordinator.swift
//  Liney
//
//  Author: wuwenrui
//

import Combine
import Foundation

@MainActor
final class TmuxAttachCoordinator: ObservableObject {
    static let shared = TmuxAttachCoordinator()

    struct Attachment {
        let storeID: UUID
        let shellSessionID: UUID
    }

    @Published private(set) var attachments: [String: Attachment] = [:]

    init() {}

    func isAttached(_ sessionID: String) -> Bool {
        attachments[sessionID] != nil
    }

    func register(sessionID: String, storeID: UUID, shellSessionID: UUID) {
        attachments[sessionID] = Attachment(storeID: storeID, shellSessionID: shellSessionID)
    }

    func unregister(sessionID: String) {
        attachments.removeValue(forKey: sessionID)
    }

    func shellSessionID(for sessionID: String) -> UUID? {
        attachments[sessionID]?.shellSessionID
    }

    func storeID(for sessionID: String) -> UUID? {
        attachments[sessionID]?.storeID
    }

    func cleanup(activeSessionIDs: Set<String>) {
        for key in attachments.keys where !activeSessionIDs.contains(key) {
            attachments.removeValue(forKey: key)
        }
    }
}
