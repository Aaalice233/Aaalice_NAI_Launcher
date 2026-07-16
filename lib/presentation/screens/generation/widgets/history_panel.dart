import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/file_explorer_utils.dart';
import '../../../../core/utils/image_share_sanitizer.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/tag_library_page_provider.dart';

import '../../../../data/services/image_metadata_service.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../providers/reverse_prompt_provider.dart';
import '../../../providers/share_image_settings_provider.dart';
import '../../../services/image_workflow_launcher.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_viewer.dart';
import '../../../widgets/common/draggable_memory_image.dart';
import '../../../widgets/common/selectable_image_card.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import '../../../utils/image_detail_opener.dart';
import '../../../utils/krita_send_helper.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../services/generation_save_service.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../tag_library_page/widgets/entry_add_dialog.dart';

double resolveHistoryPreviewAspectRatio(
  double aspectRatio, {
  double fallback = 1.0,
}) {
  if (!aspectRatio.isFinite || aspectRatio <= 0) {
    return fallback;
  }
  return aspectRatio;
}

double resolveCurrentHistoryPreviewAspectRatio(
  double batchAspectRatio, {
  double? completedImageAspectRatio,
}) {
  return resolveHistoryPreviewAspectRatio(
    completedImageAspectRatio ?? batchAspectRatio,
    fallback: resolveHistoryPreviewAspectRatio(batchAspectRatio),
  );
}

