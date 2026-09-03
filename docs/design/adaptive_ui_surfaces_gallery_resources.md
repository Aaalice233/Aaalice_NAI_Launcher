# 画廊、资源库与统计自适应 UI Surface 审计

> 审计范围：`local_gallery`、`online_gallery`、`tag_library_page`、`vibe_library`、`precise_ref_library`、`statistics`，以及这些入口直接调用的相关 widgets。审计日期：2026-09-02。本文只记录代码与仓库现存测试；本次未运行测试或真实 Windows/Android UI。

## 证据口径

- **D2**：测试通过该 UI 单元的生产 `show/open` 入口或真实 Screen 直接打开并操作该单元。
- **D1**：测试直接构建该 UI 单元或其专用可见实现；不证明生产入口连接。
- **D0**：未找到直接测试，仅有源码静态证据。父 Screen、父 Panel 或共享 presenter 的测试一律不向子 Dialog/Menu/Overlay 外推。
- “响应条件”只写实现中的局部 constraints、`WindowSizeClass`、文字缩放、输入策略、SafeArea/IME 或业务 capability；未写出的尺寸和组合状态不视为覆盖。
- “实现已审计”表示当前源码已逐项核对且未发现该 UI 单元的实现缺失；专项测试是否存在只写入证据说明。D0 或状态矩阵未穷举不等于实现缺口，也不以“缺口”描述证据空白。
- 只有源码中确实缺少入口、触屏等价操作、自适应约束或 Reduce Motion 处理时，才标为“实现缺口”并明确说明。

## 本地画廊

