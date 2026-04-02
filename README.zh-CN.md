# AiyuTerm

[English Version](./README.md)

[![Platform](https://img.shields.io/badge/Platform-macOS-black?style=flat-square)](https://github.com/AiyuAI/AiyuTerm)
[![License](https://img.shields.io/badge/License-Apache%202.0-2ea44f?style=flat-square)](./LICENSE)

AiyuTerm 是一款原生 macOS 终端工作区应用，面向需要频繁在多个仓库、worktree、分支和分屏之间切换的开发者。支持本地 shell、SSH、tmux 会话管理，以及 AI Agent 会话的实时状态提醒。

> AiyuTerm 基于 [Liney](https://github.com/everettjf/liney)（作者 everettjf）fork 而来，感谢原作者提供的优秀基础。

![AiyuTerm 应用截图](./images/screenshot.png)

## 功能特性

- 在同一个侧边栏里管理多个仓库和 worktree
- 回到某个仓库时，快速恢复上次使用的分屏布局
- 混合使用本地 shell、SSH 和 Agent 驱动的终端会话
- Tmux 会话管理面板（attach、创建、重命名、kill）
- Agent 状态徽章：Claude Code 权限请求和任务完成的实时通知
- 围绕键盘高频操作设计的原生 macOS 应用

## 安装

### 直接下载

从 GitHub Releases 下载最新已签名的 `.dmg`：

<https://github.com/AiyuAI/AiyuTerm/releases/latest>

## 快速开始

1. 打开 AiyuTerm
2. 向侧边栏添加一个或多个本地仓库
3. 选择一个仓库或 worktree，打开终端标签页
4. 按需拆分面板，切换 worktree 时继续沿用已有布局

## Agent 状态徽章

AiyuTerm 在侧边栏图标上实时显示 Claude Code 的状态：

| 状态 | 徽章 | 触发条件 |
|------|------|---------|
| 权限请求 | 红色脉冲 | Claude Code 等待用户批准 |
| 任务完成 | 绿色对勾 | Claude Code 完成了一个任务 |
| 错误 | 红色静态 | Claude Code 遇到错误 |

基于 Claude Code hooks 实现。详见 [docs/agent-status-badges.md](./docs/agent-status-badges.md)。

## 系统要求

- macOS 14.6 或更高版本
- 同时支持 Apple Silicon 和 Intel Mac

## 面向开发者

开发环境配置、构建命令、测试方式和发布流程：[`DEVELOP.md`](./DEVELOP.md)

## 致谢

- [Liney](https://github.com/everettjf/liney)（作者 everettjf）-- 本项目 fork 自该开源终端工作区应用
- [Ghostty](https://ghostty.org/) -- AiyuTerm 使用的终端引擎
- [Sparkle](https://sparkle-project.org/) -- 自动更新框架

## 许可证

本项目基于 Apache License 2.0 发布。详见 [`LICENSE`](./LICENSE)。
