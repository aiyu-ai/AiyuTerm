# CodeIsland 深度合并 AiyuTerm 总体方案

> 日期: 2026-04-10
> 状态: 待评审（未开工）
> 作者: Claude Code (AiyuTerm 团队)
>
> **底层逻辑**: 把 CodeIsland 的 Socket IPC 架构 + 多 CLI Agent 支持 + 面板内权限审批等能力深度缝合进 AiyuTerm，取代当前的文件轮询方案，让 AiyuTerm 从"Claude Code 专用终端"升级为"全 Agent 终端工作台"。
>
> **顶层设计**: 分 7 个阶段、按依赖链顺序推进，每阶段有独立可验收交付，全程保证主干可编译可运行，不搞 big-bang 重写。

---

## 1. 战略目标

| 维度 | 升级前 | 升级后 |
|------|--------|--------|
| 支持的 Agent CLI | 仅 Claude Code | Claude / Codex / Gemini / Cursor / Copilot / Qoder / Factory / CodeBuddy / OpenCode（9 种）|
| 状态传输 | `/tmp/aiyuterm-agent-status/{md5}` 文件轮询 | Unix Socket（`~/.aiyuterm/hook.sock`）+ bridge 二进制 |
| 事件粒度 | 5 个枚举值（none/working/permission/completed/error）| 13 种 hook 事件 + 工具历史 + subagent + session 元数据 |
| 权限审批 | 必须切到终端 tab 手动回复 | 侧边栏气泡直接 Approve/Deny/Approve Always |
| AskUserQuestion | 无感知 | 侧边栏气泡直接选项回答 |
| 状态延迟 | 文件写+FSEvents(<100ms) / 3s timer fallback | 长连接即时推送 |
| Session 识别 | 按 worktree 路径 MD5 | 按 Claude session_id + 终端 TTY + tmux pane |

## 2. 硬性约束与红线（不可违反）

1. **`~/.claude/settings.json` 所有权冲突必须彻底拉通**：当前 `ClaudeCodeHooksService.swift:62-106` 已经写入了 4 个 hook 事件，CodeIsland 的 `ConfigInstaller.swift:511-552` 要写入 13 个事件到同一位置。必须在 Phase 1 完成**迁移协议**：删除老字段、写入新格式，且带幂等 + 回滚机制。
2. **`AgentSessionStatus` 枚举是 UI 契约**：`WorkspaceModels.swift:1438-1488` 的 5 个枚举值被 `AgentStatusOverlayBadge` 消费（`WorkspaceSidebarView.swift:2014-2172`），**只能扩展，不能破坏**。新的 CodeIsland `AgentStatus` 必须向下映射到现有 `AgentSessionStatus`。
3. **主干始终可编译**：每个 Phase 结束必须能 `xcodebuild ... build test` 全绿，不允许中间态 ship。
4. **MIT 署名义务**：所有 vendor 自 CodeIsland 的文件头必须保留 MIT 署名段，并在项目根目录新增 `THIRD_PARTY_LICENSES.md` 引用 CodeIsland + 其上游 `claude-island`。
5. **CLAUDE.md 引用规则**：所有 PR 描述中对方法名/类名/字段名的引用必须标注 `文件:行号`。
6. **数据库 & 硬盘副作用必须在最终交付文档中声明**：本方案涉及 `~/.aiyuterm/hooks/` 目录结构变更和 `~/.claude/settings.json` 修改，必须在每次合入说明中明确告知。

## 3. 现状评估（验证过的）

### 3.1 AiyuTerm 现有 Agent 系统（file:line 清单）