| UI 单元 | 入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|
| LocalGalleryScreen | `/local-gallery` | `lib/presentation/screens/local_gallery/local_gallery_screen.dart` | loading/error/empty/no-results/data、分页、选择、分类请求 | `<1000` 分类用面板，`>=1000` persistent；网格按局部宽度 | `local_gallery_screen_test.dart`（D1：999/1000 与布局公式） | 实现已审计；专项证据部分；无真实路由、IME/大字页面级直接证据 |
| 分类/相簿 persistent Panel | 页面左侧分类入口 | `screens/local_gallery/local_gallery_category_panel.dart` | 全部图片/收藏、相簿、文件夹、独立折叠、modal | 仅页面局部宽 `>=1000` persistent | `local_gallery_category_panel_test.dart`（D1） | 实现已审计；有组件证据；无跨断点状态组合证据 |
| 分类/相簿 adaptive Sheet | 工具栏“分类”或快捷键 | `local_gallery_screen_controller.dart::showCategoryPanelSheet` → `LocalGalleryCategoryPanel` | 与 persistent 同状态，选择后关闭 | `<1000`；`AdaptivePresenter` bottom/side 形态 | `local_gallery_category_panel_test.dart` modal 用例（D1） | 实现已审计；专项证据部分；未直接调用生产 `showCategoryPanelSheet` |
| GalleryScanProgressPanel（宿主 1） | `LocalGalleryCategoryPanel` 底部 | `local_gallery_category_panel.dart:174` → `widgets/gallery/gallery_scan_progress_panel.dart` | 扫描中、总数为 0、不同比例、当前阶段/文件；非扫描隐藏 | 跟随分类宿主宽度；图例 `Wrap` | `gallery_scan_progress_panel_test.dart` 仅 helper/动画（D1） | 实现已审计；专项证据空白；宿主内完整面板布局未直接测 |
| GalleryScanProgressPanel（宿主 2） | `GalleryCategoryTreeView(showScanProgress: true)` | `widgets/gallery/gallery_category_tree_view.dart:146` → `gallery_scan_progress_panel.dart` | 同上 | 跟随树视口；是否出现由 `showScanProgress` 与 provider 决定 | 无直接宿主测试（D0） | 实现已审计；专项证据空白；不得由宿主 1 外推 |
| GalleryScanProgressPanel Reduce Motion | 扫描条 processing segment | `gallery_scan_progress_panel.dart::_AnimatedStripes` | 动画开/关、无效/极大画布 | `MediaQuery.disableAnimations=true` 时 controller 停止并固定 `value=1`；否则 repeat | `gallery_scan_progress_panel_test.dart`（D1：开/关、边界与 4096 条上限） | 实现已审计；有直接证据；只覆盖条纹，不代表整个面板 |
| 本地工具栏普通态 | 页面顶部 | `widgets/gallery/local_gallery_toolbar.dart` | 搜索、计数、刷新、筛选、分类、视图、分页/更多 | actions 可换行；320/360/600/840/1180/1600 与 3x | `local_gallery_toolbar_selection_test.dart`（D1） | 实现已审计；有所列宽度证据 |
| 本地工具栏多选编辑态 | 长按/多选按钮 | `local_gallery_toolbar.dart` + selection provider | 当前页/全部结果选择、移出相簿、移动、元数据、打包、删除、退出 | 窄宽/3x 保持全部操作 | `local_gallery_toolbar_selection_test.dart`（D1） | 实现已审计；有直接证据；无完整生产批量流程证据 |
| 工具栏更多 Menu | 普通态更多按钮 | `local_gallery_toolbar.dart::PopupMenuButton` | 相册/目录能力、排序/视图等条件项 | capability 与可用 callbacks 决定菜单项 | 无专用直接测试（D0） | 实现已审计；专项证据空白；工具栏存在测试不能外推菜单内容 |
| GalleryFilterPanel | 工具栏/快捷键筛选 | `lib/presentation/widgets/gallery_filter_panel.dart` | 日期、评分、模型、尺寸等筛选，清除/应用 | Adaptive panel；320/360/390/700、3x、IME、SafeArea | `gallery_filter_panel_test.dart`（D2） | 实现已审计；有生产 show 入口证据 |
| GalleryContentView | 页面内容区 | `widgets/gallery/gallery_content_view.dart` | loading/error/empty/no-results/data、grid/grouped、选择 | 局部网格列数、触屏显式操作、指针 secondary tap | `gallery_content_view_context_menu_test.dart`（D1） | 实现已审计；专项证据部分；状态视图无逐状态直接测试 |
| GalleryGrid | 内容区网格模式 | `widgets/gallery/gallery_grid.dart` | 列数、滚动、选择、resize、模式切换 | 按局部宽度算列；resize 保持 selection/offset | `gallery_grid_responsive_test.dart`（D1） | 实现已审计；有直接响应证据 |
| 分组列表/日期组编辑态 | 内容区 grouped 模式 | `gallery_content_view.dart`、`widgets/grouped_grid_view.dart` | 日期分组、组 loading、卡片操作、跳转日期 | 局部约束；与 grid 切换保持 offset | `gallery_grid_responsive_test.dart`、`gallery_content_view_context_menu_test.dart`（D1） | 实现已审计；专项证据部分；日期跳转 DatePicker 未联动测试 |
| 本地卡片 | 网格/分组条目 | `widgets/gallery/local_image_card_3d.dart` | 缩略图/失败、收藏、选择、元数据层、拖放、发送 | touch 显式更多；窄 Android 隐藏元数据；Reduce Motion 关闭 hover motion | `local_image_card_thumbnail_test.dart`、`gallery_content_view_context_menu_test.dart`（D1） | 实现已审计；专项证据部分；Reduce Motion 无该卡专用测试 |
| 本地卡片 touch Menu | 卡片更多按钮 | `local_image_card_3d.dart::_buildTouchActionMenu` | 收藏、详情、发送、水印、系统相册、删除等 capability 项 | `shouldExposeTouchAlternatives`；窄卡仍可达 | `local_image_card_thumbnail_test.dart`（D1：水印/系统相册） | 实现已审计；专项证据部分；未穷举菜单项 |
| LocalImageContextMenu | 右键或卡片发送按钮 | `widgets/gallery/local_image_context_menu.dart` | metadata 有/无、Krita、水印衍生、Android 相册、send 子菜单 | 锚点避边/SafeArea；无展开动画 | `local_image_context_menu_test.dart`（D2） | 实现已审计；有直接证据；320 边缘锚点已覆盖 |
| LocalImageHoverPreview Overlay | 精细指针悬停卡片 | `widgets/gallery/local_image_hover_preview.dart` | 预览、metadata、dismiss、视口边缘 | 仅精细指针加速入口；约束到 viewport | `local_image_hover_preview_test.dart`（D1） | 实现已审计；有组件证据；无 Reduce Motion 专测 |
| 分类树节点/空白 Menu | 分类栏右键或触屏更多 | `widgets/gallery/gallery_category_tree_view.dart` | 新建、子分类、重命名、移动、删除、拖入图片 | pointer 锚定 `showMenu`；touch `PopupMenuButton` | `gallery_category_tree_view_drag_test.dart` 仅 drag data（D1） | 实现已审计；专项证据空白；菜单无直接测试 |
| 相簿树节点 Menu | 相簿右键或触屏更多 | `widgets/gallery/gallery_album_tree_view.dart` | 新建子相簿、重命名、移动、删除、拖入图片 | pointer/touch 双入口 | 无专用直接测试（D0） | 实现已审计；专项证据空白 |
| 分类/相簿 CRUD 输入与确认 Dialog | 分类/相簿菜单 | `local_gallery_screen_controller.dart` → `ThemedInputDialog` / `ThemedConfirmDialog` | 新建、重命名、删除、保护确认 | 共享 adaptive dialog；IME/SafeArea 由共享实现 | `themed_input_dialog_test.dart`、`themed_confirm_dialog_test.dart` 仅共享组件（D1） | 实现已审计；专项证据空白；具体菜单到业务回调未直测 |
| MoveTarget Dialog | 多选“移动到分类” | `screens/local_gallery/local_gallery_move_target.dart` | 空 targets、层级 labels、选择、取消 | `AdaptivePresenter`，side width 440 | `local_gallery_move_target_test.dart`（D2） | 实现已审计；有生产入口证据 |
| AlbumSelect Dialog | 多选“加入相簿” | `widgets/gallery/album_select_dialog.dart` | loading/error/empty/search/选择/新建 | adaptive panel，side width 450 | `collection_album_select_presenter_test.dart`（D1，非该类专名入口） | 实现已审计；专项证据部分；`AlbumSelectDialog.show` 无专用返回值测试 |
| ZIP metadata Dialog | 多选“打包” | `widgets/gallery/zip_export_metadata_dialog.dart` | 保留/移除 metadata、取消 | adaptive panel，side width 520 | `zip_export_metadata_dialog_test.dart`（D2） | 实现已审计；有结果证据；无窄屏/IME 专测 |
| ZIP partial-failure Sheet | 打包部分失败 | `local_gallery_action_coordinator.dart::showLocalGalleryZipFailureDetails` | 长失败列表、文件名/错误、关闭 | adaptive panel，side width 600，ListView + SafeArea | `local_gallery_adaptive_presentations_test.dart`（D2：400/1180） | 实现已审计；有入口级宽度证据 |
| BulkMetadataEdit Dialog | 多选“编辑元数据” | `lib/presentation/widgets/bulk_metadata_edit_dialog.dart` | 选中项、字段编辑、进度/结果 | adaptive form | `local_gallery_bulk_dialog_responsive_test.dart`（D2） | 实现已审计；有直接响应证据 |
| BulkProgress Dialog | 批量元数据操作执行后 | `lib/presentation/widgets/bulk_progress_dialog.dart` | running/completed/error、关闭 | 320 窄宽；状态原位切换 | `local_gallery_bulk_dialog_responsive_test.dart`（D1） | 实现已审计；有三状态组件证据；生产联动未直测 |
| MetadataImport Dialog | 单图“导入参数/文生图” | `widgets/metadata/metadata_import_dialog.dart` | 可导入字段、选择、空选择、应用 | adaptive form | `metadata_import_dialog_test.dart`（D2） | 实现已审计；有直接组件入口证据；画廊联动未直测 |
| PromptCopy Dialog | 单图“复制 Prompt” | `widgets/common/image_detail/components/prompt_copy_dialog.dart` | 分类字段、固定词、选择/复制 | adaptive form | `prompt_copy_dialog_test.dart`（D2） | 实现已审计；有直接证据 |
| PreciseReferenceType Dialog | 单图“发送到精确参考” | `widgets/common/precise_reference_type_dialog.dart` | character/style 类型、取消 | adaptive selection form | `precise_reference_type_dialog_test.dart`（D2） | 实现已审计；有直接证据 |
| DiscordShare Dialog | 单图“分享到 Discord” | `widgets/discord_share/discord_share_dialog.dart` | 配置、预览、发送中、成功/失败 | SafeArea/IME/大字由专测场景覆盖 | `discord_share_dialog_test.dart`（D2） | 实现已审计；有直接证据；画廊入口联动未直测 |
| 单图/批量删除与保护确认 | 卡片/批量工具栏 | `local_gallery_action_coordinator.dart` → `ThemedConfirmDialog` / `AssetProtectionGuard` | 普通确认、受保护资源二次确认、取消/失败 | shared dialog | 无画廊业务专测（D0） | 实现已审计；专项证据空白；不得由共享确认框外推业务链 |
| 权限拒绝/首次索引提示 Dialog | 页面启动扫描 | `local_gallery_screen_controller.dart::_showPermissionDeniedDialog/_showFirstTimeTip` | 权限失败、首次提示、继续/取消 | shared confirm/info dialog | 无直接测试（D0） | 实现已审计；专项证据空白 |
| 日期选择 Dialog | 工具栏跳转日期 | `local_gallery_screen_controller.dart::jumpToDate` → `showDatePicker` | 日期选择/取消 | Material date picker，主题覆盖 | 无直接测试（D0） | 实现已审计；专项证据空白 |

## 在线画廊

