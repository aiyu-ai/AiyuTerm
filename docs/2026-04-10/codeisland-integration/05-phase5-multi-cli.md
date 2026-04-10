# Phase 5: 多 CLI 支持（Codex / Gemini / Cursor / Copilot / ...）

> 预计工作量: 2-3 天
> 前置依赖: Phase 1-4 完成并稳定运行
> 后续阶段: Phase 6

## 目标

把 AiyuTerm 从"只支持 Claude Code"升级为"支持 9 种主流 Agent CLI"：

1. 移植 CodeIsland 的 `ConfigInstaller.swift` 为 `AgentCLIConfigInstaller.swift`
2. 为 Codex / Gemini / Cursor / Copilot 等 CLI 安装各自格式的 hook
3. 新增设置页 "Agents" 标签，显示每个 CLI 的检测状态和开关
4. 实现 `verifyAndRepair`，启动时自动修复被其他工具覆盖的配置
5. 支持 OpenCode 的 JS 插件（可选，产品评估）

## 支持的 CLI 列表

来自 `ConfigInstaller.swift:52-191`（file:line 已验证）：

| # | CLI | source tag | config path (相对 $HOME) | format | 行数 |
|---|-----|-----------|-------------------------|--------|------|
| 1 | Claude Code | `claude` | `.claude/settings.json` | `.claude` | `:55-57` |
| 2 | Codex | `codex` | `.codex/hooks.json` | `.nested` | `:80-82` |
| 3 | Gemini | `gemini` | `.gemini/settings.json` | `.nested` | `:93-95` |
| 4 | Cursor | `cursor` | `.cursor/hooks.json` | `.flat` | `:107-109` |
| 5 | Qoder | `qoder` | `.qoder/settings.json` | `.claude` | `:125-127` |
| 6 | Factory (droid) | `droid` | `.factory/settings.json` | `.claude` | `:143-145` |
| 7 | CodeBuddy | `codebuddy` | `.codebuddy/settings.json` | `.claude` | `:161-163` |
| 8 | Copilot | `copilot` | `.copilot/hooks/codeisland.json` | `.copilot` | `:179-181` |
| 9 | OpenCode | `opencode` | `.config/opencode/plugins/codeisland.js` | JS 插件 | `:225-227` |

## Hook 格式差异（`ConfigInstaller.swift:17-26`）

| 格式 | 使用者 | 结构 |
|------|--------|------|
| `.claude` | Claude, Qoder, Factory, CodeBuddy | `[{matcher, hooks: [{type, command, timeout, async}]}]` |
| `.nested` | Codex, Gemini | `[{hooks: [{type, command, timeout}]}]`（无 matcher）|
| `.flat` | Cursor | `[{command: "..."}]` |
| `.copilot` | Copilot CLI | `[{type, bash, timeoutSec}]` 加顶层 `version` |

## 详细步骤

### 5.1 新建 `AgentCLIConfigInstaller.swift`

基础蓝本是 `ConfigInstaller.swift:1-856`，逐段移植。重命名清单：

| 原（file:line）| 新 |
|--------------|-----|
| `HookId.current = "codeisland"` (`ConfigInstaller.swift:6`) | `HookId.current = "aiyuterm-bridge"` |
| `HookId.legacy = ["vibenotch", ...]` (`ConfigInstaller.swift:7`) | 增加 `"codeisland"` 到 legacy 列表（迁移用户）|
| `~/.claude/hooks/codeisland-bridge` (`:44`) | bridge 安装位置改为 `AiyuTerm.app/Contents/Helpers/aiyuterm-hook-bridge`，运行时直接用绝对路径 |
| `~/.claude/hooks/codeisland-hook.sh` (`:45`) | `~/.aiyuterm/hooks/claude-code-bridge-hook.sh`（Phase 4 已创建） |
| `hookScript` 常量 (`:202-221`) | 移植 + 常量替换为 AiyuTerm 的 |
| `Bundle.appModule.url(...)` (`:786`) | `Bundle.main.url(...)` |
| `Logger(subsystem: "com.codeisland", ...)` | `Logger(subsystem: "com.aiyuai.aiyuterm", ...)` |

### 5.2 `CLIConfig` 结构

直接沿用 `ConfigInstaller.swift:29-41` 的 struct，字段不变：

```swift
struct AgentCLIConfig {
    let name: String
    let source: String
    let configPath: String  // relative to $HOME
    let configKey: String
    let format: HookFormat
    let events: [(name: String, timeout: Int, async: Bool)]
    let versionedEvents: [String: String]  // event -> min version

    var fullPath: String { NSHomeDirectory() + "/" + configPath }
    var dirPath: String { (fullPath as NSString).deletingLastPathComponent }
}
```

