# NAI Launcher

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher Logo" width="120">
</p>

<p align="center">
  <strong>面向 NovelAI 图像生成的第三方桌面客户端</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases"><img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version"></a>
  <img src="https://img.shields.io/badge/Flutter-3.44.2-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS-lightgrey" alt="Platforms">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-加入服务器-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

NAI Launcher 是一个使用 Flutter 构建的 NovelAI 第三方客户端。它把图像生成、图生图、局部重绘、Vibe / Precise Reference、本地图库、在线图库、生成队列、Krita 联动和统计工具整合在一个桌面应用里，适合日常生成、批量出图和长期管理本地作品。

> 本项目不是 NovelAI 官方产品。使用前请确保你拥有自己的 NovelAI 账号，并遵守 NovelAI 的服务条款。

## ✨ 功能概览

| 能力 | 说明 |
| --- | --- |
| 🎨 图像生成 | 支持 NovelAI Diffusion V1/V2/V3/V4/V4.5、Furry 系列、常用采样器、尺寸预设、多角色参数和 Anlas 估算。 |
| 🖼️ 图生图与编辑 | 支持图生图、局部重绘、Focused Inpaint、Outpaint、虚拟画布扩图、硬边蒙版和点击式区域填充。 |
| 🌈 参考与风格 | 支持 Vibe Transfer、Precise Reference、多图参考、Vibe 整包导入导出、PNG 元数据嵌入导出。 |
| ✍️ Prompt 工具 | 支持 Danbooru 标签补全、中文搜索、NAI/SD 权重语法辅助、Token 统计、提示词框内搜索和固定词。 |
| 📚 本地图库 | 支持递归扫描、SQLite 全文搜索、分类/收藏/集合、元数据解析、批量操作和大图预览。 |
| 🌐 在线图库 | 支持 Danbooru / Safebooru / Gelbooru 浏览、搜索、标签复制、图片发送到生成页和批量下载。 |
| 📦 生成队列 | 支持任务排序、批量生成、暂停/继续、失败策略、进度统计和队列导入导出。 |
| 🔌 外部联动 | 支持 Krita 本地联动、ComfyUI 本地工作流、系统代理、跨平台图片复制和文件定位。 |

## 🖥️ 界面预览

<p align="center">
  <img src="assets/images/1.png" alt="图像生成界面" width="80%">
  <br>
  <em>图像生成主界面</em>
</p>

<p align="center">
  <img src="assets/images/2.png" alt="本地画廊" width="80%">
  <br>
  <em>本地画廊与瀑布流浏览</em>
</p>

<p align="center">
  <img src="assets/images/4.png" alt="图片详情" width="80%">
  <br>
  <em>图片详情、元数据和参数复用</em>
</p>

<p align="center">
  <img src="assets/images/5.png" alt="Danbooru 在线画廊" width="80%">
  <br>
  <em>Danbooru 在线画廊</em>
</p>

<p align="center">
  <img src="assets/images/7.png" alt="统计仪表盘" width="80%">
  <br>
  <em>统计仪表盘</em>
</p>

## 🧩 平台支持

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Windows | 可用 | 主要开发和发布平台，支持系统托盘、窗口状态保存、视频播放、剪贴板和文件定位。 |
| macOS | 最小适配 | 支持构建、启动、登录、本地数据库、视频播放、Keychain、系统代理、图片复制和文件定位；系统托盘后续再补。 |
| Linux | 未发布 | 部分桌面代码已有分支，但当前不提供正式包。 |
| Android | 计划中 | 仍处于后续适配阶段。 |

## 📦 下载与安装

前往 [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases) 下载最新版本。

| 平台 | 下载文件 | 使用方式 |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | 安装版，推荐普通用户，安装到当前用户目录，支持应用内一键更新。 |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | 便携版，解压后运行 `nai_launcher.exe`，只检测更新并跳转 Release 页面。 |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | 便携版，解压后打开 `Aaalice NAI Launcher.app`。未公证版本如被拦截，可在系统设置的隐私与安全中允许打开。 |

首次登录可以使用 NovelAI 账号密码或 API Token。账号数据仅保存在本地设备，桌面端使用系统安全存储保存敏感信息。

