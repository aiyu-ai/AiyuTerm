# Phase 3: 事件映射层（AgentHookEvent -> AgentSessionStatus）

> 预计工作量: 1 天
> 前置依赖: Phase 1 + Phase 2
> 后续阶段: Phase 4

## 目标

在 CodeIsland 的丰富事件模型和 AiyuTerm 的简化 `AgentSessionStatus` 之间搭建翻译层：

1. 实现 `AgentHookEventMapper`：把 `AgentHookEvent` 转成对 `WorkspaceModel.setAgentStatus()` 的调用
2. 实现 `session_id -> worktreePath` 解析
3. 让 Phase 2 的 `AgentHookServer` 通过 `AgentHookReceiver` 协议回调 `AgentHookEventMapper`
4. **本阶段仍与老的 `AgentStatusFilePoller` 共存**，新旧两套并行运行

## 核心挑战

| 挑战 | 说明 |
|------|------|
| 模型不对齐 | CodeIsland 13 个事件 + 5 种状态 vs AiyuTerm 5 个 `AgentSessionStatus` |
| 维度不对齐 | CodeIsland 按 `sessionId` 组织 vs AiyuTerm 按 `worktreePath` 组织 |
| 并发安全 | 事件来自 socket 接收队列，状态更新必须在 `@MainActor` |
| 兜底路径 | 解析失败时不能让整个管道停摆 |

## 状态映射表

来自 `reduceEvent` 的最终 `AgentStatus`（`SessionSnapshot.swift:354-551`）映射到 `AgentSessionStatus`（`WorkspaceModels.swift:1438-1488`）：

| CodeIsland `AgentHookStatus` | AiyuTerm `AgentSessionStatus` | 说明 |
|------------------------------|------------------------------|------|
| `.idle` | `.taskCompleted`（仅在 `Stop` 事件后）/ `.none`（其他场合）| Stop 事件映射为 completed |
| `.processing` | `.working` | Agent 在处理用户输入 |
| `.running` | `.working` | Agent 在调用工具 |
| `.waitingApproval` | `.permissionNeeded` | 权限请求 |
| `.waitingQuestion` | `.permissionNeeded`（Phase 3 简化）/ 新 case（Phase 6） | Phase 6 再细分 |

**特殊事件处理**:

| 事件 | 行为 |
|------|------|
| `UserPromptSubmit` | 清零 `unreadCompletedWorktrees` 和 `unreadPermissionWorktrees`，状态 -> `.working` |
| `Stop` | 状态 -> `.taskCompleted`，设置 `unreadCompletedWorktrees` |
| `StopFailure` / `PostToolUseFailure` | 状态 -> `.error` |
| `Notification`(permission) | 状态 -> `.permissionNeeded`，设置 `unreadPermissionWorktrees` |
| `PreToolUse` / `PostToolUse` | 状态维持 `.working` |
| `PreCompact` | 忽略 |
| `SessionStart` / `SessionEnd` | 仅记录 cwd 映射，不改 badge |
| `SubagentStart` / `SubagentStop` | 维持 `.working`（Phase 3 简化）|

## session_id -> worktreePath 解析

### 三级兜底策略

```swift
func resolveWorktreePath(for event: AgentHookEvent) -> String? {
    // Level 1: direct cwd lookup
    if let cwd = event.rawJSON["cwd"] as? String,
       let worktree = findWorktree(matchingPath: cwd) {
        return worktree.path
    }

    // Level 2: tmux_pane / tty reverse lookup
    if let tmuxPane = event.rawJSON["_tmux_pane"] as? String,
       let worktree = findWorktree(byTmuxPane: tmuxPane) {
        return worktree.path
    }
    if let tty = event.rawJSON["_tty"] as? String,
       let worktree = findWorktree(byTty: tty) {
        return worktree.path
    }

    // Level 3: fallback to cached session->worktree map
    if let sessionId = event.sessionId,
       let cached = sessionWorktreeCache[sessionId] {
        return cached
    }

    return nil
}

private func findWorktree(matchingPath path: String) -> WorktreeModel? {
    // Walk up path until it matches any known worktree
    var candidate = path
    while !candidate.isEmpty {
        for workspace in workspacesProvider() {
            for worktree in workspace.worktrees where worktree.path == candidate {
                return worktree
            }
        }
        candidate = (candidate as NSString).deletingLastPathComponent
        if candidate == "/" { break }
    }
    return nil
}
```

