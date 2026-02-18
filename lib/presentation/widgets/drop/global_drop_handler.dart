import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/image/image_params.dart';
import '../../../data/models/metadata/metadata_import_options.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_metadata_service.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import '../common/app_toast.dart';
import '../metadata/metadata_import_dialog.dart';
import 'image_destination_dialog.dart';
import 'tag_library_drop_handler.dart';

/// 文件读取结果
class _FileData {
  final String fileName;
  final Uint8List bytes;

  const _FileData({required this.fileName, required this.bytes});
}

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
        // 重要：不要等待 _handleDrop 完成，让拖放回调立即返回
        // 否则 Windows 拖放系统会卡死，导致资源管理器无响应
        unawaited(_handleDrop(event));
        return;
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

      final fileData = await _readFileData(reader);
      if (fileData != null) {
        await _processDroppedFile(fileData.fileName, fileData.bytes);
      }
    }
  }

  /// 文件读取参数（用于 Isolate）
  static Future<_FileData?> _readFileInIsolate(_FileReadParams params) async {
    try {
      final file = File(params.filePath);
      final bytes = await file.readAsBytes();
      return _FileData(fileName: params.fileName, bytes: bytes);
    } catch (e) {
      return null;
    }
  }

  Future<_FileData?> _readFileData(DataReader reader) async {
    // 尝试获取文件 URI
    if (reader.canProvide(Formats.fileUri)) {
      final uri = await _getFileUri(reader);
      if (uri != null) {
        try {
          final filePath = uri.toFilePath();
          final fileName = filePath.split(Platform.pathSeparator).last;

          // 使用 compute 将文件读取移到 Isolate，避免阻塞 UI
          final result = await compute(
            _readFileInIsolate,
            _FileReadParams(filePath: filePath, fileName: fileName),
          );

          if (result == null) {
            _showError('读取文件失败');
          }
          return result;
        } catch (e) {
          if (kDebugMode) {
            AppLogger.d('Error reading dropped file: $e', 'DropHandler');
          }
          _showError(e.toString());
        }
      }
      return null;
    }

    // 尝试获取图片数据（从拖放的原始数据，不是文件系统）
    final imageFormat = _getSupportedImageFormat(reader);
    if (imageFormat != null) {
      try {
        final file = await _getImageFile(reader, imageFormat);
        if (file == null) {
          AppLogger.w('无法读取拖放的图片文件', 'DropHandler');
          return null;
        }
        final bytes = await file.readAll();
        final extension = imageFormat == Formats.png ? 'png' : 'jpg';
        final fileName = file.fileName ?? 'dropped_image.$extension';
        return _FileData(fileName: fileName, bytes: bytes);
      } catch (e) {
        if (kDebugMode) {
          AppLogger.d('Error reading dropped image: $e', 'DropHandler');
        }
        _showError(e.toString());
      }
    }

    return null;
  }

  Future<Uri?> _getFileUri(DataReader reader) async {
    final completer = Completer<Uri?>();

    // 关键检查：如果 getValue 返回 null，说明格式不可用，直接返回 null
    final progress = reader.getValue(
      Formats.fileUri,
      (uri) {
        if (!completer.isCompleted) {
          completer.complete(uri);
        }
      },
      onError: (e) {
        AppLogger.w('获取文件URI错误: $e', 'DropHandler');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    if (progress == null) {
      // 格式不可用，不需要等待回调
      return null;
    }

    // 添加超时保护，防止某些拖拽源不触发回调导致永久挂起
    try {
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.w('获取文件URI超时', 'DropHandler');
          return null;
        },
      );
    } catch (e) {
      AppLogger.w('获取文件URI失败: $e', 'DropHandler');
      return null;
    }
  }

  FileFormat? _getSupportedImageFormat(DataReader reader) {
    if (reader.canProvide(Formats.png)) return Formats.png;
    if (reader.canProvide(Formats.jpeg)) return Formats.jpeg;
    return null;
  }

  Future<DataReaderFile?> _getImageFile(
      DataReader reader, FileFormat format,) async {
    final completer = Completer<DataReaderFile?>();

    // 关键检查：如果 getFile 返回 null，说明格式不可用，直接返回 null
    final progress = reader.getFile(
      format,
      (file) {
        if (!completer.isCompleted) {
          completer.complete(file);
        }
      },
      onError: (e) {
        AppLogger.w('获取图片文件错误: $e', 'DropHandler');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    if (progress == null) {
      // 格式不可用，不需要等待回调
      return null;
    }

    // 添加超时保护，防止某些拖拽源不触发回调导致永久挂起
    try {
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.w('获取图片文件超时', 'DropHandler');
          return null;
        },
      );
    } catch (e) {
      AppLogger.w('获取图片文件失败: $e', 'DropHandler');
      return null;
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
    final currentPath =
        GoRouter.of(context).routeInformationProvider.value.uri.path;
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

    // 保存 context 相关数据后再进行异步操作
    final l10n = context.l10n;
    final showExtractMetadata = fileName.toLowerCase().endsWith('.png');

    // 检测是否包含 Vibe 元数据（仅 PNG）
    final detectedVibe = await _detectVibeMetadata(fileName, bytes);

    if (!mounted) return;

    // 显示目标选择对话框
    final destination = await ImageDestinationDialog.show(
      context,
      imageBytes: bytes,
      fileName: fileName,
      showExtractMetadata: showExtractMetadata,
      detectedVibe: detectedVibe,
    );

    if (destination == null || !mounted) return;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);

    await _handleDestination(
      destination,
      fileName,
      bytes,
      detectedVibe,
      notifier,
      l10n,
    );
  }

  Future<VibeReference?> _detectVibeMetadata(
    String fileName,
    Uint8List bytes,
  ) async {
    if (!fileName.toLowerCase().endsWith('.png')) return null;

    try {
      final vibeService = VibeMetadataService();
      final vibe = await vibeService.extractVibeFromImage(bytes);
      if (vibe != null) {
        AppLogger.i(
          'Detected pre-encoded Vibe in dropped image: ${vibe.displayName}',
          'DropHandler',
        );
      }
      return vibe;
    } catch (e) {
      AppLogger.d('Failed to detect Vibe metadata: $e', 'DropHandler');
      return null;
    }
  }

  Future<void> _handleDestination(
    ImageDestination destination,
    String fileName,
    Uint8List bytes,
    VibeReference? detectedVibe,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    switch (destination) {
      case ImageDestination.img2img:
        _handleImg2Img(bytes, notifier, l10n);
        break;

      case ImageDestination.vibeTransfer:
        await _handleVibeTransfer(fileName, bytes, notifier, l10n);
        break;

      case ImageDestination.vibeTransferReuse:
        if (detectedVibe != null) {
          await _handleVibeReuse(detectedVibe, notifier, l10n);
        }
        break;

      case ImageDestination.vibeTransferRaw:
        await _handleVibeTransfer(
          fileName,
          bytes,
          notifier,
          l10n,
          forceRaw: true,
        );
        break;

      case ImageDestination.characterReference:
        _handleCharacterReference(bytes, notifier, l10n);
        break;

      case ImageDestination.extractMetadata:
        await _handleExtractMetadata(bytes, notifier, l10n);
        break;

      case ImageDestination.addToQueue:
        await _handleAddToQueue(bytes, l10n);
        break;
    }
  }

  void _handleImg2Img(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) {
    notifier.setSourceImage(bytes);
    notifier.updateAction(ImageGenerationAction.img2img);

    if (mounted) {
      AppToast.success(context, l10n.drop_addedToImg2Img);
    }
  }

  Future<void> _handleVibeTransfer(
    String fileName,
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n, {
    bool forceRaw = false,
  }) async {
    try {
      final currentState = ref.read(generationParamsNotifierProvider);
      final currentCount = currentState.vibeReferencesV4.length;
      const maxCount = 16;

      final vibes = await VibeFileParser.parseFile(fileName, bytes);

      if (currentCount + vibes.length > maxCount) {
        if (mounted) {
          AppToast.warning(context, '风格参考已达上限 ($maxCount 张)');
        }
        return;
      }

      for (final vibe in vibes) {
        final vibeToAdd = forceRaw && vibe.vibeEncoding.isNotEmpty
            ? vibe.copyWith(
                vibeEncoding: '',
                rawImageData: bytes,
                sourceType: VibeSourceType.rawImage,
              )
            : vibe;
        notifier.addVibeReference(vibeToAdd);
      }

      if (mounted) {
        final message = _buildVibeMessage(currentCount, vibes.length, l10n);
        AppToast.success(context, message);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error parsing vibe file: $e', 'DropHandler');
      }
      _showError(e.toString());
    }
  }

  String _buildVibeMessage(
    int currentCount,
    int addedCount,
    AppLocalizations l10n,
  ) {
    if (currentCount > 0) {
      return '已追加 $addedCount 个风格参考';
    }
    return addedCount == 1
        ? l10n.drop_addedToVibe
        : l10n.drop_addedMultipleToVibe(addedCount);
  }

  Future<void> _handleVibeReuse(
    VibeReference vibe,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final currentState = ref.read(generationParamsNotifierProvider);
    const maxCount = 16;

    if (currentState.vibeReferencesV4.length >= maxCount) {
      if (mounted) {
        AppToast.warning(context, '风格参考已达上限 ($maxCount 张)');
      }
      return;
    }

    notifier.addVibeReference(vibe);

    if (mounted) {
      final message = currentState.vibeReferencesV4.isNotEmpty
          ? '已追加 1 个风格参考（复用预编码 Vibe）'
          : '已添加风格参考（复用预编码 Vibe，节省 2 Anlas）';
      AppToast.success(context, message);
    }
  }

  void _handleCharacterReference(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) {
    final currentState = ref.read(generationParamsNotifierProvider);
    final hasExisting = currentState.preciseReferences.isNotEmpty;

    if (hasExisting) {
      notifier.clearPreciseReferences();
    }

    notifier.addPreciseReference(
      bytes,
      type: PreciseRefType.character,
      strength: 1.0,
      fidelity: 1.0,
    );

    if (mounted) {
      AppToast.success(
        context,
        hasExisting ? '已替换角色参考' : l10n.drop_addedToCharacterRef,
      );
    }
  }

  Future<void> _handleExtractMetadata(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    try {
      final metadata = await NaiMetadataParser.extractFromBytes(bytes);

      if (metadata == null || !metadata.hasData) {
        if (mounted) {
          AppToast.warning(context, l10n.metadataImport_noDataFound);
        }
        return;
      }

      if (!mounted) return;
      final options =
          await MetadataImportDialog.show(context, metadata: metadata);
      if (options == null || !mounted) return;

      final appliedCount =
          await _applyMetadataWithOptions(metadata, options, notifier);

      if (!mounted) return;

      if (appliedCount > 0) {
        AppToast.success(
          context,
          l10n.metadataImport_appliedCount(appliedCount),
        );
        _showMetadataAppliedDialog(metadata, options, l10n);
      } else {
        AppToast.warning(context, l10n.metadataImport_noParamsSelected);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error extracting metadata: $e', 'DropHandler');
      }
      _showError('提取元数据失败: $e');
    }
  }

  /// 根据选项应用元数据
  Future<int> _applyMetadataWithOptions(
    dynamic metadata,
    MetadataImportOptions options,
    GenerationParamsNotifier notifier,
  ) async {
    var appliedCount = 0;

    // 只有在勾选导入多角色提示词时才清空
    if (options.importCharacterPrompts &&
        metadata.characterPrompts.isNotEmpty) {
      ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    }

    // 应用基础参数
    appliedCount += _applyBasicParams(metadata, options, notifier);

    // 应用多角色提示词
    if (options.importCharacterPrompts &&
        metadata.characterPrompts.isNotEmpty) {
      _applyCharacterPrompts(metadata);
      appliedCount++;
    }

    // 应用高级参数
    appliedCount += _applyAdvancedParams(metadata, options, notifier);

    return appliedCount;
  }

  int _applyBasicParams(
    dynamic metadata,
    MetadataImportOptions options,
    GenerationParamsNotifier notifier,
  ) {
    var count = 0;

    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      notifier.updatePrompt(metadata.prompt);
      count++;
    }

    if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
      notifier.updateNegativePrompt(metadata.negativePrompt);
      count++;
    }

    if (options.importSeed && metadata.seed != null) {
      notifier.updateSeed(metadata.seed!);
      count++;
    }

    if (options.importSteps && metadata.steps != null) {
      notifier.updateSteps(metadata.steps!);
      count++;
    }

    if (options.importScale && metadata.scale != null) {
      notifier.updateScale(metadata.scale!);
      count++;
    }

    if (options.importSize &&
        metadata.width != null &&
        metadata.height != null) {
      notifier.updateSize(metadata.width!, metadata.height!);
      count++;
    }

    return count;
  }

  void _applyCharacterPrompts(dynamic metadata) {
    final characters = <char.CharacterPrompt>[];
    for (var i = 0; i < metadata.characterPrompts.length; i++) {
      final prompt = metadata.characterPrompts[i];
      final negPrompt = i < metadata.characterNegativePrompts.length
          ? metadata.characterNegativePrompts[i]
          : '';

      characters.add(
        char.CharacterPrompt.create(
          name: 'Character ${i + 1}',
          gender: _inferGenderFromPrompt(prompt),
          prompt: prompt,
          negativePrompt: negPrompt,
        ),
      );
    }
    ref.read(characterPromptNotifierProvider.notifier).replaceAll(characters);
  }

  int _applyAdvancedParams(
    dynamic metadata,
    MetadataImportOptions options,
    GenerationParamsNotifier notifier,
  ) {
    var count = 0;

    final params = [
      (options.importSampler, metadata.sampler, notifier.updateSampler),
      (options.importModel, metadata.model, notifier.updateModel),
      (options.importSmea, metadata.smea, notifier.updateSmea),
      (options.importSmeaDyn, metadata.smeaDyn, notifier.updateSmeaDyn),
      (
        options.importNoiseSchedule,
        metadata.noiseSchedule,
        notifier.updateNoiseSchedule
      ),
      (
        options.importCfgRescale,
        metadata.cfgRescale,
        notifier.updateCfgRescale
      ),
      (
        options.importQualityToggle,
        metadata.qualityToggle,
        notifier.updateQualityToggle
      ),
      (options.importUcPreset, metadata.ucPreset, notifier.updateUcPreset),
    ];

    for (final (shouldImport, value, updateFn) in params) {
      if (shouldImport && value != null) {
        updateFn(value);
        count++;
      }
    }

    return count;
  }

  Future<void> _handleAddToQueue(Uint8List bytes, AppLocalizations l10n) async {
    try {
      final metadata = await NaiMetadataParser.extractFromBytes(bytes);

      if (metadata == null || metadata.prompt.isEmpty) {
        if (mounted) {
          AppToast.warning(context, '未找到有效的提示词');
        }
        return;
      }

      final task = ReplicationTask.create(prompt: metadata.prompt);
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

  void _showMetadataAppliedDialog(
    dynamic metadata,
    MetadataImportOptions options,
    AppLocalizations l10n,
  ) {
    final items = _buildMetadataItems(metadata, options, l10n);

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
              ...items,
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

  List<Widget> _buildMetadataItems(
    dynamic metadata,
    MetadataImportOptions options,
    AppLocalizations l10n,
  ) {
    final items = <Widget>[];

    final itemConfigs = [
      (
        options.importPrompt && metadata.prompt.isNotEmpty,
        l10n.metadataImport_prompt,
        metadata.prompt,
        3,
      ),
      (
        options.importNegativePrompt && metadata.negativePrompt.isNotEmpty,
        l10n.metadataImport_negativePrompt,
        metadata.negativePrompt,
        2,
      ),
      (
        options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty,
        l10n.metadataImport_characterPrompts,
        '${metadata.characterPrompts.length} ${l10n.metadataImport_charactersCount}',
        1,
      ),
      (
        options.importSeed && metadata.seed != null,
        l10n.metadataImport_seed,
        metadata.seed?.toString(),
        1
      ),
      (
        options.importSteps && metadata.steps != null,
        l10n.metadataImport_steps,
        metadata.steps?.toString(),
        1
      ),
      (
        options.importScale && metadata.scale != null,
        l10n.metadataImport_scale,
        metadata.scale?.toString(),
        1
      ),
      (
        options.importSize && metadata.width != null && metadata.height != null,
        l10n.metadataImport_size,
        '${metadata.width} x ${metadata.height}',
        1,
      ),
      (
        options.importSampler && metadata.sampler != null,
        l10n.metadataImport_sampler,
        metadata.displaySampler,
        1,
      ),
      (
        options.importModel && metadata.model != null,
        l10n.metadataImport_model,
        metadata.model?.toString(),
        1
      ),
      (
        options.importSmea && metadata.smea != null,
        l10n.metadataImport_smea,
        metadata.smea?.toString(),
        1
      ),
      (
        options.importSmeaDyn && metadata.smeaDyn != null,
        l10n.metadataImport_smeaDyn,
        metadata.smeaDyn?.toString(),
        1
      ),
      (
        options.importNoiseSchedule && metadata.noiseSchedule != null,
        l10n.metadataImport_noiseSchedule,
        metadata.noiseSchedule?.toString(),
        1,
      ),
      (
        options.importCfgRescale && metadata.cfgRescale != null,
        l10n.metadataImport_cfgRescale,
        metadata.cfgRescale?.toString(),
        1,
      ),
    ];

    for (final (shouldShow, label, value, maxLines) in itemConfigs) {
      if (shouldShow && value != null) {
        items.add(_buildAppliedItem(label, value, maxLines: maxLines));
      }
    }

    return items;
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

/// 文件读取参数（用于 Isolate）
class _FileReadParams {
  final String filePath;
  final String fileName;

  _FileReadParams({required this.filePath, required this.fileName});
}