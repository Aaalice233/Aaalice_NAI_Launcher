# Repository Guidelines

## 项目结构与模块组织

这是 NovelAI 的 Flutter 桌面客户端。主应用代码位于 `lib/`，主要按 `core/`、`data/`、`presentation/` 分层。国际化配置在 `l10n.yaml`，源 ARB 文件位于 `lib/l10n/`。静态资源放在 `assets/`，字体放在 `fonts/`，Windows、macOS、Android 平台工程分别在 `windows/`、`macos/`、`android/`。Krita 桥接和插件代码位于 `krita_plugin/`。测试代码放在 `test/`，开发和诊断脚本放在 `tool/` 与 `scripts/`。

## 构建、测试与开发命令

项目使用 Flutter `>=3.35.0` 和 Dart `>=3.10.7`。请确保本地 `flutter` 和 `dart` 命令可用，并与版本要求兼容。

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/dev_hot_reload_window.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/dev_hot_reload.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/trigger_hot_reload.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/trigger_hot_restart.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/capture_dev_window.ps1
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter test
flutter analyze
flutter build windows --release
```

Windows 桌面开发优先使用 `scripts/dev_hot_reload_window.ps1`，它会打开独立 PowerShell 窗口并调用 `scripts/dev_hot_reload.ps1`。后者会先运行 `build_runner`，再进入 `flutter run -d windows`，之后可在该窗口按 `r` 热重载、`R` 热重启、`q` 退出。已有该开发会话时，不启动第二个 `flutter attach`，而是在代码修改并完成最小验证后按以下规则自动触发：

- 普通热重载（`r`）：运行 `scripts/trigger_hot_reload.ps1`。它会保留当前页面、输入内容和现有 `State`，适用于只修改方法实现、Widget 布局、样式、文案等不改变状态初始化的代码。
- 热重启（`R`）：运行 `scripts/trigger_hot_restart.ps1`。它会重建 Dart 应用状态并重新执行 `main`、`initState` 和各类初始化器，适用于新增、删除或改变 `State` 字段，修改 `initState`、Provider/依赖注入初始化、全局变量、静态缓存、启动流程或生成代码。遇到“代码已更新但旧状态仍生效”、新增字段出现 `LateInitializationError` 等情况，必须使用热重启，不能继续只发普通热重载。
- 原生 Windows/C++、插件注册或依赖构建发生变化时，两者都不够，需要停止现有会话并重新运行开发启动脚本。

桌面 UI 改动可用 `scripts/capture_dev_window.ps1` 截取实际 Debug 窗口，默认输出到 `tool/.tmp/nai_launcher_window.png`；截图验证完需删除临时图片。依赖变更后运行 `flutter pub get`。新增或修改 Riverpod providers、Freezed models、JSON models、Hive adapters 或生成路由后运行 `build_runner`。

## 代码风格与命名约定

遵循 `analysis_options.yaml` 和 Dart 默认格式化规则，使用两个空格缩进。变量和方法使用 `lowerCamelCase`，类型使用 `UpperCamelCase`。Riverpod provider 命名应以 `Provider` 或 `NotifierProvider` 结尾。新增功能优先复用现有 service、provider、widget 和 utility，保持 `core`、`data`、`presentation` 的职责边界清晰。

## 测试规范

测试使用 `flutter_test`，需要 mock 时使用 `mocktail`。测试文件以 `_test.dart` 结尾，并放在对应功能路径下，例如 `test/core/utils/`、`test/data/services/`、`test/presentation/providers/`。UI 行为变更尽量补 widget test；状态管理、请求构造、文件处理等逻辑变更应补 provider 或 service 回归测试。

## 资源、生成文件与发布注意事项

`assets/databases/*.db` 通过 Git LFS 管理，发布前应确认本地文件是真实 SQLite 数据库而不是 LFS pointer。`assets/translations/`、`assets/data/` 和 `assets/images/` 会随 Flutter assets 打包，移动或重命名后需要同步检查 `pubspec.yaml`。发布前确认 `CHANGELOG.md`、`dist/release_notes_<tag>.md`、`pubspec.yaml` 版本号和 Windows release build。

## Changelog 与 Release Notes 规范

`CHANGELOG.md` 是 GitHub Release notes 的“更新内容”来源；Release workflow 不会自动根据 git commit 生成变更摘要。准备发布前必须对比上一个 tag 到当前 HEAD 的提交，把本版本用户可见变化整理进对应版本段落，例如 `## [1.0.0] - YYYY-MM-DD`。

Changelog 条目应面向用户描述结果，不要只写内部实现名。常用分类为 `### ✨ 新增`、`### 🛠 改进`、`### 🐛 修复`，必要时才增加 `### ⚠️ 注意`。不要在 `CHANGELOG.md` 中写发布文件列表；安装版、便携版、macOS 包说明由 `scripts/generate_release_metadata.ps1` 自动生成，避免 Release notes 重复。

准备发布时需要检查：

- 当前版本段落是否覆盖登录、更新、生成、设置、启动、安装包等用户实际能感知到的变化。
- bug 修复是否写成用户看到的问题和结果，例如“修复 Token 登录后无法获取会员状态”，而不是只写接口名或类名。
- 新功能开发期间顺手修掉的问题，如果用户从未用过损坏版本，可以合并进新功能描述，不必拆成多条。
- `CHANGELOG.md` 中不要重复自动生成的下载文件表；Release 页面会自动附带文件说明、校验文件和更新内容。

## README 双语同步规范

`README.md`（简体中文）与 `README.en-US.md`（English）内容必须保持同步：新增功能、平台支持、构建步骤、发布流程、项目结构等任一变化涉及 README 时，两份文件在同一提交中一起更新，不允许只改一份。两份文件顶部均保留指向对方的语言切换链接。仓库约定（如提交消息格式）以中文版表述为准，英文版只做翻译说明，不得改写约定本身。

## 提交与 Pull Request 规范

Git 历史使用 Conventional Commits，例如 `fix(generation): cancel stale results`、`feat(prompt): add random mode`。提交应保持范围清晰、标题简洁。Pull Request 需要说明用户可见变化，列出已运行的验证命令，标注生成文件、LFS 资源或 assets 变更；涉及界面变化时附截图。

## 安全与配置

不要提交 NovelAI API token、账号数据、本地日志、构建产物或个人工作流文件。调试认证逻辑时避免打印完整 bearer token；如需日志，只记录 token 类型、长度或脱敏前缀。