| UI 单元 | 入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|
| OnlineGalleryScreen | `/online-gallery` | `lib/presentation/screens/online_gallery/online_gallery_screen.dart` | 初始化/载入/错误/空/data、search/popular/favorites/random、多选 | 页面由局部 constraints 驱动 toolbar/grid | `online_gallery_source_auth_test.dart` 多场景直接构建 Screen（D1） | 实现已审计；专项证据部分；无真实路由证据 |
| OnlineGalleryContent 状态面 | Screen 内容区 | `screens/online_gallery/online_gallery_content.dart` | loading/error/empty/auth-error/data、暂停/续载 | 认证错误可开 adaptive 凭据面板 | `online_gallery_source_auth_test.dart`（D1：来源/空页续载等） | 实现已审计；专项证据部分；各状态未逐一直接断言 |
| 桌面/平板双行 Toolbar | Screen 顶部 | `screens/online_gallery/widgets/online_gallery_toolbar/**` | 全局第一行、来源第二行、搜索/热门/收藏/分级/多选 | 非 Compact；`<1800` 第一行可滚动，`<1100` 紧凑/折叠来源控件，text scale `>1.2` 强制紧凑 | `online_gallery_source_auth_test.dart`（D1：700/840/1180/1600，QuickTagCloud 与 3x） | 实现已审计；有所列场景证据 |
| Compact Toolbar | Screen 顶部 | `online_gallery_toolbar_feature.dart` | 紧凑搜索 reveal、来源/模式、全局动作、来源动作 | `WindowSizeClass.isCompact`（`<600`） | `online_gallery_source_auth_test.dart`（D1：320/360） | 实现已审计；专项证据部分；所有菜单分支未穷举 |
| Compact SearchReveal 编辑态 | Compact 搜索按钮 | `online_gallery_search_reveal.dart` | 收起/展开、输入、提交、关闭 | Compact；保持 controller/focus | 无专用直接测试（D0） | 实现已审计；专项证据空白 |
| Source Dropdown Menu | Toolbar 站点按钮 | `online_gallery_toolbar.dart::OnlineGallerySourceDropdown` | 各来源、当前选中、capability | popup menu | 来源切换在 `online_gallery_source_auth_test.dart` 间接操作（D1） | 实现已审计；专项证据部分；菜单视觉/边缘无专测 |
| Rating Dropdown Menu | Toolbar 分级 | `online_gallery_toolbar.dart::OnlineGalleryRatingDropdown` | General/Questionable/Explicit | popup menu；全局第一行 | QuickTagCloud rating 复用测试（D1） | 实现已审计；专项证据部分 |
| ViewMode Menu | 模式入口 | `online_gallery_toolbar_feature.dart::PopupMenuButton<GalleryViewMode>` | 搜索/热门/收藏、来源 capability | 紧凑布局或模式按钮入口 | `online_gallery_source_auth_test.dart`（D1：random/pagination 与来源模式） | 实现已审计；专项证据部分；菜单本体未专测 |
| Compact Global Actions Menu | Compact 更多按钮 | `online_gallery_toolbar_feature.dart::_MobileGalleryAction` | 黑名单、输出过滤、随机、刷新、多选等 | Compact/touch 显式入口 | `online_gallery_source_auth_test.dart`（D1：320/360 全局控件） | 实现已审计；专项证据部分；每项回调未穷举 |
| AI TAG source Menu | AI TAG 来源操作 | `online_gallery_toolbar_source_controls.dart::MenuAnchor` | 榜单/日期/来源筛选等 | 来源为 AI TAG；第二行/compact 来源面板 | `online_gallery_source_auth_test.dart`（D1：700/840/1180/1600） | 实现已审计；有布局证据；菜单动作部分 |
| Account Popup Menu | 账号入口 | `online_gallery_toolbar_auth.dart` | 登录、账号信息、退出、来源专属说明 | 来源 capability/登录状态；无账号来源不显示 | `online_gallery_source_auth_test.dart`（D1：各来源/模式） | 实现已审计；有来源可见性证据；完整 menu 回调未穷举 |
| DateRange Overlay | 日期按钮 | `online_gallery_toolbar_dialogs.dart` 手工 `OverlayEntry` | 起止日期、应用/取消、外部关闭、dispose | 约束到可用宽度；320/360；文字缩放扩大内容宽 | `online_gallery_source_auth_test.dart`（D2：320/360、关闭、Screen dispose 移除） | 实现已审计；有入口与生命周期证据 |
| 来源筛选 adaptive Panel | compact 来源筛选按钮 | `online_gallery_toolbar_dialogs.dart::showSiteFilters` | 仅当前来源专属控件；不得含全局黑名单/输出过滤 | adaptive panel，side width 480 | `online_gallery_source_auth_test.dart` toolbar 场景（D1） | 实现已审计；专项证据部分；面板内容无独立完整测试 |
| Danbooru Login Panel | 账号入口 | `online_gallery_auth_dialogs.dart` → `widgets/danbooru_login_dialog.dart` | 凭据、loading/error/success | adaptive panel，side width 440；IME/SafeArea | `danbooru_login_dialog_test.dart`（D1）；toolbar 入口测试（D2） | 实现已审计；有直接组件和入口证据 |
| Gelbooru Credentials Panel | 账号入口或认证错误 | `online_gallery_auth_dialogs.dart` / `online_gallery_content.dart` → `gelbooru_credentials_dialog.dart` | 未配置、错误、保存/取消 | adaptive panel，side width 480；320/1180 | `online_gallery_source_auth_test.dart`（D2） | 实现已审计；有生产入口证据 |
| Blacklist Settings Panel | 全局黑名单按钮 | `widgets/online_gallery/blacklist_settings_panel.dart` | 本地规则、搜索/增删、Danbooru 登录/同步、长列表 | adaptive panel，side width 728；320 大字/短高/expanded bounded | `blacklist_settings_panel_test.dart`（D2） | 实现已审计；有广泛直接证据 |
| Blacklist Import Form | Blacklist Panel“导入” | `blacklist_settings_panel.dart::_BlacklistImportForm` | 文本导入、opaque 规则、保留标签、错误 | adaptive form，side width 560；IME/大字 | `blacklist_settings_panel_test.dart`（D1） | 实现已审计；有直接内容证据 |
| Blacklist Push Review Form | Blacklist Panel“推送云端” | `blacklist_settings_panel.dart::_BlacklistPushReviewForm` | diff、空云端/opaque-only/旧账号迁移额外 gate | adaptive form，side width 620；短高保持双 gate | `blacklist_settings_panel_test.dart`（D1） | 实现已审计；有直接风险状态证据 |
| Blacklist destructive Confirm | 清空/替换操作 | `blacklist_settings_panel.dart::showDialog<bool>` | 危险确认、取消 | responsive constraints + inset padding，`scrollable: true` | `blacklist_settings_panel_test.dart`（D1：额外确认） | 实现已审计；有业务直接证据 |
| Output Filter Settings Panel | 全局输出过滤按钮 | `widgets/online_gallery/output_filter_settings_panel.dart` | 多 tag 输入、列表、删除、清空 | adaptive panel，side width 768；320 大字短高/expanded bounded | `output_filter_settings_panel_test.dart`（D2） | 实现已审计；有直接入口证据 |
| Output Filter clear Confirm | 过滤面板清空 | `output_filter_settings_panel.dart::showDialog` | 清空确认/取消 | responsive constraints + inset padding，`scrollable: true` | `output_filter_settings_panel_test.dart`（D1，面板流程） | 实现已审计；专项证据部分；无独立 confirm 断言 |
| QuickTagCloud Toolbar/来源行 | QuickTagCloud 来源 | `widgets/online_gallery/quick_tag_cloud_toolbar.dart` | 法典、分类、筛选、更新、最近浏览、贡献者 | 第二行；320/360/700/840/1180/1600，3x | `quick_tag_cloud_toolbar_test.dart`、`online_gallery_source_auth_test.dart`（D1） | 实现已审计；有直接响应证据 |
| QuickTagCloud Codex Picker Panel | 法典按钮 | `quick_tag_cloud_toolbar.dart` | loading/列表/选择、单击切换 | adaptive panel，side width 680 | `quick_tag_cloud_toolbar_test.dart`（D1） | 实现已审计；有直接交互证据 |
| QuickTagCloud Category Picker Panel | 分类按钮 | `quick_tag_cloud_toolbar.dart` | 层级、计数、全部分类、多选 | adaptive panel，side width 580 | `quick_tag_cloud_toolbar_test.dart`（D1） | 实现已审计；有直接交互证据 |
| QuickTagCloud Filter Panel | 筛选按钮 | `quick_tag_cloud_toolbar.dart::_showFilterDialog` | media 类型、更新范围、apply/cancel；不重复 rating | adaptive panel，side width 560 | `quick_tag_cloud_toolbar_test.dart`（D2） | 实现已审计；有 apply 与职责边界证据 |
| QuickTagCloud Contributors Panel | 贡献者按钮 | `quick_tag_cloud_toolbar.dart` | 完整 contributors/attribution、长列表 | adaptive panel，side width 580 | `quick_tag_cloud_toolbar_test.dart` list-dialog 用例（D1） | 实现已审计；专项证据部分；完整 attribution 数据链不属 UI 测试 |
| OnlineGalleryGrid/Masonry | 内容 data 状态 | `screens/online_gallery/online_gallery_grid.dart`、`online_gallery_masonry_layout.dart` | placeholders、append、深跳、可见性、滚动恢复 | 列数取网格宽；零 constraints/列变化恢复 anchor | `online_gallery_grid_test.dart`（D1） | 实现已审计；有直接布局/状态保持证据 |
| GalleryGridItem | 网格条目 | `screens/online_gallery/gallery_grid_item.dart` | detail loading/error/retry/cancel、缺尺寸、AI TAG media | visibility scope 控制解析与重试 | `gallery_grid_item_test.dart`（D1） | 实现已审计；有直接状态证据 |
| Pending/placeholder Card | initial/append loading | `online_gallery_grid.dart::OnlineGalleryPendingCard`、`online_gallery_image_placeholder.dart` | loading/failure、稳定占位几何 | 继承 masonry slot | `online_gallery_grid_test.dart`、`online_gallery_image_placeholder_test.dart`（D1） | 实现已审计；有直接证据 |
| Online card status Overlays | 卡片角标 | `widgets/online_gallery/online_gallery_card_status_overlays.dart` | rating、favorite/read-only、video、多媒体/状态 | 根据 capability/来源显示 | `danbooru_post_card_test.dart` 覆盖部分 badges（D1） | 实现已审计；专项证据部分；该 overlay 类无专测 |
| Online card hover/press 状态 | 网格卡片 | `widgets/danbooru_post_card.dart`、`online_gallery_hover_controller.dart` | hover preview、touch action、收藏、只读 | mixed input；hover 不作唯一入口；Reduce Motion 关闭 scale | `danbooru_post_card_test.dart`（D1） | 实现已审计；专项证据部分；Reduce Motion 无该卡专用断言 |
| ProgressiveGalleryImage | 卡片/详情媒体 | `widgets/online_gallery/progressive_gallery_image.dart` | sample/full、等待、取消/恢复、错误/retry、cache frame | Reduce Motion 立即提升 sample；fade 最长 160ms | `progressive_gallery_image_test.dart`（D1） | 实现已审计；有直接状态与 Reduce Motion 证据 |
| 多选编辑态/批量工具栏 | Toolbar 多选 | `online_gallery_screen.dart` + selection provider + `online_gallery_selection_actions.dart` | 选择、批量收藏、下载、加入 Queue、退出 | compact/desktop 共用命令；加入 Queue 仅是此处的批量动作，Queue 管理 UI 不在本文审计范围 | `online_gallery_source_auth_test.dart`（D2：生产多选入口、选择后批量收藏/下载/Queue 可达） | 实现已审计；有关键入口与动作启用证据，未执行真实下载 |
| 批量下载 Progress Panel | 多选“下载” | `online_gallery_selection_actions.dart::_downloadPosts` → `_GalleryDownloadProgressPanel` | 不可取消 progress、成功/失败/跳过 | `AdaptivePresenter.showPanel`；side width 480、内容 max width 440，compact bottom sheet / expanded side sheet，短高可滚动 | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Pagination / random exhausted bar | 网格底部 | `screens/online_gallery/online_gallery_pagination.dart` | 普通分页、随机继续/耗尽、加载 | `<400` 紧凑；横向滚动保可达 | `online_gallery_pagination_test.dart`（D1：320/360、3x） | 实现已审计；有直接响应证据 |
| Detail loading Dialog | 点击卡片、详情未预载 | `online_gallery_detail_launcher.dart::_loadGalleryDetailWithProgress` | loading、取消、完成、异常、重复请求 gate | blocking AlertDialog | `gallery_detail_dialog_test.dart` 不直接覆盖 launcher loading（D0） | 实现已审计；专项证据空白 |
| GalleryDetail adaptive Form | 点击卡片 | `online_gallery_detail_launcher.dart` → `GalleryDetailDialog` | 文本-only、单/多媒体、video、favorite loading、actions、错误 | `AdaptivePresenter.showForm` side width 960；320×568、compact 横屏、窄宽/大字 | `gallery_detail_dialog_test.dart`（D1；embedded presenter 组合） | 实现已审计；专项证据部分；launcher 真实入口未直测 |
| Detail ActionRail/overflow Menu | 详情右侧/底部 actions | `gallery_detail_action_rail.dart` | focused action 展开、overflow、disabled original、touch | 窄宽折叠 overflow；Reduce Motion 直接终态 | `gallery_detail_dialog_test.dart`（D1：action rail/窄宽） | 实现已审计；专项证据部分；Reduce Motion 无专测 |
| Detail media viewer Overlay/controls | 详情媒体区 | `gallery_detail_media_viewer.dart`、`video_player_widget.dart` | zoom、前后媒体、loading/failure、video controls | compact/wide；动画遵循 disableAnimations | `gallery_detail_dialog_test.dart`、`video_player_widget_test.dart`（D1） | 实现已审计；专项证据部分；Reduce Motion 无 viewer 专测 |
| Detail info Panel | 详情信息区 | `gallery_detail_info_panel.dart` | prompt/tags/metadata/attribution、长文本、空区块 | wide 并列、narrow 纵向；局部可滚动 | `gallery_detail_overview_card_test.dart`、`gallery_detail_text_section_test.dart`（D1） | 实现已审计；专项证据部分；完整 panel 无专测 |
| Tag Context Menu | 详情 tag 单击/右键 | `widgets/online_gallery/gallery_tag_context_menu.dart` | 搜索 tag、加输出过滤、加黑名单、失败反馈 | 锚点 `showMenu` | `gallery_detail_dialog_test.dart`、`gallery_tag_context_menu_test.dart`（D2） | 实现已审计；有业务动作直接证据 |
| GalleryPromptCopy Dialog | 详情“复制 Prompt” | `widgets/online_gallery/gallery_prompt_copy_dialog.dart` | 字段选择、空选择拒绝、复制 | adaptive form，side width 500；320×568、3x、IME | `gallery_prompt_copy_dialog_test.dart`、`gallery_detail_dialog_test.dart`（D2） | 实现已审计；有入口/响应证据 |

