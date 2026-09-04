# 生成、Prompt、角色与图像编辑自适应 UI 面审计

> 范围：`lib/presentation/screens/{generation,prompt_config,director_tools}`、`lib/presentation/prompt_assistant`，以及 `lib/presentation/widgets/{prompt,character,generation,image_editor}`。仓库不存在 `lib/presentation/screens/prompt_assistant`；其真实实现位于 `lib/presentation/prompt_assistant/widgets`。本表只逐项记录由这些目录拥有且从生产代码可达的 UI 面；跳往范围外公共 Dialog/Screen 的入口会注明，但不递归盘点范围外实现。

## 口径

- 每行是一个可独立出现、切换或编辑的 Screen、Dialog、Sheet、Panel、Menu、Overlay 或编辑态；不把普通按钮、卡片、绘制器、Tooltip、Toast、纯状态类拆成 UI 面。
- 响应代码：`R-G`＝Generation 局部宽度 `<840` 用移动组合，`>=840` 用 classic/web；移动工作区在宽度 `>=640×textScale`、高度 `>=320` 且宽高比 `>1.15` 时横排。`R-P`＝`AdaptivePresenter` 按 safe usable pane 宽度呈现：`showForm` 在 Compact `<600` 全屏、Medium `600–839` 居中有界、Expanded/Wide `>=840` 侧栏，`showPanel` 在 `<840` 使用避开 SafeArea/IME 的 bottom sheet、`>=840` 使用合同限宽侧栏；两者关闭后恢复触发焦点，并在 `MediaQuery.disableAnimations` 下取消入场和 inset 动画。`R-I`＝图像编辑器仅在宽度 `>=840`、高度 `>=480` 且 14px 文本缩放后 `<=20px` 时桌面布局，否则移动布局。`R-M`＝锚定 Popup/Overlay，依局部约束或 `InteractionPolicy` 收边，不自动等价为移动 Sheet。
- 实现状态与测试证据分开记录：`实现已审计` 表示当前生产入口与响应策略已按源码复核；只有发现真实实现偏差时才标为实现缺口。没有专项测试或完整状态矩阵未直测，只限制证据强度，不降低实现状态。
- 证据说明：`D`＝测试直接构建该单元或调用该单元生产 `show` 入口；`P`＝只有父级/组合测试看到它，**不是该子单元直接证据**；`S`＝仅源码可达性与静态条件。测试路径均相对 `test/presentation/`；本次只审计现有代码与证据文件，未新增或执行测试。

## Generation 与 Director Tools

