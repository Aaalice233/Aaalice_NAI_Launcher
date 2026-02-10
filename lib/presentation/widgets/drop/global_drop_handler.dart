import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/image/image_params.dart';
import '../../../data/models/metadata/metadata_import_options.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import '../common/app_toast.dart';
import '../metadata/metadata_import_dialog.dart';
import 'image_destination_dialog.dart';
import 'tag_library_drop_handler.dart';

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
                borderRadius: BorderRadius.circular(8),
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

    // 检测当前是否为词库页面
    final currentPath = GoRouter.of(context).routeInformationProvider.value.uri.path;
    final isTagLibraryPage = currentPath == AppRoutes.tagLibraryPage;

    // 如果是词库页面，使用词库专属拖拽处理
    if (isTagLibraryPage) {
      await TagLibraryDropHandler.handle(
        context: context,
        ref: ref,
        fileName: fileName,
        bytes: bytes,
      );
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

      case ImageDestination.addToQueue:
        await _handleAddToQueue(bytes);
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
    final hasExisting = currentState.preciseReferences.isNotEmpty;

    // 角色参考只支持 1 张，如果已有则替换
    if (hasExisting) {
      notifier.clearPreciseReferences();
    }

    // 使用默认 Character 类型添加 Precise Reference
    notifier.addPreciseReference(
      bytes,
      type: PreciseRefType.character,
      strength: 1.0,
      fidelity: 1.0,
    );

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
          AppToast.warning(context, context.l10n.metadataImport_noDataFound);
        }
        return;
      }

      // 显示参数选择对话框
      final options = await _showMetadataImportDialog(metadata);
      if (options == null || !mounted) return; // 用户取消

      // 应用选中的参数
      final appliedCount = await _applyMetadataWithOptions(
        metadata,
        options,
        notifier,
      );

      if (mounted) {
        if (appliedCount > 0) {
          AppToast.success(
            context,
            context.l10n.metadataImport_appliedCount(appliedCount),
          );

          // 显示详细信息
          _showMetadataAppliedDialog(metadata, options);
        } else {
          AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error extracting metadata: $e', 'DropHandler');
      }
      // 保存错误消息以避免跨 async gap 使用 context
      final errorMessage = '提取元数据失败: $e';
      await _showErrorAsync(errorMessage);
    }
  }

  /// 显示元数据导入对话框（抽取方法避免 async gap 警告）
  Future<MetadataImportOptions?> _showMetadataImportDialog(dynamic metadata) {
    return MetadataImportDialog.show(
      context,
      metadata: metadata,
    );
  }

  /// 异步显示错误（带 mounted 检查）
  Future<void> _showErrorAsync(String message) async {
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    _showError(message);
  }

  /// 根据选项应用元数据
  Future<int> _applyMetadataWithOptions(
    dynamic metadata,
    MetadataImportOptions options,
    GenerationParamsNotifier notifier,
  ) async {
    var appliedCount = 0;

    // 只有在勾选导入多角色提示词时才清空
    if (options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty) {
      final characterNotifier =
          ref.read(characterPromptNotifierProvider.notifier);
      characterNotifier.clearAllCharacters();
    }

    // 应用 Prompt
    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      notifier.updatePrompt(metadata.prompt);
      appliedCount++;
    }

    // 应用负向提示词
    if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
      notifier.updateNegativePrompt(metadata.negativePrompt);
      appliedCount++;
    }

    // 应用多角色提示词
    if (options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty) {
      final characterNotifier =
          ref.read(characterPromptNotifierProvider.notifier);
      final characters = <char.CharacterPrompt>[];
      for (var i = 0; i < metadata.characterPrompts.length; i++) {
        final prompt = metadata.characterPrompts[i];
        final negPrompt = i < metadata.characterNegativePrompts.length
            ? metadata.characterNegativePrompts[i]
            : '';

        // 尝试从提示词推断性别
        final gender = _inferGenderFromPrompt(prompt);

        characters.add(
          char.CharacterPrompt.create(
            name: 'Character ${i + 1}',
            gender: gender,
            prompt: prompt,
            negativePrompt: negPrompt,
          ),
        );
      }
      characterNotifier.replaceAll(characters);
      appliedCount++;
    }

    // 应用 Seed
    if (options.importSeed && metadata.seed != null) {
      notifier.updateSeed(metadata.seed!);
      appliedCount++;
    }

    // 应用 Steps
    if (options.importSteps && metadata.steps != null) {
      notifier.updateSteps(metadata.steps!);
      appliedCount++;
    }

    // 应用 Scale
    if (options.importScale && metadata.scale != null) {
      notifier.updateScale(metadata.scale!);
      appliedCount++;
    }

    // 应用尺寸
    if (options.importSize &&
        metadata.width != null &&
        metadata.height != null) {
      notifier.updateSize(metadata.width!, metadata.height!);
      appliedCount++;
    }

    // 应用采样器
    if (options.importSampler && metadata.sampler != null) {
      notifier.updateSampler(metadata.sampler!);
      appliedCount++;
    }

    // 应用模型
    if (options.importModel && metadata.model != null) {
      notifier.updateModel(metadata.model!);
      appliedCount++;
    }

    // 应用 SMEA
    if (options.importSmea && metadata.smea != null) {
      notifier.updateSmea(metadata.smea!);
      appliedCount++;
    }
    if (options.importSmeaDyn && metadata.smeaDyn != null) {
      notifier.updateSmeaDyn(metadata.smeaDyn!);
      appliedCount++;
    }

    // 应用 Noise Schedule
    if (options.importNoiseSchedule && metadata.noiseSchedule != null) {
      notifier.updateNoiseSchedule(metadata.noiseSchedule!);
      appliedCount++;
    }

    // 应用 CFG Rescale
    if (options.importCfgRescale && metadata.cfgRescale != null) {
      notifier.updateCfgRescale(metadata.cfgRescale!);
      appliedCount++;
    }

    // 应用 Quality Toggle
    if (options.importQualityToggle && metadata.qualityToggle != null) {
      notifier.updateQualityToggle(metadata.qualityToggle!);
      appliedCount++;
    }

    // 应用 UC Preset
    if (options.importUcPreset && metadata.ucPreset != null) {
      notifier.updateUcPreset(metadata.ucPreset!);
      appliedCount++;
    }

    return appliedCount;
  }

  /// 处理加入队列（提取正面提示词）
  Future<void> _handleAddToQueue(Uint8List bytes) async {
    try {
      // 解析 NAI 隐写元数据
      final metadata = await NaiMetadataParser.extractFromBytes(bytes);

      if (metadata == null || metadata.prompt.isEmpty) {
        if (mounted) {
          AppToast.warning(context, '未找到有效的提示词');
        }
        return;
      }

      // 创建队列任务（只使用正面提示词）
      final task = ReplicationTask.create(
        prompt: metadata.prompt,
      );

      // 添加到队列
      ref.read(replicationQueueNotifierProvider.notifier).add(task);

      if (mounted) {
        final displayPrompt = metadata.prompt.length > 50
            ? '${metadata.prompt.substring(0, 50)}...'
            : metadata.prompt;
        AppToast.success(context, '已加入队列: $displayPrompt');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error adding to queue: $e', 'DropHandler');
      }
      _showError('提取提示词失败: $e');
    }
  }

  /// 从提示词推断角色性别
  char.CharacterGender _inferGenderFromPrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('1girl') ||
        lowerPrompt.contains('girl,') ||
        lowerPrompt.startsWith('girl')) {
      return char.CharacterGender.female;
    } else if (lowerPrompt.contains('1boy') ||
        lowerPrompt.contains('boy,') ||
        lowerPrompt.startsWith('boy')) {
      return char.CharacterGender.male;
    }
    return char.CharacterGender.other;
  }

  /// 显示元数据应用成功对话框
  void _showMetadataAppliedDialog(
    dynamic metadata,
    MetadataImportOptions options,
  ) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(l10n.metadataImport_appliedTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.metadataImport_appliedDescription),
              const SizedBox(height: 12),
              if (options.importPrompt && metadata.prompt.isNotEmpty)
                _buildAppliedItem(
                  l10n.metadataImport_prompt,
                  metadata.prompt,
                  maxLines: 3,
                ),
              if (options.importNegativePrompt &&
                  metadata.negativePrompt.isNotEmpty)
                _buildAppliedItem(
                  l10n.metadataImport_negativePrompt,
                  metadata.negativePrompt,
                  maxLines: 2,
                ),
              if (options.importCharacterPrompts &&
                  metadata.characterPrompts.isNotEmpty)
                _buildAppliedItem(
                  l10n.metadataImport_characterPrompts,
                  '${metadata.characterPrompts.length} ${l10n.metadataImport_charactersCount}',
                ),
              if (options.importSeed && metadata.seed != null)
                _buildAppliedItem(
                  l10n.metadataImport_seed,
                  metadata.seed.toString(),
                ),
              if (options.importSteps && metadata.steps != null)
                _buildAppliedItem(
                  l10n.metadataImport_steps,
                  metadata.steps.toString(),
                ),
              if (options.importScale && metadata.scale != null)
                _buildAppliedItem(
                  l10n.metadataImport_scale,
                  metadata.scale.toString(),
                ),
              if (options.importSize &&
                  metadata.width != null &&
                  metadata.height != null)
                _buildAppliedItem(
                  l10n.metadataImport_size,
                  '${metadata.width} x ${metadata.height}',
                ),
              if (options.importSampler && metadata.sampler != null)
                _buildAppliedItem(
                  l10n.metadataImport_sampler,
                  metadata.displaySampler,
                ),
              if (options.importModel && metadata.model != null)
                _buildAppliedItem(
                  l10n.metadataImport_model,
                  metadata.model.toString(),
                ),
              if (options.importSmea && metadata.smea != null)
                _buildAppliedItem(
                  l10n.metadataImport_smea,
                  metadata.smea.toString(),
                ),
              if (options.importSmeaDyn && metadata.smeaDyn != null)
                _buildAppliedItem(
                  l10n.metadataImport_smeaDyn,
                  metadata.smeaDyn.toString(),
                ),
              if (options.importNoiseSchedule &&
                  metadata.noiseSchedule != null)
                _buildAppliedItem(
                  l10n.metadataImport_noiseSchedule,
                  metadata.noiseSchedule.toString(),
                ),
              if (options.importCfgRescale && metadata.cfgRescale != null)
                _buildAppliedItem(
                  l10n.metadataImport_cfgRescale,
                  metadata.cfgRescale.toString(),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_confirm),
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
