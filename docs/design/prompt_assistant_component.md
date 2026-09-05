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
| `editor` | 直接放入编辑器的 `Stack.children`，或传入 `TagModePromptField.assistant` | 角色、固定标签、词库及普通输入框右下角 |
| `viewport` | 放入覆盖编辑器的 `Positioned.fill` | 主正负面提示词框；滚动时跟随可见区域 |

`iconOnly` 决定收起时是否省略文字；`compactDesktopToolbar` 决定撤销/重做是否通过菜单访问；`expandInPlace: false` 将入口设为直接打开菜单。它们不能改变外壳高度。输入方式和主题通过共享 policy/theme 获取。

模式开关在主输入框底栏、角色顶栏及编辑弹窗页脚中挂载；通用输入框提供默认底栏。助手收起时使用图标入口，展开不改变输入区尺寸。

页面只有在产品需要避让助手时才使用 `PromptAssistantToolbarMetrics.contentBottomClearance` 为正文预留空间；主提示词框使用覆盖式交互，不预留正文空间。不要在页面再次添加与展开状态相关的 `SizedBox`、`Padding`、`Material` 或 `ClipRRect` 来包装助手。

## 验证

共享契约见 `test/presentation/prompt_assistant/widgets/prompt_assistant_layout_test.dart`，覆盖挂载位置、鼠标/触屏、图标/文字入口、大字号、状态切换、高度与点击区域。入口集成测试分别位于 generation、character 和 tag_library_page 的对应测试目录。修改共享控件后同时检查其调用方，并保留各入口的会话标识、翻译语义和业务回调。
