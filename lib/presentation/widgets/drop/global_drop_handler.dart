import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import '../../../data/services/vibe_metadata_service.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../router/app_router.dart';
import '../../utils/dropped_file_reader.dart';
import '../../utils/metadata_import_coordinator.dart';
import '../common/app_toast.dart';
import '../metadata/metadata_import_dialog.dart';
import 'image_destination_dialog.dart';
import 'tag_library_drop_handler.dart';

Future<void> appendDroppedCharacterReference({
  required GenerationParamsNotifier notifier,
  required Uint8List image,
}) {
  // addPreciseReferenceFromImage stages the original bytes before its first
  // await, then replaces them after Director Reference normalization finishes.
  unawaited(
    notifier.addPreciseReferenceFromImage(
      image,
      type: PreciseRefType.characterAndStyle,
      strength: 1.0,
      fidelity: 1.0,
    ),
  );
  return Future<void>.value();
}

Future<NaiImageMetadata?> detectImportableDroppedImageMetadata(
  String fileName,
  Uint8List bytes,
) async {
  if (!fileName.toLowerCase().endsWith('.png')) return null;

  try {
    final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);
    if (metadata != null && metadata.hasData) {
      AppLogger.i(
        'Detected NovelAI metadata in dropped image: $fileName',
        'DropHandler',
      );
      return metadata;
    }
  } catch (e) {
    AppLogger.d('Failed to detect NovelAI metadata: $e', 'DropHandler');
  }
  return null;
}

class _PasteImageIntent extends Intent {
  const _PasteImageIntent();
}

/// 全局拖拽处理器
///
/// 包装整个生成界面，监听拖拽事件
/// 当用户拖拽图片到界面任意位置时，弹出选择对话框
class GlobalDropHandler extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalDropHandler({super.key, required this.child});

  @override
  ConsumerState<GlobalDropHandler> createState() => _GlobalDropHandlerState();
}

class _GlobalDropHandlerState extends ConsumerState<GlobalDropHandler> {
  bool _isDragging = false;
  bool _isProcessing = false;
  bool _isReadingClipboard = false;

  Future<void> _handlePasteShortcut(VoidCallback? fallbackTextPaste) async {
    if (_isReadingClipboard || _isProcessing) {
      fallbackTextPaste?.call();
      return;
    }

    _isReadingClipboard = true;
    try {
      final pastedFile = await _safeReadClipboardFile();
      if (pastedFile == null) {
        fallbackTextPaste?.call();
        return;
      }

      _showProcessingIndicator();
      try {
        await _processDroppedFile(pastedFile.fileName, pastedFile.bytes);
      } finally {
        _hideProcessingIndicator();
      }
    } finally {
      _isReadingClipboard = false;
    }
  }

  Future<DroppedFileData?> _safeReadClipboardFile() async {
    try {
      return await _readClipboardFile();
    } catch (e) {
      AppLogger.d(
        'Failed to inspect clipboard for pasted image: $e',
        'ClipboardPaste',
      );
      return null;
    }
  }

