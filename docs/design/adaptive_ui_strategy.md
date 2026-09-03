# 跨平台自适应策略

本策略与 [`adaptive_ui_inventory.md`](adaptive_ui_inventory.md) 共同构成全界面重构契约：本文件定义共享规则，清单定义覆盖范围和完成证据。视觉规则以仓库根目录 `DESIGN.md` 为准。

## 1. 唯一全局尺寸分类

全局尺寸分类由 `lib/presentation/adaptive/window_size_class.dart` 唯一提供：

| 分类 | 可用 pane 宽度 | 结构职责 |
|---|---:|---|
| Compact | `<600` | `NavigationBar`、单主流程、bottom sheet 或独立次级页 |
| Medium | `600–839` | 60px Rail、紧凑双区；次级面板仍优先 bottom sheet |
| Expanded | `840–1179` | 稳定 Rail、受限 side sheet、按内容最小宽度并列主辅区 |
| Wide | `≥1180` | 可展开 196px Rail，可增加辅助列；表单仍限制在 840–960px |

执行规则：

- Shell/整页依据当前无障碍 pane 的 constraints；局部组件依据最近的 `LayoutBuilder.constraints`。
- IME 只改变可见高度，不改变 width class；折叠屏先由 `LargestDisplayFeatureSubScreen` 选择无铰链遮挡 pane。
- 全局断点不得继续从 `DesignTokens.breakpointMobile/tablet/desktop` 等第二套常量读取；现有 `600/900/1200` 全局语义逐步迁移。
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

对应清单：第 1 节全部条目，以及第 10 节“Medium 仍复用桌面 Shell”“键盘/底栏突变”“状态随断点销毁”。

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
- Medium：紧凑 master/content；次级编辑仍优先 bottom sheet。
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

### Panel

统一复用 `AdaptivePresenter`：

- Compact/Medium：避开 SafeArea 与 IME 的 `DraggableScrollableSheet`。
- Expanded/Wide：受限 side sheet，默认宽度经 `WorkspaceSidePanelContract` 随可用 pane 计算；调用方的内容偏好宽度仍受同一上限约束，避免 Expanded 主区被挤压，Wide 也不盲目拉宽。
- 公共契约补齐 dismiss policy、焦点恢复、可选 Compact fullscreen 和 Reduce Motion。

### Dialog

- Dialog 仅用于必须打断的决策、危险确认、脏状态确认和不可中断流程。
- 短确认使用可滚动正文 + 固定可达 actions；取消在前，主操作在后。
- 长表单/向导：Compact fullscreen，Medium 受限居中 dialog，Expanded/Wide 使用受限 side sheet；危险确认仍用短 dialog。
- 最大尺寸依据 safe usable viewport、`viewInsets` 和稳定 viewport margin 计算；现有固定 `800x600`、`640x640` 等只作最大值，不得成为强制尺寸。
- Esc/系统返回关闭后恢复触发控件焦点。

### Menu

- Pointer/keyboard：锚定菜单并避让四边与 SafeArea。
- Touch 或显式“更多”：bottom action sheet。
- 两种容器消费同一 action/command 列表；enabled、selected、danger、shortcut 和 semantic label 只是展示属性，不复制 callback。
- hover、右键、拖放、快捷键只作加速器；核心操作必须有单击、长按或显式更多入口。

### Overlay

- 自动补全继续使用现有手工 root-overlay `OverlayEntry`，不得迁回 `OverlayPortal`。
- 所有 Overlay 覆盖屏幕边缘定位、IME、Escape/外部点击、route dispose、异步取消后不重开。
- Toast 只承载瞬时反馈；必须阅读的错误、风险和状态在页面、panel 或 dialog 原位显示。

对应清单：第 9 节全部条目，以及所有页面中的 dialog/menu/sheet 子项。

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

## 9. 实施依赖顺序

1. 统一 `WindowSizeClass`、pane/insets 指标和旧断点来源。
2. 明确 OS capability 与 interaction policy 边界。
3. 扩展 `AdaptivePresenter`、公共 dialog frame、menu/action presenter、焦点/insets 契约。
4. 稳定 MainShell 拓扑、Medium Rail、目的地登记、返回顺序和 Banner。
5. 统一 Toolbar、BulkActionBar、Pagination、卡片菜单、树节点、空/载/错状态。
6. 生成/Prompt/角色/参数/历史/固定词/Agent。
7. 图片详情/编辑器/Director/水印/3D/对比/幻灯片。
8. 本地/在线画廊和 Tag/Vibe/Precise Ref 资源库。
9. Prompt Config、Statistics、Settings、Cloud Sync、Login、Splash、错误页。
10. 按清单逐项复核、补测试、运行 affected tests 与 analyze。

公共契约必须先于页面迁移；不得先复制 Compact/Expanded 页面，最后再抽象业务状态。

## 10. 可核验测试矩阵

| 宽度 | Shell | Panel | 核心断言 |
|---:|---|---|---|
| 360 | NavigationBar | bottom/fullscreen | 单列、48px 主命中区、无 overflow |
| 412 | NavigationBar | bottom/fullscreen | 软键盘、长本地化、系统返回 |
| 600 | 60px Rail | bottom sheet | Medium 边界准确，不进入宽桌面布局 |
| 700 | 60px Rail | bottom sheet | 在线画廊第一行可滚动且两行职责不混用 |
| 840 | 60px Rail | side sheet | Expanded 边界准确，主辅区不挤压 |
| 1180 | Wide，可展开 Rail | side sheet | 辅助列按局部最小宽度出现 |
| 1600 | Wide | bounded side sheet | 表单不盲目拉宽，画廊充分利用空间 |

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

除非用户后续明确要求，不启动 Windows/Android 自动化运行验收。
