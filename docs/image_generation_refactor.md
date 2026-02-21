# 图像生成 Provider 重构架构设计

## 概述

原 `ImageGenerationNotifier` 包含 **1,153 行代码** 和 **63 个控制流语句**，负责图像生成的全部逻辑。重构后，代码被拆分为：**专注的 Service 类** + **精简的 Notifier 类**，实现关注点分离和更好的可测试性。

## 架构概览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        新架构分层设计                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      Facade 层 (简化版 Provider)                  │   │
│  │              ImageGenerationNotifierNew (~294 行)               │   │
│  │     - 统一对外接口                                                │   │
│  │     - 状态管理（生成中/完成/错误/取消）                           │   │
│  │     - 委托具体逻辑到 Service 层                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                    │
│                                    ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      Service 层（纯业务逻辑）                      │   │
│  │                                                                  │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐              │   │
│  │  │ ImageGeneration     │  │ ParameterProcessing │              │   │
│  │  │ Service (503行)     │  │ Service (363行)     │              │   │
│  │  │ - 单张/批量生成     │  │ - 别名解析          │              │   │
│  │  │ - 流式预览支持      │  │ - 固定词应用        │              │   │
│  │  │ - 重试机制          │  │ - 参数预处理        │              │   │
│  │  │ - 取消支持          │  │                     │              │   │
│  │  └─────────────────────┘  └─────────────────────┘              │   │
│  │                                                                  │   │
│  │  ┌─────────────────────┐                                      │   │
│  │  │ CharacterConversion │                                      │   │
│  │  │ Service (172行)     │                                      │   │
│  │  │ - UI角色转API格式   │                                      │   │
│  │  │ - 位置坐标转换      │                                      │   │
│  │  │ - 角色别名解析      │                                      │   │
│  │  └─────────────────────┘                                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                    │
│                                    ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                   Notifier 层（专注状态管理）                      │   │
│  │                                                                  │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐    │   │
│  │  │ BatchGeneration          │ StreamGeneration          │    │   │
│  │  │ Notifier (586行)         │ Notifier (392行)          │    │   │
│  │  │ - 批量生成状态           │ - 流式生成状态            │    │   │
│  │  │ - 并发控制               │ - 实时预览                │    │   │
│  │  │ - 统计信息               │ - 进度跟踪                │    │   │
│  │  └──────────────┘ └──────────────┘ └──────────────────────┘    │   │
│  │                                                                  │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐    │   │
│  │  │ ImageSave                │ MetadataPreload           │    │   │
│  │  │ Notifier (327行)         │ Notifier (385行)          │    │   │
│  │  │ - 自动保存               │ - 元数据预加载            │    │   │
│  │  │ - 批量保存               │ - 队列管理                │    │   │
│  │  │ - 保存统计               │ - 缓存统计                │    │   │
│  │  └──────────────┘ └──────────────┘ └──────────────────────┘    │   │
│  │                                                                  │   │
│  │  ┌──────────────────────────────────────┐                      │   │
│  │  │ RetryPolicy Notifier (165行)          │                      │   │
│  │  │ - 重试策略配置                        │                      │   │
│  │  │ - 指数退避计算                        │                      │   │
│  │  │ - 本地持久化                          │                      │   │
│  │  └──────────────────────────────────────┘                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 重构收益

| 指标 | 重构前 | 重构后 | 改善 |
|------|--------|--------|------|
| 最大文件行数 | 1,153 行 | 503 行 (Service) | **56% ↓** |
| Facade 层行数 | 1,153 行 | 294 行 | **74% ↓** |
| 单文件控制流 | 63 个 | 平均 <20 个 | **68% ↓** |
| 单元测试覆盖 | 困难 | 容易 | **可测试性↑** |
| 代码复用性 | 低 | 高 | **复用性↑** |

## Service 层职责

### 1. ImageGenerationService

**位置**: `lib/presentation/providers/generation/image_generation_service.dart`

**职责**:
- 核心图像生成逻辑
- 单张生成 (`generateSingle`)
- 批量生成 (`generateBatch`)
- 流式预览支持
- 重试机制（指数退避）
- 取消支持

**特点**:
- 纯服务类，**不依赖 Riverpod**
- 通过构造函数注入 API 服务
- 返回 `ImageGenerationResult` 封装结果
- 支持 `GenerationProgressCallback` 进度回调

