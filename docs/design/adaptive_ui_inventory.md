# 自适应 UI 覆盖清单

本文件用于确定本次改动的入口和验收范围，不是历史通过报告。布局规则见 [自适应策略](adaptive_ui_strategy.md)，视觉规则见 [DESIGN.md](../../DESIGN.md)，真实界面操作见 [运行验收技能](../../.agents/skills/aaalice-runtime-verify/SKILL.md)。

## 如何建立本次矩阵

从当前页面代码向下追踪可达的 Screen、Dialog、Sheet、Panel、Menu、Overlay 和编辑态，逐项记录入口、状态、尺寸、操作与预期结果。下面是领域入口，不代表列出的全部功能已完成测试。

| 领域 | 代码入口 | 需要按改动展开的场景 |
|---|---|---|
| Shell 与导航 | [router/](../../lib/presentation/router/) | 目的地、更多菜单、Rail 折叠、Agent/队列面板、返回层级、最小化恢复 |
| 启动与登录 | [splash/](../../lib/presentation/screens/splash/)、[auth/](../../lib/presentation/screens/auth/) | 预热、未登录、自动登录失败、恢复入口、账号切换 |
| 生成工作台 | [generation/](../../lib/presentation/screens/generation/) | 经典/官网式布局、文生图/图生图、正负 Prompt、参数、历史、随机模式 |
| 角色 | [character/](../../lib/presentation/widgets/character/) | 0/1/多角色、添加、选择、编辑、折叠、移动端独立入口 |
| Prompt 与固定词 | [prompt/](../../lib/presentation/widgets/prompt/)、[prompt_config/](../../lib/presentation/screens/prompt_config/) | 文本/标签模式、补全、权重、搜索替换、固定词、预设、DIY、导入导出 |
| Prompt Assistant | [prompt_assistant/](../../lib/presentation/prompt_assistant/) | 输入、历史、菜单、配置、取消、错误与长输出 |
| 图像编辑与 Director | [image_editor/](../../lib/presentation/widgets/image_editor/)、[director_tools/](../../lib/presentation/screens/director_tools/) | 工具、图层、选区、参数面板、退出/保存、系统文件入口 |
| 本地图库 | [local_gallery/](../../lib/presentation/screens/local_gallery/) | 扫描、分类/相簿、搜索、筛选、排序、分页、选择、批量操作、详情 |
| 在线画廊 | [online_gallery/](../../lib/presentation/screens/online_gallery/) | 来源/模式/分级、全局工具、来源筛选、登录、加载/取消/失败、详情与多选 |
| 词库 | [tag_library_page/](../../lib/presentation/screens/tag_library_page/) | 分类树、排序、选择、新增/编辑、缩略图、独立选择器、批量操作 |
| Vibe 与精准参考 | [vibe_library/](../../lib/presentation/screens/vibe_library/)、[precise_ref_library/](../../lib/presentation/screens/precise_ref_library/) | 分类、卡片菜单、导入/导出、详情、选择、编辑、模型可用性 |
| 统计 | [statistics/](../../lib/presentation/screens/statistics/) | 周期、自定义日期、筛选、图表、空数据、导出 |
| 设置与云备份 | [settings/](../../lib/presentation/screens/settings/)、[cloud_sync/](../../lib/presentation/screens/cloud_sync/) | 分类→详情、长表单、主题/语言、账户、选择内容、连接、预览/取消、进度/错误 |
| Agent | [agent_chat/](../../lib/presentation/agent_chat/)、[agent_settings/](../../lib/presentation/agent_settings/) | 会话、Composer、模型/权限菜单、附件、工具结果、停止、长消息与滚动恢复 |
| 队列 | [queue/](../../lib/presentation/widgets/queue/) | 列表、空态、编辑、排序、选择、取消与进度；启动任务受付费授权约束 |
| 水印与 3D | [watermark/](../../lib/presentation/screens/watermark/)、[model3d_editor/](../../lib/presentation/widgets/model3d_editor/) | 画布、工具、参数、材质/资源选择、保存与退出 |
| 共享反馈与系统入口 | [common/](../../lib/presentation/widgets/common/)、[drop/](../../lib/presentation/widgets/drop/)、[metadata/](../../lib/presentation/widgets/metadata/)、[discord_share/](../../lib/presentation/widgets/discord_share/) | 提示、菜单、文件选择、拖放、元数据、分享提交前确认 |
| 沉浸查看 | [slideshow_screen.dart](../../lib/presentation/screens/slideshow_screen.dart)、[image_comparison_screen.dart](../../lib/presentation/screens/image_comparison_screen.dart) | 翻页、缩放、元数据、操作显隐、返回、键鼠与触屏等价入口 |

