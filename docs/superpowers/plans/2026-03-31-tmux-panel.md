# Tmux Sidebar Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a collapsible tmux management panel to the sidebar bottom, allowing users to view, create, rename, kill, detach sessions and windows, and open tmux windows in new terminal panes.

**Architecture:** A `TmuxService` enum wraps tmux CLI calls using `ShellCommandRunner`. A `TmuxPanelStore` (ObservableObject) manages panel state. A `TmuxPanelView` (SwiftUI, hosted in NSHostingView) renders the panel between the outline scroll view and the footer button inside `SidebarOutlineContainerView`.

**Tech Stack:** Swift, AppKit + SwiftUI, XCTest, tmux CLI

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `Liney/Services/Tmux/TmuxModels.swift` | TmuxSession, TmuxWindow, TmuxError types |
| Create | `Liney/Services/Tmux/TmuxService.swift` | Stateless CLI wrapper using ShellCommandRunner |
| Create | `Liney/App/TmuxPanelStore.swift` | Panel state management (ObservableObject) |
| Create | `Liney/UI/Sidebar/TmuxPanelView.swift` | SwiftUI panel view with session/window tree |
| Create | `Tests/TmuxServiceTests.swift` | Output parsing unit tests |
| Modify | `Liney/UI/Sidebar/WorkspaceSidebarView.swift:1036-1098` | Insert tmux panel hosting view in SidebarOutlineContainerView |
| Modify | `Liney/App/WorkspaceStore.swift:1190-1211` | Hold TmuxPanelStore, add createTmuxPane method |
| Modify | `Liney/Domain/AppSettings.swift:244-263` | Add tmuxPanelCollapsed boolean |

---

### Task 1: Add TmuxModels

**Files:**
- Create: `Liney/Services/Tmux/TmuxModels.swift`

- [ ] **Step 1: Create the models file**

```swift
//
//  TmuxModels.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

struct TmuxSession: Identifiable, Equatable {
    let name: String
    let isAttached: Bool
    let windowCount: Int
    var id: String { name }
}

struct TmuxWindow: Identifiable, Equatable {
    let sessionName: String
    let index: Int
    let name: String
    let isActive: Bool
    var id: String { "\(sessionName):\(index)" }
}

enum TmuxError: LocalizedError {
    case notInstalled
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "tmux is not installed"
        case .commandFailed(let message):
            return "tmux command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse tmux output: \(message)"
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Liney/Services/Tmux/TmuxModels.swift
git commit -m "feat: add TmuxSession, TmuxWindow, and TmuxError models"
```

---

### Task 2: Create TmuxService with TDD tests

**Files:**
- Create: `Tests/TmuxServiceTests.swift`
- Create: `Liney/Services/Tmux/TmuxService.swift`

- [ ] **Step 1: Write the failing tests**