## Tag Library

| UI 单元 | 入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|
| TagLibraryPageScreen | `/tag-library` | `lib/presentation/screens/tag_library_page/tag_library_page_screen.dart` | loading/error/empty/data、搜索、分类、grid/list/grouped、多选 | `<840` 分类 adaptive panel，`>=840` 240px sidebar；网格考虑 text scale | `tag_library_responsive_layout_test.dart`、`tag_library_page_screen_test.dart`（D1） | 实现已审计；有 320/600/840/1180/1600 与状态保持证据；无真实路由 |
| 分类 Sidebar / adaptive Panel | 页面分类按钮 | `tag_library_page_screen.dart::_buildCategorySidebar/_showCategoryPanel` | 层级展开、当前分类、添加、选择后 compact 关闭 | 840 断点；panel 与 sidebar 共用树状态 | `tag_library_page_screen_test.dart`（D2：panel 打开/关闭与 840 往返） | 实现已审计；有生产入口证据 |
| TagLibraryToolbar | 页面顶部 | `widgets/tag_library_page/tag_library_toolbar.dart` | 搜索、分类、添加、导入/导出、视图、排序、多选 | `<900` 或 text scale `>1.5` compact；大字 primary stack | `tag_library_toolbar_test.dart`、`tag_library_responsive_layout_test.dart`（D1） | 实现已审计；有直接响应证据 |
| Sort Menu | Toolbar 排序 | `tag_library_toolbar.dart::MenuAnchor` | 多种排序、当前选择 | root overlay，宽 176、高至 280 | `tag_library_toolbar_test.dart`（D1：打开） | 实现已审计；专项证据部分；边缘/键盘无专测 |
| 多选编辑态/Bulk actions | Toolbar 多选 | `tag_library_page_screen.dart` | 当前页/全部、移动、收藏、复制、删除、退出 | 320/600/840/1180/1600 保持动作 | `tag_library_responsive_layout_test.dart`（D1） | 实现已审计；专项证据部分；各批量业务流程未穷举 |
| EntryCard grid item | grid 模式 | `widgets/entry_card.dart` | thumbnail/no-thumbnail、favorite、selected、hover、drag、actions | 卡高随 1–3x；touch menu；多选禁 drag | `entry_card_test.dart`（D1） | 实现已审计；有选择/预览状态证据；响应宽度部分 |
| EntryCard action Menu | 卡片更多 | `entry_card.dart::PopupMenuButton` | 发送、编辑、复制、收藏、移动、删除 | touch 显式入口 | 无菜单专用直接测试（D0） | 实现已审计；专项证据空白 |
| EntryListItem action Menu | list 模式条目更多 | `widgets/entry_list_item.dart` | 与卡片等价操作、tags、选择 | list 局部宽度；touch menu | 无直接测试（D0） | 实现已审计；专项证据空白；不得由 EntryCard 外推 |
| GroupedEntriesView / CategoryHeader | grouped 模式 | `widgets/grouped_view/**` | 分类 header、分组列表、选择/滚动 | sliver persistent header | 无直接测试（D0） | 实现已审计；专项证据空白 |
| TagLibraryEntryHoverPreview Overlay | 精细指针悬停 | `widgets/tag_library/tag_library_entry_hover_preview.dart` | thumbnail/content/tags、dismiss、边缘约束 | pointer-only accelerator | `tag_library_entry_hover_preview_test.dart`（D1） | 实现已审计；有组件证据 |
| CategoryTree empty/node Menus | sidebar/panel 右键或触屏更多 | `widgets/category_tree_view.dart` | 新建、子分类、重命名、移动、删除 | pointer `showMenu`；touch `PopupMenuButton` | `category_tree_view_test.dart` 仅 hover（D1） | 实现已审计；专项证据空白；菜单无直接测试 |
| Add Category Form 编辑态 | 分类添加 | `tag_library_page_screen.dart::_AddCategoryForm` | 输入、重名错误、提交/取消 | `AdaptivePresenter.showForm` side width 440；compact IME/3x | `tag_library_page_screen_test.dart`（D2） | 实现已审计；有生产入口响应证据 |
| Delete Category Confirm | 分类菜单删除 | `tag_library_page_screen.dart::_showDeleteCategoryConfirmation` → `ThemedConfirmDialog` | 分类名、entry count、取消/删除 | `<600` adaptive form；其他宽度为 bounded、scrollable `AlertDialog` | 无 Tag Library 业务专项测试（D0）；共享 `themed_confirm_dialog_test.dart` 为 D1 | 实现已审计；业务链专项证据空白 |
| Delete Entry Confirm | 卡片/列表删除 | `tag_library_page_screen.dart::_showDeleteEntryConfirmationForEntry` → `ThemedConfirmDialog` | 名称、取消/删除 | `<600` adaptive form；其他宽度为 bounded、scrollable `AlertDialog` | 无 Tag Library 业务专项测试（D0）；共享 `themed_confirm_dialog_test.dart` 为 D1 | 实现已审计；业务链专项证据空白 |
| Bulk Delete Confirm | 多选删除 | `tag_library_page_screen.dart::_handleBulkDelete` → `ThemedConfirmDialog` | 数量、危险确认、取消 | shared adaptive dialog | 无 Tag Library 业务专测（D0） | 实现已审计；专项证据空白 |
| BulkMoveCategory Dialog | 多选移动 | `widgets/bulk_move_category_dialog.dart` | 未分类/分类树、当前分类、选择/返回 | Compact fullscreen；Medium/Expanded bounded，IME/SafeArea/3x | `bulk_move_category_dialog_responsive_test.dart`（D2） | 实现已审计；有生产 show 入口证据 |
| EntryAddDialog 新增/编辑态 | 添加或编辑条目 | `widgets/entry_add_dialog.dart` | 新增/编辑、名称/content/category/tags、thumbnail、校验 | Compact fullscreen；Medium bounded dialog；Expanded side form；320 3x/IME/SafeArea | `entry_add_dialog_test.dart`（D2） | 实现已审计；有入口与三形态证据 |
| Thumbnail source BottomSheet | EntryAddDialog 选择缩略图 | `entry_add_dialog.dart::showModalBottomSheet` | 选文件/从当前图裁剪等来源 | bottom sheet | 无直接测试（D0） | 实现已审计；专项证据空白；父 Dialog 测试不外推 sheet |
| ThumbnailCropDialog | EntryAddDialog 裁剪 | `widgets/thumbnail_crop_dialog.dart` | zoom/drag/crop/cancel、竖屏/横屏 | `<600` compact；`<360` 或 text scale `>=2` 紧凑 actions；max width 720 | `thumbnail_crop_dialog_test.dart`（D2） | 实现已审计；有 320/360/800横屏/1200/1600、3x/IME/SafeArea 证据 |
| ImportDialog | Toolbar 导入 | `widgets/import_dialog.dart` | 文件/解析、冲突策略 Menu、预览、进度/错误 | adaptive form，side width 700；320 3x/IME、1180 side | `tag_library_dialog_responsive_test.dart`（D2） | 实现已审计；有入口响应证据；冲突菜单细项部分 |
| ExportDialog | Toolbar 导出 | `widgets/export_dialog.dart` | 非空选择、格式/分类/thumbnail、进度/错误 | adaptive form，side width 600；320 3x/IME、1180 side | `tag_library_dialog_responsive_test.dart`（D2） | 实现已审计；有入口响应证据 |
| SendToHomeDialog | 点击条目/发送 | `widgets/send_to_home_dialog.dart` | 目标类型、alias、解析 preview、结果 | adaptive form，side width 480；`<360` 或 scale `>1.5` 纵向 | `tag_library_dialog_responsive_test.dart`（D2：320/medium/back） | 实现已审计；有入口响应证据 |
| EntrySelectorDialog | 其他功能选择词库条目 | `widgets/entry_selector_dialog.dart` | 搜索、列表、单/多选、确认/取消 | adaptive panel，side width 500；320 3x/IME/SafeArea | `entry_selector_dialog_test.dart`（D2） | 实现已审计；有入口证据 |
| TagLibraryPickerDialog | Prompt/角色/固定词等“从词库选择” | `lib/presentation/widgets/tag_library/tag_library_picker_dialog.dart` | 搜索、分类、列表、选择/取消 | 320 3x/IME/SafeArea fullscreen；其他宽度 bounded shared surface | `tag_library_picker_dialog_test.dart`（D2） | 实现已审计；有生产 show 入口证据；不由 TagLibraryPage 测试外推 |
| FixedTagLibraryPickerDialog | 固定词管理“链接词库” | `lib/presentation/widgets/prompt/fixed_tag_library_picker_dialog.dart` | 搜索、排除已链接、选择/取消 | adaptive picker | `fixed_tags_library_picker_test.dart`（D2） | 实现已审计；有生产入口证据；宽度矩阵不完整 |
| TagLibraryDropMenu | 外部文件/图片 drop | `widgets/tag_library_drop_menu.dart` | 导入/创建/取消动作 | adaptive form，side width 400；320×568 3x/IME/SafeArea fullscreen | `tag_library_drop_menu_test.dart`（D2） | 实现已审计；有生产 show 入口证据 |

