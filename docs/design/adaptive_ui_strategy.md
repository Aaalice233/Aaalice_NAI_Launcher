# 跨平台自适应策略

本文件维护共享自适应实现规则；[覆盖清单](adaptive_ui_inventory.md) 用于确定本次影响范围，[DESIGN.md](../../DESIGN.md) 定义视觉和交互标准。代码入口以 `lib/presentation/adaptive/` 为准，不把历史迁移计划当作现行 API。

## 1. 唯一全局尺寸分类

全局尺寸分类由 `lib/presentation/adaptive/window_size_class.dart` 唯一提供：

| 分类 | 可用 pane 宽度 | 结构职责 |
|---|---:|---|
| Compact | `<600` | `NavigationBar`、单主流程、bottom sheet 或独立次级页 |
| Medium | `600–839` | 60px Rail、紧凑双区；表单居中，Panel/Picker 按共享 API 呈现 |
| Expanded | `840–1179` | 稳定 Rail、模态内容居中、常驻主辅区按最小宽度并列 |
| Wide | `≥1180` | 可展开 196px Rail，可增加辅助列；表单仍限制在 840–960px |

执行规则：

- Shell/整页依据当前无障碍 pane 的 constraints；局部组件依据最近的 `LayoutBuilder.constraints`。
- IME 只改变可见高度，不改变 width class；折叠屏先由 `LargestDisplayFeatureSubScreen` 选择无铰链遮挡 pane。
- 全局断点只消费 `WindowSizeClass`，不得从 `DesignTokens.breakpointMobile/tablet/desktop` 或页面常量建立第二套全局分类。
- 页面允许声明有业务含义并有测试的局部内容阈值，例如“主区 480 + 辅区 360 + gap 能否并列”；不得把局部阈值包装成设备类型。
- 双栏/三栏成立条件始终是各区域最小宽度与间距之和不超过可用宽度，不因进入 Wide 就强制多栏。
- 网格按最大 item extent 或现有 Masonry 算法算列数，不按设备固定列数。
- 工具栏不足时依次采用：重排、职责分组菜单、可发现横向滚动；禁止缩小交互控件的 `FittedBox`。

## 2. Shell 与导航

`MainShell` 是导航、分支内容、全局 Banner、Agent/队列面板和返回编排的稳定 owner。跨断点时不得创建另一套路由、Provider 或业务命令。

- Compact：保留四个高频目的地 + “更多”的五入口 `NavigationBar`。
- Medium：固定 60px Rail；所有目的地通过 Rail 或明确“更多”入口可达，不展开为 196px。
- Expanded：稳定 60px Rail，可保留用户展开偏好但不挤压主内容。
- Wide：应用现有 Rail 展开偏好，宽度为 60/196px。
- `AppBranch` 及其共享 destination model 是 route index、图标、文案、快捷键、Compact 主入口和“更多”入口的唯一登记源。
- Agent 与队列始终复用 `ShellPanel` / `shellPanelProvider`；Compact/Medium 呈现为底部面板，Expanded/Wide 呈现为右侧面板。
- 面板在 resize 时原位变形，不关闭重开；当前 Agent 会话、队列、输入、选择和滚动状态不得丢失。
- Compact 键盘或全屏 workspace overlay 激活时可以暂时隐藏底栏以保护内容，但不得清空导航或 overlay 状态。

验证 Shell、键盘/底栏变化与状态恢复时，使用[覆盖清单](adaptive_ui_inventory.md) 建立具体入口矩阵。

## 3. 工作区、目录与配置页面模式

### 任务工作区

适用：Generation、Image Editor、Director Tools、Watermark、3D Editor。

- Compact：单主区；参数、历史、工具设置放 Drawer、sheet 或独立层。
- Medium：主区 + 最多一个可选辅助区，并始终保护主任务最小宽度。
- Expanded/Wide：按局部最小宽度并列多区，侧栏宽度复用 `WorkspaceSidePanelContract`。
- 断点分支只重排共享业务组件；controller、FocusNode、selection、task state 不得创建在分支内部。

### 目录与画廊

适用：Local/Online Gallery、Tag/Vibe/Precise Ref Library。

- Compact：工具面板 + 自适应网格/列表；分类、筛选和详情分层呈现。
- Medium：紧凑 master/content；编辑表单使用 `showForm` 的居中容器，Picker/Panel 遵循各自 API。
- Expanded/Wide：可 persistent tree/content/detail；网格充分利用宽度。
- 列数变化使用稳定 item ID + 局部偏移恢复，而不是只恢复 pixel offset。

### 配置与阅读

适用：Settings、Cloud Sync、Login、Statistics、Prompt Config。

- Compact：列表→详情或单列分组；当前字段避开键盘。
- Medium：Rail/紧凑双区，内容按局部约束重排。
- Expanded/Wide：内容宽度通常限制在 840–960px；图表和工作区例外按任务扩展。
- 不用全宽卡片/表单填满 4K，不用嵌套卡片重复表达层级。

### 沉浸查看

适用：Image Detail、Slideshow、Comparison。

