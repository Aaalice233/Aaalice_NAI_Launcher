import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../core/utils/image_share_sanitizer.dart';
import '../../../../../data/models/image/image_stream_chunk.dart';
import '../../../../providers/history_click_behavior_provider.dart';
import '../../../../providers/image_generation_provider.dart';
import '../../../../widgets/common/image_card_action.dart';
import 'history_image_card.dart';
import 'history_panel_layout.dart';
import 'history_prepared_drag_item.dart';

class HistoryPanelList extends StatelessWidget {
  const HistoryPanelList({
    super.key,
    required this.state,
    required this.previewWidth,
    required this.previewHeight,
    required this.scrollController,
    required this.stripMetadata,
    required this.clickBehavior,
    required this.selectedPreviewId,
    required this.selectedIds,
    required this.selectionActive,
    required this.isHistoryScrolling,
    required this.transform,
    required this.sharePreparationService,
    required this.pinnedHoverActions,
    required this.onDescriptorsUpdated,
    required this.onScrollNotification,
    required this.imageKeyFor,
    required this.favoriteStateFor,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onSave,
    required this.onSaveAs,
    required this.onFavoriteToggle,
    required this.onDelete,
    required this.onSelectionChanged,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onFullscreen,
    required this.onReversePrompt,
    required this.onImageToImage,
    required this.onVibeTransfer,
    required this.onPreciseReference,
    required this.onSaveToPreciseRefLibrary,
    required this.onEditImage,
    required this.onInpaint,
    required this.onGenerateVariations,
    required this.onDirectorTools,
    required this.onEnhance,
    required this.onUpscale,
    required this.onSendToKrita,
    required this.onOpenInExplorer,
    required this.onSaveToLibrary,
  });

  final ImageGenerationState state;
  final int previewWidth;
  final int previewHeight;
  final ScrollController scrollController;
  final bool stripMetadata;
  final HistoryClickBehavior clickBehavior;
  final String? selectedPreviewId;
  final Set<String> selectedIds;
  final bool selectionActive;
  final bool isHistoryScrolling;
  final ShareImageTransform? transform;
  final ShareImagePreparationService sharePreparationService;
  final List<ImageCardActionId> pinnedHoverActions;
  final void Function(List<HistoryRowDescriptor> descriptors)
  onDescriptorsUpdated;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;
  final GlobalKey Function(String imageId) imageKeyFor;
  final bool Function(GeneratedImage image) favoriteStateFor;
  final void Function(GeneratedImage image) onHoverEnter;
  final VoidCallback onHoverExit;
  final void Function(GeneratedImage image) onSave;
  final void Function(GeneratedImage image) onSaveAs;
  final void Function(GeneratedImage image) onFavoriteToggle;
  final void Function(GeneratedImage image) onDelete;
  final void Function(GeneratedImage image, bool selected) onSelectionChanged;
  final void Function(GeneratedImage image) onTap;
  final void Function(GeneratedImage image) onDoubleTap;
  final void Function(GeneratedImage image) onLongPress;
  final void Function(GeneratedImage image) onFullscreen;
  final void Function(GeneratedImage image) onReversePrompt;
  final void Function(GeneratedImage image) onImageToImage;
  final void Function(GeneratedImage image) onVibeTransfer;
  final void Function(GeneratedImage image) onPreciseReference;
  final void Function(GeneratedImage image) onSaveToPreciseRefLibrary;
  final void Function(GeneratedImage image) onEditImage;
  final void Function(GeneratedImage image) onInpaint;
  final void Function(GeneratedImage image) onGenerateVariations;
  final void Function(GeneratedImage image) onDirectorTools;
  final void Function(GeneratedImage image) onEnhance;
  final void Function(GeneratedImage image) onUpscale;
  final void Function(GeneratedImage image) onSendToKrita;
  final void Function(GeneratedImage image) onOpenInExplorer;
  final void Function(Uint8List bytes, String? prompt) onSaveToLibrary;

