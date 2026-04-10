# Phase 8: Dynamic Island 刘海悬浮面板

> 预计工作量: 3-5 天
> 前置依赖: Phase 1-7 完成
> 后续阶段: 无（最终 UX 闭环）

## 目标

把 CodeIsland 的 Dynamic Island 悬浮面板深度缝合进 AiyuTerm，作为**全局 Agent 活动中心**：

1. 在 MacBook 刘海两侧展开的 `NSPanel` 面板
2. 折叠态显示当前活动 session 的聚合状态（药丸形状）
3. 展开态显示所有 worktree 的 agent 活动列表 + 工具历史 + 权限审批快捷入口
4. 自动检测内建显示器的刘海位置，外接显示器 fallback 到模拟宽度
5. 订阅 `WorkspaceModel` 的聚合状态，**不重复维护 AppState**
6. 可选的像素动画效果（开关控制）

## 源文件映射表

| 源（CodeIsland） | 目标（AiyuTerm） | 行数 | 改造重点 |
|-----------------|-----------------|------|---------|
| `Sources/CodeIsland/NotchPanelView.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchPanelView.swift` | 2045 | 数据源从 `AppState` 改为 `WorkspaceStore`；删除 mascot/sound 依赖 |
| `Sources/CodeIsland/PanelWindowController.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchPanelController.swift` | 596 | 保持 `NSPanel` 层级逻辑；接入 AiyuTerm 生命周期 |
| `Sources/CodeIsland/ScreenDetector.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchScreenDetector.swift` | ~200 | 完整保留，只改命名 |
| `Sources/CodeIsland/IslandCollapsedView.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchCollapsedView.swift` | 176 | 绑定 `workspace.aggregatedAgentStatus` |
| `Sources/CodeIsland/IslandExpandedView.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchExpandedView.swift` | 527 | 绑定 `workspace.worktrees` 列表 |
| `Sources/CodeIsland/IslandPixelAnimation.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchPixelAnimation.swift` | 351 | 可选保留，默认关闭 |
| `Sources/CodeIsland/IslandContentView.swift` | `AiyuTerm/UI/NotchPanel/AgentNotchContentRouter.swift` | 40 | 内容路由 |

**不移植**:
- 吉祥物 per-CLI 图像资源（`Resources/mascots/*`）—— 产品方向不符
- 8-bit 音效（`Resources/sounds/*`）—— 产品方向不符
- `IslandNotificationState.swift` 里的通知历史持久化 —— AiyuTerm 已有聚合机制

## 核心设计

### D8.1: 数据源解耦

CodeIsland 的 `NotchPanelView` 深度依赖 `@ObservedObject private var appState: AppState`（CodeIsland `NotchPanelView.swift` 顶部）。我们改为：

```swift
struct AgentNotchPanelView: View {
    @EnvironmentObject var store: WorkspaceStore
    @EnvironmentObject var appSettings: AppSettings

    private var visibleWorkspaces: [WorkspaceModel] {
        store.workspaces.filter { !$0.worktrees.isEmpty }
    }

    private var aggregatedStatus: AgentSessionStatus {
        let statuses = visibleWorkspaces.map { $0.aggregatedAgentStatus }
        return AgentSessionStatus.highestPriority(in: statuses)
    }

    private var pendingPermissionCount: Int {
        visibleWorkspaces.reduce(0) { $0 + $1.pendingPermissionRequests.count }
    }

    var body: some View {
        if isCollapsed {
            AgentNotchCollapsedView(status: aggregatedStatus, pendingCount: pendingPermissionCount)
        } else {
            AgentNotchExpandedView(workspaces: visibleWorkspaces)
        }
    }
}
```

**关键**: 不引入新的 state store，复用现有 `WorkspaceStore`。

### D8.2: NSPanel 层级

CodeIsland 用 `NSPanel` 设置为 `statusBar` 层级（`PanelWindowController.swift` 里的 `window.level = .statusBar + 1`）。AiyuTerm 移植时需要：

- **层级**: `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)))` 或 `.floating`
- **ignoresMouseEvents**: false（需要交互）
- **hasShadow**: false（避免遮住菜单栏）
- **isOpaque**: false
- **backgroundColor**: `.clear`
- **collectionBehavior**: `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`
- **styleMask**: `[.borderless, .nonactivatingPanel]`（点击不抢焦点）

