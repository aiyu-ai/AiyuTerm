# Phase 2: Bridge 二进制 + Hook Server

> 预计工作量: 1-2 天
> 前置依赖: Phase 1 完成
> 后续阶段: Phase 3

## 目标

1. 把 CodeIsland 的 `HookServer.swift` 和 `CodeIslandBridge/main.swift` 移植进来
2. 在 Xcode 工程新增独立 Command Line Tool target `AiyuTermHookBridge`
3. 构建 build phase，把 bridge 二进制拷贝到 `AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge`
4. 实现"空回调" `AgentHookServer`：socket 能 accept，事件能解析，但先不更新任何 WorkspaceStore 状态
5. 启动 AiyuTerm 后 `~/.aiyuterm/hook.sock` 存在，nc 手测能收发

## 源文件映射

| 源 | 目标 | 变更 |
|----|------|------|
| `Sources/CodeIsland/HookServer.swift:1-210` | `AiyuTerm/Services/Agent/Transport/AgentHookServer.swift` | 重命名 + 解耦 AppState |
| `Sources/CodeIslandBridge/main.swift:1-338` | `AiyuTermHookBridge/main.swift` | 重命名常量/日志路径/env var |
| 新建 | `AiyuTerm/Services/Agent/Transport/AgentHookReceiver.swift` | 新协议 |

## 详细步骤

### 2.1 新建协议 `AgentHookReceiver.swift`

```swift
import Foundation

/// Protocol implemented by the component that consumes hook events from the
/// AgentHookServer (typically WorkspaceStore).
///
/// Inspired by the AppState callback surface in CodeIsland HookServer.swift:106-160.
@MainActor
protocol AgentHookReceiver: AnyObject {
    /// Fire-and-forget event (UserPromptSubmit, Stop, PreToolUse, PostToolUse, etc.)
    func handleEvent(_ event: AgentHookEvent)

    /// Blocking permission request. Must return a JSON Data response to send
    /// back to the agent CLI. Response format:
    /// {"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow|deny"}}}
    func handlePermissionRequest(_ event: AgentHookEvent) async -> Data

    /// Blocking structured question request (Claude's AskUserQuestion tool).
    func handleAskUserQuestion(_ event: AgentHookEvent) async -> Data

    /// Blocking free-form question from Notification events.
    func handleQuestion(_ event: AgentHookEvent) async -> Data

    /// Signal that the peer connection was closed before we replied.
    /// Used to clean up dangling permission/question queues.
    func handlePeerDisconnect(sessionId: String)
}
```

### 2.2 移植 `AgentHookServer.swift`

基础蓝本是 `HookServer.swift:1-210`。关键改动：

1. **构造函数解耦**：
   ```swift
   @MainActor
   final class AgentHookServer {
       weak var receiver: AgentHookReceiver?
       private var listener: NWListener?
       private var connectionContexts: [ObjectIdentifier: ConnectionContext] = [:]

       private static let logger = Logger(
           subsystem: "com.aiyuai.aiyuterm",
           category: "AgentHookServer"
       )
       
       init() {}

       func attach(receiver: AgentHookReceiver) {
           self.receiver = receiver
       }
   }
   ```

2. **`start()` 方法**（对齐 `HookServer.swift:18-53`）：
   ```swift
   func start() throws {
       let path = AgentHookSocketPath.path

       // Ensure parent dir exists
       let dir = (path as NSString).deletingLastPathComponent
       try? FileManager.default.createDirectory(
           atPath: dir, withIntermediateDirectories: true
       )

       // Unlink stale socket
       unlink(path)

       // Enforce 104-byte sun_path limit
       guard path.utf8.count < 104 else {
           throw AgentHookServerError.socketPathTooLong(path)
       }

       let params = NWParameters()
       params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
       params.requiredLocalEndpoint = NWEndpoint.unix(path: path)

       let listener = try NWListener(using: params)
       self.listener = listener

       listener.newConnectionHandler = { [weak self] connection in
           Task { @MainActor in
               self?.handleConnection(connection)
           }
       }

       listener.stateUpdateHandler = { [weak self] state in
           switch state {
           case .ready:
               chmod(path, 0o700)
               Self.logger.info("AgentHookServer ready at \(path, privacy: .public)")
           case .failed(let err):
               Self.logger.error("AgentHookServer failed: \(err.localizedDescription, privacy: .public)")
           default:
               break
           }
       }

       listener.start(queue: .main)
   }
   ```

