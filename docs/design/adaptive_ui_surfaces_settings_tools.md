# 设置与工具自适应界面逐单元审计

> 范围：`settings`、`cloud_sync`、`auth`、`watermark`、`model3d`、`shortcuts`、`metadata`、`discord_share`、`queue` 的可达 Screen / Dialog / Sheet / Panel / Menu / Overlay / 编辑态。本文逐项核对当前生产代码；实现状态与自动化证据独立记录，专项测试空白不等于实现缺口。

## 证据口径

- **E3 真实入口组件级**：测试调用生产 `show` / launcher / shell 或真实交互入口，并直接断言该单元及返回行为。
- **E2 直接组件级**：测试直接构建该 Widget 并断言布局或状态；不能证明生产入口。
- **E1 间接/静态**：只有父级交互经过、业务测试或源码可达性；不能证明该单元布局。
- **E0 专项测试空白**：已审计到生产实现，但没有定位到针对该单元的测试；不得据此称为实现缺口。
- “已审计：符合”只说明当前代码符合本轮自适应契约；测试列未覆盖的尺寸、状态组合及真机行为仍不算已验证。

## Settings

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Settings Screen | Shell 设置分支、`/settings?section=` | `lib/presentation/screens/settings/settings_screen.dart` | 11 分类、当前分类、滚动、Agent 草稿 dirty、外部 section 更新 | `<600` 分类列表→详情；`>=600` Rail；Wide 扩展 Rail；内容限宽 960；跨断点保持状态 | 已审计：符合 | `settings_screen_test.dart`：390、700/840/1180/1600/3840、草稿确认、断点与 `initialSection`/外部 section 恢复（E3）；`appRouterProvider` 真实 `/settings?section=` 导航专项测试空白 |
| Settings 分类列表/NavigationRail | Settings Screen 内 | `settings_screen.dart` `_buildCompactSettings` / `_buildNavigationRail` | 11 分类、选中态、图标/标签 | Compact 56 高列表项；Medium/Expanded Rail；Wide `extended` | 已审计：符合 | `settings_screen_test.dart` 宽度矩阵与选中态（E2） |
| Settings Section 内容容器 | 选择任一分类 | `settings_screen.dart`、`widgets/settings_page_layout.dart` | 标题、说明、分组、滚动、SafeArea | 最大宽 960；窄标题纵排；全尺寸可滚动 | 已审计：符合 | `settings_page_layout_test.dart`：320/600/840/1180/1600、多主题/大字；`settings_screen_test.dart`：SafeArea/限宽（E2） |
| Agent 草稿离开确认 | 切分类、AppBar/系统返回、外部 section 更新 | `settings_screen.dart` `_confirmDiscardAgentDraft`→`ThemedConfirmDialog` | keep editing / discard；并发确认合并 | Compact 自适应全屏；其他宽度有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | `settings_screen_test.dart`：桌面、Compact、系统返回、外部 section（E3）；共享 `themed_confirm_dialog_test.dart` 覆盖 320/3x/IME/SafeArea，但不外推业务入口 |
| Account Settings Section | Settings→账户 | `sections/account_settings_section.dart` | 未登录、当前账号、多账号、登录/资料入口 | 320–1600、3x；窄屏登录走生产 route | 已审计：符合 | `account_settings_login_navigation_test.dart`：320–1600/3x、登录与 footer；父页进入（E3） |
| Account Profile form | 账户卡片；Mobile More 账号项 | `widgets/settings/account_profile_sheet.dart` | Token/邮箱账号、切换、昵称、退出 | `AdaptivePresenter.showForm`；Compact 全屏，其他共享表面；IME/SafeArea | 已审计：符合 | `account_profile_sheet_test.dart`：真实 `show`、320×568、3x、IME/SafeArea（E3）；Medium/Expanded 专项尺寸空白 |
| Nickname 编辑 form | Account Profile→编辑昵称 | `widgets/settings/nickname_edit_dialog.dart` | 初值、trim、保存/取消 | 320 全屏、600 centered、840/1600 side sheet；3x+IME+SafeArea | 已审计：符合 | `nickname_edit_dialog_test.dart`：真实 `show`、完整断点与返回值（E3） |
| Appearance Settings Section | Settings→外观 | `sections/appearance_settings_section.dart` | 主题、布局、字体、语言、字号、历史点击行为 | 320–1600、大字；纵向滚动 | 已审计：符合 | `appearance_settings_section_test.dart`：宽度矩阵、大字、持久化（E2） |
| 主题选择 Dialog | 外观→主题 | `appearance_settings_section.dart` `_showThemeDialog` | 当前主题、选择即保存、取消 | 可滚动有界 `AlertDialog` | 已审计：符合短单选器契约 | 入口与选择行为（E2）；320/3x 专项测试空白 |
| 布局选择 Dialog | 外观→布局 | `appearance_settings_section.dart` `_showLayoutDialog` | 当前布局、选择/关闭 | 有界 Dialog；短高内部滚动 | 已审计：符合短单选器契约 | `appearance_settings_section_test.dart`：短高+3x 可滚动（E2） |
| 字体选择 form | 外观→字体 | `appearance_settings_section.dart` `_showFontDialog`、`_FontPickerContent` | 异步字体列表、选择、取消 | `AdaptivePresenter.showForm` | 已审计：符合；近期已迁移共享表面 | 真实点击入口、异步选择与取消（E3）；断点矩阵未逐项覆盖 |
| 语言选择 Dialog | 外观→语言 | `appearance_settings_section.dart` `_showLanguageDialog` | 当前 locale、切换 | 有界 `AlertDialog` | 已审计：符合短单选器契约 | 入口经过（E1）；独立窄屏/大字专项测试空白 |
| 字号编辑 form | 外观→字号 | `appearance_settings_section.dart` `_showFontScaleDialog`、`_FontScaleEditor` | 实时预览、保存/取消 | `AdaptivePresenter.showForm`；Compact、3x、IME | 已审计：符合；近期已迁移共享表面 | 真实入口、320/3x/IME 与保存（E3） |
| Generation Settings Section | Settings→生成 | `sections/generation_settings_section.dart` | 输入、输出、重试、提醒、音效 | 320–1600、3x；局部重排 | 已审计：符合 | `generation_settings_section_test.dart`：宽度矩阵、3x、持久化/回滚（E2） |
| Agent Settings Section | Settings→智能体 | `sections/agent_settings_section.dart` | 模型/阅读/权限/Web Access；Prompt/Skills 子面板 | 手机/横屏/桌面；局部动作重排 | 已审计：符合 | `agent_settings_section_test.dart`：多形态、大列表；`settings_screen_test.dart`：入口/草稿（E2/E3） |
| Agent System Prompt 编辑态 | Agent→系统提示词 | `sections/agent/system_prompt_editor.dart` | 默认/自定义、dirty、保存/放弃、错误 | 复用 Settings 滚动与断点 | 已审计：符合 | dirty 流程与直接子面板（E2/E3）；IME 下长 Prompt 专项测试空白 |
| Skill Management Panel | Agent→Skills | `sections/agent/skill_management_panel.dart` | 搜索、筛选、诊断、大列表、导入导出 | 惰性列表；窄屏筛选/动作重排 | 已审计：符合 | `agent_settings_section_test.dart`：大列表、来源/状态（E2）；完整生产操作链专项测试空白 |
| Skill 导出 form | Skills→导出 | `skill_management_panel.dart` `_exportSkills` | 多选、空选择、导出 | `AdaptivePresenter.showForm` | 已审计：符合；近期已迁移共享表面 | 紧凑/宽屏、选择保持（E3） |
| Skill 导入冲突 form | Skills 导入 ZIP 冲突 | `SkillImportConflictForm.show` | replace/skip、多冲突、取消 | `AdaptivePresenter.showForm`；长列表可滚动 | 已审计：符合；近期已迁移共享表面 | 最坏文本/列表、替换/取消（E3） |
| Agent 配置导入审阅 form | Agent profile import | `sections/agent/agent_profile_actions.dart` | 差异、有效模型、应用/取消 | `AdaptivePresenter.showForm`；内容/动作局部重排 | 已审计：符合；近期已迁移共享表面 | 极端尺寸、滚动、应用/取消（E3） |
| Storage Settings Section | Settings→数据与存储 | `sections/storage_settings_section.dart`、`widgets/data_source_cache_settings.dart` | 路径、缓存、基础库/共现/ffdkj、ONNX | 320–1600、3x；统计/动作局部堆叠 | 已审计：符合 | `storage_settings_section_test.dart` 宽度矩阵；`settings_data_status_tile_test.dart` 局部重排（E2） |
| 删除共现数据 form | 数据源缓存→删除共现包 | `data_source_cache_settings.dart` `_confirmDelete` | 删除、停止自动下载、取消 | `AdaptivePresenter.showForm`；滚动正文与固定动作 | 已审计：符合；近期已迁移共享表面 | 真实入口 320/3x/IME/SafeArea（E3） |
| ffdkj 安装/删除确认 | 数据源缓存→中文词库动作 | `data_source_cache_settings.dart`→`ThemedConfirmDialog` | 上游下载确认、删除确认 | Compact 全屏；其他有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | 业务专项测试空白（E0）；共享确认测试不外推业务返回 |
| 图库缓存重扫确认 | Storage→图库缓存动作 | `widgets/gallery_cache_actions.dart`→`ThemedConfirmDialog` | 重扫确认、busy/error | Compact 全屏；其他有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | 业务专项测试空白（E0） |
| ONNX 文件清理确认 | Storage→本地 ONNX tagger | `storage_settings_section.dart` `_clearLocalOnnxTaggerFiles`→`ThemedConfirmDialog` | 清理/取消 | Compact 全屏；其他有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | 仅路径/入口间接证据（E1）；确认返回专项测试空白 |
| Hive 路径变更/恢复确认 | Storage→数据路径 | `HiveStoragePathTile`→`ThemedConfirmDialog` | 重启警告、选择路径、恢复默认 | Compact 全屏；其他有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | 业务专项测试空白（E0） |
| Privacy Settings Section | Settings→安全与分享 | `sections/privacy_settings_section.dart` | 保护、水印、元数据、黑名单、数字限制 | 320/600/840/1180/1600；卡片同宽 | 已审计：符合 | `privacy_settings_section_test.dart`：矩阵、联动、卡片宽度（E2） |
| Privacy 数字编辑 form | Privacy→数字项 | `_showNumberEditor` | 初值、范围校验、保存/取消 | `AdaptivePresenter.showForm`；320/3x/IME/SafeArea | 已审计：符合；近期已迁移共享表面 | 两个真实入口、校验与返回（E3） |
| Network Settings Section | Settings→网络 | `sections/network_settings_section.dart` | 代理、认证、测试、错误 | 320–1600、3x；字段/动作局部重排 | 已审计：符合 | `network_settings_section_test.dart`：矩阵与状态（E2） |
| Web Access Settings Panel | Agent/Web Access | `sections/web_access_settings.dart` | 总开关、SearXNG、Exa Key、loading/error | 局部 `LayoutBuilder`；窄屏编辑入口 | 已审计：符合 | `web_access_settings_test.dart`：呈现、权威开关、状态（E2） |
| API Key 编辑 form | Web Access→编辑 Exa Key | `_showApiKeyEditor` | masked、save/no-op/clear、IME | `AdaptivePresenter.showForm` | 已审计：符合；近期已迁移共享表面 | 真实入口、保存/空值/清除（E3） |
| Shortcuts Settings Section | Settings→快捷键 | `sections/shortcut_settings_section.dart` | 摘要、管理、帮助入口 | 跟随 Settings 容器 | 已审计：符合 | 仅父页分类入口（E1）；Section 独立尺寸/状态专项测试空白 |
| Shortcut Management Panel | Shortcuts→管理 | `shortcut_settings_panel.dart` | loading/error/empty/search、录制、冲突、保存、重置 | `AdaptivePresenter.showForm`；320/600/840/1180/1600、3x/短高/IME | 已审计：符合；近期已迁移共享表面 | 真实 `show`、宽度矩阵、状态保持/空错/冲突（E3） |
| Shortcut Binding 编辑态 | 管理面板→绑定 | `shortcut_binding_editor.dart` | 录制、组合键、冲突、清除/保存 | 嵌入 Panel；窄屏动作堆叠 | 已审计：符合 | 录制冲突禁止保存（E2）；返回时未保存录制专项测试空白 |
| Shortcuts 重置确认 | 管理面板→重置 | `_showResetConfirmDialog`→`ThemedConfirmDialog` | reset/cancel | Compact 全屏；其他有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | 业务专项测试空白（E0） |
| Integrations Settings Section | Settings→集成 | `sections/integrations_settings_section.dart` | Prompt Assistant / ComfyUI / Krita；capability | 分段导航可横滚；320–1600 | 已审计：符合 | `integrations_settings_section_test.dart`：切换、文案、capability、矩阵；父页入口（E2/E3） |
| Prompt Assistant 服务商编辑 form | Integrations→新增/编辑服务商 | `_showProviderDialog` | protocol、URL、图片输入、API Key、保存/取消 | `AdaptivePresenter.showForm`；Compact 全屏、520 side sheet；滚动正文/固定动作/IME/SafeArea | 已审计：符合；近期已从固定 `AlertDialog` 迁移 | `settings_screen_test.dart`：390、1.6x、IME、真实新增（E3）；编辑态断点专项测试空白 |
| Prompt Assistant 连接配置 form | 服务商卡片→连接配置 | `_showConnectionDialog` | Base URL、API Key、清除 Key、图片输入、保存/取消 | `AdaptivePresenter.showForm`；Compact 全屏、520 side sheet；滚动正文/固定动作/IME/SafeArea | 已审计：符合；近期已从固定 `AlertDialog` 迁移 | 专项测试空白（E0）；源码入口与实现已核对 |
| Prompt Assistant 规则编辑 form | Rules→新增/编辑 | `_showRuleDialog` | 名称、任务类型、规则内容、删除、保存/取消 | `AdaptivePresenter.showForm`；Compact 全屏、560 side sheet；长文本滚动/固定动作 | 已审计：表单自适应符合；近期已从固定 `AlertDialog` 迁移 | 专项测试空白（E0）；源码入口与实现已核对 |
| Prompt Assistant 服务商删除确认 | 服务商卡片→删除 | `prompt_assistant_settings_section.dart` 卡片删除按钮 → `ThemedConfirmDialog.showDelete` | 显示服务商名称、取消/删除；确认后调用 notifier | 共享 adaptive confirm；Compact/大字/SafeArea 继承共享实现 | 共享确认组件证据（E1）；业务入口专项测试空白 | 实现已审计 |
| ComfyUI Settings Panel | Integrations→ComfyUI | `sections/comfyui_settings_section.dart` | capability、连接、工作流、导入/删除、错误 | 局部重排；受 capability 控制 | 已审计：符合 | 组件状态与 Integrations capability（E2） |
| ComfyUI 工作流删除确认 | 工作流→删除 | `_confirmDeleteWorkflow`→`ThemedConfirmDialog` | delete/cancel | Compact 全屏；其他有界 Dialog | 已审计：符合；近期已迁移共享确认表面 | 业务专项测试空白（E0） |
| Workflow Import Wizard | ComfyUI→导入工作流 | `widgets/workflow_import_wizard.dart` | 文件、解析、映射、冲突、确认、完成/错误 | `AdaptivePresenter.showForm`；footer 局部重排 | 已审计：符合；近期已迁移共享表面 | 真实 `show`、多断点、长文本与步骤状态（E3） |
| Krita Settings Panel | Integrations→Krita | `sections/krita_bridge_settings_section.dart` | capability、连接状态、设置入口 | 跟随 Integrations 滚动容器 | 已审计：符合 | 可切换到面板（E1）；独立窄屏/错误态专项测试空白 |
| About Settings Section | Settings→关于 | `sections/about_settings_section.dart` | 版本、更新、许可、链接 | 跟随 Settings 容器 | 已审计：符合 | 仅分类入口（E1）；长文案/大字/短高专项测试空白 |