  @override
  Widget build(BuildContext context) {
    final history = state.history;
    // 使用批次分辨率（点击生成时捕获），fallback 到全局参数
    final batchAspectRatio =
        (state.batchWidth != null && state.batchHeight != null)
        ? state.batchWidth! / state.batchHeight!
        : previewWidth / previewHeight;

    final currentGenerationCount = getCurrentHistoryGenerationCount(state);
    final deduplicatedHistory = deduplicateHistoryImages(state);
    final totalCount = currentGenerationCount + deduplicatedHistory.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = (constraints.maxWidth - 16).clamp(
          1.0,
          double.infinity,
        );
        final descriptors = buildHistoryRowDescriptors(
          rowWidth: rowWidth,
          batchAspectRatio: batchAspectRatio,
          currentGenerationCount: currentGenerationCount,
          currentImages: state.currentImages,
          deduplicatedHistory: deduplicatedHistory,
        );
        onDescriptorsUpdated(descriptors);

        return NotificationListener<ScrollNotification>(
          onNotification: onScrollNotification,
          child: ListView.builder(
            controller: scrollController,
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
                    child: currentImage != null
                        ? _buildPreparedCard(
                            image: currentImage,
                            index: index,
                            showIndex: true,
                            completionPreview:
                                state.completionPreviews[currentImage.id],
                          )
                        : HistoryStreamPreviewCard(
                            state: state,
                            generationIndex: index - state.currentImages.length,
                            imageWidth: state.batchWidth ?? previewWidth,
                            imageHeight: state.batchHeight ?? previewHeight,
                          ),
                  ),
                );
                return currentImage == null
                    ? item
                    : KeyedSubtree(
                        key: imageKeyFor(currentImage.id),
                        child: item,
                      );
              }

              // 历史图像（已去重）- 使用图像自己的宽高比
              final historyIndex = index - currentGenerationCount;
              final historyImage = deduplicatedHistory[historyIndex];
              // 计算在原始 history 中的真实索引（用于选择操作）
              final actualHistoryIndex = history.indexOf(historyImage);
              return KeyedSubtree(
                key: imageKeyFor(historyImage.id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AspectRatio(
                    aspectRatio: resolveHistoryPreviewAspectRatio(
                      historyImage.aspectRatio,
                      fallback: batchAspectRatio,
                    ),
                    child: _buildPreparedCard(
                      image: historyImage,
                      index: actualHistoryIndex,
                      showIndex: false,
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

  Widget _buildPreparedCard({
    required GeneratedImage image,
    required int index,
    required bool showIndex,
    StreamPreviewFrame? completionPreview,
  }) {
    final isFavorite = favoriteStateFor(image);
    return HistoryPreparedDragItem(
      image: image,
      stripMetadata: stripMetadata,
      transform: transform,
      sharePreparationService: sharePreparationService,
      onHoverEnter: () => onHoverEnter(image),
      onHoverExit: onHoverExit,
      childBuilder: (dragPreparationReady) => HistoryImageCard(
        image: image,
        index: index,
        showIndex: showIndex,
        isSelected: selectedIds.contains(image.id),
        isPreviewActive: selectedPreviewId == image.id,
        isFavorite: isFavorite,
        dragPreparationReady: dragPreparationReady,
        completionPreview: completionPreview,
        selectionMode: selectionActive,
        hoverEffectsEnabled: !isHistoryScrolling,
        clickBehavior: clickBehavior,
        pinnedHoverActions: pinnedHoverActions,
        onSave: () => onSave(image),
        onSaveAs: () => onSaveAs(image),
        onFavoriteToggle: () => onFavoriteToggle(image),
        onDelete: () => onDelete(image),
        onSelectionChanged: (selected) => onSelectionChanged(image, selected),
        onTap: () => onTap(image),
        onDoubleTap: () => onDoubleTap(image),
        onLongPress: () => onLongPress(image),
        onFullscreen: () => onFullscreen(image),
        onReversePrompt: () => onReversePrompt(image),
        onImageToImage: () => onImageToImage(image),
        onVibeTransfer: () => onVibeTransfer(image),
        onPreciseReference: () => onPreciseReference(image),
        onSaveToPreciseRefLibrary: () => onSaveToPreciseRefLibrary(image),
        onEditImage: () => onEditImage(image),
        onInpaint: () => onInpaint(image),
        onGenerateVariations: () => onGenerateVariations(image),
        onDirectorTools: () => onDirectorTools(image),
        onEnhance: () => onEnhance(image),
        onUpscale: () => onUpscale(image),
        onSendToKrita: () => onSendToKrita(image),
        onOpenInExplorer: () => onOpenInExplorer(image),
        onSaveToLibrary: onSaveToLibrary,
      ),
    );
  }
}
