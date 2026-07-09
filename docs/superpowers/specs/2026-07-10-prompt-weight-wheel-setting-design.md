# 提示词选区滚轮调权设置设计

- 日期：2026-07-10
- 状态：已确认，待实现
- 范围：所有复用 `UnifiedPromptInput` 的提示词输入框及“设置 > 生成”页面

## 背景

当前提示词输入框在文本存在有效选区时，会直接处理 `PointerScrollEvent` 并按 0.05 步长调整权重。事件未通过 Flutter 的 `PointerSignalResolver` 仲裁，因此同一个滚轮事件还会被祖先 `Scrollable` 处理，在官网式生成布局中表现为权重变化的同时页面滑动。固定高度且内容可滚动的提示词框还可能由内部 `EditableText` 滚动区域抢先处理事件。

用户确认保留该功能并新增设置开关。开关默认开启；开启且存在有效提示词选区时，滚轮只调整权重，不触发页面、输入框内部或其他滚轮控制；关闭后滚轮不再调整权重，原有滚动行为完全恢复。

## 方案比较

### 方案一：仅使用 `PointerSignalResolver`

权重监听器通过 resolver 注册事件，成为祖先页面滚动区域之前的处理者。该方案改动最小，能解决当前官网式布局的页面滑动冲突；固定高度多行输入框的内部 `Scrollable` 位于更深层，仍可能先获得事件，不满足“任何其他滚轮控制都不触发”的完整要求。

### 方案二：共享输入框内使用 resolver，并按选区暂停内部滚动（采用）

权重监听器通过 resolver 独占事件；共享提示词输入组件同时使用动态滚动物理规则，在开关开启且存在有效选区时让输入框内部 `Scrollable` 不接受用户滚动。其他状态继续委托 Flutter 默认滚动物理规则。该方案把影响限制在当前提示词输入框，同时覆盖页面滚动和输入框内部滚动。

### 方案三：应用级全局拦截

在应用级路由中识别提示词焦点和选区并抢占滚轮。该方案会让提示词组件状态泄漏到全局输入系统，容易影响图像编辑器、数值控件和其他滚轮交互，范围过大，不采用。

## 已确认行为

| 场景 | 权重变化 | 提示词框内部滚动 | 页面或祖先控件滚动 |
| --- | --- | --- | --- |
| 开关开启，有有效选区，鼠标位于提示词框 | 是 | 否 | 否 |
| 开关开启，无有效选区 | 否 | 按原行为 | 按原行为 |
| 开关关闭，有或无选区 | 否 | 按原行为 | 按原行为 |
| 鼠标位于浮动权重工具条，开关开启 | 是 | 否 | 否 |
| 鼠标位于浮动权重工具条，开关关闭 | 否 | 不适用 | 按原行为 |

开关只控制滚轮调权。选区浮动工具条继续显示，其减小、增加、数值输入、重置和关闭操作不受影响。现有 `WeightAdjustToolbarWrapper.enabled` 同时控制整个工具条，不复用为本开关；新增独立的滚轮启用参数。

## 事件处理

`WeightAdjustToolbarWrapper` 收到纵向 `PointerScrollEvent` 后，仅在以下条件同时成立时注册 `GestureBinding.instance.pointerSignalResolver`：

1. 滚轮调权设置开启。
2. controller 中存在合法、非折叠且未越界的文本选区。
3. `scrollDelta.dy` 不为零。

实际权重调整放入 resolver 的获胜回调。回调完成调整后调用 `event.respond(allowPlatformDefault: false)`，阻止桌面平台执行默认滚轮动作。条件不成立时不注册 resolver，也不直接处理事件。

浮动权重工具条的滚轮入口使用同一仲裁规则和同一个开关，避免设置关闭后仍能从浮层区域滚轮调权。

为了覆盖提示词框自身可滚动的场景，`ThemedInput` 暴露 `scrollPhysics`。`UnifiedPromptInput` 传入选区感知的滚动物理规则：开关开启且 controller 当前存在有效选区时，`shouldAcceptUserOffset` 返回 `false`；其他状态委托父级 physics。判断在每次滚轮处理时读取 controller 当前值，不依赖选区变化触发整棵输入组件重建。

## 设置与持久化

设置位于“设置 > 生成”，与现有随机提示词工具入口开关并列。新增持久化键 `enable_prompt_weight_scroll`，由 `LocalStorageService` 读写，并通过 keep-alive Riverpod notifier 暴露为 `promptWeightScrollSettingsProvider`。

未保存过该键时默认返回 `true`。切换后立即写入现有 Hive `settings` box，并立即影响所有复用 `UnifiedPromptInput` 的提示词输入框，无需重启。

本地化文案：

| 语言 | 标题 | 说明 |
| --- | --- | --- |
| 中文 | 滚轮调整提示词权重 | 选中提示词时，滚轮仅调整权重，不再触发页面滚动等其他滚轮操作 |
| English | Adjust prompt weight with mouse wheel | When prompt text is selected, use the wheel only to adjust its weight and suppress other scroll actions. |
| 日本語 | マウスホイールでプロンプトの重みを調整 | プロンプトを選択している間は、ホイールで重みだけを調整し、ページスクロールなどの操作は行いません。 |

## 组件边界

- `StorageKeys` 只定义持久化键。
- `LocalStorageService` 只负责默认值和 Hive 读写。
- `PromptWeightScrollSettings` notifier 只负责响应式状态和持久化调用。
- `GenerationSettingsSection` 只渲染开关并调用 notifier。
- `UnifiedPromptInput` 读取 provider，并把滚轮设置传给共享权重包装器和输入框滚动物理规则。
- `WeightAdjustToolbarWrapper` 负责选区判断、resolver 注册、权重调整及浮层滚轮行为。
- `ThemedInput` 只透传 Flutter `TextField.scrollPhysics`，不读取业务 provider。

## 测试策略

新增权重包装器 widget 回归测试，使用可滚动祖先页面和真实 `PointerScrollEvent` 验证：

1. 开关开启且有选区时，权重按 0.05 改变，祖先页面 offset 不变。
2. 开关关闭且有选区时，文本不变，祖先页面正常滚动。
3. 开关开启但无选区时，文本不变，祖先页面正常滚动。
4. 固定高度长文本输入框在开关开启且有选区时，权重变化，输入框内部和祖先页面 offset 均不变。
5. 浮动工具条区域遵守同一开关。

新增生成设置 section/provider 回归测试，验证默认值为 `true`、已存储的 `false` 能正确恢复、切换后 provider 状态和 Hive 键同步更新。

实现遵循测试驱动顺序：先加入能复现“权重变化且页面同时滚动”的失败测试，确认失败原因正确，再修改生产代码；设置持久化同样先写失败测试。

## 生成与验证

新增 Riverpod notifier 后运行 `dart run build_runner build --delete-conflicting-outputs`。修改中、英、日 ARB 后运行 `flutter gen-l10n`。完成后按仓库规则运行 `flutter pub get`、完整 `flutter test`、`flutter analyze` 和 `flutter build windows --release`。

## 明确不做

- 不改变现有 0.05 权重步长、0.1 至 3.0 范围或 NAI 权重语法。
- 不改变浮动权重工具条的显示条件、按钮和数值编辑能力。
- 不给图片编辑器、数值输入、图库或其他非提示词组件增加全局滚轮规则。
- 不新增依赖，不改变移动端触摸滚动行为。
