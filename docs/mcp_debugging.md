# 项目级 MCP 调试

Codex 的配置保存在仓库内的 [`.codex/config.toml`](../.codex/config.toml)，随 Git 迁移，不修改用户级 MCP 配置。Codex 只加载已信任项目的配置；新配置保存后，在 MCP 设置中重启服务器，或重新打开项目任务，使工具列表刷新。

## 启动与 SDK 解析

配置从当前 Git 工作树定位 [`scripts/start_dart_mcp.ps1`](../scripts/start_dart_mcp.ps1)，通过 PowerShell 7 启动 SDK 自带的 `dart mcp-server`。需要 Git、PowerShell 7，以及包含 MCP server 的 Flutter SDK；不需要额外安装第三方 MCP server 或填写 API key。

启动器按以下顺序定位 Flutter SDK：

1. 当前进程的 `FLUTTER_SDK`。
2. 本机 `android/local.properties` 中的 `flutter.sdk`。
3. `PATH` 中的 `flutter`。

配置不包含本机绝对路径。迁移工程后，只需在新机器设置上述任一 SDK 来源；`android/local.properties` 保持本机文件，不提交。显式配置指向无效 SDK 时直接报错，不静默改用另一版本。启动器仅为 MCP 子进程补齐 `PATH` 并固定官方 Flutter/Dart 源，标准输出只承载 MCP 协议。

在项目目录执行 `codex mcp get dart --json` 可确认 Codex 已识别配置；这不等于运行时连接成功，还需执行下面的应用连接检查。

## 连接当前应用

1. 按 [开发会话技能](../.agents/skills/aaalice-dev-sessions/SKILL.md) 检查 `Status`，只为缺失平台启动 Runner。两个 Runner 均带 `--print-dtd` 和 `ENABLE_FLUTTER_DRIVER=true`。
2. 使用 MCP 的 `roots` 注册当前仓库的 `file:` URI，再用 `dtd` 的 `listDtdUris` 查找该工作树对应的 DTD；也可使用当前 Runner 日志中实际输出的 DTD URI。旧版 MCP 发现列表为空时，使用同一 SDK 的 `dart tooling-daemon --list`，根据工作树和 PID 核对真实 URI，再交给 MCP 连接。
3. 用 `dtd` 的 `connect` 连接，再通过 `listConnectedApps` 确认应用。存在多个平台或工作树时，后续调用显式传返回的 `appUri`，不得猜 URI、端口或复用旧会话地址。
4. 使用 `widget_inspector` 的 `get_widget_tree` 和 `flutter_driver_command` 的 `get_health` 确认检查器与 Driver 均可用，再执行操作。

复用项目 Runner，禁止为了连接 MCP 再运行 `launch_app`、第二个 `flutter run` 或 `flutter attach`。SDK/Runner 变更后若旧会话没有 DTD，正常停止并重新启动受影响会话，不能把“配置已保存”当作“应用已连接”。

## 应用操作与验收

- 应用内操作使用 `flutter_driver_command`，从当前 widget tree 中选取真实的 `ByValueKey`、文字、Tooltip 或 widget 类型。操作后重新读取树或截图确认结果，不猜控件、不使用屏幕坐标或系统键鼠注入。
- 截图使用 Driver 的 `screenshot`，当前 Agent 必须实际查看返回图像；错误使用 `get_runtime_errors` 并与本轮日志基线比较。截图和临时日志只放在 `tool/.tmp/` 的任务子目录。
- 输入前明确目标编辑框。需要 `enter_text` 时，用 `set_text_entry_emulation` 临时启用模拟输入，完成后恢复为 `false`，避免影响用户继续使用真实 IME。
- 热重载和热重启仍遵循 [热重载技能](../.agents/skills/aaalice-hot-reload/SKILL.md) 的选择规则。已连通 MCP 时可使用 `hot_reload` / `hot_restart`，检查返回结果、运行错误和刷新后页面；未连通时使用已有 `control.ps1` 处理会话准备。
- MCP 不占用系统鼠标键盘，但操作仍会改变目标应用页面和输入。保留并恢复本次临时数据，避免与用户同时编辑同一字段。
- MCP 没有暴露的滚轮、快捷键、原生窗口、系统弹窗或 IME 行为，使用相关 Widget/集成测试补充；实际设备未执行的场景明确标注。不得偷偷退回 Computer Use，或把单元测试结果称为真实设备操作。
- Android 的权限、系统返回、软键盘、分享和文件选择器等系统界面按需使用 ADB；应用内部仍优先 MCP。Windows 原生系统界面若 MCP 无法覆盖，报告边界并由用户手动验证。
- 测试继续使用有 watchdog 的 `scripts/test_affected.ps1` / `scripts/run_flutter_tests.ps1`，不得绕过项目测试时限直接触发无总时限的全量测试。

自动验收授权不包含真实 Anlas 消耗、外部发送、云端传输和用户数据删除。

## 官方依据

- [Codex MCP 配置](https://developers.openai.com/codex/mcp/)：支持受信任项目的 `.codex/config.toml`。
- [Dart/Flutter MCP server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server)：工具、DTD 应用发现与 `--print-dtd`。

工具名与参数以本机 SDK 返回的 schema 为准；SDK 升级后重新验证握手、应用连接、截图和一次可撤销操作。
