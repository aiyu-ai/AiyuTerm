# Phase 1: Vendor CodeIslandCore 到 AiyuTerm

> 预计工作量: 0.5-1 天
> 前置依赖: 无
> 后续阶段: Phase 2

## 目标

把 CodeIsland 的 `CodeIslandCore` 5 个源文件重命名后放入 AiyuTerm Xcode 工程，作为事件协议层的纯 Swift 数据模型。本阶段**不引入 Socket、不引入 Bridge、不改动任何现有 AiyuTerm 文件**，只是新增文件 + 建立测试。

## 源文件映射表

| 源（CodeIsland） | 目标（AiyuTerm） | 重命名的类型 |
|-----------------|-----------------|-------------|
| `Sources/CodeIslandCore/Models.swift:1-161` | `AiyuTerm/Services/Agent/HookProtocol/AgentHookModels.swift` | `AgentStatus` -> `AgentHookStatus` / `HookEvent` -> `AgentHookEvent` / `SubagentState` -> `AgentSubagentState` / `ToolHistoryEntry` -> `AgentToolHistoryEntry` / `ChatMessage` -> `AgentChatMessage` / `QuestionPayload` -> `AgentQuestionPayload` |
| `Sources/CodeIslandCore/SessionSnapshot.swift:1-721` | `AiyuTerm/Services/Agent/HookProtocol/AgentSessionSnapshot.swift` | `SessionSnapshot` -> `AgentSessionSnapshot` / `SessionSummary` -> `AgentSessionSummary` / `SideEffect` -> `AgentSessionSideEffect` / `SessionTitleSource` -> `AgentSessionTitleSource` |
| `Sources/CodeIslandCore/SocketPath.swift:1-11` | `AiyuTerm/Services/Agent/HookProtocol/AgentHookSocketPath.swift` | **重写**（见下方）|
| `Sources/CodeIslandCore/EventNormalizer.swift:1-33` | `AiyuTerm/Services/Agent/HookProtocol/AgentHookEventNormalizer.swift` | `EventNormalizer` -> `AgentHookEventNormalizer` |
| `Sources/CodeIslandCore/ChatMessageTextFormatter.swift:1-34` | **Phase 6 再引入** | 延后 |

## 详细步骤

### 1.1 创建目录结构
```
AiyuTerm/Services/Agent/HookProtocol/
```
Xcode 工程中创建同名 Group，关联到 AiyuTerm target。

### 1.2 `AgentHookSocketPath.swift`（**重写**）

原版（`SocketPath.swift:1-11`）使用 `/tmp/codeisland-<uid>.sock` 和环境变量 `CODEISLAND_SOCKET_PATH`。重写为：

```swift
import Foundation
import Darwin

/// Provides the Unix domain socket path used by the AiyuTerm agent hook bridge.
///
/// Adapted from CodeIsland (MIT) SocketPath.swift.
enum AgentHookSocketPath {
    /// Environment variable name used to override the default socket path.
    static let environmentOverrideKey = "AIYUTERM_HOOK_SOCKET"

    /// Default location under the user's AiyuTerm support directory.
    /// We use ~/.aiyuterm/hook.sock (instead of /tmp) so the socket lives with
    /// the rest of AiyuTerm's state and survives /tmp cleanups.
    static var path: String {
        if let override = ProcessInfo.processInfo.environment[environmentOverrideKey],
           !override.isEmpty {
            return override
        }
        let home = NSHomeDirectory()
        return "\(home)/.aiyuterm/hook.sock"
    }
}
```

**设计说明**:
- 改到 `~/.aiyuterm/hook.sock`，和 AiyuTerm 现有的 `~/.aiyuterm/` 数据目录对齐（见 `CLAUDE.md` "Data storage"段）。
- 环境变量前缀改为 `AIYUTERM_`。
- `sun_path` 上限 104 字节，需要在 Phase 2 启动时验证路径长度，否则 fallback 到 `/tmp/aiyuterm-hook-<uid>.sock`。

