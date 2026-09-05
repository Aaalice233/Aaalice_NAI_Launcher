# 项目文档索引

按需要读取对应文档，不把历史发布记录当作当前实现或验证结果。

| 主题 | 入口 | 维护范围 |
|---|---|---|
| 用户说明 | [简体中文](../README.md)、[繁體中文](../README.zh-TW.md)、[English](../README.en-US.md) | 功能、平台、安装、隐私与支持；三份事实同步 |
| 工程协作 | [AGENTS.md](../AGENTS.md) | 结构、命令、代码边界、验证、资源与提交约定 |
| 产品边界 | [PRODUCT.md](../PRODUCT.md) | 用户、核心任务、能力与对外承诺 |
| 设计语言 | [DESIGN.md](../DESIGN.md) | 色面、排版、组件、交互与视觉验收标准 |
| 自适应实现 | [策略](design/adaptive_ui_strategy.md)、[覆盖清单](design/adaptive_ui_inventory.md) | 共享布局契约、代码入口和按任务建立的验收矩阵 |
| 测试 | [test/README.md](../test/README.md) | 受控测试入口、证据范围和运行验收的区别 |
| 开发会话 | [aaalice-dev-sessions](../.agents/skills/aaalice-dev-sessions/SKILL.md) | Windows/Android 热重载窗口的启动、复用与关闭 |
| 刷新应用 | [aaalice-hot-reload](../.agents/skills/aaalice-hot-reload/SKILL.md) | Reload、Restart、完整重建的选择与日志验证 |
| 自动化验收 | [aaalice-runtime-verify](../.agents/skills/aaalice-runtime-verify/SKILL.md) | 自动启动会话，Windows Computer Use、Android ADB 操作与视觉检查 |
| 云备份 | [协议与验证](cloud_sync.md)、[OAuth 配置](cloud_drive_oauth.md) | 持久化、传输、恢复、后端能力和平台注册 |
| 应用发布 | [aaalice-launcher-release](../.agents/skills/aaalice-launcher-release/SKILL.md) | 版本号、更新日志、发布检查与 tag |
| 标签数据 | [标签目录](../tool/tag_catalog/README.md)、[随机词库](../tool/random_tag_library/README.md) | 锁定来源、构建与校验 |
| Krita | [插件说明](../krita_plugin/README.md) | 安装、连接、隔离预检与真实联动验收 |
| Windows 拖放 | [OLE 检查器](../tool/ole_drag_inspector/README.md) | 格式检查与元数据保护回归 |
| CI 缓存 | [prepare-flutter-build](../.github/actions/prepare-flutter-build/README.md) | Flutter 构建层与缓存约束 |

`CLAUDE.md` 只引用 `AGENTS.md`，不复制规则。版本变化保留在 `CHANGELOG.md` 和正式发布记录；第三方归属保留在 `THIRD_PARTY_NOTICES.md`、`licenses/`。

文档描述规则、当前结构和可复现方法，不长期保存“本轮全部通过”、临时阻塞、个人机器结果或未执行的验收表。需要报告验证时，记录实际命令、代码版本、平台、场景与结果；本地产物放在 `tool/.tmp/`，不能由旧报告推断当前通过。