### D8.3: 刘海检测

完整保留 `ScreenDetector.swift` 的逻辑：

```swift
enum AgentNotchScreenDetector {
    static func notchFrame(for screen: NSScreen) -> CGRect? {
        // macOS 12+: screen.safeAreaInsets.top > 0 表示有刘海
        if screen.safeAreaInsets.top > 0 {
            let width = screen.auxiliaryTopLeftArea?.width ?? 200
            let origin = CGPoint(
                x: screen.frame.midX - width / 2,
                y: screen.frame.maxY - screen.safeAreaInsets.top
            )
            return CGRect(origin: origin, size: CGSize(width: width, height: screen.safeAreaInsets.top))
        }
        // 无刘海屏幕：模拟一个固定宽度的区域
        let simulated = CGSize(width: 220, height: 32)
        let origin = CGPoint(
            x: screen.frame.midX - simulated.width / 2,
            y: screen.frame.maxY - simulated.height
        )
        return CGRect(origin: origin, size: simulated)
    }
}
```

### D8.4: 展开/折叠动画

折叠态 -> 展开态通过 `NSPanel` 的 `setFrame(_:display:animate:)` 驱动：

```swift
func expand() {
    guard let screen = NSScreen.main,
          let notchFrame = AgentNotchScreenDetector.notchFrame(for: screen) else { return }
    let expandedSize = CGSize(width: 480, height: 340)
    let newFrame = CGRect(
        x: notchFrame.midX - expandedSize.width / 2,
        y: notchFrame.minY - expandedSize.height,
        width: expandedSize.width,
        height: expandedSize.height
    )
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.22
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window?.animator().setFrame(newFrame, display: true)
    }
    isExpanded = true
}
```

## 详细步骤

### 8.1 创建目录 + vendor 文件

1. 创建 `AiyuTerm/UI/NotchPanel/`
2. 从 `/tmp/codeisland-research/Sources/CodeIsland/` 复制 7 个文件
3. 逐文件重命名类型（`Island*` -> `AgentNotch*`）
4. 删除所有对 `AppState`、`SoundManager`、`MascotManager` 的引用
5. 文件头添加 MIT 署名段（对齐 Phase 1 的格式）

### 8.2 AgentNotchPanelController

接入 AiyuTerm 生命周期：

```swift
@MainActor
final class AgentNotchPanelController: NSObject {
    private var window: NSPanel?
    private var hostingView: NSHostingView<AgentNotchPanelView>?
    private weak var store: WorkspaceStore?
    private weak var settings: AppSettings?

    init(store: WorkspaceStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        super.init()
    }

    func showIfEnabled() {
        guard settings?.notchPanelEnabled == true else {
            hide()
            return
        }
        if window == nil {
            createWindow()
        }
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        // ... NSPanel config from D8.2
    }
}
```

### 8.3 AppSettings 新增开关

`AiyuTerm/Domain/AppSettings.swift`:

```swift
@Published var notchPanelEnabled: Bool = false  // 默认关闭，用户主动开启
@Published var notchPanelPixelAnimationEnabled: Bool = false
@Published var notchPanelCollapsedWidth: Double = 220
@Published var notchPanelExpandedWidth: Double = 480
@Published var notchPanelExpandedHeight: Double = 340
```

### 8.4 WorkspaceStore 接入

```swift
// WorkspaceStore.swift
private var notchPanelController: AgentNotchPanelController?

func ensureNotchPanelIfEnabled() {
    guard notchPanelController == nil else {
        notchPanelController?.showIfEnabled()
        return
    }
    notchPanelController = AgentNotchPanelController(store: self, settings: appSettings)
    notchPanelController?.showIfEnabled()
}
```

在 `loadIfNeeded()` 末尾调用 `ensureNotchPanelIfEnabled()`。

设置开关变化时监听并调用 `showIfEnabled()` / `hide()`。

### 8.5 设置页新增 Notch Panel 标签