```swift
//
//  TmuxServiceTests.swift
//  LineyTests
//
//  Author: everettjf
//

import XCTest
@testable import Liney

final class TmuxServiceTests: XCTestCase {

    // MARK: - Session parsing

    func testParseSessionsFromTypicalOutput() {
        let output = "dev-server\t1\t3\nmonitoring\t0\t2\nold-task\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].name, "dev-server")
        XCTAssertEqual(sessions[0].isAttached, true)
        XCTAssertEqual(sessions[0].windowCount, 3)
        XCTAssertEqual(sessions[1].name, "monitoring")
        XCTAssertEqual(sessions[1].isAttached, false)
        XCTAssertEqual(sessions[1].windowCount, 2)
        XCTAssertEqual(sessions[2].name, "old-task")
        XCTAssertEqual(sessions[2].isAttached, false)
        XCTAssertEqual(sessions[2].windowCount, 1)
    }

    func testParseSessionsFromEmptyOutput() {
        let sessions = TmuxService.parseSessions(from: "")
        XCTAssertEqual(sessions, [])
    }

    func testParseSessionsSkipsMalformedLines() {
        let output = "good-session\t1\t2\nbadline\n\nanother-good\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].name, "good-session")
        XCTAssertEqual(sessions[1].name, "another-good")
    }

    // MARK: - Window parsing

    func testParseWindowsFromTypicalOutput() {
        let output = "0\teditor\t0\n1\tserver\t1\n2\tlogs\t0\n"
        let windows = TmuxService.parseWindows(from: output, sessionName: "dev-server")
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows[0].sessionName, "dev-server")
        XCTAssertEqual(windows[0].index, 0)
        XCTAssertEqual(windows[0].name, "editor")
        XCTAssertEqual(windows[0].isActive, false)
        XCTAssertEqual(windows[1].index, 1)
        XCTAssertEqual(windows[1].name, "server")
        XCTAssertEqual(windows[1].isActive, true)
        XCTAssertEqual(windows[2].index, 2)
        XCTAssertEqual(windows[2].name, "logs")
        XCTAssertEqual(windows[2].isActive, false)
    }

    func testParseWindowsFromEmptyOutput() {
        let windows = TmuxService.parseWindows(from: "", sessionName: "test")
        XCTAssertEqual(windows, [])
    }

    func testParseWindowsSkipsMalformedLines() {
        let output = "0\teditor\t1\nbadline\n2\tlogs\t0\n"
        let windows = TmuxService.parseWindows(from: output, sessionName: "s")
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].index, 0)
        XCTAssertEqual(windows[1].index, 2)
    }

    // MARK: - Attach command

    func testAttachCommandForSessionAndWindow() {
        let args = TmuxService.attachArguments(session: "dev-server", windowIndex: 1)
        XCTAssertEqual(args, ["-lc", "tmux attach -t dev-server \\; select-window -t 1"])
    }

    func testAttachCommandEscapesSessionName() {
        let args = TmuxService.attachArguments(session: "my session", windowIndex: 0)
        XCTAssertEqual(args, ["-lc", "tmux attach -t 'my session' \\; select-window -t 0"])
    }

    // MARK: - tmux executable path

    func testTmuxExecutablePath() {
        let path = TmuxService.tmuxExecutablePath
        XCTAssertTrue(path == "/usr/bin/env")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test -only-testing:LineyTests/TmuxServiceTests 2>&1 | tail -10`
Expected: BUILD FAILED (TmuxService not defined)

- [ ] **Step 3: Write the implementation**

