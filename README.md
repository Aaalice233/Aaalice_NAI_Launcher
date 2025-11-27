# NAI Launcher

**NovelAI Universal Launcher** - 跨平台 NovelAI 第三方客户端

[![Flutter](https://img.shields.io/badge/Flutter-3.16+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.2+-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 功能特性

- **纯客户端架构** - 无需后端服务，APK 安装即用
- **跨平台支持** - Windows、Android、Linux
- **图像生成** - 完整支持 NovelAI 图像生成 API
- **5 套精美主题** - Invoke Style、Discord、Linear、复古未来主义、寻呼机风格
- **响应式布局** - 桌面端三栏布局，移动端自适应
- **中英双语** - 内置国际化支持

## 截图预览

*截图待添加*

## 快速开始

### 环境要求

- Flutter 3.16+
- Dart 3.2+
- Android SDK 23+ (Android)
- Visual Studio 2019+ (Windows)

### 安装步骤

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

### 打包发布

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Linux
flutter build linux --release
```

## 项目结构

```
lib/
├── core/                  # 核心基础设施
│   ├── constants/         # 常量定义
│   ├── crypto/            # NovelAI 加密服务 (Blake2b + Argon2id)
│   ├── network/           # Dio 网络层
│   ├── storage/           # 安全存储 + Hive
│   └── utils/             # 工具类 (ZIP 处理等)
│
├── data/                  # 数据层
│   ├── models/            # Freezed 数据模型
│   ├── repositories/      # 仓库层
│   └── datasources/       # API 服务
│
├── presentation/          # 表现层
│   ├── providers/         # Riverpod 状态管理
│   ├── router/            # GoRouter 路由
│   ├── screens/           # 页面
│   ├── widgets/           # 通用组件
│   └── themes/            # 5 套主题系统
│
└── l10n/                  # 国际化资源
```

## 技术栈

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

## 主题预览

### 1. Invoke Style (默认)
专业深色生产力工具风格，参考 InvokeAI

### 2. Discord Style
熟悉的社交应用风格，Blurple 配色

### 3. Linear Style
极简现代 SaaS 风格

### 4. Cassette Futurism
复古科幻高对比度风格，橙红 + 黑

### 5. Motorola Beeper
怀旧液晶屏风格，经典绿色

## 开发说明

### 代码生成

项目使用 `build_runner` 生成模型和 Provider 代码：

```bash
# 一次性生成
dart run build_runner build --delete-conflicting-outputs

# 监听模式
dart run build_runner watch --delete-conflicting-outputs
```

### 加密实现

NovelAI 的认证使用 Blake2b + Argon2id 算法：

```dart
// lib/core/crypto/nai_crypto_service.dart
// 1. Blake2b 生成盐值
// 2. Argon2id 派生 Access Key
// 3. POST /user/login 获取 Token
```

## 许可证

MIT License

## 致谢

- [NovelAI](https://novelai.net/) - AI 图像生成服务
- [novelai-api](https://github.com/Aedial/novelai-api) - API 参考实现
- [InvokeAI](https://invoke.ai/) - UI 设计参考
