# 提示词助手组件

所有提示词助手入口复用 `lib/presentation/prompt_assistant/widgets/` 中的组件。页面不再计算助手收起/展开尺寸、绘制助手背景或维护独立展开状态。

## 职责

- `PromptAssistantOverlay`：接收 `sessionId`、文本控制器及业务回调；连接共享状态、历史、菜单与操作命令。`supportsTagMode` 和 `stripFixedTagsFromInput` 描述编辑器业务语义。
- `PromptAssistantToolbar`：统一绘制按钮、提示、色面、圆角、裁切和横向滚动。
- `PromptAssistantToolbarMetrics`：统一计算按钮命中区、外壳高度、文字按钮宽度、展开宽度和需要预留的底部空间。普通字号下桌面高度为 44、触屏为 48；大字号可整体增高，收起、展开、处理中、错误态使用同一高度。
- `PromptTagModeToggle`：共享文本/标签双图标开关；`PromptEditorControlRow` 将其与标题、提示文字或相邻操作组合。二者位于 `widgets/prompt/`，不依赖具体页面。
- `promptTagModeProvider(sessionId)`：每个输入框独立管理模式。稳定会话标识仅保存在本机；临时草稿与无持久标识的输入框使用 controller 身份，不写入设置，也不参与云同步。正向、负向、角色及不同词条不得共用标识。

## 挂载方式

`PromptAssistantPlacement` 只描述位置，不改变按钮样式或动作：

| 方式 | 页面结构 | 用途 |
|---|---|---|
| `inline` | 普通布局，按工具栏自然尺寸挂载 | 独立工具栏或组件测试 |
| `editor` | 直接放入编辑器的 `Stack.children`，或传入 `TagModePromptField.assistant` | 角色、固定标签及普通输入框右下角 |
| `viewport` | 放入覆盖编辑器的 `Positioned.fill` | 主正负面提示词框、随内容增高的词库编辑框；滚动时跟随可见区域 |

`iconOnly` 决定收起时是否省略文字；`compactDesktopToolbar` 决定撤销/重做是否通过菜单访问；`expandInPlace: false` 将入口设为直接打开菜单。它们不能改变外壳高度。输入方式和主题通过共享 policy/theme 获取。

模式开关在主输入框底栏、角色顶栏及编辑弹窗页脚中挂载；通用输入框提供默认底栏。助手收起时使用透明、无边框的图标入口，悬停底色为圆形；展开时使用主题内不透明、无边框的浮层色面，遮住底层提示词，且不改变输入区尺寸。

页面只有在产品需要避让助手时才使用 `PromptAssistantToolbarMetrics.contentBottomClearance` 为正文预留空间；主提示词框使用覆盖式交互，不预留正文空间。不要在页面再次添加与展开状态相关的 `SizedBox`、`Padding`、`Material` 或 `ClipRRect` 来包装助手。

## 编辑器尺寸边界

`UnifiedPromptInput.fitContent` 将自动高度意图传递给 `TagModePromptField`：文本模式由文本编辑器自然布局，标签模式由实际标签视图自然布局。隐藏模式保留编辑状态，但不参与自动高度；不得用文本行数、标签数量估算或额外高度缓存代替当前视图的布局结果。手动高度和父级限制只约束视口，内容超出时由当前模式内部滚动；恢复自动高度只解除手动约束，不重建编辑器。

## 执行与预览交互

助手处理时暂时收起为同高度的进度按钮，鼠标悬停或键盘聚焦后显示停止图标；触屏直接显示停止入口。成功后恢复展开并显示完成提示；取消或失败保留原文，不提交未完成结果。切换输入会话或卸载编辑器会取消原任务，旧回调不得写入新输入框。

角色替换每次打开词库选择面，只有明确选择本次目标才开始处理；不读取或写入反推菜单的持久化角色选择。

`DelayedRichTooltip` 统一管理提示词类型、固定词、质量词与角色预览：每个入口独立等待 300 毫秒，切换入口时关闭旧预览，移入预览后可继续滚动。普通简短 Tooltip 保持原行为。

## 验证

共享契约见 `test/presentation/prompt_assistant/widgets/prompt_assistant_layout_test.dart`，覆盖挂载位置、鼠标/触屏、图标/文字入口、大字号、状态切换、高度与点击区域。入口集成测试分别位于 generation、character 和 tag_library_page 的对应测试目录。修改共享控件后同时检查其调用方，并保留各入口的会话标识、翻译语义和业务回调。
