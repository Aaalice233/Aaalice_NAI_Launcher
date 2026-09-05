---
name: aaalice-runtime-verify
description: 用户要求自动化运行验收、界面操作、截图检查或双端 UI 测试时，自动启动或复用 Aaalice NAI Launcher 热重载会话，使用 Windows Computer Use 和 Android ADB 验证相关成果。
---

# Aaalice 双端运行时验收

## 触发与范围

用户要求自动化验收，即授权为本次验收启动或复用目标热重载会话、刷新应用、进入相关界面、执行可撤销操作和查看截图，无需再次询问是否启动或是否点击。普通代码/文档修改不自动触发运行验收。

按请求和改动范围选择目标：指定 PC 或安卓时只操作对应端；共享 UI 且未限定平台时覆盖 Windows 与 Android。验收相关页面及其可达子状态；只有用户要求全应用验收时才遍历全应用。macOS 未实际运行时不得借用 Windows 结果声称已验收。

## 自动准备会话

1. 加载 [aaalice-dev-sessions](../aaalice-dev-sessions/SKILL.md) 与 [aaalice-hot-reload](../aaalice-hot-reload/SKILL.md)，先检查 `Status`。
2. 缺少目标会话时直接由 `start.ps1` 启动；已有会话按 worktree、进程和设备复用，每个平台最多一个 `flutter run`。不得另开 `flutter attach` 或 Codex task。
3. 以 Runner 预检决定是否需要依赖解析或代码生成。先启动所需环境，不为启动先跑全仓库测试或生成器；预检阻塞时按开发会话技能处理。
4. 读取控制台，确认真实构建/启动日志、Windows Debug App 进程或 Android 包进程；窗口、marker 和 `running` 状态字段不能单独证明应用就绪。
5. 已有会话按改动选择 Reload、Restart 或完整重建；刚从当前代码成功启动的会话无需再重复刷新。

双端启动示例；单端将 `All` 换成 `Windows` 或 `Android`：

~~~powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-dev-sessions/scripts/start.ps1 -Target All -EmulatorId Aaalice_API35
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Logs -Target All -Last 200
~~~

## 工具与目标

- Windows 使用当前可用的 Computer Use skill；操作前读取其运行时、目标窗口和确认规则。通过实时窗口列表选定当前 worktree 的 Debug App，不能只凭标题选择可能同时运行的安装版。
- Computer Use 可截图、查看可用 UI 树、点击、输入、滚动和操作原生弹窗；缺少语义节点时使用当前截图定位。输入可能占用用户键鼠和焦点，开始前说明，结束后交还控制权。
- Android 使用 ADB 操作 App 与系统界面。依据 runner 的实际设备 ID 和当前 Activity 选择目标；坐标来自本次设备截图或 `uiautomator dump` 的 bounds，不从 Windows 模拟器窗口坐标换算。
- 项目验收不依赖 Dart MCP 配置。保留的 Flutter Driver 开发扩展不是 Computer Use/ADB 的前置条件，也不需要为此开启文本输入模拟。
- 工具不可用、目标不明确或控件无法操作时，保留原始错误并报告具体未验收项，不以模拟结果代替。

## 覆盖矩阵与操作

开始前按“页面 × 子部件 × 状态 × 展开层级”列出本次范围。使用 [自适应覆盖清单](../../../docs/design/adaptive_ui_inventory.md) 寻找入口，不能用只访问首页代替相关流程。

- 实际打开相关选项卡、模式、折叠区、抽屉、菜单、筛选、详情、弹窗和编辑态，并验证操作后的状态或数据回写。
- 布局变化涉及空态/有数据态、loading/error、长文案、窄屏、短横屏、3x 文本、IME、SafeArea 或系统返回时分别覆盖。不要把 widget test 中的尺寸组合声称为设备上实际操作过。
- 修改生成页时按影响范围覆盖文生图/图生图、正负提示词、参数、固定词、角色 0/1/多角色及编辑、随机模式、历史和 Agent。
- 热重载前保留控制台日志基线；Android 场景开始前清理或记录 logcat 基线，结束后读取本次增量日志。
- 修改用户输入、选择、临时角色、窗口尺寸或横竖屏等状态后恢复；退出编辑应使用正常取消/返回路径，不清空用户数据。
- 自动化验收不包含真实扣除 Anlas 的生成、Vibe 编码等付费请求，也不包含对外发送、云端上传/恢复、删除用户数据等额外动作；这些操作遵循用户已明确授权的范围，缺少授权时验收到提交前并说明边界。

## 逐张视觉检查与修复

截图生成后，当前 Agent 必须实际查看每张相关截图，按 [DESIGN.md](../../../DESIGN.md) 检查：

- 页面四边、标题栏、导航、工具栏首尾、卡片、输入区、底栏及弹窗的截断、重叠、对齐和间距。
- 文字和图标对比、完整标签、Tooltip、触屏命中区、键盘焦点、选中与禁用状态。
- 展开/折叠、滚动、弹窗与键盘出现前后的内容可达性；真实操作后目标窗口/Activity 仍正确。
- 增量日志中无本次引起的 RenderFlex overflow、Flutter exception 或原生崩溃。

不能只确认截图文件存在、只读 UI 树、只找黄色溢出条或只检查日志。发现属于本次改动的问题后修复、正确刷新、重走失败场景，并复查共享改动影响的另一端。新一轮未出现相关问题后结束；无关问题单独报告，不扩大修复范围。不强制创建审查子代理。

## Android 快速场景与系统输入

~~~powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-runtime-verify/scripts/android_verify.ps1 -Name <scenario> -HotReload -Action "tap:x,y","wait:500"
~~~

`-HotReload` 通过现有独立控制台刷新应用；已单独刷新并确认完成时省略。脚本支持 `tap`、`text`、`key`、`swipe`、`wait`，产出截图、窗口树、Activity 与有界日志。只需恢复前台时使用 `-Foreground`，不用 `am force-stop` 破坏正在运行的 Flutter 会话。

横竖屏、软键盘、返回手势、文件选择器、分享、相册、权限和更新安装涉及 Android 系统行为时，必须实际操作相应系统界面。键盘验证同时检查截图中键盘可见、字符进入输入框及 `dumpsys input_method` 状态，不能只看光标。不要通过禁用、重置 LatinIME 或反复点击旧坐标掩盖输入连接问题。

## 结果与清理

分别报告实际验收的平台、场景、操作和可见结果，区分已通过、失败、未执行及原因。静态检查不替代运行验收；一次成功操作不外推到全部尺寸和状态。

截图、UI 树与日志放在 `tool/.tmp/windows-e2e/` 或 `tool/.tmp/android-e2e/`，查看并报告后清理本次产物，不提交或删除其他任务的证据。开发会话默认保留供用户继续使用；按明确要求关闭，Android emulator 默认保留暖缓存。

稳定且可重复的流程适合固化到 `integration_test/`；运行时必须设置总时限和进程树清理，不能把没有设备执行记录的测试文件当作验收结果。