### 1.3 `AgentHookModels.swift`

基于 `Models.swift` 逐类重命名，保留 JSON 解析逻辑不变。关键改动：

1. **文件头增加 MIT 署名段**：
```swift
// Adapted from CodeIsland (https://github.com/wxtsky/CodeIsland)
// Original file: Sources/CodeIslandCore/Models.swift
// Copyright (c) 2026 wxtsky — MIT License
// Modifications (c) 2026 AiyuAI — Apache License 2.0
```

2. **枚举重命名**（`Models.swift:3-9` -> `AgentHookStatus`）：
```swift
public enum AgentHookStatus {
    case idle
    case processing
    case running
    case waitingApproval
    case waitingQuestion
}
```

3. **`HookEvent` -> `AgentHookEvent`**（`Models.swift:11-93`）：
   - 保留 `init?(from data: Data)` 逻辑不变
   - 保留 `toolDescription` 所有分支（`Models.swift:32-92`）

4. 所有 `public` 保留，内部消费不需要 framework 边界，但保留 `public` 便于测试。

### 1.4 `AgentSessionSnapshot.swift`

基于 `SessionSnapshot.swift:1-721` 重命名。注意事项：

1. **保留完整文件**，即使某些 `terminalName` 分支（`SessionSnapshot.swift:213-261`）与 AiyuTerm 不直接相关，也先保留以降低 diff 风险。
2. **`appBundleNames` / `appBundleSources`**（`SessionSnapshot.swift:192-210`）新增 AiyuTerm 自己的 bundle ID：
   ```swift
   "com.aiyuai.aiyuterm": "AiyuTerm",
   "com.aiyuai.aiyuterm.debug": "AiyuTerm Debug",
   ```
3. **重命名签名**：`reduceEvent(sessions:event:maxHistory:)` 保持不变，只是类型改名：
   ```swift
   public func reduceAgentHookEvent(
       sessions: inout [String: AgentSessionSnapshot],
       event: AgentHookEvent,
       maxHistory: Int
   ) -> [AgentSessionSideEffect]
   ```

### 1.5 `AgentHookEventNormalizer.swift`

`EventNormalizer.swift:1-33` 逐字复制，只改类名。映射表保持完整（包括 Cursor / Gemini / Copilot 的 9 个映射条目）。

### 1.6 Xcode 工程接入

1. 用 Xcode UI 把 4 个新文件加入 `AiyuTerm.xcodeproj`:
   - `AgentHookSocketPath.swift`
   - `AgentHookModels.swift`
   - `AgentSessionSnapshot.swift`
   - `AgentHookEventNormalizer.swift`
2. 勾选 AiyuTerm target
3. 验证 `AiyuTerm/Services/Agent/HookProtocol/` Group 存在
4. `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug build` 通过

### 1.7 单元测试

新建 `Tests/Agent/AgentHookProtocolTests.swift`，参考 `Tests/CodeIslandCoreTests/` 3 个测试文件：

