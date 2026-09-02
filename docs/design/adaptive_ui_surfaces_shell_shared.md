# Shell 与共享自适应界面面审计

## 范围与证据

本表只记录 `lib/app.dart`、`lib/presentation/router/`、`lib/presentation/screens/splash/`、全局 drop/overlay/banner/toast、`lib/presentation/agent_chat/` 与 `lib/presentation/widgets/common/` 中代码实际可达的 Screen、Dialog、Sheet、Panel、Menu、Overlay 和编辑态；路由目标逐项记录，但不把某一组件族的结论外推给未检查界面。

证据级别：**A**＝有该单元的直接 widget/contract test；**B**＝有入口/宿主的直接测试或调用链测试，但没有完整覆盖该单元状态矩阵；**C**＝仅静态代码与真实调用点证据。证据级别只描述测试与调用证据，不决定实现是否完成。

实现审计：**已审计**＝当前代码已有与风险相称的响应策略；**实现缺口**＝当前代码缺少必要策略或存在真实行为问题。**专项测试空白**单独写在“专项测试 / 证据级别”列；未写专项测试不等于实现未完成，也不记为实现缺口。

## App、Router、Splash 与导航壳层

| 单元 | 真实入口 | 实现 | 关键状态 | 响应条件 | 专项测试 / 证据级别 | 实现审计 |
|---|---|---|---|---|---|---|
| 启动 Splash Screen | `main` 的 `AppBootstrap` 在 warmup 完成前挂载 | `screens/splash/splash_screen.dart` `SplashScreen` | 预热进度、子任务、错误、重试、完成 | `AdaptiveSlotLayout`、SafeArea、滚动、640 上限、Reduce Motion | `splash_screen_responsive_test.dart` / A | 已审计 |
| Splash→主应用切换 | warmup `isComplete` 后下一帧切换 | `screens/splash/app_bootstrap.dart` `AppBootstrap` | 首帧启动、准备完成、post-warmup、首次启动、自动更新轮询 | 页面级切换；主应用与 Splash 各自 MaterialApp | `app_bootstrap_test.dart` / A | 已审计 |
| 主应用根面 | `AppBootstrap` 完成后 `_MainAppWrapper` | `app.dart` `NAILauncherApp` | 主题、字体、缩放、语言、全局快捷键、系统栏 | 全局 text scale 0.8–3.0、DisplayFeature 子屏、桌面窗口框 | `app_bootstrap_test.dart` 仅入口 / B；专项测试空白：根 builder 独立宽度/大字体 | 已审计 |
| Login Screen | `/login`、认证重定向、账号入口 | `router/app_router_config.dart`→`screens/auth/login_screen.dart` | 未登录、认证错误、登录中、更新提示 | Fade+轻微纵向 Slide；页面自身响应式不在本表外推 | `app_router_auth_redirect_test.dart`、`login_screen_optional_login_test.dart` / A | 已审计（入口）；页面细节见其直接测试 |
| Generation Screen | `/`、`/generation`、导航“生成” | `app_router_config.dart`→`GenerationScreen` | 当前 StatefulShell 分支、分支销毁/重建 | Fade；壳层按安全可用宽度切换 | `app_router_navigation_test.dart`、`generation_screen_responsive_test.dart` / A | 已审计 |
| Local Gallery Screen | `/local-gallery`、导航“画廊” | `app_router_config.dart`→`LocalGalleryScreen` | StatefulShell 保活、子路由 | 壳层自适应；页面策略由自身测试证明 | `app_router_navigation_test.dart`、`local_gallery_screen_test.dart` / A | 已审计 |
| Slideshow Screen | Local Gallery 子路由 `slideshow` | `app_router_config.dart`→`SlideshowScreen` | runtime images、合法化 initialIndex、deep-link empty | 独立 MaterialPage；`GallerySlideshowRouteData` 传递不可 URL 编码的记录 | `slideshow_screen_test.dart` / A | 已审计：路由 payload 保留完整列表；无 payload 的直接深链显式进入可返回空态 |
| Image Comparison Screen | Local Gallery 子路由 `comparison` | `app_router_config.dart`→`ImageComparisonScreen` | runtime comparison list、deep-link empty、超限态 | 独立 MaterialPage；`GalleryComparisonRouteData` 传递记录 | `image_comparison_screen_test.dart` / A | 已审计：路由 payload 保留比较列表；无 payload 的直接深链显式进入可返回空态 |
| Online Gallery Screen | `/online-gallery`、导航“探索” | `app_router_config.dart`→`OnlineGalleryScreen` | StatefulShell 保活 | 壳层自适应；页面断点不由路由外推 | `app_router_navigation_test.dart`、`online_gallery_source_auth_test.dart` / A | 已审计（入口） |
| Settings Screen | `/settings?section=`、更多/Agent 设置 | `app_router_config.dart`→`SettingsScreen` | 初始 section、更新红点 | 壳层自适应；section 由 query 恢复 | `settings_screen_test.dart`、`app_router_navigation_test.dart` / A | 已审计 |
| Prompt Config Screen | `/prompt-config`、更多“随机配置” | `app_router_config.dart`→`PromptConfigScreen` | 分支切换 | 壳层自适应 | `prompt_config_responsive_layout_test.dart` / A | 已审计 |
| Statistics Screen | `/statistics`、更多“统计” | `app_router_config.dart`→`StatisticsScreen` | 加载/数据与布局 | 壳层自适应 | `statistics_responsive_layout_test.dart` / A | 已审计 |
| Tag Library Page Screen | `/tag-library`、底部“词典” | `app_router_config.dart`→`TagLibraryPageScreen` | StatefulShell 当前分支 | 壳层自适应 | `tag_library_responsive_layout_test.dart` / A | 已审计 |
| Vibe Library Screen | `/vibe-library`、更多入口 | `app_router_config.dart`→`VibeLibraryScreen` | StatefulShell 保活 | 壳层自适应 | `vibe_library_responsive_layout_test.dart` / A | 已审计 |
| Precise Ref Library Screen | `/precise-ref-library`、更多入口 | `app_router_config.dart`→`PreciseRefLibraryScreen` | StatefulShell 保活 | 壳层自适应 | `precise_ref_responsive_layout_test.dart` / A | 已审计 |
| Router Error Screen | GoRouter 无匹配路径或 builder 错误 | `app_router_config.dart` `RouterErrorScreen` | 可返回/不可返回、错误文本 | SafeArea、滚动、640 上限、动作 Wrap | `app_router_error_screen_test.dart` / A | 已审计 |
| Main Shell | StatefulShellRoute `navigatorContainerBuilder` | `router/app_shell.dart` `MainShell` | 当前分支、保活集合、分支 pop、prompt 最大化、外部拖放 | 安全可用宽度 `>=840` Desktop，否则 Mobile | `main_shell_keep_alive_test.dart`、`main_shell_minimize_lifecycle_test.dart` / A | 已审计 |
| 登录要求确认 Dialog | auth prompt provider 发出生成/队列/Director/超分/Krita/Vibe/过期请求 | `app_shell.dart` `_showAuthPrompt` AlertDialog | 单例可见、排队消费、原因文案、取消/去登录 | Material AlertDialog；无显式窄屏 form 分支 | `main_shell_auth_prompt_test.dart` / A；专项测试空白：320/3x/IME 矩阵 | 已审计：短确认由 Material Dialog 约束 |
| Desktop Shell | MainShell 安全宽度 `>=840` | `router/desktop_shell.dart` `DesktopShell` | 导航 rail、全局 banner、Agent/Queue 面板、Esc 焦点恢复 | 主区+并行侧板；窄工作区退化覆盖层；Reduce Motion | `desktop_shell_sidebar_transition_test.dart` / A | 已审计 |
| Desktop Main Nav Rail | DesktopShell 左侧 | `widgets/navigation/main_nav_rail.dart` `MainNavRail` | 折叠/展开、目的地、Agent/Queue、账号、更新/运行 badge、社区链接 | 宽 60/196；`allowExpansion`；触控命中区由 interaction policy | `main_nav_rail_test.dart`、`desktop_shell_sidebar_transition_test.dart` / A；专项测试空白：完整键盘遍历 | 已审计 |
| Desktop 账号 Menu | 点击 rail 账号头像 | `main_nav_rail.dart` `_AccountAvatarButtonState._showAccountMenu` | 未登录、当前账号、多账号、切换、添加、退出 | 以 rail 右侧和按钮纵坐标构造 `RelativeRect` 调用 `showMenu`；Material route 将菜单宽高约束在安全视口内、调整边缘位置，并让超长菜单滚动 | `main_nav_rail_test.dart` 覆盖未认证菜单行为 / B；专项测试空白：窄高窗口、3x 文本、键盘遍历 | 已审计：锚定与 Material 视口约束均已实现 |
| Desktop 添加账号 Form | 账号 Menu“添加账号” | `main_nav_rail.dart` `_showAddAccountDialog` | 登录模式、认证错误、成功关闭 | `AdaptivePresenter.showForm`；side sheet 450 | `main_nav_rail_test.dart` 覆盖 320px、3x、IME、SafeArea、700/1000px / A | 已审计 |
| Mobile Shell | MainShell 安全宽度 `<840` | `router/mobile_shell.dart` `MobileShell` | 当前分支、Agent/Queue overlay、键盘、其他 overlay、双击返回退出 | NavigationBar；键盘/overlay 时隐藏；SafeArea；根返回守卫 | `android_root_back_guard_test.dart`、`mobile_more_panel_test.dart` / A | 已审计 |
| Mobile Navigation Bar | MobileShell 底部 | `mobile_shell.dart` `NavigationBar` | 生成/画廊/探索/词典/更多、queue/update badge、面板选中 | 键盘或 shell overlay 激活即隐藏；SafeArea | `mobile_more_panel_test.dart`、路由导航测试 / B；专项测试空白：3x/横屏全部标签 | 已审计 |
| Mobile More Sheet | 点击底部“更多” | `router/mobile_more_panel.dart` `showMobileMorePanel` | 账号、Agent、Queue、读元数据、次级分支、设置、badge、社区链接 | `AdaptivePresenter.showPanel`；0.52–0.80；大字时社区按钮纵排 | `mobile_more_panel_test.dart` / A | 已审计 |
| Shell Agent Panel | rail/更多/快捷键打开 Agent | `router/shell_panels_overlay.dart` `ShellPanelsOverlay`→`AgentChatPanel` | 首次懒挂载、显示/隐藏、焦点、Agent/Queue 互斥 | desktop 右侧或 compact bottom 94%；scrim；SafeArea；Reduce Motion | `desktop_shell_sidebar_transition_test.dart`、`agent_chat_mobile_responsive_test.dart` / A | 已审计 |
| Shell Queue Panel | rail/更多/快捷键打开 Queue | `ShellPanelsOverlay`→`QueueManagementPage` | 显示/隐藏、焦点、与 Agent 互斥 | desktop 460 或 compact bottom 85%；scrim；SafeArea | `desktop_shell_sidebar_transition_test.dart` 间接 / B | 已审计（仅 Shell 呈现；Queue 内容不在本审计范围） |
| Android 根返回短通知 | MobileShell 当前分支不可 pop 时第一次返回 | `mobile_shell.dart`→`AndroidRootBackGuard`→`AppToast.info` | 首次提示、第二次退出、分支切换重置 | Android capability；顶部 Toast | `android_root_back_guard_test.dart` / A | 已审计 |
| Desktop Window Frame | Splash 与主 MaterialApp builder | `common/desktop_window_frame.dart` | 自绘标题栏、拖动、最小化/最大化/还原/关闭 | 仅支持桌面窗口控制时显示；SafeArea/Overlay 顺序 | `desktop_window_frame_test.dart` / A | 已审计 |
| Shortcut Help Dialog | 全局快捷键 help | `app.dart`/`app_shell.dart`→`ShortcutHelpDialog.show` | 快捷键分类与关闭 | 由该组件自身 presenter 决定；不属于 common 实现 | `shortcut_help_dialog_test.dart` / A | 已审计（入口） |

