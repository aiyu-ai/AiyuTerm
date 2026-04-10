# Phase 4: 安装新 Hook 脚本 + 切换主数据源

> 预计工作量: 1 天
> 前置依赖: Phase 1-3
> 后续阶段: Phase 5

## 目标

1. 让 AiyuTerm 安装一份新的 Claude Code hook 脚本，调用 `aiyuterm-hook-bridge` 通过 socket 上报
2. 保留老的 `agent-status-notify.sh` 作为**双写兼容期**的 fallback
3. 在设置页新增 "使用 Hook Socket 协议" 开关（默认开）
4. 通过开关可以实时切换两套数据源，不需要重启
5. 验证 Claude Code 真实工作流程下 badge 行为与老版本一致

## 核心策略：双写期

```
Phase 4 期间同时存在两套 hook:

   ~/.claude/settings.json
        ├── UserPromptSubmit -> agent-status-notify.sh (老)
        ├── UserPromptSubmit -> aiyuterm-hook-bridge (新)
        ├── Stop              -> agent-status-notify.sh (老)
        ├── Stop              -> aiyuterm-hook-bridge (新)
        └── ...

用户实际看到的 badge 由两个数据源共同推送，
WorkspaceModel.setAgentStatus 是幂等的，所以不会冲突。
```

**为什么双写**:
- 老 hook 覆盖了 3s timer + DispatchSource fallback 兜底，稳定性经过验证
- 新 hook 覆盖了更细粒度事件 + 多 CLI 扩展
- 双写期验证 2 周后，Phase 7 再删除老的

## 详细步骤

### 4.1 扩展 `ClaudeCodeHooksService.swift`

**不要删除**现有实现，在同文件新增一套 API：

```swift
extension ClaudeCodeHooksService {
    /// New hook script that calls the native bridge binary.
    /// Fallback to socket-write shell script if bridge binary is missing.
    static let bridgeHookScriptVersion = 1

    static func bridgeHookScriptURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".aiyuterm/hooks/claude-code-bridge-hook.sh")
    }

    static func bridgeBinaryURL() -> URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/aiyuterm-hook-bridge")
    }

    /// Writes the bridge hook script if missing or out-of-date.
    /// Script body is adapted from ConfigInstaller.swift:202-221 (CodeIsland v4).
    static func ensureBridgeHookScript() {
        let url = bridgeHookScriptURL()
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        let content = bridgeHookScriptContent()
        try? content.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    private static func bridgeHookScriptContent() -> String {
        let bridgePath = bridgeBinaryURL().path
        let socketPath = "$HOME/.aiyuterm/hook.sock"
        return """
        #!/bin/bash
        # AiyuTerm Claude Code hook v\(bridgeHookScriptVersion) — bridge binary + socket fallback
        BRIDGE="\(bridgePath)"
        if [ -x "$BRIDGE" ]; then
          exec "$BRIDGE" "$@"
        fi
        # Fallback: write directly to socket via nc
        SOCK="\(socketPath)"
        [ -S "$SOCK" ] || exit 0
        INPUT=$(cat)
        _ITERM_GUID="${ITERM_SESSION_ID##*:}"
        TERM_INFO="\\"_term_app\\":\\"${TERM_PROGRAM:-}\\",\\"_iterm_session\\":\\"${_ITERM_GUID:-}\\",\\"_tty\\":\\"$(tty 2>/dev/null || true)\\",\\"_ppid\\":$PPID"
        PATCHED="${INPUT%\\}},${TERM_INFO}}"
        if echo "$INPUT" | grep -q '"PermissionRequest"'; then
          echo "$PATCHED" | nc -U -w 120 "$SOCK" 2>/dev/null || true
        else
          echo "$PATCHED" | nc -U -w 2 "$SOCK" 2>/dev/null || true
        fi
        exit 0
        """
    }

    /// Injects the bridge hook alongside the legacy hook (dual-write period).
    /// Claude Code supports multiple hook commands per event — both fire.
    @discardableResult
    static func injectBridgeHooks() -> Bool {
        let settingsURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        // Read, merge, write. Events to hook:
        // UserPromptSubmit, Stop, StopFailure, Notification,
        // PreToolUse, PostToolUse, PermissionRequest, SessionStart, SessionEnd
        let newEvents: [(name: String, timeout: Int)] = [
            ("UserPromptSubmit", 5),
            ("Stop", 5),
            ("StopFailure", 5),
            ("Notification", 86400),
            ("PreToolUse", 5),
            ("PostToolUse", 5),
            ("PermissionRequest", 86400),
            ("SessionStart", 5),
            ("SessionEnd", 5),
        ]

        // ... read existing settings.json, merge, write back
        // Use hook ID "aiyuterm-bridge" in the command string to identify
        // our managed entries for later removal.
        return mergeBridgeHookEntries(settingsURL: settingsURL, events: newEvents)
    }

    /// Removes ONLY the bridge hook entries (leaves legacy entries alone).
    static func removeBridgeHooks() {
        // Scan settings.json and remove any entry whose command string
        // contains "aiyuterm-hook-bridge" or "claude-code-bridge-hook.sh"
    }
}
```

