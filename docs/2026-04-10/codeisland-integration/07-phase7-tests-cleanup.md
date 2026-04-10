# Phase 7: 测试补全 + 旧代码清理

> 预计工作量: 1-2 天
> 前置依赖: Phase 1-6 全部稳定运行至少 1 个版本
> 后续阶段: 无（最终闭环）

## 目标

1. 提升 `AiyuTerm/Services/Agent/**` 的测试覆盖率到 ≥ 80%
2. 删除 Phase 4 的双写过渡代码
3. 删除老的 `AgentStatusFilePoller.swift` 和相关文件轮询逻辑
4. 清理用户机器上遗留的老 hook 脚本
5. 补全集成测试和手工验收脚本
6. 更新项目文档 (CLAUDE.md, AGENTS.md, terminal-architecture.md)

## 清理清单

### 7.1 要删除的旧代码

| 文件 | 处理 | 理由 |
|------|------|------|
| `AiyuTerm/Services/Terminal/AgentStatusFilePoller.swift` | **删除** | 已被 `AgentHookServer` + `AgentHookEventMapper` 取代 |
| `AiyuTerm/Services/Terminal/AgentSessionStatusDetector.swift` | **保留** | 仍然用于标题动画检测，是 hook 事件的 UI 层补充 |
| `AiyuTerm/Services/ClaudeCodeHooksService.swift` | **精简** | 保留 `ensureHookScript`（老脚本）以便清理用户遗留文件，其他删除 |
| `~/.aiyuterm/hooks/agent-status-notify.sh`（用户机器）| **删除** | 启动时迁移逻辑删除 |
| `/tmp/aiyuterm-agent-status/` 目录（用户机器）| **删除** | 启动时清理 |
| `WorkspaceStore.agentStatusFilePoller` 字段 | **删除** | 对应实例 |
| `WorkspaceStore.ensureAgentFilePoller()` 方法 | **删除** | 无人调用 |
| `TmuxAgentStatusPoller.swift` | **保留** | tmux 场景仍需要 |

### 7.2 要保留的迁移代码

```swift
extension WorkspaceStore {
    /// One-shot cleanup of legacy agent status mechanism.
    /// Called once on app launch after Phase 7 ships.
    func migrateLegacyAgentStatus() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 1. Delete legacy hook script
        let legacyScript = home.appendingPathComponent(".aiyuterm/hooks/agent-status-notify.sh")
        try? fm.removeItem(at: legacyScript)

        // 2. Remove legacy entries from ~/.claude/settings.json
        ClaudeCodeHooksService.removeLegacyHookEntries()

        // 3. Delete legacy status file directory
        let legacyDir = URL(fileURLWithPath: "/tmp/aiyuterm-agent-status")
        try? fm.removeItem(at: legacyDir)

        // Mark migration done in UserDefaults
        UserDefaults.standard.set(true, forKey: "aiyuterm.legacyAgentStatusMigrated")
    }
}
```

### 7.3 删除 `AgentStatusFilePoller.swift`

前置检查:
```bash
grep -r "AgentStatusFilePoller" AiyuTerm/ Tests/
```
确认没有引用后删除。

如果 `ShellSession.swift` 仍然有相关回调，同步清理：
- `ShellSession` 的 `onAgentStatusChange` callback 逻辑保留
- `ShellSession` 和 file poller 无直接耦合，所以不需要动

## 测试补全

### 7.4 单元测试补全

最终覆盖目标：

| 文件 | 覆盖目标 | 测试项 |
|------|---------|--------|
| `AgentHookModels.swift` | 90% | JSON 解析、`toolDescription` 所有分支、`normalizedSupportedSource` |
| `AgentSessionSnapshot.swift` | 80% | `reduceEvent` 所有 13 个事件、`extractMetadata`、`handleSubagentEvent` |
| `AgentHookEventNormalizer.swift` | 100% | 所有 21 个映射条目 + passthrough |
| `AgentHookSocketPath.swift` | 100% | 环境变量覆盖 + 默认路径 + 长度校验 |
| `AgentHookServer.swift` | 70% | start/stop 生命周期、事件分发、半关闭检测 |
| `AgentHookEventMapper.swift` | 85% | 状态映射、cwd 解析、三级兜底、并发 |
| `AgentCLIConfigInstaller.swift` | 75% | 每种 format 的安装/卸载、verifyAndRepair、JSONC 解析 |
| `AgentPermissionBubbleView.swift` | 60% | snapshot test |