### 5.3 9 个 CLI 的配置表

完整拷贝 `ConfigInstaller.swift:52-191` 的 `allCLIs` 数组，只做 4 处替换：
1. `configPath` 里 CodeIsland 特有的 `.copilot/hooks/codeisland.json` 改为 `.copilot/hooks/aiyuterm.json`
2. `configPath` 里 OpenCode 特有的 `plugins/codeisland.js` 改为 `plugins/aiyuterm.js`
3. 事件列表完全保留（Claude 13 个事件 + 版本门控表）
4. 每个 CLI 的 `source` tag 不变（因为 bridge 解析时需要这个 tag）

### 5.4 安装/卸载入口

```swift
@MainActor
enum AgentCLIConfigInstaller {
    static let allCLIs: [AgentCLIConfig] = [ /* 9 entries */ ]

    /// Install hooks for all enabled CLIs. Called on app launch and when
    /// the user toggles a CLI on in Settings.
    @discardableResult
    static func install() -> [String] {
        var updated: [String] = []
        installBridgeBinary()
        installHookScript()
        for cli in allCLIs where isEnabled(source: cli.source) && cliExists(source: cli.source) {
            if installHooks(for: cli) {
                updated.append(cli.name)
            }
        }
        return updated
    }

    static func uninstall() {
        for cli in allCLIs {
            uninstallHooks(for: cli)
        }
        // Keep bridge binary in Contents/Helpers (it's inside the app bundle)
    }

    static func verifyAndRepair() -> [String] { ... }

    static func isEnabled(source: String) -> Bool {
        UserDefaults.standard.object(forKey: "aiyuterm.cli_enabled_\(source)") as? Bool ?? true
    }

    @discardableResult
    static func setEnabled(source: String, enabled: Bool) -> Bool { ... }
}
```

### 5.5 Codex / Gemini 的 `.nested` 格式安装

移植 `ConfigInstaller.swift:554-580` 的 `installNestedHooks(cli:fm:)` 函数。关键点：
- `.nested` 格式没有 `matcher` 字段
- 写入时用 `JSONSerialization.data(withJSONObject:options: [.prettyPrinted])`
- 先 `removeManagedHookEntries` 再追加（幂等）

### 5.6 Cursor 的 `.flat` 格式

移植 `ConfigInstaller.swift:582-615`。Cursor 的 hook 条目是最简结构：
```json
[
  {"command": "~/.aiyuterm/hooks/cursor-bridge-hook.sh"}
]
```
但 Cursor 的事件名不同（`beforeSubmitPrompt`, `beforeShellExecution` 等），这些已经在 `EventNormalizer` 里做了归一化（`EventNormalizer.swift:8-17`）。

### 5.7 Copilot 的 `.copilot` 格式

移植 `ConfigInstaller.swift` 里的 `installCopilotHooks`。Copilot 的 hook stdin 格式缺 `hook_event_name`，所以 bridge 要用 `--event` 参数注入：

```bash
#!/bin/bash
exec "~/Library/.../Contents/Helpers/aiyuterm-hook-bridge" --source copilot --event sessionStart
```

bridge 的 `main.swift:182-191` 已经处理了 `--source` 和 `--event` 参数，不需要改 bridge 代码。

### 5.8 OpenCode JS 插件（可选）

如果保留 OpenCode 支持：
1. 把 `Sources/CodeIsland/Resources/codeisland-opencode.js` 拷贝到 `AiyuTerm/Resources/aiyuterm-opencode.js`
2. Xcode 工程把它加到 Copy Bundle Resources
3. 移植 `installOpencodePlugin`（`ConfigInstaller.swift:784-825`）
4. JS 内容里的 socket 路径需要从 `/tmp/codeisland-*.sock` 改为 `~/.aiyuterm/hook.sock`

**推荐**: Phase 5 先不做 OpenCode，产品需求明确后再补。

### 5.9 设置页 UI

新建 `SettingsAgentsView.swift`（SwiftUI）：