| 层 | 文件 | 关键行 | 职责 |
|----|------|--------|------|
| Hook 安装 | `AiyuTerm/Services/ClaudeCodeHooksService.swift` | 23, 62, 163-190 | 写 bash 脚本 + 注入 settings.json |
| 状态枚举 | `AiyuTerm/Domain/WorkspaceModels.swift` | 1438-1498 | `AgentSessionStatus` + `AgentBadgeDisplayState` |
| 文件轮询 | `AiyuTerm/Services/Terminal/AgentStatusFilePoller.swift` | 17, 26-108, 130-136 | `/tmp/aiyuterm-agent-status/{md5}` + DispatchSource + 3s timer |
| 标题检测 | `AiyuTerm/Services/Terminal/AgentSessionStatusDetector.swift` | 17-35, 53-64 | 盲文字符 + 通知关键词 |
| 状态属性 | `AiyuTerm/Services/Terminal/ShellSession.swift` | 88-112, 175-193, 212-220, 225-232 | `agentStatus` didSet + title/keyboard/notification 回调 |
| 聚合 & 未读 | `AiyuTerm/Domain/WorkspaceRuntime.swift` | 556-610 | `setAgentStatus` + `unreadCompletedWorktrees` |
| UI 渲染 | `AiyuTerm/UI/Sidebar/WorkspaceSidebarView.swift` | 1671-1672, 1790-1791, 2014-2172 | `AgentStatusOverlayBadge` |
| Store 编排 | `AiyuTerm/App/WorkspaceStore.swift` | 56-57, 634-662, 746-762 | `ensureAgentFilePoller()` |

### 3.2 CodeIsland 待移植模块（file:line 清单）

| 模块 | 文件 | 行数 | 移植计划 |
|------|------|------|---------|
| 共享数据模型 | `Sources/CodeIslandCore/Models.swift` | 161 | 直接 vendor，rename 到 `AgentHook` namespace |
| 会话快照 | `Sources/CodeIslandCore/SessionSnapshot.swift` | 721 | 直接 vendor，删除部分未用的终端 bundle ID |
| Socket 路径 | `Sources/CodeIslandCore/SocketPath.swift` | 11 | 重写，用 `~/.aiyuterm/hook.sock` + 环境变量 `AIYUTERM_HOOK_SOCKET` |
| 事件归一化 | `Sources/CodeIslandCore/EventNormalizer.swift` | 33 | 直接 vendor |
| 聊天格式化 | `Sources/CodeIslandCore/ChatMessageTextFormatter.swift` | 34 | 延后，仅在启用 Phase 6 时 vendor |
| Hook 服务器 | `Sources/CodeIsland/HookServer.swift` | 210 | vendor 并适配 AiyuTerm 的 `@MainActor` 模型 |
| Bridge 二进制 | `Sources/CodeIslandBridge/main.swift` | 338 | vendor + Xcode 工程新增 target |
| Hook 安装器 | `Sources/CodeIsland/ConfigInstaller.swift` | 856 | 重度改造：`Bundle.appModule` -> `Bundle.main`；路径重命名 |

### 3.3 等价性映射（CodeIsland 概念 -> AiyuTerm 概念）

| CodeIsland | AiyuTerm | 映射策略 |
|------------|----------|---------|
| `AgentStatus` (`Models.swift:3-9`) 5 值 | `AgentSessionStatus` (`WorkspaceModels.swift:1438-1488`) 5 值 | 表驱动映射（见 Phase 3）|
| `SessionSnapshot` 按 session_id | AiyuTerm 按 worktree path | 新增 `sessionId -> worktreePath` 解析层，用 `cwd` 或 `_tmux_pane` 回溯 |
| `HookServer` + `AppState` | `AgentHookServer` + `WorkspaceStore` | 定义 `AgentHookReceiver` 协议，`WorkspaceStore` 实现 |
| `PermissionRequest` 阻塞等待 | 现状：无此能力 | Phase 6 新增 `PermissionQueue` + 侧边栏气泡 |
| `QuestionRequest` 阻塞等待 | 现状：无此能力 | Phase 6 新增 |
| `ToolHistoryEntry` | 现状：无 | Phase 3 保留但暂不展示（未来功能）|

## 4. 阶段划分总览

