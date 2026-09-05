---
name: aaalice-hot-reload
description: 为 Aaalice NAI Launcher 修改代码后选择并执行 Windows/Android 的 r 热重载、R 热重启或完整重建，并读取 Codex 管理的独立开发控制台验证结果。用户要求热重载、热重启、修改后自动刷新双端或查看 Flutter 日志时使用。
---

# Aaalice 双端热重载

先加载 [aaalice-dev-sessions](../aaalice-dev-sessions/SKILL.md)，确认目标独立 PowerShell 窗口已运行；缺失时由该 skill 创建。用户已要求自动化验收时直接完成这些准备，刷新完成后继续 [aaalice-runtime-verify](../aaalice-runtime-verify/SKILL.md) 的界面操作与截图检查。不得启动第二个 `flutter run`、`flutter attach` 或新的 Codex task。

## 判定动作

- `Reload`（小写 `r`）：普通 Dart 方法、Widget 布局、样式、文案和不改变初始化的交互逻辑。
- `Restart`（大写 `R`）：状态字段、`initState`、Provider/依赖注入、路由/启动流程、全局或静态缓存、生成 Dart 代码，以及疑似旧状态残留的问题。
- 完整重建：`pubspec.yaml`/插件依赖、Windows C++/插件注册、Android Kotlin/Manifest/Gradle/插件注册发生变化。先停止受影响会话，按需完成 `flutter pub get` 或生成，再由 `aaalice-dev-sessions` 新建窗口；不得用 `r`/`R` 代替原生重建。

共享 Dart/UI/业务代码作用于 `All`；平台实现只作用于对应端。

## 执行与验证

1. 按变更风险选择必要的定向测试、格式与静态检查，不把三者机械当作每次刷新前置步骤。用户要求立即刷新或启动自动化验收时，先完成会话准备与正确刷新，再补相关最小验证；纯 Dart/UI 改动不得预先运行 `build_runner`。
2. 触发前读取目标控制台，保留本次日志基线：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Logs -Target All -Last 200
```

3. 按判定触发并读取更新后的控制台：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Reload -Target All
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Restart -Target All
```

4. 若输出尚未出现完成或失败信息，短暂等待后仅重新执行 `Logs`，不要重复发送 `r`/`R`。

必须分别确认每个目标出现本次 reload/restart 完成信息，且没有新的编译失败、Flutter exception、`RenderFlex overflow`、`LateInitializationError` 或原生崩溃。某一端失败时保留另一端真实结果并给出失败端的原始错误；“输入已发送”本身不算完成。

用户可以直接在独立窗口手动按 `r`/`R`。Codex 自动操作统一使用本 skill 的 `scripts/control.ps1`；脚本会先用 session marker、进程启动时间、仓库路径和 Flutter 子进程验证目标，再向其控制台发送输入，不依赖窗口标题或固定窗口句柄。