## Cloud Sync

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Cloud Sync Screen | Settings→备份与恢复；query section | `screens/cloud_sync/cloud_sync_screen.dart` | error、未连接、已连接 | 复用 Settings 960 限宽和滚动 | 已审计：符合 | `cloud_sync_screen_test.dart` 通过 `SettingsScreen(initialSection: cloudSync)` 构建（E3）；真实 router query 专项测试空白 |
| Setup Panel | 未连接 Screen | `cloud_sync_setup*.dart` | WebDAV/GitHub、敏感字段、allowlist、测试/保存 | 局部 grid 单/双列；320–1600、3x | 已审计：符合 | `cloud_sync_screen_test.dart`：矩阵、保存与 secret（E2） |
| Agent 同步内容 Panel | Setup→同步内容 | `cloud_sync_agent_content_section.dart` | prompt、skills、多选、缺失 IDs | 窄宽动作/缺失项重排 | 已审计：符合 | `cloud_sync_agent_content_section_test.dart`（E2） |
| Dashboard | 已连接 Screen | `cloud_sync_dashboard.dart` | capability、push/pull、暂停、进度、历史、警告 | 320–1600；snapshot 行局部重排 | 已审计：符合 | `cloud_sync_screen_test.dart`：矩阵、mode、进度/暂停/历史（E2） |
| Push/Pull 二次确认 | Dashboard→推送/拉取 | `_confirmSyncDirection` `AlertDialog` | 方向说明、确认/取消、失败 | 短确认有界 Dialog | 已审计：符合短确认契约 | 两个真实按钮→确认→调用（E3）；320/3x 专项布局空白 |
| Conflict Center Panel | Dashboard→冲突 | `cloud_sync_conflict_center.dart` | local/remote/keepBoth、批量、manual 禁用 | action grid 局部重排 | 已审计：符合 | 冲突列表、批量/单项、manual 禁用（E2） |
| Merge/Restore Preview Panel | pending preview | `cloud_sync_preview_panel.dart` | added/modified/deleted、确认、restore gating | 跟随 Settings 滚动 | 已审计：符合 | 摘要、确认应用、禁用态（E2）；真实网络流程不在证据内 |
| ffdkj 安装 Prompt | restore install intent | `cloud_sync_ffdkj_prompt.dart` | 安装、暂不安装、清除提示、二次确认 | 内嵌 Prompt + 短确认 Dialog | 已审计：符合 | Prompt 与暂不安装（E2）；安装确认专项测试空白 |
| Security/Danger Panel | Dashboard 底部 | `cloud_sync_security_section.dart` | 删除云备份、断开、busy | 短确认 Dialog | 已审计：符合 | 仅危险入口（E1）；确认返回专项测试空白 |
| Warning/error Banner | Screen/Dashboard | `cloud_sync_widgets.dart` | backend/maintenance warning、error | 自然换行 | 已审计：符合 | warning、maintenance、错误脱敏（E2） |

