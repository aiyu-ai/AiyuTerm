# Agent Status Badge Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign sidebar agent status badges with lifecycle animations: working spinner, task completed pulse/shrink, permission needed pulse, error pulse.

**Architecture:** Extend `AgentSessionStatus` enum with `.working` case, add `AgentBadgeDisplayState` for view-layer presentation, track read/unread completions on `WorkspaceModel`, rewrite `AgentStatusOverlayBadge` view with spinner + pulse + spring-shrink animations.

**Tech Stack:** Swift, SwiftUI, AppKit (NSOutlineView host), XCTest

**Spec:** `docs/superpowers/specs/2026-04-06-agent-status-badge-redesign.md`

---

### Task 1: Extend AgentSessionStatus enum and add AgentBadgeDisplayState

**Files:**
- Modify: `AiyuTerm/Domain/WorkspaceModels.swift:1433-1455`
- Test: `Tests/AgentSessionStatusAggregationTests.swift`

- [ ] **Step 1: Write failing tests for new priority and properties**

Add to `Tests/AgentSessionStatusAggregationTests.swift` after line 41:

```swift
    func testHighestPriorityStatusReturnsCompletedOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .taskCompleted]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .taskCompleted)
    }

    func testHighestPriorityStatusReturnsErrorOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .error]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .error)
    }

    func testHighestPriorityStatusReturnsPermissionOverWorking() {
        let statuses: [AgentSessionStatus] = [.working, .permissionNeeded]
        let result = AgentSessionStatus.highestPriority(in: statuses)
        XCTAssertEqual(result, .permissionNeeded)
    }

    func testWorkingIsNotUserDismissible() {
        XCTAssertFalse(AgentSessionStatus.working.isUserDismissible)
    }

    func testNoneIsNotUserDismissible() {
        XCTAssertFalse(AgentSessionStatus.none.isUserDismissible)
    }

    func testTaskCompletedIsUserDismissible() {
        XCTAssertTrue(AgentSessionStatus.taskCompleted.isUserDismissible)
    }

    func testPermissionNeededIsUserDismissible() {
        XCTAssertTrue(AgentSessionStatus.permissionNeeded.isUserDismissible)
    }

    func testErrorIsUserDismissible() {
        XCTAssertTrue(AgentSessionStatus.error.isUserDismissible)
    }

    func testWorkingIsVisible() {
        XCTAssertTrue(AgentSessionStatus.working.isVisible)
    }

    func testNoneIsNotVisible() {
        XCTAssertFalse(AgentSessionStatus.none.isVisible)
    }

    func testBadgeDisplayStateSpinnerForWorking() {
        XCTAssertEqual(AgentSessionStatus.working.badgeDisplayState(isUnread: false), .spinner)
    }

    func testBadgeDisplayStateCompletedUnreadWhenUnread() {
        XCTAssertEqual(AgentSessionStatus.taskCompleted.badgeDisplayState(isUnread: true), .completedUnread)
    }

    func testBadgeDisplayStateCompletedReadWhenRead() {
        XCTAssertEqual(AgentSessionStatus.taskCompleted.badgeDisplayState(isUnread: false), .completedRead)
    }

    func testBadgeDisplayStateHiddenForNone() {
        XCTAssertEqual(AgentSessionStatus.none.badgeDisplayState(isUnread: false), .hidden)
    }

    func testBadgeDisplayStatePermissionNeeded() {
        XCTAssertEqual(AgentSessionStatus.permissionNeeded.badgeDisplayState(isUnread: false), .permissionNeeded)
    }

    func testBadgeDisplayStateError() {
        XCTAssertEqual(AgentSessionStatus.error.badgeDisplayState(isUnread: false), .error)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentSessionStatusAggregationTests 2>&1 | tail -20`
Expected: FAIL -- `.working` does not exist

- [ ] **Step 3: Implement the enum extension and new types**

Replace the entire `AgentSessionStatus` enum in `AiyuTerm/Domain/WorkspaceModels.swift:1433-1455` with:

```swift
enum AgentSessionStatus: Equatable {
    case none
    case working
    case permissionNeeded
    case taskCompleted
    case error

    var isActionable: Bool {
        self != .none
    }

    /// Whether the badge should be displayed in the sidebar.
    var isVisible: Bool {
        self != .none
    }

    /// Whether user interaction (keyboard/notification) should auto-dismiss this status.
    /// Working status must NOT be auto-dismissed by keyboard activity.
    var isUserDismissible: Bool {
        switch self {
        case .permissionNeeded, .taskCompleted, .error: return true
        case .none, .working: return false
        }
    }

    private var priority: Int {
        switch self {
        case .permissionNeeded: return 4
        case .error: return 3
        case .taskCompleted: return 2
        case .working: return 1
        case .none: return 0
        }
    }

    static func highestPriority(in statuses: [AgentSessionStatus]) -> AgentSessionStatus {
        statuses.max(by: { $0.priority < $1.priority }) ?? .none
    }

    func badgeDisplayState(isUnread: Bool) -> AgentBadgeDisplayState {
        switch self {
        case .none: return .hidden
        case .working: return .spinner
        case .taskCompleted: return isUnread ? .completedUnread : .completedRead
        case .permissionNeeded: return .permissionNeeded
        case .error: return .error
        }
    }
}

enum AgentBadgeDisplayState: Equatable {
    case hidden
    case spinner
    case completedUnread
    case completedRead
    case error
    case permissionNeeded
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test -only-testing:AiyuTermTests/AgentSessionStatusAggregationTests 2>&1 | tail -20`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add AiyuTerm/Domain/WorkspaceModels.swift Tests/AgentSessionStatusAggregationTests.swift
git commit -m "feat: add .working status, AgentBadgeDisplayState, isUserDismissible property"
```

---

### Task 2: Add agentGlowColor .working case and rewrite AgentStatusOverlayBadge

**Files:**
- Modify: `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift:1893-1900` (agentGlowColor)
- Modify: `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift:1929-1931` (badge call site in SidebarItemIconView)
- Modify: `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift:2055-2144` (AgentStatusOverlayBadge rewrite)
- Modify: `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift:1721-1722` (WorkspaceRowContent badge call)
- Modify: `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift:1834-1835` (WorktreeRowContent badge call)

- [ ] **Step 1: Add .working case to agentGlowColor**

In `WorkspaceSidebarView.swift`, replace lines 1893-1900:

```swift
    private var agentGlowColor: Color? {
        switch agentStatus {
        case .permissionNeeded: return Color(red: 1.0, green: 0.18, blue: 0.57)
        case .taskCompleted: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .error: return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .working: return Color(red: 0.31, green: 0.63, blue: 1.0)
        case .none: return nil
        }
    }
```

- [ ] **Step 2: Rewrite AgentStatusOverlayBadge**

Replace the entire `AgentStatusOverlayBadge` struct (lines 2055-2144) with:

```swift
struct AgentStatusOverlayBadge: View {
    let displayState: AgentBadgeDisplayState
    let size: CGFloat
    @State private var isPulsing = false
    @State private var rotation: Double = 0

    private var badgeSize: CGFloat {
        max(10, size * 0.6)
    }

    private var spinnerSize: CGFloat {
        max(10, size * 0.48)
    }

    private var badgeScale: CGFloat {
        switch displayState {
        case .completedRead: return 0.444
        case .completedUnread: return isPulsing ? 1.25 : 1.0
        case .permissionNeeded: return isPulsing ? 1.3 : 1.0
        case .error: return isPulsing ? 1.2 : 1.0
        case .spinner, .hidden: return 1.0
        }
    }

    private var iconOpacity: Double {
        displayState == .completedRead ? 0 : 1
    }

    private var symbolName: String {
        switch displayState {
        case .completedUnread, .completedRead: return "checkmark"
        case .permissionNeeded: return "exclamationmark"
        case .error: return "xmark"
        case .spinner, .hidden: return ""
        }
    }

    private var gradientColors: [Color] {
        switch displayState {
        case .completedUnread, .completedRead:
            return [Color(red: 0.19, green: 0.82, blue: 0.35), Color(red: 0.15, green: 0.66, blue: 0.27)]
        case .permissionNeeded:
            return [Color(red: 1.0, green: 0.18, blue: 0.57), Color(red: 0.90, green: 0.0, blue: 0.31)]
        case .error:
            return [Color(red: 1.0, green: 0.27, blue: 0.23), Color(red: 0.84, green: 0.18, blue: 0.13)]
        case .spinner, .hidden:
            return [.clear, .clear]
        }
    }

    private var glowColor: Color {
        gradientColors[0]
    }