### tmux_pane / tty 反查

要求 AiyuTerm 的 `ShellSession` 暴露两个新属性：

- `ShellSession.tmuxPane: String?`（当前已有，`ShellSession.swift` 的 tmux 集成代码中）
- `ShellSession.ttyPath: String?`（**可能需要新增**）

**待验证**: 在 Phase 3 开工前用 Grep 确认 `ShellSession.swift` 是否已经暴露 ttyPath，如果没有，需要在 ShellSession 创建时从 Ghostty 的 PTY 信息里拿到 tty 路径并缓存。

## 详细步骤

### 3.1 新建 `AgentHookEventMapper.swift`

```swift
import Foundation
import os.log

/// Maps enriched hook events coming from the socket into calls on the
/// existing AiyuTerm WorkspaceModel state surface.
///
/// This is the translation layer between CodeIsland's rich event model
/// and AiyuTerm's simplified AgentSessionStatus enum.
@MainActor
final class AgentHookEventMapper: AgentHookReceiver {
    private let workspacesProvider: () -> [WorkspaceModel]
    private var sessionWorktreeCache: [String: String] = [:]
    private var snapshots: [String: AgentSessionSnapshot] = [:]

    private static let logger = Logger(
        subsystem: "com.aiyuai.aiyuterm",
        category: "AgentHookEventMapper"
    )

    init(workspacesProvider: @escaping () -> [WorkspaceModel]) {
        self.workspacesProvider = workspacesProvider
    }

    // MARK: - AgentHookReceiver

    func handleEvent(_ event: AgentHookEvent) {
        guard let sessionId = event.sessionId else {
            Self.logger.debug("Event without session_id: \(event.eventName)")
            return
        }

        // Update snapshot via shared reducer
        _ = reduceAgentHookEvent(
            sessions: &snapshots,
            event: event,
            maxHistory: 50
        )

        // Resolve worktree and derive AiyuTerm status
        guard let worktreePath = resolveWorktreePath(for: event) else {
            Self.logger.debug("Cannot resolve worktree for session \(sessionId)")
            return
        }

        // Cache the mapping for later events that don't carry cwd
        sessionWorktreeCache[sessionId] = worktreePath

        guard let workspace = findWorkspace(containing: worktreePath) else {
            return
        }

        let status = deriveStatus(from: event, snapshot: snapshots[sessionId])
        applyStatus(status, to: workspace, worktreePath: worktreePath, event: event)
    }

    func handlePermissionRequest(_ event: AgentHookEvent) async -> Data {
        // Phase 3: simplified — always deny (Phase 6 will add real UI)
        handleEvent(event)
        return Self.denyResponse
    }

    func handleAskUserQuestion(_ event: AgentHookEvent) async -> Data {
        handleEvent(event)
        return Self.denyResponse
    }

    func handleQuestion(_ event: AgentHookEvent) async -> Data {
        handleEvent(event)
        return Self.denyResponse
    }

    func handlePeerDisconnect(sessionId: String) {
        // Clear any dangling waiting state
        if var snapshot = snapshots[sessionId] {
            if snapshot.status == .waitingApproval || snapshot.status == .waitingQuestion {
                snapshot.status = .processing
                snapshots[sessionId] = snapshot
            }
        }
    }

    // MARK: - Status derivation

    private func deriveStatus(
        from event: AgentHookEvent,
        snapshot: AgentSessionSnapshot?
    ) -> AgentSessionStatus {
        let normalized = AgentHookEventNormalizer.normalize(event.eventName)

        switch normalized {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse",
             "SubagentStart", "SubagentStop", "AfterAgentResponse":
            return .working

        case "Stop":
            return .taskCompleted

        case "StopFailure", "PostToolUseFailure":
            return .error

        case "PermissionRequest":
            return .permissionNeeded

        case "Notification":
            // Check for permission prompt keywords
            if let type = event.rawJSON["notification_type"] as? String,
               type == "permission_prompt" || type == "idle_prompt" {
                return .permissionNeeded
            }
            if AgentQuestionPayload.from(event: event) != nil {
                return .permissionNeeded
            }
            return .working

        case "SessionStart", "SessionEnd", "PreCompact":
            return .none

        default:
            return .working
        }
    }

    private func applyStatus(
        _ status: AgentSessionStatus,
        to workspace: WorkspaceModel,
        worktreePath: String,
        event: AgentHookEvent
    ) {
        switch status {
        case .taskCompleted:
            workspace.markCompletionUnread(forWorktreePath: worktreePath)

        case .permissionNeeded:
            workspace.markPermissionUnread(forWorktreePath: worktreePath)

        case .working:
            workspace.markCompletionRead(forWorktreePath: worktreePath)
            workspace.markPermissionRead(forWorktreePath: worktreePath)

        default:
            break
        }

        if status != .none {
            workspace.setAgentStatus(status, forWorktreePath: worktreePath)
        }
    }

    // MARK: - Lookup helpers

    private func resolveWorktreePath(for event: AgentHookEvent) -> String? {
        if let cwd = event.rawJSON["cwd"] as? String,
           let path = walkUpToMatchWorktree(from: cwd) {
            return path
        }
        // TODO Phase 3.5: tmux_pane + tty reverse lookup
        if let sessionId = event.sessionId,
           let cached = sessionWorktreeCache[sessionId] {
            return cached
        }
        return nil
    }

    private func walkUpToMatchWorktree(from path: String) -> String? {
        var candidate = path
        while !candidate.isEmpty, candidate != "/" {
            for workspace in workspacesProvider() {
                for worktree in workspace.worktrees where worktree.path == candidate {
                    return worktree.path
                }
            }
            candidate = (candidate as NSString).deletingLastPathComponent
        }
        return nil
    }

    private func findWorkspace(containing worktreePath: String) -> WorkspaceModel? {
        for workspace in workspacesProvider() {
            if workspace.worktrees.contains(where: { $0.path == worktreePath }) {
                return workspace
            }
        }
        return nil
    }

    private static let denyResponse: Data = {
        """
        {"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}
        """.data(using: .utf8)!
    }()
}
```

