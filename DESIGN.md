---
version: alpha
name: Aaalice NAI Launcher
description: Quiet Layered Utility for a local-first, cross-platform NovelAI creative workspace
colors:
  primary: "#F0EAD6"
  on-primary: "#1A1A1A"
  primary-container: "#5C4A3D"
  on-primary-container: "#FFF5EE"
  secondary: "#DC143C"
  on-secondary: "#FFFFFF"
  tertiary: "#D2691E"
  on-tertiary: "#281406"
  surface: "#1A1A1A"
  on-surface: "#F0EAD6"
  on-surface-variant: "#D4CFC0"
  outline: "#525252"
  error: "#DC143C"
  error-container: "#5C1A1A"
  on-error-container: "#FFDAD6"
typography:
  display-large:
    fontFamily: "Oswald"
    fontSize: "57px"
    fontWeight: 400
    letterSpacing: "-0.25px"
  headline-small:
    fontFamily: "Oswald"
    fontSize: "24px"
    fontWeight: 600
  title-large:
    fontFamily: "Oswald"
    fontSize: "22px"
    fontWeight: 500
  title-medium:
    fontFamily: "Courier Prime"
    fontSize: "16px"
    fontWeight: 500
    letterSpacing: "0.15px"
  body-large:
    fontFamily: "Courier Prime"
    fontSize: "16px"
    fontWeight: 400
    letterSpacing: "0.5px"
  body-medium:
    fontFamily: "Courier Prime"
    fontSize: "14px"
    fontWeight: 400
    letterSpacing: "0.25px"
  body-small:
    fontFamily: "Courier Prime"
    fontSize: "12px"
    fontWeight: 400
    letterSpacing: "0.4px"
  label-large:
    fontFamily: "Courier Prime"
    fontSize: "14px"
    fontWeight: 500
    letterSpacing: "0.1px"
  label-medium:
    fontFamily: "Courier Prime"
    fontSize: "12px"
    fontWeight: 500
    letterSpacing: "0.5px"
rounded:
  sm: "4px"
  md: "6px"
  lg: "8px"
  xl: "12px"
  panel: "24px"
  pill: "100px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-large}"
    rounded: "{rounded.md}"
    padding: "12px 20px"
  button-tonal:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    typography: "{typography.label-large}"
    rounded: "{rounded.md}"
    padding: "12px 20px"
  input-default:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.lg}"
    padding: "10px 12px"
  chip-selected:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    typography: "{typography.label-medium}"
    rounded: "{rounded.sm}"
    padding: "4px 8px"
  navigation-active:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    typography: "{typography.label-large}"
    rounded: "{rounded.sm}"
    height: "48px"
  card-section:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
  image-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
---

# Design System: Aaalice NAI Launcher

## Overview

**Creative North Star: "Quiet Layered Utility / 静谧层叠工具界面"**

Aaalice NAI Launcher 是高频创作工具，而不是视觉陈列品。Prompt、图像、参数、状态和操作是视觉主体；容器、主题装饰与品牌表达退到背景，只在帮助理解任务时出现。整体气质克制、专业、内容优先，默认状态安静，交互状态清楚而及时。

系统以 Flutter Material 3 为行为基础，以 `ColorScheme`、`TextTheme`、`AppThemeExtension` 和公共组件表达稳定语义。主题可以改变颜色、字体、形状与轻量动效，但不能改变信息架构、操作顺序、密度边界、可访问性或桌面与 Android 的能力等价。默认 frontmatter 记录 Grunge Collage 暗色主题的真实锚点；其他主题必须沿用同一语义角色，而不是创建另一套组件规则。

**Key Characteristics:**

- 内容优先，容器退后；先用排版、留白和低对比色面建立层级。
- 克制、直接、状态清楚；状态变化不改变组件几何尺寸。
- tonal layered 深度：静态内容依赖色面，阴影留给浮层和图像交互。
- 桌面与移动端共享业务组件、状态和命令，但采用各自自然的导航与输入方式。
- 多主题共享同一信息层级、语义色、命中区和交互结果。

**The Content Before Container Rule.** 如果去掉边框后层级仍然清楚，就不要把边框加回来。

## Colors