## 全局 Banner、Toast、Overlay 与 Drop

| 单元 | 真实入口 | 实现 | 关键状态 | 响应条件 | 专项测试 / 证据级别 | 实现审计 |
|---|---|---|---|---|---|---|
| Global Status Banner Stack | Desktop/Mobile Shell 主内容顶部 | `router/global_status_banners.dart` `GlobalStatusBanners` | 更新通知、认证恢复同时/分别可见 | 外层可滚动且高度封顶；子 banner 各自 reflow | shell 与 banner 测试 / B；专项测试空白：两个 banner 同时出现的高度竞争 | 已审计 |
| Update Notice Banner | 自动/手动更新状态有新版本或错误且 notificationVisible | `common/update_notice_banner.dart` `UpdateNoticeBanner` | 可用、已下载、错误、稍后提醒、查看详情 | `<520` 或 text scale `>1.3` 改纵排；640 上限、SafeArea | `update_notice_banner_test.dart` / A | 已审计 |
| Auth Recovery Banner | auth status=error 且有 errorCode | `router/global_status_banners.dart` `_AuthRecoveryBanner` | 重试、去登录、关闭、长错误 | `<600` 或 text scale `>1.3` 改纵排；760 上限 | `main_shell_auth_prompt_test.dart` 不直接覆盖 / B；专项测试空白：自身宽度/大字体 | 已审计 |
| 普通 Toast 栈 | 全项目 `AppToast.success/error/warning/info` | `common/app_toast.dart` `_ToastStack`/`_SingleToastWidget` | 四语义类型、多条堆叠、超时、手动关闭、根 Overlay 替换 | compact 顶部居中；锚定菜单策略顶部右侧；SafeArea、可滚动、Reduce Motion | `app_toast_test.dart` / A | 已审计 |
| Progress Toast | 长任务 `AppToast.showProgress` | `app_toast.dart` `_ProgressToastWidget` | 不定/确定进度、更新、完成、失败、替换、关闭 | root Overlay；单例；触控/精确指针布局；Reduce Motion | `app_toast_test.dart` / A | 已审计 |
| Global Drop Hover Overlay | 桌面外部文件拖入应用 | `drop/global_drop_handler.dart`→`GlobalDropOverlay` | dragging true/false | 仅 external file drop capability；全屏、SafeArea、420 上限、滚动 | `global_drop_overlay_test.dart`、`global_drop_handler_test.dart` / A | 已审计 |
| Global Drop Processing Overlay | 文件 drop/paste 正在解析 | `GlobalDropHandler`→`GlobalDropProcessingOverlay` | processing true/false | 全屏阻断、SafeArea、420 上限、滚动 | `global_drop_overlay_test.dart` / A | 已审计 |
| Image Destination Form | 全局图片 drop/paste 解析完成 | `drop/image_destination_dialog.dart` `ImageDestinationDialog.show` | 普通图、NAI metadata、解析错误、Vibe/bundle、目标能力 | `AdaptivePresenter.showForm`；480/960 side sheet；内容自适应 | `image_destination_dialog_test.dart` / A | 已审计 |
| Prompt Library Entry Form | Drop 目标选择“保存 Prompt 到词库” | `drop/prompt_library_entry_dialog.dart` `PromptLibraryEntryDialog.show` | 新建/追加/覆盖、分隔符、目标、分类、更多、保存错误/成功短通知 | adaptive form、共享 scroll controller、窄屏/大字条件 | `prompt_library_entry_dialog_test.dart` / A | 已审计 |
| Drop Vibe 命名 Form | drop 检出单 Vibe/bundle 后保存到库 | `drop/global_drop_action_coordinator.dart` `showVibeLibraryNamingForm` | 单项/Bundle、名称校验、取消/保存 | `AdaptivePresenter.showForm`；520 side sheet、可滚动 | `global_drop_handler_test.dart` 间接 / B；专项测试空白：命名 form 独立宽度/IME | 已审计 |
| Tag Library Drop Menu | 在词库目标上 drop 图像 | `drop/tag_library_drop_handler.dart`→`TagLibraryDropMenu.show` | 创建词条、更新预览、取消、系统返回 | `AdaptivePresenter.showForm`；Compact 全屏、Medium 居中、Expanded side sheet；SafeArea/IME/滚动 | `tag_library_drop_menu_test.dart` / A | 已审计 |
| Drop 结果短通知组 | coordinator 各目标处理完成/警告/失败 | `drop/global_drop_action_coordinator.dart` 多处 `AppToast` | img2img、反推、Vibe、角色参考、metadata、队列等结果 | 统一继承 AppToast 响应策略 | `global_drop_handler_test.dart` 行为 + `app_toast_test.dart` 视觉 / B；专项测试空白：逐文案视觉 | 已审计（共享通知） |