```swift
//
//  TmuxService.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

enum TmuxService {

    static let tmuxExecutablePath = "/usr/bin/env"

    private static let runner = ShellCommandRunner()

    // MARK: - Query

    static func isTmuxAvailable() async -> Bool {
        do {
            let result = try await runner.run(executable: "/usr/bin/env", arguments: ["which", "tmux"])
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    static func listSessions() async throws -> [TmuxSession] {
        let result = try await runTmux(arguments: [
            "list-sessions", "-F", "#{session_name}\t#{session_attached}\t#{session_windows}"
        ])
        return parseSessions(from: result.stdout)
    }

    static func listWindows(session: String) async throws -> [TmuxWindow] {
        let result = try await runTmux(arguments: [
            "list-windows", "-t", session, "-F", "#{window_index}\t#{window_name}\t#{window_active}"
        ])
        return parseWindows(from: result.stdout, sessionName: session)
    }

    // MARK: - Session operations

    static func createSession(name: String) async throws {
        try await runTmux(arguments: ["new-session", "-d", "-s", name])
    }

    static func killSession(name: String) async throws {
        try await runTmux(arguments: ["kill-session", "-t", name])
    }

    static func renameSession(oldName: String, newName: String) async throws {
        try await runTmux(arguments: ["rename-session", "-t", oldName, newName])
    }

    static func detachSession(name: String) async throws {
        try await runTmux(arguments: ["detach-client", "-t", name])
    }

    // MARK: - Window operations

    static func createWindow(session: String, name: String?) async throws {
        var args = ["new-window", "-t", session]
        if let name, !name.isEmpty {
            args += ["-n", name]
        }
        try await runTmux(arguments: args)
    }

    static func killWindow(session: String, index: Int) async throws {
        try await runTmux(arguments: ["kill-window", "-t", "\(session):\(index)"])
    }

    static func renameWindow(session: String, index: Int, newName: String) async throws {
        try await runTmux(arguments: ["rename-window", "-t", "\(session):\(index)", newName])
    }

    static func moveWindow(session: String, index: Int, targetSession: String) async throws {
        try await runTmux(arguments: ["move-window", "-s", "\(session):\(index)", "-t", targetSession])
    }

    // MARK: - Attach helpers

    static func attachArguments(session: String, windowIndex: Int) -> [String] {
        let escapedSession = session.contains(" ") ? "'\(session)'" : session
        return ["-lc", "tmux attach -t \(escapedSession) \\; select-window -t \(windowIndex)"]
    }

    // MARK: - Parsing

    static func parseSessions(from output: String) -> [TmuxSession] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let attached = Int(parts[1]),
                  let windowCount = Int(parts[2]) else { return nil }
            return TmuxSession(name: parts[0], isAttached: attached > 0, windowCount: windowCount)
        }
    }

    static func parseWindows(from output: String, sessionName: String) -> [TmuxWindow] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let index = Int(parts[0]),
                  let active = Int(parts[2]) else { return nil }
            return TmuxWindow(sessionName: sessionName, index: index, name: parts[1], isActive: active > 0)
        }
    }

    // MARK: - Internal

    @discardableResult
    private static func runTmux(arguments: [String]) async throws -> ShellCommandResult {
        let result: ShellCommandResult
        do {
            result = try await runner.run(executable: "/usr/bin/env", arguments: ["tmux"] + arguments)
        } catch {
            throw TmuxError.commandFailed(error.localizedDescription)
        }
        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("no server running") || message.contains("not found") {
                throw TmuxError.notInstalled
            }
            throw TmuxError.commandFailed(message)
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test -only-testing:LineyTests/TmuxServiceTests 2>&1 | tail -15`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Tests/TmuxServiceTests.swift Liney/Services/Tmux/TmuxService.swift
git commit -m "feat: add TmuxService CLI wrapper with TDD tests"
```

---

### Task 3: Create TmuxPanelStore

**Files:**
- Create: `Liney/App/TmuxPanelStore.swift`

- [ ] **Step 1: Create the store**

```swift
//
//  TmuxPanelStore.swift
//  Liney
//
//  Author: everettjf
//

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

    // MARK: - Session operations

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

    // MARK: - Window operations

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

    // MARK: - Attach

    func attachConfiguration(session: String, windowIndex: Int) -> SessionBackendConfiguration {
        let shellArgs = TmuxService.attachArguments(session: session, windowIndex: windowIndex)
        let defaultShell = LocalShellSessionConfiguration.default
        return .local(shellPath: defaultShell.shellPath, shellArguments: shellArgs)
    }

    // MARK: - Private

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
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Liney/App/TmuxPanelStore.swift
git commit -m "feat: add TmuxPanelStore for panel state management"
```

---

### Task 4: Add tmuxPanelCollapsed to AppSettings

**Files:**
- Modify: `Liney/Domain/AppSettings.swift`

- [ ] **Step 1: Add the property to AppSettings**

Read `Liney/Domain/AppSettings.swift`. Find the `AppSettings` struct and its stored properties (around line 244-263). Add after the last sidebar-related boolean (`sidebarShowsWorktreeBadges`):

```swift
    var tmuxPanelCollapsed: Bool
```

Then find the `init` method (around line 280+). Add the parameter with default `true`:

```swift
    tmuxPanelCollapsed: Bool = true,
```

Make sure to add it in the corresponding position in both the property list and the init parameter list.

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Liney/Domain/AppSettings.swift
git commit -m "feat: add tmuxPanelCollapsed setting to AppSettings"
```

---

### Task 5: Create TmuxPanelView

**Files:**
- Create: `Liney/UI/Sidebar/TmuxPanelView.swift`

- [ ] **Step 1: Create the view file**

