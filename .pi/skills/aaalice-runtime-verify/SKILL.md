---
name: aaalice-runtime-verify
description: 对 Aaalice NAI Launcher 的 Windows 桌面端和 Android 端执行不抢占用户键鼠的 Flutter 原生 AI 自动化、截图、布局检查与异常日志验证。用户要求自动化测试、点击操作、检查布局、双端 UI 验收、Android emulator 或 PC 窗口测试时使用。
compatibility: Dart 3.9+、Dart and Flutter MCP server、ADB，且对应 Flutter 开发会话已启动。
---

# Aaalice 双端运行时验收

先加载 `aaalice-dev-sessions` 与 `aaalice-hot-reload`，确认目标会话已运行并完成正确的 `r`/`R`。

## 强制边界

- 禁止使用 Computer Use、Win32 鼠标注入或任何会抢占用户键盘、鼠标、焦点和桌面操作权的方案。
- Windows 与普通 Flutter UI 使用官方 Dart and Flutter MCP server 驱动现有 App。
- Android 系统 UI 使用 ADB；不得从 Windows emulator 窗口坐标推算设备坐标。
- Flutter MCP 无法控制的 Windows 原生弹窗或 platform view 由用户手动验收，不以后台模拟结果冒充。

## Flutter MCP 准备

项目 `.mcp.json` 已配置：

```json
{
  "mcpServers": {
    "dart": {
      "command": "dart",
      "args": ["mcp-server"]
    }
  }
}
```

项目 runner 使用 `--dart-define=ENABLE_FLUTTER_DRIVER=true`，`lib/main.dart` 只在该开发标志存在时启用 `enableFlutterDriverExtension()`，正式构建不会启用驱动。

使用前：

1. 通过 Pi 的 `mcp` 搜索/连接 `dart` server；配置刚变更而当前会话尚未发现时先执行 `/reload`，不要改用 Computer Use 绕过。
2. 搜索并描述与 DTD、running Flutter app、`flutter_driver_command`、screenshot/tap/text/scroll 有关的真实工具，按返回 schema 调用，不凭记忆猜参数。
3. 连接当前 worktree 的运行中 Flutter App；Windows 和 Android 同时运行时，依据设备/进程信息选择明确目标，禁止对不确定目标发送操作。

## 通用验收顺序

1. 热重载前记录目标 Orca terminal 的 `latestCursor`。
2. 通过 `aaalice-hot-reload` 执行正确动作。
3. 从基线 cursor 增量读取控制台，确认更新完成且没有新异常。
4. 通过 Flutter MCP 获取当前 screenshot/语义状态，再执行 tap、输入或滚动。
5. 每次改变 UI 后重新截图并读取状态，分别验证可见文本、控件状态、布局和增量日志。
6. 可复现且长期有价值的流程固化为 `integration_test/` 下的 Flutter `integration_test`，使用 `flutter test integration_test/<name>_test.dart -d windows` 或 Android 目标运行。
7. 产物统一放入 `tool/.tmp/`，验收完成后删除，不得提交。

## Windows 自动化

Windows 普通 Flutter Widget 交互全部通过 Dart and Flutter MCP server 完成：截图、按文本/语义定位、tap、输入、滚动和热重载都不接管系统鼠标。

需要确定性窗口截图作为额外证据时可运行只读捕获脚本：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-runtime-verify/scripts/capture_windows.ps1 -OutputPath tool/.tmp/windows-e2e/<name>.png -NoActivate
```

`-NoActivate` 不抢前台焦点。布局至少检查：目标是 Debug App、关键文案/控件存在、没有截断/遮挡/重叠、滚动与弹窗边界正确、最新日志无 `RenderFlex overflow`、Flutter exception 或 crash。响应式场景优先写成可设置 surface size 的 widget/integration test；不主动拖动用户窗口。

## Android 自动化

Flutter App 内普通 Widget 优先使用 Flutter MCP。涉及系统界面、Activity、软键盘、权限、文件选择器等场景使用 ADB，并先实时获取 `uiautomator dump`、截图与 Activity。快速场景：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-runtime-verify/scripts/android_verify.ps1 -Name <scenario> -HotReload -Action "tap:x,y","wait:500"
```

脚本支持 `tap`、`text`、`key`、`swipe`、`wait`，产出 screenshot、window tree、Activity 和有界日志到 `tool/.tmp/android-e2e/`，发现 rendering exception、overflow 或原生崩溃时失败。

规则：

- 坐标只能来自本次设备 tree 的 bounds 或设备截图。
- 只需恢复前台时用 `-Foreground`，不使用 `am force-stop` 破坏 `flutter run`。
- 横竖屏、系统文件选择器、分享、相册、权限和更新安装必须实际走系统界面。
- 未获用户明确授权不得发起真实扣除 Anlas 的生成请求。

## 结论要求

分别报告 Windows 与 Android：执行过的动作、可见结果、截图/树/日志路径、新增异常。任一端未实际运行或操作未验证时明确标记未验收，不以静态分析或“命令已发送”代替真实 UI 结果。