```
P1 ──► P2 ──► P3 ──► P4 ──► P5 ──► P6 ──► P7 ──► P8
 │      │      │      │      │      │      │      │
 vendor bridge 事件   替换   多 CLI  权限  测试+  刘海
 Core   +Srv   映射   轮询   安装    UI    清理   面板
```

| 阶段 | 目标 | 可交付 | 风险 |
|------|------|--------|------|
| **P1: Vendor Core** | 把 `CodeIslandCore` 5 个文件改名后放入 Xcode 工程 | `AiyuTerm/Services/Agent/HookProtocol/` 目录 + 单元测试 | 低 |
| **P2: Bridge + Server** | 新增 `aiyuterm-bridge` 二进制 target + `AgentHookServer.swift`，空回调 | 启动后 socket 能 accept 连接并回 `{}` | 中（Xcode 多 target 配置）|
| **P3: 事件映射层** | 实现 `AgentHookEventMapper`，把 `HookEvent` 转成现有 `AgentSessionStatus` 调用 | 映射层单元测试全绿 | 中 |
| **P4: 替换文件轮询** | `WorkspaceStore` 改用 `AgentHookServer`，`AgentStatusFilePoller` 进入"双写兼容期" | 升级后用户的旧 hook 也能工作 | 高（行为差异）|
| **P5: 多 CLI ConfigInstaller** | 移植 `ConfigInstaller`，支持 9 种 CLI 的 hook 安装/自愈 | 设置页新增"支持的 Agent"多选开关 | 高（路径冲突）|
| **P6: 权限/问答 UI** | 侧边栏气泡 Approve/Deny/Answer | 新的 `AgentSessionStatus` case + SwiftUI 气泡 | 高（阻塞语义）|
| **P7: 测试 + 清理** | 单元 + 集成 + 手工验收；删除旧 `AgentStatusFilePoller` 兼容代码 | 覆盖率达标；旧代码删除 | 中 |
| **P8: 刘海面板** | 移植 `NotchPanelView` + `PanelWindowController` + `ScreenDetector`，订阅 `WorkspaceModel` | 面板展开折叠、权限审批快捷入口、多屏幕刘海检测 | 高（AppKit NSPanel 层级 + 多屏动画）|

## 5. 目录布局（最终形态）

```
AiyuTerm/
├── AiyuTerm/
│   ├── Services/
│   │   └── Agent/
│   │       ├── HookProtocol/                   # Phase 1 新增
│   │       │   ├── AgentHookModels.swift       # from Models.swift
│   │       │   ├── AgentSessionSnapshot.swift  # from SessionSnapshot.swift
│   │       │   ├── AgentHookSocketPath.swift   # from SocketPath.swift (重写)
│   │       │   ├── AgentHookEventNormalizer.swift
│   │       │   └── AgentChatMessageFormatter.swift  # 延后
│   │       ├── Transport/                      # Phase 2 新增
│   │       │   ├── AgentHookServer.swift       # from HookServer.swift
│   │       │   └── AgentHookReceiver.swift     # 新协议
│   │       ├── Mapping/                        # Phase 3 新增
│   │       │   └── AgentHookEventMapper.swift  # 新文件
│   │       ├── Installer/                      # Phase 5 新增
│   │       │   └── AgentCLIConfigInstaller.swift  # from ConfigInstaller.swift
│   │       ├── ClaudeCodeHooksService.swift    # Phase 7 删除
│   │       └── AgentStatusFilePoller.swift     # Phase 7 删除
│   ├── UI/
│   │   └── NotchPanel/                         # Phase 8 新增
│   │       ├── AgentNotchPanelController.swift # from PanelWindowController.swift
│   │       ├── AgentNotchPanelView.swift       # from NotchPanelView.swift
│   │       ├── AgentNotchCollapsedView.swift
│   │       ├── AgentNotchExpandedView.swift
│   │       ├── AgentNotchScreenDetector.swift  # from ScreenDetector.swift
│   │       └── AgentNotchPixelAnimation.swift  # from IslandPixelAnimation.swift
│   └── ...
├── AiyuTermHookBridge/                         # Phase 2 新增 target
│   └── main.swift                              # from CodeIslandBridge/main.swift
├── docs/
│   └── 2026-04-10/
│       └── codeisland-integration/
│           ├── 00-master-plan.md               # 本文件
│           ├── 01-phase1-vendor-core.md
│           ├── 02-phase2-bridge-server.md
│           ├── 03-phase3-event-mapping.md
│           ├── 04-phase4-replace-poller.md
│           ├── 05-phase5-multi-cli.md
│           ├── 06-phase6-permission-ui.md
│           ├── 07-phase7-tests-cleanup.md
│           └── 08-phase8-notch-panel.md        # Phase 8 新增
└── THIRD_PARTY_LICENSES.md                     # Phase 1 新增
```