- 媒体始终是视觉主体；metadata 和操作在窄屏分层，在宽屏并列。
- 缩放、翻页、复制、编辑、导出等核心操作必须同时有触屏与键鼠路径。

## 4. Panel、Dialog、Menu 与 Overlay

### 模态 Panel 与 Form

统一复用 [AdaptivePresenter](../../lib/presentation/adaptive/adaptive_presenter.dart)，按 API 职责选择容器：

| API | Compact | Medium | Expanded / Wide |
|---|---|---|---|
| `showForm` | content-sized bottom sheet，可显式展开 | 有界居中 Dialog | 有界居中 Dialog |
| `showPanel` | 可拖拽 bottom sheet | 可拖拽 bottom sheet | 有界居中 Dialog |
| `showPicker` | bottom sheet | bottom sheet | 几何稳定的有界居中 Dialog |

短表单使用 `ContentSizedAdaptiveForm` 随内容收缩并在上限内滚动；长清单保持惰性视口。最大尺寸来自 safe viewport 与 IME，不能把最大高度当作短内容固定高度。呈现结束后按共享 API 恢复焦点，Reduce Motion 直接到稳定终态。

常驻工作区侧栏由 Shell 或布局组件承载，宽度复用 `WorkspaceSidePanelContract`；它不等于模态 side sheet，不能用来替代需要完成/取消的表单。

### Dialog

- Dialog 承载短确认、通知、单选器或需要完成/取消的编辑任务，不只用于危险操作。
- 正文在有界空间内滚动，取消在前、主操作在后；避免两个同轴主滚动区域。
- 固定尺寸只能作为可用视口内的最大值；长内容、大字和 IME 下操作仍须可达。
- Esc/系统返回遵守 dismiss policy，关闭后恢复合理焦点，不丢失不应丢弃的草稿。

### Menu

- Pointer/keyboard：锚定菜单并避让四边与 SafeArea。
- Touch 或显式“更多”：bottom action sheet。
- 两种容器消费同一 action/command 列表；enabled、selected、danger、shortcut 和 semantic label 只是展示属性，不复制 callback。
- hover、右键、拖放、快捷键只作加速器；核心操作必须有单击、长按或显式更多入口。

### Overlay

- 自动补全继续使用现有手工 root-overlay `OverlayEntry`，不得迁回 `OverlayPortal`。
- 所有 Overlay 覆盖屏幕边缘定位、IME、Escape/外部点击、route dispose、异步取消后不重开。
- Toast 只承载瞬时反馈；必须阅读的错误、风险和状态在页面、panel 或 dialog 原位显示。

Dialog、Menu、Sheet 等子项必须独立列入本次矩阵，不能用父页面证据外推。

## 5. Capability 与交互策略边界

`PlatformCapabilities` 只回答真实 OS/API 能力：窗口控制、文件拖放、系统分享/相册、存储、安装、Krita、ComfyUI 等。页面布局不得读取平台名。

Presentation-level interaction policy 回答当前交互方式：

| 输入 | 基础入口 | 加速器与反馈 |
|---|---|---|
| Touch | 单击、显式更多、长按、拖动手柄 | 核心目标优先 48×48，最低 44×44；press/ripple |
| Pointer | 单击、右键、滚轮/触控板、拖放 | hover；桌面常规目标不小于 40×40 |
| Keyboard | Tab/Shift+Tab、方向键、Enter/Space、Esc | 可见焦点、Shortcuts/Actions、关闭后焦点恢复 |

- 输入 modality 只改变入口、反馈和允许的视觉密度，不切换整页布局；锚定菜单等瞬时呈现跟随当前 modality。
- 已观察到的输入能力用于持续保留等价入口和安全命中区：触摸后再使用鼠标不应移除触屏入口，Android 外接鼠标也不应丢失触屏能力。
- Android 外接鼠标、Windows 触屏等混合输入不能被 `isMobile/isDesktop` 简化；未观察到精细指针前不得默认启用 hover/锚定菜单。
- 多选在触屏上有显式模式；桌面额外提供 Ctrl/Cmd、Shift 加速。
- 长按和拖动必须仲裁，不能一次动作同时开菜单并开始拖动。
- Prompt/Autocomplete 的既有 IME、Enter、Shift+Enter、Escape 和相关标签语义保持不变。

## 6. SafeArea、IME 与系统返回

### Insets 所有权

1. `LargestDisplayFeatureSubScreen` 选择 pane。
2. Shell 处理系统状态栏、导航栏和手势区一次。
3. 页面只处理自己确实延伸到的边缘，避免重复 `SafeArea`。
4. Dialog/panel 在自己的 route 内处理 `viewInsets`。
5. 当前输入字段通过稳定 ScrollController / `Scrollable.ensureVisible` 保持可见，不主动丢焦点。
6. Compact 底栏、生成底部操作区和 sheet 不得重复叠加 bottom inset。

### 返回消费顺序

每次返回只关闭一层：

