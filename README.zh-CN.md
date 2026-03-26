# Liney

[English Version](./README.md)

[![Website](https://img.shields.io/badge/Website-liney.dev-111111?style=flat-square)](https://liney.dev)
[![Releases](https://img.shields.io/badge/Download-GitHub%20Releases-24292f?style=flat-square&logo=github)](https://github.com/wuwenrui/liney/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS-black?style=flat-square)](https://liney.dev)
[![License](https://img.shields.io/badge/License-Apache%202.0-2ea44f?style=flat-square)](./LICENSE)

Liney 是一款原生 macOS 终端工作区应用，面向需要在多个仓库、worktree、分支和分屏之间高频切换的开发者。

它为你提供一个专注的工作空间，用来打开代码库、切换 worktree、保留终端布局，并在无需同时管理一堆 Terminal 窗口的情况下更高效地工作。

![Liney 应用截图](./images/screenshot.png)

## 为什么使用 Liney

- 在一个侧边栏中管理多个仓库和 worktree。
- 回到某个仓库时，重新打开之前的分屏布局。
- 混合使用本地 shell、SSH 和 agent 驱动的终端会话。
- 在一个围绕键盘高频操作设计的原生 macOS 应用中完成工作。

## 安装

### Homebrew

```bash
brew update && brew install --cask wuwenrui/tap/liney
```

### 直接下载

从 GitHub Releases 下载最新已签名的 `.dmg`：

<https://github.com/wuwenrui/liney/releases/latest>

## 快速开始

1. 打开 Liney。
2. 向侧边栏添加一个或多个本地仓库。
3. 选择一个仓库或 worktree，并打开一个终端标签页。
4. 按需拆分面板，并在切换 worktree 时无需从头重建布局。

## 系统要求

- macOS 15.6 或更高版本
- Apple Silicon Mac

## 相关链接

- Website: <https://liney.dev>
- Releases: <https://github.com/wuwenrui/liney/releases>
- Issues: <https://github.com/wuwenrui/liney/issues>
- Discord: <https://discord.com/invite/eGzEaP6TzR>

## 面向开发者

开发环境配置、构建命令、测试方式、仓库结构以及发布文档位于 [`DEVELOP.md`](./DEVELOP.md)。

## 许可证

本项目基于 Apache License 2.0 发布。详见 [`LICENSE`](./LICENSE)。