## Vibe Library

| UI 单元 | 入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|
| VibeLibraryScreen / Workspace | `/vibe-library` | `lib/presentation/screens/vibe_library/vibe_library_screen.dart`、`vibe_library_workspace.dart` | loading/error/empty/data、搜索、分类、排序、分页、多选、drag/import | `<1000` 分类 panel，`>=1000` 260px persistent；toolbar `contentWidth<1050` 或 scale `>1.5` compact | `vibe_library_responsive_layout_test.dart`（D1） | 实现已审计；有 320/600/840/1180/1600；无真实路由 |
| Category persistent Panel / adaptive Sheet | 分类按钮 | `vibe_library_workspace.dart::_CategoryPanel`、`vibe_library_screen.dart::_showCategoryPanel` | 层级、选择、新建、展开、关闭 | 1000 断点；adaptive panel | `vibe_library_responsive_layout_test.dart` 覆盖 destination，不直接覆盖 category host（D0） | 实现已审计；专项证据空白 |
| Workspace Toolbar | 页面顶部 | `vibe_library_workspace.dart::_Toolbar` | 搜索、计数、导入、分类、排序、刷新、更多、多选 | 局部宽/大字 compact；touch actions 保留 | `vibe_library_responsive_layout_test.dart`（D1） | 实现已审计；有直接布局证据 |
| Toolbar More Menu | Toolbar 更多 | `vibe_library_workspace.dart::PopupMenuButton<_ToolbarMenuAction>` | 导出、打开文件夹（capability） | capability 条件项 | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Sort Menu | Toolbar 排序 | `vibe_library_workspace.dart::_SortButton` | 排序选项/当前项 | popup menu | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Vibe Import Menu | 导入按钮 | `vibe_library_workspace.dart` → `widgets/menus/vibe_import_menu.dart::showImportMenu` | Vibe 文件、图片、剪贴板 | touch-first 主点击打开 `AdaptivePresenter.showPanel` action panel，48px rows；精细指针主点击直接导入文件、右键打开锚定 `PopupRoute` | `vibe_library_responsive_layout_test.dart`（D1：320 touch 主点击、adaptive bottom sheet 三入口、pointer 主/右键分流） | 实现已审计；有触屏等价入口与交互策略专项证据 |
| Empty/Error/Loading 内容态 | Workspace body | `vibe_library_empty_view.dart`、`vibe_library_content_view.dart` | empty 主导入、provider error/retry、loading | 跟随 workspace 局部约束 | `vibe_library_empty_view_test.dart`、provider tests（D1） | 实现已审计；专项证据部分；error UI 无直接 widget 测试 |
| Vibe grid/content | data body | `vibe_library_content_view.dart` | virtualization、选择、详情、context menu、bundle、分页 | 网格列数考虑 text scale；cache extent bounded | `vibe_library_content_view_test.dart`、`vibe_library_responsive_layout_test.dart`（D1） | 实现已审计；有布局/业务 helper 证据 |
| VibeCard | 网格条目 | `widgets/vibe_card.dart` | image/bundle、favorite、selected、metadata、drag、hover/touch actions | touch 显式 menu；pointer hover preview | `vibe_card_hover_test.dart`、`vibe_library_context_menu_flash_test.dart`（D1） | 实现已审计；专项证据部分；完整 card actions 未直测 |
| VibeCard touch Menu | 卡片更多 | `vibe_card.dart::_buildTouchActionMenu` | 发送、详情、收藏、编辑/导出/删除等 | touch alternative | 无专用直接测试（D0） | 实现已审计；专项证据空白 |
| Vibe context PopupRoute | 右键卡片 | `vibe_library_content_view.dart::_ContextMenuRoute` | 详情、发送、收藏、导出、删除等 | pointer route，边缘定位 | `vibe_library_context_menu_flash_test.dart`（D1：抬起后打开/不闪图） | 实现已审计；专项证据部分；动作列表未穷举 |
| Vibe hover Preview Overlay | 悬停卡片 | `vibe_card.dart::_VibeHoverPreview` | 高清图、参数、bundle badges、边缘约束 | pointer-only；高度有上限 | `vibe_card_hover_test.dart`（D1） | 实现已审计；有组件证据；无 Reduce Motion 专测 |
| Drop Overlay | 文件拖入 workspace | `vibe_library_workspace.dart::_DropOverlay` | dragging 提示、离开/放下 | controller `isDragging` | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Import Progress Overlay | 图片/bundle 导入 | `vibe_library_workspace.dart::_ImportOverlay` | progress、阻止重复操作、完成/失败 | controller `importProgress != null`；SafeArea、16px 最小边距、320 上限、短高/大字可滚动 | `vibe_library_responsive_layout_test.dart`（D2：touch-first 图片导入、320px SafeArea 与 progress overlay） | 实现已审计；有生产入口组合证据 |
| Pagination Bar 编辑态 | data body 底部 | `vibe_library_workspace.dart::_PaginationBar` | page/page size、前后页、selection 保持 | page-size dropdown；局部宽 | 页面 responsive test（D1） | 实现已审计；专项证据部分；分页菜单/边界无专测 |
| Category node/empty Menus | 分类树右键/触屏更多 | `widgets/category/vibe_category_item.dart`、`vibe_category_tree_view.dart` | 新建、重命名、移动、删除 | pointer `showMenu` + touch popup | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Category CRUD Dialogs | 分类菜单 | `vibe_library_screen.dart` → `ThemedInputDialog/ThemedConfirmDialog` | 新建/重命名/删除 | shared adaptive dialog | 无 Vibe 业务直接测试（D0） | 实现已审计；专项证据空白 |
| CategoryDestination Panel | 多选移动 | `vibe_library_screen.dart::VibeCategoryDestinationPanel` | 分类列表、选择/取消 | adaptive form，side width 440；320 3x/IME/SafeArea、wide bounded | `vibe_library_responsive_layout_test.dart`（D2） | 实现已审计；有生产 show 入口证据 |
| 多选编辑态/Bulk actions | Toolbar 多选 | `vibe_library_screen.dart` | 当前页选择、发送、移动、导出、收藏、encoding model、删除 | compact actions 可达 | `vibe_library_responsive_layout_test.dart`、`vibe_library_encoding_model_bulk_test.dart`（D1） | 实现已审计；专项证据部分；删除/导出完整链未直测 |
| Limit/批量删除 Confirm Dialog | 超过 Vibe 限制或删除 | `vibe_library_screen.dart::_showVibeLimitDialog` / `ThemedConfirmDialog` | 限制说明、确认/取消 | `<600` adaptive form；其他宽度为 bounded、scrollable `AlertDialog` | 无 Vibe 业务专项测试（D0）；共享 `themed_confirm_dialog_test.dart` 覆盖 320、3x、IME/SafeArea（D1） | 实现已审计；业务链专项证据空白 |
| VibeImportNamingDialog | 单文件导入 | `widgets/vibe_import_naming_dialog.dart` | 名称/category/结果/取消 | adaptive form，side width 400；内容 `<380` compact | `vibe_import_naming_dialog_test.dart`（D2） | 实现已审计；有入口/结果证据 |
| VibeBundleImportDialog | bundle 导入 | `widgets/vibe_bundle_import_dialog.dart` | bundle items、参数策略、命名/category、结果 | adaptive form，side width 500；`<380` compact；极窄/大字 stack | `vibe_bundle_import_dialog_test.dart`（D2） | 实现已审计；有入口/本地化/响应证据 |
| VibeImageEncodeDialog | 图片导入编码配置 | `widgets/vibe_image_encode_dialog.dart::VibeImageEncodeDialog` | 模型、strength/info、V3 raw local save、取消 | adaptive form，side width 400；320/600/840/1180/1600、3x/IME/SafeArea | `vibe_image_encode_dialog_test.dart`（D2） | 实现已审计；有入口响应证据 |
| Encoding Progress Dialog | 编码进行中 | `vibe_image_encode_dialog.dart::VibeImageEncodingDialog` | blocking progress | `showDialog` | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Encode Error Dialog | 编码失败 | `vibe_image_encode_dialog.dart::VibeImageEncodeErrorDialog` | retry/skip 等 action | `AdaptivePresenter.showForm`，side width 440；错误文本可滚动，actions 用 `Wrap` | 无直接测试（D0） | 实现已审计；专项证据空白 |
| VibeDetailViewer adaptive Form | 点击详情 | `widgets/vibe_detail_viewer.dart` | single/bundle、解析 loading、preview/params tabs、save/close、无原图 | side width 960；布局由局部 `WindowSizeClass`；横向条件 `w>1.15h`；短高/大字 tabs | `vibe_detail_viewer_test.dart`（D2） | 实现已审计；有 320 3x/IME/SafeArea、mixed input、wide 证据 |
| Vibe Rename Form 编辑态 | Detail rename | `vibe_detail_viewer.dart::_VibeRenameForm` | 名称编辑、保存/取消 | adaptive form，side width 440 | `vibe_detail_viewer_test.dart` 320 用例（D1） | 实现已审计；专项证据部分 |
| Detail Param Panel action Menu | Detail 参数区更多 | `vibe_detail_param_panel.dart::PopupMenuButton` | 收藏、导出、删除等；slider 参数 | `<420` actions 重排 | `vibe_detail_viewer_test.dart` 仅整体（D0） | 实现已审计；专项证据空白；父详情测试不外推 menu |
| Detail preview Drop Overlay | Detail 替换预览拖放 | `vibe_preview_drop_zone.dart` | dragging、replace、失败 | pointer drag；overlay | 无直接测试（D0） | 实现已审计；专项证据空白 |
| VibeSelectorDialog | 生成页/其他入口选择 Vibe | `widgets/vibe_selector_dialog.dart` | 搜索、source filter Menu、sort Menu、单/替换选择、短高、IME | adaptive form，side width 900；`<600` toolbar stack；列数按 340/500/680；320/360 | `vibe_selector_dialog_test.dart`（D2） | 实现已审计；有广泛直接证据 |
| VibeExportDialog | 卡片/批量普通导出 | `widgets/vibe_export_dialog.dart` | 格式、范围、carrier/options、进度/错误 | adaptive form，side width 650；`<640` compact，`<360` stack | 无该普通 Dialog 专用测试（D0） | 实现已审计；专项证据空白 |
| VibeExportDialogAdvanced | 高级导出入口 | `widgets/vibe_export_dialog_advanced.dart` | 单项/批量、PNG carrier、校验/进度/错误 | adaptive form，side width 520；320 3x/IME/SafeArea 与多宽度 | `vibe_export_dialog_advanced_test.dart`（D2） | 实现已审计；有直接入口/模式证据 |