## 尺寸、状态与输入

共享 UI 按适用范围覆盖 320、600、840、1180、1600 logical pixels，补充短横屏、3x 文本、SafeArea、IME、Reduce Motion 和长本地化。边界判断另测 599.9/600、839.9/840、1179.9/1180；不能靠单个设备截图证明全部断点。

每个独立子表面至少考虑：

- 空态、有数据、loading、error、disabled、success，以及最长有效内容。
- 展开前后、菜单/弹窗打开、编辑提交/取消、选择与未提交状态。
- 鼠标/键盘/触屏入口、焦点恢复、滚动、返回与窗口变化后的状态保持。
- 预期操作是否真实完成；请求有成本或外部写入时按已有授权确定终点。

在线画廊额外覆盖 700、840、1180、1600；所有全局控件保持第一行职责和纵向中心，QuickTagCloud 单列回归。

## 共享实现与回归入口

| 能力 | 实现 | 测试 |
|---|---|---|
| 尺寸分类 | [window_size_class.dart](../../lib/presentation/adaptive/window_size_class.dart) | [window_size_class_test.dart](../../test/presentation/adaptive/window_size_class_test.dart) |
| 布局与限宽 | [adaptive_layout.dart](../../lib/presentation/adaptive/adaptive_layout.dart) | [adaptive_layout_test.dart](../../test/presentation/adaptive/adaptive_layout_test.dart) |
| 输入策略 | [interaction_policy.dart](../../lib/presentation/adaptive/interaction_policy.dart) | [interaction_policy_test.dart](../../test/presentation/adaptive/interaction_policy_test.dart) |
| 模态呈现 | [adaptive_presenter.dart](../../lib/presentation/adaptive/adaptive_presenter.dart) | [adaptive_presenter_test.dart](../../test/presentation/adaptive/adaptive_presenter_test.dart) |
| Dialog 视口 | [adaptive_dialog_frame.dart](../../lib/presentation/widgets/common/adaptive_dialog_frame.dart) | [adaptive_dialog_frame_test.dart](../../test/presentation/widgets/common/adaptive_dialog_frame_test.dart) |
| 主题与色面 | [themes/](../../lib/presentation/themes/) | [theme_color_contrast_test.dart](../../test/tool/theme_color_contrast_test.dart) |
| 架构契约 | [adaptive/](../../lib/presentation/adaptive/) | [responsive_ui_contract_test.dart](../../test/presentation/adaptive/responsive_ui_contract_test.dart) |
| 在线画廊顶栏 | [online_gallery_screen.dart](../../lib/presentation/screens/online_gallery/online_gallery_screen.dart) | [online_gallery_source_auth_test.dart](../../test/presentation/screens/online_gallery/online_gallery_source_auth_test.dart) |

领域测试从 `test/presentation/` 对应路径定位，检查实际断言而不是仅凭文件名判断覆盖。优先用 `scripts/test_affected.ps1 -ListOnly` 查看选择结果。

## 证据要求

源码审查、Widget 断言、真实设备操作和视觉检查分别报告。父组件测试不能外推为子菜单直接证据；测试文件存在不等于本次执行通过；UI 树不能代替逐张查看截图。

一次验收记录至少说明平台、代码版本、入口、尺寸/状态、实际操作、可见结果与增量日志。临时矩阵和截图只属于本次任务，不把“本轮通过/未测/阻塞”长期写回本清单。新增或移动入口时更新上述索引；细节以当前代码和本次矩阵为准。
