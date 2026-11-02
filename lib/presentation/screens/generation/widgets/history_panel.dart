import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/file_explorer_utils.dart';
import '../../../../core/utils/image_share_sanitizer.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/copy_drag_watermark_provider.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/generation/image_card_selection_provider.dart';
import '../../../providers/generation/preview_selection_provider.dart';
import '../../../providers/history_click_behavior_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../providers/share_image_settings_provider.dart';
import '../../../selection/card_selection_scope.dart';
import '../../../services/image_workflow_launcher.dart';
import '../../../utils/image_detail_opener.dart';
import '../../../utils/krita_send_helper.dart';
import '../../../utils/precise_ref_library_import_helper.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_card_action.dart';
import '../../../widgets/common/image_card_batch_scope.dart';
import '../../../widgets/common/image_detail/image_detail_viewer.dart';
import '../../../widgets/common/owned_scroll_controller.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import '../services/generated_image_file_link.dart';
import '../services/generation_detail_data.dart';
import '../services/generation_image_batch_actions.dart';
import '../services/generation_image_deletion.dart';
import '../services/generation_save_service.dart';
import 'history_panel/history_image_actions.dart';
import 'history_panel/history_panel_bottom_actions.dart';
import 'history_panel/history_panel_empty_state.dart';
import 'history_panel/history_panel_header.dart';
import 'history_panel/history_panel_layout.dart';
import 'history_panel/history_panel_list.dart';
import 'history_panel/history_share_preheat_controller.dart';

export 'history_panel/history_panel_layout.dart'
    show
        resolveCurrentHistoryPreviewAspectRatio,
        resolveHistoryPreviewAspectRatio;

