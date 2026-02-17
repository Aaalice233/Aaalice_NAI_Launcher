# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NAI Launcher 是一个 NovelAI 跨平台第三方客户端，使用 Flutter 构建，支持 Windows、Android 和 Linux。

**代码规模**: 929 个 Dart 文件，约 29 万行代码，232 个生成文件

## Development Commands

### 日常开发（推荐）

```bash
# 安装依赖
flutter pub get

# 生成代码 (Freezed, Riverpod, JSON Serializable, Hive)
dart run build_runner build --delete-conflicting-outputs

# 代码分析（开发时只需运行此命令检查，无需构建发行包）
flutter analyze

# 快速修复分析错误
dart fix --apply

# 运行应用
flutter run
```

### Windows 开发脚本

项目提供 Windows 批处理脚本简化开发流程（位于 `scripts/`）：

```powershell
# 交互式菜单（分析/生成/修复等）
.\scripts\dev_tools.bat

# 一键完整检查（analyze → gen-l10n → build_runner）
.\scripts\quick_check.bat
```

> **注意**: Windows 项目建议在 Windows 端运行 Flutter 命令，WSL 仅用于代码编辑。

### WSL 中调试 Flutter (Windows 项目)

当在 WSL (Linux 环境) 中开发 Windows Flutter 项目时，需要通过 Windows 的 Flutter SDK 运行命令：

```bash
# 设置 Windows Flutter 路径变量
FLUTTER="/mnt/e/flutter/bin/flutter.bat"
DART="/mnt/e/flutter/bin/dart.bat"

# 运行分析
$FLUTTER analyze

# 生成国际化代码
$FLUTTER gen-l10n

# 运行 build_runner
$DART run build_runner build --delete-conflicting-outputs

# 运行应用 (Windows 桌面)
$FLUTTER run -d windows
```

**要点:**
- 使用 `cmd.exe /c` 或直接使用 `.bat` 文件来执行 Windows 命令
- WSL 路径 `/mnt/e/` 对应 Windows 的 `E:\`
- 所有 Flutter 命令必须在 Windows 端执行，WSL 仅用于代码编辑和文件操作
- 遇到 `l10n` 未定义错误时，检查 `l10n.yaml` 的 `synthetic-package: false` 配置

### 完整验证

```bash
# 运行测试
flutter test

# 生成国际化代码
flutter gen-l10n

# 完整检查（分析 + 生成 + 测试）
flutter analyze && dart run build_runner build --delete-conflicting-outputs && flutter test
```

### 构建发行包（仅发布时需要）

```bash
# Windows 版本
flutter build windows

# 或使用打包脚本（自动预构建数据库并签名）
scripts\build_release.bat