## Precise Ref Library

| UI 单元 | 入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|
| PreciseRefLibraryScreen | `/precise-ref-library` | `lib/presentation/screens/precise_ref_library/precise_ref_library_screen.dart` | loading/error/empty/data、搜索/type filter、sort、多选、drop | 网格列数考虑 1–3x；320/600/840/1180/1600 | `precise_ref_library_screen_test.dart`、`precise_ref_responsive_layout_test.dart`（D1） | 实现已审计；有直接状态/宽度证据；无真实路由 |
| Toolbar/type filter 编辑态 | Screen 顶部 | `precise_ref_library_screen.dart`、`precise_ref_type_filter_chips.dart` | 搜索、类型、sort、selection、import | `>=760` 保留横排；`<400` 或 scaled 14 `>18` compact | `precise_ref_responsive_layout_test.dart`（D1） | 实现已审计；有直接布局证据 |
| Sort Menu | Toolbar 排序 | `precise_ref_library_screen.dart::PopupMenuButton` | 名称/日期/收藏等 | popup menu | 无直接测试（D0） | 实现已审计；专项证据空白 |
| Empty/Error states | Screen body | `precise_ref_library_screen.dart` | 空库仅中央导入、错误+重试、快捷保存失败 | Single screen responsive body | `precise_ref_library_screen_test.dart`（D1） | 实现已审计；有直接状态证据 |
| Drop Overlay | 拖入图片 | `precise_ref_library_screen.dart::_buildDropOverlay` | dragging、导入、离开 | controller `_isDragging` | 无直接测试（D0） | 实现已审计；专项证据空白 |
| PreciseRefCard | 网格条目 | `widgets/precise_ref_card.dart` | 名称/参数/type、收藏、发送、编辑、删除、hover/touch | Android touch menu；Windows mouse hover actions | `precise_ref_card_test.dart`（D1） | 实现已审计；有跨输入直接证据 |
| PreciseRefCard Menu/context | 卡片更多/右键 | `precise_ref_card.dart::PopupMenuButton` + Screen secondary tap | 发送、收藏、编辑、删除 | touch popup；pointer context；避免 modality flip | `precise_ref_card_test.dart`、`precise_ref_context_menu_flash_test.dart`（D1） | 实现已审计；有入口动作证据；边缘定位未测 |
| PreciseRefSelectorDialog | 生成页/其他选择入口 | `widgets/precise_ref_selector_dialog.dart` | 搜索/type filter、选择/确认、空态 | adaptive panel，side width 720；列数 `<340/500/680`；320 3x/IME | `precise_ref_responsive_layout_test.dart`（D2） | 实现已审计；有生产 show 入口证据 |
| PreciseRefEntryEditDialog 编辑态 | 卡片编辑 | `widgets/precise_ref_entry_edit_dialog.dart` | 名称/type/strength/fidelity、保存/取消 | adaptive form，side width 440；`<360` 或 scale `>1.5` stack | `precise_ref_responsive_layout_test.dart`（D2） | 实现已审计；有入口响应证据 |
| Delete Confirm Dialog | 卡片删除 | `precise_ref_library_screen.dart::showDialog<bool>` | 名称、取消/删除 | AlertDialog | 无直接测试（D0） | 实现已审计；专项证据空白 |