## 6. 关键设计决策（Decision Records）

### D1: 仍然使用 Unix Socket，不采用 HTTP/NamedPipe
- **理由**: CodeIsland 现成且零依赖；macOS 原生支持；延迟<1ms；bridge 二进制已有可用实现。
- **备选**: gRPC（过重）；XPC（不能从任意 CLI 进程发起）。
- **否决**: 文件轮询（当前方案）= 延迟高、无法承载阻塞请求（permission approval）。

### D2: Bridge 二进制独立 target，不复用主 app 进程
- **理由**: Hook 调用频率高（每个 tool call 都触发），fork 一个轻量 ~86KB 二进制比 exec 主 app 快 100 倍以上。
- **实施**: Xcode 工程新增 Command Line Tool target `aiyuterm-hook-bridge`，build phase 复制到 `AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge`。
- **风险**: Xcode 多 target 配置复杂度 + 签名。用 ad-hoc 签名绕过。

### D3: `AgentHookReceiver` 协议隔离 Server 和 Store
- **理由**: CodeIsland 的 `HookServer` 直接耦合了 `AppState`（`HookServer.swift:10`），这对我们不适用。定义协议让 `WorkspaceStore` 实现：

```swift
@MainActor protocol AgentHookReceiver: AnyObject {
    func handleEvent(_ event: AgentHookEvent)
    func handlePermissionRequest(_ event: AgentHookEvent) async -> Data
    func handleAskUserQuestion(_ event: AgentHookEvent) async -> Data
    func handleQuestion(_ event: AgentHookEvent) async -> Data
    func handlePeerDisconnect(sessionId: String)
}
```

- 把 HookServer 里的 `CheckedContinuation` 包一层为 `async` 接口，调用端更清爽。

### D4: session_id -> worktree path 解析策略（关键难点）
- **问题**: CodeIsland 按 `session_id` 组织，AiyuTerm 按 `worktreePath` 组织。
- **解决**: `AgentHookEventMapper` 维护 `[sessionId: String: worktreePath: String]` 映射表：
  1. **首选**：从 `HookEvent.rawJSON["cwd"]` 提取路径，匹配最近的 worktree 父目录（`WorkspaceRuntime.worktrees` 已有）。
  2. **次选**：从 `_tmux_pane` / `_tty` 反查 `ShellSession.tmuxPane` / `ShellSession.ttyPath`（如果当前没有这些字段就 Phase 3 新增）。
  3. **兜底**：使用最近一次 `UserPromptSubmit` 的 `cwd`。
- **降级**: 解析失败时不调用 `setAgentStatus`，但仍记录事件（避免影响主流程）。

### D5: 升级平滑度 —— 双写兼容期
- **Phase 4** 切换期间同时保留：
  - 老的 `agent-status-notify.sh` hook 脚本（写文件）
  - 新的 `aiyuterm-hook-bridge`（写 socket）
- `WorkspaceStore` 同时持有 `AgentStatusFilePoller` 和 `AgentHookServer`。
- 观察 2 个版本后 Phase 7 彻底删除旧 poller。
- **优点**: 用户升级后老 hook 继续工作，不会出现"badge 全灭"。