## Auth

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Login Screen | `/login`、账号设置、Mobile More | `screens/auth/login_screen.dart` | optional、saved accounts、三种登录、loading/error/update | `AdaptiveSlotLayout`；滚动；内容限宽 620 | 已审计：符合；近期迁移共享 Slot/Bounds | 360/900/1600 与可选登录；真实 push（E2/E3）；3x+IME 组合空白 |
| Login Form / Mode Switcher | Login Screen | `login_form_container.dart`、`auth_mode_switcher.dart` | Token/邮箱/第三方、auth error | 局部模式标签适配 | 已审计：符合 | 多 locale、370/520、切换（E2） |
| Token Login Card | API Token | `token_login_card.dart` | token、auto login、loading/error | 跟随登录滚动容器 | 已审计：符合 | 默认呈现与输入（E2）；320/3x/IME、真实提交专项测试空白 |
| Credentials Login Form | 邮箱密码 | `credentials_login_form.dart` | email/password、auto login、forgot、loading | 320+3x actions 纵排；触屏 48 | 已审计：符合 | 320/3x/touch（E2） |
| Third-party API Login Card | 第三方 | `third_party_api_login_card.dart` | URL/token、streaming 提示、error | 360、2x、多 locale；长路径换行 | 已审计：符合 | 多 locale、360/2x（E2）；真实提交/IME 空白 |
| Login loading Overlay | 登录请求中 | `login_screen.dart` `_LoadingOverlay` / root `OverlayEntry` | 单例、dismiss、dispose remove | 填满 root overlay，非尺寸分支表面 | 已审计：符合 | 专项测试空白（E0）；生命周期代码已核对 |
| Network Troubleshooting panel | 网络失败→排障 | `network_troubleshooting_dialog.dart` | tips、server status、关闭 | `<840` bottom sheet；`>=840` side sheet；320–1600、3x、IME | 已审计：符合；近期迁移共享 Panel | 真实 `show`、7 种尺寸/键盘组合（E3） |
| Global auth-required Dialog | auth guard | `router/app_shell.dart` | reason、取消/登录、串行请求 | 短确认 `AlertDialog` | 已审计：符合短确认契约 | 请求顺序、Medium 入口（E3）；Compact 3x 空白 |
| Auth recovery Banner | session expired / auto-login fail | `global_status_banners.dart` | retry/login/dismiss、长错误 | 桌面限宽、移动紧凑 | 已审计：符合 | 1580→390 resize、关闭（E2） |
| Danbooru Login panel | Online Gallery 账号 | `online_gallery_auth_dialogs.dart` | credentials、loading/error、结果 | `AdaptivePresenter.showPanel` | 已审计：符合；近期迁移共享 Panel | 真实来源入口、desktop bounded（E3）；320/IME 空白 |
| Gelbooru Credentials panel | Gallery Gelbooru 账号 | 同上 | user ID/API key、保存/清除/error | `AdaptivePresenter.showPanel` | 已审计：符合；近期迁移共享 Panel | 多宽度真实入口（E3）；IME/大字空白 |