| ID | UI 单元 | 真实入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|---|
| GEN-001 | GenerationScreen 路由页 | `/generation`、`/generation/:sessionId` | `screens/generation/generation_screen.dart` | classic/web、固定词开关、文件拖放能力 | R-G；固定词在 `<900` 为遮罩侧浮层，`>=900` 为并排栏 | D `screens/generation/generation_screen_responsive_test.dart` | 实现已审计；未覆盖全部业务面组合 |
| GEN-002 | Classic 三栏工作台 | GenerationScreen，`layoutMode!=webStyle` | `screens/generation/desktop_layout.dart` | 左/右/固定词栏展开、拖宽、快捷键、生成中 | `>=840`；左右栏 40px 折叠并按合同限宽 | P `generation_screen_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-003 | Web-style 工作台 | GenerationScreen，`layoutMode==webStyle` | `screens/generation/web_style_layout.dart` | 左栏、参数抽屉、固定词覆盖、右栏 | `>=840`；主区不足时固定词改覆盖层 | P `generation_screen_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-004 | 移动生成壳层 | GenerationScreen 在 Compact/Medium | `screens/generation/mobile_layout.dart`、`mobile_generation_shell.dart` | 普通、Prompt 最大化、Agent 全屏、系统返回 | R-G | P `generation_screen_responsive_test.dart` | 实现已审计；壳层独立状态矩阵未直测 |
| GEN-005 | 移动生成主工作区 | 移动壳层默认面 | `screens/generation/mobile_generation_workspace.dart` | 空/结果/生成进度、竖排概览、横屏双区 | R-G 中的移动横排条件 | P `generation_screen_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-006 | 移动 Prompt 最大化编辑态 | 点击 Prompt 概览；返回先退出最大化 | `mobile_generation_workspace.dart`、`widgets/prompt_input.dart` | 输入、IME、焦点、正负 Prompt、工具条 | 移动全区；SafeArea/IME | D `screens/generation/widgets/prompt_input_test.dart`、`prompt_input_compact_test.dart` | 实现已审计；有直接证据 |
| GEN-007 | 移动 Agent 全屏面 | 移动顶栏 Agent；返回/下滑关闭 | `mobile_generation_shell.dart` | 未打开/已打开、全屏、设置入口 | 移动全区、动效禁用策略 | P `agent_chat/widgets/agent_chat_mobile_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-008 | Classic 参数左栏 | Classic 左栏/折叠条 | `widgets/left_panel.dart`、`parameter_panel.dart` | 展开、折叠、拖宽、各参数段 | `250–450px`，拖拽时禁动画 | D `screens/generation/widgets/parameter_panel_test.dart` | 实现已审计；Panel 有直接证据，壳层拖宽状态矩阵未直测 |
| GEN-009 | Web 参数二级菜单 Overlay | Web 左栏底部“参数”触发条 | `widgets/web_left_panel.dart` | 持久化展开、遮罩关闭、动画挂载 | 左栏真实宽度 `<319` 只显示折叠入口；展开菜单限高 | D `screens/generation/widgets/web_left_panel_test.dart` | 实现已审计；菜单业务项状态覆盖有限 |
| GEN-010 | 生成右侧 Chat Panel | 右侧折叠态 Chat 入口 | `widgets/right_panel.dart` | Chat/历史持久化页、展开/折叠 | 40px 折叠；展开宽度遵循 side-panel 合同 | D `screens/generation/widgets/right_panel_test.dart` | 实现已审计；有直接入口证据 |
| GEN-011 | 生成右侧 History Panel | 右侧折叠态 History 入口 | `widgets/right_panel.dart`、`history_panel.dart` | 空/生成占位/完成、选择、批量、滚动恢复 | 同 GEN-010；内部按行高/可用宽度重排 | D `history_panel_test.dart`、`history_panel_interaction_test.dart` | 实现已审计；有直接证据 |
| GEN-012 | 固定词 Sidebar | classic/web 固定栏；移动固定词按钮 | `widgets/fixed_tags_sidebar.dart`、`fixed_tags_sidebar_slot.dart` | 正/负、列表/网格、搜索、链接、拖放、空态 | `<900` 右侧 Modal overlay，`>=900`/桌面可持久并排 | D `screens/generation/widgets/fixed_tags_sidebar_test.dart` | 实现已审计；有直接证据 |
| GEN-013 | Sidebar 新增 Menu | Sidebar 顶部“+” | `widgets/fixed_tags_sidebar.dart` | 新建、从词库添加、正/负目标 | R-M | P `fixed_tags_sidebar_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-014 | Sidebar 条目操作 Menu | 触屏/更多按钮 | `widgets/sidebar_entry_tile.dart` | 复制、编辑、删除；hover 快捷操作等价 | 精细指针 hover；触屏 PopupMenu | D `fixed_tags_sidebar_test.dart` | 实现已审计；有直接证据 |
| GEN-015 | MainWorkspace Prompt/预览/控制组合 | Classic 中栏 | `widgets/main_workspace.dart` | Prompt 最大化、位置画布、短高滚动、预览、控制条 | 高度 `<560` 或大字时整体可滚动；Prompt 高度有预览预算 | D `screens/generation/widgets/main_workspace_test.dart` | 实现已审计；有直接证据 |
| GEN-016 | Prompt 搜索/替换编辑态 | Prompt 工具栏或 Ctrl/Cmd+F/H | `widgets/prompt_input_toolbar.dart`、`widgets/prompt/unified/unified_prompt_input.dart` | 搜索、当前/全部替换、关闭、选区保持 | 工具栏按局部宽度收纳；IME 可滚动 | D `screens/generation/widgets/prompt_input_test.dart` | 实现已审计；有直接证据 |
| GEN-017 | Prompt Assistant inline/root Overlay | Prompt footer 助手按钮 | `lib/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart` | 折叠/展开、处理、错误、撤销/重做、取消 | inline 或 root `OverlayEntry`；宽度不超过窗口减 16；Reduce Motion 立即切换 | P `prompt_input_test.dart` | 实现已审计；Overlay 独立状态矩阵未直测 |
| GEN-018 | Prompt Assistant 操作 Menu/Sheet | 助手更多按钮/长按位置 | `lib/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart` | 历史、撤销/重做、翻译、优化、自定义、角色替换、设置、取消 | 精细指针用锚定 `showMenu`，触屏用 R-P Panel；桌面菜单与触屏 Panel 能力等价，触屏将三个设置捷径合并为可达完整设置的助手设置入口 | S | 实现已审计；专项测试空白 |
| GEN-019 | Prompt Assistant 历史 Panel | Assistant Menu→历史 | `lib/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart` | 空、历史倒序、点击恢复 | R-P Panel | S | 实现已审计；专项测试空白 |
| GEN-020 | Prompt Assistant 自定义任务 Form | 助手“自定义” | `lib/presentation/prompt_assistant/widgets/prompt_assistant_custom_dialog.dart` | 用户要求、可选图片、模型禁图、IME、提交/取消 | R-P Form：Compact 全屏、Medium 居中、Expanded/Wide 侧栏 | D `prompt_assistant/widgets/prompt_assistant_custom_dialog_responsive_test.dart` | 实现已审计；有直接证据 |
| GEN-021 | Prompt Assistant 快速设置 Panel | Prompt 工具栏助手设置 | `widgets/prompt_input_coordinator.dart` | 总开关、桌面 Overlay 开关 | R-P Panel；侧栏偏好宽 440 | S | 实现已审计；专项测试空白 |
| GEN-022 | Prompt 输入工具栏溢出/移动工具面 | PromptInput 窄宽或移动最大化 | `widgets/prompt_input_toolbar.dart`、`widgets/prompt/toolbar/prompt_editor_toolbar.dart` | 固定词、随机、角色、正则、助手等动作 | 局部宽度切到滚动/移动工具条，不隐藏能力；紧凑按钮按 InteractionPolicy 保持 48px 触屏命中区 | D `prompt_input_test.dart`、`prompt_input_compact_test.dart` | 实现已审计；有直接证据 |
| GEN-023 | 批量生成设置 Form | 生成控制条批量按钮 | `widgets/generation_controls/batch_settings_button.dart` | batch size/count、边界、IME | R-P Form | D `screens/generation/widgets/generation_controls/generation_controls_test.dart` | 实现已审计；有直接证据 |
| GEN-024 | 预览主面 | 中央预览区 | `widgets/image_preview.dart` | 空、生成中、流式、错误、单/多图、已选详情 | 局部约束；键盘快捷键仅预览有焦点时 | D `image_preview_selection_test.dart`、`image_preview_shortcuts_test.dart` | 实现已审计；有直接证据 |
| GEN-025 | 图像对比编辑态 | 兼容结果的信息条对比开关 | `widgets/image_comparison_view.dart` | 分隔拖动/键盘、缩放、重置 | 共享缩放；各断点保持布局 | D `image_comparison_view_test.dart` | 实现已审计；有直接证据 |
| GEN-026 | 透明背景选择 Overlay | 预览信息条棋盘格按钮 | `widgets/preview_info_bar.dart` | 跟随图像/黑白/自定义色，外点关闭 | R-M，锚定并收边 | D `screens/generation/preview_info_bar_test.dart` | 实现已审计；有直接证据 |
| GEN-027 | Img2Img 折叠 Panel | 参数区/官网左栏 Img2Img | `widgets/img2img_panel.dart` | 空源图、重绘、增强、超分、任务运行/错/完成 | 折叠面板随父宽；内部条件切换 | D `screens/generation/widgets/img2img_panel_test.dart` | 实现已审计；有直接证据 |
| GEN-028 | Img2Img 源图操作区 | Img2Img 展开→添加/编辑/工作流/Director | `widgets/img2img_source_section.dart` | 文件/剪贴板/拖入、蒙版、裁剪、清除 | 按局部宽度 Wrap；触屏保留入口 | P `img2img_panel_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-029 | Img2Img 调整子 Panel | 有源图且非超分 | `widgets/img2img_adjustment_section.dart` | 重绘强度/噪声、增强参数、模式条件 | 子面板按父宽纵排 | D `img2img_panel_test.dart` | 实现已审计；有直接证据 |
| GEN-030 | Img2Img 超分子 Panel | Workflow 切为 upscale | `widgets/img2img_upscale_section.dart` | 本地/NovelAI、倍率、Seed、Anlas、运行状态 | 局部 Wrap/滚动 | D `img2img_panel_test.dart` | 实现已审计；有直接业务证据 |
| GEN-031 | ComfyUI Workflow Form | Img2Img 源图区工作流按钮 | `widgets/comfyui_workflow_dialog.dart` | 未配置、动态槽位、运行、结果、错误 | R-P Form；侧栏 560 | D `screens/generation/widgets/comfyui_workflow_dialog_test.dart` | 实现已审计；有直接证据 |
| GEN-032 | Reverse Prompt Panel | 参数区/官网左栏反推 | `widgets/reverse_prompt_panel.dart` | 无图/多图、拖放、ONNX/LLM/角色替换链、处理/错误/结果 | 折叠面板；动作按局部宽度重排 | D `reverse_prompt_panel_test.dart`、`light_theme_readability_test.dart` | 实现已审计；组合链覆盖不完整 |
| GEN-033 | Vibe Transfer Panel | 参数区/官网左栏 Vibe | `widgets/unified_reference_panel.dart`、`vibe_transfer_content.dart` | 无/多 Vibe、最近、启用、编码、库导入导出 | 折叠面板；卡片窄宽重排 | P `vibe_card_test.dart` | 实现已审计；状态矩阵未直测 |
| GEN-034 | Vibe 卡手动编码确认 Dialog | 未编码 Vibe→编码 | `widgets/vibe_card.dart` | 未登录、估算成本、确认/取消、处理中 | 策略允许的短付费确认 `AlertDialog` | D `screens/generation/widgets/vibe_card_test.dart` | 实现已审计；有直接业务证据；窄屏 Dialog 专项测试空白 |
| GEN-035 | Vibe 导出 Menu | Vibe Panel 导出按钮 | `handlers/vibe_export_handler.dart` | 单个/多个、文件/嵌图选项 | R-M PopupMenu | S | 实现已审计；专项测试空白 |
| GEN-036 | Vibe 导出类型 Dialog | 导出多个 Vibe 后选择类型 | `handlers/vibe_export_handler.dart` | 数量、类型、取消 | `AlertDialog` | S | 实现已审计；专项测试空白 |
| GEN-037 | Vibe 嵌入选择 Form | 导出→选择要嵌入的 Vibe | `handlers/vibe_export_handler.dart` | 0–16 选择、全选、返回 | R-P Form；侧栏 480 | D `screens/generation/handlers/vibe_export_handler_test.dart` | 实现已审计；有直接证据 |
| GEN-038 | Vibe 保存到库 Form | Vibe 导入/卡片保存 | `handlers/vibe_import_handler.dart` | 名称、分类、信息提取、覆盖原图 | R-P Form；侧栏 440 | D `screens/generation/handlers/vibe_import_handler_test.dart` | 实现已审计；有直接证据 |
| GEN-039 | Precise Reference Panel | 参数区/官网左栏精准参考 | `widgets/precise_reference_panel.dart` | 不支持、空/多引用、启用、类型、强度/保真度、拖放 | 折叠面板；卡片随父宽重排 | D `parameter_panel_test.dart`、`light_theme_readability_test.dart` | 实现已审计；导入弹层在范围外 |
| GEN-040 | Director Tools Screen | Img2Img 源图→Director Tools；`ImageWorkflowLauncher.openDirectorTools` | `screens/director_tools/director_tools_screen.dart` | 源图、工具选择、Prompt、处理中、错误、结果、应用 | 高 `>=480` 且剩余图区满足最小宽才左右排，否则上下堆叠；顶栏 `<600` 图标化 | D `screens/director_tools/director_tools_screen_responsive_test.dart` | 实现已审计；有真实 launcher 与组件证据 |
| GEN-041 | Director Anlas 确认 Dialog | 点击运行收费工具 | `screens/director_tools/director_tools_screen.dart` | 成本不可估禁用、确认/取消、一次执行 | 公共 `ThemedConfirmDialog`；响应实现范围外 | D `director_tools_screen_responsive_test.dart` | 实现已审计；有入口行为证据 |