/// 历史面板组件
class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({
    super.key,
    this.onClose,
    this.onCollapse,
    this.embedded = false,
    this.viewportOffset,
    this.sharePreparationService,
  });

  final ShareImagePreparationService? sharePreparationService;
  final VoidCallback? onClose;

  /// 替换默认的“收起右栏”行为，按钮仍表达收起而非关闭。
  final VoidCallback? onCollapse;

  /// 嵌入模式：隐藏自带标题行，由外层 Tab 栏承担标题职责。
  final bool embedded;
  final OwnedViewportOffset? viewportOffset;

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  static const _pinnedHoverActions = [
    ImageCardActionId.copy,
    ImageCardActionId.delete,
  ];

  Set<String> get _selectedIds =>
      ref.read(generationImageCardSelectionProvider).selectedIds;
  GenerationImageCardSelection get _selection =>
      ref.read(generationImageCardSelectionProvider.notifier);
  late final ShareImagePreparationService _sharePreparationService;
  late final HistorySharePreheatController _preheatController;
  final Map<String, bool> _favoriteStates = {};
  final Map<String, String?> _favoriteStatePaths = {};
  final Set<String> _favoriteStatusLoadingIds = {};
  final Set<String> _favoriteToggleLoadingIds = {};
  late final OwnedScrollController _scrollController;
  late final GenerationImageDeletion _deletion;
  final Map<String, GlobalKey> _imageKeys = {};
  List<HistoryRowDescriptor> _rowDescriptors = const [];
  ProviderSubscription<String?>? _selectionSubscription;
  int _scrollRequestEpoch = 0;

  @override
  void initState() {
    super.initState();
    _sharePreparationService =
        widget.sharePreparationService ?? ShareImagePreparationService.instance;
    _preheatController = HistorySharePreheatController(
      sharePreparationService: _sharePreparationService,
      isMounted: () => mounted,
      onScrollingChanged: () {
        if (mounted) setState(() {});
      },
      readTransform: () => ref.read(copyDragWatermarkProvider),
      readCurrentMaintenanceState: () {
        final currentState = ref.read(imageGenerationNotifierProvider);
        final currentStripMetadata = ref
            .read(shareImageSettingsProvider)
            .effectiveStripMetadataForCopyAndDrag;
        return (
          images: currentState.selectableMergedImages,
          stripMetadata: currentStripMetadata,
        );
      },
      isImageVisible: _isHistoryImageVisible,
    );
    _scrollController = OwnedScrollController(viewport: widget.viewportOffset);
    _deletion = GenerationImageDeletion(context: context, ref: ref);
    _sharePreparationService.addListener(_handleSharePreparationChanged);
    _selectionSubscription = ref.listenManual(
      generationPreviewSelectionProvider,
      (_, selectedId) => _scheduleScrollToSelection(selectedId),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _preheatController.dispose();
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
    ref.watch(
      imageGenerationNotifierProvider.select(HistoryPanelStructure.fromState),
    );
    final state = ref.read(imageGenerationNotifierProvider);
    final selection = ref.watch(generationImageCardSelectionProvider);
    ref.watch(copyDragWatermarkProvider);
    final stripMetadata = ref.watch(
      shareImageSettingsProvider.select(
        (settings) => settings.effectiveStripMetadataForCopyAndDrag,
      ),
    );
    final clickBehavior = ref.watch(historyClickBehaviorNotifierProvider);
    final selectedPreviewId =
        clickBehavior == HistoryClickBehavior.selectPreview
        ? ref.watch(generationPreviewSelectionProvider)
        : null;
    _preheatController.scheduleMaintenance(
      state.selectableMergedImages,
      stripMetadata,
    );

    final allSelectableImages = state.selectableMergedImages;
    final selectedImages = allSelectableImages
        .where((image) => selection.isSelected(image.id))
        .toList();
    final hasItems = state.history.isNotEmpty || state.currentImages.isNotEmpty;
    final allSelected =
        hasItems && _selectedIds.length == allSelectableImages.length;

    return ImageCardBatchScope(
      runner: _selection.actionRunner,
      targetIds: selection.selectedIds,
      actions: GenerationImageBatchActions(
        context: context,
        images: selectedImages,
        selection: _selection,
        deletion: _deletion,
        saveImages: (images) =>
            GenerationSaveService.saveImages(context, ref, images),
        saveImagesToFolder: (images) =>
            GenerationSaveService.saveImagesAsToFolder(context, ref, images),
      ).build(),
      child: CardSelectionScope(
        selection: selection,
        commands: _selection,
        orderedIds: allSelectableImages.map((image) => image.id).toList(),
        child: CardSelectionShortcuts(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistoryPanelHeader(
                embedded: widget.embedded,
                hasItems: hasItems,
                totalCount: allSelectableImages.length,
                allSelected: allSelected,
                onToggleSelectAll: () => _toggleSelectAll(allSelectableImages),
                onClear: () => showClearHistoryConfirmDialog(
                  context,
                  ref,
                  onCleared: () {
                    setState(() {
                      _selection.clearSelection();
                    });
                  },
                ),
                onCollapse:
                    widget.onClose ??
                    widget.onCollapse ??
                    () => ref
                        .read(layoutStateNotifierProvider.notifier)
                        .setRightPanelExpanded(false),
                isCloseButton: widget.onClose != null,
              ),
              Expanded(
                child:
                    state.history.isEmpty && !hasCurrentHistoryGeneration(state)
                    ? const HistoryPanelEmptyState()
                    : _buildHistoryList(
                        state,
                        stripMetadata: stripMetadata,
                        clickBehavior: clickBehavior,
                        selectedPreviewId: selectedPreviewId,
                      ),
              ),
              if (_selectedIds.isNotEmpty) const HistoryPanelBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelectAll(List<GeneratedImage> allImages) {
    setState(() {
      if (_selectedIds.length == allImages.length) {
        _selection.clearSelection();
      } else {
        _selection.clearSelection();
        _selection.enter();
        _selection.selectAll(allImages.map((img) => img.id));
      }
    });
  }

  Widget _buildHistoryList(
    ImageGenerationState state, {
    required bool stripMetadata,
    required HistoryClickBehavior clickBehavior,
    required String? selectedPreviewId,
  }) {
    final previewDimensions = ref.watch(
      generationParamsNotifierProvider.select(selectPreviewDimensionsViewData),
    );
    return HistoryPanelList(
      state: state,
      previewWidth: previewDimensions.width,
      previewHeight: previewDimensions.height,
      scrollController: _scrollController,
      stripMetadata: stripMetadata,
      clickBehavior: clickBehavior,
      selectedPreviewId: selectedPreviewId,
      selectedIds: _selectedIds,
      selectionActive: ref.read(generationImageCardSelectionProvider).isActive,
      isHistoryScrolling: _preheatController.isHistoryScrolling,
      transform: ref.read(copyDragWatermarkProvider),
      sharePreparationService: _sharePreparationService,
      pinnedHoverActions: _pinnedHoverActions,
      onDescriptorsUpdated: (descriptors) {
        _rowDescriptors = descriptors;
        final retainedIds = descriptors
            .map((row) => row.imageId)
            .whereType<String>()
            .toSet();
        _imageKeys.removeWhere((id, _) => !retainedIds.contains(id));
      },
      onScrollNotification: (notification) => _preheatController
          .handleScrollNotification(notification, stripMetadata),
      imageKeyFor: _imageKeyFor,
      favoriteStateFor: _favoriteStateFor,
      onHoverEnter: (image) =>
          _preheatController.scheduleHoverPreheat(image, stripMetadata),
      onHoverExit: _preheatController.cancelHoverPreheat,
      onSave: (image) =>
          GenerationSaveService.saveImages(context, ref, [image]),
      onSaveAs: (image) =>
          GenerationSaveService.saveImageAs(context, ref, image),
      onFavoriteToggle: (image) => _toggleHistoryFavorite(context, image),
      onDelete: (image) => _deletion.confirmAndDelete([image]),
      onSelectionChanged: (image, selected) {
        if (!image.canBulkSelect) return;
        setState(() {
          if (selected) {
            _selection.enterAndSelect(image.id);
          } else {
            _selection.deselect(image.id);
          }
        });
      },
      onTap: (image) => _handleImageTap(context, image, clickBehavior),
      onDoubleTap: (image) => _showLinkedDetail(context, image),
      onLongPress: (image) => _selection.enterAndSelect(image.id),
      onFullscreen: (image) => _showLinkedDetail(context, image),
      onReversePrompt: (image) =>
          unawaited(sendHistoryImageToReversePrompt(context, ref, image)),
      onImageToImage: (image) =>
          sendHistoryImageToImageToImage(context, ref, image),
      onVibeTransfer: (image) =>
          unawaited(sendHistoryImageToVibeTransfer(context, ref, image)),
      onPreciseReference: (image) =>
          unawaited(sendHistoryImageToPreciseReference(context, ref, image)),
      onSaveToPreciseRefLibrary: (image) =>
          unawaited(saveBytesToPreciseRefLibrary(ref, context, image.bytes)),
      onEditImage: (image) => ImageWorkflowLauncher.openEditor(
        context,
        ref,
        image.bytes,
        mode: ImageEditorMode.edit,
      ),
      onInpaint: (image) =>
          ImageWorkflowLauncher.openInpaint(context, ref, image.bytes),
      onGenerateVariations: (image) =>
          ImageWorkflowLauncher.generateVariations(context, ref, image.bytes),
      onDirectorTools: (image) =>
          ImageWorkflowLauncher.openDirectorTools(context, ref, image.bytes),
      onEnhance: (image) => ImageWorkflowLauncher.openEnhance(ref, image.bytes),
      onUpscale: (image) => ImageWorkflowLauncher.openUpscale(ref, image.bytes),
      onSendToKrita: (image) => KritaSendHelper.sendImageBytes(
        context,
        ref,
        image.bytes,
        name: 'history_${image.id}.png',
      ),
      onOpenInExplorer: (image) => _openImageInExplorer(context, image),
      onSaveToLibrary: (bytes, _) =>
          showSaveHistoryImageToLibraryDialog(context, ref, bytes),
    );
  }

  bool _isHistoryImageVisible(String imageId) {
    final item = _imageKeys[imageId]?.currentContext?.findRenderObject();
    final panel = context.findRenderObject();
    if (item is! RenderBox ||
        !item.attached ||
        !item.hasSize ||
        panel is! RenderBox ||
        !panel.attached ||
        !panel.hasSize) {
      return false;
    }
    return (item.localToGlobal(Offset.zero) & item.size).overlaps(
      panel.localToGlobal(Offset.zero) & panel.size,
    );
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

  void _handleImageTap(
    BuildContext context,
    GeneratedImage image,
    HistoryClickBehavior behavior,
  ) {
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

    final gallery = ref.read(localGalleryNotifierProvider.notifier);
    try {
      final linked = await GeneratedImageFileLink.ensureSaved(
        ref,
        image,
        context.l10n,
      );
      final filePath = linked.path;
      final isFavorite = await gallery.toggleFavorite(filePath);

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
        GenerationSaveService.showSystemGalleryFailure(context, linked);
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

  /// 在文件夹中定位图片。已保存的图片直接定位原文件，未保存时先保存再定位。
  Future<void> _openImageInExplorer(
    BuildContext context,
    GeneratedImage image,
  ) async {
    try {
      final linked = await GeneratedImageFileLink.ensureSaved(
        ref,
        image,
        context.l10n,
      );
      await FileExplorerUtils.revealFile(linked.path);
      if (context.mounted) {
        GenerationSaveService.showNewlySavedFeedback(context, linked);
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
    final detailImages = sequence.map(GenerationDetailData.forImage).toList();
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
        onSaveAs: (detail) =>
            GenerationSaveService.saveImageAsFromDetail(context, ref, detail),
        contextMenuActions: (_, detail) {
          final image = sequence.firstWhereOrNull(
            (i) => i.id == detail.identifier,
          );
          if (image == null) return const [];
          final l10n = context.l10n;
          ImageCardAction action(
            ImageCardActionId id,
            IconData icon,
            String label,
            VoidCallback run,
          ) => ImageCardAction(id: id, icon: icon, label: label, invoke: run);
          return [
            if (image.canUseAsGenerationInput) ...[
              action(
                ImageCardActionId.reversePrompt,
                Icons.manage_search_rounded,
                l10n.drop_reversePrompt,
                () =>
                    unawaited(_sendHistoryImageToReversePrompt(context, image)),
              ),
              action(
                ImageCardActionId.imageToImage,
                Icons.image_outlined,
                l10n.drop_img2img,
                () => _sendHistoryImageToImageToImage(context, image),
              ),
              action(
                ImageCardActionId.vibeTransfer,
                Icons.palette_outlined,
                l10n.drop_vibeTransfer,
                () =>
                    unawaited(_sendHistoryImageToVibeTransfer(context, image)),
              ),
              action(
                ImageCardActionId.preciseReference,
                Icons.center_focus_strong,
                l10n.drop_characterReference,
                () => unawaited(
                  _sendHistoryImageToPreciseReference(context, image),
                ),
              ),
              action(
                ImageCardActionId.saveToPreciseRefLibrary,
                Icons.bookmark_add_outlined,
                l10n.drop_saveToPreciseRefLibrary,
                () => unawaited(
                  saveBytesToPreciseRefLibrary(ref, context, image.bytes),
                ),
              ),
            ],
            if (image.canSave &&
                PlatformCapabilities.current.supportsOpenFolder)
              action(
                ImageCardActionId.openFolder,
                Icons.folder_open,
                l10n.shortcut_action_open_folder,
                () => unawaited(_openImageInExplorer(context, image)),
              ),
          ];
        },
      ),
    );
  }
}