3. **事件分发**（对齐 `HookServer.swift:106-160`）：
   保留 `autoApproveTools` 常量但按 AiyuTerm 的安全策略调整（先保守，只放 `TodoRead`、`TodoWrite`、`EnterPlanMode`、`ExitPlanMode`，不放 `TaskCreate` 等 Task 工具，因为 AiyuTerm 还没完全掌握那些工具的语义）。

4. **半关闭检测保留**（`HookServer.swift:172-199`）：
   - 不要简化！保留 `ConnectionContext.responded` 标志和 `stateUpdateHandler` 监听。
   - 这是 CodeIsland 踩过的坑（`HookServer.swift:172-180` 的 comment 写得很清楚）。

5. **错误类型**：
   ```swift
   enum AgentHookServerError: Error {
       case socketPathTooLong(String)
       case startFailed(Error)
   }
   ```

### 2.3 移植 `AiyuTermHookBridge/main.swift`

基础蓝本是 `CodeIslandBridge/main.swift:1-338`。关键改动清单（所有 `codeisland` 相关标识符全部替换）：

| 原字段 (file:line) | 新字段 |
|-------------------|--------|
| `CODEISLAND_SKIP` (`main.swift:194`) | `AIYUTERM_HOOK_SKIP` |
| `CODEISLAND_DEBUG` (`main.swift:73`) | `AIYUTERM_HOOK_DEBUG` |
| `CODEISLAND_SOCKET_PATH` (通过 SocketPath) | `AIYUTERM_HOOK_SOCKET` |
| `/tmp/codeisland-bridge.log` (`main.swift:76`) | `/tmp/aiyuterm-hook-bridge.log` |
| bridge 程序名 | `aiyuterm-hook-bridge` |

其余代码（socket 连接、`sendAll`/`recvAll`、stdin 解析、env 注入、tmux 查询等）**逐字复制**，因为这些逻辑都是 CodeIsland 在生产环境调试出来的稳态实现，不要轻易改。

### 2.4 Xcode 工程新增 bridge target

这是 Phase 2 最容易踩坑的地方。步骤：

1. Xcode 打开 `AiyuTerm.xcodeproj`
2. File -> New -> Target -> macOS -> Command Line Tool
3. Product Name: `aiyuterm-hook-bridge`
4. Language: Swift
5. Team: 同 AiyuTerm
6. 新建后删除自动生成的 `main.swift`，手动把我们移植好的 `AiyuTermHookBridge/main.swift` 添加进去
7. 新 target 的 Build Phases:
   - Compile Sources: `main.swift` + 引用 HookProtocol 的 4 个文件（共享源码方式）
   - **注意**: 不能直接依赖 AiyuTerm target，要让 HookProtocol 的 4 个 Swift 文件同时属于两个 target（在 Xcode 的 File Inspector 里勾选两个 target membership）
8. 在 AiyuTerm target 的 Build Phases 里添加：
   - **Dependencies**: `aiyuterm-hook-bridge`
   - **Copy Files** phase:
     - Destination: `Wrapper`
     - Subpath: `Contents/Helpers`
     - Item: `aiyuterm-hook-bridge` (from Products)
9. 验证构建后 `AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge` 存在

**风险处理**:
- HookProtocol 文件跨 target 可能导致 Swift module 重复编译，如果出问题改用 "Embed Frameworks" 方式，把 HookProtocol 独立成 framework。
- bridge target 不需要签名（`CODE_SIGNING_ALLOWED=NO`），启动时用 `codesign --force --sign -` ad-hoc 签名。
- bridge 二进制的 quarantine 属性：AiyuTerm 首次启动时调用 `removexattr` 移除（移植自 `ConfigInstaller.swift:778`）。

### 2.5 WorkspaceStore 接入占位