默认主题以旧纸奶油、炭黑画布和猩红信号形成高对比的创作工作台；所有主题都通过 Material 3 语义角色替换色值，组件不得直接依赖某一主题的视觉颜色。

### Primary

- **旧纸奶油（`primary`）**：默认暗色主题的主操作、当前选择、焦点和关键进度；使用必须稀少，避免与内容竞争。
- **深褐容器（`primary-container`）**：选中项、低强调主色背景和需要持续可见的状态。

### Secondary

- **猩红信号（`secondary`）**：来源强调和少量主题个性；错误语义必须仍通过 `error` 角色表达，即使默认主题两者同色。

### Tertiary

- **锈橙辅助（`tertiary`）**：次级分类和辅助强调，不承担主操作。

### Neutral

- **炭黑画布（`surface`）**：页面、工作区和默认暗色表面。
- **旧纸正文（`on-surface`）**：主文本与默认图标。
- **暖灰元数据（`on-surface-variant`）**：说明、路径、统计与次级图标。
- **石墨边界（`outline`）**：必要的结构线、输入轮廓和精确边界，不作为普通容器装饰。

Material 表面按职责使用：Canvas=`surface`，Section=`surfaceContainerLow`，Control=`surfaceContainer` / `surfaceContainerHighest`，Overlay=`surfaceContainerHigh`。同一页面最多出现三个明显表面层级。

**The Semantic Color Rule.** 页面只使用 `ColorScheme` 与具名业务语义；禁止散落固定颜色或把 `secondary` 当作错误色。

**The Quiet Accent Rule.** `primary` 只标记主操作、选择、焦点与关键进度，不能让所有按钮和标签同时高亮。

## Typography

默认主题使用 Oswald 构成紧凑标题骨架，以 Courier Prime 承载正文与控制标签；其他主题或用户字体设置可以替换字体族，但必须保留 Material 文字角色、字号层级和可读性。中文正文不额外增加 letter spacing。

- **Display / Headline**：用于少量大标题和页面标题；Operate 界面通常从 `headlineSmall` 或更低层级开始，避免宣传页式巨型标题。
- **Title**：`titleLarge` 用于页面或主面板标题，`titleMedium` / `titleSmall` 用于分组和条目标题。
- **Body**：`bodyLarge` 用于重要说明，`bodyMedium` 是常规正文与表单内容，`bodySmall` 用于辅助信息。
- **Label**：按钮、chip、导航和紧凑元数据使用 label 层级；路径、模型、种子和成列数字应保持易扫描，并使用 tabular figures（适用时）。

一个局部区域最多使用三个明显字号层级。Placeholder 不能替代永久标签；文本缩放和中、英、日、繁体中文长度变化不得裁切关键内容。

**The Working Type Rule.** 排版服务于扫描和操作：标题靠字号、字重与留白建立层级，不靠描边、全大写或高饱和颜色。

## Layout

布局采用 4px 基础网格，稳定间距为 4、8、12、16、24、32px。同组元素间距必须小于组间距；桌面页面水平边距通常为 20–24px，紧凑屏幕为 12–16px。表单和设置内容通常限制在 840–960px，画廊、画布与生成工作区按任务需要扩展。

### Adaptive structure

- **Compact `<600px`**：移动 Shell，单列主流程、Material `NavigationBar`、bottom sheet 或独立次级页面。
- **Medium `600–839px`**：内容可采用紧凑双区，但面板仍优先 bottom sheet；不得通过等比例缩放获得平板布局。
- **Expanded `≥840px`**：桌面 Shell、稳定侧栏与可并行主辅面板。
- **Wide `≥1180px`**：可增加辅助列或更宽工作区，但不盲目拉宽表单。

桌面 Navigation Rail 折叠宽 60px、展开宽 196px；导航项高 48px。宽度动效只改变导航自身的裁切视口，路由工作区只能接收动画起点与终点约束，不得把每一帧的中间宽度传入页面级 `LayoutBuilder`。触屏平台核心命中区优先 48×48 logical pixels，最低不小于 44×44；桌面常规点击目标通常不小于 40×40。方向、窗口尺寸、软键盘与导航容器变化后必须保留输入、选择、滚动位置和任务状态。

