---
name: aaalice-dev-sessions
description: 管理 Aaalice NAI Launcher 项目专用的 Windows 与 Android Flutter 开发会话。用户提到 PC热重载、安卓热重载、启动/关闭/重建独立命令行窗口、模拟器启动异常或检查双端会话时使用。
---

# Aaalice 双端开发会话

运行环境需要 Windows、PowerShell 7、Flutter 与 Android SDK。会话由 Codex 启动的独立 PowerShell 窗口承载，不使用外部终端编排器、`flutter attach` 或新的 Codex task。

只管理当前 Aaalice NAI Launcher worktree；每个平台最多保留一个 `flutter run`。用户要求自动化验收时，启动或复用所需会话属于已授权的准备步骤，无需另问是否启动；就绪后继续由 [aaalice-runtime-verify](../aaalice-runtime-verify/SKILL.md) 操作和检查界面，不能停在“窗口已打开”。

## 前置检查

1. 确认当前目录存在 `pubspec.yaml` 与本 skill 的 `scripts/start.ps1`、`scripts/windows_runner.ps1`、`scripts/android_runner.ps1`。
2. 确认 Flutter/Dart 可执行文件与 Android SDK 路径。当前进程 PATH 缺少工具时，先核对项目 `android/local.properties` 或已配置的 SDK 路径，再仅为启动进程设置 PATH 或 `FLUTTER_CMD`/`DART_CMD`；不猜路径、不修改用户/系统环境。
3. 运行状态检查；命令可能因任一端未启动而返回非零，应分别读取两端结果：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
```

用户要求立即启动会话时，检查后直接创建或复用目标 Runner，不得先运行测试、Analyze 或 `build_runner`。若 Runner 预检明确报告生成文件缺失/过期，再将完整 `dart run build_runner build --delete-conflicting-outputs` 作为一次性环境准备：先说明预计耗时，确认两个 Flutter 会话均已停止，让命令完整结束后立即重启目标 Runner。生成命令中断时检查并恢复被删除但未重新生成的已有输出。

## 创建或复用独立窗口

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-dev-sessions/scripts/start.ps1 -Target Windows
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-dev-sessions/scripts/start.ps1 -Target Android -EmulatorId Aaalice_API35
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-dev-sessions/scripts/start.ps1 -Target All -EmulatorId Aaalice_API35
```

`start.ps1` 先查找当前 worktree 对应的 Runner 进程，只为缺失目标创建可见的独立 PowerShell 窗口。创建后轮询 `Status` 与 `Logs`：Windows 需看到原生构建成功/启动标记且存在真实 `nai_launcher` 进程；Android 需看到应用启动完成且目标设备上存在包进程。仅有窗口、marker 或 PID 不代表启动成功。

两个 Runner 均传入 `--print-dtd` 和 `--dart-define=ENABLE_FLUTTER_DRIVER=true`，供[项目级 MCP](../../../docs/mcp_debugging.md) 发现并操作现有应用。连接 MCP 时复用这些会话，不通过 `launch_app` 另开第二个应用。

规则：

- Android 项目会话必须使用基于 `system-images;android-35;google_apis_playstore;x86_64` 的 `-EmulatorId Aaalice_API35`，确保 Google Drive 登录所需的 Google Play Services 可用；Runner 在冷启动前会启用 AVD 的 host hardware keyboard，确保物理键盘输入可用。不要把临时的 `emulator-5554` 写成固定 `-DeviceId`；`-DeviceId` 只用于明确复用外部设备。
- Runner 默认复用依赖与生成文件，不额外执行独立的 `pub get` / `build_runner` 准备阶段；`flutter run` 自身仍可能解析依赖。依赖变化时使用 `-RunPubGet`；Freezed/Riverpod 等生成输入变化或预检阻塞时才使用 `-RunBuildRunner`。生成步骤不得与另一端 Flutter 构建并发。
- Windows 与 Android Runner 按 Process → User → Machine 的优先级读取各自平台的 Google Drive / OneDrive OAuth 环境变量并作为 `--dart-define` 注入，因此持久化到当前用户的开发配置无需重启 Codex；Windows OneDrive 本地注册也可通过 `-OneDriveClientId`、`-OneDriveRedirectUri`、`-OneDriveTenantId` 显式覆盖。OAuth 参数以 [cloud_drive_oauth.md](../../../docs/cloud_drive_oauth.md) 和平台配置为准：Google Windows Desktop 使用已配置的 client secret；OneDrive 与移动 public client 不额外创建 secret。access token 或 refresh token 绝不能作为 Runner 参数或 dart-define。
- Android runner 首次启动 emulator 时禁用 Quick Boot 快照、使用 host GPU、移除设备外框并等待系统完成启动；默认保留 emulator 作为暖缓存。只有显式传 `-StopEmulatorOnExit` 才随会话关闭。

## 状态、日志与关闭

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Logs -Target All -Last 200
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Stop -Target All
```

`Logs` 直接读取项目独立窗口的控制台缓冲区；`Stop` 向已验证的 Runner 控制台发送 `q` 并等待正常退出。正常退出失败时保留原始错误，不直接终止用户预先存在的 emulator 或物理设备。重建时先 `Stop` 受影响目标，再用 `start.ps1` 创建新窗口。