```swift
//
//  TmuxPanelView.swift
//  Liney
//
//  Author: everettjf
//

import SwiftUI

struct TmuxPanelView: View {
    @ObservedObject var store: TmuxPanelStore
    @Binding var isCollapsed: Bool
    let onAttachWindow: (SessionBackendConfiguration) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LineyTheme.border)
                .frame(height: 1)

            TmuxPanelHeaderView(
                store: store,
                isCollapsed: $isCollapsed
            )

            if !isCollapsed {
                TmuxPanelContentView(
                    store: store,
                    onAttachWindow: onAttachWindow
                )
            }
        }
        .background(LineyTheme.sidebarBackground)
        .onAppear {
            store.checkAvailability()
        }
    }
}

// MARK: - Header

private struct TmuxPanelHeaderView: View {
    @ObservedObject var store: TmuxPanelStore
    @Binding var isCollapsed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() } }) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    .frame(width: 12)
            }
            .buttonStyle(.plain)

            Text("TMUX")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LineyTheme.mutedText)

            if !store.sessions.isEmpty {
                Text("\(store.sessions.count)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.15), in: Capsule())
            }

            Spacer()

            if !isCollapsed {
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Button(action: { store.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { store.createSession(name: "new-\(Int.random(in: 100...999))") }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Content

private struct TmuxPanelContentView: View {
    @ObservedObject var store: TmuxPanelStore

    let onAttachWindow: (SessionBackendConfiguration) -> Void

    var body: some View {
        if !store.isAvailable {
            TmuxNotInstalledView()
        } else if let error = store.errorMessage {
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(LineyTheme.danger)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        } else if store.sessions.isEmpty {
            Text("No sessions")
                .font(.system(size: 10))
                .foregroundStyle(LineyTheme.mutedText)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(store.sessions) { session in
                        TmuxSessionRowView(
                            session: session,
                            isExpanded: store.expandedSessions.contains(session.name),
                            windows: store.windowsBySession[session.name] ?? [],
                            store: store,
                            onAttachWindow: onAttachWindow
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 200)
        }
    }
}

// MARK: - Not Installed

private struct TmuxNotInstalledView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("tmux not installed")
                .font(.system(size: 10))
                .foregroundStyle(LineyTheme.mutedText)
            Text("brew install tmux")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LineyTheme.mutedText.opacity(0.6))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row

private struct TmuxSessionRowView: View {
    let session: TmuxSession
    let isExpanded: Bool
    let windows: [TmuxWindow]
    let store: TmuxPanelStore
    let onAttachWindow: (SessionBackendConfiguration) -> Void
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showKillConfirm = false

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                Button(action: { store.toggleSession(session.name) }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                        .frame(width: 10)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(session.isAttached ? LineyTheme.success : LineyTheme.mutedText.opacity(0.4))
                    .frame(width: 6, height: 6)

                if isRenaming {
                    TextField("name", text: $renameText, onCommit: {
                        if !renameText.isEmpty && renameText != session.name {
                            store.renameSession(oldName: session.name, newName: renameText)
                        }
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(session.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(session.isAttached ? Color.white.opacity(0.9) : LineyTheme.mutedText)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            renameText = session.name
                            isRenaming = true
                        }
                }

                Spacer()

                if isHovering && !isRenaming {
                    HStack(spacing: 3) {
                        TmuxInlineButton(systemName: "plus") {
                            store.createWindow(session: session.name, name: nil)
                        }
                        TmuxInlineButton(systemName: "pencil") {
                            renameText = session.name
                            isRenaming = true
                        }
                        if session.isAttached {
                            TmuxInlineButton(systemName: "eject") {
                                store.detachSession(name: session.name)
                            }
                        }
                        TmuxInlineButton(systemName: "xmark", isDanger: true) {
                            showKillConfirm = true
                        }
                    }
                } else if !isHovering {
                    Text("\(session.windowCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(LineyTheme.mutedText.opacity(0.6))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovering ? Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.08) : .clear)
            )
            .onHover { isHovering = $0 }
            .alert("Kill session '\(session.name)'?", isPresented: $showKillConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Kill", role: .destructive) {
                    store.killSession(name: session.name)
                }
            } message: {
                Text("This will terminate all windows and processes in this session.")
            }

            if isExpanded {
                ForEach(windows) { window in
                    TmuxWindowRowView(
                        window: window,
                        store: store,
                        onAttach: {
                            let config = store.attachConfiguration(session: window.sessionName, windowIndex: window.index)
                            onAttachWindow(config)
                        },
                        allSessions: store.sessions
                    )
                }
            }
        }
    }
}

// MARK: - Window Row

private struct TmuxWindowRowView: View {
    let window: TmuxWindow
    let store: TmuxPanelStore
    let onAttach: () -> Void
    let allSessions: [TmuxSession]
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showMoveMenu = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.6))

            if isRenaming {
                TextField("name", text: $renameText, onCommit: {
                    if !renameText.isEmpty && renameText != window.name {
                        store.renameWindow(session: window.sessionName, index: window.index, newName: renameText)
                    }
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .onExitCommand { isRenaming = false }
            } else {
                Text("\(window.index): \(window.name)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(window.isActive ? Color.white.opacity(0.85) : LineyTheme.mutedText)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        renameText = window.name
                        isRenaming = true
                    }
                    .onTapGesture(count: 1) {
                        onAttach()
                    }
            }

            if window.isActive && !isHovering {
                Text("*")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
            }

            Spacer()

            if isHovering && !isRenaming {
                HStack(spacing: 2) {
                    TmuxInlineButton(systemName: "arrow.up.right", size: 7) {
                        onAttach()
                    }
                    TmuxInlineButton(systemName: "pencil", size: 7) {
                        renameText = window.name
                        isRenaming = true
                    }
                    TmuxInlineButton(systemName: "arrow.left.arrow.right", size: 7) {
                        showMoveMenu = true
                    }
                    .popover(isPresented: $showMoveMenu) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Move to:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(LineyTheme.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.top, 6)
                            ForEach(allSessions.filter({ $0.name != window.sessionName })) { target in
                                Button(target.name) {
                                    store.moveWindow(session: window.sessionName, index: window.index, targetSession: target.name)
                                    showMoveMenu = false
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(minWidth: 120)
                    }
                    TmuxInlineButton(systemName: "xmark", size: 7, isDanger: true) {
                        store.killWindow(session: window.sessionName, index: window.index)
                    }
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHovering ? Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.06) : .clear)
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Inline Button

private struct TmuxInlineButton: View {
    let systemName: String
    var size: CGFloat = 8
    var isDanger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 15, height: 15)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDanger ? LineyTheme.danger : LineyTheme.secondaryText)
        .background(
            (isDanger ? LineyTheme.danger.opacity(0.1) : Color.white.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 3, style: .continuous)
        )
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Liney/UI/Sidebar/TmuxPanelView.swift
git commit -m "feat: add TmuxPanelView with session/window tree and hover actions"
```