在线画廊在可承载工具栏的桌面/平板宽度维持固定职责分行：第一行只放全局控件，第二行只放来源专属筛选与操作。第一行采用左侧站点/模式/分级、中间弹性搜索、右侧全局操作的三段式结构；宽度不足时整行横向滚动，不把全局控件挪到第二行。顶栏使用与 collection workspace 相同的整条 Section 色面，底部分页或随机状态使用独立 Control 色面与 8px 外间距；两者均不使用贯穿式分隔线。设置与统计等工具页面沿用同一顶栏色面规则；设置分类导航作为带 8px 外间距的独立 Section 区域，不用纵向分隔线连接成表格。回归覆盖 700、840、1180、1600px，QuickTagCloud 单独覆盖。

### Collection workspace shell

本地画廊、Vibe 库、精准参考库与词库共用同一种 collection workspace 骨架。工具栏始终是横跨整个工作区的一体化 Section 色面，页面名称固定在工具栏左端；页面标识组按内容取得自然宽度，与后续工具组使用 12px 间距，不得用固定宽度占位制造空白。Expanded/Wide 下的持久分类树位于工具栏下方的独立强 tonal 区域，分页也作为主内容底部的独立强 tonal 区域。三者通过背景色、圆角和 8px 间隔建立层级，不使用贯穿式边线把页面切成表格；色面必须通过 `sectionSurfaceColor` / `controlSurfaceColor` 解析，不能直接读取可能与 Canvas 重合的容器色 token。常规单行工具栏的最小高度统一为 72px，以容纳触屏 48px 命中区；侧栏宽度统一为 250px。新增同类页面必须复用 `GalleryCollectionWorkspace`、`GalleryCollectionToolbarSurface` 与 `GallerySidebarSurface`，不得在各页面复制壳层结构和尺寸。

Compact/Medium 下没有持久侧栏时，页面名称保留在主工具栏，分类导航由 adaptive panel 承载并使用面板自身标题。窄屏换行、长本地化文案或放大文字可以让工具栏向下扩展，但不得裁切、缩放或隐藏操作；恢复为可容纳单行的宽度后应回到 72px 的共同基线。

### Generation workspace identity

画布是高密度创作工作区，不套用 collection workspace 的整条页面工具栏。Expanded/Wide 下，页面身份固定在展开的生成控制栏顶部，以无副标题的紧凑 Section 色面显示“画布”及画笔图标，并与侧栏折叠操作同排；经典布局与官网式布局必须复用 `GenerationWorkspaceHeader`。Compact/Medium 下由 AppBar 显示相同图标与 `nav_canvas` 文案；进入提示词全屏编辑等子任务后，AppBar 改为当前任务标题。侧栏收起时只保留参数展开入口，不重复页面标题。

经典布局的左栏只承载模型、尺寸、采样和高级选项等生成参数；主提示词与角色提示词共同属于中心编辑区，角色区固定紧邻主提示词。官网式布局可将同一角色模块呈现为提示词侧栏列表，但两种布局必须共享模型可用性、角色数据、折叠状态、摘要和添加命令，只替换卡片排布策略。支持角色的模型即使尚无角色，也必须保留首个角色的显式添加入口，不能因空列表隐藏整个模块。

**The Capability Parity Rule.** 桌面 hover、右键与快捷键必须有移动端单击、长按、菜单或系统入口的等价路径；低频操作可以折叠，但不能静默消失。

**The Local Constraint Rule.** 响应式判断使用局部 `LayoutBuilder.constraints` 与 capabilities；禁止按设备型号、`FittedBox` 缩小交互工具栏或在共享页面散落平台判断。

## Elevation & Depth

系统采用 **tonal layered** 深度。Canvas、Section、Control 和 Overlay 主要通过表面色与留白区分；普通 Card、静态内容、输入和按钮在静止状态不使用投影。菜单和 tooltip 使用一级环境阴影，对话框与 bottom sheet 使用二级结构阴影；图像卡片拥有独立的内容交互阴影。

智能体对话的 Composer 是持续可操作的浮起输入区，使用 `controlSurfaceColor` 与聊天 Canvas 建立稳定色阶；不得复用可能向 Canvas 变暗并与背景合并的普通输入填充色。其内部编辑器保持无独立填充和无描边，由同一个 Composer 色面承载输入与操作。附件、权限、展开、模型和上下文等次级控件静止时透明，只用 hover、focus 与 pressed 反馈交互；仅启用的状态开关和可执行的发送主操作保留填充色。