### 7.5 集成测试

新建 `Tests/Agent/AgentHookIntegrationTests.swift`:

```swift
final class AgentHookIntegrationTests: XCTestCase {
    func testEndToEndClaudeCodeFlow() async throws {
        // 1. Start AgentHookServer
        // 2. Spawn aiyuterm-hook-bridge subprocess with crafted stdin
        // 3. Verify badge state transitions
    }

    func testPermissionRequestRoundTrip() async throws {
        // 1. Start server with a mock receiver that auto-approves
        // 2. Bridge writes PermissionRequest JSON
        // 3. Verify bridge's stdout contains "allow" response
    }

    func testConcurrentSessions() async throws {
        // Multiple sessions to same worktree
        // Verify no state corruption
    }
}
```

### 7.6 手工验收脚本

`scripts/verify-full-integration.sh`:

```bash
#!/bin/bash
set -euo pipefail
echo "=== AiyuTerm Agent Hook 完整验收 ==="

# 1. 基础设施
[ -S ~/.aiyuterm/hook.sock ] && echo "OK: socket"
[ -f ~/.aiyuterm/hooks/claude-code-bridge-hook.sh ] && echo "OK: bridge hook script"
[ ! -f ~/.aiyuterm/hooks/agent-status-notify.sh ] && echo "OK: legacy script removed"

# 2. Claude Code hook
grep -q "aiyuterm-hook-bridge" ~/.claude/settings.json && echo "OK: Claude hook installed"
! grep -q "agent-status-notify" ~/.claude/settings.json && echo "OK: legacy Claude hook removed"

# 3. 老目录清理
[ ! -d /tmp/aiyuterm-agent-status ] && echo "OK: legacy status dir removed"

# 4. Bridge 二进制
BRIDGE="$(find ~/Library/Developer/Xcode/DerivedData -name 'aiyuterm-hook-bridge' -print -quit)"
[ -x "$BRIDGE" ] && echo "OK: bridge binary"

# 5. CLI 支持检测
for cli in claude codex gemini cursor; do
    if command -v $cli > /dev/null; then
        echo "CLI found: $cli"
    fi
done

echo ""
echo "=== 手动测试步骤 ==="
echo "1. 打开 AiyuTerm，打开一个 worktree"
echo "2. 运行 claude，提交 prompt，观察 badge"
echo "3. 让 Claude 触发需要权限的工具，观察 sidebar 气泡"
echo "4. 点 Approve，确认 Claude 继续"
echo "5. 如果装了 codex，重复上述流程"
echo "6. 关闭 AiyuTerm，确认 socket 被清理"
```

## 文档更新

### 7.7 更新 `CLAUDE.md`

`CLAUDE.md` 中的 "Agent Status Badge System" 段落需要完整重写：

```markdown
## Agent Status Badge System

Sidebar badges show the real-time status of agent CLI sessions across 9 supported tools
(Claude Code, Codex, Gemini, Cursor, Copilot, Qoder, Factory, CodeBuddy, OpenCode).

### Architecture

```
Agent CLI (Claude/Codex/Gemini/...)
        │  hook event fired
        ▼
