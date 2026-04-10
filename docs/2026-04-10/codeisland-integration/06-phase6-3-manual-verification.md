# Phase 6.3 - 手工端到端验收指南

> **前置**: Phase 6.1 (数据层 + continuation) 和 Phase 6.2 (Sidebar bubble UI) 已合入 `feat/codeisland-integration` 分支，共 151 个单元测试全部通过。
>
> **目的**: 验证一个真实的 Claude Code session 在向 AgentHookServer 发送 `PermissionRequest` 时，AiyuTerm 侧边栏能正确渲染 `AgentPermissionBubbleView`，且点击 Allow/Deny/Always 能正确把决策回传给 Claude Code，让用户不必切回终端 tab 就能完成权限审批。

---

## 前置条件

| 项 | 要求 |
|----|------|
| 分支 | `feat/codeisland-integration` HEAD (包含 Phase 1-6.2 所有 commit) |
| Xcode | 16+ with Metal toolchain |
| Claude Code CLI | 2.1.89+ (Phase 5.1 的 versionedEvents 表要求 PermissionDenied/PostToolUseFailure 在此版本后可用) |
| 其他 | 一个已 `git init` 的目录用作 worktree，例如 `/tmp/phase6-3-demo` |

## 步骤

### 1. 拉取分支并 Debug build

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git checkout feat/codeisland-integration
xcodebuild -project AiyuTerm.xcodeproj \
           -scheme AiyuTerm \
           -configuration Debug \
           -destination 'platform=macOS' build
```

验证产物:

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -name 'AiyuTerm.app' -path '*/Debug/*' | head -1)
ls -la "$APP/Contents/Helpers/aiyuterm-hook-bridge"  # should exist, ~290KB
```

### 2. 准备 demo worktree

```bash
mkdir -p /tmp/phase6-3-demo
cd /tmp/phase6-3-demo
git init -q
echo "# demo" > README.md
git add README.md
git commit -qm "seed"
```

### 3. 启动 AiyuTerm 并添加 worktree

1. 从 Xcode 启动 (Run) 或直接执行 `"$APP/Contents/MacOS/AiyuTerm"`。
2. 在 AiyuTerm 侧边栏按 `+` 添加 workspace，选择 `/tmp/phase6-3-demo`。
3. 确认侧边栏能看到 `phase6-3-demo` 这一行，下面有一个默认 worktree。

### 4. 确认 socket + hook 已安装

在另一个 macOS Terminal:

```bash
ls -la ~/.aiyuterm-debug/hook.sock  # should be a socket, owner rwx-only
cat ~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh | head -5  # bridge wrapper
grep -c "aiyuterm" ~/.claude/settings.json  # expect ≥ 13 entries
```

### 5. 手工注入一个 PermissionRequest (模拟 Claude Code)

这一步模拟 Claude Code 在 demo 目录内触发工具调用时，Claude Code hook runtime 会调用 `claude-code-bridge-hook.sh`:

```bash
cd /tmp/phase6-3-demo
echo '{
  "hook_event_name": "PermissionRequest",
  "session_id": "phase6-3-manual",
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /tmp/phase6-3-demo/generated",
    "description": "Delete generated files"
  },
  "cwd": "/tmp/phase6-3-demo"
}' | ~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh &
NC_PID=$!
```

**关键**: 不要 `wait` 或 fg —— bridge 会挂起等待 AiyuTerm 回应，我们要保留它的 stdin/stdout。

### 6. 验证气泡出现

在 AiyuTerm 里:

- [ ] 侧边栏 demo worktree 旁边的 badge 变成**粉色 permission pulse**
- [ ] 该 worktree 行下方**立即出现一个气泡**，内容是:
  - 标题: `Bash` (粉色手势图标 + 工具名)
  - 正文: `Delete generated files`（monospaced, 灰色）
  - 三个按钮: `Deny` / `Allow` (粉色 prominent) / `Always`

### 7. 点击 Allow, 验证 bridge 收到 allow JSON

在终端等待 bridge 进程:

```bash
wait $NC_PID  # bridge should exit shortly after you click Allow
```

bridge 应该已经把 `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}` 写到 stdout。如果终端会话是实时的，这个 JSON 会出现在 shell 里。