---

### Task 6: Integrate TmuxPanelStore into WorkspaceStore

**Files:**
- Modify: `Liney/App/WorkspaceStore.swift`

- [ ] **Step 1: Add TmuxPanelStore property**

Read `Liney/App/WorkspaceStore.swift`. Find the class definition and its `@Published` properties near the top. Add after the last published property:

```swift
    let tmuxPanelStore = TmuxPanelStore()
```

- [ ] **Step 2: Add createTmuxPane method**

Find the existing `createSession(in:backendConfiguration:workingDirectory:)` method (around line 1195). Add after it:

```swift
    func createTmuxPane(in workspace: WorkspaceModel, configuration: SessionBackendConfiguration) {
        let snapshot = PaneSnapshot(
            id: UUID(),
            preferredWorkingDirectory: workspace.activeWorktreePath,
            preferredEngine: .libghosttyPreferred,
            backendConfiguration: configuration
        )
        workspace.createPane(
            splitAxis: workspace.layout == nil ? nil : .vertical,
            snapshot: snapshot
        )
        persist()
    }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Liney/App/WorkspaceStore.swift
git commit -m "feat: add TmuxPanelStore and createTmuxPane to WorkspaceStore"
```

---

### Task 7: Embed TmuxPanelView in SidebarOutlineContainerView