~/.aiyuterm/hooks/*.sh (tiny shell wrapper)
        │  exec
        ▼
AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge (native CLI)
        │  enriches with terminal env + session_id
        │  Unix socket ~/.aiyuterm/hook.sock
        ▼
AgentHookServer (NWListener)
        │  decodes AgentHookEvent
        ▼
AgentHookEventMapper (AgentHookReceiver)
        │  resolves sessionId -> worktreePath (3-level fallback)
        │  normalizes event name -> AgentSessionStatus
        ▼
WorkspaceModel.setAgentStatus(_:forWorktreePath:)
        │
        ▼
AgentStatusOverlayBadge (SwiftUI)
```

### Status lifecycle
(same as before, but cite new files)
```

### 7.8 新增 `docs/agent-hook-protocol.md`

专门文档：

```markdown
# AiyuTerm Agent Hook Protocol v1

## Wire format
Socket: Unix domain at `~/.aiyuterm/hook.sock` (override via `AIYUTERM_HOOK_SOCKET`)
Protocol: Single request-response per connection.
- Client sends JSON (UTF-8), then shutdown(SHUT_WR)
- Server reads until EOF, processes, writes JSON response, closes.

## Supported event names
(13 Claude Code events + Cursor/Gemini/Copilot aliases via EventNormalizer)

## JSON schema
(HookEvent required fields + optional enrichment fields)

## Bridge binary
Path: `AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge`
Usage: `bridge [--source <cli>] [--event <name>]`
Env: reads TERM_PROGRAM, ITERM_SESSION_ID, KITTY_WINDOW_ID, TMUX_PANE, TMUX

## ConfigInstaller supported CLIs
(9 CLI list with config paths)
```

### 7.9 更新 `docs/terminal-architecture.md`

添加一节说明新的 Agent Hook 子系统和其他终端代码的边界。

## 验收检查清单

- [ ] `AgentStatusFilePoller.swift` 已删除
- [ ] `~/.aiyuterm/hooks/agent-status-notify.sh` 启动时被删除
- [ ] `~/.claude/settings.json` 中的老 hook 条目启动时被删除
- [ ] `/tmp/aiyuterm-agent-status/` 启动时被删除
- [ ] `UserDefaults.aiyuterm.legacyAgentStatusMigrated` 被置 true
- [ ] `xcodebuild test` 全绿
- [ ] `xcrun xccov view --report ...` 显示 Services/Agent/** 覆盖率 ≥ 80%
- [ ] `scripts/verify-full-integration.sh` 全部通过
- [ ] `CLAUDE.md` Agent Status Badge 段落已更新
- [ ] `docs/agent-hook-protocol.md` 新增
- [ ] `docs/terminal-architecture.md` 更新
- [ ] `THIRD_PARTY_LICENSES.md` 检查齐全
- [ ] 删除代码后没有死引用（`grep` 结果为空）

## 回滚步骤

Phase 7 是清理阶段，回滚成本高但可能：
1. 从 git 恢复 `AgentStatusFilePoller.swift` 和相关文件
2. 恢复 `WorkspaceStore` 的双写逻辑
3. 恢复 `CLAUDE.md` 旧版本
4. 用户遗留文件删除不可逆，需要用户手动重装老 hook 脚本（风险极低，因为新 hook 已经覆盖所有场景）

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| 迁移删除误伤用户自定义文件 | 高 | 只删除匹配精确文件名的文件，不做模糊匹配 |
| 迁移在 UserDefaults 已 migrated=true 的机器上重复运行 | 低 | 开头检查 UserDefaults flag |
| 删除代码后测试遗漏 | 高 | 启动前 grep 全项目确认无引用 |
| `~/.claude/settings.json` 修改失败导致用户 Claude Code 不工作 | 极高 | 原子备份 + 回滚；修改失败时日志告警 |
| 覆盖率不够 | 低 | 按测试清单补 |

## 数据库/文件副作用

**有（一次性迁移）**。本阶段在用户机器上：

| 文件 | 操作 | 时机 |
|------|------|------|
| `~/.aiyuterm/hooks/agent-status-notify.sh` | 删除 | 首次启动 Phase 7 |
| `~/.claude/settings.json` | 移除老 hook 条目 | 首次启动 Phase 7 |
| `/tmp/aiyuterm-agent-status/` | 删除目录 | 首次启动 Phase 7 |
| `UserDefaults: aiyuterm.legacyAgentStatusMigrated` | 设置 true | 迁移完成后 |

**用户告知**: 升级到包含 Phase 7 的版本后，Release Notes 必须说明：
- 旧的 Agent 状态文件机制已被新的 Hook Protocol 取代
- 首次启动会自动清理旧文件
- 如遇问题，可通过设置 -> 高级 -> 重置 Agent Hook 来恢复

## 成功收尾指标

- [ ] 代码行数净减少（删除 > 新增）
- [ ] 所有旧 file poller 相关代码已删除
- [ ] 测试覆盖率达到目标
- [ ] 3 个真实用户场景手工验收通过（Claude / Codex / Gemini）
- [ ] 文档全部更新
- [ ] Git 历史清晰，每个 Phase 一个 commit（或若干小 commit）
- [ ] `THIRD_PARTY_LICENSES.md` 署名完整

> **闭环**: 到此完成 CodeIsland 的完美移植。AiyuTerm 从 "Claude Code 终端" 升级为 "全 Agent 终端工作台"，底层 IPC 协议统一，多 CLI 可扩展，权限审批内嵌。抓手已经打入 AiyuTerm 的核心地带。