**期望**:
- [ ] AiyuTerm 气泡**消失**
- [ ] worktree badge 变回 `.working`（淡蓝色转圈，或者很快变回 idle）
- [ ] bridge 的 stdout 包含 `"behavior":"allow"`
- [ ] bridge 的 exit code 是 0

### 8. 重复测试 Deny 路径

```bash
echo '{
  "hook_event_name": "PermissionRequest",
  "session_id": "phase6-3-deny",
  "tool_name": "Bash",
  "tool_input": {"command": "rm -rf /"},
  "cwd": "/tmp/phase6-3-demo"
}' | ~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh
```

点击 `Deny`, 验证 bridge 输出 `"behavior":"deny"`, exit 0。

### 9. 测试 AskUserQuestion

```bash
echo '{
  "hook_event_name": "PermissionRequest",
  "session_id": "phase6-3-q",
  "tool_name": "AskUserQuestion",
  "tool_input": {
    "questions": [
      {
        "question": "Which directory to clean?",
        "options": ["src", "tests", "build"],
        "header": "Cleanup"
      }
    ]
  },
  "cwd": "/tmp/phase6-3-demo"
}' | ~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh
```

**期望**:
- [ ] 气泡标题变成 `Cleanup` (蓝色问号图标)
- [ ] 正文: `Which directory to clean?`
- [ ] 三个选项按钮 + 一个 Skip 小按钮
- [ ] 点 `src`, bridge stdout 包含 `"answers":[{"answer":"src","header":"Cleanup"}]`

### 10. 测试 peer disconnect

模拟 bridge 在用户决策前死亡:

```bash
echo '{
  "hook_event_name": "PermissionRequest",
  "session_id": "phase6-3-disconnect",
  "tool_name": "Bash",
  "tool_input": {"command": "sleep 999"},
  "cwd": "/tmp/phase6-3-demo"
}' | timeout 1 ~/.aiyuterm-debug/hooks/claude-code-bridge-hook.sh
```

`timeout 1` 会在 1 秒后 SIGTERM bridge。AgentHookServer 的 `stateUpdateHandler` 应该监听到 `.cancelled` 并调用 `handlePeerDisconnect`, 后者在 `AgentHookEventMapper` 里 drain continuation + 清空 workspace 的 pending 状态。

**期望**:
- [ ] 气泡在 1 秒内**自动消失**
- [ ] 没有僵尸气泡、没有 beach ball

---

## 失败时的调试线索

| 症状 | 可能原因 | 定位命令 |
|------|---------|---------|
| Socket 不存在 | AgentHookServer 启动失败 | `log show --predicate 'subsystem == "com.aiyuai.aiyuterm" AND category == "AgentHookServer"' --info --last 5m` |
| 气泡不出现但 bridge 已发送 | `cwd` 不匹配 worktree | 在 AiyuTerm 里确认 worktree path 精确匹配 `cwd`；路径符号链接 (`/tmp` vs `/private/tmp`) 是常见坑 |
| 气泡出现但点 Allow 后 bridge 挂住 | mapper 没调到 `resolvePermission` | 在 `AgentHookEventMapper.resolvePermission` 打断点或加 `logger.debug` |
| bridge stdout 为空 | bridge `recvAll` timeout | 检查 SO_RCVTIMEO: blocking events 应该是 86400s; 看 `AiyuTermHookBridge/main.swift:310-314` |
| 气泡出现但 bridge 立即 exit 1 | JSON 解析失败 | `AIYUTERM_HOOK_DEBUG=1` 重跑, 查 `/tmp/aiyuterm-hook-bridge.log` |

---

## 验收完成后

如果所有 10 个步骤都通过，在 commit message 或 PR 描述里留一条记录:

```
Phase 6.3 manual verification: PASSED on <date>
  - Allow / Deny / Always paths verified
  - AskUserQuestion option answer path verified
  - peer disconnect drain path verified
```

并把本文档的第 "## 失败时的调试线索" 段加入到 `CLAUDE.md` 或 `AGENTS.md` 作为未来 debug 参考。

Phase 6 至此完整闭环，Phase 7 可以启动（删除老的 `AgentStatusFilePoller` + 集成测试 + 清理迁移）。