```swift
struct SettingsNotchPanelView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Enable notch panel", isOn: $settings.notchPanelEnabled)
            } footer: {
                Text("Show a floating panel at the top of the screen for quick access to agent activity.")
            }

            Section(header: Text("Size")) {
                HStack {
                    Text("Collapsed width")
                    Spacer()
                    TextField("", value: $settings.notchPanelCollapsedWidth, format: .number)
                        .frame(width: 60)
                }
                HStack {
                    Text("Expanded width")
                    Spacer()
                    TextField("", value: $settings.notchPanelExpandedWidth, format: .number)
                        .frame(width: 60)
                }
                HStack {
                    Text("Expanded height")
                    Spacer()
                    TextField("", value: $settings.notchPanelExpandedHeight, format: .number)
                        .frame(width: 60)
                }
            }

            Section(header: Text("Effects")) {
                Toggle("Pixel art animation", isOn: $settings.notchPanelPixelAnimationEnabled)
            }
        }
        .disabled(!settings.notchPanelEnabled)
    }
}
```

### 8.6 AgentNotchCollapsedView

绑定聚合状态：

```swift
struct AgentNotchCollapsedView: View {
    let status: AgentSessionStatus
    let pendingCount: Int

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            if pendingCount > 0 {
                Text("\(pendingCount)")
                    .font(.caption2).bold()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.black.opacity(0.85))
        )
        .foregroundColor(.white)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .working:
            ProgressView().controlSize(.small).tint(.white)
        case .permissionNeeded:
            Image(systemName: "hand.raised.fill").foregroundColor(.pink)
        case .taskCompleted:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
        case .none:
            Image(systemName: "moon.stars.fill").foregroundColor(.gray)
        }
    }
}
```

### 8.7 AgentNotchExpandedView

展开面板列出所有 worktree：

```swift
struct AgentNotchExpandedView: View {
    let workspaces: [WorkspaceModel]
    @EnvironmentObject var store: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(workspaces) { workspace in
                        workspaceSection(workspace)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 480, height: 340)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 10)
        )
    }

    private var header: some View {
        HStack {
            Text("AiyuTerm Agents")
                .font(.headline)
            Spacer()
            Button(action: { /* close */ }) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    @ViewBuilder
    private func workspaceSection(_ workspace: WorkspaceModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workspace.name)
                .font(.subheadline).bold()
            ForEach(workspace.worktrees, id: \.path) { worktree in
                worktreeRow(workspace: workspace, worktree: worktree)
            }
        }
    }

    @ViewBuilder
    private func worktreeRow(workspace: WorkspaceModel, worktree: WorktreeModel) -> some View {
        HStack {
            Text(worktree.displayName)
            Spacer()
            // Status badge + permission button
            if let request = workspace.pendingPermissionRequests[worktree.path] {
                HStack(spacing: 4) {
                    Button("Allow") {
                        store.approvePermission(forWorktreePath: worktree.path, mode: .once)
                    }
                    .controlSize(.mini)
                    Button("Deny") {
                        store.denyPermission(forWorktreePath: worktree.path)
                    }
                    .controlSize(.mini)
                }
            } else {
                badgeFor(status: workspace.agentStatus(forWorktreePath: worktree.path))
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func badgeFor(status: AgentSessionStatus) -> some View {
        // reuse AgentStatusOverlayBadge or a compact variant
        Text(statusLabel(status))
            .font(.caption2)
            .foregroundColor(statusColor(status))
    }
}
```

### 8.8 多屏幕处理

CodeIsland 的 `ScreenDetector` 会监听 `NSApplication.didChangeScreenParametersNotification`。移植时：

```swift
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        self?.relocateToPrimaryNotch()
    }
}
```

### 8.9 点击外部关闭

```swift
private var clickOutsideMonitor: Any?

func installClickOutsideMonitor() {
    clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
        matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
        guard let self, self.isExpanded else { return }
        let location = NSEvent.mouseLocation
        if let frame = self.window?.frame, !frame.contains(location) {
            Task { @MainActor in self.collapse() }
        }
    }
}
```

### 8.10 单元测试

```swift
final class AgentNotchScreenDetectorTests: XCTestCase {
    func testNotchFrameForNotchScreen() {
        // Mock NSScreen with safeAreaInsets.top > 0
    }

    func testFallbackForExternalScreen() {
        // Mock screen without notch, verify simulated rect
    }
}

final class AgentNotchPanelViewTests: XCTestCase {
    func testAggregatedStatusPrioritizesPermission() {
        // Snapshot test
    }

    func testPendingCountReflectsWorkspaces() {
        // ...
    }
}
```