## Agent Chat

| 单元 | 真实入口 | 实现 | 关键状态 | 响应条件 | 专项测试 / 证据级别 | 实现审计 |
|---|---|---|---|---|---|---|
| Agent Chat Panel | Shell Agent 面板、生成页右栏、移动生成全屏 | `agent_chat/widgets/agent_chat_panel.dart` `AgentChatPanel` | 初始化、会话、消息流、状态、composer、drop、settings/close | fullScreen、宽 `<600` 或高 `<=520`/IME 改 stacked；SafeArea；阅读缩放 | `agent_chat_panel_test.dart`、`agent_chat_mobile_responsive_test.dart` / A | 已审计 |
| Agent Header | Chat Panel 顶部 | `agent_chat_header.dart` `AgentChatHeader` | 会话选择、新会话、更多、关闭/折叠 | fullScreen/compact/desktop key；56 高；interaction policy 命中区 | `agent_chat_header_test.dart` / A | 已审计 |
| Session Picker Menu/Sheet | 点击 header 会话标题 | `core/windowing/agent_chat_session_picker.dart`，由 `AgentChatHeader` 调用 | 选择、新建、重命名、删除、transition 禁用 | touchOptimized 用 bottom sheet；否则 `MenuAnchor`；长列表滚动 | `agent_chat_header_test.dart`、`core/windowing/agent_chat_session_picker_test.dart` / A | 已审计 |
| Header More Menu | 点击 header 更多 | `agent_chat_header.dart` `PopupMenuButton` | rename/compact/delete/settings，按活动会话与 transition 显隐 | 锚定 popup；最小宽 220；触控 extent | `agent_chat_header_test.dart` / A | 已审计 |
| New Session 短动作 | Header 新建按钮或 session picker | coordinator `newSession` | transition 中禁用、成功切换 | 无独立 surface；状态原位更新 | `agent_chat_panel_test.dart` / A | 已审计 |
| Rename Session Input Form | Header More/Session Picker“重命名” | `agent_chat_panel_coordinator.dart`→`ThemedInputDialog.show` | 初值、空值校验、取消/提交 | common input dialog 自适应 | `agent_chat_panel_test.dart` 间接、`themed_input_dialog_test.dart` / B | 已审计（组合证据） |
| Delete Session Confirm | Header More/Session Picker“删除” | coordinator→`ThemedConfirmDialog.showDelete` | 危险确认、取消/删除 | compact adaptive form；expanded AlertDialog | `agent_chat_panel_test.dart` 间接、`themed_confirm_dialog_test.dart` / B | 已审计（组合证据） |
| Compact Session 状态/短通知 | Header More“压缩” | coordinator + `AgentChatStatus` + `AppToast` | compacting、成功/无需压缩/失败 | panel 内原位状态；结果统一顶部 Toast | `agent_chat_status_test.dart`、coordinator 静态调用 / B；专项测试空白：结果位置一致性 | 已审计 |
| Agent Composer 编辑面 | Chat routeReady | `agent_chat_composer.dart` `AgentChatComposer` | 草稿、发送、运行中 steer queue、停止、附件、模型、推理、权限、web、context、扩展编辑、消息编辑 | mobile/desktop、极窄桌面、IME、320/520、输入组合态 | `agent_chat_composer_test.dart` / A | 已审计 |
| Composer 扩展编辑态 | 点击 composer 扩展 | `AgentChatComposer` 内 expanded editor | 多行编辑、运行中 stop、取消/恢复、IME | 高度与 SafeArea 约束；320/520 和 Android IME | `agent_chat_composer_test.dart` / A | 已审计 |
| 已发消息编辑态 | 最新安全 user message 的 Edit | `AgentChatMessages`→controller→composer edit header | 恢复文本/图片/资源、取消、重发 | 复用 composer，不新建业务流 | `agent_chat_edit_message_test.dart` / A | 已审计 |
| Slash Command 内联 Menu | composer 开头输入 `/` | `agent_chat_slash_menu.dart` `AgentChatSlashMenu` | 搜索、分组、highlight、键盘选择/Esc、session command | 内联位于编辑器上方；touch 58/208 高、精确指针 48/244 高 | `agent_chat_composer_test.dart` / A | 已审计 |
| Compact Controls Menu | compact composer 更多 | `agent_chat_composer.dart` `PopupMenuButton<_AgentChatCompactControlAction>` | 模型、推理、权限、web/context 等压缩动作 | 极窄宽度用单菜单保留能力 | `agent_chat_composer_test.dart` / A | 已审计 |
| Desktop Attachment Menu | desktop composer “+” | `agent_chat_composer.dart` attachment `PopupMenuButton` | 上传图片、当前画布、历史、资源库；按能力禁用 | 锚定 popup | `agent_chat_composer_test.dart` / A | 已审计 |
| Mobile Attachment Sheet | mobile composer “+” | `agent_chat_composer.dart` `_showMobileAttachmentSources` | 同 desktop 附件动作、当前画布可用性 | `showModalBottomSheet`、SafeArea、scroll controlled、drag handle | `agent_chat_composer_test.dart` / A | 已审计 |
| Model Picker Sheet/Side Sheet | composer 模型控件 | `agent_chat_model_picker.dart` `_showAgentChatModelPicker` | 全量模型、当前选中、搜索、空结果、键盘 highlight | `AdaptivePresenter.showPanel`；compact bottom sheet、expanded 620 side sheet；0.5–0.96 | `agent_chat_model_picker_test.dart` / A | 已审计 |
| Thinking Level Menu | composer 推理控件 | `AgentChatThinkingControl` `PopupMenuButton` | 仅支持等级、当前选中、禁用 | anchored popup；行高跟触控/字号 control extent | `agent_chat_model_picker_test.dart` / A | 已审计 |
| Permission Mode Menu | composer 权限控件 | `agent_chat_composer.dart` `PopupMenuButton<AgentPermissionMode>` | safe/ask/full、设置不可交互态 | anchored popup；interaction control extent | `agent_chat_composer_test.dart` / A | 已审计 |
| Reference Gallery Panel | attachment“本地历史” | `agent_chat_resource_widgets.dart` `showReferenceGallery` | 初始化、加载、错误/重试、取消、选择 | `AdaptivePresenter.showPanel`；0.5–0.9，1180 side sheet | `agent_chat_resource_widgets_test.dart` / A | 已审计 |
| Resource Library Panel | attachment“资源库” | `agent_chat_resource_widgets.dart` `showResourceLibrary` | Vibe/精准参考模式、初始化、加载/空/错误、选择 | `AdaptivePresenter.showPanel`；0.5–0.9，1180 side sheet | `agent_chat_resource_widgets_test.dart` / A | 已审计 |
| Pending Attachment Cards | composer 发送前附件区 | `agent_chat_resource_widgets.dart` pending image/resource cards | 预览、token 编号、移除、失效 | 受 composer 宽度与滚动约束；触控操作 | `agent_chat_composer_test.dart`、`agent_chat_resource_widgets_test.dart` / A | 已审计 |
| Sent Resource Cards | 消息 transcript 资源引用 | `agent_chat_resource_widgets.dart` sent cards/gallery | 加载、有效、不可用、打开、copy 失败短通知 | 消息流内有界卡片 | `agent_chat_messages_layout_test.dart`、`agent_chat_resource_widgets_test.dart` / A | 已审计 |
| Resource Drag Context Menu | 从 Agent 资源拖拽/右键 | `agent_resource_drop_region.dart` `showMenu<bool>` | 添加引用、资源不可用、成功/错误 SnackBar | 锚定指针坐标；拖放 capability | `agent_resource_drop_region_test.dart` / A；专项测试空白：菜单边缘定位 | 已审计 |
| Inline Image Hover Preview Overlay | hover transcript/tool 图片 | `agent_chat_panel_controller.dart` `_inlineImagePreview` | pointer 位置、显示/关闭、bytes | root Overlay，按 viewport clamp，预览尺寸受限 | `agent_chat_panel_test.dart` 间接 / B；专项测试空白：边缘/大缩放预览 | 已审计 |
| Network Image Full Preview Route | 点击工具结果网络图片 | `agent_chat_tool_widgets.dart` `_showNetworkImagePreview` | loading/success/error、缩放、关闭 | 独立全屏 route；SafeArea/IME；Reduce Motion；图片 fitting | `agent_chat_tool_widgets_test.dart` / A | 已审计 |
| Agent Error Card 展开态 | state.error 非空 | `agent_chat_status.dart` `_AgentChatErrorCard` | 摘要、详情展开、retry、dismiss | `<600` margin；详情 140 高滚动；触控 extent | `agent_chat_status_test.dart`、`agent_chat_tool_widgets_test.dart` / A | 已审计 |
| Compacting Inline Status | state.compacting | `AgentChatStatus` | 压缩中 | panel 内单行；无动画 | `agent_chat_status_test.dart` 间接 / B；专项测试空白：长本地化/3x | 已审计 |
| Sensitive Action Approval Panel | state.approvalRequest | `agent_chat_approval.dart` `AgentChatApprovalCard` | 参数脱敏、Anlas 估算、展开详情、允许/拒绝、单次提交 | shared approval surface；触控策略；提交后禁用且降透明度 | `agent_chat_approval_test.dart`、`agent_chat_status_test.dart` / A | 已审计 |
| Work Trail 折叠面板 | 每轮 tool/reasoning/narration | `agent_chat_turn.dart` `AgentChatWorkTrail` | running/completed、分组、折叠、详情 | 长线程懒保留；窄宽动作 Wrap/有界 | `agent_chat_turn_test.dart` / A | 已审计 |
| Tool Activity/Result/Reasoning 折叠面板 | 消息中的工具调用与结果 | `agent_chat_tool_widgets.dart` | running/success/error、详情、参数、copy、媒体、资源不可用 | 详情有界可滚动；任务层级跨宽度；无永动动画 | `agent_chat_tool_widgets_test.dart` / A | 已审计 |
| Tool/Resource Copy 与错误短通知 | 点击复制或打开失败 | coordinator/resource/tool widgets 的 `AppToast` | copied、resource unavailable、文件失败 | 统一继承全局 Toast 响应位置、SafeArea 与 Reduce Motion | `agent_chat_tool_widgets_test.dart` 行为 + `app_toast_test.dart` 视觉 / B | 已审计 |
| Jump-to-latest 浮动动作 | 用户离开底部且有新流内容 | `agent_chat_messages.dart`/controller | auto-follow、暂停、恢复、流式更新 | viewport 底部状态驱动；触摸/滚轮均可暂停 | `agent_chat_scroll_follow_test.dart`、`agent_chat_panel_test.dart` / A | 已审计 |