    private var glowOpacity: Double {
        switch displayState {
        case .completedUnread: return isPulsing ? 0.7 : 0.3
        case .permissionNeeded: return isPulsing ? 0.8 : 0.3
        case .error: return isPulsing ? 0.6 : 0.3
        case .completedRead: return 0.3
        case .spinner, .hidden: return 0
        }
    }

    private var spinnerColor: Color {
        Color(red: 0.31, green: 0.63, blue: 1.0)
    }

    var body: some View {
        Group {
            if displayState == .spinner {
                spinnerBody
            } else {
                badgeBody
            }
        }
        // .drawingGroup() flattens into Metal texture for animation perf in NSOutlineView
        .drawingGroup()
    }

    private var spinnerBody: some View {
        ZStack {
            Circle()
                .stroke(spinnerColor.opacity(0.25), lineWidth: 2)
                .frame(width: spinnerSize, height: spinnerSize)
            Circle()
                .trim(from: 0, to: 0.65)
                .stroke(spinnerColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: spinnerSize, height: spinnerSize)
                .rotationEffect(Angle(degrees: rotation))
        }
        .onAppear {
            rotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onChange(of: displayState) { _, newValue in
            guard newValue == .spinner else { return }
            rotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private var badgeBody: some View {
        ZStack {
            // Glow layer: blurred circle behind badge (cheaper than .shadow)
            Circle()
                .fill(glowColor)
                .frame(width: badgeSize, height: badgeSize)
                .blur(radius: badgeSize * 0.4)
                .opacity(glowOpacity)

            // Badge circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: symbolName)
                        .font(.system(size: max(5, badgeSize * 0.45), weight: .black))
                        .foregroundStyle(.white)
                        .opacity(iconOpacity)
                )
                .overlay(
                    Circle()
                        .stroke(AiyuTermTheme.sidebarBackground, lineWidth: size > 18 ? 2 : 1.5)
                )
                .frame(width: badgeSize, height: badgeSize)
        }
        .scaleEffect(badgeScale)
        .onAppear {
            startPulseIfNeeded()
        }
        .onChange(of: displayState) { _, _ in
            isPulsing = false
            startPulseIfNeeded()
        }
    }

    private func startPulseIfNeeded() {
        let duration: Double
        switch displayState {
        case .permissionNeeded: duration = 1.0
        case .completedUnread: duration = 1.5
        case .error: duration = 1.2
        default: return
        }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}
```

- [ ] **Step 3: Update WorkspaceRowContent badge call (line 1715-1722)**

Replace `WorkspaceSidebarView.swift` lines 1715-1722:

```swift
    private var workspaceAgentStatus: AgentSessionStatus {
        workspace.aggregatedAgentStatus
    }

    private var workspaceBadgeDisplayState: AgentBadgeDisplayState {
        let hasUnread = workspace.worktrees.contains { workspace.unreadCompletedWorktrees.contains($0.path) }
        return workspaceAgentStatus.badgeDisplayState(isUnread: hasUnread)
    }

    var body: some View {
        HStack(spacing: 8 * uiScale) {
            if workspaceBadgeDisplayState != .hidden {
                AgentStatusOverlayBadge(displayState: workspaceBadgeDisplayState, size: 16 * uiScale)
            }
```

- [ ] **Step 4: Update WorktreeRowContent badge call (lines 1828-1835)**

Replace lines 1828-1835:

```swift
    private var worktreeAgentStatus: AgentSessionStatus {
        workspace.agentStatus(forWorktreePath: worktree.path)
    }

    private var worktreeBadgeDisplayState: AgentBadgeDisplayState {
        worktreeAgentStatus.badgeDisplayState(isUnread: workspace.unreadCompletedWorktrees.contains(worktree.path))
    }

    var body: some View {
        HStack(spacing: 8 * uiScale) {
            if worktreeBadgeDisplayState != .hidden {
                AgentStatusOverlayBadge(displayState: worktreeBadgeDisplayState, size: 12 * uiScale)
            }
```

- [ ] **Step 5: Update SidebarItemIconView badge call (lines 1929-1931)**

Replace lines 1929-1931:

```swift
            if agentStatus.isVisible {
                AgentStatusOverlayBadge(displayState: agentStatus.badgeDisplayState(isUnread: true), size: size)
                    .offset(x: size * 0.15, y: size * 0.15)
            }
```

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift
git commit -m "feat: rewrite AgentStatusOverlayBadge with spinner, pulse, and spring-shrink animations"
```

---

### Task 3: Add clearErrorStatus and unread tracking to runtime layer

**Files:**
- Modify: `AiyuTerm/Services/Terminal/WorkspaceSessionController.swift:199-203`
- Modify: `AiyuTerm/Domain/WorkspaceRuntime.swift:412-421,567-571`

- [ ] **Step 1: Add clearErrorStatus to WorkspaceSessionController**

Add after `clearAgentStatus` method at `WorkspaceSessionController.swift:203`:

```swift
    func clearErrorStatus(using path: String) {
        for session in sessions.values where session.isUsing(pathPrefix: path) && session.agentStatus == .error {
            session.agentStatus = .none
        }
    }
```

- [ ] **Step 2: Add unreadCompletedWorktrees and methods to WorkspaceRuntime**

Add to `WorkspaceModel` class in `WorkspaceRuntime.swift`, after `clearAgentStatus` method (line 571):

```swift
    @Published private(set) var unreadCompletedWorktrees: Set<String> = []

    func markCompletionUnread(forWorktreePath path: String) {
        unreadCompletedWorktrees.insert(path)
    }

    func markCompletionRead(forWorktreePath path: String) {
        unreadCompletedWorktrees.remove(path)
    }

    func clearErrorStatus(forWorktreePath path: String) {
        worktreeControllers[path]?.values.forEach { controller in
            controller.clearErrorStatus(using: path)
        }
    }
```

- [ ] **Step 3: Update switchToWorktree**

Replace `WorkspaceRuntime.swift` line 415 (`clearAgentStatus(forWorktreePath: path)`) with:

```swift
        markCompletionRead(forWorktreePath: path)
        clearErrorStatus(forWorktreePath: path)
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add AiyuTerm/Services/Terminal/WorkspaceSessionController.swift AiyuTerm/Domain/WorkspaceRuntime.swift
git commit -m "feat: add clearErrorStatus, unread tracking, and selective clear on worktree switch"
```

---

### Task 4: Update status parsers to handle "working"

**Files:**
- Modify: `AiyuTerm/Services/Terminal/AgentStatusFilePoller.swift:56-69`
- Modify: `AiyuTerm/Services/Tmux/TmuxAgentStatusPoller.swift:107-112`

- [ ] **Step 1: Update AgentStatusFilePoller parser**

Replace `AgentStatusFilePoller.swift` lines 65-69 (the switch statement in `parseStatusValue`):

```swift
        switch statusString {
        case "working": return .working
        case "permission": return .permissionNeeded
        case "completed": return .taskCompleted
        case "error": return .error
        default: return .none
        }
```

- [ ] **Step 2: Add unread tracking to the poll loop**

Replace `AgentStatusFilePoller.swift` lines 48-52 (inside the `poll()` method) with:

```swift
            guard status != .none else { continue }
            if status == .taskCompleted {
                workspace.markCompletionUnread(forWorktreePath: workspace.activeWorktreePath)
            }
            if status == .working {
                workspace.markCompletionRead(forWorktreePath: workspace.activeWorktreePath)
            }
            for session in workspace.sessionController.sessions.values where session.agentStatus != status {
                session.agentStatus = status
            }
```

- [ ] **Step 3: Update TmuxAgentStatusPoller parser**

Replace `TmuxAgentStatusPoller.swift` lines 107-112 (the switch statement in `parseHookValue`):

```swift
        switch statusString {
        case "working": return .working
        case "permission": return .permissionNeeded
        case "completed": return .taskCompleted
        case "error": return .error
        default: return .none
        }
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add AiyuTerm/Services/Terminal/AgentStatusFilePoller.swift AiyuTerm/Services/Tmux/TmuxAgentStatusPoller.swift
git commit -m "feat: parse 'working' status in file poller and tmux poller, track unread completions"
```

---

### Task 5: Fix ShellSession auto-clear to use isUserDismissible

**Files:**
- Modify: `AiyuTerm/Services/Terminal/ShellSession.swift:183,188,192`

- [ ] **Step 1: Replace isActionable with isUserDismissible in notification handler**

In `ShellSession.swift` line 183, replace:

```swift
                } else if self.agentStatus.isActionable && title.localizedCaseInsensitiveContains("claude") {
```

With:

```swift
                } else if self.agentStatus.isUserDismissible && title.localizedCaseInsensitiveContains("claude") {
```

- [ ] **Step 2: Replace isActionable with isUserDismissible in keyboard handler**

In `ShellSession.swift` line 188, replace:

```swift
                guard let self, self.agentStatus.isActionable else { return }
```

With:

```swift
                guard let self, self.agentStatus.isUserDismissible else { return }
```

In `ShellSession.swift` line 192, replace:

```swift
                    guard let self, self.agentStatus.isActionable else { return }
```

With:

```swift
                    guard let self, self.agentStatus.isUserDismissible else { return }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AiyuTerm/Services/Terminal/ShellSession.swift
git commit -m "fix: use isUserDismissible to prevent keyboard activity clearing working spinner"
```

---

### Task 6: Update WorkspaceStore select/open logic

**Files:**
- Modify: `AiyuTerm/App/WorkspaceStore.swift:746-752,2139-2147`

- [ ] **Step 1: Update selectWorkspace**

Replace `WorkspaceStore.swift` lines 746-752:

```swift
    func selectWorkspace(_ workspace: WorkspaceModel) {
        selectedWorkspaceID = workspace.id
        workspace.bootstrapIfNeeded()
        workspace.markCompletionRead(forWorktreePath: workspace.activeWorktreePath)
        workspace.clearErrorStatus(forWorktreePath: workspace.activeWorktreePath)
        ensureAgentFilePoller()
        persist()
    }
```

- [ ] **Step 2: Update openWorktree**

Replace `WorkspaceStore.swift` lines 2139-2147:

```swift
    private func openWorktree(_ workspace: WorkspaceModel, worktree: WorktreeModel, requestedAction: PendingWorktreeAction) {
        guard workspace.activeWorktreePath != worktree.path else {
            perform(requestedAction, in: workspace)
            selectWorkspace(workspace)
            return
        }
        activateWorktree(workspace: workspace, worktree: worktree, restartRunning: false, requestedAction: requestedAction)
    }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AiyuTerm/App/WorkspaceStore.swift
git commit -m "feat: selective clear on workspace select - mark completion read, clear error only"
```

---

### Task 7: Update TmuxPanelView badge call

**Files:**
- Modify: `AiyuTerm/UI/Sidebar/TmuxPanelView.swift:203-205`

- [ ] **Step 1: Update TmuxSessionRow badge**

Replace `TmuxPanelView.swift` lines 203-205:

```swift
            let tmuxBadgeDisplayState = agentStatus.badgeDisplayState(isUnread: true)
            if tmuxBadgeDisplayState != .hidden {
                AgentStatusOverlayBadge(displayState: tmuxBadgeDisplayState, size: 16)
            }
```

- [ ] **Step 2: Build full project**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AiyuTerm/UI/Sidebar/TmuxPanelView.swift
git commit -m "feat: update TmuxPanelView badge to use AgentBadgeDisplayState"
```

---

### Task 8: Run all tests and build debug app

**Files:** None (verification only)

- [ ] **Step 1: Run all tests**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -destination 'platform=macOS' test 2>&1 | tail -30`
Expected: All tests PASS

- [ ] **Step 2: Build debug app**

Run: `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Open debug build for manual testing**

Run: `open $(find ~/Library/Developer/Xcode/DerivedData/AiyuTerm-*/Build/Products/Debug/AiyuTerm.app -maxdepth 0 2>/dev/null | head -1)`

Manual verification checklist:
1. Add a workspace, run `echo 'working:'$(date +%s) > /tmp/aiyuterm-agent-status/$(echo -n $PWD | md5 | head -c 16)` -- verify blue spinner appears
2. Run `echo 'completed:'$(date +%s) > /tmp/aiyuterm-agent-status/$(echo -n $PWD | md5 | head -c 16)` -- verify large green pulse badge
3. Click the workspace in sidebar -- verify badge shrinks to small green dot
4. Run `echo 'permission:'$(date +%s) > /tmp/aiyuterm-agent-status/$(echo -n $PWD | md5 | head -c 16)` -- verify large red pulse badge
5. Type in terminal during working state -- verify spinner is NOT dismissed

- [ ] **Step 4: Final commit if any test fixes needed**

```bash
git add -A
git commit -m "test: verify agent status badge redesign implementation"
```
