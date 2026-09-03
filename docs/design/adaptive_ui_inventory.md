# 自适应 UI 清单与证据索引

> 最后复核：2026-09-02。本文只定义覆盖边界、领域索引和验证口径；逐项 UI 单元见四份领域台账。实现策略见 [`adaptive_ui_strategy.md`](adaptive_ui_strategy.md)。

## 1. 覆盖契约

- 统一宽度级别：Compact `<600`、Medium `600–839`、Expanded `840–1179`、Wide `>=1180`。
- 页面级分类来自 `WindowSizeClass`；局部重排依据 `LayoutBuilder` constraints，不依据平台名、设备型号或横竖屏标签。
- 触屏、精细指针和键盘由 `InteractionPolicyScope` 决定；混合输入设备同时保留触屏等价入口与键鼠效率入口。
- 复杂长表单统一走 `AdaptivePresenter.showForm`：Compact 全屏，Medium 居中有界，Expanded/Wide 侧栏；短确认、短通知和单选器可以使用有界 Dialog。
- 业务组件、Provider、路由状态和命令跨端共享；断点切换保持输入、选择、焦点、滚动和未提交状态。
- Compact 最坏组合基准为 320px 宽、3x 文本、SafeArea 与 IME 同时存在；触屏核心命中区至少 48×48。
- Reduce Motion 必须停止装饰性无限动画并直接呈现稳定终态。

## 2. 逐项 UI 单元台账

以下台账按稳定业务边界拆分，不按文件数量机械切片。每个 Screen、Dialog、Sheet、Panel、Menu、Overlay 或独立编辑态单列真实入口、实现路径、关键状态、响应条件和直接证据：

| 领域 | 台账 | 单元数/范围 | 用途 |
|---|---|---|---|
| 生成、Prompt、角色与图片编辑 | [`adaptive_ui_surfaces_generation.md`](adaptive_ui_surfaces_generation.md) | Generation、Prompt Config、Director、Prompt Assistant、角色、Image Editor | 生成工作台及其全部可达子表面 |
| 画廊、资源库与统计 | [`adaptive_ui_surfaces_gallery_resources.md`](adaptive_ui_surfaces_gallery_resources.md) | Local/Online Gallery、Tag/Vibe/Precise Ref Library、Statistics | 内容浏览、资源管理、扫描与统计 |
| 设置、同步与工具 | [`adaptive_ui_surfaces_settings_tools.md`](adaptive_ui_surfaces_settings_tools.md) | Settings、Cloud Sync、Auth、Watermark、Model3D、Shortcuts、Metadata、Discord、Queue | 配置、同步、编辑器与任务管理 |
| Shell、全局反馈、Agent 与共享组件 | [`adaptive_ui_surfaces_shell_shared.md`](adaptive_ui_surfaces_shell_shared.md) | App/Router/Splash、导航壳层、Banner/Toast/Drop、Agent Chat、Common Widgets | 全局容器、反馈与复用表面 |

台账中的证据等级只表示自动化证据强度：父级测试不得外推为子单元直接证据；“缺直接证据”也不等价于实现不可用。最终真实视觉与完整业务流程仍由 Windows/Android 运行验收确认。

## 3. 共享基础

| 能力 | 实现 | 代表性测试 |
|---|---|---|
| 可用子屏与窗口分类 | `lib/presentation/adaptive/window_size_class.dart` | `test/presentation/adaptive/window_size_class_test.dart` |
| 插槽布局与内容限宽 | `lib/presentation/adaptive/adaptive_layout.dart` | `test/presentation/adaptive/adaptive_layout_test.dart` |
| 动态输入能力 | `lib/presentation/adaptive/interaction_policy.dart` | `test/presentation/adaptive/interaction_policy_test.dart` |
| Panel/Form 呈现 | `lib/presentation/adaptive/adaptive_presenter.dart` | `test/presentation/adaptive/adaptive_presenter_test.dart` |
| 通用 Dialog 视口 | `lib/presentation/widgets/common/adaptive_dialog_frame.dart` | `test/presentation/widgets/common/adaptive_dialog_frame_test.dart` |
| 主题、对比度与 Motion | `lib/presentation/themes/**` | `test/tool/theme_color_contrast_test.dart` |
| 架构边界 | presentation 不从 OS 推导输入模式；长表单不绕过共享 Presenter | `test/presentation/adaptive/responsive_ui_contract_test.dart` |

