# NAI Launcher

## What This Is

NAI Launcher 是一个 NovelAI 跨平台第三方客户端，使用 Flutter 构建，支持 Windows、Android 和 Linux。由于 NovelAI 官方网页体验不佳，本项目提供更高效、更本地化的 AI 绘图工作流程。

## Core Value

让用户能够稳定、高效地使用 NovelAI 进行图像生成，核心功能（图像生成、画廊管理、提示词管理）必须可靠运行。

## Requirements

### Validated

- ✓ 图像生成（文本到图像）— 现有功能
- ✓ Vibe Transfer（图像风格迁移）— 现有功能
- ✓ 本地画廊（SQLite 索引）— 现有功能
- ✓ Danbooru 在线画廊集成 — 现有功能
- ✓ 提示词系统（动态语法解析）— 现有功能
- ✓ 队列系统（批量生成任务）— 现有功能
- ✓ 快捷键系统 — 现有功能
- ✓ 词库/标签库管理 — 现有功能
- ✓ 随机词库（基础版）— 现有功能

### Active

- [ ] 界面优化和布局调整
- [ ] 性能优化
- [ ] 图像解析相关 Bug 修复（影响稳定性）
- [ ] 用户反馈的小功能需求
- [ ] 词库分组视图功能

### Out of Scope

- 其他 AI 绘图平台支持（如 Midjourney、Stable Diffusion WebUI）— 专注于 NovelAI
- 完整的图像编辑功能 — 生成为主，编辑为辅
- 社交/分享功能 — 非核心需求

## Context

**当前版本状态**: Beta 版本，已发布在 GitHub

**用户反馈重点**:
- 界面改进需求
- 性能优化需求
- 小功能增强
- Bug 修复（图像解析相关最影响稳定性）

**技术栈**: Flutter + Dart，Clean Architecture + DDD

**平台支持**: Windows（主要）、Android、Linux

## Constraints

- **Tech Stack**: Flutter 框架，需保持跨平台兼容性
- **API 依赖**: NovelAI API，受限于官方接口能力
- **Stability Goal**: 核心功能无恶性 Bug 后才进入 v1.0

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 专注 NovelAI 第三方客户端 | 官方体验差，有明确用户需求 | — Pending |
| 跨平台 Flutter | 一套代码覆盖多端 | ✓ Good |
| 本地优先设计 | 减少网络依赖，提升响应速度 | ✓ Good |

---

## Future Milestones

### v1.0 稳定版
- 修复图像解析相关 Bug
- 界面和性能优化完成
- 核心功能完善

### v2.0 功能扩展
- 完善 Danbooru 画廊（支持更多站点）
- 重构随机词库功能
- LLM 辅助提示词（多渠道支持 + 自定义渠道）
  - 自动生成提示词
  - Tag 扩写优化
  - 随机灵感生成

---
*Last updated: 2025-02-28 after project initialization*
