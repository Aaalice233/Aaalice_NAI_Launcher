# Vibe 图片自动编码导入实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Vibe 库导入图片时，如果图片没有嵌入的 Vibe 数据，弹出配置对话框让用户对图片进行服务端编码并自动保存到 Vibe 库。

**Architecture:** 复用现有 `GenerationParamsNotifier.encodeVibeWithCache()` API 进行编码，通过三个对话框（配置/编码中/错误）实现交互式编码流程，编码成功后调用 `VibeLibraryNotifier.saveEntry()` 保存。

**Tech Stack:** Flutter, Riverpod, Dart

---

## 前置知识

### 现有相关文件

- `lib/core/utils/vibe_image_embedder.dart` - Vibe 图片嵌入/提取工具，包含 `NoVibeDataException` 异常
- `lib/presentation/screens/vibe_library/vibe_library_screen.dart` - Vibe 库主页面，包含导入逻辑
- `lib/presentation/screens/vibe_library/widgets/vibe_import_naming_dialog.dart` - 参考弹窗风格
- `lib/presentation/providers/generation/generation_params_notifier.dart` - 编码 API 提供者

### 关键 API

```dart
// 编码 API
GenerationParamsNotifier.encodeVibeWithCache(
  Uint8List imageBytes, {
  required String model,
  required double informationExtracted,
  required String vibeName,
})

// 保存 Vibe 到库
VibeLibraryNotifier.saveEntry(VibeLibraryEntry entry)
```

---

## Task 1: 创建 Vibe 图片编码配置对话框

**Files:**
- Create: `lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart`

**Step 1: 编写对话框基础结构**

创建文件，实现带缩略图、名称输入、参数滑块的配置对话框：

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_logger.dart';

/// Vibe 图片编码配置结果
class VibeImageEncodeConfig {
  final String name;
  final double strength;
  final double infoExtracted;

  const VibeImageEncodeConfig({
    required this.name,
    required this.strength,
    required this.infoExtracted,
  });
}

/// Vibe 图片编码配置对话框
///
/// 用于在无 Vibe 数据的图片导入时，配置编码参数
class VibeImageEncodeDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  const VibeImageEncodeDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  static Future<VibeImageEncodeConfig?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return showDialog<VibeImageEncodeConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeImageEncodeDialog(
        imageBytes: imageBytes,
        fileName: fileName,
      ),
    );
  }

  @override
  State<VibeImageEncodeDialog> createState() => _VibeImageEncodeDialogState();
}

class _VibeImageEncodeDialogState extends State<VibeImageEncodeDialog> {
  late final TextEditingController _nameController;
  double _strength = 0.6;
  double _infoExtracted = 0.7;

  @override
  void initState() {
    super.initState();
    // 默认名称: vibe_YYYYMMDD_HHMMSS
    final defaultName = 'vibe_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    _nameController = TextEditingController(text: defaultName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(VibeImageEncodeConfig(
      name: name,
      strength: _strength,
      infoExtracted: _infoExtracted,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 24),
              _buildImagePreview(theme),
              const SizedBox(height: 24),
              _buildNameInput(theme),
              const SizedBox(height: 16),
              _buildStrengthSlider(theme),
              const SizedBox(height: 16),
              _buildInfoExtractedSlider(theme),
              const SizedBox(height: 8),
              _buildAnlasHint(theme),
              const SizedBox(height: 24),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.auto_fix_high, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '将此图片编码为 Vibe',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          widget.imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 8),
                Text('预览加载失败', style: theme.textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNameInput(ThemeData theme) {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: '名称',
        hintText: '输入 Vibe 名称',
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _confirm(),
    );
  }

  Widget _buildStrengthSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text('Strength', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(_strength.toStringAsFixed(2), style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            )),
          ],
        ),
        Slider(
          value: _strength,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (value) => setState(() => _strength = value),
        ),
      ],
    );
  }

  Widget _buildInfoExtractedSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.visibility, size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text('Info Extracted', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(_infoExtracted.toStringAsFixed(2), style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            )),
          ],
        ),
        Slider(
          value: _infoExtracted,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (value) => setState(() => _infoExtracted = value),
        ),
      ],
    );
  }

  Widget _buildAnlasHint(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Text('编码将消耗 2 Anlas', style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        )),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始编码'),
        ),
      ],
    );
  }
}
```

**Step 2: 检查代码风格一致性**

Run: `flutter analyze lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart
git commit -m "feat(vibe): 添加图片编码配置对话框"
```

---

## Task 2: 创建编码中状态对话框

**Files:**
- Modify: `lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart`（添加新类）

**Step 1: 添加编码中对话框类**

在文件末尾添加：

```dart
/// Vibe 图片编码中对话框
class VibeImageEncodingDialog extends StatelessWidget {
  const VibeImageEncodingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const VibeImageEncodingDialog(),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '正在编码图片...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请稍候',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart
git commit -m "feat(vibe): 添加编码中状态对话框"
```

---

## Task 3: 创建编码错误处理对话框

**Files:**
- Modify: `lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart`（添加新类）

**Step 1: 添加编码错误对话框类**

在文件末尾添加：

```dart
/// 编码错误处理结果
enum VibeEncodeErrorAction {
  skip,
  retry,
}

/// Vibe 图片编码错误对话框
class VibeImageEncodeErrorDialog extends StatelessWidget {
  final String fileName;
  final String errorMessage;

