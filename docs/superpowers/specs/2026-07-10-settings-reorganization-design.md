# 设置页面分类重组设计

- 日期：2026-07-10
- 状态：待评审
- 范围：`lib/presentation/screens/settings/`、l10n ARB 词条、相关 widget 测试
- 决策人已确认：采用"重组为 9 类"方案；「集成」页采用页内子导航切换

## 背景与问题

当前设置页（`settings_screen.dart`）有 13 个平铺分类，存在四类问题：

1. **归类错位**：悬浮球背景图片在「队列」；保护模式全套 7 项在「存储」；在线画廊黑名单在「数据源」；本地 ONNX Tagger 目录混在「存储」的保存路径之间。
2. **粒度失衡**：「存储」承载 14+ 项，而「账号」「快捷键」各 1 项、「生成」「通知」各 2 项。
3. **命名与内容不符**：「生成」只有 2 个提示词输入行为开关；「通知」实际是队列完成提示音（由 `queue_execution_provider` 触发）。
4. **导航过长**：13 项平铺，检索成本高。

根因：分类按内部模块（队列、数据源）而非用户任务命名，代码结构泄漏到 UI。

## 目标

- 分类从 13 减到 9，每个分类语义自洽、名实相符。
- 所有设置项按"用户想改什么行为"归位，不改变任何设置的持久化 key 与行为。
- 导航可扫描性提升；集成类（Prompt Assistant / ComfyUI / Krita）合并后不产生超长滚动页。

## 非目标

- 不改动任何设置的存储格式、默认值、生效逻辑（纯 UI 信息架构重组，无数据迁移）。
- 不重做各设置项的控件样式。
- 不引入两级分组导航（NavigationRail 保持原生组件）。

## 新分类结构（9 类）

导航顺序按使用频率与任务流排列：

| # | 分类 | 图标 | 内容（→ 表示迁入来源） |
|---|------|------|------------------------|
| 1 | 账号 | `person` | 账户资料卡（不变） |
| 2 | 外观 | `palette` | 主题、字体、字号、语言、生成页布局（均不变）；**悬浮球背景图片 → 自「队列」** |
| 3 | 生成 | `tune` | 随机提示词工具、权重滚轮（不变）；**重试次数、重试间隔 → 自「队列」**；**完成提示音开关、自定义音效 → 自「通知」** |
| 4 | 数据与存储 | `storage` | 图片保存路径、自动保存、Vibe 库路径、Hive 路径、缓存统计、画廊缓存操作（不变）；本地 ONNX Tagger 目录（留守，属本地模型数据）；**Danbooru 标签缓存设置 → 自「数据源」** |
| 5 | 安全与分享 | `shield` | **保护模式总开关及 6 子项（脱敏元数据、危险操作确认、外发警告、防覆盖、高 Anlas 警告、阈值）→ 自「存储」**；**在线画廊黑名单 → 自「数据源」** |
| 6 | 网络 | `network_check` | 代理设置（不变） |
| 7 | 快捷键 | `keyboard` | 快捷键面板入口（不变；快捷键独立成类是桌面应用惯例） |
| 8 | 集成 | `extension` | Prompt Assistant / ComfyUI / Krita，页内子导航切换 |
| 9 | 关于 | `info` | 版本、检查更新、预发布开关、开源链接（不变）；文件日志（留守，理由见下） |

被撤销的分类：队列、通知、数据源、Prompt Assistant（独立项）、ComfyUI（独立项）、Krita（独立项）。

### 有意保留的"争议"归位

- **文件日志留在「关于」**：使用场景是排障链路（出问题 → 查版本 → 开日志 → 反馈），与"检查更新"同场景，不值得为 1 项新建"高级"分类。
- **生成页布局留在「外观」**：它决定生成页的视觉排布，与主题/字体同属"看起来什么样"。
- **ONNX Tagger 目录归「数据与存储」**：本质是"本地模型数据放在哪"，与 Vibe/Hive 路径同类。

