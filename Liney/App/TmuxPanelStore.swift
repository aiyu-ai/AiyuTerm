//
//  TmuxPanelStore.swift
//  Liney
//
//  Author: wuwenrui
//

import Combine
import Foundation

@MainActor
final class TmuxPanelStore: ObservableObject {
    @Published var sessions: [TmuxSession] = []
    @Published var windowsBySession: [String: [TmuxWindow]] = [:]
    @Published var expandedSessions: Set<String> = []
    @Published var isAvailable: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func checkAvailability() {
        Task {
            isAvailable = await TmuxService.isTmuxAvailable()
        }
    }

    func refresh() {
        guard isAvailable else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let loadedSessions = try await TmuxService.listSessions()
                sessions = loadedSessions
                for sessionName in expandedSessions {
                    if loadedSessions.contains(where: { $0.name == sessionName }) {
                        let windows = try await TmuxService.listWindows(session: sessionName)
                        windowsBySession[sessionName] = windows
                    } else {
                        windowsBySession.removeValue(forKey: sessionName)
                    }
                }
                expandedSessions = expandedSessions.filter { name in
                    loadedSessions.contains(where: { $0.name == name })
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func toggleSession(_ name: String) {
        if expandedSessions.contains(name) {
            expandedSessions.remove(name)
        } else {
            expandedSessions.insert(name)
            loadWindows(for: name)
        }
    }

    func createSession(name: String) {
        Task {
            do {
                try await TmuxService.createSession(name: name)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func killSession(name: String) {
        Task {
            do {
                try await TmuxService.killSession(name: name)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func renameSession(oldName: String, newName: String) {
        Task {
            do {
                try await TmuxService.renameSession(oldName: oldName, newName: newName)
                if expandedSessions.contains(oldName) {
                    expandedSessions.remove(oldName)
                    expandedSessions.insert(newName)
                }
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func detachSession(name: String) {
        Task {
            do {
                try await TmuxService.detachSession(name: name)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func createWindow(session: String, name: String?) {
        Task {
            do {
                try await TmuxService.createWindow(session: session, name: name)
                loadWindows(for: session)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func killWindow(session: String, index: Int) {
        Task {
            do {
                try await TmuxService.killWindow(session: session, index: index)
                loadWindows(for: session)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func renameWindow(session: String, index: Int, newName: String) {
        Task {
            do {
                try await TmuxService.renameWindow(session: session, index: index, newName: newName)
                loadWindows(for: session)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func moveWindow(session: String, index: Int, targetSession: String) {
        Task {
            do {
                try await TmuxService.moveWindow(session: session, index: index, targetSession: targetSession)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func attachConfiguration(session: String, windowIndex: Int) -> SessionBackendConfiguration {
        let shellArgs = TmuxService.attachArguments(session: session, windowIndex: windowIndex)
        let defaultShell = LocalShellSessionConfiguration.default
        return .local(shellPath: defaultShell.shellPath, shellArguments: shellArgs)
    }

    private func loadWindows(for session: String) {
        Task {
            do {
                let windows = try await TmuxService.listWindows(session: session)
                windowsBySession[session] = windows
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