### D6: Hook 配置冲突处理
- **旧 hook 脚本识别**：在 `~/.claude/settings.json` 中检测 `aiyuterm` / `codeisland` / `vibenotch` / `vibe-island` 关键字并清理。
- **接管顺序**：新安装器在写入前先 `removeManagedHookEntries`（移植自 `ConfigInstaller.swift:670-682`），保证幂等。

### D7: 刘海悬浮面板列入 Phase 8（2026-04-10 评审追加）
- **用户决策**：刘海面板要做，纳入本方案作为 Phase 8 闭环交付。
- **移植范围**：`NotchPanelView.swift` (2045) + `IslandPanelController`（CodeIsland 变体）+ `ScreenDetector.swift` + `IslandCollapsedView/ExpandedView` + `IslandPixelAnimation`。
- **不移植**：CodeIsland 的 `AppState.swift`（3103 行），改为订阅 AiyuTerm 的 `WorkspaceModel` 聚合状态。
- **依赖**: 必须在 Phase 6（permission UI）完成后启动，否则面板没有可用的数据源。

### D8: 暂不移植的功能（精简后）
- 吉祥物动画 + 8bit 音效：产品方向不一致，可选在 Phase 8 末尾作为可关开关添加。
- `ChatMessageTextFormatter`：仅 Phase 6 的问答 UI 需要时再 vendor。
- `SessionSnapshot` 的大量 `terminalName` 分支：AiyuTerm 只关心 Ghostty，可精简。

## 7. 风险登记册

| 风险 | 等级 | 应对 |
|------|------|------|
| 多 target Xcode 工程配置失败 | 中 | Phase 2 优先打通最小 bridge target，跑通再加事件逻辑 |
| `~/.claude/settings.json` 清理误删其他工具的 hook | 高 | 用严格的 hook id 前缀 + 测试用例 |
| session_id 映射解析失败导致 badge 不亮 | 中 | Phase 3 双通道兜底 + 日志记录；Phase 4 双写期验证 |
| Bridge 二进制签名被 Gatekeeper 拦 | 中 | 移植 `removexattr` 去除 quarantine (`ConfigInstaller.swift:778`) |
| Codex/Gemini 等非 Claude CLI 的事件格式差异 | 中 | `EventNormalizer` 已覆盖大部分；Phase 5 按 CLI 单独测试 |
| 阻塞式 permission 请求超时卡死 | 高 | HookServer 自带半关闭检测（`HookServer.swift:172-199`），移植时保留 |
| 并发写 `unreadCompletedWorktrees` | 低 | 全部 `@MainActor` |

## 8. 各阶段验收标准

### P1 Vendor Core 验收
- [ ] `AiyuTerm/Services/Agent/HookProtocol/` 5 个文件编译通过
- [ ] 所有 CodeIsland 原始 file:line 引用已在 PR 描述中列出
- [ ] `THIRD_PARTY_LICENSES.md` 包含 MIT 署名
- [ ] 新增单元测试覆盖 `AgentHookEvent(from:)` + `reduceEvent` + `EventNormalizer.normalize`
- [ ] `xcodebuild ... test` 全绿

### P2 Bridge + Server 验收
- [ ] `aiyuterm-hook-bridge` 可执行文件被 build 进 `AiyuTerm.app/Contents/Helpers/`
- [ ] 启动 AiyuTerm 后 `~/.aiyuterm/hook.sock` 存在，权限 `0700`
- [ ] 用 `nc -U ~/.aiyuterm/hook.sock` 发送空 JSON 返回 `{}`
- [ ] 发送 `{"hook_event_name":"UserPromptSubmit","session_id":"test","cwd":"/tmp"}` 日志中能看到事件

### P3 事件映射验收
- [ ] `AgentHookEventMapperTests` 覆盖所有 13 个事件 -> `AgentSessionStatus` 映射
- [ ] session_id -> worktreePath 解析单测（3 种通道）