## 验收检查清单

- [ ] 7 个 UI 文件编译通过
- [ ] 设置页新增 "Notch Panel" 标签
- [ ] 开关默认关闭，开启后面板出现
- [ ] MacBook Pro 刘海屏幕上面板居中于刘海下方
- [ ] 外接显示器上面板居中于屏幕顶部
- [ ] 折叠态显示聚合状态（spinner / 绿点 / 粉点）
- [ ] 有 pending permission 时折叠态显示数字徽章
- [ ] 点击折叠态展开为列表
- [ ] 列表中每个 worktree 显示状态 badge
- [ ] pending permission 的 worktree 行显示 Allow/Deny 按钮
- [ ] 点 Allow/Deny 通过 `WorkspaceStore` 分发响应
- [ ] 点击面板外部自动折叠
- [ ] 屏幕切换（插拔显示器）时面板自动迁移
- [ ] 关闭开关后面板立即隐藏
- [ ] 像素动画开关独立控制，默认关闭
- [ ] 单元测试通过

## 回滚步骤

1. 设置 `notchPanelEnabled = false`
2. 删除 `AiyuTerm/UI/NotchPanel/` 目录
3. 回滚 `WorkspaceStore` 的 `ensureNotchPanelIfEnabled` 改动
4. 回滚 `AppSettings` 的 5 个新字段

## 风险与应对

| 风险 | 等级 | 应对 |
|------|------|------|
| NSPanel 层级在全屏应用下消失 | 高 | `collectionBehavior` 加 `.fullScreenAuxiliary` |
| 多屏切换时面板失踪 | 中 | `didChangeScreenParametersNotification` 监听 |
| 菜单栏被遮挡 | 高 | 面板 y 位置限制在 `screen.frame.maxY - safeAreaInsets.top` 下方 |
| 权限审批按钮被 AiyuTerm 主窗口遮挡 | 中 | 面板层级设为 `.statusBar`，高于普通窗口 |
| 和 macOS 自带 Dynamic Island（Stage Manager）冲突 | 低 | 没有冲突，macOS 不是全局刘海 |
| 和 Raycast/Alfred 等工具的 statusBar 面板重叠 | 中 | 面板居中刘海，通常不冲突；提供位置偏移设置 |
| 点击面板后焦点被抢 | 高 | `.nonactivatingPanel` + `becomesKeyOnlyIfNeeded = true` |

## 数据库/文件副作用

**无**。Phase 8 不写磁盘，只管理运行时 NSPanel 窗口。

## UX 设计参考

CodeIsland 的折叠态大致像这样（宽度随刘海变化）：

```
┌─────────────────────────┐
│  ⚙  AiyuTerm  [3]      │  <- 折叠态：3 = pending permission 数
└─────────────────────────┘
```

展开态：

```
┌──────────────────────────────────┐
│  AiyuTerm Agents             ✕   │
├──────────────────────────────────┤
│  project-alpha                    │
│    main          ⚡ working       │
│    feature-a     ✓ completed      │
│    bugfix-b      ⚠ needs approve  │
│                  [Allow] [Deny]   │
│                                   │
│  project-beta                     │
│    main          · idle           │
└──────────────────────────────────┘
```

## 成功标准

- [ ] 用户开启开关后，一眼能看到所有 worktree 的 agent 活动
- [ ] 不打开主窗口就能响应权限请求
- [ ] 不影响 AiyuTerm 主窗口或其他 macOS 应用的使用
- [ ] 移动鼠标到刘海时优雅展示（可选 hover 展开）
- [ ] 锁屏/睡眠后恢复时面板自动恢复

> **闭环**: Phase 8 完成后，AiyuTerm 的 Agent 交互能力已经全面覆盖：sidebar badge（常驻视图）+ 面板气泡（细粒度操作）+ 刘海面板（全局瞥一眼 + 快捷审批）。从"Claude Code 终端"到"多 Agent 工作台"的底层升级和上层表达形成完整矩阵。