### 「生成」页内顺序

按任务流排列：输入行为（随机工具、权重滚轮）→ 执行策略（重试次数、间隔）→ 完成反馈（提示音）。页内用三个小节标题分隔。

### 「集成」页交互

- 页顶放 `SegmentedButton`（三段：Prompt Assistant / ComfyUI / Krita），选中态显示对应面板，一次只渲染一块。
- 子导航选中项为页面内部临时状态（`StatefulWidget` 本地 state），默认选中第一段，不持久化。
- 现有三个 section widget（`prompt_assistant_settings_section.dart`、`comfyui_settings_section.dart`、`krita_bridge_settings_section.dart`）原样复用，仅由新容器引用。

## 文件级变更

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `settings_screen.dart` | sections 列表 13 → 9，更新图标与 l10n 引用 |
| 新建 | `sections/integrations_settings_section.dart` | SegmentedButton + 三面板容器 |
| 新建 | `sections/privacy_settings_section.dart` | 保护模式块 + 黑名单面板 |
| 修改 | `sections/generation_settings_section.dart` | 迁入重试 2 项与提示音 2 项，加小节标题 |
| 修改 | `sections/appearance_settings_section.dart` | 迁入悬浮球背景图片项 |
| 修改 | `sections/storage_settings_section.dart` | 移出保护模式块；迁入 `DataSourceCacheSettings`；文件名与类名保留，仅 UI 标题改用 `settings_dataStorage` |
| 删除 | `sections/queue_settings_section.dart` | 内容拆分至生成/外观 |
| 删除 | `sections/notification_settings_section.dart` | 内容并入生成 |
| 删除 | `sections/data_source_settings_section.dart` | 内容拆分至数据与存储/安全与分享 |
| 保留 | PA / ComfyUI / Krita 三个 section 文件 | 被集成页引用，内部不动 |

搬迁方式：整块移动 widget 代码及其依赖 import 与辅助方法（如 `_editHighAnlasThreshold`、`_selectBackgroundImage`），不重写控件逻辑。

## l10n 变更（zh / en / ja 三份 ARB）

新增：
- `settings_dataStorage`：数据与存储 / Data & Storage / データとストレージ
- `settings_privacySharing`：安全与分享 / Privacy & Sharing / 保護と共有
- `settings_integrations`：集成 / Integrations / 連携
- 「生成」页内小节标题 3 条（输入 / 重试 / 提醒）

保留复用：提示音相关词条（`settings_notificationSound` 等，在生成页内继续使用）、`settings_queueRetry*`。

旧分类标签词条（`settings_dataSource`、`settings_queue`、`settings_notifications`）：实现时用 `grep` 核实引用，仅被设置页引用则随迁移删除，另有引用则保留。

## 兼容性与风险

- **无深链风险**：`SettingsScreen` 仅经 `/settings` 路由整页打开，构造无参数，无外部代码依赖分区索引（已核实 `app_router.dart`）。
- **无数据迁移**：所有 provider 与持久化 key 不动。
- **`_selectedIndex` 越界**：现有保护逻辑（`settings_screen.dart:164`）已覆盖分类数减少的场景。
- **PA 面板体积**：集成页一次只渲染一个面板，不放大现有性能开销。

## 测试计划

- 新增 `test/presentation/screens/settings/settings_screen_test.dart`：
  - 渲染 9 个导航目的地且标签正确；
  - 切换到「集成」后 SegmentedButton 三段可切换，各面板关键控件出现；
  - 「生成」页包含重试滑条与提示音开关；「外观」页包含悬浮球背景项。
- 回归：`flutter test` 全量、`flutter analyze`、`flutter build windows --release`。
- 手动冒烟：逐项确认搬迁后的设置读写生效（重点：保护模式子项联动禁用、代理测试、集成三面板）。
