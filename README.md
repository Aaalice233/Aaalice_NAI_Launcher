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

### 中文 | Chinese

以下截图展示应用的主要功能和界面：

- **主界面** - 图像生成主界面（三栏布局）
- **主题切换** - 展示 5 套不同主题的效果
- **移动端界面** - Android/iOS 响应式布局
- **设置页面** - 配置和个性化选项
- **图像生成流程** - 从输入到输出的完整流程

> 📸 **截图征集** - 欢迎提交您的高质量截图！

### English

The following screenshots showcase the main features and interface:

- **Main Interface** - Image generation main interface (three-column layout)
- **Theme Switching** - Demonstration of all 5 beautiful themes
- **Mobile Interface** - Android/iOS responsive layout
- **Settings Page** - Configuration and customization options
- **Image Generation Flow** - Complete workflow from input to output

> 📸 **Screenshots Wanted** - Contributions of high-quality screenshots are welcome!

---

#### 待添加截图 | Screenshots to Add

<details>
<summary>点击展开查看详情 | Click to expand details</summary>

**中文 | Chinese**

请添加以下截图（建议尺寸：1920x1080 或更大）：
- 每个主题的主界面截图
- 中文和英文界面对比
- 移动端和桌面端对比
- 图像生成结果展示

**English**

Please add the following screenshots (recommended size: 1920x1080 or larger):
- Main interface screenshot for each theme
- Chinese and English interface comparison
- Mobile and desktop comparison
- Image generation results showcase

</details>

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
│   └── utils/             # 工具类 (ZIP 处理, NAI API 工具) | Utilities
│
├── data/                  # 数据层 | Data Layer
│   ├── models/            # Freezed 数据模型 | Freezed Data Models
│   ├── repositories/      # 仓库层 | Repository Layer
│   └── datasources/       # NovelAI API 服务 (按领域分离) | Domain-Specific API Services
│       ├── nai_auth_api_service.dart              # 认证服务 | Authentication
│       ├── nai_image_generation_api_service.dart  # 图像生成 | Image Generation
│       ├── nai_image_enhancement_api_service.dart # 图像增强 | Upscale/Augment/Annotate
│       ├── nai_tag_suggestion_api_service.dart    # 标签建议 | Tag Suggestion
│       ├── nai_user_info_api_service.dart         # 用户信息 | User Subscription
│       ├── nai_api_service.dart                   # @Deprecated 门面模式 | Facade (Legacy)
│       └── danbooru_api_service.dart              # Danbooru API 服务
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

## 架构设计 | Architecture

### 中文 | Chinese

项目采用**领域驱动设计 (DDD)** 架构，将 NovelAI API 服务按功能领域拆分为 6 个独立服务：

#### 领域服务 | Domain Services

1. **NAIAuthApiService** (`nai_auth_api_service.dart`)
   - Token 验证和用户登录
   - 静态方法: `isValidTokenFormat()`

2. **NAIImageGenerationApiService** (`nai_image_generation_api_service.dart`)
   - 图像生成 (流式和非流式)
   - 取消生成功能
   - 采样器映射

3. **NAIImageEnhancementApiService** (`nai_image_enhancement_api_service.dart`)
   - 图像放大 (Upscale)
   - Vibe 转移 (Vibe Transfer)
   - 图像增强 (Augmentation): 修复情感、移除背景、上色等
   - 图像标注 (Annotation): 提取标签、边缘检测、深度图、姿态提取

4. **NAITagSuggestionApiService** (`nai_tag_suggestion_api_service.dart`)
   - 标签建议和补全

5. **NAIUserInfoApiService** (`nai_user_info_api_service.dart`)
   - 用户订阅信息查询

6. **NAIApiUtils** (`core/utils/nai_api_utils.dart`)
   - 共享静态工具方法
   - PNG 格式转换、JSON 数字格式化、错误格式化

#### 门面模式 | Facade Pattern

旧的 `NAIApiService` 保留为 `@Deprecated` 门面，委托到新的领域服务：
- 向后兼容性：现有代码仍可使用旧的 `naiApiServiceProvider`
- 迁移路径：编译时警告引导开发者使用新的领域服务
- 代码行数：从 1,877 行减少到 366 行 (80% 减少)

#### 依赖注入 | Dependency Injection

所有服务使用 Riverpod 提供器注入：
```dart
// 新的领域服务 | New Domain Services
@riverpod
NAIAuthApiService naiAuthApiService(NAIAuthApiServiceRef ref) {
  final dio = ref.watch(dioClientProvider);
  return NAIAuthApiService(dio);
}

// 使用示例 | Usage
final authService = ref.read(naiAuthApiServiceProvider);
await authService.validateToken(token);
```

### English

The project uses **Domain-Driven Design (DDD)** architecture with NovelAI API services split into 6 domain-specific services:

#### Domain Services

1. **NAIAuthApiService** (`nai_auth_api_service.dart`)
   - Token validation and user login
   - Static method: `isValidTokenFormat()`

2. **NAIImageGenerationApiService** (`nai_image_generation_api_service.dart`)
   - Image generation (streaming and non-streaming)
   - Cancel generation functionality
   - Sampler mapping

3. **NAIImageEnhancementApiService** (`nai_image_enhancement_api_service.dart`)
   - Image upscaling
   - Vibe transfer
   - Image augmentation: emotion fix, background removal, colorization, etc.
   - Image annotation: tag extraction, edge detection, depth map, pose extraction

4. **NAITagSuggestionApiService** (`nai_tag_suggestion_api_service.dart`)
   - Tag suggestion and completion