  Future<DroppedFileData?> _readClipboardFile() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }

    final clipboardReader = await clipboard.read();
    for (final item in clipboardReader.items) {
      final fileData = await DroppedFileReader.read(
        item,
        allowVibeFiles: true,
        allowRemoteImages: false,
        logTag: 'ClipboardPaste',
      );
      if (fileData != null) {
        return fileData;
      }
    }
    return null;
  }

  VoidCallback? _createTextPasteFallback(BuildContext? focusedContext) {
    if (focusedContext == null) {
      return null;
    }
    return () {
      if (!focusedContext.mounted) {
        return;
      }
      Actions.maybeInvoke(
        focusedContext,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _PasteImageIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _PasteImageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PasteImageIntent: CallbackAction<_PasteImageIntent>(
            onInvoke: (intent) {
              final fallbackTextPaste = _createTextPasteFallback(
                FocusManager.instance.primaryFocus?.context,
              );
              unawaited(_handlePasteShortcut(fallbackTextPaste));
              return null;
            },
          ),
        },
        child: DropRegion(
          formats: Formats.standardFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: (event) {
            // 检查是否是应用内部拖拽（本地画廊拖拽图片）
            // 内部拖拽包含 localData，外部拖拽没有
            final isInternalDrag = event.session.items.any(
              (item) => item.localData != null,
            );

            // 如果是内部拖拽，不显示全局覆盖层
            if (isInternalDrag) {
              return DropOperation.none;
            }

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
              // 处理中覆盖层
              if (_isProcessing) _buildProcessingOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
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

  /// 构建处理中覆盖层
  Widget _buildProcessingOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.drop_processing,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    // 显示处理中提示
    _showProcessingIndicator();

    try {
      var handledAny = false;
      for (final item in event.session.items) {
        final reader = item.dataReader;
        if (reader == null) continue;

        final fileData = await DroppedFileReader.read(
          reader,
          allowVibeFiles: true,
          logTag: 'DropHandler',
        );
        if (fileData != null) {
          handledAny = true;
          await _processDroppedFile(fileData.fileName, fileData.bytes);
        }
      }
      if (!handledAny && mounted) {
        _showError(context.l10n.toast_unreadableDroppedImageSource);
      }
    } finally {
      // 关闭处理中提示
      _hideProcessingIndicator();
    }
  }

  /// 显示处理中指示器
  void _showProcessingIndicator() {
    if (!mounted) return;
    setState(() => _isProcessing = true);
  }

  /// 隐藏处理中指示器
  void _hideProcessingIndicator() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  Future<void> _processDroppedFile(String fileName, Uint8List bytes) async {
    if (!mounted) return;

    // 检查是否为支持的文件类型
    if (!VibeFileParser.isSupportedFile(fileName)) {
      _showError(context.l10n.drop_unsupportedFormat);
      return;
    }

    // 检测当前是否为词库页面
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
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
    final detectedMetadata = await detectImportableDroppedImageMetadata(
      fileName,
      bytes,
    );
    final showExtractMetadata = detectedMetadata != null;

    // 检测是否包含 Vibe 元数据（仅 PNG）
    final detectedVibe = await _detectVibeMetadata(fileName, bytes);

    // 检测是否为 bundle（多个 vibes）
    final detectedVibes = await _detectAllVibesInPng(fileName, bytes);

    if (!mounted) return;

    // 显示目标选择对话框
    final destination = await ImageDestinationDialog.show(
      context,
      imageBytes: bytes,
      fileName: fileName,
      showExtractMetadata: showExtractMetadata,
      detectedVibe: detectedVibe,
      isBundle: detectedVibes.length > 1,
    );

    if (destination == null || !mounted) return;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);

    await _handleDestination(
      destination,
      fileName,
      bytes,
      detectedVibe,
      detectedVibes,
      detectedMetadata,
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

  /// 检测 PNG 中所有 Vibe 数据（支持 Bundle）
  Future<List<VibeReference>> _detectAllVibesInPng(
    String fileName,
    Uint8List bytes,
  ) async {
    if (!fileName.toLowerCase().endsWith('.png')) return [];

    try {
      final vibeService = VibeMetadataService();
      final vibes = await vibeService.extractAllVibesFromImage(bytes);
      if (vibes.isNotEmpty) {
        AppLogger.i(
          'Detected ${vibes.length} Vibes in dropped image: ${vibes.map((v) => v.displayName).join(", ")}',
          'DropHandler',
        );
      }
      return vibes;
    } catch (e) {
      AppLogger.d('Failed to detect all Vibes: $e', 'DropHandler');
      return [];
    }
  }

  Future<void> _handleDestination(
    ImageDestination destination,
    String fileName,
    Uint8List bytes,
    VibeReference? detectedVibe,
    List<VibeReference> detectedVibes,
    NaiImageMetadata? detectedMetadata,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    switch (destination) {
      case ImageDestination.img2img:
        await _handleImg2Img(bytes, l10n);
        break;

      case ImageDestination.reversePrompt:
        await _handleReversePrompt(fileName, bytes, l10n);
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

      case ImageDestination.saveToVibeLibrary:
        if (detectedVibes.isNotEmpty) {
          await _handleSaveToVibeLibrary(detectedVibes, l10n);
        }
        break;

      case ImageDestination.characterReference:
        await _handleCharacterReference(bytes, notifier, l10n);
        break;

      case ImageDestination.extractMetadata:
        await _handleExtractMetadata(detectedMetadata, bytes, l10n);
        break;

      case ImageDestination.addToQueue:
        await _handleAddToQueue(detectedMetadata, bytes, l10n);
        break;
    }
  }

  Future<void> _handleImg2Img(Uint8List bytes, AppLocalizations l10n) async {
    await ref
        .read(imageWorkflowControllerProvider.notifier)
        .replaceSourceImageAsync(bytes);

    if (mounted) {
      AppToast.success(context, l10n.drop_addedToImg2Img);
    }
  }

  Future<void> _handleReversePrompt(
    String fileName,
    Uint8List bytes,
    AppLocalizations l10n,
  ) async {
    await ref
        .read(reversePromptProvider.notifier)
        .addImage(bytes, name: fileName);

    if (mounted) {
      AppToast.success(context, l10n.drop_addedToReversePrompt);
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
          AppToast.warning(
            context,
            context.l10n.toast_styleReferenceLimit(maxCount),
          );
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
      return l10n.toast_appendedStyleReferences(addedCount);
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
        AppToast.warning(
          context,
          context.l10n.toast_styleReferenceLimit(maxCount),
        );
      }
      return;
    }

    notifier.addVibeReference(vibe);

    if (mounted) {
      final message = currentState.vibeReferencesV4.isNotEmpty
          ? l10n.toast_appendedPreencodedVibe
          : l10n.toast_addedPreencodedVibe;
      AppToast.success(context, message);
    }
  }

  /// 保存预编码 Vibe 到库（支持 Bundle）
  Future<void> _handleSaveToVibeLibrary(
    List<VibeReference> vibes,
    AppLocalizations l10n,
  ) async {
    if (vibes.isEmpty) return;

    // 检查是否有有效的编码数据
    final invalidVibes = vibes.where((v) => v.vibeEncoding.isEmpty).toList();
    if (invalidVibes.isNotEmpty) {
      AppToast.warning(
        context,
        l10n.toast_vibesMissingEncoding(invalidVibes.length),
      );
      return;
    }

    final isBundle = vibes.length > 1;
    final defaultName = isBundle
        ? vibes.first.displayName
        : vibes.first.displayName;

    // 显示保存对话框
    final nameController = TextEditingController(text: defaultName);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isBundle ? '保存 Vibe Bundle (${vibes.length} 个)' : '保存到 Vibe 库',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBundle)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '包含以下 Vibe：\n${vibes.map((v) => '• ${v.displayName}').join('\n')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '输入保存名称',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(l10n.common_save),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final storageService = ref.read(vibeLibraryStorageServiceProvider);

        if (isBundle) {
          // 保存为 Bundle
          await storageService.saveBundleEntry(
            vibes,
            name: nameController.text.trim(),
          );
        } else {
          // 保存单个 Vibe
          final entry = VibeLibraryEntry.fromVibeReference(
            name: nameController.text.trim(),
            vibeData: vibes.first,
          );
          await storageService.saveEntry(entry);
        }

        // 刷新库
        ref.read(vibeLibraryNotifierProvider.notifier).reload();

        if (mounted) {
          AppToast.success(
            context,
            isBundle
                ? l10n.toast_savedBundle(vibes.length)
                : l10n.toast_savedToVibeLibrary,
          );
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
        }
      }
    }
  }

  Future<void> _handleCharacterReference(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    await appendDroppedCharacterReference(notifier: notifier, image: bytes);

    if (mounted) {
      AppToast.success(context, l10n.drop_addedToCharacterRef);
    }
  }

  Future<void> _handleExtractMetadata(
    NaiImageMetadata? detectedMetadata,
    Uint8List bytes,
    AppLocalizations l10n,
  ) async {
    try {
      final metadata =
          detectedMetadata ??
          await ImageMetadataService().getMetadataFromBytes(bytes);

      if (metadata == null || !metadata.hasData) {
        if (mounted) {
          AppToast.warning(context, l10n.metadataImport_noDataFound);
        }
        return;
      }

      if (!mounted) return;
      final options = await MetadataImportDialog.show(
        context,
        metadata: metadata,
      );
      if (options == null || !mounted) return;

      final appliedCount = await MetadataImportCoordinator.apply(
        read: ref.read,
        metadata: metadata,
        options: options,
      );

      if (!mounted) return;

      if (appliedCount > 0) {
        AppToast.success(
          context,
          l10n.metadataImport_appliedCount(appliedCount),
        );
        unawaited(
          MetadataImportCoordinator.showAppliedDialog(
            context: context,
            metadata: metadata,
            options: options,
            l10n: l10n,
            currentModel: ref.read(generationParamsNotifierProvider).model,
          ),
        );
      } else {
        AppToast.warning(context, l10n.metadataImport_noParamsSelected);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error extracting metadata: $e', 'DropHandler');
      }
      _showError(l10n.toast_extractMetadataFailed(e.toString()));
    }
  }

  Future<void> _handleAddToQueue(
    NaiImageMetadata? detectedMetadata,
    Uint8List bytes,
    AppLocalizations l10n,
  ) async {
    try {
      final metadata =
          detectedMetadata ??
          await ImageMetadataService().getMetadataFromBytes(bytes);

      if (metadata == null || metadata.prompt.isEmpty) {
        if (mounted) {
          AppToast.warning(context, context.l10n.toast_noValidPromptFound);
        }
        return;
      }

      final task = ReplicationTask.create(prompt: metadata.prompt);
      ref.read(replicationQueueNotifierProvider.notifier).add(task);

      if (mounted) {
        final displayPrompt = metadata.prompt.length > 50
            ? '${metadata.prompt.substring(0, 50)}...'
            : metadata.prompt;
        AppToast.success(
          context,
          context.l10n.toast_addedToQueue(displayPrompt),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error adding to queue: $e', 'DropHandler');
      }
      _showError(l10n.toast_extractPromptFailed(e.toString()));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }
}