```swift
struct SettingsAgentsView: View {
    @State private var cliStates: [CLIState] = []

    var body: some View {
        Form {
            Section(header: Text("Supported Agents")) {
                ForEach(cliStates) { state in
                    HStack {
                        Text(state.name)
                        Spacer()
                        if state.installed {
                            Text("Installed").foregroundColor(.green)
                        } else if state.cliExists {
                            Text("Not installed").foregroundColor(.orange)
                        } else {
                            Text("CLI not found").foregroundColor(.secondary)
                        }
                        Toggle("", isOn: Binding(
                            get: { state.enabled },
                            set: { newVal in toggle(state, newVal) }
                        ))
                        .disabled(!state.cliExists)
                    }
                }
            }

            Button("Repair all hooks") {
                let updated = AgentCLIConfigInstaller.verifyAndRepair()
                // show toast
            }
        }
        .onAppear(perform: refresh)
    }
}

struct CLIState: Identifiable {
    let id: String  // source tag
    let name: String
    let cliExists: Bool
    let installed: Bool
    let enabled: Bool
}
```

### 5.10 启动时自动修复

在 `WorkspaceStore.loadIfNeeded()` 里增加：

```swift
// Phase 5: auto-repair CLI hooks on launch
Task.detached(priority: .background) {
    let updated = await MainActor.run {
        AgentCLIConfigInstaller.verifyAndRepair()
    }
    if !updated.isEmpty {
        print("Auto-repaired CLIs: \(updated)")
    }
}
```

## 验收检查清单

- [ ] `AgentCLIConfigInstaller.swift` 编译通过
- [ ] `AgentCLIConfigInstaller.allCLIs` 包含 9 个 CLI
- [ ] 设置页 "Agents" 标签显示所有 CLI 和状态
- [ ] 安装 Codex（`brew install codex` 或已有）后，开关启用，能在 `~/.codex/hooks.json` 看到条目
- [ ] 安装 Gemini 后，能在 `~/.gemini/settings.json` 看到条目
- [ ] 运行 `codex ...` 触发 badge 更新
- [ ] 运行 `gemini ...` 触发 badge 更新
- [ ] 关闭某个 CLI 的开关后，对应 config 文件里的条目被删除
- [ ] `verifyAndRepair()` 单元测试通过
- [ ] 手动删除 `~/.codex/hooks.json` 后重启 AiyuTerm，能自动恢复

## 回滚步骤

1. 设置里关闭所有 CLI 的开关（除 Claude Code 之外）
2. 或者调用 `AgentCLIConfigInstaller.uninstall()`
3. 代码层 revert 本 Phase 的 commit
4. 手动清理残余文件：
   ```bash
   rm ~/.codex/hooks.json
   rm ~/.gemini/settings.json  # 或编辑删除 aiyuterm-bridge 段
   rm ~/.cursor/hooks.json
   rm ~/.copilot/hooks/aiyuterm.json
   ```

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| 误删用户其他工具的 hook | 极高 | 严格用 `aiyuterm-bridge` 前缀识别；加单元测试 |
| CLI 升级后格式变化 | 中 | `versionedEvents` 门控 + 启动时检测版本 |
| `Bundle.appModule` 在 Xcode 下不存在 | 高 | 用 `Bundle.main.url(forResource:withExtension:)` |
| JSONC 解析失败 | 中 | 移植 `stripJSONComments` (`ConfigInstaller.swift:384-433`)，失败时跳过该 CLI |
| 用户手动编辑 config 后冲突 | 中 | `isHooksInstalled` 检测不到就重装；尊重用户自定义部分 |
| 一次性注入 9 个 CLI 的 hook 过于激进 | 中 | 默认只启用 Claude，其他 CLI 开关默认关 |

## 数据库/文件副作用

**有**。本阶段会影响以下文件：

| 文件 | 操作 | 条件 |
|------|------|------|
| `~/.claude/settings.json` | 注入 13 个 hook 事件（升级自 Phase 4 的 9 个） | Claude 启用 |
| `~/.codex/hooks.json` | 创建并注入 hook 条目 | Codex 启用 |
| `~/.gemini/settings.json` | 注入 hook 条目 | Gemini 启用 |
| `~/.cursor/hooks.json` | 创建并注入 hook 条目 | Cursor 启用 |
| `~/.qoder/settings.json` | 注入 hook 条目 | Qoder 启用 |
| `~/.factory/settings.json` | 注入 hook 条目 | Factory 启用 |
| `~/.codebuddy/settings.json` | 注入 hook 条目 | CodeBuddy 启用 |
| `~/.copilot/hooks/aiyuterm.json` | 创建 | Copilot 启用 |
| `~/.config/opencode/plugins/aiyuterm.js` | 创建 | OpenCode 启用（可选） |
| `~/.aiyuterm/hooks/claude-code-bridge-hook.sh` | 更新 | 启动时 |

**用户告知**: 启用新 CLI 时弹窗说明会修改哪个配置文件。设置页提供 "Repair all hooks" 按钮和 "Uninstall all hooks" 按钮供用户自助。
