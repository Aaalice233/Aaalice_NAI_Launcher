# Repository Guidelines

## 项目结构与模块组织

这是 NovelAI 的 Flutter 桌面客户端。主应用按 `core`、`data`、`presentation` 分层，平台工程、资源、测试和工具各自独立；新增代码应放入现有职责最接近的目录，不在仓库根目录堆放临时实现。

```text
Aaalice_NAI_Launcher/
├── lib/
│   ├── core/               # 网络、存储、数据库、缓存、通用服务与基础能力
│   ├── data/               # API 数据源、业务模型、仓库与领域服务
│   ├── presentation/       # 页面、组件、Riverpod providers、主题与路由
│   └── l10n/               # ARB 源文案及 Flutter 生成的本地化代码
├── assets/                 # 图片、翻译、数据文件与随包 SQLite 数据库
├── fonts/                  # 应用字体
├── test/                   # 与 lib 分层对应的单元测试和 widget tests
├── scripts/                # 构建、打包、发布、开发会话与诊断入口脚本
├── tool/                   # 数据构建、验证、迁移与一次性开发工具
├── krita_plugin/           # Krita 桥接与插件代码
├── windows/                # Windows Runner 与原生工程
├── macos/                  # macOS Runner 与原生工程
├── android/                # Android 平台工程（尚未正式发布）
├── installer/              # Windows 安装器配置
├── .github/workflows/      # PR 验证与 Release CI
├── l10n.yaml               # Flutter 国际化生成配置
└── pubspec.yaml            # Dart/Flutter 依赖、版本与 assets 声明
```

`tool/.tmp/` 只存放可删除的本地临时产物，不得提交。移动或新增 assets 后同步检查 `pubspec.yaml`；修改 ARB 后保持中/英/日文案键一致并重新生成本地化代码。

## 构建、测试与开发命令

项目使用 Flutter `>=3.35.0`、Dart `>=3.10.7`，当前 CI 固定 Flutter `3.44.2`。拉取仓库后必须安装 Git LFS，并获取 `assets/databases/*.db`。Windows 构建还需要 Visual Studio 2022 的 Desktop development with C++、已加入 `PATH` 的 NuGet CLI；macOS 构建需要完整 Xcode 与 CocoaPods。

```powershell
git lfs install
git lfs pull --include="assets/databases/*.db"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter test
flutter analyze
flutter build windows --release
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_nuget.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/dev_hot_reload_window.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/dev_hot_reload.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/trigger_hot_reload.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/trigger_hot_restart.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/capture_dev_window.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/read_flutter_console.ps1 -Last 200
```

Windows release 产物位于 `build/windows/x64/runner/Release/`。macOS 使用 `flutter build macos --release`，产物位于 `build/macos/Build/Products/Release/Aaalice NAI Launcher.app`；本地 Keychain 反复授权时使用 `scripts/create_macos_dev_cert.sh` 与 `scripts/dev_run_macos_signed.sh debug`。

Windows 桌面开发优先使用 `scripts/dev_hot_reload_window.ps1`，它会打开独立 PowerShell 窗口并调用 `scripts/dev_hot_reload.ps1`。后者会先运行 `build_runner`，再进入 `flutter run -d windows`，之后可在该窗口按 `r` 热重载、`R` 热重启、`q` 退出。已有该开发会话时，不启动第二个 `flutter attach`，而是在代码修改并完成最小验证后按以下规则自动触发：

- 普通热重载（`r`）：运行 `scripts/trigger_hot_reload.ps1`。它会保留当前页面、输入内容和现有 `State`，适用于只修改方法实现、Widget 布局、样式、文案等不改变状态初始化的代码。
- 热重启（`R`）：运行 `scripts/trigger_hot_restart.ps1`。它会重建 Dart 应用状态并重新执行 `main`、`initState` 和各类初始化器，适用于新增、删除或改变 `State` 字段，修改 `initState`、Provider/依赖注入初始化、全局变量、静态缓存、启动流程或生成代码。遇到“代码已更新但旧状态仍生效”、新增字段出现 `LateInitializationError` 等情况，必须使用热重启，不能继续只发普通热重载。
- 原生 Windows/C++、插件注册或依赖构建发生变化时，两者都不够，需要停止现有会话并重新运行开发启动脚本。

桌面 UI 改动可用 `scripts/capture_dev_window.ps1` 截取实际 Debug 窗口，默认输出到 `tool/.tmp/nai_launcher_window.png`；截图验证完需删除临时图片。Flutter 控制台可用 `scripts/read_flutter_console.ps1 -Last 200` 读取，也可通过 `-Pattern`、`-Context` 过滤。依赖变更后运行 `flutter pub get`。新增或修改 Riverpod providers、Freezed models、JSON models、Hive adapters 或生成路由后运行 `build_runner`。

## 代码风格与命名约定

遵循 `analysis_options.yaml` 和 Dart 默认格式化规则，使用两个空格缩进。变量和方法使用 `lowerCamelCase`，类型使用 `UpperCamelCase`。Riverpod provider 命名应以 `Provider` 或 `NotifierProvider` 结尾。新增功能优先复用现有 service、provider、widget 和 utility，保持 `core`、`data`、`presentation` 的职责边界清晰。

