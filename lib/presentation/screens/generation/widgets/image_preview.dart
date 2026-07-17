import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/file_explorer_utils.dart';
import '../../../../core/utils/image_save_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../../../../core/utils/prompt_preset_resolution.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/image/image_stream_chunk.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../../data/services/image_metadata_service.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/character_panel_dock_provider.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../providers/quality_preset_provider.dart';
import '../../../providers/reverse_prompt_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../providers/uc_preset_provider.dart';
import '../../../services/image_workflow_launcher.dart';
import '../../../widgets/character/character_card_grid.dart';
import '../../../widgets/character/character_edit_dialog.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/draggable_memory_image.dart';
import '../../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_viewer.dart';
import '../../../widgets/common/selectable_image_card.dart';
import '../../../widgets/common/themed_switch.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import '../../../utils/image_detail_opener.dart';
import '../../../utils/krita_send_helper.dart';
import '../../tag_library_page/widgets/entry_add_dialog.dart';
import '../../../widgets/tag_library/tag_library_picker_dialog.dart';

/// 图像预览组件
class ImagePreviewWidget extends ConsumerStatefulWidget {
  const ImagePreviewWidget({super.key});

  @override
  ConsumerState<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends ConsumerState<ImagePreviewWidget> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);

    // 使用 GestureDetector 吸收整个区域的点击事件，避免 Windows 系统提示音
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // 空回调，仅吸收点击
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Center(child: _buildContent(context, ref, state, theme)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ImageGenerationState state,
    ThemeData theme,
  ) {
    // 检查角色面板停靠状态
    final isDocked = ref.watch(characterPanelDockProvider);
    if (isDocked) {
      return const _DockedCharacterPanel();
    }

    // 错误状态
    if (state.status == GenerationStatus.error) {
      return _buildErrorState(theme, state.errorMessage, context);
    }

    // 使用批次分辨率（点击生成时捕获），fallback 到全局参数
    final previewDimensions = ref.watch(
      generationParamsNotifierProvider.select(selectPreviewDimensionsViewData),
    );
    final batchWidth = state.batchWidth ?? previewDimensions.width;
    final batchHeight = state.batchHeight ?? previewDimensions.height;

    // 生成中状态
    if (state.isGenerating) {
      final previewSlots = _visibleStreamPreviewSlots(state);
      // 如果有已完成图像或当前请求有多个预览槽位，显示网格视图。
      if (state.currentImages.isNotEmpty || previewSlots.length > 1) {
        return _buildGeneratingWithCompletedImages(
          context,
          ref,
          state,
          theme,
          batchWidth,
          batchHeight,
        );
      }
      // 否则只显示生成中卡片
      return _buildSingleGeneratingState(
        context,
        state,
        theme,
        batchWidth,
        batchHeight,
      );
    }

    // 有图像：根据数量决定布局（使用 displayImages）
    if (state.hasImages) {
      if (state.displayImages.length == 1) {
        // 单图：居中显示
        return _buildImageView(context, ref, state.displayImages.first, theme);
      } else {
        // 多图：自适应网格
        return _buildMultiImageGrid(context, ref, state.displayImages, theme);
      }
    }

    // 空状态
    return _buildEmptyState(theme, context);
  }

  /// 计算自适应列数（基于可用宽度和最小/最大卡片尺寸）
  int _calculateColumnCount(int imageCount, double availableWidth) {
    // 最小卡片宽度: 150px，最大卡片宽度: 280px
    const minCardWidth = 150.0;
    const maxCardWidth = 280.0;
    const spacing = 12.0;

    // 计算基于图片数量的理想列数
    int idealColumns;
    if (imageCount <= 2) {
      idealColumns = 2;
    } else if (imageCount <= 4) {
      idealColumns = 2;
    } else if (imageCount <= 6) {
      idealColumns = 3;
    } else {
      idealColumns = 4;
    }

    // 根据可用宽度调整列数，确保卡片尺寸在合理范围内
    // 计算每种列数下的卡片宽度
    for (int cols = idealColumns; cols >= 2; cols--) {
      final cardWidth =
          (availableWidth - spacing * (cols - 1) - 16) / cols; // 16 = padding
      if (cardWidth >= minCardWidth && cardWidth <= maxCardWidth) {
        return cols;
      }
    }

    // 如果空间不足，尝试更多列数
    for (int cols = idealColumns + 1; cols <= 6; cols++) {
      final cardWidth = (availableWidth - spacing * (cols - 1) - 16) / cols;
      if (cardWidth >= minCardWidth) {
        return cols;
      }
    }

    // 回退到理想列数
    return idealColumns;
  }

  List<StreamPreviewSlot> _visibleStreamPreviewSlots(
    ImageGenerationState state,
  ) {
    final completedCount = state.currentImages.length;
    return [
      for (final slot in state.streamPreviewSlots)
        if (slot.imageNumber > completedCount) slot,
    ]..sort((a, b) => a.imageNumber.compareTo(b.imageNumber));
  }

  Widget _buildGeneratingCard({
    required int imageWidth,
    required int imageHeight,
    required int currentImage,
    required int totalImages,
    required double progress,
    Uint8List? streamPreview,
    FocusedStreamPreviewPlacement? focusedPreviewPlacement,
  }) {
    return SelectableImageCard(
      isGenerating: true,
      currentImage: currentImage,
      totalImages: totalImages,
      progress: progress,
      streamPreview: streamPreview,
      focusedPreviewPlacement: focusedPreviewPlacement,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      enableSelection: false,
    );
  }

  /// 构建多图网格视图
  Widget _buildMultiImageGrid(
    BuildContext context,
    WidgetRef ref,
    List<GeneratedImage> images,
    ThemeData theme,
  ) {
    // 使用第一张图像的宽高比（同一批次图像分辨率相同）
    final aspectRatio = images.isNotEmpty ? images.first.aspectRatio : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateColumnCount(
          images.length,
          constraints.maxWidth,
        );

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return _buildGeneratedImageCard(
              context: context,
              ref: ref,
              image: image,
              index: index,
              showIndex: true,
            );
          },
        );
      },
    );
  }

  /// 生成中 + 有已完成图像的混合视图
  Widget _buildGeneratingWithCompletedImages(
    BuildContext context,
    WidgetRef ref,
    ImageGenerationState state,
    ThemeData theme,
    int imageWidth,
    int imageHeight,
  ) {
    final completedImages = state.currentImages;
    final previewSlots = _visibleStreamPreviewSlots(state);
    final generatingCount = previewSlots.isNotEmpty ? previewSlots.length : 1;
    final totalItems = completedImages.length + generatingCount;
    final aspectRatio = imageWidth / imageHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateColumnCount(
          totalItems,
          constraints.maxWidth,
        );

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            // 已完成的图像
            if (index < completedImages.length) {
              final image = completedImages[index];
              return _buildGeneratedImageCard(
                context: context,
                ref: ref,
                image: image,
                index: index,
                showIndex: true,
              );
            }

            final generationIndex = index - completedImages.length;
            if (previewSlots.isNotEmpty &&
                generationIndex < previewSlots.length) {
              final slot = previewSlots[generationIndex];
              return _buildGeneratingCard(
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                currentImage: slot.imageNumber,
                totalImages: slot.totalImages,
                progress: slot.progress,
                streamPreview: slot.previewBytes,
                focusedPreviewPlacement: slot.focusedPreviewPlacement,
              );
            }

            return _buildGeneratingCard(
              imageWidth: imageWidth,
              imageHeight: imageHeight,
              currentImage: state.currentImage,
              totalImages: state.totalImages,
              progress: state.progress,
              streamPreview: state.streamPreview,
              focusedPreviewPlacement: state.focusedPreviewPlacement,
            );
          },
        );
      },
    );
  }

  /// 生成中的居中显示（无已完成图像时）
  Widget _buildSingleGeneratingState(
    BuildContext context,
    ImageGenerationState state,
    ThemeData theme,
    int imageWidth,
    int imageHeight,
  ) {
    final aspectRatio = imageWidth / imageHeight;
    final previewSlots = _visibleStreamPreviewSlots(state);
    final slot = previewSlots.isNotEmpty ? previewSlots.first : null;
    return _buildSingleAspectRatioCard(
      aspectRatio: aspectRatio,
      child: _buildGeneratingCard(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        currentImage: slot?.imageNumber ?? state.currentImage,
        totalImages: slot?.totalImages ?? state.totalImages,
        progress: slot?.progress ?? state.progress,
        streamPreview: slot?.previewBytes ?? state.streamPreview,
        focusedPreviewPlacement:
            slot?.focusedPreviewPlacement ?? state.focusedPreviewPlacement,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          size: 80,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.generation_emptyPromptHint,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.generation_imageWillShowHere,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    String? message,
    BuildContext context,
  ) {
    // 解析错误代码和详情
    final (errorTitle, errorHint) = _parseApiError(message, context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          errorTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        if (errorHint != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// 解析 API 错误代码，返回 (标题, 提示)
  (String, String?) _parseApiError(String? message, BuildContext context) {
    if (message == null || message.isEmpty) {
      return (context.l10n.generation_generationFailed, null);
    }

    // 取消操作
    if (message == 'Cancelled') {
      return (context.l10n.generation_cancelGeneration, null);
    }

    // 解析错误代码格式: "ERROR_CODE|详情"
    final parts = message.split('|');
    final errorCode = parts[0];
    final details = parts.length > 1 ? parts[1] : null;

    switch (errorCode) {
      case 'API_ERROR_429':
        return (context.l10n.api_error_429, context.l10n.api_error_429_hint);
      case 'API_ERROR_401':
        return (context.l10n.api_error_401, context.l10n.api_error_401_hint);
      case 'API_ERROR_402':
        return (context.l10n.api_error_402, context.l10n.api_error_402_hint);
      case 'API_ERROR_400':
        return ('${context.l10n.common_error} (400)', details);
      case 'API_ERROR_500':
        return (context.l10n.api_error_500, context.l10n.api_error_500_hint);
      case 'API_ERROR_503':
        return (context.l10n.api_error_503, context.l10n.api_error_503_hint);
      case 'API_ERROR_TIMEOUT':
        return (
          context.l10n.api_error_timeout,
          context.l10n.api_error_timeout_hint,
        );
      case 'API_ERROR_NETWORK':
        return (
          context.l10n.api_error_network,
          context.l10n.api_error_network_hint,
        );
      default:
        // 未知错误或其他 HTTP 错误
        if (errorCode.startsWith('API_ERROR_HTTP_')) {
          final code = errorCode.replaceFirst('API_ERROR_HTTP_', '');
          return ('${context.l10n.common_error} (HTTP $code)', details);
        }
        return (context.l10n.generation_generationFailed, message);
    }
  }

  Widget _buildImageView(
    BuildContext context,
    WidgetRef ref,
    GeneratedImage image,
    ThemeData theme,
  ) {
    return _buildSingleAspectRatioCard(
      aspectRatio: image.aspectRatio,
      child: _buildGeneratedImageCard(
        context: context,
        ref: ref,
        image: image,
        showIndex: false,
      ),
    );
  }

  Widget _buildGeneratedImageCard({
    required BuildContext context,
    required WidgetRef ref,
    required GeneratedImage image,
    required bool showIndex,
    int? index,
  }) {
    final imageBytes = image.bytes;
    final canUseAsInput = image.canUseAsGenerationInput;
    final isFailedSnapshot = image.isFailedStreamSnapshot;

    final card = SelectableImageCard(
      imageBytes: imageBytes,
      sourceFilePath: image.filePath,
      index: index,
      showIndex: showIndex,
      enableSelection: false,
      enableSaveAction: image.canSave,
      enableCopyAction: image.canSave,
      statusBadgeLabel: isFailedSnapshot
          ? context.l10n.generation_failedStreamSnapshot
          : null,
      statusBadgeTooltip: isFailedSnapshot
          ? context.l10n.generation_failedStreamSnapshotHint
          : null,
      onTap: () => _showFullscreenImage(imageBytes),
      onReversePrompt: canUseAsInput
          ? () => unawaited(_sendPreviewImageToReversePrompt(context, image))
          : null,
      onImageToImage: canUseAsInput
          ? () => _sendPreviewImageToImageToImage(context, image)
          : null,
      onVibeTransfer: canUseAsInput
          ? () => unawaited(_sendPreviewImageToVibeTransfer(context, image))
          : null,
      onPreciseReference: canUseAsInput
          ? () => unawaited(_sendPreviewImageToPreciseReference(context, image))
          : null,
      onEditImage: canUseAsInput
          ? () => ImageWorkflowLauncher.openEditor(
              context,
              ref,
              imageBytes,
              mode: ImageEditorMode.edit,
            )
          : null,
      onInpaint: canUseAsInput
          ? () => ImageWorkflowLauncher.openInpaint(context, ref, imageBytes)
          : null,
      onGenerateVariations: canUseAsInput
          ? () => ImageWorkflowLauncher.generateVariations(
              context,
              ref,
              imageBytes,
            )
          : null,
      onDirectorTools: canUseAsInput
          ? () => ImageWorkflowLauncher.openDirectorTools(
              context,
              ref,
              imageBytes,
            )
          : null,
      onEnhance: canUseAsInput
          ? () => ImageWorkflowLauncher.openEnhance(ref, imageBytes)
          : null,
      onUpscale: canUseAsInput
          ? () => ImageWorkflowLauncher.openUpscale(ref, imageBytes)
          : null,
      onSendToKrita: canUseAsInput
          ? () => KritaSendHelper.sendImageBytes(
              context,
              ref,
              imageBytes,
              name: _previewImageFileName(image),
            )
          : null,
      onOpenInExplorer: image.canSave
          ? () => _openImageInExplorer(context, image)
          : null,
      onSaveToLibrary: canUseAsInput
          ? (bytes, _) => _showSaveToLibraryDialog(context, bytes)
          : null,
    );

    if (!image.canDrag) {
      return card;
    }

    return DraggableMemoryImage(
      imageBytes: imageBytes,
      fileName: _previewImageFileName(image),
      sourceFilePath: image.filePath,
      child: card,
    );
  }

  String _previewImageFileName(GeneratedImage image) {
    final filePath = image.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return p.basename(filePath);
    }
    return 'generation_${image.id}.png';
  }

  Future<void> _sendPreviewImageToReversePrompt(
    BuildContext context,
    GeneratedImage image,
  ) async {
    final l10n = context.l10n;

    try {
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(image.bytes, name: _previewImageFileName(image));

      if (!context.mounted) return;
      AppToast.success(context, l10n.drop_addedToReversePrompt);
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, l10n.gallery_sendFailed(e.toString()));
      }
    }
  }

  void _sendPreviewImageToImageToImage(
    BuildContext context,
    GeneratedImage image,
  ) {
    ImageWorkflowLauncher.openImageToImage(ref, image.bytes);
    AppToast.success(context, context.l10n.drop_addedToImg2Img);
  }

  Future<void> _sendPreviewImageToVibeTransfer(
    BuildContext context,
    GeneratedImage image,
  ) async {
    final l10n = context.l10n;

    try {
      final currentState = ref.read(generationParamsNotifierProvider);
      final currentCount = currentState.vibeReferencesV4.length;
      const maxCount = 16;
      final vibes = await VibeFileParser.parseFile(
        _previewImageFileName(image),
        image.bytes,
      );

      if (!context.mounted) return;
      if (currentCount + vibes.length > maxCount) {
        AppToast.warning(context, l10n.toast_styleReferenceLimit(maxCount));
        return;
      }

      ref
          .read(generationParamsNotifierProvider.notifier)
          .addVibeReferences(vibes);

      final message = currentCount > 0
          ? l10n.toast_appendedStyleReferences(vibes.length)
          : vibes.length == 1
          ? l10n.drop_addedToVibe
          : l10n.drop_addedMultipleToVibe(vibes.length);
      AppToast.success(context, message);
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '${l10n.vibeParseFailed}: $e');
      }
    }
  }

  Future<void> _sendPreviewImageToPreciseReference(
    BuildContext context,
    GeneratedImage image,
  ) async {
    final l10n = context.l10n;

    try {
      await ref
          .read(generationParamsNotifierProvider.notifier)
          .addPreciseReferenceFromImage(
            image.bytes,
            type: PreciseRefType.character,
            strength: 1.0,
            fidelity: 1.0,
          );

      if (!context.mounted) return;
      AppToast.success(context, l10n.drop_addedToCharacterRef);
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, l10n.gallery_sendFailed(e.toString()));
      }
    }
  }

  /// 在文件夹中定位图片。已保存的图片直接定位原文件，未保存时先保存再定位。
  Future<void> _openImageInExplorer(
    BuildContext context,
    GeneratedImage image,
  ) async {
    try {
      final existingPath = image.filePath;
      if (existingPath != null &&
          existingPath.isNotEmpty &&
          await File(existingPath).exists()) {
        await FileExplorerUtils.revealFile(existingPath);
        return;
      }

      final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
      if (saveDirPath == null) return;
      final saveDir = Directory(saveDirPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(saveDirPath, fileName));
      await file.writeAsBytes(image.bytes);

      ref.read(localGalleryNotifierProvider.notifier).refresh();
      await FileExplorerUtils.revealFile(file.path);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDirPath));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  Widget _buildSingleAspectRatioCard({
    required double aspectRatio,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = _fitAspectRatio(
          aspectRatio: aspectRatio,
          maxSize: Size(constraints.maxWidth, constraints.maxHeight),
        );

        return Center(
          child: SizedBox(
            width: cardSize.width,
            height: cardSize.height,
            child: child,
          ),
        );
      },
    );
  }

  Size _fitAspectRatio({required double aspectRatio, required Size maxSize}) {
    final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : 1.0;
    final maxWidth = maxSize.width.isFinite ? max(0.0, maxSize.width) : 500.0;
    final maxHeight = maxSize.height.isFinite
        ? max(0.0, maxSize.height)
        : 650.0;

    var width = maxWidth;
    var height = width / safeAspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * safeAspectRatio;
    }

    return Size(
      width.clamp(0.0, maxWidth).toDouble(),
      height.clamp(0.0, maxHeight).toDouble(),
    );
  }

  /// 显示保存到词库对话框
  Future<void> _showSaveToLibraryDialog(
    BuildContext context,
    Uint8List bytes,
  ) async {
    final params = ref.read(generationParamsNotifierProvider);
    final characterConfig = ref.read(characterPromptNotifierProvider);

    // 使用竖线格式合并正面提示词和角色提示词
    final positivePrompt = params.prompt;
    final enabledCharacters = characterConfig.characters
        .where((c) => c.enabled && c.prompt.isNotEmpty)
        .toList();

    final String combinedPrompt;
    if (enabledCharacters.isEmpty) {
      combinedPrompt = positivePrompt;
    } else {
      // 使用竖线格式：主提示词 | 角色1 | 角色2
      final buffer = StringBuffer(positivePrompt);
      for (final char in enabledCharacters) {
        buffer.write('\n| ${char.prompt}');
      }
      combinedPrompt = buffer.toString();
    }

    // 解析别名引用，保存实际内容到词库
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
    final resolvedPrompt = aliasResolver.resolveAliases(combinedPrompt);

    final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);

    if (!context.mounted) return;

    await EntryAddDialog.show(
      context,
      categories: tagLibraryState.categories,
      initialContent: resolvedPrompt,
      initialImageBytes: bytes,
    );
  }

  Future<void> _showFullscreenImage(Uint8List imageBytes) async {
    final state = ref.read(imageGenerationNotifierProvider);

    // 找到当前点击图像的索引
    final initialIndex = state.displayImages
        .indexWhere((img) => img.bytes == imageBytes)
        .clamp(0, state.displayImages.length - 1);

    // 简化逻辑：统一使用 FileImageDetailData 从 PNG 文件解析
    // - 已保存的图像直接使用 filePath
    // - 未保存的图像使用 GeneratedImageDetailData 作为 fallback
    final allImages = state.displayImages.map((img) {
      if (img.filePath != null && img.filePath!.isNotEmpty) {
        // 加入预加载队列（如果尚未解析）
        ImageMetadataService().enqueuePreload(
          taskId: img.id,
          filePath: img.filePath,
        );
        return FileImageDetailData(
          filePath: img.filePath!,
          cachedBytes: img.bytes,
          id: img.id,
          initialMetadata: img.metadata,
          showCopyButton: img.canSave,
        );
      }

      // 未保存的图像：使用 GeneratedImageDetailData 作为 fallback
      return GeneratedImageDetailData(
        imageBytes: img.bytes,
        metadata: img.metadata,
        id: img.id,
        showSaveButton: img.canSave,
        showCopyButton: img.canSave,
      );
    }).toList();

    // 使用 ImageDetailOpener 打开详情页
    ImageDetailOpener.showMultipleImmediate(
      context,
      images: allImages,
      initialIndex: initialIndex,
      showMetadataPanel: true,
      showThumbnails: allImages.length > 1,
      callbacks: ImageDetailCallbacks(
        onSave: (image) async {
          if (!image.showSaveButton) return;
          await _saveImage(context, image);
        },
      ),
    );
  }

  /// 获取保存目录
  Future<Directory?> _getSaveDirectory() async {
    final dirPath = await GalleryFolderRepository.instance.getRootPath();
    if (dirPath == null) return null;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存图像
  Future<void> _saveImage(BuildContext context, ImageDetailData image) async {
    try {
      final imageBytes = await image.getImageBytes();
      final saveDir = await _getSaveDirectory();
      if (saveDir == null) return;
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${saveDir.path}/$fileName';

      if (ImageSaveUtils.hasEmbeddedNovelAiMetadata(imageBytes)) {
        await File(filePath).writeAsBytes(imageBytes);
      } else {
        final params = ref.read(generationParamsNotifierProvider);
        final characterConfig = ref.read(characterPromptNotifierProvider);
        final fixedTagsState = ref.read(fixedTagsNotifierProvider);

        // 解析别名
        final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
        final resolvedPrompt = aliasResolver.resolveAliases(params.prompt);
        final resolvedNegative = aliasResolver.resolveAliases(
          params.negativePrompt,
        );
        final promptWithFixedTags = fixedTagsState.applyToPrompt(
          resolvedPrompt,
        );
        final negativePromptWithFixedTags = fixedTagsState
            .applyToNegativePrompt(resolvedNegative);
        final qualityState = ref.read(qualityPresetNotifierProvider);
        final qualityContent = ref
            .read(qualityPresetNotifierProvider.notifier)
            .getEffectiveContent(params.model);
        final ucState = ref.read(ucPresetNotifierProvider);
        final ucPresetContent = ref
            .read(ucPresetNotifierProvider.notifier)
            .getEffectiveContent(params.model);
        final presetResolution = resolvePromptPresetSettings(
          prompt: promptWithFixedTags,
          negativePrompt: negativePromptWithFixedTags,
          qualityMode: qualityState.mode,
          qualityContent: qualityContent,
          ucPresetType: ucState.presetType,
          ucPresetContent: ucPresetContent,
          useCustomUcPreset: ucState.isCustom,
        );

        // 尝试从图片元数据中提取实际的 seed
        int actualSeed = params.seed;
        if (actualSeed == -1) {
          final extractedMeta = await ImageMetadataService()
              .getMetadataFromBytes(imageBytes);
          if (extractedMeta != null &&
              extractedMeta.seed != null &&
              extractedMeta.seed! > 0) {
            actualSeed = extractedMeta.seed!;
          } else {
            actualSeed = Random().nextInt(4294967295);
          }
        }

        // 构建 V4 多角色提示词结构（解析别名）
        final charCaptions = <Map<String, dynamic>>[];
        final charNegCaptions = <Map<String, dynamic>>[];

        for (final char in characterConfig.characters.where(
          (c) => c.enabled && c.prompt.isNotEmpty,
        )) {
          charCaptions.add({
            'char_caption': aliasResolver.resolveAliases(char.prompt),
            'centers': [
              {'x': 0.5, 'y': 0.5},
            ],
          });
          charNegCaptions.add({
            'char_caption': aliasResolver.resolveAliases(char.negativePrompt),
            'centers': [
              {'x': 0.5, 'y': 0.5},
            ],
          });
        }

        final encodedSize = NaiResolutionAdapter.readImageSize(imageBytes);
        final paramsForSave = params.copyWith(
          prompt: presetResolution.prompt,
          negativePrompt: presetResolution.negativePrompt,
          qualityToggle: presetResolution.qualityToggle,
          ucPreset: presetResolution.ucPreset,
          width: encodedSize?.$1 ?? params.width,
          height: encodedSize?.$2 ?? params.height,
        );
        await ImageSaveUtils.saveImageWithMetadata(
          imageBytes: imageBytes,
          filePath: filePath,
          params: paramsForSave,
          actualSeed: actualSeed,
          fixedPrefixTags: fixedTagsState.enabledPrefixes
              .map((entry) => entry.weightedContent)
              .where((content) => content.isNotEmpty)
              .toList(growable: false),
          fixedSuffixTags: fixedTagsState.enabledSuffixes
              .map((entry) => entry.weightedContent)
              .where((content) => content.isNotEmpty)
              .toList(growable: false),
          fixedNegativePrefixTags: fixedTagsState.negativeEnabledPrefixes
              .map((entry) => entry.weightedContent)
              .where((content) => content.isNotEmpty)
              .toList(growable: false),
          fixedNegativeSuffixTags: fixedTagsState.negativeEnabledSuffixes
              .map((entry) => entry.weightedContent)
              .where((content) => content.isNotEmpty)
              .toList(growable: false),
          charCaptions: charCaptions,
          charNegCaptions: charNegCaptions,
          useCoords: !characterConfig.globalAiChoice,
        );
      }

      // 立即解析并缓存刚保存图像的元数据
      unawaited(
        ImageMetadataService()
            .getMetadata(filePath)
            .then((metadata) {
              AppLogger.d(
                '生成图像元数据已缓存: ${metadata?.prompt.substring(0, metadata.prompt.length > 30 ? 30 : metadata.prompt.length)}...',
                'ImagePreview',
              );
            })
            .catchError((e) {
              AppLogger.w('生成图像元数据缓存失败: $e', 'ImagePreview');
            }),
      );

      // 更新保存图像的文件路径到状态
      final currentState = ref.read(imageGenerationNotifierProvider);
      final updatedImages = currentState.displayImages.map((img) {
        if (img.id == image.identifier) {
          return img.copyWithFilePath(filePath);
        }
        return img;
      }).toList();

      if (updatedImages.isNotEmpty) {
        ref
            .read(imageGenerationNotifierProvider.notifier)
            .updateDisplayImages(updatedImages);
      }

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }
}

/// 停靠状态的角色面板
///
/// 当角色面板处于停靠模式时，显示在中央图像区域
/// 布局：标题栏 + 左侧竖直按钮栏 + 右侧角色网格 + 底部工具栏
class _DockedCharacterPanel extends ConsumerWidget {
  const _DockedCharacterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = ref.watch(characterPromptNotifierProvider);
    final l10n = context.l10n;

    return Container(
      // 使用半透明表面色，让背景微妙透出
      color: colorScheme.surface.withValues(alpha: 0.95),
      child: Column(
        children: [
          // 标题栏 - 横跨整个宽度
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.people, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.characterEditor_title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 取消停靠按钮
                _UndockButton(
                  onPressed: () {
                    ref.read(characterPanelDockProvider.notifier).undock();
                  },
                ),
              ],
            ),
          ),

          // 极淡的分隔线
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),

          // 主内容区：左侧竖直按钮栏 + 右侧角色网格
          Expanded(
            child: Row(
              children: [
                // 左侧竖直按钮栏
                Container(
                  width: 64,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                  ),
                  child: const _VerticalAddButtons(),
                ),

                // 右侧角色卡片网格（紧贴边缘，无内边距）
                Expanded(
                  child: CharacterCardGrid(
                    globalAiChoice: config.globalAiChoice,
                    padding: EdgeInsets.zero,
                    onCardTap: (character) {
                      // 停靠模式下点击卡片打开完整编辑对话框
                      CharacterEditDialog.show(
                        context,
                        character,
                        config.globalAiChoice,
                      );
                    },
                    onDelete: (id) {
                      ref
                          .read(characterPromptNotifierProvider.notifier)
                          .removeCharacter(id);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 底部分隔线
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),

          // 底部工具栏 - 横跨整个宽度，紧贴边缘
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            child: Row(
              children: [
                // 全局AI选择开关（左侧留少量空间对齐按钮栏）
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(characterPromptNotifierProvider.notifier)
                            .setGlobalAiChoice(!config.globalAiChoice);
                      },
                      child: Text(
                        l10n.characterEditor_globalAiChoice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: l10n.characterEditor_globalAiChoiceHint,
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 全局AI选择开关 - 使用 Consumer 确保实时更新
                    Consumer(
                      builder: (context, ref, child) {
                        final globalAiChoice = ref.watch(
                          characterPromptNotifierProvider.select(
                            (c) => c.globalAiChoice,
                          ),
                        );
                        return ThemedSwitch(
                          value: globalAiChoice,
                          onChanged: (value) {
                            ref
                                .read(characterPromptNotifierProvider.notifier)
                                .setGlobalAiChoice(value);
                          },
                          scale: 0.85,
                        );
                      },
                    ),
                  ],
                ),

                const Spacer(),

                // 清空所有按钮
                if (config.characters.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showClearAllConfirm(context, ref),
                    icon: Icon(
                      Icons.delete_sweep,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    label: Text(
                      l10n.characterEditor_clearAll,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearAllConfirm(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.characterEditor_clearAllTitle),
        content: Text(l10n.characterEditor_clearAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.common_clear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    }
  }
}

/// 左侧竖直添加按钮栏
///
/// 停靠模式下使用竖直布局的添加按钮
class _VerticalAddButtons extends ConsumerWidget {
  const _VerticalAddButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 女性按钮
          _VerticalGenderButton(
            icon: Icons.female,
            label: l10n.characterEditor_addFemale,
            color: const Color(0xFFEC4899), // pink-500
            onTap: () => _addCharacter(ref, CharacterGender.female),
          ),
          const SizedBox(height: 6),
          // 男性按钮
          _VerticalGenderButton(
            icon: Icons.male,
            label: l10n.characterEditor_addMale,
            color: const Color(0xFF3B82F6), // blue-500
            onTap: () => _addCharacter(ref, CharacterGender.male),
          ),
          const SizedBox(height: 6),
          // 其他按钮
          _VerticalGenderButton(
            icon: Icons.transgender,
            label: l10n.characterEditor_addOther,
            color: const Color(0xFF8B5CF6), // violet-500
            onTap: () => _addCharacter(ref, CharacterGender.other),
          ),
          const SizedBox(height: 6),
          // 词库按钮
          _VerticalLibraryButton(onTap: () => _addFromLibrary(context, ref)),
        ],
      ),
    );
  }

  void _addCharacter(WidgetRef ref, CharacterGender gender) {
    ref.read(characterPromptNotifierProvider.notifier).addCharacter(gender);
  }

  Future<void> _addFromLibrary(BuildContext context, WidgetRef ref) async {
    final entry = await showDialog(
      context: context,
      builder: (context) => const TagLibraryPickerDialog(),
    );

    if (entry != null) {
      ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
      ref
          .read(characterPromptNotifierProvider.notifier)
          .addCharacter(
            CharacterGender.female,
            name: entry.displayName,
            prompt: entry.content,
            thumbnailPath: entry.thumbnail,
          );
    }
  }
}

/// 竖直性别按钮
class _VerticalGenderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _VerticalGenderButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_VerticalGenderButton> createState() => _VerticalGenderButtonState();
}

class _VerticalGenderButtonState extends State<_VerticalGenderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.18)
                : widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 22, color: widget.color),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _isHovered
                      ? widget.color
                      : colorScheme.onSurfaceVariant,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 竖直词库按钮
class _VerticalLibraryButton extends StatefulWidget {
  final VoidCallback onTap;

  const _VerticalLibraryButton({required this.onTap});

  @override
  State<_VerticalLibraryButton> createState() => _VerticalLibraryButtonState();
}

class _VerticalLibraryButtonState extends State<_VerticalLibraryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final accentColor = colorScheme.tertiary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? accentColor.withValues(alpha: 0.18)
                : accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 22,
                color: _isHovered ? accentColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.characterEditor_addFromLibrary,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _isHovered
                      ? accentColor
                      : colorScheme.onSurfaceVariant,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 取消停靠按钮
class _UndockButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _UndockButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1,
            ),
            color: colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin, size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                l10n.characterEditor_undock,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