```swift
import XCTest
@testable import AiyuTerm

final class AgentHookEventTests: XCTestCase {
    func testInitFromValidJSON() {
        let json = """
        {"hook_event_name":"UserPromptSubmit","session_id":"abc","cwd":"/tmp"}
        """
        let data = json.data(using: .utf8)!
        let event = AgentHookEvent(from: data)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.eventName, "UserPromptSubmit")
        XCTAssertEqual(event?.sessionId, "abc")
    }

    func testInitFromMissingHookName() {
        let json = """{"session_id":"abc"}"""
        XCTAssertNil(AgentHookEvent(from: json.data(using: .utf8)!))
    }

    func testToolDescriptionForBash() {
        let json = """
        {"hook_event_name":"PreToolUse","session_id":"a","tool_name":"Bash","tool_input":{"command":"ls -la"}}
        """
        let event = AgentHookEvent(from: json.data(using: .utf8)!)
        XCTAssertEqual(event?.toolDescription, "ls -la")
    }
}

final class AgentHookEventNormalizerTests: XCTestCase {
    func testCursorMappings() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("beforeShellExecution"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("afterAgentResponse"), "AfterAgentResponse")
    }

    func testGeminiMappings() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("BeforeTool"), "PreToolUse")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("BeforeAgent"), "SubagentStart")
    }

    func testCopilotMappings() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("sessionStart"), "SessionStart")
        XCTAssertEqual(AgentHookEventNormalizer.normalize("preToolUse"), "PreToolUse")
    }

    func testPassthrough() {
        XCTAssertEqual(AgentHookEventNormalizer.normalize("Stop"), "Stop")
    }
}

final class AgentSessionSnapshotReducerTests: XCTestCase {
    func testUserPromptSubmitTransitionsToProcessing() {
        var sessions: [String: AgentSessionSnapshot] = [:]
        let json = """
        {"hook_event_name":"UserPromptSubmit","session_id":"s1","cwd":"/tmp","prompt":"Hi"}
        """
        let event = AgentHookEvent(from: json.data(using: .utf8)!)!
        _ = reduceAgentHookEvent(sessions: &sessions, event: event, maxHistory: 10)
        XCTAssertEqual(sessions["s1"]?.status, .processing)
    }

    func testStopTransitionsToIdle() {
        var sessions: [String: AgentSessionSnapshot] = [
            "s1": {
                var s = AgentSessionSnapshot()
                s.status = .processing
                return s
            }()
        ]
        let json = """
        {"hook_event_name":"Stop","session_id":"s1"}
        """
        let event = AgentHookEvent(from: json.data(using: .utf8)!)!
        _ = reduceAgentHookEvent(sessions: &sessions, event: event, maxHistory: 10)
        XCTAssertEqual(sessions["s1"]?.status, .idle)
    }
}
```

### 1.8 THIRD_PARTY_LICENSES.md（根目录）

```markdown
# Third-Party Licenses

## CodeIsland
- **Source**: https://github.com/wxtsky/CodeIsland
- **License**: MIT
- **Copyright**: (c) 2026 wxtsky
- **Upstream**: CodeIsland is itself inspired by claude-island (https://github.com/farouqaldori/claude-island)
- **Used in**: AiyuTerm/Services/Agent/HookProtocol/*.swift, AiyuTerm/Services/Agent/Transport/*.swift, AiyuTerm/Services/Agent/Installer/*.swift, AiyuTermHookBridge/*.swift

<full MIT license text here>
```

## 验收检查清单

- [ ] 4 个新文件创建完成
- [ ] 每个文件的文件头包含 MIT 署名段 + 源 file:line
- [ ] `AgentHookSocketPath.path` 返回 `~/.aiyuterm/hook.sock`
- [ ] `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm -configuration Debug build` 成功
- [ ] `xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm test -only-testing:AiyuTermTests/AgentHookEventTests` 成功
- [ ] `THIRD_PARTY_LICENSES.md` 存在
- [ ] 没有修改任何现有 AiyuTerm 文件（只新增）

## 回滚步骤

1. 从 Xcode 工程移除 4 个新文件
2. 删除 `AiyuTerm/Services/Agent/HookProtocol/` 目录
3. 删除 `Tests/Agent/AgentHookProtocolTests.swift`
4. 删除 `THIRD_PARTY_LICENSES.md`
5. `git checkout -- .`

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| `AttributedString(markdown:)` 在 macOS 14.6 行为差异 | 低 | `ChatMessageTextFormatter` 延后到 Phase 6 |
| `SessionSnapshot` 里终端 bundle ID 过多 | 低 | 保留全部，不做删减；Phase 7 再 tidy |
| 命名空间冲突 | 低 | 所有新类型都用 `Agent` 前缀 |

## 数据库/文件副作用

- **无**。本阶段只新增 Swift 源码和单元测试，不触碰 `~/.aiyuterm/` 或 `~/.claude/` 目录。
