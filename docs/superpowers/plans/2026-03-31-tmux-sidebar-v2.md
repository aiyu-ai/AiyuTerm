# Tmux Sidebar Split (v2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign tmux integration from a small bottom panel to a split sidebar with workspace-style session rendering, stable IDs, app-level attach coordinator, and agent status badges.

**Architecture:** Refactor v1 code in-place. Update `TmuxSession` model with `sessionID`. Replace `SidebarOutlineContainerView` flat layout with `NSSplitView`. Rewrite `TmuxPanelView` as workspace-style session list. Add `TmuxAttachCoordinator` singleton for cross-window dedup. Wire agent status badges via coordinator → ShellSession mapping.

**Tech Stack:** Swift, AppKit (NSSplitView), SwiftUI, XCTest, tmux CLI

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `Liney/Services/Tmux/TmuxModels.swift` | Add sessionID, remove TmuxWindow, add name validation |
| Modify | `Liney/Services/Tmux/TmuxService.swift` | Update parsing for sessionID, remove window methods, update attach to use -lc |
| Modify | `Tests/TmuxServiceTests.swift` | Update parsing tests, add name validation tests, remove window tests |
| Create | `Liney/App/TmuxAttachCoordinator.swift` | App-level singleton for cross-window attach tracking |
| Create | `Tests/TmuxAttachCoordinatorTests.swift` | Coordinator register/unregister/lookup tests |
| Modify | `Liney/App/TmuxPanelStore.swift` | Remove window state, use sessionID, integrate coordinator |
| Modify | `Liney/Domain/AppSettings.swift` | Add tmuxSidebarSplitRatio |
| Modify | `Liney/UI/Sidebar/TmuxPanelView.swift` | Rewrite as workspace-style session list |
| Modify | `Liney/UI/Sidebar/WorkspaceSidebarView.swift` | Replace flat layout with NSSplitView |
| Modify | `Liney/App/WorkspaceStore.swift` | Wire attach through coordinator |

---

### Task 1: Update TmuxModels with sessionID and name validation

**Files:**
- Modify: `Liney/Services/Tmux/TmuxModels.swift`

- [ ] **Step 1: Rewrite TmuxModels.swift**

Replace the entire file content:

```swift
//
//  TmuxModels.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

struct TmuxSession: Identifiable, Equatable {
    let sessionID: String
    let name: String
    let isAttached: Bool
    let windowCount: Int
    var id: String { sessionID }
}

enum TmuxError: LocalizedError {
    case notInstalled
    case noServerRunning
    case commandFailed(String)
    case parseError(String)
    case invalidSessionName(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "tmux is not installed"
        case .noServerRunning:
            return "No tmux server running"
        case .commandFailed(let message):
            return "tmux command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse tmux output: \(message)"
        case .invalidSessionName(let name):
            return "Invalid session name: \(name). Only alphanumeric, dash, underscore, and dot allowed."
        }
    }
}

enum TmuxSessionNameValidator {
    static func isValid(_ name: String) -> Bool {
        let pattern = "^[a-zA-Z0-9._-]+$"
        return !name.isEmpty && name.range(of: pattern, options: .regularExpression) != nil
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Note: Build will show errors because other files reference the old `TmuxSession` (missing `sessionID`) and `TmuxWindow`. These will be fixed in subsequent tasks.

- [ ] **Step 3: Commit**

```bash
git add Liney/Services/Tmux/TmuxModels.swift
git commit -m "refactor: update TmuxSession with sessionID, remove TmuxWindow, add name validator"
```

---

### Task 2: Update TmuxService and tests for sessionID

**Files:**
- Modify: `Liney/Services/Tmux/TmuxService.swift`
- Modify: `Tests/TmuxServiceTests.swift`

- [ ] **Step 1: Rewrite TmuxService.swift**

Replace the entire file:

```swift
//
//  TmuxService.swift
//  Liney
//
//  Author: wuwenrui
//

import Foundation