## Watermark

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Watermark Editor form | 图片动作/详情/Privacy | `watermark_editor_launcher.dart`、`watermark_editor_screen.dart` | defaults/source、layer、preview、dirty、save/error | `AdaptivePresenter.showForm`；内部 `>=840` 双栏，否则单列 | 已审计：符合；近期统一 launcher 表面 | 真实 launcher 320/700/1200；Screen 宽度矩阵/IME（E3/E2） |
| Controls 编辑态 | Editor controls | `watermark_editor_controls.dart` | font/color/opacity/scale/rotation/anchor/metadata | `<350` 或大字 slider 纵排；可滚动 | 已审计：符合 | 多尺寸无 overflow（E2）；逐控件语义未全部断言 |
| Missing source confirmation | derivative 原图缺失 | `watermark_editor_launcher.dart` `AlertDialog` | cancel / choose original | 短确认有界 Dialog | 已审计：符合短确认契约 | 专项测试空白（E0） |
| Color Picker form | Controls→Color Picker | `_pickColor`→`AdaptivePresenter.showForm` | HSV、preview、confirm/cancel | 320×568、3x、IME/SafeArea | 已审计：符合；近期迁移共享 Form | 真实入口、最坏 Compact、返回不提交（E3） |
| Font dropdown Menu | Controls→字体 | `DropdownButtonFormField` | family、当前字体、预览 | Material menu overlay | 已审计：符合 | 420 展开与 family（E2）；320/3x 边缘定位空白 |
| Anchor/Arrangement Menus | Controls→位置/排列 | `DropdownButtonFormField` | anchor、排列模式 | Material menu overlay | 已审计：符合 | 专项测试空白（E0） |
| Saved result Dialog | Editor→保存成功 | `_showSaved` `AlertDialog` | 输出路径、完成 | 短通知有界 Dialog | 已审计：符合 | 专项测试空白（E0） |