在 `AiyuTerm/App/WorkspaceStore.swift` 增加（**此阶段仅占位，不触发真实逻辑**）：

```swift
// After existing agentStatusFilePoller at line 57
private let agentHookServer = AgentHookServer()
```

在 `loadIfNeeded()` 末尾（`WorkspaceStore.swift:662` 附近）追加：

```swift
// Start the new hook server alongside the legacy file poller.
// Phase 2 stub: receiver not yet wired, events will be ignored.
do {
    try agentHookServer.start()
} catch {
    print("AgentHookServer start failed: \(error)")
}
```

**注意**: 此阶段 `receiver` 依然为 `nil`，所有事件在 `AgentHookServer` 里被解析后直接 drop，**不调用** 任何 WorkspaceStore 状态更新方法。这是故意的 —— Phase 2 只验证 transport 层。

### 2.6 手工验证脚本

新建 `scripts/test-hook-bridge.sh`:

```bash
#!/bin/bash
set -euo pipefail

SOCKET="$HOME/.aiyuterm/hook.sock"

if [ ! -S "$SOCKET" ]; then
    echo "FAIL: socket not found at $SOCKET"
    exit 1
fi

# Test 1: send valid UserPromptSubmit
echo '{"hook_event_name":"UserPromptSubmit","session_id":"test-s1","cwd":"/tmp","prompt":"hello"}' \
    | nc -U -w 2 "$SOCKET"
echo "Test 1 passed: UserPromptSubmit accepted"

# Test 2: send invalid JSON
echo 'not json' | nc -U -w 2 "$SOCKET"
echo "Test 2 passed: invalid JSON rejected"

# Test 3: bridge binary runs
BRIDGE="$(dirname $(find ~/Library/Developer/Xcode/DerivedData -name 'AiyuTerm.app' -print -quit))/AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge"
if [ -x "$BRIDGE" ]; then
    echo '{"hook_event_name":"Stop","session_id":"test-s1"}' | "$BRIDGE" || true
    echo "Test 3 passed: bridge binary executable"
else
    echo "FAIL: bridge binary not found at $BRIDGE"
    exit 1
fi
```

## 验收检查清单

- [ ] `AgentHookServer.swift` 编译通过
- [ ] `AgentHookReceiver.swift` 协议定义完整
- [ ] `AiyuTermHookBridge` target 添加成功
- [ ] 构建产物中 `AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge` 存在且可执行
- [ ] 启动 AiyuTerm 后 `~/.aiyuterm/hook.sock` 创建成功
- [ ] `scripts/test-hook-bridge.sh` 3 个用例全部 PASS
- [ ] 日志中能看到 `AgentHookServer ready at ...`
- [ ] AiyuTerm 关闭后 socket 文件被 unlink

## 回滚步骤

1. Xcode 工程删除 `AiyuTermHookBridge` target
2. 删除 AiyuTerm target 的 Copy Files phase 和 Dependency
3. 删除 `AgentHookServer.swift` / `AgentHookReceiver.swift` / `AiyuTermHookBridge/main.swift`
4. 回滚 `WorkspaceStore.swift` 的改动

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| Xcode 多 target 共享源码编译冲突 | 高 | 用 framework 方式隔离 |
| bridge 二进制首次启动被 Gatekeeper 拦 | 高 | 启动时 ad-hoc codesign + removexattr |
| socket 路径 > 104 字节（长用户名） | 中 | 启动时检测并 fallback 到 `/tmp/aiyuterm-hook-<uid>.sock` |
| 和现有 FilePoller 端口冲突 | 无 | 两套机制独立，无冲突 |

## 数据库/文件副作用

**有**。本阶段会：
- 创建目录 `~/.aiyuterm/`（如果不存在）
- 创建 socket 文件 `~/.aiyuterm/hook.sock`（权限 0700）
- 在 `AiyuTerm.app/Contents/Helpers/` 嵌入 `aiyuterm-hook-bridge` 二进制（~86KB）

**用户影响**: 无（本阶段不改动 hook 配置，现有 Claude Code hook 继续走老的 file poller）。