### 3.2 接线到 `WorkspaceStore`

修改 `WorkspaceStore.swift` 在 `ensureAgentFilePoller()` 旁边新增 `ensureAgentHookServer()`：

```swift
private lazy var agentHookMapper = AgentHookEventMapper(
    workspacesProvider: { [weak self] in self?.workspaces ?? [] }
)

private func ensureAgentHookServer() {
    guard agentHookServer.receiver == nil else { return }
    agentHookServer.attach(receiver: agentHookMapper)
    do {
        try agentHookServer.start()
    } catch {
        print("AgentHookServer start failed: \(error)")
    }
}
```

在 `loadIfNeeded()` 和 `selectWorkspace()` 里都调用一次 `ensureAgentHookServer()`。

### 3.3 单元测试

新建 `Tests/Agent/AgentHookEventMapperTests.swift`:

```swift
final class AgentHookEventMapperTests: XCTestCase {
    var workspace: WorkspaceModel!
    var mapper: AgentHookEventMapper!

    override func setUp() async throws {
        workspace = makeTestWorkspace(worktreePaths: ["/tmp/repo-a", "/tmp/repo-b"])
        mapper = AgentHookEventMapper(workspacesProvider: { [self.workspace!] })
    }

    func testUserPromptSubmitSetsWorking() async {
        let event = makeEvent(name: "UserPromptSubmit", sessionId: "s1", cwd: "/tmp/repo-a")
        await MainActor.run { mapper.handleEvent(event) }
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: "/tmp/repo-a"), .working)
    }

    func testStopMarksUnreadCompleted() async {
        let start = makeEvent(name: "UserPromptSubmit", sessionId: "s1", cwd: "/tmp/repo-a")
        let stop = makeEvent(name: "Stop", sessionId: "s1", cwd: "/tmp/repo-a")
        await MainActor.run {
            mapper.handleEvent(start)
            mapper.handleEvent(stop)
        }
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: "/tmp/repo-a"), .taskCompleted)
        XCTAssertTrue(workspace.unreadCompletedWorktrees.contains("/tmp/repo-a"))
    }

    func testCwdResolutionWalksUpToWorktree() async {
        let event = makeEvent(
            name: "PreToolUse",
            sessionId: "s2",
            cwd: "/tmp/repo-a/src/subdir"
        )
        await MainActor.run { mapper.handleEvent(event) }
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: "/tmp/repo-a"), .working)
    }

    func testUnknownCwdFallsBackToCachedSession() async {
        let first = makeEvent(name: "UserPromptSubmit", sessionId: "s3", cwd: "/tmp/repo-b")
        let second = makeEvent(name: "PreToolUse", sessionId: "s3", cwd: nil) // no cwd
        await MainActor.run {
            mapper.handleEvent(first)
            mapper.handleEvent(second)
        }
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: "/tmp/repo-b"), .working)
    }

    func testPermissionNotificationMarksBadge() async {
        let event = makeEvent(
            name: "Notification",
            sessionId: "s4",
            cwd: "/tmp/repo-a",
            extra: ["notification_type": "permission_prompt"]
        )
        await MainActor.run { mapper.handleEvent(event) }
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: "/tmp/repo-a"), .permissionNeeded)
        XCTAssertTrue(workspace.unreadPermissionWorktrees.contains("/tmp/repo-a"))
    }

    func testStopFailureSetsError() async {
        let event = makeEvent(name: "StopFailure", sessionId: "s5", cwd: "/tmp/repo-a")
        await MainActor.run { mapper.handleEvent(event) }
        XCTAssertEqual(workspace.agentStatus(forWorktreePath: "/tmp/repo-a"), .error)
    }
}
```