### Shadow Vocabulary

- **Flat Rest**：普通 Card 与按钮 elevation 0，shadow transparent。
- **Overlay Menu**：Flutter elevation 8，black 15%；仅用于 popup menu 与 menu。
- **Dialog Layer**：Flutter elevation 16，black 20%；用于 dialog 与 bottom sheet。
- **Tooltip Ambient**：blur 8px、offset `(0, 4)`、black 15%。
- **Image Rest / Hover**：常态 blur 6px、offset `(0, 2)`、black 8%；hover blur 14px、offset `(0, 6)`、black 16%。

静态 surface 不叠加“渐变 + 描边 + 发光 + 阴影”。玻璃只用于确有背景穿透价值的浮层或主题表达，并避开文字、输入和图像细节。

**The Flat-at-Rest Rule.** 阴影不是默认装饰；只有浮层、状态反馈或图像内容需要与背景分离时才出现。

## Shapes

默认主题使用小而清晰的圆角：微型与 chip 为 4px，按钮为 6px，输入和普通 Card 为 8px，图像卡片为 12px。Adaptive bottom/side panel 的 24px 顶部圆角属于大型可拖拽容器，不应下放到普通卡片。

业务组件声明 `control`、`card`、`dialog`、`menu`、`panel`、`circle` 或 `pill` 等语义角色，实际值由当前 shape preset 和 `AppThemeExtension` 提供。父子圆角通常递减；内层只有 chip、状态标记或圆形控件可以更圆。

默认组件不使用全胶囊和全大圆角。明确采用 `PillShapes` 的现有主题可以保留个性化形状，但不得改变布局密度、命中区、信息架构与操作语义。

**The Semantic Shape Rule.** 页面选择形状角色，不复制圆角数字；硬编码只允许稳定的签名组件尺寸，并应逐步归并到主题或公共组件。

## Components

组件哲学是**克制、直接、状态清楚**。优先复用 Material 3 行为和 `lib/presentation/widgets/common/`，组件 API 表达 `selected`、`danger`、`emphasis` 等语义，而不是暴露任意颜色。

### Buttons

- **Shape / padding**：默认按钮 6px；Filled 与 tonal action 为水平 20px、垂直 12px，TextButton 为水平 16px、垂直 10px。
- **Hierarchy**：`FilledButton` → tonal action → `TextButton` → `IconButton`；`OutlinedButton` 兼容入口表现为无 side 的 tonal action。
- **States**：loading 使用 16px spinner 并保持内容结构和按钮尺寸；危险操作在最终确认阶段使用 error 语义。
- **Access**：仅图标按钮必须提供 tooltip 与语义标签；桌面保留焦点和快捷键，移动端提供足够命中区与即时按压反馈。

### Inputs / Fields

- **Style**：深色填充 Control surface，默认 8px 圆角；单行公共输入通常使用水平 12px、垂直 10px padding，多行使用 12px。
- **Outline**：允许固定几何的低对比 1px 轮廓；默认态尽量接近透明，focus 使用主色增强，error 使用错误色增强。所有状态占用相同内部空间，不改变外部尺寸。
- **Hierarchy**：大面积 Prompt 编辑器优先保障正文面积，工具操作放在框外 footer；只读内容无需编辑能力时直接使用文本。
- **Behavior**：prefix/suffix 保持次级权重；软键盘打开后当前字段必须可见。

### Chips

- **Style**：默认无 side，普通背景使用 `surfaceContainerHighest`，selected 使用 `primaryContainer`；短标签采用 4px 圆角与 8×4px padding。
- **State**：互斥模式优先 segmented control 或 tab；chip 只表示短标签、状态或可移除条件。
- **Touch parity**：删除按钮桌面可紧凑，触屏命中区保持 48×48px。

### Cards / Containers

- **Static Card**：`surfaceContainerLow`、无边框、无阴影；内部 padding 使用 16px 或 24px。
- **Interactive Card**：hover 可提高色面对比或轻移 2px；focus 使用不改变布局的 1px primary 状态线。
- **Grouping**：优先标题与留白，其次低对比色面，最后才是边界；不使用三层嵌套卡片。

