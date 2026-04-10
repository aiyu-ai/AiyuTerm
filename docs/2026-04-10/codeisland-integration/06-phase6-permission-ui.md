# Phase 6: 权限审批 + 问答 UI

> 预计工作量: 2-3 天
> 前置依赖: Phase 1-5
> 后续阶段: Phase 7

## 目标

让用户不离开 AiyuTerm 侧边栏就能完成 Agent 的权限审批和问答响应：

1. 扩展 `AgentSessionStatus`：新增 `.awaitingApproval(PermissionRequest)` 和 `.awaitingAnswer(QuestionRequest)` 两个 case（或用 associated value）
2. 引入 `AgentPermissionQueue` 和 `AgentQuestionQueue` 管理阻塞请求
3. 侧边栏新增气泡 UI：展示工具名 + Approve / Deny / Approve Always 按钮
4. 响应后通过 `async` continuation 把 JSON 结果发回 bridge
5. 支持 Claude 的 `AskUserQuestion` 结构化选项

## 数据流

```
Claude Code 触发 PermissionRequest hook
        │
        ▼
aiyuterm-hook-bridge [stdin]
        │ Unix socket (blocking mode: 86400s timeout)
        ▼
AgentHookServer.processRequest
        │ withCheckedContinuation
        ▼
AgentHookEventMapper.handlePermissionRequest (async)
        │ enqueue PermissionRequest
        ▼
WorkspaceStore: update worktree status to .awaitingApproval
        │
        ▼
Sidebar badge -> render permission bubble (new SwiftUI view)
        │
        ▼
User clicks "Approve"
        │
        ▼
AgentPermissionQueue.resolve(sessionId, .allow)
        │
        ▼
Continuation resumes with JSON: {"hookSpecificOutput":...,"decision":{"behavior":"allow"}}
        │
        ▼
AgentHookServer.sendResponse
        │ Unix socket write
        ▼
Bridge -> stdout -> Claude Code continues
```

## 详细步骤

### 6.1 扩展 `AgentSessionStatus`

**不破坏现有 5 个 case**，使用**新增 optional 字段**策略：

```swift
// WorkspaceModels.swift: existing enum
enum AgentSessionStatus: Equatable {
    case none
    case working
    case permissionNeeded      // 保持，泛化为"有 pending 请求"
    case taskCompleted
    case error
}
```

在 `WorkspaceRuntime.swift` 新增并行的请求队列：

```swift
@Published private(set) var pendingPermissionRequests: [String: AgentPermissionRequest] = [:]
// key = worktreePath
@Published private(set) var pendingQuestionRequests: [String: AgentQuestionRequest] = [:]
```

`AgentPermissionRequest`:
```swift
struct AgentPermissionRequest: Identifiable {
    let id: UUID
    let sessionId: String
    let toolName: String
    let toolDescription: String?
    let toolInput: [String: Any]?
    let timestamp: Date
    let continuation: CheckedContinuation<Data, Never>
}
```

### 6.2 改造 `AgentHookEventMapper`

Phase 3 的实现是直接 deny，Phase 6 改为真正排队：

```swift
func handlePermissionRequest(_ event: AgentHookEvent) async -> Data {
    return await withCheckedContinuation { continuation in
        guard let worktreePath = resolveWorktreePath(for: event),
              let workspace = findWorkspace(containing: worktreePath),
              let sessionId = event.sessionId else {
            continuation.resume(returning: Self.denyResponse)
            return
        }

        let request = AgentPermissionRequest(
            id: UUID(),
            sessionId: sessionId,
            toolName: event.toolName ?? "Unknown",
            toolDescription: event.toolDescription,
            toolInput: event.toolInput,
            timestamp: Date(),
            continuation: continuation
        )
        workspace.enqueuePermissionRequest(request, forWorktreePath: worktreePath)
        workspace.setAgentStatus(.permissionNeeded, forWorktreePath: worktreePath)
    }
}
```

`workspace.enqueuePermissionRequest` 内部：
- 加入 `pendingPermissionRequests`
- `objectWillChange.send()` 通知 UI

### 6.3 响应 API

`WorkspaceStore` 暴露两个方法供 UI 调用：

```swift
@MainActor
func approvePermission(forWorktreePath path: String, mode: ApprovalMode) {
    guard let workspace = workspace(containing: path),
          let request = workspace.pendingPermissionRequests[path] else { return }
    let response = buildPermissionResponse(request: request, decision: .allow, mode: mode)
    request.continuation.resume(returning: response)
    workspace.removePermissionRequest(forWorktreePath: path)
}

@MainActor
func denyPermission(forWorktreePath path: String) {
    guard let workspace = workspace(containing: path),
          let request = workspace.pendingPermissionRequests[path] else { return }
    request.continuation.resume(returning: Self.denyResponse)
    workspace.removePermissionRequest(forWorktreePath: path)
}

enum ApprovalMode {
    case once
    case always  // add to updatedPermissions list
}
```

响应 JSON 构造参考 `AppState.swift:811-828`：