1. popup、autocomplete、context menu；
2. dialog、sheet、side panel、Drawer/endDrawer、Shell Agent/队列；
3. 页面临时模式（Prompt 最大化、选择/批量、详情展开、编辑）；
4. 脏状态或付费操作确认；
5. 分支子路由/详情页；
6. Shell 根；
7. Android 根级二次返回退出。

`mobileShellOverlayNotifierProvider` 只控制 Shell chrome 显隐，不充当第二套导航栈。Android 专属判断只允许存在于 `AndroidRootBackGuard` 等基础设施。

## 7. Resize、最小化与状态保持

- Windows 顶层与 Flutter child resize 契约保持不变；无效/零 constraints 不写回 panel width、scroll offset 或折叠状态。
- 复用 `DesktopWindowFrame` 在零尺寸期间保留同一 child element/state 并暂停 ticker、语义和交互。
- 普通列表复用 `OwnedViewportOffset` / `OwnedScrollController`，新 controller 用保存值作为首帧 `initialScrollOffset`。
- 几何改变的网格/分组列表保存稳定 item anchor；禁止先渲染默认位置再 post-frame `jumpTo`。
- TextEditingController、FocusNode、selection、当前 route、任务、panel 状态由稳定页面 State/controller/provider 持有。
- 非活动分支继续使用 `TickerMode(false)`；保活策略不能把离屏内容留在语义树或命中测试中。

## 8. Motion、视觉与可访问性

- 组件 duration/curve 从 `AppThemeExtension` 获取；微交互 100–180ms，panel/页面 180–280ms。
- `MediaQuery.disableAnimations` 时直接到终态；关闭装饰性 slide/scale，保留静态状态提示。
- Resize 不做整页转场；Rail、panel 等 chrome 的动画不得改变内容几何事实。
- 普通 Card/按钮静止时无投影；层级优先依靠排版、留白和 tonal surface。
- icon-only 操作具 Tooltip 与 Semantics label；selected/toggled/error/loading 不只依赖颜色。
- 页面/dialog 标题具 header 语义；modal 使用独立焦点遍历；错误 Banner 谨慎使用 live region。
- 覆盖文本缩放 `1.0/1.3/2.0/3.0`、Reduce Motion 和简中/繁中/English/日本語长文本。

## 9. 修改与验证顺序

先定位共享尺寸、呈现或状态 owner 的责任，再修改对应组件和调用方；页面复用共享业务状态，不能先复制两套布局再补同步。公共契约变化同步检查受影响的页面与测试，局部改动不扩大为全界面迁移。

按覆盖清单选择相关子表面，补充能证明行为的定向回归，再执行必要静态检查。真实运行验收使用项目技能，并与 Widget 测试的证据分开报告。

## 10. 可核验测试矩阵

| 宽度 | Shell | Panel | 核心断言 |
|---:|---|---|---|
| 320/360 | NavigationBar | bottom sheet | 单列、完整操作、48px 主命中区、无 overflow |
| 412 | NavigationBar | bottom sheet | 软键盘、长本地化、系统返回 |
| 600 | 60px Rail | Panel/Picker 为 sheet；Form 居中 | Medium 边界和呈现类型准确 |
| 700 | 60px Rail | Panel/Picker 为 sheet；Form 居中 | 在线画廊第一行可滚动且两行职责不混用 |
| 840 | 60px Rail | 居中 Dialog | Expanded 边界准确，主辅区不挤压 |
| 1180 | Wide，可展开 Rail | 居中 Dialog | 辅助列按局部最小宽度出现 |
| 1600 | Wide | 居中有界 Dialog | 表单不盲目拉宽，画廊充分利用空间 |

每个适用阶段验证：

- width class 边界：`599.9/600/839.9/840/1179.9/1180`；SafeArea、display feature、IME 不误改 width class。
- Shell 往返：`1180→840→600→360→600→1180` 不丢 route、输入、scroll、selection、ShellPanel。
- 零尺寸：`Size.zero→恢复` 不 dispose 路由、不切换为错误布局、不写回状态。
- 返回：`menu→panel→edit/selection→child route→root guard` 每次只消费一层，Esc/返回恢复焦点。
- 命令等价：同一卡片的单击、右键、长按、更多菜单映射同一 command ID。
- A11y：文本缩放、高对比、Reduce Motion、Semantics header/selected/toggled/liveRegion。
- 状态恢复：列表首帧恢复；网格列数变化保持稳定 item anchor。
- 静态契约：页面无 `Platform.isAndroid`；布局不依赖 `isMobile/hasPrecisePointer`；交互工具栏无 `FittedBox`；全局断点只来自 `window_size_class.dart`。

阶段验证命令：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -Path "<修改的 lib 文件>" -Include "<新增回归测试>"
flutter analyze
```

用户明确要求自动化运行验收时，按[运行验收技能](../../.agents/skills/aaalice-runtime-verify/SKILL.md) 自动启动或复用热重载，通过[项目级 MCP](../mcp_debugging.md) 执行应用内操作、截图检查与运行错误验证；Android 系统界面按需使用 ADB。普通修改不默认启动运行验收。