**核心方法**:
```dart
// 单张生成
Future<ImageGenerationResult> generateSingle(
  ImageParams params, {
  GenerationProgressCallback? onProgress,
});

// 批量生成
Future<ImageGenerationResult> generateBatch(
  ImageParams params, {
  required int batchCount,
  required int batchSize,
  void Function(int, int, int)? onBatchStart,
  GenerationProgressCallback? onProgress,
  void Function(List<GeneratedImage>)? onBatchComplete,
});

// 生命周期管理
void cancel();
void resetCancellation();
```

### 2. ParameterProcessingService

**位置**: `lib/core/services/parameter_processing_service.dart`

**职责**:
- 别名解析（`<词库名>` → 实际内容）
- 固定词应用（前缀/后缀）
- 支持简单、随机、带权重三种别名引用

**特点**:
- 纯服务类，**不依赖 Riverpod**
- 依赖注入 `TagLibraryEntry` 和 `FixedTagEntry`
- 返回 `ParameterProcessingResult` 包含处理状态

**核心方法**:
```dart
// 完整处理流程
ParameterProcessingResult process({
  required String prompt,
  required String negativePrompt,
  bool resolveAliases = true,
  bool applyFixedTags = true,
});

// 独立功能
String resolveAliases(String text);
String applyFixedTags(String prompt);
FixedTagsStatistics getStatistics();
```

### 3. CharacterConversionService

**位置**: `lib/core/services/character_conversion_service.dart`

**职责**:
- UI 角色配置 → API 角色格式转换
- 自定义位置坐标转换（NAI 网格格式）
- 角色提示词中的别名解析

**特点**:
- 纯服务类，**不依赖 Riverpod**
- 通过 `AliasResolver` 接口注入别名解析器
- 返回 `CharacterConversionResult` 包含转换状态

**核心方法**:
```dart
// 完整转换
CharacterConversionResult convert(
  CharacterPromptConfig config, {
  bool resolveAliases = true,
});

// 快速转换（不解析别名）
List<CharacterPrompt> convertCharacters(CharacterPromptConfig config);

// 工具方法
bool hasEnabledCharacters(CharacterPromptConfig config);
int getEnabledCharacterCount(CharacterPromptConfig config);
```

## Notifier 层职责

### 1. BatchGenerationNotifier

**位置**: `lib/presentation/providers/generation/batch_generation_notifier.dart`

**职责**:
- 批量生成状态管理
- 并发控制（Semaphore 实现）
- 每批次进度跟踪
- 失败重试支持

**状态类**:
- `BatchGenerationState` - 批量生成状态
- `BatchGenerationItem` - 单个生成项状态
- `BatchStatistics` - 统计信息

### 2. StreamGenerationNotifier

**位置**: `lib/presentation/providers/generation/stream_generation_notifier.dart`

**职责**:
- 流式生成状态管理
- 实时预览图像更新
- 流连接/断开处理
- 自动回退到非流式 API

**状态类**:
- `StreamGenerationState` - 流式生成状态
- 支持 `connecting`, `streaming`, `completing` 等状态

### 3. ImageSaveNotifier

**位置**: `lib/presentation/providers/generation/image_save_notifier.dart`

**职责**:
- 自动保存功能
- 单张/批量保存
- 保存状态跟踪

**状态类**:
- `ImageSaveState` - 保存状态
- `ImageSaveResult` - 保存结果

### 4. MetadataPreloadNotifier

**位置**: `lib/presentation/providers/generation/metadata_preload_notifier.dart`

**职责**:
- 图像元数据预加载
- 队列管理（高优先级/后台）
- 缓存统计

**状态类**:
- `MetadataPreloadState` - 预加载状态
- `MetadataPreloadStats` - 统计信息

### 5. RetryPolicyNotifier

**位置**: `lib/presentation/providers/generation/retry_policy_notifier.dart`

**职责**:
- 重试策略配置管理
- 本地持久化（LocalStorageService）
- 指数退避计算

**配置项**:
- `maxRetries`: 最大重试次数 (0-10)
- `retryIntervalMs`: 重试间隔 (500-30000ms)
- `retryEnabled`: 是否启用重试
- `backoffMultiplier`: 退避倍数 (1.0-5.0)

## Facade 层（简化版 Provider）

### ImageGenerationNotifierNew

**位置**: `lib/presentation/providers/image_generation_provider_new.dart`

**设计原则**:
- **简化对外接口**：仅暴露 `generateSingle()` 和 `generateBatch()`
- **状态管理**：维护生成状态、进度、错误信息
- **委托逻辑**：所有业务逻辑委托给 `ImageGenerationService`
- **资源管理**：在 `onDispose` 中取消生成

**代码对比**:

