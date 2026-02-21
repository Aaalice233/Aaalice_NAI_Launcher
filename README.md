# NAI Launcher

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher Logo" width="120">
</p>

<p align="center">
  <strong>NovelAI 跨平台第三方客户端</strong>
</p>

<p align="center">
  <a href="#-功能特性">功能特性</a> •
  <a href="#-安装说明">安装说明</a> •
  <a href="#-使用方法">使用方法</a> •
  <a href="#-技术栈">技术栈</a> •
  <a href="#-项目结构">项目结构</a> •
  <a href="#-开发指南">开发指南</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0--beta3-blue" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/Flutter-3.16+-blue?logo=flutter" alt="Flutter">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-加入服务器-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

---

## 📋 目录

- [项目简介](#-项目简介)
- [功能特性](#-功能特性)
- [安装说明](#-安装说明)
  - [系统要求](#系统要求)
  - [下载安装](#下载安装)
  - [从源码构建](#从源码构建)
- [使用方法](#-使用方法)
  - [首次启动](#首次启动)
  - [图像生成](#图像生成)
  - [画廊管理](#画廊管理)
- [技术栈](#-技术栈)
- [项目结构](#-项目结构)
- [开发指南](#-开发指南)
  - [环境配置](#环境配置)
  - [构建运行](#构建运行)
  - [代码规范](#代码规范)
- [许可证](#-许可证)

---

## 🚀 项目简介

**NAI Launcher** 是一个专为 [NovelAI](https://novelai.net/) 设计的第三方客户端，使用 **Flutter** 构建，目前支持 **Windows** 平台，**Android** 版本正在计划中。

本项目旨在为 NovelAI 用户提供更加便捷、高效的图像生成体验，同时提供强大的本地画廊管理功能。

### 主要优势

- 🎨 **优雅的界面设计** - 现代化 UI，支持自定义主题
- 🖼️ **强大的图像生成** - 支持文生图、图生图、Vibe Transfer
- 📚 **智能画廊管理** - 本地数据库索引，快速搜索筛选
- 🔒 **隐私安全** - 本地存储，数据加密
- 🌐 **代理支持** - 内置系统代理和自定义代理支持

---

## ✨ 功能特性

### 核心功能

| 功能 | 描述 | 状态 |
|------|------|------|
| 🔐 安全登录 | 支持 NovelAI 账号密码登录，本地加密存储 | ✅ |
| 🎨 文生图 | 支持 Prompt 编辑、参数调整、多模型选择 | ✅ |
| 🖼️ 图生图 | 支持图片上传、强度调节、参考图生成 | ✅ |
| 🌈 Vibe Transfer | 风格迁移功能，保持图片风格一致性 | ✅ |
| 📂 画廊管理 | 本地图片库管理，支持标签、收藏、搜索 | ✅ |
| 🔍 智能搜索 | 基于 SQLite 的全文搜索和筛选 | ✅ |
| 💾 数据导出 | 支持 PNG 元数据导出、批量下载 | ✅ |
| 🌙 深色模式 | 支持浅色/深色主题切换 | ✅ |

### 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Windows | ✅ 可用 | 完整的桌面体验，支持窗口管理、系统托盘 |
| Android | 🚧 计划中 | 移动端适配开发中，敬请期待 |

### 高级特性

- 🎯 **Prompt 辅助** - 内置标签提示、Danbooru 标签支持
- 🎲 **随机种子** - 支持随机种子生成和固定
- 📊 **生成历史** - 查看历史生成记录，快速复用参数
- 🖱️ **拖拽支持** - 支持图片拖拽导入（桌面端）
- 🔊 **音效反馈** - 可选的生成完成音效提示

---

## 📦 安装说明

### 系统要求

| 平台 | 最低要求 |
|------|----------|
| Windows | Windows 10 版本 1809+ (64位) |

### 下载安装

#### Windows

1. 前往 [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases) 页面
2. 下载最新版本的 `NAI-Launcher-Windows.zip`
3. 解压到任意目录
4. 运行 `nai_launcher.exe`

### 从源码构建

#### 环境要求

- [Flutter SDK](https://flutter.dev/docs/get-started/install) >= 3.16.0
- [Dart SDK](https://dart.dev/get-dart) >= 3.2.0

#### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/Aaalice233/Aaalice_NAI_Launcher.git
cd Aaalice_NAI_Launcher

# 安装依赖
flutter pub get

# 生成代码（Freezed、Riverpod 等）
flutter pub run build_runner build --delete-conflicting-outputs

# 运行调试版本
flutter run

# 构建发布版本
# Windows
flutter build windows --release

```

---

## 🎯 使用方法

### 首次启动

1. 打开应用后，点击「登录」按钮
2. 输入你的 NovelAI 账号和密码
3. 选择是否启用代理（如需翻墙）
4. 完成登录后即可开始使用

### 图像生成

1. 在主界面输入 **Prompt**（提示词）
2. 调整生成参数：
   - **模型选择**: Anime Diffusion、Creative 等
   - **图片尺寸**: 自定义宽高
   - **采样步数**: 28-50 步
   - **CFG Scale**: 提示词相关性
   - **采样器**: Euler、DPM++ 等
3. 点击「生成」按钮
4. 等待生成完成后保存或继续生成

### 画廊管理

1. 点击底部「画廊」标签
2. 浏览本地保存的图片
3. 支持以下操作：
   - 🔍 **搜索**: 按标签、Prompt 搜索
   - 🏷️ **标签**: 添加自定义标签
   - ⭐ **收藏**: 标记喜欢的图片
   - 🗑️ **删除**: 移除不需要的图片
   - 📤 **分享**: 导出或分享图片

### 快捷键（桌面端）

| 快捷键 | 功能 |
|--------|------|
| `Ctrl + Enter` | 生成图片 |
| `Ctrl + S` | 保存当前图片 |
| `F1` | 打开快捷键帮助 |
| `Esc` | 关闭弹窗/返回 |

> 提示：按 `F1` 可在应用内查看完整的快捷键列表。

---

## 🛠️ 技术栈

### 核心框架

- **[Flutter](https://flutter.dev/)** - 跨平台 UI 框架
- **[Dart](https://dart.dev/)** - 编程语言

### 状态管理

- **[flutter_riverpod](https://riverpod.dev/)** - 响应式状态管理
- **[Riverpod Generator](https://riverpod.dev/docs/concepts/about_code_generation)** - 代码生成

### 网络请求

- **[Dio](https://github.com/cfug/dio)** - 强大的 HTTP 客户端
- **[dio_http2_adapter](https://github.com/cfug/dio/tree/main/plugins/http2_adapter)** - HTTP/2 支持

### 本地存储

- **[Hive](https://hivedb.dev/)** - 高性能键值存储
- **[sqflite_common_ffi](https://github.com/tekartik/sqflite/tree/master/sqflite_common_ffi)** - SQLite 数据库（桌面端）
- **[sqlite3_flutter_libs](https://github.com/simolus3/sqlite3.dart/tree/main/sqlite3_flutter_libs)** - SQLite 原生库
- **[flutter_secure_storage](https://github.com/mogol/flutter_secure_storage)** - 安全存储

### 图片处理

- **[image](https://pub.dev/packages/image)** - Dart 图片处理库
- **[cached_network_image](https://github.com/Baseflow/flutter_cached_network_image)** - 网络图片缓存

### 其他重要库

| 库 | 用途 |
|----|------|
| [go_router](https://pub.dev/packages/go_router) | 声明式路由 |
| [freezed](https://github.com/rrousselGit/freezed) | 不可变数据类 |
| [window_manager](https://github.com/leanflutter/window_manager) | 桌面窗口管理 |
| [super_drag_and_drop](https://github.com/superlistapp/super_native_extensions) | 拖拽功能 |
| [flex_color_scheme](https://github.com/rydmike/flex_color_scheme) | 主题配色 |
| [logger](https://github.com/SourceHorizon/logger) | 日志记录 |

---

## 📁 项目结构

```
nai_launcher/
├── android/                    # Android 平台配置
├── assets/                     # 静态资源
│   ├── data/                   # 数据文件
│   ├── databases/              # 预置数据库
│   ├── icons/                  # 应用图标
│   ├── images/                 # 图片资源
│   ├── sounds/                 # 音效文件
│   └── translations/           # 国际化文件
├── fonts/                      # 字体文件
├── lib/                        # 主代码目录
│   ├── core/                   # 核心模块
│   │   ├── cache/              # 缓存管理
│   │   ├── constants/          # 常量定义
│   │   ├── crypto/             # 加密相关
│   │   ├── database/           # 数据库管理
│   │   ├── enums/              # 枚举定义
│   │   ├── extensions/         # 扩展方法
│   │   ├── network/            # 网络层
│   │   ├── parsers/            # 数据解析
│   │   ├── services/           # 业务服务
│   │   ├── shortcuts/          # 快捷键管理
│   │   ├── storage/            # 存储管理
│   │   └── utils/              # 工具类
│   ├── data/                   # 数据层
│   │   ├── datasources/        # 数据源
│   │   ├── models/             # 数据模型
│   │   ├── repositories/       # 仓库实现
│   │   └── services/           # 数据服务
│   ├── l10n/                   # 国际化
│   ├── presentation/           # 展示层
│   │   ├── providers/          # Riverpod Providers
│   │   ├── screens/            # 页面
│   │   ├── themes/             # 主题配置
│   │   ├── utils/              # 展示层工具
│   │   ├── widgets/            # 组件
│   │   └── router/             # 路由配置
│   ├── utils/                  # 通用工具
│   ├── app.dart                # 应用根组件
│   └── main.dart               # 入口文件
├── scripts/                    # 构建脚本
├── test/                       # 测试代码
├── tool/                       # 工具脚本
├── tools/                      # 构建工具
├── windows/                    # Windows 平台配置
├── pubspec.yaml                # 依赖配置
└── README.md                   # 项目说明
```

### 架构模式

本项目采用 **Clean Architecture** 分层架构：

```
┌─────────────────────────────────────┐
│         Presentation Layer          │  ← UI、Providers、Screens
├─────────────────────────────────────┤
│           Domain Layer              │  ← Models、Repositories (抽象)
├─────────────────────────────────────┤
│            Data Layer               │  ← Repositories (实现)、Datasources
├─────────────────────────────────────┤
│            Core Layer               │  ← 通用工具、服务、常量
└─────────────────────────────────────┘
```

---

## 💻 开发指南

### 环境配置

1. **安装 Flutter**

   ```bash
   # 参考官方文档
   # https://flutter.dev/docs/get-started/install

   # 验证安装
   flutter doctor
   ```

2. **安装 IDE 插件**

   - **VS Code**: Flutter、Dart 插件
   - **Android Studio**: Flutter 插件

3. **克隆项目**

   ```bash
   git clone https://github.com/Aaalice233/Aaalice_NAI_Launcher.git
   cd Aaalice_NAI_Launcher
   ```

### 构建运行

```bash
# 获取依赖
flutter pub get

# 运行代码生成（必需）
flutter pub run build_runner build --delete-conflicting-outputs

# 开发模式运行
flutter run

# 运行测试
flutter test

# 代码分析
flutter analyze

# 格式化代码
dart format lib test
```

### 代码规范

- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范
- 使用 `flutter_lints` 进行静态分析
- 提交前运行 `dart format` 和 `flutter analyze`

### 提交规范

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type 类型：**

- `feat`: 新功能
- `fix`: 修复 Bug
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例：**

```
feat(gallery): 添加图片批量导出功能

- 支持选择多张图片导出
- 导出时保留 PNG 元数据
- 添加进度提示

Closes #123
```

### 参与贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

## 📄 许可证

本项目基于 MIT 许可证开源。

```
MIT License

Copyright (c) 2026 NAI Launcher Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 致谢

- [NovelAI](https://novelai.net/) - 提供强大的 AI 图像生成服务
- [Flutter](https://flutter.dev/) - 优秀的跨平台框架
- [Riverpod](https://riverpod.dev/) - 出色的状态管理方案
- 所有贡献者和用户

---

<p align="center">
  Made with ❤️ by NAI Launcher Team
</p>
