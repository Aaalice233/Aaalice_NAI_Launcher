# 提示词助手组件

所有提示词助手入口复用 `lib/presentation/prompt_assistant/widgets/` 中的组件。页面不再计算助手收起/展开尺寸、绘制助手背景或维护独立展开状态。

## 职责

- `PromptAssistantOverlay`：接收 `sessionId`、文本控制器及业务回调；连接共享状态、历史、菜单与操作命令。`supportsTagMode` 和 `stripFixedTagsFromInput` 描述编辑器业务语义。
- `PromptAssistantToolbar`：统一绘制按钮、提示、色面、圆角、裁切和横向滚动。
- `PromptAssistantToolbarMetrics`：统一计算按钮命中区、外壳高度、文字按钮宽度、展开宽度和需要预留的底部空间。普通字号下桌面高度为 44、触屏为 48；大字号可整体增高，收起、展开、处理中、错误态使用同一高度。
- `PromptAssistantDock`：在标题栏或底栏中挂载助手，管理与说明文字、标签页及相邻操作的空间关系。展开只覆盖前方内容，不改变行高。

## 挂载方式

`PromptAssistantPlacement` 只描述位置，不改变按钮样式或动作：

| 方式 | 页面结构 | 用途 |
|---|---|---|
| `inline` | 普通布局；和其他内容共享一行时交给 `PromptAssistantDock` | 角色编辑器、固定标签和词库弹窗 |
| `editor` | 直接放入编辑器的 `Stack.children` | 普通输入框右下角 |
| `viewport` | 放入覆盖编辑器的 `Positioned.fill` | 主正负面提示词框；滚动时跟随可见区域 |

`iconOnly` 决定收起时是否省略文字；`compactDesktopToolbar` 决定撤销/重做是否通过菜单访问；`expandInPlace: false` 将入口设为直接打开菜单。它们不能改变外壳高度。输入方式和主题通过共享 policy/theme 获取。

页面只有在产品需要避让助手时才使用 `PromptAssistantToolbarMetrics.contentBottomClearance` 为正文预留空间；主提示词框使用覆盖式交互，不预留正文空间。不要在页面再次添加与展开状态相关的 `SizedBox`、`Padding`、`Material` 或 `ClipRRect` 来包装助手。

## 验证

共享契约见 `test/presentation/prompt_assistant/widgets/prompt_assistant_layout_test.dart`，覆盖挂载位置、鼠标/触屏、图标/文字入口、大字号、状态切换、高度与点击区域。入口集成测试分别位于 generation、character 和 tag_library_page 的对应测试目录。修改共享控件后同时检查其调用方，并保留各入口的会话标识、翻译语义和业务回调。
