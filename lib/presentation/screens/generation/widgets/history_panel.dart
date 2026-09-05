import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/services/android_media_store_service.dart';
import '../../../../core/services/file_export_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/file_explorer_utils.dart';
import '../../../../core/utils/image_save_utils.dart';
import '../../../../core/utils/image_share_sanitizer.dart';
import '../../../../core/utils/keyboard_modifier_utils.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/tag_library_page_provider.dart';

import '../../../../data/services/image_metadata_service.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/generation/preview_selection_provider.dart';
import '../../../providers/history_click_behavior_provider.dart';
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
import '../../../widgets/common/owned_scroll_controller.dart';
import '../../../widgets/common/selectable_image_card.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import '../../../utils/image_detail_opener.dart';
import '../../../utils/krita_send_helper.dart';
import '../../../utils/precise_ref_library_import_helper.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/common/workspace_panel_header.dart';
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

class _HistoryRowDescriptor {
  const _HistoryRowDescriptor({required this.imageId, required this.extent});

  final String? imageId;
  final double extent;
}

/// 历史面板组件
class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({
    super.key,
    this.onClose,
    this.embedded = false,
    this.viewportOffset,
  });

  final VoidCallback? onClose;

  /// 嵌入模式：隐藏自带标题行，由外层 Tab 栏承担标题职责。
  final bool embedded;
  final OwnedViewportOffset? viewportOffset;

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
  final Map<String, bool> _favoriteStates = {};
  final Map<String, String?> _favoriteStatePaths = {};
  final Set<String> _favoriteStatusLoadingIds = {};
  final Set<String> _favoriteToggleLoadingIds = {};
  late final OwnedScrollController _scrollController;
  final Map<String, GlobalKey> _imageKeys = {};
  List<_HistoryRowDescriptor> _rowDescriptors = const [];
  ProviderSubscription<String?>? _selectionSubscription;
  int _scrollRequestEpoch = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = OwnedScrollController(viewport: widget.viewportOffset);
    _sharePreparationService.addListener(_handleSharePreparationChanged);
    _selectionSubscription = ref.listenManual(
      generationPreviewSelectionProvider,
      (_, selectedId) => _scheduleScrollToSelection(selectedId),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _historyScrollIdleTimer?.cancel();
    _historyPreheatTimer?.cancel();
    _hoverPreheatTimer?.cancel();
    _selectionSubscription?.close();
    _scrollController.dispose();
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
    final clickBehavior = ref.watch(historyClickBehaviorNotifierProvider);
    final selectedPreviewId =
        clickBehavior == HistoryClickBehavior.selectPreview
        ? ref.watch(generationPreviewSelectionProvider)
        : null;
    _scheduleSharePreparationMaintenance(state, stripMetadata);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏（嵌入模式下由外层 Tab 栏承担，仅保留操作按钮）
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
            child: Row(
              children: [
                const Spacer(),
                if (state.history.isNotEmpty ||
                    state.currentImages.isNotEmpty) ...[
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
                  const SizedBox(width: 4),
                ],
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
                      _selectedIds.length ==
                              _getAllSelectableImages(state).length
                          ? Icons.deselect
                          : Icons.select_all,
                      size: 18,
                    ),
                    tooltip:
                        _selectedIds.length ==
                            _getAllSelectableImages(state).length
                        ? context.l10n.common_deselectAll
                        : context.l10n.common_selectAll,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    visualDensity: context.interactionPolicy.touchAvailable
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: context.interactionPolicy.minimumControlExtent,
                      height: context.interactionPolicy.minimumControlExtent,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                if (state.history.isNotEmpty || state.currentImages.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _showClearDialog(context, ref);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: context.l10n.common_clear,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    visualDensity: context.interactionPolicy.touchAvailable
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: context.interactionPolicy.minimumControlExtent,
                      height: context.interactionPolicy.minimumControlExtent,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
              ],
            ),
          )
        else
          WorkspacePanelHeader(
            leading: _buildCollapseButton(),
            icon: Icons.history_rounded,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    context.l10n.generation_historyRecord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
              ],
            ),
            actions: [
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
                  constraints: BoxConstraints.tightFor(
                    width: context.interactionPolicy.minimumControlExtent,
                    height: context.interactionPolicy.minimumControlExtent,
                  ),
                ),
              if (state.history.isNotEmpty || state.currentImages.isNotEmpty)
                IconButton(
                  onPressed: () => _showClearDialog(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: context.l10n.common_clear,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  constraints: BoxConstraints.tightFor(
                    width: context.interactionPolicy.minimumControlExtent,
                    height: context.interactionPolicy.minimumControlExtent,
                  ),
                ),
            ],
          ),
        if (widget.embedded) const ThemedDivider(height: 1),

        // 历史列表
        Expanded(
          child: state.history.isEmpty && !_hasCurrentGeneration(state)
              ? _buildEmptyState(theme, context)
              : _buildHistoryGrid(
                  state,
                  theme,
                  ref,
                  stripMetadata: stripMetadata,
                  clickBehavior: clickBehavior,
                  selectedPreviewId: selectedPreviewId,
                ),
        ),

        // 底部操作栏（有选中时显示）
        if (_selectedIds.isNotEmpty) _buildBottomActions(context, state, theme),
      ],
    );
  }

  Widget _buildCollapseButton() {
    final onClose = widget.onClose;
    return IconButton(
      key: const ValueKey('generation-history-collapse'),
      onPressed:
          onClose ??
          () => ref
              .read(layoutStateNotifierProvider.notifier)
              .setRightPanelExpanded(false),
      icon: const Icon(Icons.chevron_right),
      tooltip: onClose != null
          ? MaterialLocalizations.of(context).closeButtonTooltip
          : context.l10n.common_collapse,
      constraints: BoxConstraints.tightFor(
        width: context.interactionPolicy.minimumControlExtent,
        height: context.interactionPolicy.minimumControlExtent,
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
    return state.selectableMergedImages;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isHistoryScrolling) return;
          RendererBinding.instance.mouseTracker.updateAllDevices();
        });
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
      ShareImagePreparationStatus.failed =>
        context.l10n.history_dragFilePreparationFailed,
      ShareImagePreparationStatus.preparing =>
        context.l10n.history_dragFilePreparing,
      ShareImagePreparationStatus.notQueued =>
        context.l10n.history_dragFileNotReady,
      ShareImagePreparationStatus.ready => '',
    };
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
    required HistoryClickBehavior clickBehavior,
    required String? selectedPreviewId,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = (constraints.maxWidth - 16).clamp(
          1.0,
          double.infinity,
        );
        final descriptors = <_HistoryRowDescriptor>[
          for (var index = 0; index < currentGenerationCount; index++)
            _HistoryRowDescriptor(
              imageId: index < state.currentImages.length
                  ? state.currentImages[index].id
                  : null,
              extent:
                  rowWidth /
                      resolveCurrentHistoryPreviewAspectRatio(
                        batchAspectRatio,
                        completedImageAspectRatio:
                            index < state.currentImages.length
                            ? state.currentImages[index].aspectRatio
                            : null,
                      ) +
                  8,
            ),
          for (final image in deduplicatedHistory)
            _HistoryRowDescriptor(
              imageId: image.id,
              extent:
                  rowWidth /
                      resolveHistoryPreviewAspectRatio(
                        image.aspectRatio,
                        fallback: batchAspectRatio,
                      ) +
                  8,
            ),
        ];
        _rowDescriptors = descriptors;
        final retainedIds = descriptors
            .map((row) => row.imageId)
            .whereType<String>()
            .toSet();
        _imageKeys.removeWhere((id, _) => !retainedIds.contains(id));

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleHistoryScrollNotification(notification, stripMetadata),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: totalCount,
            itemExtentBuilder: (index, _) => descriptors[index].extent,
            itemBuilder: (context, index) {
              // 已完成图片使用自身比例；流式占位仍使用本批次分辨率。
              if (index < currentGenerationCount) {
                final completedImageAspectRatio =
                    index < state.currentImages.length
                    ? state.currentImages[index].aspectRatio
                    : null;
                final currentImage = index < state.currentImages.length
                    ? state.currentImages[index]
                    : null;
                final item = Padding(
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
                      clickBehavior: clickBehavior,
                      selectedPreviewId: selectedPreviewId,
                    ),
                  ),
                );
                return currentImage == null
                    ? item
                    : KeyedSubtree(
                        key: _imageKeyFor(currentImage.id),
                        child: item,
                      );
              }

              // 历史图像（已去重）- 使用图像自己的宽高比
              final historyIndex = index - currentGenerationCount;
              final historyImage = deduplicatedHistory[historyIndex];
              final isFavorite = _favoriteStateFor(historyImage);
              final isFailedSnapshot = historyImage.isFailedStreamSnapshot;
              // 计算在原始 history 中的真实索引（用于选择操作）
              final actualHistoryIndex = history.indexOf(historyImage);
              return KeyedSubtree(
                key: _imageKeyFor(historyImage.id),
                child: Padding(
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
                      childBuilder: (dragPreparationReady) =>
                          SelectableImageCard(
                            key: ValueKey(historyImage.id),
                            imageBytes: historyImage.bytes,
                            sourceFilePath: historyImage.filePath,
                            index: actualHistoryIndex,
                            showIndex: false,
                            isSelected: _selectedIds.contains(historyImage.id),
                            isPreviewActive:
                                selectedPreviewId == historyImage.id,
                            imageIdentity: historyImage.id,
                            allowRepeatedModifierTaps: true,
                            isFavorite: isFavorite,
                            dragPreparationReady: dragPreparationReady,
                            enableSelection: historyImage.canBulkSelect,
                            enableSaveAction: historyImage.canSave,
                            enableCopyAction: historyImage.canSave,
                            statusBadgeLabel: isFailedSnapshot
                                ? context.l10n.generation_failedStreamSnapshot
                                : null,
                            statusBadgeTooltip: isFailedSnapshot
                                ? context
                                      .l10n
                                      .generation_failedStreamSnapshotHint
                                : null,
                            onFavoriteToggle: historyImage.canFavorite
                                ? () => _toggleHistoryFavorite(
                                    context,
                                    historyImage,
                                  )
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
                            onTap: () => _handleImageTap(
                              context,
                              historyImage,
                              clickBehavior,
                            ),
                            onDoubleTap:
                                clickBehavior ==
                                    HistoryClickBehavior.selectPreview
                                ? () => _showLinkedDetail(context, historyImage)
                                : null,
                            onLongPress:
                                clickBehavior ==
                                    HistoryClickBehavior.selectPreview
                                ? () => _showLinkedDetail(context, historyImage)
                                : null,
                            onFullscreen: () =>
                                _showLinkedDetail(context, historyImage),
                            enableContextMenu: true,
                            hoverEffectsEnabled: !_isHistoryScrolling,
                            shareWarmupEnabled: false,
                            onReversePrompt:
                                historyImage.canUseAsGenerationInput
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
                            onPreciseReference:
                                historyImage.canUseAsGenerationInput
                                ? () => unawaited(
                                    _sendHistoryImageToPreciseReference(
                                      context,
                                      historyImage,
                                    ),
                                  )
                                : null,
                            onSaveToPreciseRefLibrary:
                                historyImage.canUseAsGenerationInput
                                ? () => unawaited(
                                    saveBytesToPreciseRefLibrary(
                                      ref,
                                      context,
                                      historyImage.bytes,
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
                            onGenerateVariations:
                                historyImage.canUseAsGenerationInput
                                ? () =>
                                      ImageWorkflowLauncher.generateVariations(
                                        context,
                                        ref,
                                        historyImage.bytes,
                                      )
                                : null,
                            onDirectorTools:
                                historyImage.canUseAsGenerationInput
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
                            onOpenInExplorer:
                                historyImage.canSave &&
                                    PlatformCapabilities
                                        .current
                                        .supportsOpenFolder
                                ? () => _openImageInExplorer(
                                    context,
                                    historyImage,
                                  )
                                : null,
                            onSaveToLibrary:
                                historyImage.canUseAsGenerationInput
                                ? (bytes, _) =>
                                      _showSaveToLibraryDialog(context, bytes)
                                : null,
                          ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
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
        imageId: image.id,
        imageBytes: image.bytes,
        feedbackPixelWidth: image.width,
        feedbackPixelHeight: image.height,
        feedbackFormat: 'PNG',
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
    required HistoryClickBehavior clickBehavior,
    required String? selectedPreviewId,
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
          key: ValueKey(image.id),
          imageBytes: imageBytes,
          sourceFilePath: image.filePath,
          index: index,
          showIndex: true,
          isSelected: _selectedIds.contains(image.id),
          isPreviewActive: selectedPreviewId == image.id,
          imageIdentity: image.id,
          allowRepeatedModifierTaps: true,
          isFavorite: isFavorite,
          dragPreparationReady: dragPreparationReady,
          completionPreview: state.completionPreviews[image.id],
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
          onTap: () => _handleImageTap(context, image, clickBehavior),
          onDoubleTap: clickBehavior == HistoryClickBehavior.selectPreview
              ? () => _showLinkedDetail(context, image)
              : null,
          onLongPress: clickBehavior == HistoryClickBehavior.selectPreview
              ? () => _showLinkedDetail(context, image)
              : null,
          onFullscreen: () => _showLinkedDetail(context, image),
          enableContextMenu: true,
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
          onSaveToPreciseRefLibrary: image.canUseAsGenerationInput
              ? () => unawaited(
                  saveBytesToPreciseRefLibrary(ref, context, image.bytes),
                )
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
          onOpenInExplorer:
              image.canSave && PlatformCapabilities.current.supportsOpenFolder
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

  GlobalKey _imageKeyFor(String imageId) =>
      _imageKeys.putIfAbsent(imageId, GlobalKey.new);

  void _scheduleScrollToSelection(String? imageId) {
    final epoch = ++_scrollRequestEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || imageId == null) return;
      unawaited(_scrollToSelection(imageId, epoch));
    });
  }

  Future<void> _scrollToSelection(String imageId, int epoch) async {
    if (!_scrollController.hasClients) return;
    final index = _rowDescriptors.indexWhere((row) => row.imageId == imageId);
    if (index < 0) return;

    var precedingExtent = 8.0;
    for (var i = 0; i < index; i++) {
      precedingExtent += _rowDescriptors[i].extent;
    }
    final row = _rowDescriptors[index];
    final viewport = _scrollController.position.viewportDimension;
    final target = (precedingExtent + row.extent / 2 - viewport / 2).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      return;
    }
    if (!mounted ||
        epoch != _scrollRequestEpoch ||
        ref.read(generationPreviewSelectionProvider) != imageId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          epoch != _scrollRequestEpoch ||
          ref.read(generationPreviewSelectionProvider) != imageId) {
        return;
      }
      final itemContext = _imageKeys[imageId]?.currentContext;
      if (itemContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            itemContext,
            alignment: 0.5,
            duration: const Duration(milliseconds: 80),
          ),
        );
      }
    });
  }

  bool get _isMultiSelectModifierPressed {
    return isPrimarySelectionModifierPressed();
  }

  void _toggleSelectedImage(GeneratedImage image) {
    if (!image.canBulkSelect) return;
    setState(() {
      if (!_selectedIds.add(image.id)) _selectedIds.remove(image.id);
    });
  }

  void _handleImageTap(
    BuildContext context,
    GeneratedImage image,
    HistoryClickBehavior behavior,
  ) {
    if (_isMultiSelectModifierPressed && image.canBulkSelect) {
      _toggleSelectedImage(image);
      return;
    }
    if (behavior == HistoryClickBehavior.selectPreview) {
      ref.read(generationPreviewSelectionProvider.notifier).select(image.id);
      ref.read(generationPreviewFocusNodeProvider).requestFocus();
      return;
    }
    _showLinkedDetail(context, image);
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
    final l10n = context.l10n;
    final existingPath = image.filePath;
    if (existingPath != null &&
        existingPath.isNotEmpty &&
        await File(existingPath).exists()) {
      return existingPath;
    }

    final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
    if (saveDirPath == null || saveDirPath.isEmpty) {
      throw StateError(l10n.localGallery_saveDirectoryNotSet);
    }

    // 原子保存：日期分类路径 + 独占防冲突 + 失败清理，全部在工具内完成
    final filePath = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: saveDirPath,
      bytes: image.bytes,
      seed: await ImageSaveUtils.resolveSeed(
        metadata: image.metadata,
        bytes: image.bytes,
      ),
    );

    ref
        .read(imageGenerationNotifierProvider.notifier)
        .updateImageFilePath(image.id, filePath);
    await ref.read(localGalleryNotifierProvider.notifier).addNewlySavedImages([
      filePath,
    ]);

    return filePath;
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
    final policyExtent = context.interactionPolicy.minimumControlExtent;
    final minimumHeight = policyExtent < 44 ? 44.0 : policyExtent;
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
              label: Text(
                '${context.l10n.common_pack} (${_selectedIds.length})',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, minimumHeight),
              ),
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
              style: FilledButton.styleFrom(
                minimumSize: Size(0, minimumHeight),
              ),
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

      // 从所有可选图像中查找选中的图像
      final allImages = _getAllSelectableImages(state);
      final selectedImages = allImages
          .where((img) => _selectedIds.contains(img.id))
          .toList();

      Object? systemGalleryError;
      // 原子保存：日期分类路径 + 独占防冲突 + 失败清理，全部在工具内完成
      for (int i = 0; i < selectedImages.length; i++) {
        final image = selectedImages[i];
        final filePath = await ImageSaveUtils.saveBytesToDatedPath(
          rootPath: saveDirPath,
          bytes: image.bytes,
          seed: await ImageSaveUtils.resolveSeed(
            metadata: image.metadata,
            bytes: image.bytes,
          ),
        );
        if (PlatformCapabilities.current.supportsSystemGalleryExport) {
          try {
            await AndroidMediaStoreService.savePng(
              bytes: image.bytes,
              fileName: p.basename(filePath),
            );
          } catch (error) {
            systemGalleryError ??= error;
          }
        }
      }

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        if (systemGalleryError != null) {
          AppToast.warning(
            context,
            context.l10n.image_savedAppOnly(systemGalleryError.toString()),
          );
        } else {
          AppToast.success(
            context,
            PlatformCapabilities.current.supportsSystemGalleryExport
                ? context.l10n.image_savedToSystemGallery
                : context.l10n.image_imageSaved(saveDirPath),
          );
        }
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

    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = '$defaultName.zip';
    String? desktopOutputPath;
    if (!PlatformCapabilities.current.supportsDocumentFileExport) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: context.l10n.localGallery_saveZipArchive,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (outputPath == null || !context.mounted) return;
      desktopOutputPath = outputPath.endsWith('.zip')
          ? outputPath
          : '$outputPath.zip';
    }

    // 显示打包进度
    AppToast.info(
      context,
      context.l10n.toast_packingImages(_selectedIds.length),
    );

    Directory? tempDir;
    try {
      // 先将选中的图片保存到临时目录
      tempDir = await Directory.systemTemp.createTemp('nai_pack_');
      final imagePaths = <String>[];

      final allImages = _getAllSelectableImages(state);
      final selectedImages = allImages
          .where((img) => _selectedIds.contains(img.id))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < selectedImages.length; i++) {
        final imageFileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${tempDir.path}/$imageFileName');
        await file.writeAsBytes(selectedImages[i].bytes);
        imagePaths.add(file.path);
      }

      late bool success;
      String? savedLocation;
      if (PlatformCapabilities.current.supportsDocumentFileExport) {
        savedLocation = await FileExportService.withTemporaryOutput(
          fileName: fileName,
          action: (temporaryPath) async {
            success = await ZipUtils.createZipFromImages(
              imagePaths,
              temporaryPath,
            );
            if (!success || !context.mounted) return null;
            return FileExportService.saveFileFromPath(
              sourcePath: temporaryPath,
              fileName: fileName,
              dialogTitle: context.l10n.localGallery_saveZipArchive,
              mimeType: 'application/zip',
              allowedExtensions: const ['zip'],
            );
          },
        );
      } else {
        success = await ZipUtils.createZipFromImages(
          imagePaths,
          desktopOutputPath!,
        );
        savedLocation = desktopOutputPath;
      }

      if (context.mounted) {
        if (success && savedLocation != null) {
          AppToast.success(
            context,
            context.l10n.toast_packedImages(selectedImages.length),
          );
          setState(() {
            _selectedIds.clear();
          });
        } else if (!success) {
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
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
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

      // 原子保存：日期分类路径 + 独占防冲突 + 失败清理，全部在工具内完成
      final filePath = await ImageSaveUtils.saveBytesToDatedPath(
        rootPath: saveDirPath,
        bytes: image.bytes,
        seed: await ImageSaveUtils.resolveSeed(
          metadata: image.metadata,
          bytes: image.bytes,
        ),
      );

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      // 在文件夹中打开并选中文件
      await FileExplorerUtils.revealFile(filePath);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDirPath));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  void _showLinkedDetail(BuildContext context, GeneratedImage image) {
    final state = ref.read(imageGenerationNotifierProvider);
    final sequence = state.detailSequenceFor(image);
    final initialIndex = sequence.indexWhere((item) => item.id == image.id);
    final detailImages = sequence.map(_createDetailData).toList();
    if (!context.mounted || detailImages.isEmpty) return;

    ImageDetailOpener.showMultipleImmediate(
      context,
      images: detailImages,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      showMetadataPanel: true,
      showThumbnails: detailImages.length > 1,
      callbacks: ImageDetailCallbacks(
        onSave: (detail) async {
          if (!detail.showSaveButton) return;
          await GenerationSaveService.saveImageFromDetail(context, ref, detail);
        },
      ),
    );
  }

  ImageDetailData _createDetailData(GeneratedImage image) {
    final filePath = image.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      ImageMetadataService().enqueuePreload(
        taskId: image.id,
        filePath: filePath,
      );
      return FileImageDetailData(
        filePath: filePath,
        cachedBytes: image.bytes,
        id: image.id,
        initialMetadata: image.metadata,
        showCopyButton: image.canSave,
      );
    }
    return GeneratedImageDetailData(
      imageBytes: image.bytes,
      metadata: image.metadata,
      id: image.id,
      showSaveButton: image.canSave,
      showCopyButton: image.canSave,
      preserveOriginalBytesOnSave: image.preserveOriginalBytesOnSave,
      fixedTagUsageSnapshot: image.fixedTagUsageSnapshot,
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