## 4. 本轮明确回归单元

| UI 单元 | 生产入口 | 直接证据 |
|---|---|---|
| `AddTagGroupDialog` | Prompt Config → Category → 添加标签组 | `add_tag_group_dialog_test.dart`：320/3x/IME/SafeArea、宽屏、名称输入后提交状态 |
| `EntryAddDialog` / `EntrySelectorDialog` | Tag Library 新增/编辑与词库选择 | `entry_add_dialog_test.dart`、`entry_selector_dialog_test.dart` |
| `PostProcessRulePanel` | Prompt Config → Tag Group → DIY → 后处理 | `post_process_rule_panel_test.dart`：320/3x 纵排、宽屏横排、预设回调 |
| `PreviewGeneratorPanel` | Prompt Config → 预览 | `preview_generator_panel_test.dart`：320/3x 标题、统计和操作重排 |
| `GalleryScanProgressPanel` | Local Gallery 分类栏与分类树扫描状态 | `gallery_scan_progress_panel_test.dart`：Reduce Motion、正常动画与边界 |
| Queue Task Edit | Queue → 任务 → 编辑 | `queue_management_page_test.dart`：320/3x/IME/SafeArea、700、1600、返回 |
| Splash | AppBootstrap 预热 | `splash_screen_responsive_test.dart`：320/3x/SafeArea/IME |
| Generation 组合 | `/generation` | `generation_screen_responsive_test.dart`：断点切换、输入策略、320/3x/SafeArea/IME |

## 5. 组合流程边界

已建立自动化证据的组合包括：

- Generation 在 839↔840 切换时复用稳定 Prompt 编辑器 owner，保持文本、正/负模式、selection、focus 与 IME composing；角色位置画布开关不卸载编辑器，Compact/中横屏可直接切换正负 Prompt。
- Queue Task Edit 在 Compact/Medium/Wide 之间保持完整任务快照和取消/系统返回语义。
- Random Mode 的 Selector、Popup、Indicator、Compact Sheet 与 Wide Sheet 使用同一状态命令。
- Gallery Filter、Tag Library 长表单、Cloud Sync 各自有组件或入口级响应证据。

未执行 Windows/Android 自动化运行验收，因此不把 widget test 声称为真机视觉证明；用户将进行真实双端验收。没有触发任何 Anlas 消耗操作。

## 6. 验证记录

主任务实现与收敛阶段执行过以下检查；四份逐项台账的编写子任务只审计现有代码和测试文件，没有把编写时未重跑的测试冒充新证据：

- `flutter analyze --no-pub`（最新整合结果通过）
- `git diff --check`（最新整合结果通过）
- 项目受控全量测试 `scripts/run_flutter_tests.ps1`，以及每轮根因修复后的对应定向回归
- 路由、Director Tools、随机模式、Splash、Generation、Tag Library、Prompt DIY、Gallery Scan 等专项 widget tests

测试通过只证明对应断言，不替代四份逐项台账，也不替代真实运行验收。

## 7. 维护规则

- 新增或删除可达 UI 单元时，同步更新对应领域台账；不得只修改本索引。
- 一行只对应一个可独立呈现或编辑的 UI 单元；父级证据不得自动升级子单元状态。
- 新增复杂长表单、输入能力分支、动画或固定尺寸前，先复用共享 Presenter、InteractionPolicy、WindowSizeClass 与 Motion 契约。
- 文档状态只陈述可核验事实，不使用“界面族已覆盖”替代逐项实现与测试证据。