# Android 版本
flutter build apk
flutter build appbundle
```

> **注意**: 日常开发时只需运行 `flutter analyze` 检查代码，无需构建 Windows 发行包，后者仅在发布时需要。

## Architecture Overview

### 项目结构 (Clean Architecture + DDD)

```
lib/
├── core/                  # 核心功能和基础设施 (188 文件)
│   ├── cache/             # 缓存管理 (Danbooru 图片缓存、标签缓存)
│   ├── constants/         # 常量定义 (StorageKeys 等)
│   ├── crypto/            # 加密服务 (NAI 认证加密)
│   ├── enums/             # 枚举类型定义
│   ├── extensions/        # Dart/Flutter 扩展
│   ├── network/           # 网络层 (Dio, 代理服务)
│   ├── parsers/           # 数据解析器
│   ├── services/          # 核心服务 (17 个服务)
│   ├── shortcuts/         # 键盘快捷键系统
│   ├── storage/           # 存储抽象 (SecureStorage, Hive)
│   └── utils/             # 工具类
├── data/                  # 数据层 (296 文件)
│   ├── datasources/       # 数据源
│   │   ├── local/         # 本地数据源 (Hive, SQLite)
│   │   └── remote/        # 远程 API 服务 (按领域拆分)
│   ├── models/            # 数据模型 (Freezed + JSON)
│   │   ├── auth/          # 认证模型
│   │   ├── character/     # 角色提示词模型
│   │   ├── danbooru/      # Danbooru 集成模型
│   │   ├── gallery/       # 画廊模型
│   │   ├── image/         # 图像生成参数模型
│   │   ├── prompt/        # 提示词配置模型 (92 文件)
│   │   ├── queue/         # 队列任务模型
│   │   ├── tag/           # 标签模型
│   │   └── vibe/          # Vibe Transfer 模型
│   ├── repositories/      # 仓库实现
│   └── services/          # 数据服务
├── presentation/          # 展示层 (445 文件)
│   ├── providers/         # Riverpod Providers (169 个)
│   ├── router/            # GoRouter 路由配置
│   ├── screens/           # 页面
│   │   ├── generation/    # 图像生成页 (桌面/移动双布局)
│   │   ├── local_gallery/ # 本地画廊
│   │   ├── online_gallery/# 在线画廊 (Danbooru)
│   │   ├── tag_library_page/# 词库管理
│   │   └── vibe_library/  # Vibe Transfer 库
│   ├── themes/            # 主题配置
│   ├── utils/             # UI 工具
│   └── widgets/           # 通用组件 (40+ 组件目录)
└── l10n/                  # 国际化 (ARB 文件)
```

### 核心功能模块

1. **图像生成** - NovelAI API 文本到图像生成，支持多参数配置
2. **Vibe Transfer** - 图像风格迁移，支持 Vibe 库管理
3. **本地画廊** - SQLite 索引的本地图像管理，元数据缓存
4. **在线画廊** - Danbooru 集成，标签搜索、池浏览
5. **提示词系统** - 动态语法解析、权重调整、标签库管理
6. **队列系统** - 批量生成任务管理，悬浮球 UI 控制
7. **快捷键系统** - 完整的键盘快捷键支持，可自定义配置

### 状态管理 (Riverpod)

项目使用 **Riverpod** 进行状态管理，共 169 个 Providers:
- 94 个 `@riverpod` 函数式 Provider
- 75 个 `@Riverpod` Controller 类

**编码模式:**

```dart
// Controller 模式 - 使用 keepAlive 保持状态
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<void> build() async { ... }

  Future<void> login() async {
    state = await AsyncValue.guard(() => _login());
  }
}

// 依赖注入模式
@riverpod
NaiAuthApiService naiAuthApiService(NaiAuthApiServiceRef ref) {
  final dio = ref.watch(dioClientProvider);
  return NaiAuthApiService(dio);
}