**Files:**
- Modify: `Liney/UI/Sidebar/WorkspaceSidebarView.swift:1036-1098`

- [ ] **Step 1: Add tmux panel hosting view to SidebarOutlineContainerView**

Read `Liney/UI/Sidebar/WorkspaceSidebarView.swift` at line 1036. The `SidebarOutlineContainerView` class has a `footerHostingView` at the bottom. We need to insert a `tmuxPanelHostingView` between the scroll view and the footer.

Add a new property after `footerHostingView` (line 1040):

```swift
    private let tmuxPanelHostingView = NSHostingView(rootView: AnyView(EmptyView()))
```

In the `override init(frame:)` method, add the tmux panel view and update constraints. After `addSubview(footerHostingView)` (line 1077), add:

```swift
        tmuxPanelHostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tmuxPanelHostingView)
```

Replace the existing constraint block (lines 1084-1098) with:

```swift
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tmuxPanelHostingView.topAnchor),

            tmuxPanelHostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tmuxPanelHostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tmuxPanelHostingView.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor),

            footerSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            footerSeparator.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor, constant: -4),

            footerHostingView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            footerHostingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            footerHostingView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            footerHostingView.heightAnchor.constraint(equalToConstant: 34),
        ])
```

- [ ] **Step 2: Add a method to set the tmux panel content**

After the existing `setOpenRepositoryAction` method (line 1115), add:

```swift
    func setTmuxPanelContent(_ view: AnyView) {
        tmuxPanelHostingView.rootView = view
    }
```

- [ ] **Step 3: Wire the tmux panel in WorkspaceSidebarCoordinator**

Find the `WorkspaceSidebarCoordinator` class (starts around line 130). In the `attach(_ container:)` method (around line 150), after the existing setup, add the tmux panel wiring. Read the method to find where `setOpenRepositoryAction` is called -- this is likely in `updateNSView` of `WorkspaceOutlineSidebar` (line 80). Add tmux panel setup alongside it.

In `WorkspaceOutlineSidebar.updateNSView` (around line 78), after `nsView.setOpenRepositoryAction(onOpenRepository)` (line 80), add:

```swift
        nsView.setTmuxPanelContent(AnyView(
            TmuxPanelView(
                store: store.tmuxPanelStore,
                isCollapsed: Binding(
                    get: { store.appSettings.tmuxPanelCollapsed },
                    set: { newValue in
                        store.appSettings.tmuxPanelCollapsed = newValue
                        store.persist()
                    }
                ),
                onAttachWindow: { configuration in
                    guard let workspace = store.workspaces.first(where: { $0.id == store.selectedWorkspaceID }) else { return }
                    store.createTmuxPane(in: workspace, configuration: configuration)
                }
            )
            .environmentObject(store)
        ))
```

- [ ] **Step 4: Build and run all tests**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test 2>&1 | tail -10`
Expected: BUILD SUCCEEDED, all tests pass

- [ ] **Step 5: Commit**

```bash
git add Liney/UI/Sidebar/WorkspaceSidebarView.swift
git commit -m "feat: embed TmuxPanelView in sidebar outline container"
```

---

### Task 8: Final integration test and manual verification

**Files:**
- No new files

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 2: Build and run the app for manual verification**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Then: `open ~/Library/Developer/Xcode/DerivedData/Liney-*/Build/Products/Debug/Liney.app`

Manual verification checklist:
1. Sidebar shows "TMUX" panel at the bottom (collapsed by default)
2. Click to expand -- shows session list or "tmux not installed" / "No sessions"
3. If tmux is available: click refresh to load sessions
4. Expand a session to see windows
5. Hover on session row -- action buttons appear (+ ✎ ⏏ ✕)
6. Hover on window row -- action buttons appear (↗ ✎ ↔ ✕)
7. Click a window -- new terminal pane opens attached to that tmux session/window
8. Create a new session via + button in header
9. Rename a session via double-click or ✎ button
10. Kill a session via ✕ button (shows confirmation)
11. Panel collapsed state persists across app restart
12. "Open Folder" button still visible below the tmux panel