### Navigation

- 桌面使用稳定 rail，active 项采用淡主色背景与主色前景；移动端使用五入口 NavigationBar，并通过“更多”保留次级能力。
- Hover 只增强桌面反馈，不承载唯一信息。键盘可见或 shell overlay 激活时，移动底部导航可暂时隐藏以保护工作区。

### Dialogs and adaptive panels

- Dialog 只用于必须打断流程的决策；标题先说决策，正文先说结果，再说原因或风险。
- 操作顺序保持低强调取消在前、主操作在后；Esc 与系统返回可关闭并恢复合理焦点。
- Expanded 使用受限 side sheet；Compact / Medium 使用避开 SafeArea 与软键盘的 bottom sheet。

### Image Cards

- 图像卡片是独立组件族，不套用普通静态 Card 的阴影与边界规则。
- 桌面 hover 约 1.01 倍，仅改变绘制，不改变网格占位；selected / preview 使用 2px 语义边界。
- 移动端通过 press、long-press、selected 和 48px 操作按钮提供等价反馈。
- `MediaQuery.disableAnimations` 时缩放立即回到 1.0，并保留静态状态提示。

动效由 `AppThemeExtension` 驱动。高频状态通常处于 100–200ms，面板和页面变化可延长到 200–300ms。界面禁止使用弹簧、回弹、过冲、弹跳、缩放弹出或会让元素方向反复变化的进出场动画；面板、弹窗、选择器和导航容器优先使用短淡入淡出，确需位移时只允许单向、无过冲的减速过渡。不得在重建时重置 Tween 起点造成横向跳动，Reduce Motion 下必须立即到达终态。

连续拖拽调宽属于高频直接操作。pointer move 不得逐次调用页面级 `setState`、写入 Provider 或重建工作区；宽度变化必须限制在对应分栏的 RenderObject / layout 边界内，由 Flutter 帧调度合并布局，并保持两侧昂贵子树的 Widget identity。拖拽过程中禁止对宽度做补间动画，面板必须一比一跟随指针；需要持久化宽度时只在 drag end 提交最终值。回归测试应同时验证宽度边界、无 overflow，以及拖动期间稳定子树没有 rebuild。

## Do's and Don'ts

### Do:

- **Do** 让 Prompt、图像、参数与主操作比容器和主题装饰更醒目。
- **Do** 从公共组件、`ColorScheme`、`TextTheme`、`AppThemeExtension` 和稳定 spacing tokens 获取样式。
- **Do** 保持 default、hover、pressed、selected、focused、disabled、loading 状态完整且几何稳定。
- **Do** 为桌面鼠标、触控板、键盘和移动端触屏提供等价完成路径。
- **Do** 在共享 UI 变更中覆盖必要的 360、412、600、840、1180、1600px 断点，并检查 SafeArea、软键盘、系统返回和窗口缩放。
- **Do** 使用 Semantics、清晰焦点、至少 WCAG AA 的正文对比度，以及不只依赖颜色的 selected / error / success 表达。
- **Do** 让加载和错误原位呈现，局部刷新保留已有内容；超过约 300ms 的异步操作提供可见反馈。

### Don't:

- **Don't** 给普通卡片、工具按钮、导航项、chip 或已填充控件默认添加高对比完整描边。
- **Don't** 叠加“大圆角卡片 + 图标底座 + 标题 + 副标题”，或用外框、内框和分隔线重复表达同一分组。
- **Don't** 在页面散落固定颜色、圆角、间距和 Duration，或声明没有实际消费者的 token。
- **Don't** 通过缩小文字、裁切、`FittedBox`、静默隐藏功能或复制业务流程得到移动版。
- **Don't** 让 hover、右键、外接键盘或精细拖拽成为核心任务的唯一入口。
- **Don't** 在高频功能控件上使用 bounce、elastic、持续漂浮或旋转；主题个性不能牺牲操作稳定性。
- **Don't** 用 placeholder 代替标签、用 toast 承载必须阅读的信息，或用只读输入框伪装普通文本。
- **Don't** 让主题改变信息架构、语义角色、命中区、响应式行为、可访问性或跨端操作结果。