enum TmuxService {

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
        do {
            let result = try await runTmux(arguments: [
                "list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_attached}\t#{session_windows}"
            ])
            return parseSessions(from: result.stdout)
        } catch TmuxError.noServerRunning {
            return []
        }
    }

    // MARK: - Session operations

    static func createSession(name: String) async throws {
        guard TmuxSessionNameValidator.isValid(name) else {
            throw TmuxError.invalidSessionName(name)
        }
        try await runTmux(arguments: ["new-session", "-d", "-s", name])
    }

    static func killSession(sessionID: String) async throws {
        try await runTmux(arguments: ["kill-session", "-t", sessionID])
    }

    static func renameSession(sessionID: String, newName: String) async throws {
        guard TmuxSessionNameValidator.isValid(newName) else {
            throw TmuxError.invalidSessionName(newName)
        }
        try await runTmux(arguments: ["rename-session", "-t", sessionID, newName])
    }

    static func detachSession(sessionID: String) async throws {
        try await runTmux(arguments: ["detach-client", "-t", sessionID])
    }

    // MARK: - Attach

    static func attachArguments(sessionName: String) -> [String] {
        ["-lc", "tmux attach -t \(sessionName)"]
    }

    // MARK: - Parsing

    static func parseSessions(from output: String) -> [TmuxSession] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 3).map(String.init)
            guard parts.count == 4,
                  let attached = Int(parts[2]),
                  let windowCount = Int(parts[3]) else { return nil }
            return TmuxSession(
                sessionID: parts[0],
                name: parts[1],
                isAttached: attached > 0,
                windowCount: windowCount
            )
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
            if message.contains("no server running") || message.contains("No such file or directory") {
                throw TmuxError.noServerRunning
            }
            if message.contains("not found") {
                throw TmuxError.notInstalled
            }
            throw TmuxError.commandFailed(message)
        }
        return result
    }
}
```

- [ ] **Step 2: Rewrite TmuxServiceTests.swift**

Replace the entire file:

```swift
//
//  TmuxServiceTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

final class TmuxServiceTests: XCTestCase {

    // MARK: - Session parsing with sessionID

    func testParseSessionsWithSessionID() {
        let output = "$0\tdev-server\t1\t3\n$1\tmonitoring\t0\t2\n$2\told-task\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].sessionID, "$0")
        XCTAssertEqual(sessions[0].name, "dev-server")
        XCTAssertEqual(sessions[0].isAttached, true)
        XCTAssertEqual(sessions[0].windowCount, 3)
        XCTAssertEqual(sessions[1].sessionID, "$1")
        XCTAssertEqual(sessions[1].name, "monitoring")
        XCTAssertEqual(sessions[1].isAttached, false)
        XCTAssertEqual(sessions[2].sessionID, "$2")
        XCTAssertEqual(sessions[2].windowCount, 1)
    }

    func testParseSessionsFromEmptyOutput() {
        let sessions = TmuxService.parseSessions(from: "")
        XCTAssertEqual(sessions, [])
    }