// 使用方式
final authState = ref.watch(authControllerProvider);
ref.read(authControllerProvider.notifier).login();
```

### API 服务架构 (领域拆分)

API 服务按功能领域分离:

| 服务 | 文件 | 功能 |
|------|------|------|
| NaiAuthApiService | `nai_auth_api_service.dart` | 认证相关 |
| NaiImageGenerationApiService | `nai_image_generation_api_service.dart` (25KB) | 图像生成 |
| NaiImageEnhancementApiService | `nai_image_enhancement_api_service.dart` | 图像增强 (img2img, 超分) |
| NaiUserInfoApiService | `nai_user_info_api_service.dart` | 用户信息 |
| NaiTagSuggestionApiService | `nai_tag_suggestion_api_service.dart` | 标签建议 |
| DanbooruApiService | `danbooru_api_service.dart` (17KB) | Danbooru 集成 |

**网络层特点:**
- Dio 客户端统一配置，支持 HTTP/2
- 自动 Token 刷新 (401 拦截)
- 系统代理自动检测 + 手动配置
- HTTP/1.1 (代理) / HTTP/2 (直连) 动态切换

### 路由架构 (GoRouter + StatefulShellRoute)

文件: `lib/presentation/router/app_router.dart` (753 行)

**混合保活策略:**
- **保活页面** (索引 2, 3): localGallery, onlineGallery - 使用 Offstage 保持状态
- **非保活页面**: 其他页面切换时销毁重建

```dart
class AppRoutes {
  static const String home = '/';
  static const String generation = '/generation';
  static const String gallery = '/gallery';
  static const String localGallery = '/local-gallery';
  static const String onlineGallery = '/online-gallery';
  static const String settings = '/settings';
  static const String promptConfig = '/prompt-config';
  static const String statistics = '/statistics';
  static const String tagLibraryPage = '/tag-library';
  static const String vibeLibrary = '/vibe-library';
}
```

### 本地存储

**多层存储架构:**

1. **Hive** - 主要本地存储 (NoSQL)
   - Boxes: `settings`, `history`, `tagCache`, `gallery`, `localFavorites`, `tags`, `searchIndex`, `statisticsCache`, `replicationQueue`, `queueExecutionState`
   - 用于: 用户设置、生成历史、标签缓存、画廊元数据

2. **SecureStorage** - 敏感数据存储
   - 用于: access token、用户凭证、账号信息

3. **SQLite** - 结构化数据存储
   - 用于: 画廊索引、复杂查询
   - 包: `sqflite_common_ffi` (支持 Windows/Linux)

4. **文件系统** - 大文件存储
   - 图像文件、Vibe 数据、共现标签数据 (100MB+)

**存储键名管理**: `lib/core/constants/storage_keys.dart` (197 个常量)

### 代码生成

项目大量使用代码生成，**修改以下文件后必须运行 build_runner**:

| 注解类型 | 用途 | 生成文件 |
|---------|------|---------|
| `@freezed` | 不可变数据类 | `.freezed.dart` |
| `@riverpod` / `@Riverpod` | Provider 生成 | `.g.dart` |
| `@HiveType` | Hive 适配器 | `.g.dart` |
| JSON Serializable | JSON 解析 | `.g.dart` |

```bash
# 生成代码
dart run build_runner build --delete-conflicting-outputs

# 监视模式（开发时自动重建）
dart run build_runner watch --delete-conflicting-outputs
```

### 国际化

- 翻译文件: `lib/l10n/app_en.arb` (134KB), `lib/l10n/app_zh.arb` (126KB)
- 使用 `context.l10n.xxx` 或 `AppLocalizations.of(context)!`
- 键名使用 lowerCamelCase

```bash
# 生成国际化代码
flutter gen-l10n
```

### 代码规范

见 `analysis_options.yaml`:

- `prefer_const_constructors: true` - 优先使用 const 构造函数
- `prefer_final_fields: true` - 字段优先使用 final
- `prefer_final_locals: true` - 局部变量优先使用 final
- `require_trailing_commas: true` - 要求尾随逗号

#### 命名规范

**禁止使用版本号后缀命名**

不要将版本号（如 `_v2`, `_v3`）用于：
- 文件名（如 `tag_data_v2.db` → `tag_data.db`）
- 类名（如 `VibeReferenceV4` → `VibeReference`）
- 变量/常量名（如 `_entriesV2` → 使用语义化命名）
- Hive Box 名称

**例外情况**：
- API 参数名（如 NovelAI 的 `ddim_v3`）保留原样
- 本地化键表示产品特性版本（如 `vibe_sourceType_v4vibe`）
- 运行时版本管理变量（版本号是值，不是名称的一部分）

**正确做法**：
- 使用语义化命名（如 `_emergency`, `_fallback`）
- 数据库版本管理使用 `version` 字段或 `user_version` PRAGMA
- 需要迁移时通过版本号变量控制，而非文件复制

**原因**：
版本号命名会导致旧代码和死代码残留，维护困难。语义化命名更具可读性和可维护性。

**快速修复:**

```bash
# 查看所有问题
flutter analyze --severity=info

# 自动修复
dart fix --apply

# 仅查看不修复
dart fix --dry-run
```

### 提交规范 (Conventional Commits)

**必须使用简体中文书写**

```
<type>(<scope>): <subject>