**关键设计**:
- 识别前缀用 `aiyuterm-hook-bridge`（和 bridge 二进制名一致），便于 Phase 7 清理
- 与老的 `agent-status-notify.sh` 并存（老的识别前缀是 `agent-status-notify`）
- hook id 列表：`["aiyuterm-hook-bridge", "claude-code-bridge-hook.sh", "agent-status-notify.sh"]`（Phase 7 清理时全部识别）

### 4.2 新增设置开关 `AppSettings.swift`

在 `AiyuTerm/Domain/AppSettings.swift` 增加：

```swift
/// When true, AiyuTerm installs the new bridge-based hook script and prefers
/// the socket-based AgentHookServer for status updates.
/// When false, AiyuTerm falls back to the legacy file-polling AgentStatusFilePoller.
/// Default: true (new installs), preserves existing value on upgrade.
@Published var useAgentHookBridge: Bool = true
```

持久化 key: `useAgentHookBridge`。

### 4.3 `WorkspaceStore` 实现动态切换

```swift
private func configureAgentDataSource() {
    if settings.useAgentHookBridge {
        ensureAgentHookServer()
        ClaudeCodeHooksService.ensureBridgeHookScript()
        // NOTE: installing requires user consent -- see §4.4
    } else {
        agentHookServer.stop()
        ClaudeCodeHooksService.removeBridgeHooks()
    }
    // File poller always stays on during Phase 4 as the safety net.
    ensureAgentFilePoller()
}
```

监听 `settings.useAgentHookBridge` 变化时调用。

### 4.4 首次启用的用户确认对话框

为了满足 CLAUDE.md 的"执行改动需要告知用户"约束，首次启用 bridge 时弹一个对话框：

```
标题: 启用新的 Agent Hook 协议？
正文:
  AiyuTerm 需要在以下位置安装新的 hook 脚本：
  - ~/.aiyuterm/hooks/claude-code-bridge-hook.sh
  - ~/.claude/settings.json 中新增 9 个 hook 事件
  
  现有的老 hook 脚本会继续保留，你可以随时在设置中关闭新协议。
  
  [取消] [启用]
```

### 4.5 日志对账机制

在 `AgentHookEventMapper.applyStatus` 和 `AgentStatusFilePoller.poll` 两个地方都打印：

```swift
Self.logger.info("[agent-status] source=hook worktree=\(path) status=\(status)")
Self.logger.info("[agent-status] source=file worktree=\(path) status=\(status)")
```

方便双写期肉眼对账，判断是否有一个数据源静默。

### 4.6 手工验收脚本