## 测试规范

测试使用 `flutter_test`，需要 mock 时使用 `mocktail`。测试文件以 `_test.dart` 结尾，并放在对应功能路径下，例如 `test/core/utils/`、`test/data/services/`、`test/presentation/providers/`。UI 行为变更尽量补 widget test；状态管理、请求构造、文件处理等逻辑变更应补 provider 或 service 回归测试。

## 资源、生成文件与发布注意事项

`assets/databases/*.db` 通过 Git LFS 管理，发布前应确认本地文件是真实 SQLite 数据库而不是 LFS pointer。`assets/translations/`、`assets/data/` 和 `assets/images/` 会随 Flutter assets 打包，移动或重命名后需要同步检查 `pubspec.yaml`。发布前确认 `CHANGELOG.md`、`dist/release_notes_<tag>.md`、`pubspec.yaml` 版本号和 Windows release build。

## Changelog 与 Release Notes 规范

`CHANGELOG.md` 是 GitHub Release notes 的“更新内容”来源。日常开发和普通代码修改不要逐次更新 Changelog；只在准备发布新版本时统一重写目标版本段落。

发布前必须在代码全部提交后运行 `scripts/prepare_changelog_review.ps1`。脚本默认对比上一个可达的 `v*` tag 与当前 `HEAD`，并在 `tool/.tmp/changelog-review/` 生成提交/文件审查报告和完整 diff。必须同时阅读两份材料、按变更文件反向核对，不能只根据 commit 标题总结，然后把本版本全部用户可见变化整理进对应版本段落，例如 `## [1.0.0] - YYYY-MM-DD`。

更新日志的差异审查、归类、撰写和完整性复核必须由当前主 Agent 亲自完成，禁止启动或委派任何子代理；这属于发布流程中的单一职责任务，不得为了并行分析而拆分。

Changelog 条目应面向用户描述结果，不要只写内部实现名。常用分类为 `### ✨ 新增`、`### 🛠 改进`、`### 🐛 修复`，必要时才增加 `### ⚠️ 注意`。同一新功能开发期间的内部修复应合并描述最终结果，不要暴露用户从未使用过的中间损坏状态。不要在 `CHANGELOG.md` 中写发布文件列表；安装版、便携版、macOS 包说明由 `scripts/generate_release_metadata.ps1` 自动生成，避免 Release notes 重复。

准备发布时需要检查：

- 当前版本段落是否覆盖登录、更新、生成、画廊、词库、设置、启动、安装包等用户实际能感知到的变化。
- bug 修复是否写成用户看到的问题和结果，例如“修复 Token 登录后无法获取会员状态”，而不是只写接口名或类名。
- 新功能开发期间顺手修掉的问题，如果用户从未用过损坏版本，可以合并进新功能描述，不必拆成多条。
- `CHANGELOG.md` 中不要重复自动生成的下载文件表；Release 页面会自动附带文件说明、校验文件和更新内容。

## 发布流程

1. 切换到 `main`，拉取最新代码，确认所有待发布修改均已提交且工作区干净。
2. 更新 `pubspec.yaml` 版本号；tag 必须等于去掉 `+build` 后的版本，如 `1.0.0+17` 对应 `v1.0.0`。
3. 运行 `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/prepare_changelog_review.ps1`，根据报告与完整 diff 重写版本日志并提交。
4. 运行 `dart run tool/tag_catalog/verify_bundled_databases.dart`，确认 LFS 数据库是真实 SQLite 文件；按风险运行测试、分析和 release build。
5. 创建并推送 `v*` tag。GitHub Actions `Release` workflow 会构建 Windows Setup、Windows Portable 与 macOS Portable，并生成 `release_manifest.json`、`checksums.txt` 和 Release notes。
6. Windows 本地打包使用 `scripts/package_windows_release.ps1`；签名使用 `scripts/sign_windows_binary.ps1`。CI secrets 为 `WINDOWS_SIGNING_CERT_BASE64` 与 `WINDOWS_SIGNING_CERT_PASSWORD`。

## README 双语同步规范

`README.md`（简体中文）与 `README.en-US.md`（English）只面向最终用户，保留产品简介、功能、界面、平台、下载安装、隐私、支持和致谢；构建命令、项目结构、开发约定、发布流程等维护者内容统一写在 `AGENTS.md`，不要再放回 README。

两份 README 内容必须保持同步：任一用户可见功能、平台支持、安装方式或隐私说明变化时，在同一提交中同时更新。两份文件顶部均保留语言切换链接；英文版只翻译中文版事实，不自行增删承诺。

## 提交与 Pull Request 规范

Git 历史使用 Conventional Commits，例如 `fix(generation): cancel stale results`、`feat(prompt): add random mode`。提交应保持范围清晰、标题简洁。Pull Request 需要说明用户可见变化，列出已运行的验证命令，标注生成文件、LFS 资源或 assets 变更；涉及界面变化时附截图。

## 安全与配置

不要提交 NovelAI API token、账号数据、本地日志、构建产物或个人工作流文件。调试认证逻辑时避免打印完整 bearer token；如需日志，只记录 token 类型、长度或脱敏前缀。
