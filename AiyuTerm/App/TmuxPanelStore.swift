//
//  TmuxPanelStore.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Combine
import Foundation

@MainActor
final class TmuxPanelStore: ObservableObject {
    @Published var sessions: [TmuxSession] = []
    @Published var isAvailable: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isCollapsed: Bool = true

    private let coordinator: TmuxAttachCoordinator

    init(coordinator: TmuxAttachCoordinator = .shared) {
        self.coordinator = coordinator
    }

    func checkAvailabilityAndRefresh() {
        Task {
            isAvailable = await TmuxService.isTmuxAvailable()
            if isAvailable && sessions.isEmpty {
                refresh()
            }
        }
    }

    func refresh() {
        guard isAvailable else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let loaded = try await TmuxService.listSessions()
                sessions = loaded
                coordinator.cleanup(activeSessionIDs: Set(loaded.map(\.sessionID)))
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Session operations

    func createSession(name: String) {
        guard TmuxSessionNameValidator.isValid(name) else {
            errorMessage = TmuxError.invalidSessionName(name).localizedDescription
            return
        }
        Task {
            do {
                try await TmuxService.createSession(name: name)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func killSession(sessionID: String) {
        Task {
            do {
                try await TmuxService.killSession(sessionID: sessionID)
                coordinator.unregister(sessionID: sessionID)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func renameSession(sessionID: String, newName: String) {
        guard TmuxSessionNameValidator.isValid(newName) else {
            errorMessage = TmuxError.invalidSessionName(newName).localizedDescription
            return
        }
        Task {
            do {
                try await TmuxService.renameSession(sessionID: sessionID, newName: newName)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func detachSession(sessionID: String) {
        Task {
            do {
                try await TmuxService.detachSession(sessionID: sessionID)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Attach

    func attachConfiguration(sessionID: String) -> SessionBackendConfiguration? {
        guard sessions.contains(where: { $0.sessionID == sessionID }),
              let shellArgs = TmuxService.attachArguments(sessionID: sessionID) else { return nil }
        let defaultShell = LocalShellSessionConfiguration.default
        return .local(shellPath: defaultShell.shellPath, shellArguments: shellArgs)
    }

    func sessionName(for sessionID: String) -> String? {
        sessions.first(where: { $0.sessionID == sessionID })?.name
    }
}