## Model3D

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Model3D Editor Screen | Image Editor 3D layer | `model3d_editor_screen.dart` | empty/model/restore/dirty/bridge error/apply | `<520` 主操作图标化；toolbar 横滚；局部 constraints | 已审计：符合；近期完成窄屏与局部宽度迁移 | 真实 push、320/360 大字、500 local width、多状态（E3） |
| Viewport | Editor 主区 | `model3d_web_viewport.dart` 等 | ready/loading、JS、timeout、render | 占满剩余区域 | 已审计：符合容器契约 | bridge/server 业务测试；Screen 用替代 viewport（E1）；真实 WebView 视觉专项测试空白 |
| Empty scene Panel | 无 model | Editor Screen | mannequin/import、apply disabled | 窄屏大字动作可达 | 已审计：符合 | 360/2x、empty→mannequin（E2） |
| Light Settings form | toolbar→light | `_showLightDialog` | intensity/azimuth/elevation、live update | `AdaptivePresenter.showForm`；320/3x/SafeArea | 已审计：符合；近期迁移共享 Form | 真实入口、slider command、系统返回（E3） |
| Replace model confirmation | 已有 model 再导入 | `_confirmReplace` `AlertDialog` | replace/cancel | 短确认有界 Dialog | 已审计：符合短确认契约 | 专项测试空白（E0） |
| Dirty exit confirmation | 返回 dirty Editor | `_confirmExit` `AlertDialog` | discard / keep editing | 短确认有界 Dialog | 已审计：符合短确认契约 | pageBack 后出现（E3）；确认/取消与大字布局空白 |
| Layer Panel 3D Menu | layer 操作 | `layer_panel.dart` | add/edit/replace/remove/rename | `showMenu` 锚点 | 已审计：触屏另有明确操作入口 | 入口/徽标/编辑回写（E2）；边缘定位专项测试空白 |

