import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/image_generation_provider.dart';
import '../common/app_toast.dart';
import 'image_destination_dialog.dart';

/// 全局拖拽处理器
///
/// 包装整个生成界面，监听拖拽事件
/// 当用户拖拽图片到界面任意位置时，弹出选择对话框
class GlobalDropHandler extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalDropHandler({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalDropHandler> createState() => _GlobalDropHandlerState();
}

class _GlobalDropHandlerState extends ConsumerState<GlobalDropHandler> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        // 检查是否包含文件
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDragging) {
            setState(() => _isDragging = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        if (_isDragging) {
          setState(() => _isDragging = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isDragging = false);
        await _handleDrop(event);
      },
      child: Stack(
        children: [
          widget.child,
          // 拖拽覆盖层
          if (_isDragging) _buildDropOverlay(context),
        ],
      ),
    );
  }

  Widget _buildDropOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: theme.colorScheme.primary.withOpacity(0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.drop_hint,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      // 尝试获取文件
      if (reader.canProvide(Formats.fileUri)) {
        reader.getValue(Formats.fileUri, (uri) async {
          if (uri == null) return;

          try {
            final file = File(uri.toFilePath());
            final fileName = file.path.split(Platform.pathSeparator).last;
            final bytes = await file.readAsBytes();

            await _processDroppedFile(fileName, bytes);
          } catch (e) {
            if (kDebugMode) {
              AppLogger.d('Error reading dropped file: $e', 'DropHandler');
            }
            _showError(e.toString());
          }
        });
      }
      // 尝试获取图片数据
      else if (reader.canProvide(Formats.png)) {
        reader.getFile(Formats.png, (file) async {
          try {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'dropped_image.png';

            await _processDroppedFile(fileName, bytes);
          } catch (e) {
            if (kDebugMode) {
              AppLogger.d('Error reading dropped image: $e', 'DropHandler');
            }
            _showError(e.toString());
          }
        });
      } else if (reader.canProvide(Formats.jpeg)) {
        reader.getFile(Formats.jpeg, (file) async {
          try {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'dropped_image.jpg';

            await _processDroppedFile(fileName, bytes);
          } catch (e) {
            if (kDebugMode) {
              AppLogger.d('Error reading dropped image: $e', 'DropHandler');
            }
            _showError(e.toString());
          }
        });
      }
    }
  }

  Future<void> _processDroppedFile(String fileName, Uint8List bytes) async {
    if (!mounted) return;

    // 检查是否为支持的文件类型
    if (!VibeFileParser.isSupportedFile(fileName)) {
      _showError(context.l10n.drop_unsupportedFormat);
      return;
    }

    // 显示目标选择对话框
    final destination = await ImageDestinationDialog.show(
      context,
      imageBytes: bytes,
      fileName: fileName,
      showExtractMetadata:
          fileName.toLowerCase().endsWith('.png'), // 只有 PNG 才支持提取元数据
    );

    if (destination == null || !mounted) return;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);

    switch (destination) {
      case ImageDestination.img2img:
        _handleImg2Img(bytes, notifier);
        break;

      case ImageDestination.vibeTransfer:
        await _handleVibeTransfer(fileName, bytes, notifier);
        break;

      case ImageDestination.characterReference:
        _handleCharacterReference(bytes, notifier);
        break;

      case ImageDestination.extractMetadata:
        await _handleExtractMetadata(bytes, notifier);
        break;
    }
  }

  void _handleImg2Img(Uint8List bytes, GenerationParamsNotifier notifier) {
    notifier.setSourceImage(bytes);
    notifier.updateAction(ImageGenerationAction.img2img);

    if (mounted) {
      AppToast.success(context, context.l10n.drop_addedToImg2Img);
    }
  }

  Future<void> _handleVibeTransfer(
    String fileName,
    Uint8List bytes,
    GenerationParamsNotifier notifier,
  ) async {
    try {
      final currentState = ref.read(generationParamsNotifierProvider);
      final currentCount = currentState.vibeReferencesV4.length;
      const maxCount = 16;

      // 解析文件，可能返回多个 vibe（bundle 情况）
      final vibes = await VibeFileParser.parseFile(fileName, bytes);
      final addCount = vibes.length;

      // 检查是否超出上限
      if (currentCount + addCount > maxCount) {
        if (mounted) {
          AppToast.warning(context, '风格参考已达上限 ($maxCount 张)');
        }
        return;
      }

      for (final vibe in vibes) {
        notifier.addVibeReferenceV4(vibe);
      }

      if (mounted) {
        String message;
        if (currentCount > 0) {
          // 追加模式
          message = '已追加 $addCount 个风格参考';
        } else {
          message = vibes.length == 1
              ? context.l10n.drop_addedToVibe
              : context.l10n.drop_addedMultipleToVibe(vibes.length);
        }
        AppToast.success(context, message);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error parsing vibe file: $e', 'DropHandler');
      }
      _showError(e.toString());
    }
  }

  void _handleCharacterReference(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
  ) {
    final currentState = ref.read(generationParamsNotifierProvider);
    final hasExisting = currentState.characterReferences.isNotEmpty;

    // 角色参考只支持 1 张，如果已有则替换
    if (hasExisting) {
      notifier.clearCharacterReferences();
    }

    final characterRef = CharacterReference(image: bytes);
    notifier.addCharacterReference(characterRef);

    if (mounted) {
      AppToast.success(
        context,
        hasExisting ? '已替换角色参考' : context.l10n.drop_addedToCharacterRef,
      );
    }
  }

  /// 处理提取元数据并应用
  Future<void> _handleExtractMetadata(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
  ) async {
    try {
      // 解析 NAI 隐写元数据
      final metadata = await NaiMetadataParser.extractFromBytes(bytes);

      if (metadata == null || !metadata.hasData) {
        if (mounted) {
          AppToast.warning(context, '未找到 NovelAI 元数据');
        }
        return;
      }

      // 应用元数据到生成参数
      int appliedCount = 0;

      // 应用 Prompt
      if (metadata.prompt.isNotEmpty) {
        notifier.updatePrompt(metadata.prompt);
        appliedCount++;
      }

      // 应用负向提示词
      if (metadata.negativePrompt.isNotEmpty) {
        notifier.updateNegativePrompt(metadata.negativePrompt);
        appliedCount++;
      }

      // 应用 Seed
      if (metadata.seed != null) {
        notifier.updateSeed(metadata.seed!);
        appliedCount++;
      }

      // 应用 Steps
      if (metadata.steps != null) {
        notifier.updateSteps(metadata.steps!);
        appliedCount++;
      }

      // 应用 Scale
      if (metadata.scale != null) {
        notifier.updateScale(metadata.scale!);
        appliedCount++;
      }

      // 应用尺寸
      if (metadata.width != null && metadata.height != null) {
        notifier.updateSize(metadata.width!, metadata.height!);
        appliedCount++;
      }

      // 应用采样器
      if (metadata.sampler != null) {
        notifier.updateSampler(metadata.sampler!);
        appliedCount++;
      }

      // 应用 SMEA 设置
      if (metadata.smea != null) {
        notifier.updateSmea(metadata.smea!);
        appliedCount++;
      }
      if (metadata.smeaDyn != null) {
        notifier.updateSmeaDyn(metadata.smeaDyn!);
        appliedCount++;
      }

      // 应用 Noise Schedule
      if (metadata.noiseSchedule != null) {
        notifier.updateNoiseSchedule(metadata.noiseSchedule!);
        appliedCount++;
      }

      // 应用 CFG Rescale
      if (metadata.cfgRescale != null) {
        notifier.updateCfgRescale(metadata.cfgRescale!);
        appliedCount++;
      }

      if (mounted) {
        if (appliedCount > 0) {
          AppToast.success(context, '已应用 $appliedCount 项参数');

          // 显示详细信息
          _showMetadataAppliedDialog(metadata);
        } else {
          AppToast.warning(context, '未能应用任何参数');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error extracting metadata: $e', 'DropHandler');
      }
      _showError('提取元数据失败: $e');
    }
  }

  /// 显示元数据应用成功对话框
  void _showMetadataAppliedDialog(dynamic metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('元数据已应用'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('以下参数已应用到当前设置：'),
              const SizedBox(height: 12),
              if (metadata.prompt.isNotEmpty)
                _buildAppliedItem('Prompt', metadata.prompt, maxLines: 3),
              if (metadata.negativePrompt.isNotEmpty)
                _buildAppliedItem(
                  '负向提示词',
                  metadata.negativePrompt,
                  maxLines: 2,
                ),
              if (metadata.seed != null)
                _buildAppliedItem('Seed', metadata.seed.toString()),
              if (metadata.steps != null)
                _buildAppliedItem('Steps', metadata.steps.toString()),
              if (metadata.scale != null)
                _buildAppliedItem('CFG Scale', metadata.scale.toString()),
              if (metadata.width != null && metadata.height != null)
                _buildAppliedItem(
                  '尺寸',
                  '${metadata.width} x ${metadata.height}',
                ),
              if (metadata.sampler != null)
                _buildAppliedItem('采样器', metadata.displaySampler),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedItem(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }
}