  const VibeImageEncodeErrorDialog({
    super.key,
    required this.fileName,
    required this.errorMessage,
  });

  static Future<VibeEncodeErrorAction?> show({
    required BuildContext context,
    required String fileName,
    required String errorMessage,
  }) {
    return showDialog<VibeEncodeErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeImageEncodeErrorDialog(
        fileName: fileName,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
      title: const Text('编码失败'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('图片: $fileName'),
          const SizedBox(height: 8),
          Text(
            '错误: $errorMessage',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(VibeEncodeErrorAction.skip),
          icon: const Icon(Icons.skip_next),
          label: const Text('跳过此图'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(VibeEncodeErrorAction.retry),
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart
git commit -m "feat(vibe): 添加编码错误处理对话框"
```

---

## Task 4: 修改 Vibe 库导入逻辑以支持自动编码

**Files:**
- Modify: `lib/presentation/screens/vibe_library/vibe_library_screen.dart`

**Step 1: 导入新增组件**

在文件顶部添加导入：

```dart
import 'widgets/vibe_image_encode_dialog.dart' as encode_dialog;
```

**Step 2: 修改 _importVibesFromImage 方法**

找到 `_importVibesFromImage` 方法（约第 1783 行），修改处理 `NoVibeDataException` 的逻辑。

首先，找到这段代码：

```dart
    if (imageFiles.isNotEmpty) {
      try {
        final importResult = await importService.importFromImage(
          images: imageFiles,
          categoryId: targetCategoryId,
          onProgress: (current, total, message) {
            AppLogger.d(message, 'VibeLibrary');
          },
        );
        totalSuccess += importResult.successCount;
        totalFail += importResult.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('导入图片 Vibe 失败', e, stackTrace, 'VibeLibrary');
        totalFail += imageFiles.length;
      }
    }
```

替换为逐张处理逻辑：

```dart
    // 处理每张图片
    for (final imageFile in imageFiles) {
      final result = await _processSingleImageImport(
        imageFile: imageFile,
        importService: importService,
        targetCategoryId: targetCategoryId,
      );

      if (result == true) {
        totalSuccess++;
      } else if (result == false) {
        totalFail++;
      }
      // result == null 表示用户取消，不计入统计
    }
```

**Step 3: 添加逐张处理方法**

在 `_importVibesFromImage` 方法后添加新方法：

```dart
  /// 处理单张图片导入
  ///
  /// 返回:
  /// - true: 成功导入
  /// - false: 导入失败
  /// - null: 用户取消
  Future<bool?> _processSingleImageImport({
    required VibeImageImportItem imageFile,
    required VibeImportService importService,
    String? targetCategoryId,
  }) async {
    // 首先尝试提取 Vibe 数据
    try {
      final reference = await VibeImageEmbedder.extractVibeFromImage(imageFile.bytes);
      // 提取成功，正常导入
      final importResult = await importService.importFromImage(
        images: [imageFile],
        categoryId: targetCategoryId,
      );
      return importResult.successCount > 0;
    } on NoVibeDataException {
      // 无 Vibe 数据，询问用户是否编码
      return await _handleImageEncoding(
        imageFile: imageFile,
        targetCategoryId: targetCategoryId,
      );
    } catch (e) {
      // 其他错误，记录为失败
      AppLogger.e('处理图片失败: ${imageFile.source}', e, null, 'VibeLibrary');
      return false;
    }
  }

  /// 处理图片编码流程
  Future<bool?> _handleImageEncoding({
    required VibeImageImportItem imageFile,
    String? targetCategoryId,
  }) async {
    if (!mounted) return null;

    // 显示编码配置对话框
    final config = await encode_dialog.VibeImageEncodeDialog.show(
      context: context,
      imageBytes: imageFile.bytes,
      fileName: imageFile.source,
    );

    if (config == null) return null; // 用户取消

    // 编码重试循环
    while (mounted) {
      // 显示编码中对话框
      encode_dialog.VibeImageEncodingDialog.show(context);

      String? encoding;
      String? errorMessage;

      try {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final params = ref.read(generationParamsNotifierProvider);
        final model = params.model;

        encoding = await notifier.encodeVibeWithCache(
          imageFile.bytes,
          model: model,
          informationExtracted: config.infoExtracted,
          vibeName: config.name,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            errorMessage = '编码超时，请检查网络连接';
            return null;
          },
        );
      } catch (e) {
        errorMessage = e.toString();
        AppLogger.e('Vibe 编码失败: ${imageFile.source}', e, null, 'VibeLibrary');
      } finally {
        // 关闭编码中对话框
        if (mounted) {
          encode_dialog.VibeImageEncodingDialog.hide(context);
        }
      }

      if (encoding != null && mounted) {
        // 编码成功，保存到 Vibe 库
        return await _saveEncodedVibe(
          name: config.name,
          encoding: encoding,
          imageBytes: imageFile.bytes,
          strength: config.strength,
          infoExtracted: config.infoExtracted,
          categoryId: targetCategoryId,
        );
      }

      // 编码失败，显示错误对话框
      if (!mounted) return null;

      final action = await encode_dialog.VibeImageEncodeErrorDialog.show(
        context: context,
        fileName: imageFile.source,
        errorMessage: errorMessage ?? '未知错误',
      );

      if (action == encode_dialog.VibeEncodeErrorAction.skip) {
        return false; // 标记为失败，继续下一张
      } else if (action == null) {
        return null; // 用户关闭对话框，视为取消
      }
      // 否则重试
    }

    return null;
  }

  /// 保存编码后的 Vibe 到库
  Future<bool> _saveEncodedVibe({
    required String name,
    required String encoding,
    required Uint8List imageBytes,
    required double strength,
    required double infoExtracted,
    String? categoryId,
  }) async {
    try {
      final notifier = ref.read(vibeLibraryNotifierProvider.notifier);

      // 创建 VibeReference
      final reference = VibeReference(
        displayName: name,
        vibeEncoding: encoding,
        strength: strength,
        infoExtracted: infoExtracted,
        sourceType: VibeSourceType.naiv4vibe,
        thumbnail: imageBytes,
        rawImageData: imageBytes,
      );

      // 创建并保存条目
      final entry = VibeLibraryEntry.fromVibeReference(
        name: name,
        vibeData: reference,
        categoryId: categoryId,
      );

      await notifier.saveEntry(entry);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('保存编码 Vibe 失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }
```

**Step 4: 确保必要的导入**

确认文件顶部有以下导入：

```dart
import '../../../core/utils/vibe_image_embedder.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../providers/generation/generation_params_notifier.dart';
```

**Step 5: 运行分析检查**

Run: `flutter analyze lib/presentation/screens/vibe_library/vibe_library_screen.dart`
Expected: No critical issues

**Step 6: Commit**

```bash
git add lib/presentation/screens/vibe_library/vibe_library_screen.dart
git commit -m "feat(vibe): 支持无 Vibe 数据的图片自动编码导入"
```

---

## Task 5: 运行代码生成和最终检查

**Step 1: 运行 build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Success, no errors

**Step 2: 运行完整分析**

Run: `flutter analyze`
Expected: No critical issues

**Step 3: Commit**

```bash
git add .
git commit -m "chore: 运行代码生成"
```

---

## 测试清单

### 功能测试

- [ ] 导入包含 Vibe 数据的 PNG → 正常导入，不弹编码对话框
- [ ] 导入无 Vibe 数据的 PNG → 弹出编码配置对话框
- [ ] 编码配置对话框显示正确：缩略图、名称输入、两个滑块
- [ ] 点击"开始编码" → 显示编码中对话框
- [ ] 编码成功 → Vibe 保存到库，名称正确
- [ ] 编码失败 → 显示错误对话框，可选择重试或跳过
- [ ] 选择"跳过" → 继续处理下一张
- [ ] 选择"重试" → 重新编码
- [ ] 导入多张无 Vibe 图片 → 逐张处理
- [ ] 最终 Toast 显示正确的成功/失败数量

### 边界测试

- [ ] 网络超时处理
- [ ] 用户取消编码配置对话框
- [ ] 名称为空时的处理（应该禁用确认按钮或提示）
- [ ] 滑块值范围正确（0.0-1.0）

---

## 完成标准

1. 所有对话框组件正常工作
2. 编码流程完整（配置 → 编码中 → 成功/失败处理）
3. 成功导入的 Vibe 正确保存到库
4. 代码分析无错误
5. 用户交互体验流畅
