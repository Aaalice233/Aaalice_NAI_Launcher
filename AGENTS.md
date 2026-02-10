# AGENTS.md - NAI Launcher

NAI Launcher 项目的 AI 编码代理指南。

## 项目概述

NAI Launcher（NovelAI Universal Launcher）- 基于 Flutter 构建的跨平台 NovelAI 第三方客户端，支持 Windows、Android 和 Linux。采用 Clean Architecture + DDD 架构，使用 Riverpod 进行状态管理。

**技术栈**：Flutter >=3.16.0、Dart >=3.2.0、Riverpod、Dio、Hive、SQLite、Freezed

## 构建命令

```bash
# 安装依赖
flutter pub get

# 运行代码生成（修改 @freezed/@riverpod/@HiveType 后必须运行）
dart run build_runner build --delete-conflicting-outputs

# 代码生成监视模式（开发时使用）
dart run build_runner watch --delete-conflicting-outputs

# 代码分析检查
flutter analyze

# 自动修复代码问题
dart fix --apply

# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/core/services/danbooru_tags_sync_service_test.dart

# 生成本地化文件
flutter gen-l10n

# 运行应用
flutter run

# 构建 Windows 发行版
flutter build windows
```

## 代码规范

### Lint 规则（analysis_options.yaml）

- `prefer_const_constructors: true` - 优先使用 const 构造函数
- `prefer_const_declarations: true` - 优先使用 const 声明
- `prefer_final_fields: true` - 字段应使用 final
- `prefer_final_locals: true` - 局部变量应使用 final
- `require_trailing_commas: true` - 要求尾随逗号
- `avoid_print: false` - 允许使用 print（建议改用 AppLogger）

### 命名规范

- **文件**：snake_case（例如：`auth_controller.dart`）
- **类**：PascalCase（例如：`AuthController`）
- **变量/函数**：camelCase（例如：`userName`、`fetchData()`）
- **常量**：camelCase（例如：`apiBaseUrl`）
- **私有成员**：下划线前缀（例如：`_privateVar`）
- **国际化键名**：lowerCamelCase（例如：`auth_login`、`common_save`）

### 导入顺序

1. Dart SDK 导入（`dart:*`）
2. Flutter SDK 导入（`package:flutter/*`）
3. 第三方包
4. 项目导入（相对或绝对路径）

示例：
```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/auth/auth_token.dart';
```

## 架构模式

### 状态管理（Riverpod）

```dart
@riverpod
class AuthController extends _$AuthController {
  @override
  Future<void> build() async {
    // 初始化逻辑
  }
  
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 异步操作
    });
  }
}

// 使用方式
final authState = ref.watch(authControllerProvider);
ref.read(authControllerProvider.notifier).login(...);
```

### API 服务（按领域拆分）

| 服务 | 文件 | 职责 |
|---------|------|---------|
| NaiAuthApiService | `nai_auth_api_service.dart` | 认证相关 |
| NaiImageGenerationApiService | `nai_image_generation_api_service.dart` | 图像生成 |
| NaiImageEnhancementApiService | `nai_image_enhancement_api_service.dart` | img2img、超分 |
| NaiUserInfoApiService | `nai_user_info_api_service.dart` | 用户信息 |
| DanbooruApiService | `danbooru_api_service.dart` | Danbooru 集成 |

### 项目结构

```
lib/
├── core/           # 核心工具、服务、常量
├── data/           # 数据层（模型、仓库、数据源）
├── presentation/   # 展示层（页面、组件、状态管理）
└── l10n/          # 国际化
```

## 代码生成

修改以下文件后**必须**运行代码生成：
- `@freezed` → 生成 `*.freezed.dart`
- `@riverpod` → 生成 `*.g.dart`
- `@HiveType` → 生成 `*.g.dart`
- ARB 文件 → 生成 `app_localizations*.dart`

## 错误处理

```dart
// 使用 AsyncValue.guard 处理异步操作
state = await AsyncValue.guard(() async {
  return await apiService.fetchData();
});

// 使用 AppLogger 记录日志
AppLogger.d('调试信息');
AppLogger.i('普通信息');
AppLogger.e('错误信息', error, stackTrace);
```

## 测试

- 测试框架：`flutter_test`、`mocktail`（用于模拟）
- 测试位置：`test/` 目录
- 运行单个测试：`flutter test test/path/to/test.dart`

## Git 规范

**提交信息必须使用简体中文。**

格式：`<类型>(<范围>): <描述>`

类型：`feat`、`fix`、`docs`、`style`、`refactor`、`test`、`chore`、`perf`

示例：
```
feat(image): 添加批量图像生成功能
fix(auth): 修复 token 过期问题
refactor(widget): 提取颜色选择器逻辑
```

## 重要注意事项

1. **修改注解文件后必须运行代码生成** - 修改 `@freezed`、`@riverpod`、`@HiveType` 文件后必须运行 `build_runner`
2. **通过服务提供者使用 Hive** - 不要直接操作 Hive，使用对应的 Provider/Service
3. **添加尾随逗号** - 代码规范要求尾随逗号，`require_trailing_commas: true`
4. **优先使用 const 构造函数** - 尽可能使用 const 构造函数优化性能
5. **使用 AppLogger 替代 print** - 日志使用 `AppLogger.d()`、`AppLogger.i()`、`AppLogger.e()` 等
6. **修改 ARB 文件** - 新增 UI 文本需同时更新 `app_en.arb` 和 `app_zh.arb`
7. **提交前运行分析** - 提交前运行 `flutter analyze` 确保无错误
8. **Windows 功能需测试** - 修改桌面端功能（窗口、托盘等）需在 Windows 上测试

## 最新变更 (2026-02-10)

### Precise Reference 功能升级

将原有的 Character Reference 功能升级为 NovelAI 最新的 Precise Reference 架构：

- **三种参考类型**: `character`, `style`, `characterAndStyle`
- **每个参考独立参数**: `strength` (0-1), `fidelity` (0-1)
- **支持多参考**: 不再限制单张图片
- **不与 Vibe Transfer 互斥**: 可以同时使用

### 关键文件

| 文件 | 说明 |
|------|------|
| `lib/core/enums/precise_ref_type.dart` | PreciseRefType 枚举定义 |
| `lib/data/models/image/image_params.dart` | CharacterReference 数据模型 |
| `lib/data/datasources/remote/nai_image_generation_api_service.dart` | API 参数构造 |
| `lib/presentation/screens/generation/widgets/precise_reference_panel.dart` | UI 面板 |

### API 映射

| PreciseRefType | API 值 |
|----------------|--------|
| `character` | `"character"` |
| `style` | `"style"` |
| `characterAndStyle` | `"character&style"` |

### Anlas 成本

- **Precise Reference**: 5 Anlas/张角色参考
- **Vibe Transfer 编码**: 2 Anlas/张（原始图片）

## 本地存储

**Hive 数据盒**：`settings`、`history`、`gallery`、`tags`、`localFavorites`、`tagCache`、`localMetadataCache`、`statisticsCache`、`replicationQueue`、`queueExecutionState`

**SecureStorage**：用于敏感数据（token、密码）

## 国际化（i18n）

- 模板文件：`lib/l10n/app_en.arb`
- 中文文件：`lib/l10n/app_zh.arb`
- 使用方式：`context.l10n.xxx` 或 `AppLocalizations.of(context)!`
- 生成命令：`flutter gen-l10n`