5. **NAIUserInfoApiService** (`nai_user_info_api_service.dart`)
   - User subscription information

6. **NAIApiUtils** (`core/utils/nai_api_utils.dart`)
   - Shared static utility methods
   - PNG format conversion, JSON number formatting, error formatting

#### Facade Pattern

The old `NAIApiService` is retained as an `@Deprecated` facade that delegates to new domain services:
- **Backwards Compatibility**: Existing code can still use `naiApiServiceProvider`
- **Migration Path**: Compile-time warnings guide developers to new services
- **Code Reduction**: Reduced from 1,877 lines to 366 lines (80% reduction)

#### Dependency Injection

All services use Riverpod providers for dependency injection:
```dart
// New domain services
@riverpod
NAIAuthApiService naiAuthApiService(NAIAuthApiServiceRef ref) {
  final dio = ref.watch(dioClientProvider);
  return NAIAuthApiService(dio);
}

// Usage example
final authService = ref.read(naiAuthApiServiceProvider);
await authService.validateToken(token);
```

---

## 迁移指南 | Migration Guide

### 中文 | Chinese

如果你仍在使用旧的 `NAIApiService`，请按以下步骤迁移到新的领域服务：

#### 步骤 1: 更新导入 | Update Imports

```dart
// 旧代码 | Old Code
import 'package:nai_launcher/data/datasources/remote/nai_api_service.dart';

// 新代码 | New Code
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
```

#### 步骤 2: 更新 Provider 引用 | Update Provider References

```dart
// 旧代码 | Old Code
final apiService = ref.read(naiApiServiceProvider);
await apiService.validateToken(token);
await apiService.generateImage(params);

// 新代码 | New Code
final authService = ref.read(naiAuthApiServiceProvider);
await authService.validateToken(token);

final genService = ref.read(naiImageGenerationApiServiceProvider);
await genService.generateImage(params);
```

#### 步骤 3: 更新静态方法调用 | Update Static Method Calls

```dart
// 旧代码 | Old Code
final isValid = NAIApiService.isValidTokenFormat(token);
final pngBytes = await NAIApiService.ensurePngFormat(bytes);

// 新代码 | New Code
final isValid = NAIAuthApiService.isValidTokenFormat(token);
final pngBytes = await NAIApiUtils.ensurePngFormat(bytes);
```

#### 方法映射表 | Method Mapping Table

| 旧方法 | 新服务 | 新方法 |
|--------|--------|--------|
| `validateToken()` | NAIAuthApiService | `validateToken()` |
| `loginWithKey()` | NAIAuthApiService | `loginWithKey()` |
| `isValidTokenFormat()` | NAIAuthApiService | `isValidTokenFormat()` (static) |
| `generateImage()` | NAIImageGenerationApiService | `generateImage()` |
| `generateImageStream()` | NAIImageGenerationApiService | `generateImageStream()` |
| `cancelGeneration()` | NAIImageGenerationApiService | `cancelGeneration()` |
| `suggestTags()` | NAITagSuggestionApiService | `suggestTags()` |
| `upscaleImage()` | NAIImageEnhancementApiService | `upscaleImage()` |
| `augmentImage()` | NAIImageEnhancementApiService | `augmentImage()` |
| `annotateImage()` | NAIImageEnhancementApiService | `annotateImage()` |
| `getUserSubscription()` | NAIUserInfoApiService | `getUserSubscription()` |
| `ensurePngFormat()` | NAIApiUtils | `ensurePngFormat()` (static) |

### English

If you're still using the old `NAIApiService`, follow these steps to migrate to new domain services:

#### Step 1: Update Imports

```dart
// Old Code
import 'package:nai_launcher/data/datasources/remote/nai_api_service.dart';

// New Code
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
```

#### Step 2: Update Provider References

```dart
// Old Code
final apiService = ref.read(naiApiServiceProvider);
await apiService.validateToken(token);
await apiService.generateImage(params);

// New Code
final authService = ref.read(naiAuthApiServiceProvider);
await authService.validateToken(token);

final genService = ref.read(naiImageGenerationApiServiceProvider);
await genService.generateImage(params);
```

#### Step 3: Update Static Method Calls

```dart
// Old Code
final isValid = NAIApiService.isValidTokenFormat(token);
final pngBytes = await NAIApiService.ensurePngFormat(bytes);

// New Code
final isValid = NAIAuthApiService.isValidTokenFormat(token);
final pngBytes = await NAIApiUtils.ensurePngFormat(bytes);
```

#### Method Mapping Table

| Old Method | New Service | New Method |
|------------|-------------|------------|
| `validateToken()` | NAIAuthApiService | `validateToken()` |
| `loginWithKey()` | NAIAuthApiService | `loginWithKey()` |
| `isValidTokenFormat()` | NAIAuthApiService | `isValidTokenFormat()` (static) |
| `generateImage()` | NAIImageGenerationApiService | `generateImage()` |
| `generateImageStream()` | NAIImageGenerationApiService | `generateImageStream()` |
| `cancelGeneration()` | NAIImageGenerationApiService | `cancelGeneration()` |
| `suggestTags()` | NAITagSuggestionApiService | `suggestTags()` |
| `upscaleImage()` | NAIImageEnhancementApiService | `upscaleImage()` |
| `augmentImage()` | NAIImageEnhancementApiService | `augmentImage()` |
| `annotateImage()` | NAIImageEnhancementApiService | `annotateImage()` |
| `getUserSubscription()` | NAIUserInfoApiService | `getUserSubscription()` |
| `ensurePngFormat()` | NAIApiUtils | `ensurePngFormat()` (static) |

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