## Shortcuts

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Shortcut Help form | 全局、Shell、Settings | `shortcut_help_dialog.dart` | 搜索、分类、空结果、滚动、返回 | 320 full-screen；700 centered；1000 side sheet；3x/IME/SafeArea | 已审计：符合 | 真实 `show`、三断点、搜索/返回（E3） |
| Global Shortcut dispatcher | Shell Focus/Shortcuts | `core/shortcuts/**`、provider、shell | fallback、冲突、优先级、禁用 | 输入能力独立 viewport | 已审计：符合 | hardware/image preview 行为测试（E2）；非视觉证据 |

## Metadata

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Metadata Import form | 详情、拖放、picker | `metadata_import_dialog.dart` | preset、Prompt/角色/Vibe/参数、父子选择 | `AdaptivePresenter.showForm`；320/700/1000、3x/IME/SafeArea | 已审计：符合 | 真实 `show`、三断点、返回/preset（E3） |
| Metadata Import workflow | Mobile More/picker/drop | `image_metadata_import_workflow.dart` 等 | cancel/no metadata/zero/apply/open | 复用共享 Dialog | 已审计：符合 | 生产 workflow 各退出路径（E3）；真实平台 picker 不在证据内 |
| Detail Metadata Panel | 详情 metadata tab | `detail_metadata_panel.dart` | prompt/tags/parameters/copy | 窄屏+3x label/value 纵排 | 已审计：符合 | responsive/direct tests（E2） |
| Bulk Metadata Edit form | Local Gallery 批量动作 | `bulk_metadata_edit_dialog.dart`→`AdaptivePresenter.showForm` | 多图、增删标签、进度/error | Compact 全屏、Medium centered、Expanded side sheet；滚动/IME | 已审计：符合；近期已从普通 Dialog 迁移 | `local_gallery_bulk_dialog_responsive_test.dart`：320/600/840/1180/1600 与真实入口（E2/E3） |
| ZIP Metadata options form | ZIP export | `zip_export_metadata_dialog.dart`→`AdaptivePresenter.showForm` | 保留/移除元数据、返回 | Compact 全屏、Medium centered、Expanded side sheet | 已审计：符合；近期已从普通 Dialog 迁移 | `zip_export_metadata_dialog_test.dart` 返回；`local_gallery_bulk_dialog_responsive_test.dart` 矩阵；真实 Gallery 入口（E2/E3） |