## 🛠️ 从源码构建

### 环境要求

- Flutter `3.44.2`（项目最低要求 Flutter `3.35.0` / Dart `3.10.7`）
- Git LFS，用于拉取 `assets/databases/*.db`
- Windows 构建：Visual Studio 2022 Desktop development with C++
- Windows 构建：[NuGet CLI](https://learn.microsoft.com/nuget/install-nuget-client-tools)，`nuget.exe` 所在目录必须加入 `PATH`
- macOS 构建：完整 Xcode、CocoaPods、Git LFS

### 通用步骤

```bash
git clone https://github.com/Aaalice233/Aaalice_NAI_Launcher.git
cd Aaalice_NAI_Launcher

git lfs install
git lfs pull --include="assets/databases/*.db"

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

### Windows

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_nuget.ps1
flutter build windows --release
```

`flutter_inappwebview` 的 Windows 实现会在编译阶段通过 NuGet 获取 WebView2 SDK 等原生依赖。`verify_nuget.ps1` 检查失败时，请先安装 NuGet CLI，并确认新 PowerShell 窗口中可以直接运行 `nuget help`。

产物目录：

```text
build/windows/x64/runner/Release/
```

### macOS

```bash
flutter build macos --release
```

产物路径：

```text
build/macos/Build/Products/Release/Aaalice NAI Launcher.app
```

本地开发时如果 Keychain 反复弹授权，可以先创建稳定的本地签名证书，再运行签名启动脚本：

```bash
scripts/create_macos_dev_cert.sh
scripts/dev_run_macos_signed.sh debug
```

## 🚀 发布流程

发布由 GitHub Actions 的 `Release` workflow 处理。推送 `v*` tag 后，工作流会分别构建 Windows 安装版、Windows 便携版和 macOS 便携版，并生成 `release_manifest.json`、`checksums.txt` 与 Release notes。

```bash
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

发布前请确保：

- `pubspec.yaml` 版本号已更新；tag 必须匹配去掉 `+build` 后的版本，例如 `1.0.0+17` 对应 `v1.0.0`。
- `CHANGELOG.md` 已按 `✨ 新增`、`🛠 改进`、`🐛 修复`、`📦 发布文件` 分类补好。
- `assets/databases/translation.db` 与 `assets/databases/cooccurrence.db` 是真实 SQLite 文件，不是 Git LFS pointer。
- Windows 安装器依赖 NSIS；本地打包可运行 `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/package_windows_release.ps1`。

## 🗂️ 项目结构

```text
nai_launcher/
├── assets/                 # 图标、截图、音效、标签数据、预置数据库
├── installer/              # 安装器脚本
├── krita_plugin/           # Krita 插件与打包/验收脚本
├── lib/
│   ├── core/               # 网络、数据库、缓存、加密、文件、快捷键等基础能力
│   ├── data/               # API、模型、仓库和业务数据服务
│   ├── l10n/               # 中英文界面文案与生成文件
│   └── presentation/       # 页面、组件、状态管理、主题和路由
├── macos/                  # macOS runner
├── scripts/                # 构建、签名、数据库和测试辅助脚本
├── test/                   # 单元测试和组件测试
├── tool/                   # 开发工具、数据处理、图标生成和诊断脚本
└── windows/                # Windows runner
```

## 💻 开发约定

常用命令：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
```

提交信息使用：

```text
type(scope): 中文描述
```

常用 type：`feat`、`fix`、`refactor`、`perf`、`style`、`docs`、`test`、`chore`。

## 🤝 贡献

欢迎通过 Issue 和 Pull Request 参与。提交 PR 前请说明变更目标、影响范围、验证方式；涉及 UI 或跨平台行为时，尽量附上截图或录屏。

## 🙏 致谢

- [NovelAI](https://novelai.net/) 提供图像生成服务。
- [Flutter](https://flutter.dev/) 提供跨平台 UI 能力。
- [Riverpod](https://riverpod.dev/) 提供状态管理能力。
- 感谢所有贡献者和测试用户。

## 📄 许可证

本项目基于 MIT License 开源，详见 [LICENSE](LICENSE)。