/// 历史面板组件
class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({super.key});

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  final Set<String> _selectedIds = {};
  final ShareImagePreparationService _sharePreparationService =
      ShareImagePreparationService.instance;
  Timer? _historyScrollIdleTimer;
  Timer? _historyPreheatTimer;
  Timer? _hoverPreheatTimer;
  bool _isHistoryScrolling = false;
  String? _lastSharePreparationMaintenanceKey;
  Uint8List? _lastStreamPreviewBytes;
  final Map<String, Uint8List> _completionPreviewPlaceholders = {};
  final Map<String, bool> _favoriteStates = {};
  final Map<String, String?> _favoriteStatePaths = {};
  final Set<String> _favoriteStatusLoadingIds = {};
  final Set<String> _favoriteToggleLoadingIds = {};

  @override
  void initState() {
    super.initState();
    _sharePreparationService.addListener(_handleSharePreparationChanged);
  }

  @override
  void dispose() {
    _historyScrollIdleTimer?.cancel();
    _historyPreheatTimer?.cancel();
    _hoverPreheatTimer?.cancel();
    _sharePreparationService.removeListener(_handleSharePreparationChanged);
    super.dispose();
  }

  void _handleSharePreparationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final stripMetadata = ref.watch(
      shareImageSettingsProvider.select(
        (settings) => settings.effectiveStripMetadataForCopyAndDrag,
      ),
    );
    final theme = Theme.of(context);
    _syncCompletionPreviewPlaceholder(state);
    _scheduleSharePreparationMaintenance(state, stripMetadata);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.only(
            left: 8,
            right: 4,
            top: 12,
            bottom: 12,
          ),
          child: Row(
            children: [
              // 折叠按钮
              _buildCollapseButton(theme),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.generation_historyRecord,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.history.isNotEmpty ||
                  state.currentImages.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_getAllSelectableImages(state).length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 全选按钮
              if (state.history.isNotEmpty || state.currentImages.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      final allImages = _getAllSelectableImages(state);
                      if (_selectedIds.length == allImages.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.clear();
                        _selectedIds.addAll(allImages.map((img) => img.id));
                      }
                    });
                  },
                  icon: Icon(
                    _selectedIds.length == _getAllSelectableImages(state).length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 20,
                  ),
                  tooltip:
                      _selectedIds.length ==
                          _getAllSelectableImages(state).length
                      ? context.l10n.common_deselectAll
                      : context.l10n.common_selectAll,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              if (state.history.isNotEmpty || state.currentImages.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _showClearDialog(context, ref);
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: context.l10n.common_clear,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
            ],
          ),
        ),
        const ThemedDivider(height: 1),

        // 历史列表
        Expanded(
          child: state.history.isEmpty && !_hasCurrentGeneration(state)
              ? _buildEmptyState(theme, context)
              : _buildHistoryGrid(
                  state,
                  theme,
                  ref,
                  stripMetadata: stripMetadata,
                ),
        ),

        // 底部操作栏（有选中时显示）
        if (_selectedIds.isNotEmpty) _buildBottomActions(context, state, theme),
      ],
    );
  }

  Widget _buildCollapseButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref
            .read(layoutStateNotifierProvider.notifier)
            .setRightPanelExpanded(false),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.generation_noHistory,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取所有可选择的图像（当前批次已完成 + 去重后的历史）
  List<GeneratedImage> _getAllSelectableImages(ImageGenerationState state) {
    // 当前批次已完成的图像（不包括正在生成中的）
    final currentCompleted = state.currentImages;
    final currentIds = currentCompleted.map((img) => img.id).toSet();

    // 从历史中过滤掉已在 currentImages 中的图像
    final deduplicatedHistory = state.history
        .where((img) => !currentIds.contains(img.id))
        .toList();

    return [
      ...currentCompleted,
      ...deduplicatedHistory,
    ].where((image) => image.canBulkSelect).toList();
  }

  /// 判断是否有当前正在生成的图像
  bool _hasCurrentGeneration(ImageGenerationState state) {
    return state.isGenerating || state.currentImages.isNotEmpty;
  }

  void _scheduleSharePreparationMaintenance(
    ImageGenerationState state,
    bool stripMetadata,
  ) {
    final images = _getAllSelectableImages(state);
    final imageIds = images.map((image) => image.id).toSet();
    final maintenanceKey =
        '${stripMetadata ? 'strip' : 'raw'}:'
        '${imageIds.join('|')}';

    if (_lastSharePreparationMaintenanceKey == maintenanceKey) {
      return;
    }
    _lastSharePreparationMaintenanceKey = maintenanceKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_sharePreparationService.retainHistoryImageIds(imageIds));
      if (!_isHistoryScrolling) {
        _scheduleHistoryPreheat(images, stripMetadata);
      }
    });
  }

  void _setHistoryScrolling(bool value) {
    if (_isHistoryScrolling == value) {
      return;
    }

    setState(() {
      _isHistoryScrolling = value;
    });
  }

  bool _handleHistoryScrollNotification(
    ScrollNotification notification,
    bool stripMetadata,
  ) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _historyScrollIdleTimer?.cancel();
      _historyPreheatTimer?.cancel();
      _hoverPreheatTimer?.cancel();
      _setHistoryScrolling(true);
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _historyScrollIdleTimer?.cancel();
      _historyScrollIdleTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _setHistoryScrolling(false);
        final currentState = ref.read(imageGenerationNotifierProvider);
        final currentStripMetadata = ref
            .read(shareImageSettingsProvider)
            .effectiveStripMetadataForCopyAndDrag;
        _scheduleHistoryPreheat(
          _getAllSelectableImages(currentState),
          currentStripMetadata,
          delay: const Duration(milliseconds: 150),
        );
      });
    }

    return false;
  }

  void _scheduleHistoryPreheat(
    List<GeneratedImage> images,
    bool stripMetadata, {
    Duration delay = const Duration(milliseconds: 600),
  }) {
    _historyPreheatTimer?.cancel();
    final draggableImages = images.where((image) => image.canDrag).toList();
    if (draggableImages.isEmpty) {
      return;
    }

    _historyPreheatTimer = Timer(delay, () {
      if (!mounted || _isHistoryScrolling) {
        return;
      }

      for (final image in draggableImages) {
        _sharePreparationService.enqueue(
          imageId: image.id,
          imageBytes: image.bytes,
          fileName: 'history_${image.id}.png',
          sourceFilePath: image.filePath,
          stripMetadata: stripMetadata,
        );
      }
    });
  }

  void _scheduleHoverPreheat(GeneratedImage image, bool stripMetadata) {
    if (!image.canDrag) {
      return;
    }

    if (_isHistoryScrolling) {
      return;
    }

    _hoverPreheatTimer?.cancel();
    _hoverPreheatTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _isHistoryScrolling) {
        return;
      }
      _sharePreparationService.enqueue(
        imageId: image.id,
        imageBytes: image.bytes,
        fileName: 'history_${image.id}.png',
        sourceFilePath: image.filePath,
        stripMetadata: stripMetadata,
      );
    });
  }

  String _dragDisabledReason(ShareImagePreparationSnapshot snapshot) {
    return switch (snapshot.status) {
      ShareImagePreparationStatus.failed => '拖拽文件准备失败，稍后重试',
      ShareImagePreparationStatus.preparing => '正在准备拖拽文件...',
      ShareImagePreparationStatus.notQueued => '拖拽文件尚未准备完成',
      ShareImagePreparationStatus.ready => '',
    };
  }

  void _syncCompletionPreviewPlaceholder(ImageGenerationState state) {
    if (state.hasStreamPreview) {
      _lastStreamPreviewBytes = state.streamPreview;
      return;
    }

    if (_lastStreamPreviewBytes != null && state.currentImages.isNotEmpty) {
      final newestImage = state.currentImages.first;
      _completionPreviewPlaceholders.putIfAbsent(
        newestImage.id,
        () => _lastStreamPreviewBytes!,
      );
      _lastStreamPreviewBytes = null;
    }

    final retainedIds = <String>{
      for (final image in state.currentImages) image.id,
      for (final image in state.history) image.id,
    };
    _completionPreviewPlaceholders.removeWhere(
      (imageId, _) => !retainedIds.contains(imageId),
    );
  }

  void _clearCompletionPreviewPlaceholder(String imageId) {
    if (_completionPreviewPlaceholders.remove(imageId) == null || !mounted) {
      return;
    }
    setState(() {});
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

  /// 计算当前生成区块的项目数
  int _getCurrentGenerationCount(ImageGenerationState state) {
    if (!_hasCurrentGeneration(state)) return 0;
    int count = state.currentImages.length;
    if (state.isGenerating) {
      final previewSlotCount = _visibleStreamPreviewSlots(state).length;
      count += previewSlotCount > 0 ? previewSlotCount : 1;
    }
    return count;
  }

  Widget _buildHistoryGrid(
    ImageGenerationState state,
    ThemeData theme,
    WidgetRef ref, {
    required bool stripMetadata,
  }) {
    final previewDimensions = ref.watch(
      generationParamsNotifierProvider.select(selectPreviewDimensionsViewData),
    );
    final history = state.history;
    // 使用批次分辨率（点击生成时捕获），fallback 到全局参数
    final batchAspectRatio =
        (state.batchWidth != null && state.batchHeight != null)
        ? state.batchWidth! / state.batchHeight!
        : previewDimensions.width / previewDimensions.height;

    // 计算当前生成区块的项目数
    final currentGenerationCount = _getCurrentGenerationCount(state);

    // 使用唯一 ID 去重：收集 currentImages 的 ID
    final currentImageIds = <String>{};
    for (final img in state.currentImages) {
      currentImageIds.add(img.id);
    }

    // 从历史中过滤掉已在 currentImages 中显示的图像
    final deduplicatedHistory = history
        .where((img) => !currentImageIds.contains(img.id))
        .toList();

    final totalCount = currentGenerationCount + deduplicatedHistory.length;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handleHistoryScrollNotification(notification, stripMetadata),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          // 已完成图片使用自身比例；流式占位仍使用本批次分辨率。
          if (index < currentGenerationCount) {
            final completedImageAspectRatio = index < state.currentImages.length
                ? state.currentImages[index].aspectRatio
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AspectRatio(
                aspectRatio: resolveCurrentHistoryPreviewAspectRatio(
                  batchAspectRatio,
                  completedImageAspectRatio: completedImageAspectRatio,
                ),
                child: _buildCurrentGenerationItem(
                  context,
                  index,
                  state,
                  state.batchWidth ?? previewDimensions.width,
                  state.batchHeight ?? previewDimensions.height,
                  stripMetadata: stripMetadata,
                ),
              ),
            );
          }

          // 历史图像（已去重）- 使用图像自己的宽高比
          final historyIndex = index - currentGenerationCount;
          final historyImage = deduplicatedHistory[historyIndex];
          final isFavorite = _favoriteStateFor(historyImage);
          final isFailedSnapshot = historyImage.isFailedStreamSnapshot;
          // 计算在原始 history 中的真实索引（用于选择操作）
          final actualHistoryIndex = history.indexOf(historyImage);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AspectRatio(
              aspectRatio: resolveHistoryPreviewAspectRatio(
                historyImage.aspectRatio,
                fallback: batchAspectRatio,
              ),
              child: _buildPreparedHistoryItem(
                context: context,
                image: historyImage,
                stripMetadata: stripMetadata,
                childBuilder: (dragPreparationReady) => SelectableImageCard(
                  imageBytes: historyImage.bytes,
                  sourceFilePath: historyImage.filePath,
                  index: actualHistoryIndex,
                  showIndex: false,
                  isSelected: _selectedIds.contains(historyImage.id),
                  isFavorite: isFavorite,
                  dragPreparationReady: dragPreparationReady,
                  enableSelection: historyImage.canBulkSelect,
                  enableSaveAction: historyImage.canSave,
                  enableCopyAction: historyImage.canSave,
                  statusBadgeLabel: isFailedSnapshot
                      ? context.l10n.generation_failedStreamSnapshot
                      : null,
                  statusBadgeTooltip: isFailedSnapshot
                      ? context.l10n.generation_failedStreamSnapshotHint
                      : null,
                  onFavoriteToggle: historyImage.canFavorite
                      ? () => _toggleHistoryFavorite(context, historyImage)
                      : null,
                  onSelectionChanged: (selected) {
                    if (!historyImage.canBulkSelect) {
                      return;
                    }
                    setState(() {
                      if (selected) {
                        _selectedIds.add(historyImage.id);
                      } else {
                        _selectedIds.remove(historyImage.id);
                      }
                    });
                  },
                  onFullscreen: () => _showFullscreen(context, historyImage),
                  enableContextMenu: true,
                  enableHoverScale: true,
                  hoverEffectsEnabled: !_isHistoryScrolling,
                  shareWarmupEnabled: false,
                  onReversePrompt: historyImage.canUseAsGenerationInput
                      ? () => unawaited(
                          _sendHistoryImageToReversePrompt(
                            context,
                            historyImage,
                          ),
                        )
                      : null,
                  onImageToImage: historyImage.canUseAsGenerationInput
                      ? () => _sendHistoryImageToImageToImage(
                          context,
                          historyImage,
                        )
                      : null,
                  onVibeTransfer: historyImage.canUseAsGenerationInput
                      ? () => unawaited(
                          _sendHistoryImageToVibeTransfer(
                            context,
                            historyImage,
                          ),
                        )
                      : null,
                  onPreciseReference: historyImage.canUseAsGenerationInput
                      ? () => unawaited(
                          _sendHistoryImageToPreciseReference(
                            context,
                            historyImage,
                          ),
                        )
                      : null,
                  onEditImage: historyImage.canUseAsGenerationInput
                      ? () => ImageWorkflowLauncher.openEditor(
                          context,
                          ref,
                          historyImage.bytes,
                          mode: ImageEditorMode.edit,
                        )
                      : null,
                  onInpaint: historyImage.canUseAsGenerationInput
                      ? () => ImageWorkflowLauncher.openInpaint(
                          context,
                          ref,
                          historyImage.bytes,
                        )
                      : null,
                  onGenerateVariations: historyImage.canUseAsGenerationInput
                      ? () => ImageWorkflowLauncher.generateVariations(
                          context,
                          ref,
                          historyImage.bytes,
                        )
                      : null,
                  onDirectorTools: historyImage.canUseAsGenerationInput
                      ? () => ImageWorkflowLauncher.openDirectorTools(
                          context,
                          ref,
                          historyImage.bytes,
                        )
                      : null,
                  onEnhance: historyImage.canUseAsGenerationInput
                      ? () => ImageWorkflowLauncher.openEnhance(
                          ref,
                          historyImage.bytes,
                        )
                      : null,
                  onUpscale: historyImage.canUseAsGenerationInput
                      ? () => ImageWorkflowLauncher.openUpscale(
                          ref,
                          historyImage.bytes,
                        )
                      : null,
                  onSendToKrita: historyImage.canUseAsGenerationInput
                      ? () => KritaSendHelper.sendImageBytes(
                          context,
                          ref,
                          historyImage.bytes,
                          name: 'history_${historyImage.id}.png',
                        )
                      : null,
                  onOpenInExplorer: historyImage.canSave
                      ? () => _openImageInExplorer(context, historyImage)
                      : null,
                  onSaveToLibrary: historyImage.canUseAsGenerationInput
                      ? (bytes, _) => _showSaveToLibraryDialog(context, bytes)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreparedHistoryItem({
    required BuildContext context,
    required GeneratedImage image,
    required bool stripMetadata,
    required Widget Function(bool dragPreparationReady) childBuilder,
  }) {
    if (!image.canDrag) {
      return childBuilder(true);
    }

    final snapshot = _sharePreparationService.snapshotFor(
      image.id,
      stripMetadata: stripMetadata,
    );
    final preparedFile = snapshot.isReady ? snapshot.file : null;
    final dragPreparationReady = preparedFile != null;

    return MouseRegion(
      onEnter: (_) => _scheduleHoverPreheat(image, stripMetadata),
      onExit: (_) => _hoverPreheatTimer?.cancel(),
      child: DraggableMemoryImage(
        imageBytes: image.bytes,
        fileName: 'history_${image.id}.png',
        sourceFilePath: image.filePath,
        requirePreparedDragFile: true,
        preparedDragFile: preparedFile,
        preparedDragStripMetadata: preparedFile == null ? null : stripMetadata,
        disabledReason: preparedFile == null
            ? _dragDisabledReason(snapshot)
            : null,
        child: childBuilder(dragPreparationReady),
      ),
    );
  }

  /// 构建当前生成区块的单个项目
  Widget _buildCurrentGenerationItem(
    BuildContext context,
    int index,
    ImageGenerationState state,
    int imageWidth,
    int imageHeight, {
    required bool stripMetadata,
  }) {
    final completedImages = state.currentImages;

    // 已完成的当前图像（支持选择）
    if (index < completedImages.length) {
      final image = completedImages[index];
      final imageBytes = image.bytes;
      final isFavorite = _favoriteStateFor(image);
      final isFailedSnapshot = image.isFailedStreamSnapshot;
      return _buildPreparedHistoryItem(
        context: context,
        image: image,
        stripMetadata: stripMetadata,
        childBuilder: (dragPreparationReady) => SelectableImageCard(
          imageBytes: imageBytes,
          sourceFilePath: image.filePath,
          index: index,
          showIndex: true,
          isSelected: _selectedIds.contains(image.id),
          isFavorite: isFavorite,
          dragPreparationReady: dragPreparationReady,
          completionPlaceholderBytes: _completionPreviewPlaceholders[image.id],
          onCompletionPlaceholderSettled: () =>
              _clearCompletionPreviewPlaceholder(image.id),
          enableSelection: image.canBulkSelect,
          enableSaveAction: image.canSave,
          enableCopyAction: image.canSave,
          statusBadgeLabel: isFailedSnapshot
              ? context.l10n.generation_failedStreamSnapshot
              : null,
          statusBadgeTooltip: isFailedSnapshot
              ? context.l10n.generation_failedStreamSnapshotHint
              : null,
          onFavoriteToggle: image.canFavorite
              ? () => _toggleHistoryFavorite(context, image)
              : null,
          onSelectionChanged: (selected) {
            if (!image.canBulkSelect) {
              return;
            }
            setState(() {
              if (selected) {
                _selectedIds.add(image.id);
              } else {
                _selectedIds.remove(image.id);
              }
            });
          },
          onFullscreen: () => _showFullscreen(context, image),
          enableContextMenu: true,
          enableHoverScale: true,
          hoverEffectsEnabled: !_isHistoryScrolling,
          shareWarmupEnabled: false,
          onReversePrompt: image.canUseAsGenerationInput
              ? () =>
                    unawaited(_sendHistoryImageToReversePrompt(context, image))
              : null,
          onImageToImage: image.canUseAsGenerationInput
              ? () => _sendHistoryImageToImageToImage(context, image)
              : null,
          onVibeTransfer: image.canUseAsGenerationInput
              ? () => unawaited(_sendHistoryImageToVibeTransfer(context, image))
              : null,
          onPreciseReference: image.canUseAsGenerationInput
              ? () => unawaited(
                  _sendHistoryImageToPreciseReference(context, image),
                )
              : null,
          onEditImage: image.canUseAsGenerationInput
              ? () => ImageWorkflowLauncher.openEditor(
                  context,
                  ref,
                  imageBytes,
                  mode: ImageEditorMode.edit,
                )
              : null,
          onInpaint: image.canUseAsGenerationInput
              ? () =>
                    ImageWorkflowLauncher.openInpaint(context, ref, imageBytes)
              : null,
          onGenerateVariations: image.canUseAsGenerationInput
              ? () => ImageWorkflowLauncher.generateVariations(
                  context,
                  ref,
                  imageBytes,
                )
              : null,
          onDirectorTools: image.canUseAsGenerationInput
              ? () => ImageWorkflowLauncher.openDirectorTools(
                  context,
                  ref,
                  imageBytes,
                )
              : null,
          onEnhance: image.canUseAsGenerationInput
              ? () => ImageWorkflowLauncher.openEnhance(ref, imageBytes)
              : null,
          onUpscale: image.canUseAsGenerationInput
              ? () => ImageWorkflowLauncher.openUpscale(ref, imageBytes)
              : null,
          onSendToKrita: image.canUseAsGenerationInput
              ? () => KritaSendHelper.sendImageBytes(
                  context,
                  ref,
                  image.bytes,
                  name: 'history_${image.id}.png',
                )
              : null,
          onOpenInExplorer: image.canSave
              ? () => _openImageInExplorer(context, image)
              : null,
          onSaveToLibrary: image.canUseAsGenerationInput
              ? (bytes, _) => _showSaveToLibraryDialog(context, bytes)
              : null,
        ),
      );
    }

    if (state.isGenerating) {
      final generationIndex = index - completedImages.length;
      final previewSlots = _visibleStreamPreviewSlots(state);

      if (previewSlots.isNotEmpty && generationIndex < previewSlots.length) {
        final slot = previewSlots[generationIndex];
        return SelectableImageCard(
          isGenerating: true,
          currentImage: slot.imageNumber,
          totalImages: slot.totalImages,
          progress: slot.progress,
          streamPreview: slot.previewBytes,
          focusedPreviewPlacement: slot.focusedPreviewPlacement,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          enableSelection: false,
          enableContextMenu: false,
        );
      }

      if (previewSlots.isEmpty && generationIndex == 0) {
        return SelectableImageCard(
          isGenerating: true,
          currentImage: state.currentImage,
          totalImages: state.totalImages,
          progress: state.progress,
          streamPreview: state.streamPreview,
          focusedPreviewPlacement: state.focusedPreviewPlacement,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          enableSelection: false,
          enableContextMenu: false,
        );
      }
    }

    return const SizedBox.shrink();
  }

  bool _favoriteStateFor(GeneratedImage image) {
    _ensureFavoriteStateLoaded(image);
    return _favoriteStates[image.id] ?? false;
  }

  void _ensureFavoriteStateLoaded(GeneratedImage image) {
    final filePath = image.filePath;
    if (filePath == null || filePath.isEmpty) {
      if (_favoriteStatePaths[image.id] != null ||
          _favoriteStates[image.id] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _favoriteStatePaths[image.id] = null;
            _favoriteStates[image.id] = false;
          });
        });
      }
      return;
    }

    if (_favoriteStatePaths[image.id] == filePath &&
        (_favoriteStates.containsKey(image.id) ||
            _favoriteStatusLoadingIds.contains(image.id))) {
      return;
    }

    _favoriteStatePaths[image.id] = filePath;
    _favoriteStatusLoadingIds.add(image.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        () async {
          final isFavorite = await ref
              .read(localGalleryNotifierProvider.notifier)
              .isFavorite(filePath);
          if (!mounted || _favoriteStatePaths[image.id] != filePath) return;
          setState(() {
            _favoriteStates[image.id] = isFavorite;
            _favoriteStatusLoadingIds.remove(image.id);
          });
        }().catchError((Object error, StackTrace stack) {
          if (!mounted) return;
          setState(() {
            _favoriteStatusLoadingIds.remove(image.id);
          });
        }),
      );
    });
  }

  Future<void> _toggleHistoryFavorite(
    BuildContext context,
    GeneratedImage image,
  ) async {
    if (!_favoriteToggleLoadingIds.add(image.id)) return;

    try {
      final filePath = await _ensureHistoryImageSaved(image);
      final isFavorite = await ref
          .read(localGalleryNotifierProvider.notifier)
          .toggleFavorite(filePath);

      if (!mounted) return;
      setState(() {
        _favoriteStatePaths[image.id] = filePath;
        _favoriteStates[image.id] = isFavorite;
      });

      if (context.mounted) {
        AppToast.success(
          context,
          isFavorite
              ? context.l10n.toast_favorited
              : context.l10n.toast_unfavorited,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.toast_favoriteUpdateFailed(e.toString()),
        );
      }
    } finally {
      _favoriteToggleLoadingIds.remove(image.id);
    }
  }

  Future<String> _ensureHistoryImageSaved(GeneratedImage image) async {
    final existingPath = image.filePath;
    if (existingPath != null &&
        existingPath.isNotEmpty &&
        await File(existingPath).exists()) {
      return existingPath;
    }

    final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
    if (saveDirPath == null || saveDirPath.isEmpty) {
      throw StateError('未设置保存目录');
    }

    final saveDir = Directory(saveDirPath);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(p.join(saveDir.path, fileName));
    await file.writeAsBytes(image.bytes);

    ref
        .read(imageGenerationNotifierProvider.notifier)
        .updateImageFilePath(image.id, file.path);
    await ref.read(localGalleryNotifierProvider.notifier).addNewlySavedImages([
      file.path,
    ]);

    return file.path;
  }

  String _historyImageFileName(GeneratedImage image) {
    final filePath = image.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return p.basename(filePath);
    }
    return 'history_${image.id}.png';
  }

  Future<void> _sendHistoryImageToReversePrompt(
    BuildContext context,
    GeneratedImage image,
  ) async {
    final l10n = context.l10n;

    try {
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(image.bytes, name: _historyImageFileName(image));

      if (!context.mounted) return;
      AppToast.success(context, l10n.drop_addedToReversePrompt);
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, l10n.gallery_sendFailed(e.toString()));
      }
    }
  }

  void _sendHistoryImageToImageToImage(
    BuildContext context,
    GeneratedImage image,
  ) {
    ImageWorkflowLauncher.openImageToImage(ref, image.bytes);
    AppToast.success(context, context.l10n.drop_addedToImg2Img);
  }

  Future<void> _sendHistoryImageToVibeTransfer(
    BuildContext context,
    GeneratedImage image,
  ) async {
    final l10n = context.l10n;

    try {
      final currentState = ref.read(generationParamsNotifierProvider);
      final currentCount = currentState.vibeReferencesV4.length;
      const maxCount = 16;
      final vibes = await VibeFileParser.parseFile(
        _historyImageFileName(image),
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

  Future<void> _sendHistoryImageToPreciseReference(
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

  Widget _buildBottomActions(
    BuildContext context,
    ImageGenerationState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // 打包按钮
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _packSelectedImages(context, state),
              icon: const Icon(Icons.archive_outlined, size: 20),
              label: Text('打包 (${_selectedIds.length})'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ),
          const SizedBox(width: 8),
          // 保存按钮
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _saveSelectedImages(context, state),
              icon: const Icon(Icons.save_alt, size: 20),
              label: Text(
                '${context.l10n.image_save} (${_selectedIds.length})',
              ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelectedImages(
    BuildContext context,
    ImageGenerationState state,
  ) async {
    if (_selectedIds.isEmpty) return;

    try {
      final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
      if (saveDirPath == null) return;
      final saveDir = Directory(saveDirPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 从所有可选图像中查找选中的图像
      final allImages = _getAllSelectableImages(state);
      final selectedImages = allImages
          .where((img) => _selectedIds.contains(img.id))
          .toList();

      for (int i = 0; i < selectedImages.length; i++) {
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File(p.join(saveDirPath, fileName));
        await file.writeAsBytes(selectedImages[i].bytes);
      }

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDirPath));
        setState(() {
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 打包选中的图片成压缩包
  Future<void> _packSelectedImages(
    BuildContext context,
    ImageGenerationState state,
  ) async {
    if (_selectedIds.isEmpty) return;

    // 直接使用保存文件对话框，用户可以选择路径并输入文件名
    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存压缩包',
      fileName: '$defaultName.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null || !context.mounted) return;

    // 确保文件名以 .zip 结尾
    final finalPath = outputPath.endsWith('.zip')
        ? outputPath
        : '$outputPath.zip';

    // 显示打包进度
    AppToast.info(
      context,
      context.l10n.toast_packingImages(_selectedIds.length),
    );

    try {
      // 先将选中的图片保存到临时目录
      final tempDir = await Directory.systemTemp.createTemp('nai_pack_');
      final imagePaths = <String>[];

      final allImages = _getAllSelectableImages(state);
      final selectedImages = allImages
          .where((img) => _selectedIds.contains(img.id))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < selectedImages.length; i++) {
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(selectedImages[i].bytes);
        imagePaths.add(file.path);
      }

      // 执行打包
      final success = await ZipUtils.createZipFromImages(imagePaths, finalPath);

      // 清理临时文件
      await tempDir.delete(recursive: true);

      if (context.mounted) {
        if (success) {
          AppToast.success(
            context,
            context.l10n.toast_packedImages(selectedImages.length),
          );
          setState(() {
            _selectedIds.clear();
          });
        } else {
          AppToast.error(context, context.l10n.toast_packFailed);
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.toast_packFailedWithError(e.toString()),
        );
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

      // 保存图片
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(saveDirPath, fileName));
      await file.writeAsBytes(image.bytes);

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      // 在文件夹中打开并选中文件
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

  void _showFullscreen(BuildContext context, GeneratedImage image) {
    final currentContext = context;

    // 简化逻辑：统一使用 FileImageDetailData 从 PNG 文件解析元数据
    // - 如果图像已保存（有 filePath），直接使用
    // - 如果图像未保存，使用 GeneratedImageDetailData 作为 fallback
    final ImageDetailData imageData;
    if (image.filePath != null && image.filePath!.isNotEmpty) {
      // 已保存的图像：使用 FileImageDetailData（异步解析元数据）
      // 加入预加载队列（如果尚未解析）
      ImageMetadataService().enqueuePreload(
        taskId: image.id,
        filePath: image.filePath,
      );
      imageData = FileImageDetailData(
        filePath: image.filePath!,
        cachedBytes: image.bytes,
        id: image.id,
        initialMetadata: image.metadata,
        showCopyButton: image.canSave,
      );
    } else {
      // 未保存的图像：使用 GeneratedImageDetailData，失败快照仅允许查看。
      imageData = GeneratedImageDetailData(
        imageBytes: image.bytes,
        metadata: image.metadata,
        id: image.id,
        showSaveButton: image.canSave,
        showCopyButton: image.canSave,
      );
    }

    if (!currentContext.mounted) return;

    // 使用 ImageDetailOpener 打开详情页（带防重复点击）
    ImageDetailOpener.showSingleImmediate(
      currentContext,
      image: imageData,
      showMetadataPanel: true,
      callbacks: ImageDetailCallbacks(
        onSave: image.canSave
            ? (img) => GenerationSaveService.saveImageFromDetail(
                currentContext,
                ref,
                img,
              )
            : null,
      ),
    );
  }

  /// 显示保存到词库对话框
  Future<void> _showSaveToLibraryDialog(
    BuildContext context,
    Uint8List bytes,
  ) async {
    // 历史记录中的图像需要尝试从元数据解析提示词
    String prompt = '';

    try {
      final extractedMeta = await ImageMetadataService().getMetadataFromBytes(
        bytes,
      );
      if (extractedMeta != null && extractedMeta.prompt.isNotEmpty) {
        prompt = extractedMeta.prompt;
      }
    } catch (e) {
      debugPrint('解析图像元数据失败: $e');
    }

    // 解析别名引用，保存实际内容到词库
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
    final resolvedPrompt = aliasResolver.resolveAliases(prompt);

    final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);

    if (!context.mounted) return;

    await EntryAddDialog.show(
      context,
      categories: tagLibraryState.categories,
      initialContent: resolvedPrompt,
      initialImageBytes: bytes,
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.generation_clearHistory,
      content: context.l10n.generation_clearHistoryConfirm,
      confirmText: context.l10n.common_clear,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );

    if (confirmed) {
      ref.read(imageGenerationNotifierProvider.notifier).clearHistory();
      setState(() {
        _selectedIds.clear();
      });
    }
  }
}