## Prompt 配置、标签与固定词

| ID | UI 单元 | 真实入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|---|
| PRM-001 | PromptConfigScreen | `/prompt-config` | `screens/prompt_config/prompt_config_screen.dart` | loading/error/空、官方/自定义/扩展、搜索、Preset | 内容宽度与 textScale 决定双区或 Compact 单区 | D `screens/prompt_config/random_config_screen_test.dart`、`prompt_config_responsive_layout_test.dart` | 实现已审计；有直接证据 |
| PRM-002 | Prompt 配方工作区 | PromptConfig 有可用 Preset/词库 | `prompt_config_screen.dart` `_RecipeWorkspace`/`_CompactWorkspace` | 搜索、类别、标签组、只读源 | Expanded 主区+Inspector；Compact 单列 | P `random_config_screen_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-003 | Prompt Inspector/预览 Panel | 顶栏预览或 Ctrl/Cmd+Enter | `prompt_config_screen.dart` `_InspectorPanel`、`preview_generator_panel.dart` | 隐藏/显示、生成预览、统计/错误 | 双区固定 370/420；Compact 内联可关闭 | D `widgets/prompt/random_manager/preview_generator_panel_test.dart` | 实现已审计；Inspector 仅父级 |
| PRM-004 | Import/Export Action Panel | PromptConfig 顶栏导入导出 | `prompt_config_screen.dart` | 导入、导出当前、无 Preset 禁用 | R-P Panel | S | 实现已审计；专项测试空白 |
| PRM-005 | Preset Import/Export Form | PRM-004 选择导入或导出 | `widgets/prompt/diy/dialogs/preset_import_dialog.dart` | JSON、校验、复制/保存、取消 | R-P Form | D `widgets/prompt/diy/dialogs/preset_import_dialog_test.dart` | 实现已审计；有直接证据 |
| PRM-006 | Source Details Form | PromptConfig 来源状态按钮 | `prompt_config_screen.dart` `PromptSourceDetailsDialog` | 当前模型、来源、校验状态、未知模型 | R-P Form | D `screens/prompt_config/prompt_config_source_status_test.dart` | 实现已审计；有真实入口证据 |
| PRM-007 | Preset 选择/操作 Menu | PromptConfig PresetSelectorBar | `widgets/prompt/random_manager/preset_selector_bar.dart` | 选择、新建、复制、重命名、删除/重置、同步项 | R-M PopupMenu；窄标题行 Wrap | P `random_config_screen_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-008 | New Preset Form | Preset Menu→新建 | `widgets/prompt/new_preset_dialog.dart` | 名称、创建方式、系统返回 | R-P Form；侧栏 420 | D `widgets/prompt/new_preset_dialog_test.dart` | 实现已审计；有直接证据 |
| PRM-009 | Preset 删除确认 Dialog | Preset Menu→删除 | `preset_selector_bar.dart` | 默认只读、确认/取消 | `AlertDialog` | S | 实现已审计；专项测试空白 |
| PRM-010 | Preset 重置确认 Dialog | Preset Menu→重置 | `preset_selector_bar.dart` | 确认/取消 | `AlertDialog` | S | 实现已审计；专项测试空白 |
| PRM-011 | Algorithm Config 展开 Panel | PromptConfig Inspector | `widgets/prompt/random_manager/algorithm_config_card.dart` | 折叠/展开、分布、权重、统计 | 卡片内局部纵排 | P `random_config_screen_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-012 | Category 编辑 Panel | PromptConfig 配方区类别卡 | `widgets/prompt/random_manager/category_card.dart`、`category_card_widgets.dart` | 展开、启用、范围、概率、增组 | 局部 Wrap；文本缩放堆叠；三选一控件按 InteractionPolicy 保持触屏 48px 且 Reduce Motion 立即切换 | P `random_config_screen_test.dart` | 实现已审计；Category Panel 状态矩阵未直测 |
| PRM-013 | Tag Group 操作 Menu | 类别内 TagGroupCard 更多 | `widgets/prompt/random_manager/tag_group_card.dart` | 编辑、复制、删除 | R-M PopupMenu | S | 实现已审计；专项测试空白 |
| PRM-014 | Tag Group 删除确认 Dialog | Tag Group Menu→删除 | `tag_group_card.dart` | 确认/取消 | `AlertDialog` | S | 实现已审计；专项测试空白 |
| PRM-015 | Tag Group 编辑 Form | 点击/菜单编辑标签组 | `tag_group_card.dart` `_TagGroupEditDialog` | 基础、标签、DIY 多 Tab、IME、dirty | R-P Form；侧栏 640 | D `widgets/prompt/random_manager/tag_group_card_test.dart` | 实现已审计；有直接证据 |
| PRM-016 | Conditional Branch 配置 Panel | Tag Group 编辑→DIY→条件分支 | `widgets/prompt/diy/panels/conditional_branch_panel.dart` | 无/有条件、模式、值、删除 | 嵌入 R-P Form 内滚动 | D `widgets/prompt/diy/dialogs/conditional_branch_dialog_test.dart`（组件 Form，不是生产入口） | 实现已审计；生产入口仅父级 |
| PRM-017 | Dependency 配置 Panel | Tag Group 编辑→DIY→依赖 | `widgets/prompt/diy/panels/dependency_config_panel.dart` | 依赖类别/组、操作、映射规则 | 嵌入 R-P Form；内部映射另开 Form | D `widgets/prompt/diy/dialogs/dependency_config_dialog_test.dart` | 实现已审计；生产组合仅父级 |
| PRM-018 | Dependency 映射规则 Form | Dependency Panel→添加/编辑映射 | `dependency_config_panel.dart` `_MappingRuleForm` | 匹配、替换、启用、提交/取消 | R-P Form | D `dependency_config_dialog_test.dart` | 实现已审计；有直接证据 |
| PRM-019 | Visibility Rule Panel | Tag Group 编辑→DIY→可见性 | `widgets/prompt/diy/panels/visibility_rule_panel.dart` | 始终/条件、规则值 | 嵌入 Form，随父宽 | P `tag_group_card_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-020 | Time Condition Panel | Tag Group 编辑→DIY→时间条件 | `widgets/prompt/diy/panels/time_condition_panel.dart` | 无/时段/日期、跨午夜 | 嵌入 Form，随父宽 | D `widgets/prompt/diy/dialogs/time_condition_dialog_test.dart`（组件 Form） | 实现已审计；组件证据；生产组合仅父级 |
| PRM-021 | Post-process Rule Panel | Tag Group 编辑→DIY→后处理 | `widgets/prompt/diy/panels/post_process_rule_panel.dart` | 规则开关、预设、参数 | 320/大字堆叠，宽屏同行 | D `widgets/prompt/diy/panels/post_process_rule_panel_test.dart` | 实现已审计；有直接证据 |
| PRM-022 | Add Tag Group Form | Category“添加组” | `widgets/prompt/random_manager/add_tag_group_dialog.dart` | 手工/Danbooru组/Pool Tab、搜索、预览、提交 | R-P Form；侧栏 580，Tab 可滚动 | D `widgets/prompt/random_manager/add_tag_group_dialog_test.dart` | 实现已审计；有直接证据 |
| PRM-023 | Danbooru Group/Pool Preview Panel | Add Tag Group 选择远程组/Pool | `widgets/prompt/random_manager/danbooru_preview_content.dart` | loading/error/空/标签列表 | Form 内滚动 | P `add_tag_group_dialog_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-024 | Random Manager 快捷键帮助 Panel | PromptConfig 快捷键帮助按钮 | `widgets/prompt/random_manager/keyboard_shortcuts.dart` | 分组快捷键、关闭 | R-P Panel | S | 实现已审计；专项测试空白；与全局 ShortcutHelpDialog 不同 |
| PRM-025 | ComfyUI Prompt Import Panel | Prompt 粘贴检测到 Comfy/NAI pipe | `widgets/prompt/comfyui_import_dialog.dart`、`comfyui_import_wrapper.dart` | 检测、全局/角色、导入/取消 | R-P Panel | D `widgets/prompt/comfyui_import_wrapper_test.dart` | 实现已审计；有真实粘贴入口证据 |
| PRM-026 | Fixed Tags 管理 Form | Prompt 固定词按钮点击/长按 | `widgets/prompt/fixed_tags_dialog.dart`、`fixed_tags_dialog_view.dart` | 正/负 Tab、分类、排序、搜索、链接、空态 | R-P Form | D `screens/generation/widgets/fixed_tags_sidebar_test.dart` | 实现已审计；有直接组件证据 |
| PRM-027 | Fixed Tags 头部溢出 Menu | 管理 Form Compact header 更多 | `widgets/prompt/fixed_tags_dialog_chrome.dart` | 添加、链接管理、视图等头部动作 | R-M PopupMenu；Compact 专用 | P `fixed_tags_sidebar_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-028 | Fixed Tag 编辑 Form | 管理/Sidebar→新增或编辑 | `widgets/prompt/fixed_tag_edit_dialog.dart` | 正/负、内容、分类、标签、库来源 | R-P Form | P `fixed_tags_sidebar_test.dart` | 实现已审计；本体状态矩阵未直测 |
| PRM-029 | Fixed Tag Library Picker Form | 固定词添加→从词库 | `widgets/prompt/fixed_tag_library_picker_dialog.dart` | 搜索、空、有/无缩略图、hover 预览、选择 | R-P Form | D `widgets/prompt/fixed_tags_library_picker_test.dart` | 实现已审计；有直接证据 |
| PRM-030 | Fixed Tag Link Manager Panel | 固定词条→联动管理 | `widgets/prompt/fixed_tags_link_manager.dart` | 正/负联动列表、删除、空态 | R-P Panel | D `widgets/prompt/fixed_tags_link_manager_test.dart` | 实现已审计；有直接入口证据 |
| PRM-031 | Fixed Tag Entry Menu | 管理列表条目更多 | `widgets/prompt/fixed_tag_entry_tile.dart` | 编辑、复制、删除、链接 | R-M；精细指针紧凑动作、触屏菜单 | D `widgets/prompt/fixed_tag_entry_tile_test.dart` | 实现已审计；有直接证据 |
| PRM-032 | Global Prompt Settings Form | PromptConfig Inspector→全局设置 | `widgets/prompt/global_settings_dialog.dart` | 默认 Preset只读保护、类别槽位、全局规则 | R-P Form | D `widgets/prompt/global_settings_dialog_responsive_test.dart` | 实现已审计；有直接证据 |
| PRM-033 | Global Settings 类别配置 Form | Global Settings→类别配置 | `global_settings_dialog.dart` | 单人/多人类别、数量/槽位 | R-P Form | S | 实现已审计；专项测试空白 |
| PRM-034 | Global Settings 自定义槽位 Form | Global Settings→自定义角色槽位 | `global_settings_dialog.dart` | 槽位增删、数量、校验 | R-P Form | S | 实现已审计；专项测试空白 |
| PRM-035 | Regex Rules 管理 Form | Prompt 工具栏→正则规则 | `widgets/prompt/regex_rules_dialog.dart` | 空/列表、启用、增改删 | R-P Form | P `widgets/prompt/prompt_character_dialogs_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-036 | Regex 删除确认 Panel | Regex 列表→删除 | `regex_rules_dialog.dart` | 规则名、确认/取消 | R-P Panel | S | 实现已审计；专项测试空白 |
| PRM-037 | Regex Rule 编辑 Form | Regex 管理→新增/编辑 | `regex_rules_dialog.dart` `_RuleEditDialog` | 名称、pattern、replace、目标、启用、校验 | R-P Form | S | 实现已审计；专项测试空白 |
| PRM-038 | Weight Adjust Panel | 标签操作→权重 | `widgets/prompt/weight_adjust_dialog.dart` | 滑杆、数值、重置、编辑、删除 | R-P Panel | D `widgets/prompt/weight_adjust_dialog_responsive_test.dart` | 实现已审计；有直接证据 |
| PRM-039 | Tag Text Edit Form | Weight Panel→编辑文本 | `weight_adjust_dialog.dart` `TagEditDialog` | 原文、替换、提交/取消、IME | R-P Form | D `weight_adjust_dialog_responsive_test.dart` | 实现已审计；有直接证据 |
| PRM-040 | Desktop Tag Floating Action Menu | 精细指针点击/选择 TagChip | `widgets/prompt/components/tag_action_menu/floating_action_menu.dart` | 权重、收藏、复制、编辑、删除、键盘 | R-M root Overlay，边缘水平校正 | D `widgets/prompt/tag_action_menu_responsive_test.dart` | 实现已审计；有直接证据 |
| PRM-041 | Touch Tag Bottom Action Sheet | 触屏点击/长按 TagChip | `widgets/prompt/components/tag_action_menu/bottom_action_sheet.dart` | 与桌面菜单等价动作、滚动 | R-P Panel | D `tag_action_menu_responsive_test.dart` | 实现已审计；有直接证据 |
| PRM-042 | Tag 批量框选 Overlay | TagView 批量选择拖框 | `widgets/prompt/components/batch_selection/selection_overlay.dart`、`tag_view.dart` | 开始/拖动/结束、命中集合 | 仅当前 TagView bounds | P `tag_view.dart` 相关父级测试未见专项文件 | 实现已审计；状态矩阵未直测 |
| PRM-043 | Tag 数量分解 Overlay/Menu | TagView 数量徽标单击；精细指针 hover 提供反馈 | `widgets/prompt/tag_view.dart` `_BreakdownMenu` | 类别计数、点击开关、外点关闭、hover 反馈 | 手工 `OverlayEntry` 锚定徽标；按 Overlay 当前 constraints 与 SafeArea 四边收边；超窄缩宽、长内容滚动 | S | 实现已审计；专项测试空白 |
| PRM-044 | Quality Tags 选择 Menu/预览 Overlay | Prompt 工具栏质量标签 | `widgets/prompt/quality_tags_selector.dart` | 模型可用性、启用、词库项、hover 预览 | PopupMenu + R-M 预览 Overlay | P `prompt_input_test.dart` | 实现已审计；菜单状态矩阵未直测 |
| PRM-045 | UC Preset 选择 Menu | Prompt 负面预设入口 | `widgets/prompt/uc_preset_selector.dart` | Heavy/Light/Furry/Human/None/自定义词库 | PopupMenu，局部收边 | P `prompt_input_test.dart` | 实现已审计；状态矩阵未直测 |
| PRM-046 | Random Mode Popup Menu | 桌面随机模式入口 | `widgets/prompt/random_mode_selector.dart` | Default/Custom/Hybrid | R-M PopupMenu | D `widgets/prompt/random_mode_selector_test.dart` | 实现已审计；有直接证据 |
| PRM-047 | Random Mode Bottom Sheet | 触屏随机模式入口 | `random_mode_selector.dart` `RandomModeBottomSheet` | Default/Custom/Hybrid、说明、选择后回调 | R-P Panel | D `random_mode_selector_test.dart` | 实现已审计；有真实 show 入口证据 |
| PRM-048 | Prompt Toolbar 清空 Menu | Prompt editor toolbar 清空按钮 | `widgets/prompt/toolbar/prompt_editor_toolbar.dart` | 清当前/全部等选项 | PopupMenu | S | 实现已审计；专项测试空白 |

## 角色 UI

| ID | UI 单元 | 真实入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|---|
| CHR-001 | Classic Character 折叠 Panel | Classic Prompt 下方；仅 V4/V5 且已有角色 | `widgets/character/inline_character_row.dart` `ClassicCharacterSection` | 折叠、数量、0 时隐藏 | 随主区宽；高度随角色编辑态 | D `widgets/character/inline_character_section_test.dart` | 实现已审计；有直接证据 |
| CHR-002 | Web Character 折叠 Panel | Web 左栏 Prompt 下方；支持角色模型 | `widgets/character/inline_character_section.dart` | 0/1/多、启用/禁用、折叠、清空 | 左栏宽度内纵排；hover 预览非唯一入口 | D `inline_character_section_test.dart` | 实现已审计；有直接证据 |
| CHR-003 | Inline Character 网格/管理面 | Classic 展开或移动管理 Form | `widgets/character/inline_character_row.dart` | 0/1/多、选择、排序、添加 | 普通按约 190px 自动列；managerLayout 强制 1 列 | D `inline_character_section_test.dart`、`mobile_character_manager_sheet_test.dart` | 实现已审计；有直接证据 |
| CHR-004 | Character Card 内联编辑态 | 点击角色卡 | `widgets/character/inline_character_card.dart`、`inline_character_editor.dart` | 名称、正/负 Prompt、助手、启用、性别、删除 | Classic 全宽行编辑；Web 卡内编辑；移动单列 | D `inline_character_card_test.dart`、`inline_character_section_test.dart` | 实现已审计；有直接证据 |
| CHR-005 | Character Card 操作 Menu | 角色卡更多 | `inline_character_card.dart` `_CharacterActionsMenu` | 上移/下移、入库、删除等 | R-M PopupMenu | P `inline_character_card_test.dart` | 实现已审计；菜单完整状态矩阵未直测 |
| CHR-006 | Add Character Menu | Prompt 角色按钮、网格尾部“+” | `character_prompt_button.dart`、`inline_character_row.dart` | 女/男/其他/从库；达到上限禁用 | PopupMenu；触屏通过可见按钮进入 | D `character_add_from_library_test.dart`、`prompt_input_test.dart` | 实现已审计；有入口证据 |
| CHR-007 | Mobile Character Manager Form | 手机角色按钮（多角色/管理） | `widgets/character/mobile_character_manager_sheet.dart` | 0/1/多、编辑、滚动、返回先退出编辑 | R-P Form；侧栏 560；手机单列 | D `widgets/character/mobile_character_manager_sheet_test.dart`、`screens/generation/widgets/prompt_input_test.dart` | 实现已审计；有直接证据 |
| CHR-008 | Add Character to Library Form | 角色编辑→入库 | `widgets/character/add_to_library_dialog.dart` | 名称、内容、分类、覆盖/返回 | R-P Form | D `widgets/common/add_to_library_dialog_test.dart`、`widgets/prompt/prompt_character_dialogs_responsive_test.dart` | 实现已审计；有生产入口调用证据 |
| CHR-009 | Clear All Characters 确认 Panel | 角色 Panel 清空全部 | `widgets/character/inline_character_editor.dart` | 确认/取消、空列表 | R-P Panel | S | 实现已审计；专项测试空白 |
| CHR-010 | Character Position Canvas 编辑态 | 角色位置模式/位置按钮 | `widgets/character/character_position_canvas.dart` | 拖锚点、键盘移动、自动/自定义、角色芯片 | 画布按可用区；触屏/精细指针共享命令 | D `widgets/character/character_position_canvas_test.dart` | 实现已审计；有直接证据 |
| CHR-011 | Composition Guide Popover Panel | 位置画布构图指南按钮 | `widgets/character/composition_guide_button.dart` | 网格/三分法等提示、开关 | 锚定按钮的轻量浮层 | S | 实现已审计；专项测试空白 |

## 图像编辑器

| ID | UI 单元 | 真实入口 | 实现路径 | 关键状态 | 响应条件 | 直接测试与证据级别 | 实现状态 / 证据说明 |
|---|---|---|---|---|---|---|---|
| EDT-001 | ImageEditorScreen | Img2Img“编辑/重绘”、Agent manual inpaint；`ImageEditorScreen.show` | `widgets/image_editor/image_editor_screen.dart` | 初始化、edit/inpaint、现有 mask/focus、完成返回 | R-I | P `image_editor_workspace_responsive_test.dart` | 实现已审计；Screen 真实入口状态矩阵未直测 |
| EDT-002 | 编辑器初始化 Screen | ImageEditorScreen 首帧/解码中 | `image_editor_workspace.dart` | loading、初始化失败由上层错误处理 | Scaffold + 居中进度 | S | 实现已审计；专项测试空白 |
| EDT-003 | Desktop Editor Workspace | ImageEditor 主体 | `image_editor_workspace.dart` | 菜单、工具栏、画布、图层/设置/颜色、状态栏 | R-I 桌面条件 | D `widgets/image_editor/image_editor_workspace_responsive_test.dart` | 实现已审计；有直接证据 |
| EDT-004 | Mobile Editor Workspace | ImageEditor 主体 | `image_editor_workspace.dart` | AppBar、画布、内联工具设置、底栏 | 不满足 R-I；工具设置高度 `<420` 时 96，否则 150 | D `image_editor_workspace_responsive_test.dart` | 实现已审计；有直接证据 |
| EDT-005 | Mobile AppBar Overflow Menu | 移动宽度 `<520` 的更多按钮 | `image_editor_workspace.dart` | 压缩、加载蒙版、扩边、效果按模式显示 | `<520`；PopupMenu | S | 实现已审计；专项测试空白 |
| EDT-006 | Desktop Toolbar | 桌面编辑器左侧 | `widgets/image_editor/widgets/toolbar/desktop_toolbar.dart` | 工具选择、撤销/重做、清空/填充、禁用 | R-I 桌面；允许工具按 mode 过滤 | D `widgets/image_editor/widgets/toolbar/desktop_toolbar_test.dart` | 实现已审计；有直接证据 |
| EDT-007 | Mobile Toolbar | 移动编辑器底部 | `widgets/image_editor/widgets/toolbar/mobile_toolbar.dart` | 横向工具滚动、撤销/重做、图层、mode 过滤 | R-I 移动；48px 工具目标 | P `image_editor_workspace_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| EDT-008 | Editor Canvas 编辑态 | Workspace 中央 | `widgets/image_editor/canvas/editor_canvas.dart` | 绘制、选区、缩放/平移、hover cursor、预览 | 填满剩余区；输入由能力策略区分 | D `widgets/image_editor/canvas/editor_canvas_cursor_test.dart`、`editor_render_scheduler_test.dart` | 实现已审计；有直接证据 |
| EDT-009 | Layer Panel | 桌面右栏；移动图层按钮 | `widgets/image_editor/widgets/panels/layer_panel.dart` | 空/多层、激活、显隐、排序、删除、合并、3D | 桌面 280px；移动 R-P Panel | D `widgets/image_editor/layer_panel_model3d_test.dart` | 实现已审计；组件有直接证据，移动 Sheet 组合状态矩阵未直测 |
| EDT-010 | Layer Rename 编辑态 | 双击普通图层名 | `layer_panel.dart` `_LayerTile` | 查看→输入、提交/取消、3D 层跳外部编辑器 | 行内输入，受 Panel 宽度约束 | D `layer_panel_model3d_test.dart` | 实现已审计；有直接证据 |
| EDT-011 | Delete Layer 确认 Dialog | Layer Panel 删除非空层 | `layer_panel.dart` | 层名、确认/取消 | `AlertDialog` | S | 实现已审计；专项测试空白 |
| EDT-012 | Mobile Layer Sheet | 移动 AppBar/底栏“图层” | `image_editor_workspace.dart` + `layer_panel.dart` | 同 EDT-009，滚动 | R-P Panel，初始 0.62 | S | 实现已审计；专项测试空白 |
| EDT-013 | Tool Settings Panel 宿主 | 桌面右栏/移动画布下 | `image_editor_workspace.dart` | 当前工具切换、无工具、滚动 | 桌面占右栏 flex；移动高 96/150 | P `image_editor_workspace_responsive_test.dart` | 实现已审计；状态矩阵未直测 |
| EDT-014 | Brush Settings Panel | 选择 Brush | `widgets/image_editor/tools/brush_tool.dart` | 预设、大小、硬度/不透明度等 | 宿主宽度内滚动 | D `widgets/image_editor/tools/brush_tool_test.dart` | 实现已审计；有直接局部证据 |
| EDT-015 | Eraser Settings Panel | 选择 Eraser | `widgets/image_editor/tools/eraser_tool.dart` | 大小/硬度等 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-016 | Fill Settings Panel | 选择 Fill | `widgets/image_editor/tools/fill_tool.dart` | 容差/连续等 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-017 | Magic Wand Settings Panel | 选择 Magic Wand | `widgets/image_editor/tools/magic_wand_tool.dart` | 模式、容差、反转、运行 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-018 | Color Picker Tool Settings Panel | 选择 Color Picker | `widgets/image_editor/tools/color_picker_tool.dart` | 采样模式、预览、颜色同步 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-019 | Clone Stamp Settings Panel | 选择 Clone Stamp | `widgets/image_editor/tools/clone_stamp_tool.dart` | 采样点、大小、硬度、对齐 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-020 | Blur Settings Panel | 选择 Blur | `widgets/image_editor/tools/blur_tool.dart` | 大小、强度等 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-021 | Selection Settings Panel | 矩形/椭圆/套索选区工具 | `widgets/image_editor/tools/selection/base_selection_tool.dart` | 羽化、操作模式等 | 宿主宽度内滚动 | S | 实现已审计；专项测试空白 |
| EDT-022 | Color Panel | Desktop 非 inpaint 右栏 | `widgets/image_editor/widgets/panels/color_panel.dart` | 前/背景色、交换、快捷色 | 仅 R-I 桌面且非 inpaint | D `widgets/image_editor/widgets/panels/color_panel_test.dart` | 实现已审计；有直接证据 |
| EDT-023 | Color Picker Form | Color Panel 点击前/背景色 | `color_panel.dart` `_ColorPickerDialog` | HSV/HEX/RGB、即时更新、IME、关闭 | R-P Form；侧栏 440 | D `color_panel_test.dart` | 实现已审计；有直接入口证据 |
| EDT-024 | Effects Preview Form | 非 inpaint 顶栏/移动菜单→效果 | `widgets/image_editor/effects/effects_preview_dialog.dart` | 无效果/滤镜、预览、参数、应用/取消 | R-P Form | D `widgets/image_editor/effects/effects_preview_dialog_test.dart` | 实现已审计；有直接证据 |
| EDT-025 | Canvas Size Form | Desktop 尺寸按钮 | `widgets/image_editor/widgets/panels/canvas_size_dialog.dart` | 预设/自定义、比例、crop/pad/stretch、校验 | R-P Form | D `widgets/image_editor/widgets/panels/canvas_size_dialog_test.dart` | 实现已审计；有直接证据 |
| EDT-026 | Shift Edges/Outpaint Form | inpaint 顶栏/移动菜单→扩边 | `widgets/image_editor/widgets/panels/shift_edges_dialog.dart` | 四边值、吸附、请求/实际尺寸、键盘提交 | R-P Form | D `widgets/image_editor/widgets/panels/shift_edges_dialog_test.dart` | 实现已审计；有直接证据 |
| EDT-027 | Compression Settings Panel | 顶栏压缩控制→详情 | `image_editor_workspace.dart` `_showCompressionSheet` | 目标尺寸、候选档、已应用/还原 | R-P Panel，初始 0.62 | P `image_editor_workspace_responsive_test.dart` | 实现已审计；Panel 本体状态矩阵未直测 |
| EDT-028 | Shortcut Help Form | Desktop 顶栏键盘按钮 | `image_editor_workspace.dart` `_presentShortcutHelp` | 工具/画布/编辑快捷键、滚动/关闭 | R-P Form；侧栏 440 | D `image_editor_workspace_responsive_test.dart` | 实现已审计；有直接入口证据 |
| EDT-029 | Dirty Exit 确认 Dialog | 返回且有修改 | `image_editor_workspace.dart` | 取消、退出、保存并退出；保存可用性 | `AlertDialog` | S | 实现已审计；专项测试空白 |
| EDT-030 | Export Loading Modal | 保存并退出/完成导出 | `image_editor_workspace.dart` | 不可取消、成功关闭、异常清理 | root `showDialog` 居中进度 | S | 实现已审计；专项测试空白 |
| EDT-031 | Magic Wand Progress Overlay | 魔棒异步处理中 | `widgets/image_editor/widgets/magic_wand_progress_overlay.dart` | idle/processing/progress/阻断 | 覆盖画布区域 | D `widgets/image_editor/widgets/magic_wand_progress_overlay_test.dart` | 实现已审计；有直接证据 |
| EDT-032 | Outpaint Edge Drag Overlay 编辑态 | inpaint、未聚焦重绘、非填充模式 | `widgets/image_editor/widgets/outpaint_edge_drag_overlay.dart` | hover、四边拖动、吸附、预览、提交中、旋转/镜像禁用 | 覆盖画布；手柄/热区随几何计算 | D `widgets/image_editor/widgets/outpaint_edge_drag_overlay_test.dart` | 实现已审计；有直接证据 |
| EDT-033 | Focused Inpaint Overlay/卡片编辑态 | inpaint 启用聚焦重绘 | `image_editor_workspace.dart`、`painters/focused_overlay_painter.dart` | 选区捕获、移动/缩放、成本、启用/关闭 | 画布 Overlay；卡片左上，约束到画布 | D `widgets/image_editor/focused_selection_state_test.dart`、`painters/focused_overlay_painter_test.dart` | 实现已审计；交互组合 UI 状态矩阵未直测 |

