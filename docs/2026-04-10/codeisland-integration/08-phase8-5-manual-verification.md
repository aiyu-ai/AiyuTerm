# Phase 8.5 - Notch Panel 手工验收指南

> **前置**: Phase 8.1-8.4 已合入 `feat/codeisland-integration`。共 183 个单元测试全部通过。
>
> **目的**: 验证 `AppSettings.notchPanelEnabled` 开关能正确拉起 / 关闭 `AgentNotchPanelController` 及其托管的 `AgentNotchPanelView`，并且在 AiyuTerm 侧边栏 agent 状态变化时，notch 面板能同步呈现。

## 前置条件

| 项 | 要求 |
|----|------|
| 分支 | `feat/codeisland-integration` HEAD |
| 硬件 | 任何 macOS 14.6+；MacBook 有刘海最佳，外接显示器 / 无刘海机型走模拟宽度 |
| Claude Code CLI | 可选。不需要就能验收折叠态；验收 pendingCount 需要真实 permission request |

## 步骤

### 1. Debug build + 启动

```bash
cd /Users/wuwenrui/Desktop/code/junfeng/AiyuTerm
git checkout feat/codeisland-integration
xcodebuild -project AiyuTerm.xcodeproj -scheme AiyuTerm \
           -configuration Debug -destination 'platform=macOS' build
APP=$(find ~/Library/Developer/Xcode/DerivedData -name 'AiyuTerm.app' -path '*/Debug/*' | head -1)
open "$APP"
```

### 2. 打开 Settings，定位 notch 开关

1. `Cmd+,` 打开 Settings sheet
2. 选 **General** tab
3. 在 Behavior GroupBox 里找到 **"Show agent activity in the notch"** 开关（位于 `Show archived workspaces` 下面）

**期望**: 开关默认关闭。

### 3. 开启 notch 面板

勾选 **"Show agent activity in the notch"** 开关。

**期望**:
- [ ] 刘海/屏顶区域**立即**出现一个黑色药丸形状的小面板
- [ ] 面板居中于刘海宽度（MacBook Pro）或屏幕顶部中央（外接 / 无刘海机型）
- [ ] 面板里显示一个 `moon.stars.fill` 图标（灰色，代表 idle）
- [ ] 关闭 Settings sheet 后面板仍然在
- [ ] 在其他 app 里切换 Space 时面板跟随出现（`.canJoinAllSpaces`）
- [ ] 进入全屏模式时面板仍然可见（`.fullScreenAuxiliary`）

### 4. 点击面板展开

单击黑色药丸。

**期望**:
- [ ] 面板区域展示一个 380×260 的圆角 material 卡片
- [ ] 顶部标题 `AiyuTerm Agents` + 右侧 X 关闭按钮
- [ ] 内容区显示 `No active agents` + 月亮图标（因为没有活动的 agent）
- [ ] 点 X 或再次点击折叠药丸可收起

### 5. 触发一个工作中的 agent 验证 collapsed 图标

在任意 worktree 里启动 Claude Code 并提交一个 prompt：

```bash
cd /tmp/any-workspace
claude
> hello
```

**期望**:
- [ ] notch 药丸左侧的 `moon.stars.fill` 图标**切换为一个白色小旋转 progress indicator**（对应 `AgentSessionStatus.working`）
- [ ] 展开面板时能看到一行 `{workspace name}` + `{worktree display name}` + 蓝色状态点
- [ ] Claude 执行完成后变为 `checkmark.circle.fill` 绿色图标（taskCompleted）

### 6. 触发一个 PermissionRequest 验证 pendingCount 徽章

让 Claude Code 调用一个需要权限的工具（如 `Bash(rm)`）。

**期望**:
- [ ] 面板药丸右侧出现一个**粉色小 capsule 徽章**，内容是 "1"
- [ ] 药丸图标变为 `hand.raised.fill`（粉色）
- [ ] 展开面板时对应 worktree 行右侧显示 `permission` 蓝色标签（或粉色，取决于主题）
- [ ] 侧边栏对应 worktree 行下方**同时**显示 Phase 6.2 的 permission bubble
- [ ] 在 AiyuTerm 侧边栏 bubble 里点 `Allow`
- [ ] 面板药丸图标变回 spinner（working），徽章消失

### 7. 关闭 notch 面板

回到 Settings，取消勾选 **"Show agent activity in the notch"**。

**期望**:
- [ ] 面板**立即**从屏幕上消失（无需重启）
- [ ] 再次勾选能重新显示
- [ ] 连续多次切换不会产生僵尸窗口、不会 crash

### 8. 多屏测试（可选）

如果接了外接显示器：
1. 把 AiyuTerm 主窗口拖到外接显示器
2. 切到一个在外接显示器上的其他 app（例如 Finder）

**期望**:
- [ ] notch 面板自动**跟随到外接显示器的顶部**
- [ ] 拔掉外接显示器时面板迁移回内建显示器
- [ ] `NSApplication.didChangeScreenParametersNotification` 触发时无 crash

### 9. 重启持久化

1. 勾选开关让面板显示
2. Cmd+Q 退出 AiyuTerm
3. 重启 AiyuTerm

**期望**:
- [ ] `~/.aiyuterm-debug/settings.json` (Debug) 或 `~/.aiyuterm/settings.json` (Release) 里 `notchPanelEnabled` 为 `true`
- [ ] 重启后面板自动出现，无需再次手动开启

---

## 已知限制

| 限制 | 说明 | 后续 |
|------|------|------|
| Notch 面板状态不自动刷新 | Phase 8.4 `refreshNotchPanelState()` 只在初次 show 时调用，没有订阅 WorkspaceModel 的 `@Published` 更新 | 下个 P8.6 补一个 ObservedObject 桥接 |
| "Allow Always" 和 "Allow Once" JSON 响应一致 | 共用 allow-once 负载 | Phase 6.3 的 rule editor TODO |
| 英文 Settings label 没本地化 | 直接用英文字面量 | 后续补 L10n |
| Hover-to-expand 未实现 | 必须点击才能展开 | 下一版 |

## 验收完成

如果 1-9 全部符合预期，在 PR 描述里记录:

```
Phase 8.5 manual verification: PASSED on <date>
  - Settings toggle drives show/hide
  - Collapsed pill renders per status
  - Expanded card renders per-worktree rows
  - Multi-screen migration works
  - Persistence across restart verified
```

Phase 8 至此完整闭环，整个 CodeIsland 合并方案的 8 个 Phase 全部落地。