## Statistics

| UI 单元 | 入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|
| StatisticsScreen | `/statistics` | `lib/presentation/screens/statistics/statistics_screen.dart` | initial loading、error/retry、empty、data、stale data refresh | dashboard effective width=`availableWidth/textScale`：`<600` 1 列、`<900` 2 列、否则 3 列 | `statistics_responsive_layout_test.dart`（D1：列公式、360 3x empty） | 实现已审计；专项证据部分；data/error 多宽度与真实路由未直测 |
| Header/action row | Screen 顶部 | `statistics_screen.dart::_buildHeader` | title、export disabled/enabled、refresh/loading | `<520` 或 text scale `>1.5` 纵向；touch+非 compact 显示文字 export，否则 icon | `statistics_responsive_layout_test.dart` 仅 empty page（D0） | 实现已审计；专项证据空白；header 分支无直接断言 |
| OverviewStatsRow / MetricCard hover | data 第一行 | `statistics/widgets/dashboard/overview_stats_row.dart`、`cards/metric_card.dart` | 总图数/收藏/磁盘等、trend/sparkline、hover | `StatsGrid` 依局部宽重排；Reduce Motion 禁 hover motion | `statistics_widget_responsive_test.dart`（D1：grid local width） | 实现已审计；专项证据部分；MetricCard Reduce Motion 无专测 |
| OtherStatsCard | dashboard | `dashboard/other_stats_card.dart` | 其他统计值、空值 | `ChartCard` local width | 无专用直接测试（D0） | 实现已审计；专项证据空白 |
| AnlasCostCard | dashboard | `dashboard/anlas_cost_card.dart` | loading/error/data、总额/日均、period、自定义天数 | card local width；period popup；custom form adaptive side width 420 | `anlas_cost_card_test.dart`（D1：period/汇总/custom days） | 实现已审计；有业务组件证据；窄宽/IME 未直测 |
| Anlas period Menu | AnlasCostCard period 按钮 | `anlas_cost_card.dart::PopupMenuButton<AnlasStatisticsPeriod>` | 各 period、checked 当前项、自定义 | popup menu | `anlas_cost_card_test.dart`（D1：选择） | 实现已审计；有直接交互证据；边缘/大字未测 |
| CustomDays adaptive Form | period 选择 custom | `anlas_cost_card.dart::_CustomDaysForm` | 天数输入、校验、应用/取消 | `AdaptivePresenter.showForm` side width 420 | `anlas_cost_card_test.dart`（D1） | 实现已审计；专项证据部分；生产 presenter 形态/IME 未专测 |
| SamplerDistributionCard | dashboard | `dashboard/sampler_distribution_card.dart` → `ParameterDistributionBar` | empty/data、全部 sampler 保留 | chart 依局部宽，自适应 bar label | `statistics_widget_responsive_test.dart` 只测通用局部容器（D0） | 实现已审计；专项证据空白；不得由通用容器外推该图表 |
| AspectRatioCard | dashboard | `dashboard/aspect_ratio_card.dart` → `AspectRatioChart` | empty/data、前 8 比例、legend/preview | chart local width；窄宽/大字时 legend 下置；Reduce Motion 关闭内部过渡 | `statistics_widget_responsive_test.dart`（D1：360、280 局部宽、3x legend） | 实现已审计；有图表直接响应证据，Reduce Motion 专项证据空白 |
| ActivityHeatmapCard | dashboard | `dashboard/activity_heatmap_card.dart` → `HeatmapChart` | empty/data、日期 hover/tap | chart local width；touch cell 至少 48px；Reduce Motion 直接终态并关闭 hover 过渡 | `statistics_widget_responsive_test.dart`（D1：360、280 局部宽、touch 48px） | 实现已审计；有触屏目标直接证据，Reduce Motion 专项证据空白 |
| HourlyDistributionCard | dashboard | `dashboard/hourly_distribution_card.dart` → `PolarActivityChart` | empty/data、peak info | `<` 局部窄宽上下，桌面横排 | `hourly_distribution_card_test.dart`（D1：390 纵向、760 横向） | 实现已审计；有直接响应证据 |
| WeekdayDistributionCard | dashboard | `dashboard/weekday_distribution_card.dart` → `WeekdayBarChart` | empty/data、weekday summary/hover | chart local width | 无专用直接测试（D0） | 实现已审计；专项证据空白 |
| AnimatedRefreshButton | Header | `dashboard/animated_refresh_button.dart` | idle/loading、点击 refresh | 显式读取 `MediaQuery.disableAnimationsOf`；Reduce Motion 下不启动/停止旋转，hover 容器与文字 duration 为 zero | 无直接测试（D0） | 实现已审计；Reduce Motion 专项证据空白 |
| StatisticsExportDialog | Header export | `lib/presentation/widgets/statistics/export_dialog.dart` | JSON/CSV、范围、pending、error、close | 320–1600、3x；短高/IME/SafeArea；Reduce Motion 测试环境 | `export_dialog_responsive_test.dart`（D2） | 实现已审计；有生产 show 入口与状态证据 |