types: feat, fix, docs, style, refactor, test, chore, perf
```

## Key Dependencies

### 核心框架
- `flutter_riverpod: ^2.5.1` - 状态管理
- `go_router: ^14.2.0` - 路由

### 网络
- `dio: ^5.4.0` - HTTP 客户端
- `dio_http2_adapter: ^2.3.0` - HTTP/2 支持

### 本地存储
- `hive: ^2.2.3` + `hive_flutter: ^1.1.0` - NoSQL 存储
- `flutter_secure_storage: ^9.2.4` - 安全存储
- `sqflite_common_ffi: ^2.3.4` - SQLite FFI

### 数据模型
- `freezed: ^2.5.2` - 不可变数据类
- `json_annotation: ^4.9.0` - JSON 序列化

### 桌面功能
- `window_manager: ^0.3.9` - 窗口管理
- `tray_manager: ^0.2.3` - 系统托盘

### 媒体处理
- `image: ^4.1.7` - 图像处理
- `video_player: ^2.8.0` + `video_player_media_kit` - 视频播放
- `audioplayers: ^6.0.0` - 音效播放

### UI 组件
- `flex_color_scheme: ^7.3.1` - 主题方案
- `google_fonts: ^6.1.0` - 字体
- `fl_chart: ^0.68.0` - 图表
- `flutter_staggered_grid_view: ^0.7.0` - 瀑布流布局
- `super_drag_and_drop: ^0.8.23` - 拖拽功能

### 工具
- `file_picker: ^8.0.0` - 文件选择
- `share_plus: ^10.0.0` - 分享功能
- `logger: ^2.4.0` - 日志记录
- `path_provider: ^2.1.0` - 路径获取

## 平台特性与最佳实践

### Windows 平台特性

1. **单实例应用** - Windows 平台单实例支持，新实例启动时唤醒已存在实例
2. **系统代理检测** - 自动检测 Windows 系统代理设置
3. **窗口状态保存** - 关闭时保存窗口位置和大小
4. **系统托盘** - 最小化到托盘，右键菜单支持

### 性能优化

1. **图片缓存** - 最大 500 张 / 200MB 缓存限制
2. **懒加载** - Danbooru 标签懒加载服务
3. **并发控制** - 信号量限制并发请求
4. **后台预加载** - 启动时后台预加载 NAI 标签数据 (不阻塞 UI)
5. **大数据延迟加载** - 共现标签数据 (100MB+) 延迟下载

### 错误处理

1. **认证错误自动处理** - 401 时自动刷新 JWT
2. **API 错误统一拦截** - Dio 拦截器处理
3. **异步状态使用 AsyncValue** - `AsyncValue.guard()` 包装异步操作

### 存储迁移

- `DataMigrationService` 处理版本升级时的数据迁移
- Hive 使用子目录存储，支持旧数据迁移

### 响应式布局

- 桌面端布局阈值: 1000px
- 自适应组件: `LayoutBuilder` 动态选择布局
- 桌面/移动端双布局: `desktop_layout.dart` / `mobile_layout.dart`

## 日志系统

**日志目录**: `E:\Aaalice_NAI_Launcher\logs`

**功能**:
- 同时输出到控制台和文件
- 自动保留最近3个启动的日志
- 自动删除旧日志文件

**文件名规则**:
- 正式环境: `app_YYYYMMDD_HHMMSS.log`
- 测试环境: `test_YYYYMMDD_HHMMSS.log`

**使用**:
```dart
// 初始化（在 main() 中调用）
await AppLogger.initialize(isTestEnvironment: false);

// 记录日志
AppLogger.i('信息日志', 'Tag');
AppLogger.d('调试日志');
AppLogger.w('警告日志');
AppLogger.e('错误日志', error, stackTrace);
```

**获取日志文件**:
```dart
final files = await AppLogger.getLogFiles(); // 按时间倒序
print(AppLogger.currentLogFile); // 当前日志文件路径
```

## 测试

**位置**: `test/` 目录

**运行测试**:
```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/app_logger_test.dart
flutter test test/app_test.dart
flutter test test/data_source_test.dart
```

**测试日志**:
- 使用相同日志目录 `E:\Aaalice_NAI_Launcher\logs`
- 日志文件名以 `test_` 前缀区分
- 同样保留最近3个测试日志文件