需要一个测试帮助函数 `makeEvent(name:sessionId:cwd:extra:)` 构造 `AgentHookEvent`。

## 验收检查清单

- [ ] `AgentHookEventMapper.swift` 编译通过
- [ ] `WorkspaceStore.swift` 里同时启动 file poller 和 hook server
- [ ] 5 个单元测试全部通过
- [ ] 手工测试：用 nc 发送 `UserPromptSubmit`，sidebar badge 亮起转圈
- [ ] 手工测试：发送 `Stop`，badge 变绿色脉冲
- [ ] 手工测试：发送 `Notification`(permission_prompt)，badge 变粉色脉冲
- [ ] 新旧两套状态源并存时不会相互覆盖导致闪烁（看日志判断）

## 回滚步骤

1. 删除 `AgentHookEventMapper.swift`
2. 回滚 `WorkspaceStore.swift` 的 `ensureAgentHookServer` 改动
3. 删除测试文件

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| 新旧状态源冲突导致 badge 闪烁 | 高 | 日志每次状态变更的 source（file/hook），对比排查 |
| cwd 不在任何 worktree 下 | 中 | 记录 debug 日志，不 crash |
| `snapshots` 字典无限增长 | 低 | Phase 7 加过期清理（idle > 1h 的 session 移除）|
| 并发 handleEvent 乱序 | 低 | `@MainActor` 串行化 |

## 数据库/文件副作用

**无**。本阶段只是事件转译和状态更新，不写磁盘。