## Discord Share

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Discord Share form | Image Preview、动作 dispatcher | `discord_share_dialog.dart` `show` | 初始化、认证、targets、编辑、发送、成功/error | `AdaptivePresenter.showForm`；320、1000、3x/IME/SafeArea | 已审计：符合；近期迁移共享 Form | 真实 `show`、Compact/Wide、认证到编辑、返回（E3）；Medium 空白 |
| 未认证/验证 Panel state | Share 初始区 | 同上 | session、verify、OAuth、join/error | 同一 form 内滚动 | 已审计：符合 | null session→authenticate→targets、脱敏（E2） |
| 分享编辑态 | 验证成功后 | 同上 | targets、caption、categories、metadata、send | 大字隐藏 subtitle；内容滚动 | 已审计：符合 | target/prompt/category/preferences（E2）；sending/success/rate limit 响应式状态空白 |

## Queue

| 单元 | 入口 | 实现 | 关键状态 | 响应条件 | 实现状态 | 证据说明 |
|---|---|---|---|---|---|---|
| Queue Shell Panel | Desktop rail、Mobile More、快捷键 | `shell_panels_overlay.dart`→`queue_management_page.dart` | open/close、互斥、保活、焦点 | Compact 全宽 overlay；desktop 约 460；scrim/Escape/返回 | 已审计：符合 | 360/1200 shell panel、返回、真实 Mobile More 入口（E3） |
| Queue Management Page | Shell Panel | `queue_management_page.dart` | empty/task states、selection、filter/sort、批量/执行 | 短高滚动；390+3x 统计/动作纵排 | 已审计：符合 | 460×485 empty、390×820/3x（E2）；有数据大宽矩阵专项测试空白 |
| Execution Stats Panel | Queue 顶部 | `execution_stats_panel.dart` | idle/running/paused、进度、动作 | 窄/大字纵排；460 常规同排 | 已审计：符合 | 460 同排、390/3x 纵排（E2）；error/completed 专项测试空白 |
| Task Edit form | task→编辑 | `task_edit_dialog.dart` | prompt、完整参数、duplicate/save/cancel、dirty | `AdaptivePresenter.showForm`；320/700/1600、3x/IME/SafeArea | 已审计：符合；近期迁移共享 Form | 真实 `show`、三断点、返回/取消（E3） |
| Task Detail panel | task 触屏详情 | `_showTaskDetails`→`AdaptivePresenter.showPanel`、`QueueTaskDetailView` | thumbnail、完整 Prompt、角色、参数 | 触屏 panel；与桌面 hover 共用内容 | 已审计：符合；近期补齐触屏等价入口 | 专项测试空白（E0） |
| Task hover Overlay | desktop hover | `_TaskTooltipWrapper` / `OverlayEntry` | delayed show/remove、详情、边缘定位 | 精细指针专用；按 SafeArea/viewport 双向择边并 clamp；metrics/dispose 清理 | 已审计：符合；近期补齐边缘约束与生命周期 | 专项测试空白（E0） |
| 单任务删除确认 | task→删除 | `task_list_item.dart` `_confirmDelete` `AlertDialog` | delete/cancel | 短确认有界 Dialog | 已审计：符合短确认契约 | 专项测试空白（E0） |
| 清空/批量删除/失败清理确认 | toolbar/selection | `queue_management_page.dart`→`ThemedConfirmDialog` | 数量、危险确认、取消 | Compact 全屏；其他有界 Dialog | 已审计：符合；近期迁移共享确认表面 | 业务专项测试空白（E0） |
| Task thumbnail | row/detail | `queue_task_thumbnail.dart` | local、legacy remote、missing/error | 固定槽位、父级定尺寸 | 已审计：符合 | local/legacy source（E2）；响应尺寸专项测试空白 |
| Execution/auth state | start command | `queue_execution_provider.dart` | unauth、running/paused/cancelled、失败策略 | 非可视状态，映射到 Page/Stats | 已审计：符合 | provider/auth guard（E2 业务）；不外推视觉状态 |

## 审计结论

- 本轮确认近期迁移已落到生产代码：共享 `ThemedConfirmDialog` 的 Compact 全屏适配、Settings 多个长表单、Prompt Assistant 服务商/连接/规则三表单、Bulk Metadata/ZIP options、Network Troubleshooting、Watermark、Model3D Light、Discord、Queue Task Edit，以及 Queue 触屏详情与 hover 边缘约束。
- 自动化证据与实现状态已完全拆开；所有“专项测试空白”仅表示 E0，不再写成实现缺口，也没有为本次文档审计补测试。
- 当前逐项源码复核未保留真实实现缺口：服务商与自定义规则的破坏性删除均先经过共享自适应确认；专项测试空白只限制证据强度。
- 未执行 Windows/Android 运行验收；现有 widget test 不作为真机视觉证明。
