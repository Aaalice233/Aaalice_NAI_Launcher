# NAI Launcher

**NovelAI Universal Launcher** - 跨平台 NovelAI 第三方客户端

[![Flutter](https://img.shields.io/badge/Flutter-3.16+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.2+-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 功能特性 | Features

### 中文 | Chinese

- **纯客户端架构** - 无需后端服务，APK 安装即用
- **跨平台支持** - Windows、Android、Linux
- **图像生成** - 完整支持 NovelAI 图像生成 API
- **5 套精美主题** - Invoke Style、Discord、Linear、复古未来主义、寻呼机风格
- **响应式布局** - 桌面端三栏布局，移动端自适应
- **中英双语** - 内置国际化支持

### English

- **Pure Client Architecture** - No backend required, works out of the box
- **Cross-Platform Support** - Windows, Android, Linux
- **Image Generation** - Full support for NovelAI image generation API
- **5 Beautiful Themes** - Invoke Style, Discord, Linear, Cassette Futurism, Motorola Beeper
- **Responsive Layout** - Three-column desktop layout, mobile-responsive
- **Bilingual Support** - Built-in internationalization (Chinese & English)

---

## 截图预览 | Screenshots

*截图待添加 | Screenshots coming soon*

---

## 快速开始 | Quick Start

### 环境要求 | Requirements

#### 中文 | Chinese

- Flutter 3.16+
- Dart 3.2+
- Android SDK 23+ (Android)
- Visual Studio 2019+ (Windows)

#### English

- Flutter 3.16+
- Dart 3.2+
- Android SDK 23+ (Android)
- Visual Studio 2019+ (Windows)

### 安装步骤 | Installation

#### 中文 | Chinese

```bash
# 克隆项目
git clone https://github.com/your-username/nai-launcher.git
cd nai-launcher

# 获取依赖
flutter pub get

# 生成代码 (Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 运行项目
flutter run
```

#### English

```bash
# Clone the repository
git clone https://github.com/your-username/nai-launcher.git
cd nai-launcher

# Get dependencies
flutter pub get

# Generate code (Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run the project
flutter run
```

### 打包发布 | Build & Release

#### 中文 | Chinese

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Linux
flutter build linux --release
```

#### English

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Linux
flutter build linux --release
```

---

## 项目结构 | Project Structure

```
lib/
├── core/                  # 核心基础设施 | Core Infrastructure
│   ├── constants/         # 常量定义 | Constants
│   ├── crypto/            # NovelAI 加密服务 (Blake2b + Argon2id)
│   ├── network/           # Dio 网络层 | Dio Network Layer
│   ├── storage/           # 安全存储 + Hive | Secure Storage + Hive
│   └── utils/             # 工具类 (ZIP 处理等) | Utilities (ZIP handling, etc.)
│
├── data/                  # 数据层 | Data Layer
│   ├── models/            # Freezed 数据模型 | Freezed Data Models
│   ├── repositories/      # 仓库层 | Repository Layer
│   └── datasources/       # API 服务 | API Services
│
├── presentation/          # 表现层 | Presentation Layer
│   ├── providers/         # Riverpod 状态管理 | Riverpod State Management
│   ├── router/            # GoRouter 路由 | GoRouter Routing
│   ├── screens/           # 页面 | Screens/Pages
│   ├── widgets/           # 通用组件 | Common Widgets
│   └── themes/            # 5 套主题系统 | 5 Theme Systems
│
└── l10n/                  # 国际化资源 | Internationalization Resources
```

---

## 技术栈 | Tech Stack

### 中文 | Chinese

| 分类 | 技术 |
|------|------|
| 框架 | Flutter 3.16+ |
| 状态管理 | Riverpod 2.5+ |
| 网络 | Dio 5.4+ |
| 路由 | GoRouter 14+ |
| 数据模型 | Freezed + json_serializable |
| 加密 | cryptography (Blake2b + Argon2id) |
| 存储 | flutter_secure_storage + Hive |
| 主题 | FlexColorScheme |

### English

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.16+ |
| State Management | Riverpod 2.5+ |
| Networking | Dio 5.4+ |
| Routing | GoRouter 14+ |
| Data Models | Freezed + json_serializable |
| Cryptography | cryptography (Blake2b + Argon2id) |
| Storage | flutter_secure_storage + Hive |
| Theming | FlexColorScheme |

---

## 主题预览 | Theme Preview

### 1. Invoke Style (默认 | Default)

#### 中文
专业深色生产力工具风格，参考 InvokeAI

#### English
Professional dark productivity tool style, inspired by InvokeAI

---

### 2. Discord Style

#### 中文
熟悉的社交应用风格，Blurple 配色

#### English
Familiar social app style with Blurple color scheme

---

### 3. Linear Style

#### 中文
极简现代 SaaS 风格

#### English
Minimalist modern SaaS style

---

### 4. Cassette Futurism

#### 中文
复古科幻高对比度风格，橙红 + 黑

#### English
Retro sci-fi high contrast style, orange-red + black

---

### 5. Motorola Beeper

#### 中文
怀旧液晶屏风格，经典绿色

#### English
Nostalgic LCD screen style, classic green

---

## 开发说明 | Development Guide

### 代码生成 | Code Generation

#### 中文 | Chinese

项目使用 `build_runner` 生成模型和 Provider 代码：

```bash
# 一次性生成
dart run build_runner build --delete-conflicting-outputs

# 监听模式
dart run build_runner watch --delete-conflicting-outputs
```

#### English

This project uses `build_runner` to generate models and Provider code:

```bash
# One-time generation
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch --delete-conflicting-outputs
```

### 加密实现 | Cryptography Implementation

#### 中文 | Chinese

NovelAI 的认证使用 Blake2b + Argon2id 算法：

```dart
// lib/core/crypto/nai_crypto_service.dart
// 1. Blake2b 生成盐值
// 2. Argon2id 派生 Access Key
// 3. POST /user/login 获取 Token
```

#### English

NovelAI authentication uses Blake2b + Argon2id algorithms:

```dart
// lib/core/crypto/nai_crypto_service.dart
// 1. Blake2b generates salt
// 2. Argon2id derives Access Key
// 3. POST /user/login to get Token
```

---

## 许可证 | License

### 中文 | English

MIT License

---

## 致谢 | Acknowledgments

### 中文 | Chinese

- [NovelAI](https://novelai.net/) - AI 图像生成服务
- [novelai-api](https://github.com/Aedial/novelai-api) - API 参考实现
- [InvokeAI](https://invoke.ai/) - UI 设计参考

### English

- [NovelAI](https://novelai.net/) - AI Image Generation Service
- [novelai-api](https://github.com/Aedial/novelai-api) - API Reference Implementation
- [InvokeAI](https://invoke.ai/) - UI Design Reference

---

## 贡献 | Contributing

### 中文 | Chinese

欢迎提交 Issue 和 Pull Request！

### English

Issues and Pull Requests are welcome!

---

## 联系方式 | Contact

### 中文 | Chinese

如有问题或建议，请通过 GitHub Issues 联系。

### English

For questions or suggestions, please reach out via GitHub Issues.
