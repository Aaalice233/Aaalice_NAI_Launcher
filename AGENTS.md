# Repository Guidelines

## 项目结构与模块组织

这是 NovelAI 的 Flutter 桌面客户端。主应用代码位于 `lib/`，主要按 `core/`、`data/`、`presentation/` 分层。国际化配置在 `l10n.yaml`，源 ARB 文件位于 `lib/l10n/`。静态资源放在 `assets/`，字体放在 `fonts/`，Windows、macOS、Android 平台工程分别在 `windows/`、`macos/`、`android/`。Krita 桥接和插件代码位于 `krita_plugin/`。测试代码放在 `test/`，开发和诊断脚本放在 `tool/` 与 `scripts/`。

## 构建、测试与开发命令

项目使用 Flutter `>=3.35.0` 和 Dart `>=3.10.7`。请确保本地 `flutter` 和 `dart` 命令可用，并与版本要求兼容。

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter test
flutter analyze
flutter build windows --release
```

依赖变更后运行 `flutter pub get`。新增或修改 Riverpod providers、Freezed models、JSON models、Hive adapters 或生成路由后运行 `build_runner`。Windows 桌面调试使用 `flutter run -d windows`。

## 代码风格与命名约定

遵循 `analysis_options.yaml` 和 Dart 默认格式化规则，使用两个空格缩进。变量和方法使用 `lowerCamelCase`，类型使用 `UpperCamelCase`。Riverpod provider 命名应以 `Provider` 或 `NotifierProvider` 结尾。新增功能优先复用现有 service、provider、widget 和 utility，保持 `core`、`data`、`presentation` 的职责边界清晰。

## 测试规范

测试使用 `flutter_test`，需要 mock 时使用 `mocktail`。测试文件以 `_test.dart` 结尾，并放在对应功能路径下，例如 `test/core/utils/`、`test/data/services/`、`test/presentation/providers/`。UI 行为变更尽量补 widget test；状态管理、请求构造、文件处理等逻辑变更应补 provider 或 service 回归测试。

## 资源、生成文件与发布注意事项

`assets/databases/*.db` 通过 Git LFS 管理，发布前应确认本地文件是真实 SQLite 数据库而不是 LFS pointer。`assets/translations/`、`assets/data/` 和 `assets/images/` 会随 Flutter assets 打包，移动或重命名后需要同步检查 `pubspec.yaml`。发布前确认 `CHANGELOG.md`、`dist/release_notes_<tag>.md`、`pubspec.yaml` 版本号和 Windows release build。

## 提交与 Pull Request 规范

Git 历史使用 Conventional Commits，例如 `fix(generation): cancel stale results`、`feat(prompt): add random mode`。提交应保持范围清晰、标题简洁。Pull Request 需要说明用户可见变化，列出已运行的验证命令，标注生成文件、LFS 资源或 assets 变更；涉及界面变化时附截图。

## 安全与配置

不要提交 NovelAI API token、账号数据、本地日志、构建产物或个人工作流文件。调试认证逻辑时避免打印完整 bearer token；如需日志，只记录 token 类型、长度或脱敏前缀。
