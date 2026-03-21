# Liney 仓库协作指南

## 项目概览

Liney 是一个原生 macOS 终端工作区应用，技术栈是 `AppKit + SwiftUI + libghostty`。
当前代码已经从早期的根级 Swift Package 结构迁移到 Xcode 工程布局，主要交互围绕多仓库 sidebar、worktree 切换和多 pane 终端会话展开。

## 目录结构

- `Liney/`：应用源码根目录。
- `Liney/App/`：应用级状态与入口装配，重点看 `WorkspaceStore.swift`。
- `Liney/Domain/`：工作区、worktree、pane layout 的领域模型。
- `Liney/Persistence/`：工作区状态持久化与迁移。
- `Liney/Services/Git/`：git 仓库检查、fetch、worktree 操作。
- `Liney/Services/Process/`：子进程执行封装。
- `Liney/Services/Terminal/`：Ghostty runtime、terminal surface、session backend。
- `Liney/Support/`：主题、菜单、路径格式化和通用支持代码。
- `Liney/UI/Components/`：状态栏和复用 UI 组件。
- `Liney/UI/Sheets/`：创建 worktree、SSH、agent session 等弹窗。
- `Liney/UI/Sidebar/`：左侧工作区树，核心文件是 `WorkspaceSidebarView.swift`。
- `Liney/UI/Workspace/`：右侧工作区详情、split panes、terminal pane UI。
- `Liney/Vendor/`：vendored `GhosttyKit.xcframework`。
- `Tests/`：当前单元测试。
- `RELEASING.md`：维护者发布说明。
- `scripts/`：macOS app bundle / release 脚本。

## 工程与构建

优先使用仓库根目录的 Xcode 工程：

```sh
xcodebuild \
  -project Liney.xcodeproj \
  -scheme Liney \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

补充说明：

- 当前协作默认使用仓库根目录的 `Liney.xcodeproj`。
- 发布脚本位于 `scripts/build_macos_app.sh` 和 `scripts/release_macos.sh`，它们依赖额外的发布输入和签名环境，不适合作为日常改动后的最小验证命令。

## 测试与验证

- UI 或状态管理改动后，至少执行一次 `xcodebuild ... build`。
- git / worktree / layout 逻辑改动时，优先查看并补充 `Tests/` 下对应单元测试。
- 涉及 sidebar、pane 布局、worktree 操作或发版流程时，补充必要的手工 smoke test，并在结果里写清覆盖范围。

## 代码热点

- `Liney/App/WorkspaceStore.swift`：大多数用户动作的入口，包含新增仓库、切换 worktree、创建 pane、刷新仓库等编排逻辑。
- `Liney/UI/Sidebar/WorkspaceSidebarView.swift`：左侧树形列表、搜索、上下文菜单、多选与拖拽排序。
- `Liney/UI/Workspace/WorkspaceDetailView.swift`：右侧工作区详情与 pane 容器。
- `Liney/Services/Git/GitRepositoryService.swift`：git 状态解析与仓库检查。
- `Liney/Services/Terminal/`：会话启动与 Ghostty bridge；改这里前先确认不会破坏现有 AppKit 集成。

## 修改约定

- 保持现有的 `AppKit 容器 + SwiftUI 内容` 模式，不要为了小改动重写整块 UI 架构。
- sidebar 是自定义 `NSOutlineView` 桥接，改动时注意不要破坏多选、右键菜单、键盘操作和拖拽重排。
- 终端相关代码默认依赖 vendored `libghostty`，不要引入新的备用终端实现。
- 没有明确需求时，不要修改 `Vendor/` 下的二进制依赖。
- 如果文档中的目录结构、命令或测试路径因代码变更失效，更新对应文档，避免继续漂移。