## 可达性审计结论

- 在指定目录中发现但生产引用仅指向自身、因此未列作“可达 UI”的声明：`MobileToolSettingsSheet`、`EmphasisConfigPanel`、`DiyGuideDialog`、`NaiRulesDialog`，以及独立 `ConditionalBranchDialog` / `DependencyConfigDialog` / `TimeConditionDialog`。后三者对应的 **Panel** 由 `TagGroupCard` 的生产编辑 Form 直接承载，表中记录的是实际入口，不把测试专用独立 Dialog 冒充生产入口。
- `lib/presentation/widgets/generation` 当前只有 `AutoSaveToggleChip`，它是控制组件而非独立 Screen/Dialog/Sheet/Panel/Menu/Overlay/编辑态，故不单列；其可见性由 `generation_controls_test.dart` 覆盖。
- 当前逐项源码复核未保留真实实现缺口；专项测试空白只限制证据强度。
- 事实性证据边界：Prompt Assistant 菜单/历史/快速设置、部分 PopupMenu 动作集合、Global Settings 嵌套 Form、Regex 管理/编辑、Vibe 导出弹层、图像编辑器移动 Layer Sheet、部分工具设置 Panel、退出与导出 Modal 当前只有源码或父级组合证据；这表示专项状态矩阵尚未直测，不构成实现未完成的结论。
- `AdaptivePresenter` 的 Compact/Medium/Expanded-Wide 表单与面板容器、SafeArea/IME、合同限宽及焦点恢复已有共享测试；Reduce Motion 行为由当前 Presenter 与各行所列组件源码确认，本台账未把没有逐单元动画测试写成实现缺口。
- 现有 widget 测试不等同于 Windows/Android 真实运行验收；本文件不声称执行过真机、模拟器或 Anlas 消耗操作。