## 横向证据结论

- 本次源码逐项核对未发现真实实现缺口；D0 与未穷举状态只表示专项证据空白，不改变“实现已审计”。
- 现存专项证据最强的是共享 adaptive form/panel 的主要资源 Dialog、在线顶栏、在线 masonry grid、三个资源库主布局；较少的是卡片/树节点 Menu、drag/import Overlay、业务确认链、在线批量下载 progress 和统计独立图表。
- `GalleryScanProgressPanel` 必须视为两个独立宿主组合：`LocalGalleryCategoryPanel` 与 `GalleryCategoryTreeView(showScanProgress: true)`；当前仅条纹 helper/Reduce Motion 有直接测试，不能把该证据外推为任一宿主的完整响应布局专项证据。
- Reduce Motion 实现已覆盖本审计涉及的扫描条纹、在线渐进图片、相关 hover/详情 motion，以及统计的 refresh、卡片、数字和图表动画；直接专项测试仅确认扫描条纹、`ProgressiveGalleryImage` 与统计 `AnimatedNumber`，其余均为源码审计结论。
- Vibe touch-first 导入通过 adaptive action panel 提供文件、图片、剪贴板三入口；在线批量下载使用 adaptive progress panel。Queue 管理页不在本文范围，本文只记录在线批量“加入 Queue”命令。
- 本文未把 provider/service 单测当作 UI surface 证据；它们只能补充业务状态来源，不能证明 Dialog/Sheet/Panel/Menu/Overlay 在真实 constraints 下可达。