新建 `scripts/verify-phase4.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "=== Phase 4 手工验收 ==="

# 1. 检查 bridge hook script 存在
[ -f ~/.aiyuterm/hooks/claude-code-bridge-hook.sh ] || { echo "FAIL: bridge hook script missing"; exit 1; }
[ -x ~/.aiyuterm/hooks/claude-code-bridge-hook.sh ] || { echo "FAIL: bridge hook script not executable"; exit 1; }

# 2. 检查 ~/.claude/settings.json 包含新 hook
grep -q 'claude-code-bridge-hook.sh' ~/.claude/settings.json || { echo "FAIL: bridge hook not in settings.json"; exit 1; }

# 3. 检查老 hook 仍然存在（双写期）
grep -q 'agent-status-notify.sh' ~/.claude/settings.json || { echo "WARN: legacy hook removed"; }

# 4. 检查 socket 存在
[ -S ~/.aiyuterm/hook.sock ] || { echo "FAIL: socket missing"; exit 1; }

echo "=== 全部通过 ==="
echo ""
echo "下一步手工测试:"
echo "1. 打开 AiyuTerm，打开一个 worktree"
echo "2. 在终端里运行: claude"
echo "3. 提交一个 prompt，观察 sidebar badge 是否出现 spinner"
echo "4. 等 Claude 完成，观察 badge 是否变成绿色脉冲"
echo "5. 触发一个需要权限的工具调用，观察 badge 是否变粉色"
echo "6. 查看日志对比 source=hook 和 source=file 两条记录"
```

## 验收检查清单

- [ ] `bridgeHookScriptURL` 返回 `~/.aiyuterm/hooks/claude-code-bridge-hook.sh`
- [ ] 脚本写入后权限为 0755
- [ ] 设置页新增 "使用 Hook Socket 协议" 开关
- [ ] 开关默认为 on（新装）
- [ ] 首次启用弹出用户确认对话框
- [ ] 启用后 `~/.claude/settings.json` 同时包含 old hook 和 new hook 的 9 个事件
- [ ] 关闭开关后 new hook 从 settings.json 移除（old hook 仍在）
- [ ] 手工测试：Claude Code 真实工作流程下 badge 行为正常
- [ ] 日志显示两个数据源都在工作，且没有相互覆盖
- [ ] `scripts/verify-phase4.sh` 全部通过

## 回滚步骤

1. 设置里关闭 "使用 Hook Socket 协议" 开关
2. 或者直接 `rm ~/.aiyuterm/hooks/claude-code-bridge-hook.sh`
3. 或者手动编辑 `~/.claude/settings.json` 删除 `aiyuterm-hook-bridge` 相关条目
4. 代码层 revert 本 Phase 的 commit

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| 双写期 badge 闪烁 | 高 | 状态更新幂等；日志对账；必要时给 file poller 加优先级降权 |
| hook 脚本权限错误 | 中 | `posixPermissions: 0o755` 强制设置 |
| `~/.claude/settings.json` JSON 损坏 | 高 | 读取失败时原子备份到 `.bak`，不写入 |
| bridge 二进制路径包含空格 | 低 | 路径 quote |
| 用户已经有 CodeIsland 安装 | 高 | 识别 `codeisland` 关键字，提示用户先卸载 CodeIsland 或允许共存（共存风险：两个应用抢同一个 socket） |

### 与 CodeIsland 共存冲突

**重要**：如果用户已经装了 CodeIsland app，它占用 `/tmp/codeisland-<uid>.sock`，我们占用 `~/.aiyuterm/hook.sock`，**socket 路径不冲突**。但 `~/.claude/settings.json` 里两方都会注入 hook。解决方案：

- AiyuTerm 只管理带 `aiyuterm-` 前缀的 hook 条目
- CodeIsland 管理带 `codeisland` 前缀的 hook 条目
- Claude Code 会依次调用每个 hook，两者互不干扰（只是每个事件触发两次）
- Phase 4 文档里说明：两方共存时性能略有影响但功能正常

## 数据库/文件副作用

**有**。本阶段会：
- 写入新文件 `~/.aiyuterm/hooks/claude-code-bridge-hook.sh`
- 修改 `~/.claude/settings.json`（新增 9 个 hook 条目）
- 启用时弹窗告知用户

**执行说明**:
1. 用户首次启动带 Phase 4 代码的 AiyuTerm 会弹窗请求启用
2. 同意后脚本和 settings.json 变更立即生效
3. 用户可以随时在设置里关闭，老 hook 恢复主导
4. 升级到 Phase 7 后老 hook 才会被彻底删除

**脚本路径**:
- `~/.aiyuterm/hooks/claude-code-bridge-hook.sh`（新增）
- `~/.aiyuterm/hooks/agent-status-notify.sh`（旧有，保留）