| 特性 | 旧版 (1,153行) | 新版 Facade (294行) |
|------|---------------|---------------------|
| 生成逻辑 | 内置在 Notifier | 委托给 Service |
| 别名解析 | 内置在 Notifier | 委托给 Service |
| 固定词应用 | 内置在 Notifier | 委托给 Service |
| 重试机制 | 内置在 Notifier | 委托给 Service |
| 状态管理 | 复杂，包含业务 | 简单，纯状态 |

## 使用方式

### 基础生成

```dart
// 使用 Facade 层（推荐）
final notifier = ref.read(imageGenerationNotifierNewProvider.notifier);
await notifier.generateSingle(params);

// 监听状态
final status = ref.watch(generationStatusProvider);
final progress = ref.watch(generationProgressProvider);
final images = ref.watch(generatedImagesProvider);
```

### 批量生成

```dart
// 使用专门的 Batch Notifier
final notifier = ref.read(batchGenerationNotifierProvider.notifier);
await notifier.generateBatch(params, imageCount: 10);

// 监听批量状态
final batchState = ref.watch(batchGenerationNotifierProvider);
final stats = notifier.getStatistics();
```

### 参数预处理

```dart
// 直接使用 Service（无需 Riverpod）
final service = ParameterProcessingService(
  tagLibraryEntries: entries,
  fixedTags: fixedTags,
);

final result = service.process(
  prompt: 'masterpiece, <quality>',
  negativePrompt: 'lowres',
);

print(result.prompt); // 解析后的提示词
print(result.aliasesResolved); // 是否解析了别名
```

### 角色转换

```dart
// 直接使用 Service
final service = CharacterConversionService(
  aliasResolver: parameterProcessingService,
);

final result = service.convert(characterConfig);
final apiCharacters = result.characters;
final useCoords = result.useCoords;
```

## 迁移指南

### 从旧版 ImageGenerationNotifier 迁移

```dart
// 旧方式
final notifier = ref.read(imageGenerationNotifierProvider.notifier);
await notifier.generate(params);

// 新方式（单张）
final notifier = ref.read(imageGenerationNotifierNewProvider.notifier);
await notifier.generateSingle(params);

// 新方式（批量）
await notifier.generateBatch(
  params,
  batchCount: 4,
  batchSize: 1,
);
```

### 状态监听迁移

```dart
// 旧方式
final state = ref.watch(imageGenerationNotifierProvider);

// 新方式 - 使用便捷 Provider
final isGenerating = ref.watch(isGeneratingProvider);
final progress = ref.watch(generationProgressProvider);
final error = ref.watch(generationErrorProvider);
final hasPreview = ref.watch(hasStreamPreviewProvider);
```

## 文件清单

### Service 层

| 文件 | 行数 | 职责 |
|------|------|------|
| `image_generation_service.dart` | 503 | 核心生成逻辑 |
| `parameter_processing_service.dart` | 363 | 参数预处理 |
| `character_conversion_service.dart` | 172 | 角色转换 |

### Notifier 层

| 文件 | 行数 | 职责 |
|------|------|------|
| `batch_generation_notifier.dart` | 586 | 批量生成状态 |
| `stream_generation_notifier.dart` | 392 | 流式生成状态 |
| `image_save_notifier.dart` | 327 | 保存功能 |
| `metadata_preload_notifier.dart` | 385 | 元数据预加载 |
| `retry_policy_notifier.dart` | 165 | 重试策略配置 |

### Facade 层

| 文件 | 行数 | 职责 |
|------|------|------|
| `image_generation_provider_new.dart` | 294 | 统一对外接口 |

### 测试文件

| 文件 | 测试数 | 覆盖 |
|------|--------|------|
| `image_generation_service_test.dart` | 23 | 核心生成逻辑 |
| `parameter_processing_service_test.dart` | 46 | 参数预处理 |
| `batch_generation_notifier_test.dart` | 37+ | 批量生成状态 |

## 设计原则

1. **单一职责原则 (SRP)**：每个 Service/Notifier 只负责一个明确的功能
2. **依赖注入**：Service 通过构造函数注入依赖，便于测试
3. **纯服务类**：Service 层不依赖 Riverpod，是纯粹的业务逻辑
4. **状态分离**：Notifier 层专注于状态管理，不包含复杂业务逻辑
5. **Facade 模式**：简化版 Provider 作为统一入口，内部委托给专业服务

## 注意事项

1. **生成代码**：修改 `@riverpod` 注解的类后，需要运行 `flutter pub run build_runner build`
2. **测试**：Service 层使用纯 Dart 测试，Notifier 层使用 Riverpod 测试工具
3. **兼容性**：旧版 `ImageGenerationNotifier` 仍保留，可逐步迁移