    func testParseSessionsSkipsMalformedLines() {
        let output = "$0\tgood\t1\t2\nbadline\n$1\tanother\t0\t1\n"
        let sessions = TmuxService.parseSessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].sessionID, "$0")
        XCTAssertEqual(sessions[1].sessionID, "$1")
    }

    // MARK: - Attach arguments

    func testAttachArgumentsForSession() {
        let args = TmuxService.attachArguments(sessionName: "dev-server")
        XCTAssertEqual(args, ["-lc", "tmux attach -t dev-server"])
    }

    // MARK: - Session name validation

    func testValidSessionNames() {
        XCTAssertTrue(TmuxSessionNameValidator.isValid("my-session"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("dev_server"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("task.123"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("ABC"))
        XCTAssertTrue(TmuxSessionNameValidator.isValid("a"))
    }

    func testInvalidSessionNames() {
        XCTAssertFalse(TmuxSessionNameValidator.isValid(""))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("has space"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("semi;colon"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("pipe|char"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("dollar$sign"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("back`tick"))
        XCTAssertFalse(TmuxSessionNameValidator.isValid("quote\"mark"))
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test -only-testing:LineyTests/TmuxServiceTests 2>&1 | tail -15`
Expected: All 7 tests PASS

- [ ] **Step 4: Commit**

```bash
git add Liney/Services/Tmux/TmuxService.swift Tests/TmuxServiceTests.swift
git commit -m "refactor: update TmuxService for sessionID, remove window methods, add name validation"
```

---

### Task 3: Create TmuxAttachCoordinator with tests

**Files:**
- Create: `Liney/App/TmuxAttachCoordinator.swift`
- Create: `Tests/TmuxAttachCoordinatorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
//
//  TmuxAttachCoordinatorTests.swift
//  LineyTests
//
//  Author: wuwenrui
//

import XCTest
@testable import Liney

@MainActor
final class TmuxAttachCoordinatorTests: XCTestCase {

    func testRegisterAndLookup() {
        let coordinator = TmuxAttachCoordinator()
        let storeID = UUID()
        let shellID = UUID()
        coordinator.register(sessionID: "$0", storeID: storeID, shellSessionID: shellID)
        XCTAssertTrue(coordinator.isAttached("$0"))
        XCTAssertEqual(coordinator.shellSessionID(for: "$0"), shellID)
        XCTAssertEqual(coordinator.storeID(for: "$0"), storeID)
    }

    func testUnregister() {
        let coordinator = TmuxAttachCoordinator()
        coordinator.register(sessionID: "$0", storeID: UUID(), shellSessionID: UUID())
        coordinator.unregister(sessionID: "$0")
        XCTAssertFalse(coordinator.isAttached("$0"))
        XCTAssertNil(coordinator.shellSessionID(for: "$0"))
    }

    func testIsAttachedReturnsFalseForUnknown() {
        let coordinator = TmuxAttachCoordinator()
        XCTAssertFalse(coordinator.isAttached("$99"))
    }

    func testCleanupRemovesStaleEntries() {
        let coordinator = TmuxAttachCoordinator()
        coordinator.register(sessionID: "$0", storeID: UUID(), shellSessionID: UUID())
        coordinator.register(sessionID: "$1", storeID: UUID(), shellSessionID: UUID())
        let activeSessions: Set<String> = ["$1"]
        coordinator.cleanup(activeSessionIDs: activeSessions)
        XCTAssertFalse(coordinator.isAttached("$0"))
        XCTAssertTrue(coordinator.isAttached("$1"))
    }
}
```

- [ ] **Step 2: Write implementation**

```swift
//
//  TmuxAttachCoordinator.swift
//  Liney
//
//  Author: wuwenrui
//

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
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test -only-testing:LineyTests/TmuxAttachCoordinatorTests 2>&1 | tail -10`
Expected: All 4 tests PASS

- [ ] **Step 4: Commit**

```bash
git add Liney/App/TmuxAttachCoordinator.swift Tests/TmuxAttachCoordinatorTests.swift
git commit -m "feat: add TmuxAttachCoordinator with cross-window dedup and stale cleanup"
```

---

### Task 4: Rewrite TmuxPanelStore for session-only with coordinator

**Files:**
- Modify: `Liney/App/TmuxPanelStore.swift`

- [ ] **Step 1: Rewrite TmuxPanelStore.swift**

Replace the entire file:

```swift
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
    @Published var isAvailable: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let coordinator: TmuxAttachCoordinator

    init(coordinator: TmuxAttachCoordinator = .shared) {
        self.coordinator = coordinator
    }

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
        guard let session = sessions.first(where: { $0.sessionID == sessionID }) else { return nil }
        let shellArgs = TmuxService.attachArguments(sessionName: session.name)
        let defaultShell = LocalShellSessionConfiguration.default
        return .local(shellPath: defaultShell.shellPath, shellArguments: shellArgs)
    }

    func sessionName(for sessionID: String) -> String? {
        sessions.first(where: { $0.sessionID == sessionID })?.name
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Note: TmuxPanelView still references old API -- will be fixed in Task 6.

- [ ] **Step 3: Commit**

```bash
git add Liney/App/TmuxPanelStore.swift
git commit -m "refactor: rewrite TmuxPanelStore for session-only with coordinator integration"
```

---

### Task 5: Add tmuxSidebarSplitRatio to AppSettings

**Files:**
- Modify: `Liney/Domain/AppSettings.swift`

- [ ] **Step 1: Add the property**

Read `Liney/Domain/AppSettings.swift`. Find `tmuxPanelCollapsed` property (added in v1). Add after it:

```swift
    var tmuxSidebarSplitRatio: Double
```

Find the `init` method. Add the parameter near `tmuxPanelCollapsed`:

```swift
    tmuxSidebarSplitRatio: Double = 0.6,
```

And the assignment:

```swift
    self.tmuxSidebarSplitRatio = tmuxSidebarSplitRatio
```

If there's a `CodingKeys` enum, add: `case tmuxSidebarSplitRatio`

If there's an `init(from decoder:)`, add decode with default 0.6.

- [ ] **Step 2: Build**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Liney/Domain/AppSettings.swift
git commit -m "feat: add tmuxSidebarSplitRatio to AppSettings"
```

---

### Task 6: Rewrite TmuxPanelView as workspace-style session list

**Files:**
- Modify: `Liney/UI/Sidebar/TmuxPanelView.swift`

- [ ] **Step 1: Rewrite TmuxPanelView.swift**

Replace the entire file. This is a large view. Key changes from v1:
- No more collapse toggle (always visible in split)
- Session rows match workspace row style (18pt icon, two-line label)
- Agent status badge via coordinator lookup
- No window sub-nodes
- Hover actions: rename, detach, kill (session level only)

```swift
//
//  TmuxPanelView.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

struct TmuxPanelView: View {
    @ObservedObject var store: TmuxPanelStore
    let coordinator: TmuxAttachCoordinator
    let onAttachSession: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TmuxHeaderView(store: store)

            if !store.isAvailable {
                TmuxNotInstalledView()
            } else if let error = store.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(LineyTheme.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else if store.sessions.isEmpty && !store.isLoading {
                Text("No sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(LineyTheme.mutedText)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.sessions) { session in
                            TmuxSessionRow(
                                session: session,
                                store: store,
                                coordinator: coordinator,
                                onAttach: { onAttachSession(session.sessionID) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(LineyTheme.sidebarBackground)
        .onAppear {
            store.checkAvailability()
            if store.isAvailable && store.sessions.isEmpty {
                store.refresh()
            }
        }
    }
}

// MARK: - Header

private struct TmuxHeaderView: View {
    @ObservedObject var store: TmuxPanelStore
    @State private var showNewSessionPrompt = false
    @State private var newSessionName = ""

    var body: some View {
        HStack(spacing: 6) {
            Text("TMUX")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))

            if !store.sessions.isEmpty {
                Text("\(store.sessions.count)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.15), in: Capsule())
            }

            Spacer()

            if store.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else {
                Button(action: { store.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                }
                .buttonStyle(.plain)
            }

            Button(action: { showNewSessionPrompt = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNewSessionPrompt) {
                VStack(spacing: 8) {
                    Text("New Session")
                        .font(.system(size: 11, weight: .semibold))
                    TextField("session-name", text: $newSessionName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(width: 160)
                    HStack {
                        Button("Cancel") { showNewSessionPrompt = false }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                        Spacer()
                        Button("Create") {
                            if !newSessionName.isEmpty {
                                store.createSession(name: newSessionName)
                                newSessionName = ""
                                showNewSessionPrompt = false
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                    }
                }
                .padding(12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row

private struct TmuxSessionRow: View {
    let session: TmuxSession
    let store: TmuxPanelStore
    let coordinator: TmuxAttachCoordinator
    let onAttach: () -> Void
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showKillConfirm = false

    private var agentStatus: AgentSessionStatus {
        // Agent status lookup will be wired when ShellSession mapping exists
        .none
    }

    var body: some View {
        HStack(spacing: 8) {
            // Icon with agent status badge
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.43, green: 0.16, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("T")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    )

                if agentStatus.isActionable {
                    AgentStatusOverlayBadge(status: agentStatus, size: 22)
                        .offset(x: 22 * 0.15, y: 22 * 0.15)
                }
            }
            .frame(width: 24, height: 24)

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("name", text: $renameText, onCommit: {
                        if !renameText.isEmpty && renameText != session.name {
                            store.renameSession(sessionID: session.sessionID, newName: renameText)
                        }
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(session.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            renameText = session.name
                            isRenaming = true
                        }
                        .onTapGesture(count: 1) {
                            onAttach()
                        }
                }

                Text("\(session.isAttached ? "attached" : "detached") \u{00B7} \(session.windowCount) win")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering && !isRenaming {
                HStack(spacing: 3) {
                    TmuxInlineButton(systemName: "pencil") {
                        renameText = session.name
                        isRenaming = true
                    }
                    if session.isAttached {
                        TmuxInlineButton(systemName: "eject") {
                            store.detachSession(sessionID: session.sessionID)
                        }
                    }
                    TmuxInlineButton(systemName: "xmark", isDanger: true) {
                        showKillConfirm = true
                    }
                }
            } else {
                Circle()
                    .fill(session.isAttached ? LineyTheme.success : LineyTheme.mutedText.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
        .alert("Kill session '\(session.name)'?", isPresented: $showKillConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Kill", role: .destructive) {
                store.killSession(sessionID: session.sessionID)
            }
        } message: {
            Text("This will terminate all windows and processes.")
        }
    }
}

// MARK: - Inline Button

private struct TmuxInlineButton: View {
    let systemName: String
    var isDanger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDanger ? LineyTheme.danger : LineyTheme.secondaryText)
        .background(
            (isDanger ? LineyTheme.danger.opacity(0.1) : Color.white.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Note: `WorkspaceSidebarView` still references old `TmuxPanelView` API. Fix in next task.

- [ ] **Step 3: Commit**

```bash
git add Liney/UI/Sidebar/TmuxPanelView.swift
git commit -m "refactor: rewrite TmuxPanelView as workspace-style session list"
```

---

### Task 7: Rewrite SidebarOutlineContainerView with NSSplitView

**Files:**
- Modify: `Liney/UI/Sidebar/WorkspaceSidebarView.swift`

This is the most complex task. The current `SidebarOutlineContainerView` uses flat `NSLayoutConstraint` with `scrollView`, `tmuxPanelHostingView`, `footerSeparator`, `footerHostingView`. We replace it with an `NSSplitView` that has two panes: top (workspace outline + footer) and bottom (tmux panel).

- [ ] **Step 1: Rewrite SidebarOutlineContainerView**

Read `Liney/UI/Sidebar/WorkspaceSidebarView.swift`. Find `SidebarOutlineContainerView` (around line 1052). Replace the entire class definition (from `private final class SidebarOutlineContainerView: NSView {` through its closing `}`).

The new class uses `NSSplitView` with a vertical split. The top pane contains the workspace outline scroll view + footer button. The bottom pane contains the tmux panel SwiftUI view.

```swift
private final class SidebarOutlineContainerView: NSView, NSSplitViewDelegate {
    let outlineView = SidebarOutlineView()
    private let splitView = NSSplitView()
    private let topPane = NSView()
    private let bottomPane = NSView()
    private let scrollView = NSScrollView()
    private let contentView = SidebarScrollContentView()
    private let footerHostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let tmuxPanelHostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var splitRatio: CGFloat = 0.6
    var onSplitRatioChange: ((Double) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.delegate = self
        addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Top pane: workspace outline + footer
        topPane.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.rowHeight = 46
        outlineView.indentationPerLevel = 10
        outlineView.floatsGroupRows = false
        outlineView.selectionHighlightStyle = .regular
        outlineView.focusRingType = .none
        outlineView.backgroundColor = .clear
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.allowsMultipleSelection = true
        outlineView.allowsEmptySelection = true
        outlineView.intercellSpacing = NSSize(width: 0, height: 4)
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        outlineView.setDraggingSourceOperationMask([], forLocal: false)
        outlineView.draggingDestinationFeedbackStyle = .gap

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        contentView.outlineView = outlineView
        scrollView.documentView = contentView
        topPane.addSubview(scrollView)

        footerHostingView.translatesAutoresizingMaskIntoConstraints = false
        topPane.addSubview(footerHostingView)

        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator
        footerSeparator.translatesAutoresizingMaskIntoConstraints = false
        topPane.addSubview(footerSeparator)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: topPane.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: topPane.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topPane.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor),

            footerSeparator.leadingAnchor.constraint(equalTo: topPane.leadingAnchor),
            footerSeparator.trailingAnchor.constraint(equalTo: topPane.trailingAnchor),
            footerSeparator.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor, constant: -4),

            footerHostingView.leadingAnchor.constraint(equalTo: topPane.leadingAnchor, constant: 8),
            footerHostingView.trailingAnchor.constraint(equalTo: topPane.trailingAnchor, constant: -8),
            footerHostingView.bottomAnchor.constraint(equalTo: topPane.bottomAnchor, constant: -10),
            footerHostingView.heightAnchor.constraint(equalToConstant: 34),
        ])

        splitView.addSubview(topPane)

        // Bottom pane: tmux panel
        bottomPane.translatesAutoresizingMaskIntoConstraints = false
        tmuxPanelHostingView.translatesAutoresizingMaskIntoConstraints = false
        bottomPane.addSubview(tmuxPanelHostingView)

        NSLayoutConstraint.activate([
            tmuxPanelHostingView.leadingAnchor.constraint(equalTo: bottomPane.leadingAnchor),
            tmuxPanelHostingView.trailingAnchor.constraint(equalTo: bottomPane.trailingAnchor),
            tmuxPanelHostingView.topAnchor.constraint(equalTo: bottomPane.topAnchor),
            tmuxPanelHostingView.bottomAnchor.constraint(equalTo: bottomPane.bottomAnchor),
        ])

        splitView.addSubview(bottomPane)
        splitView.adjustSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateContentLayout()
    }

    func applySplitRatio(_ ratio: CGFloat) {
        splitRatio = max(0.2, min(0.8, ratio))
        let totalHeight = splitView.bounds.height
        guard totalHeight > 0 else { return }
        splitView.setPosition(totalHeight * splitRatio, ofDividerAt: 0)
    }

    func reloadOutlineData() {
        outlineView.reloadData()
        updateContentLayout()
    }

    func setOpenRepositoryAction(_ action: @escaping () -> Void) {
        footerHostingView.rootView = AnyView(SidebarOpenRepositoryRow(action: action))
    }

    func setTmuxPanelContent(_ view: AnyView) {
        tmuxPanelHostingView.rootView = view
    }

    func relayout() {
        updateContentLayout()
    }

    private func updateContentLayout() {
        let visibleWidth = max(scrollView.contentSize.width, topPane.bounds.width)
        let visibleHeight = max(scrollView.contentSize.height, topPane.bounds.height)
        let outlineHeight = outlineContentHeight()
        contentView.outlineHeight = outlineHeight
        let requiredHeight = contentView.requiredHeight(forWidth: visibleWidth)
        contentView.frame = NSRect(
            x: 0,
            y: max(0, visibleHeight - requiredHeight),
            width: visibleWidth,
            height: max(requiredHeight, visibleHeight)
        )
        outlineView.sizeLastColumnToFit()
    }

    private func outlineContentHeight() -> CGFloat {
        var total: CGFloat = 0
        let rowCount = outlineView.numberOfRows
        for row in 0..<rowCount {
            total += outlineView.frameOfCell(atColumn: 0, row: row).height
            total += outlineView.intercellSpacing.height
        }
        return total
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        100
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        splitView.bounds.height - 100
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        let totalHeight = splitView.bounds.height
        guard totalHeight > 0 else { return }
        let newRatio = topPane.bounds.height / totalHeight
        if abs(newRatio - splitRatio) > 0.01 {
            splitRatio = newRatio
            onSplitRatioChange?(Double(newRatio))
        }
    }
}
```

- [ ] **Step 2: Update WorkspaceOutlineSidebar.updateNSView**

Find `WorkspaceOutlineSidebar.updateNSView` (around line 78). Replace the tmux panel content call to use the new API:

```swift
    func updateNSView(_ nsView: SidebarOutlineContainerView, context: Context) {
        context.coordinator.store = store
        nsView.setOpenRepositoryAction(onOpenRepository)
        nsView.onSplitRatioChange = { [weak store] ratio in
            store?.appSettings.tmuxSidebarSplitRatio = ratio
            store?.persist()
        }
        nsView.applySplitRatio(CGFloat(store.appSettings.tmuxSidebarSplitRatio))
        nsView.setTmuxPanelContent(AnyView(
            TmuxPanelView(
                store: store.tmuxPanelStore,
                coordinator: TmuxAttachCoordinator.shared,
                onAttachSession: { sessionID in
                    guard let workspace = store.workspaces.first(where: { $0.id == store.selectedWorkspaceID }) else { return }
                    store.attachTmuxSession(sessionID: sessionID, in: workspace)
                }
            )
        ))
        context.coordinator.apply(
            workspaces: store.sidebarWorkspaces,
            selectedWorkspaceID: store.selectedWorkspaceID,
            query: query
        )
    }
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10`

Note: `store.attachTmuxSession` doesn't exist yet -- fix in next task.

- [ ] **Step 4: Commit**

```bash
git add Liney/UI/Sidebar/WorkspaceSidebarView.swift
git commit -m "refactor: replace flat sidebar layout with NSSplitView for tmux section"
```

---

### Task 8: Wire attach through WorkspaceStore and coordinator

**Files:**
- Modify: `Liney/App/WorkspaceStore.swift`

- [ ] **Step 1: Replace createTmuxPane with attachTmuxSession**

Read `Liney/App/WorkspaceStore.swift`. Find `createTmuxPane` method (added in v1, around line 1214). Replace it with:

```swift
    func attachTmuxSession(sessionID: String, in workspace: WorkspaceModel) {
        let coordinator = TmuxAttachCoordinator.shared

        if coordinator.isAttached(sessionID) {
            if let shellID = coordinator.shellSessionID(for: sessionID),
               let session = workspace.sessionController.sessions[shellID] {
                workspace.sessionController.focus(shellID)
                return
            }
        }

        guard let config = tmuxPanelStore.attachConfiguration(sessionID: sessionID) else { return }

        let snapshot = PaneSnapshot(
            id: UUID(),
            preferredWorkingDirectory: workspace.activeWorktreePath,
            preferredEngine: .libghosttyPreferred,
            backendConfiguration: config
        )
        workspace.createPane(
            splitAxis: workspace.layout == nil ? nil : .vertical,
            snapshot: snapshot
        )

        coordinator.register(sessionID: sessionID, storeID: id, shellSessionID: snapshot.id)
        persist()
    }
```

Note: `WorkspaceStore` needs an `id` property. Check if it already has one. If not, add `let id = UUID()` near the top of the class.

- [ ] **Step 2: Build and run all tests**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test 2>&1 | tail -10`
Expected: BUILD SUCCEEDED, all tests pass

- [ ] **Step 3: Commit**

```bash
git add Liney/App/WorkspaceStore.swift
git commit -m "feat: wire tmux attach through coordinator with dedup"
```

---

### Task 9: Final integration test and manual verification

**Files:**
- No new files

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -destination 'platform=macOS' test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 2: Build and run debug app**

Run: `xcodebuild -project Liney.xcodeproj -scheme Liney -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Then: `open ~/Library/Developer/Xcode/DerivedData/Liney-*/Build/Products/Debug/Liney.app`

Manual verification checklist:
1. Sidebar shows workspace list (top) and TMUX section (bottom) with draggable divider
2. Drag divider to resize -- ratio persists on restart
3. TMUX section shows session count badge and refresh/new buttons
4. Click refresh -- loads tmux sessions (or shows "No sessions" / "tmux not installed")
5. Sessions render with purple "T" icon, name, "attached/detached" label, status dot
6. Hover session row -- rename/detach/kill buttons appear
7. Click session -- terminal opens attached to tmux session in current workspace
8. Click same session again -- focuses existing terminal (no duplicate)
9. Create new session via + button -- validates name, shows error for invalid names
10. Rename session via double-click or pencil button
11. Kill session via xmark button -- shows confirmation
12. "Open Folder" button still visible and functional in top section
