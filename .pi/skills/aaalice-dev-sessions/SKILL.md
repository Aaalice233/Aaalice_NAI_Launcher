---
name: aaalice-dev-sessions
description: 管理 Aaalice NAI Launcher 项目专用的 Windows 与 Android Flutter 开发会话。用户提到 PC热重载、安卓热重载、启动/关闭/重建开发终端、创建 Orca 终端、模拟器启动异常、检查双端会话时使用。
compatibility: Windows、PowerShell 7、Flutter、Android SDK 与运行中的 Orca。
---

# Aaalice 双端开发会话

只管理当前 Aaalice NAI Launcher worktree，不启动 `flutter attach`，不创建重复的 `flutter run`。

## 前置检查

1. 确认当前目录存在 `pubspec.yaml` 与本 skill 的 `scripts/windows_runner.ps1`、`scripts/android_runner.ps1`。
2. 加载并遵循全局 `orca-cli` skill；解析本会话应使用的 Orca CLI，运行 `orca status --json`。
3. 运行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
```

该命令可能因任一端未启动而返回非零；分别读取输出，不把“另一端未启动”误判为已运行端失效。

用户要求立即启动会话时，完成上述检查后直接创建或复用目标 Runner，不得先运行测试、Analyze 或 `build_runner`。若 Runner 预检明确报告生成文件缺失/过期，再将完整 `dart run build_runner build --delete-conflicting-outputs` 作为一次性环境准备：先说明全仓库扫描的预计耗时，确认两个 Flutter 会话均已停止，让生成命令完整结束后立即重启目标 Runner。不得把全量生成称为最小验证，不得因等待期间切换任务而反复中断重跑；命令中断时检查并恢复被删除但未重新生成的已有输出。

## 创建或复用终端

先运行 `orca terminal list --worktree active --json`。有效会话标记与对应进程是会话存在的权威依据；标题和输出标记仅用于兼容旧会话。

缺少 Windows 会话时创建：

```text
orca terminal create --worktree active --title "PC热重载" --command "pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-dev-sessions/scripts/windows_runner.ps1" --json
```

缺少 Android 会话时创建：

```text
orca terminal create --worktree active --title "安卓热重载" --command "pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-dev-sessions/scripts/android_runner.ps1 -EmulatorId Aaalice_API35" --json
```

规则：

- Android 项目会话必须使用 `-EmulatorId Aaalice_API35`，不要使用 `-DeviceId emulator-5554`；后者只复用外部模拟器，会绕过项目的 GPU 和无设备外框启动参数。
- 两个 runner 默认都复用现有依赖与生成文件，不运行 `pub get` / `build_runner`。纯 Dart/UI 改动及针对性测试不得预先运行生成器；依赖变化时显式传 `-RunPubGet`，Freezed/Riverpod 等生成源变化或 Runner 预检明确阻塞时才单独完成 `-RunBuildRunner`，不得与另一端 Flutter 构建并发。
- Windows Runner 会把当前进程中已设置的 Google Drive / OneDrive Windows OAuth 环境变量作为 `--dart-define` 注入；OneDrive 本地注册也可通过 `-OneDriveClientId`、`-OneDriveRedirectUri`、`-OneDriveTenantId` 显式传入。不要把 access token、refresh token 或 client secret 传给 Runner。
- 在 Orca 中直接创建项目终端；所有项目专用 runner/helper 都位于 `.pi/skills/`，不依赖仓库 `scripts/` 下的热重载入口。
- 创建后轮询 `orca terminal read --terminal <handle> --json`。Windows 等待 `Starting Flutter in Windows debug mode`，Android 等待 `Starting Flutter in Android debug mode` 且应用启动完成。出现构建错误立即报告，不盲等。
- Android runner 首次启动 emulator 时禁用 Quick Boot 快照、使用 host GPU、移除设备外框并等待系统完成启动；默认保留运行中的 emulator 作为下次会话的暖缓存。复用前会停止旧 App 并回到 Home，不会把旧界面当作本次启动结果。只有显式传 `-StopEmulatorOnExit` 才让 emulator 随会话关闭。

## 查看状态和日志

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Logs -Target All -Last 200
```

需要精确的新日志时，优先用会话标记中的 `terminalHandle` 配合 Orca cursor 增量读取，而不是只看整段历史 tail。

## 停止或重建

1. 用 `orca terminal read` 确认目标是对应的 Flutter runner。
2. 用 `orca terminal send --terminal <handle> --text q --json` 发送 `q`。
3. 等待终端命令退出；默认保留项目 emulator 作为下次启动缓存，显式使用 `-StopEmulatorOnExit` 的会话才由生命周期监视器关闭它。
4. 只有正常退出失败时才报告并请求处理，不直接杀掉用户预先存在的 emulator 或物理设备。
5. 重新创建时仍使用上面的固定标题与命令；运行中的 `Aaalice_API35` 会直接复用。