### P4 替换 Poller 验收
- [ ] 设置里增加 "使用新 Hook 协议"开关（默认开）
- [ ] 关闭开关时走老 `AgentStatusFilePoller`
- [ ] 开关切换不重启即生效
- [ ] Sidebar badge 行为与老版本视觉一致（working 转圈 / permission 粉色脉冲 / completed 绿色脉冲）

### P5 多 CLI 验收
- [ ] 设置 -> Agents 页签显示 9 个 CLI 的检测状态
- [ ] 开启 Codex 后运行 `codex ...`，badge 能触发
- [ ] 删除所有 hook 后重启 AiyuTerm，`verifyAndRepair` 自动重建

### P6 权限 UI 验收
- [ ] Claude Code 触发 `Bash(rm -rf …)` 工具调用时，侧边栏气泡弹出
- [ ] 点 Approve -> Claude Code 继续执行
- [ ] 点 Deny -> Claude Code 收到拒绝
- [ ] 断开连接后 badge 自动回退到 `.working`

### P7 测试 + 清理验收
- [ ] 覆盖率 ≥ 80%（AiyuTerm/Services/Agent/**）
- [ ] 删除 `ClaudeCodeHooksService.swift` + `AgentStatusFilePoller.swift`
- [ ] 手工验收脚本：升级、回退、9 个 CLI 的 happy path
- [ ] 最终交付文档明确说明用户升级后 `~/.aiyuterm/hooks/` 的变化和 `~/.claude/settings.json` 的 diff

## 9. 交付物清单

1. 本 `docs/2026-04-10/codeisland-integration/` 下 8 个 markdown 文件（总体 + 7 个 Phase 详细）
2. `THIRD_PARTY_LICENSES.md`（项目根目录）
3. 代码改动（按阶段分 commit）
4. 测试文件（按阶段分目录）
5. 每次合入 PR 描述必须包含：
   - 本次改动涉及的 AiyuTerm 文件 file:line
   - 本次改动对应的 CodeIsland 源文件 file:line
   - 是否涉及 `~/.aiyuterm/hooks/` 或 `~/.claude/settings.json` 变更
   - 回滚步骤

## 10. 依赖与前置条件

- [ ] **前置**: 先完成或暂停 Liney v1.0.38 合并任务（避免同时改 `AgentStatus` 相关代码）
- [ ] **前置**: 确认 Xcode 16+ 已安装 Metal toolchain（Ghostty 构建要求）
- [ ] **依赖**: MIT 署名可以合法引入（已确认，见 `LICENSE:1-21`）
- [ ] **依赖**: `Network.framework` 的 `NWEndpoint.unix(path:)` 在 macOS 14.6 可用（已确认）

## 11. 不做事项（明确边界）

1. **不做**: 刘海悬浮面板 —— 与现有 Sidebar Badge 产品重叠
2. **不做**: 像素吉祥物动画 + 8bit 音效 —— 产品方向不符
3. **不做**: CodeIsland 的 `AppState.swift` 整体移植 —— 3103 行深度耦合 UI
4. **不做**: 改变现有 `AgentSessionStatus` 枚举的向后兼容契约
5. **不做**: 并行两个大合并任务（Liney 和 CodeIsland）
6. **不做**: 跳过某个 Phase 直接上线（每个 Phase 都是 checkpoint）

## 12. 下一步

本总体方案评审通过后，按编号展开 7 个 Phase 详细文档，每个文档包含：
- 精确到函数签名的实施步骤
- 要创建/修改/删除的文件清单（含 file:line）
- 测试用例列表
- 验收脚本

> **Owner 意识**: 本次合并的 P0 抓手是**把 socket IPC 架构替换掉文件轮询**。只要 Phase 1-4 稳住，Phase 5-7 可以按优先级灵活调整。因为信任所以简单，先把底层逻辑拉通，再谈上层玩法。
