---
name: aaalice-hot-reload
description: 为 Aaalice NAI Launcher 修改代码后选择并执行 Windows/Android 的 r 热重载、R 热重启或完整重建，并通过 Orca 增量读取两个控制台验证结果。用户要求热重载、热重启、修改后自动刷新双端、查看两端 Flutter 日志时使用。
compatibility: 项目的 PC热重载与安卓热重载会话已启动。
---

# Aaalice 双端热重载

先加载 `aaalice-dev-sessions` skill，确认需要的开发会话已运行；缺失时按该 skill 创建 Orca 终端。不得启动第二个 `flutter run` 或 `flutter attach`。

## 1. 判定动作

按本次实际改动选择最小但正确的动作：

- `Reload`（小写 `r`）：普通 Dart 方法实现、Widget 布局、样式、文案、不会改变初始化的交互逻辑。
- `Restart`（大写 `R`）：新增/删除/改变 `State` 字段，修改 `initState`、Provider/依赖注入初始化、路由初始化、全局变量、静态缓存、启动流程或生成 Dart 代码；旧状态残留和 `LateInitializationError` 也用它。
- 完整重建：`pubspec.yaml`/插件依赖、Windows C++/插件注册、Android Kotlin/Manifest/Gradle/插件注册发生变化。停止受影响会话，按需运行 `flutter pub get` 或 `build_runner`，再由 `aaalice-dev-sessions` 重建终端。不要用 `r`/`R` 伪装原生改动已生效。

目标选择：

- 共享 Dart/UI/业务代码：`All`。
- 仅 Windows 平台实现：`Windows`。
- 仅 Android 平台实现：`Android`。

## 2. 修改后验证顺序

1. 默认先运行与改动范围匹配的格式化、affected tests 和 scoped analyze；用户明确要求立即启动/刷新时跳过此步，先完成会话启动或 reload/restart，再补最小验证。纯 Dart/UI 改动不得把 `build_runner` 当作验证；只有生成输入变化或 Runner 预检明确阻塞时才按 `aaalice-dev-sessions` 执行一次性环境准备。
2. 从 `tool/.tmp/windows_hot_reload_session.json` 与 `tool/.tmp/android_hot_reload_session.json` 读取 `terminalHandle`。
3. 对每个目标运行 `orca terminal read --terminal <handle> --json`，记录返回的 `latestCursor`，作为本次日志基线。
4. 触发动作但不读取历史 tail：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Reload -Target All -SkipLogs
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Restart -Target All -SkipLogs
```

按判定替换 `Action` 与 `Target`。

5. 等待约 1–2 秒后，对每个 terminal handle 使用步骤 3 的 cursor 增量读取：

```text
orca terminal read --terminal <handle> --cursor <baselineCursor> --limit 1000 --json
```

若结果 `limited`，继续使用 `nextCursor` 读取，直到追上 `latestCursor`。

## 3. 完成标准

必须分别确认每个目标：

- 控制台出现对应的 reload/restart 完成信息，而不是只有“已发送按键”。
- 没有新的编译失败、Flutter exception、`RenderFlex overflow`、`LateInitializationError` 或原生崩溃。
- 某一端失败时保留另一端真实结果，明确指出失败端和原始错误；不要笼统声称双端完成。

用户也可以在两个终端中手动按 `r`/`R`。Agent 自动操作时始终走本 skill 的 `scripts/control.ps1` 和 Orca 增量日志，不使用固定窗口句柄。