## Common Widgets 中的可达界面面

| 单元 | 真实入口 | 实现 | 关键状态 | 响应条件 | 专项测试 / 证据级别 | 实现审计 |
|---|---|---|---|---|---|---|
| Adaptive Dialog Frame | Emoji、传统 AlertDialog 内容等共享 | `common/adaptive_dialog_frame.dart` | SafeArea、IME、标题/动作预留、大字预留 | 直接按 viewport/padding/viewInsets 夹宽高 | `adaptive_dialog_frame_test.dart` / A | 已审计 |
| Add to Library Form | 角色卡、图像详情 metadata actions | `common/add_to_library_dialog.dart` `AddToLibraryDialog.show` | 名称、内容、分类、tags、保存中/成功/失败短通知 | `AdaptivePresenter.showForm`；compact 全屏、expanded side sheet 520 | `add_to_library_dialog_test.dart` / A | 已审计 |
| Emoji Picker Form | 随机词组/分类选择 emoji | `common/emoji_picker_dialog.dart` `EmojiPickerDialog.show` | 分类、搜索、最近、选择即返回、取消 | adaptive form 440；宽 `<280` 5 列否则 8 列；IME/大字 frame | `emoji_picker_dialog_test.dart`、presenter integration / A | 已审计 |
| Themed Confirm Dialog/Form | 删除、清空、覆盖、信息确认等全项目调用 | `common/themed_confirm_dialog.dart` | normal/danger/warning/info、取消/确认、焦点恢复 | window `<600` adaptive form；否则 AlertDialog；长文滚动 | `themed_confirm_dialog_test.dart` / A | 已审计 |
| Themed Input Form | Agent 重命名、画廊/相册/Vibe 名称等 | `common/themed_input_dialog.dart` | 初值、验证错误、取消/提交、IME | adaptive presenter；SafeArea、滚动、IME | `themed_input_dialog_test.dart` / A | 已审计 |
| Precise Reference Type Dialog | 发送到精准参考/生成精准参考添加 | `common/precise_reference_type_dialog.dart` | Character+Style/Character/Style 选择、取消 | AlertDialog 内容在短窄视口可滚动 | `precise_reference_type_dialog_test.dart` / A | 已审计 |
| Save As Preset Form | 图像详情 metadata action | `common/save_as_preset_dialog.dart` | 名称、分类、tags、保存、错误 | adaptive form；320/3x/IME 长表单滚动 | `save_as_preset_dialog_test.dart` / A | 已审计 |
| Save Vibe Form | 图像详情 Vibe action | `common/save_vibe_dialog.dart` | 单/多 Vibe、命名、分类、tags、保存 | adaptive form；320/3x/IME 长表单滚动 | `save_vibe_dialog_test.dart` / A | 已审计 |
| Update Check Form | 更新 banner、设置“检查更新” | `common/update_check_dialog.dart` `UpdateCheckDialog.show` | 检查中、最新、可更新、下载、校验、安装、错误、手动下载 | `AdaptivePresenter.showForm`；响应动作行；安装前短确认 AlertDialog | `update_check_dialog_test.dart` / A；专项测试空白：内嵌安装确认 320/3x | 已审计 |
| Prompt Copy Form | 图像详情/本地画廊复制 prompt | `common/image_detail/components/prompt_copy_dialog.dart` | 正/负/角色 prompt 选项、普通复制/导出、全选 | compact 全屏 form；expanded 有界 surface；大内容滚动 | `prompt_copy_dialog_test.dart` / A | 已审计 |
| Image Detail Viewer Screen/Dialog | 本地画廊与共享图片卡“查看详情” | `common/image_detail/image_detail_viewer.dart` `show/showSingle` | 单/多图、加载/错误、页切换、缩略图、actions、关闭、metadata | full-screen route；compact metadata 改 adaptive panel；键盘导航 | `image_detail_viewer_responsive_test.dart` / A | 已审计 |
| Image Detail Metadata Panel | Viewer expanded 常驻或 compact action 打开 | `common/image_detail/components/detail_metadata_panel.dart` | metadata、prompt、Vibe、copy/export/save actions | compact 通过 `AdaptivePresenter.showPanel`；窄+3x value 堆叠 | `detail_metadata_panel_responsive_test.dart`、`detail_metadata_panel_test.dart` / A | 已审计 |
| Image Detail Top-bar Overflow Menu | Viewer 顶栏空间不足/次要动作 | `common/image_detail/components/detail_top_bar.dart` | 当前图片 actions、关闭、overflow | responsive action compression；触控菜单保留动作 | `detail_top_bar_responsive_test.dart` / A | 已审计 |
| Image Card Context Menu/Action Sheet | `SelectableImageCard` 右键、长按、触控更多 | `common/image_card_context_menu.dart` | 按 capability/action catalog 显隐、loading、危险项 | touch 用 `AdaptivePresenter.showPanel`；precise pointer 用 `PopupRoute` | `selectable_image_card_gesture_test.dart`、`selectable_image_card_test.dart` / A | 已审计 |
| Pro Context Menu | ImageCard 与其他专业右键菜单 | `common/pro_context_menu.dart` | disabled、divider、icon、keyboard highlight、选择 | SafeArea 边缘 clamp；touch 48；长菜单滚动 | `pro_context_menu_test.dart` / A | 已审计 |
| Card Actions Touch Sheet | 卡片 action 组在触控端“更多” | `common/card_action_buttons.dart` `_showTouchActions` | 可见/隐藏、loading、选择动作 | adaptive panel；触控 48；长动作可达 | `card_action_buttons_test.dart` / A | 已审计 |
| Safe Dropdown Popup | 共享表单下拉 | `common/safe_dropdown.dart` | 当前值、disabled、focus、键盘选择 | popup 避让右/下边缘；触控 48；3x 长文本 | `safe_dropdown_test.dart` / A | 已审计 |
| Themed Dropdown Popup | 共享主题下拉字段 | `common/themed_dropdown.dart` | value/disabled/focus | Material dropdown；共享 input surface | `themed_dropdown_test.dart` / A；专项测试空白：本组件长菜单/边缘 | 已审计（SafeDropdown 的长菜单/边缘策略不外推为本组件专项证据） |
| Pagination 页码编辑态 | 画廊分页条点击页码/输入 | `common/pagination_bar.dart` | loading、页码编辑、提交/取消、导航 | 极窄重排；3x matrix；触控 48；loading 自动关编辑 | `pagination_bar_test.dart` / A | 已审计 |
| Image Picker Card loading/error/edit state | 需要选图的共享表单 | `common/image_picker_card/` `ImagePickerCard`/`LoadingOverlay` | empty、picking、preview、invalid、error、clear、desktop drag | 320–1600、3x/短高；loading overlay 有界；touch 选择 | `image_picker_card_test.dart` / A | 已审计 |
| Collapsible Image Panel 展开/hover preview | 生成/编辑共享图片折叠面板 | `common/collapsible_image_panel.dart` | collapsed、expanded、摘要、背景、hover preview | 宽度矩阵；键盘切换；Reduce Motion；root Overlay 边缘判断 | `collapsible_image_panel_test.dart` / A；专项测试空白：hover overlay 独立边缘 | 已审计 |
| Hover Image Preview Overlay | 图片 hover 包装器 | `common/hover_image_preview.dart` | hover 延时、目标变化、关闭 | 根据 viewport 缩小并避边；OverlayEntry | `hover_image_preview_test.dart` / A | 已审计 |
| Card/Gallery Hover Preview Overlay | gallery/card hover controller | `common/card_hover_preview_controller.dart`、`gallery_hover_controller.dart`、`hover_preview_card.dart` | intent 延时、取消、预览 loading/error | root Overlay、preferred size、viewport clamp | `gallery_hover_controller_test.dart`；card controller 静态 / B；专项测试空白：card controller 与 hover preview card 直接矩阵 | 已审计：三个实现并存是维护风险，不凭测试覆盖差异判为实现缺口 |
| Weight Adjust Floating Toolbar | prompt 文本选择后 | `common/weight_adjust_toolbar.dart` | selection、controller 替换、增减权重、wheel、focus | OverlayEntry 贴字段；窄 3x 保持屏内；键盘；pointer policy | `weight_adjust_toolbar_test.dart` / A | 已审计 |
| Composition Guide Overlay | 图像/画布启用 thirds/phi/grid | `common/composition_guide.dart` | none/thirds/phi/grid、行列、DPR | IgnorePointer 绘制层；像素对齐；无布局占用 | `composition_guide_test.dart` / A | 已审计 |
| Image Card Focused Preview Overlay | generation card streaming/focused preview | `common/image_card_focused_preview.dart`、`image_card_generating.dart` | stream slots、mask、decode、focus | 卡片内 overlay；Reduce Motion 由宿主 effects 控制 | `selectable_image_card_test.dart` / A | 已审计 |
| Image Card Drag Preparation Overlay | 开始导出/拖动共享图片卡 | `common/image_card_surface.dart` `_DragPreparationOverlay` | preparing/ready/failure | 卡片内阻断层；跟随卡片尺寸 | `draggable_memory_image_test.dart` 间接 / B；专项测试空白：overlay 语义与大字 | 已审计 |
| App State empty/loading/error Panel | 多页面共享空态/错误态 | `common/app_state_view.dart` `AppStateView` | empty/loading/error、action、disabled/loading | 窄+3x、Reduce Motion、touch 48、滚动可读 | `app_state_view_test.dart` / A | 已审计 |
| Prompt Section tag/edit expansion | Image Detail metadata 内 prompt 区 | `common/image_detail/components/prompt_section.dart` | raw/tag view、翻译、角色 section、展开/折叠 | 受 metadata panel 约束；tag wrap | `detail_metadata_panel_test.dart` 间接 / B；专项测试空白：自身 320/3x/超长 tag | 已审计 |
| Vibe Section expansion | Image Detail metadata 内 Vibe 区 | `common/image_detail/components/vibe_section.dart` | 多 Vibe 卡、展开/折叠 | panel 内滚动/Wrap | image detail tests 间接 / B；专项测试空白：自身宽度/大字 | 已审计 |
| Draggable Number / Editable Double 编辑态 | 参数型共享控件调用 | `common/draggable_number_input.dart`、`editable_double_field.dart` | display→edit、拖动、提交、取消、focus | 触控 48；精确指针拖动与原生文本编辑；3x 自适应宽度；resize 保留编辑态 | `adaptive_numeric_input_test.dart` / A | 已审计 |
| Themed Input 清空确认编辑态 | 共享文本输入启用 clear confirmation | `common/themed_input.dart`→`ThemedConfirmDialog` | focus、clear、确认、controller 内容更新 | 不占布局 focus outline；确认继承 adaptive dialog | `themed_input_test.dart`、`themed_confirm_dialog_test.dart` / A | 已审计 |

## 汇总

### 实现审计结论

1. 当前逐项源码复核未保留真实自适应实现缺口；Chat 短反馈已统一为 `AppToast`。
2. Slideshow / Image Comparison 路由通过 typed runtime payload 接收完整图片记录；无 payload 的外部深链保留明确、可返回的空态。

### 专项测试空白

1. Desktop 账号 Menu 的锚定和 Material 安全视口约束已完成代码审计；缺少窄高窗口、3x 文本与键盘遍历专项矩阵，不影响实现完成结论。
2. 其余空白集中在：双全局 banner 高度竞争、少数短确认/安装确认的 320px + 3x 矩阵、部分 hover/drag overlay 边缘与大字矩阵，以及若干宿主已覆盖但单元未独立覆盖的状态。
3. 本审计没有把 Shell 的入口证据外推为各业务 Screen 的全部子界面证据；表中引用业务 Screen 自己的直接测试，仅证明相应专项证据存在。