```swift
private func buildPermissionResponse(
    request: AgentPermissionRequest,
    decision: PermissionDecision,
    mode: ApprovalMode
) -> Data {
    switch decision {
    case .allow:
        if mode == .always {
            let rule: [String: Any] = [
                "tool_name": request.toolName,
                // ... (match CodeIsland's rule format)
            ]
            let payload: [String: Any] = [
                "hookSpecificOutput": [
                    "hookEventName": "PermissionRequest",
                    "decision": ["behavior": "allow"],
                    "updatedPermissions": [rule]
                ]
            ]
            return try! JSONSerialization.data(withJSONObject: payload)
        } else {
            return Self.allowOnceResponse
        }
    case .deny:
        return Self.denyResponse
    }
}

private static let allowOnceResponse = """
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}
""".data(using: .utf8)!

private static let denyResponse = """
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}
""".data(using: .utf8)!
```

### 6.4 Sidebar 气泡 UI

新建 `AgentPermissionBubbleView.swift`:

```swift
struct AgentPermissionBubbleView: View {
    let request: AgentPermissionRequest
    let onApproveOnce: () -> Void
    let onApproveAlways: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.pink)
                Text("Permission needed")
                    .font(.headline)
                Spacer()
            }

            if let desc = request.toolDescription {
                Text(desc)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            } else {
                Text(request.toolName)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack(spacing: 6) {
                Button("Deny", action: onDeny)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Allow", action: onApproveOnce)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Always", action: onApproveAlways)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(radius: 4)
        )
    }
}
```

### 6.5 集成到 `WorkspaceSidebarView`

在现有的 worktree row 下方，当 `pendingPermissionRequests[worktree.path]` 非空时显示气泡：

```swift
if let request = workspace.pendingPermissionRequests[worktree.path] {
    AgentPermissionBubbleView(
        request: request,
        onApproveOnce: {
            store.approvePermission(forWorktreePath: worktree.path, mode: .once)
        },
        onApproveAlways: {
            store.approvePermission(forWorktreePath: worktree.path, mode: .always)
        },
        onDeny: {
            store.denyPermission(forWorktreePath: worktree.path)
        }
    )
    .padding(.leading, 24)
    .transition(.move(edge: .top).combined(with: .opacity))
}
```

### 6.6 AskUserQuestion 支持

结构化问答使用类似机制，但 UI 是一个选项列表：

```swift
struct AgentQuestionBubbleView: View {
    let request: AgentQuestionRequest
    let onAnswer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundColor(.blue)
                Text(request.payload.header ?? "Question")
                    .font(.headline)
            }

            Text(request.payload.question)
                .font(.caption)

            if let options = request.payload.options {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(options, id: \.self) { option in
                        Button(option) { onAnswer(option) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(radius: 4)
        )
    }
}
```

### 6.7 超时和取消

- Claude Code 侧 timeout 是 86400s（`ConfigInstaller.swift:66, 70`），基本等于无超时
- AiyuTerm 侧不额外超时，用户什么时候响应什么时候回
- **取消路径**: 用户关闭 worktree / 退出 app 时，`handlePeerDisconnect` 自动 resume continuation 为 deny

### 6.8 单元测试

```swift
func testPermissionRequestEnqueues() async {
    let event = makePermissionEvent(session: "s1", cwd: "/tmp/repo-a", tool: "Bash", command: "rm -rf /")
    Task {
        _ = await mapper.handlePermissionRequest(event)
    }
    try? await Task.sleep(for: .milliseconds(50))
    XCTAssertEqual(workspace.pendingPermissionRequests["/tmp/repo-a"]?.toolName, "Bash")
}

func testApproveResumesContinuationWithAllow() async {
    // Start a permission flow
    // Approve
    // Verify the returned Data is the "allow" JSON
}

func testDenyResumesContinuationWithDeny() async { ... }
func testDisconnectCancelsRequests() async { ... }
```

## 验收检查清单

- [ ] `AgentPermissionRequest` 和 `AgentQuestionRequest` 类型定义完成
- [ ] `WorkspaceModel` 有 `pendingPermissionRequests` / `pendingQuestionRequests`
- [ ] `WorkspaceStore.approvePermission/denyPermission` 方法可用
- [ ] `AgentPermissionBubbleView` 渲染正确
- [ ] `AgentQuestionBubbleView` 渲染正确
- [ ] 手工测试：Claude Code 触发 `Bash` 工具调用，sidebar 出现气泡
- [ ] 点击 Approve，Claude Code 继续执行
- [ ] 点击 Deny，Claude Code 收到拒绝
- [ ] 点击 "Allow Always"，后续同类工具调用自动通过
- [ ] 关闭 AiyuTerm 时 pending continuation 自动 resolve 为 deny
- [ ] `AskUserQuestion` 触发时显示选项列表
- [ ] 选中一个选项后 Claude 继续

## 回滚步骤

1. 删除 `AgentPermissionBubbleView.swift` / `AgentQuestionBubbleView.swift`
2. 删除 `WorkspaceModel` 的两个 pending 字段
3. `AgentHookEventMapper.handlePermissionRequest` 恢复为 Phase 3 的直接 deny

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| Continuation 被 double-resume | 高 | 用标志位保护；全部 `@MainActor` 串行化 |
| 气泡挡住其他 UI | 中 | UI 评审；气泡可折叠 |
| 批量权限请求队列爆炸 | 中 | 同一时间只展示当前请求，其他排队 |
| 用户响应慢导致 Claude 超时 | 低 | Claude timeout 是 86400s，基本不会触发 |
| `AskUserQuestion` JSON 结构变化 | 中 | 参照 `AppState.swift:887-970` 的解析逻辑，兼容多种格式 |

## 数据库/文件副作用

**无**。本阶段只是 UI 和内存态管理，不写磁盘。
