import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/platform/platform_capabilities.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/image/image_stream_chunk.dart';
import '../../../../providers/history_click_behavior_provider.dart';
import '../../../../providers/image_generation_provider.dart';
import '../../../../widgets/common/image_card_action.dart';
import '../../../../widgets/common/selectable_image_card.dart';
import 'history_panel_layout.dart';

class HistoryImageCard extends StatelessWidget {
  const HistoryImageCard({
    super.key,
    required this.image,
    required this.index,
    required this.showIndex,
    required this.isSelected,
    required this.isPreviewActive,
    required this.isFavorite,
    required this.dragPreparationReady,
    required this.selectionMode,
    required this.hoverEffectsEnabled,
    required this.clickBehavior,
    required this.pinnedHoverActions,
    this.completionPreview,
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

  final GeneratedImage image;
  final int index;
  final bool showIndex;
  final bool isSelected;
  final bool isPreviewActive;
  final bool isFavorite;
  final bool dragPreparationReady;
  final bool selectionMode;
  final bool hoverEffectsEnabled;
  final HistoryClickBehavior clickBehavior;
  final List<ImageCardActionId> pinnedHoverActions;
  final StreamPreviewFrame? completionPreview;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onFullscreen;
  final VoidCallback onReversePrompt;
  final VoidCallback onImageToImage;
  final VoidCallback onVibeTransfer;
  final VoidCallback onPreciseReference;
  final VoidCallback onSaveToPreciseRefLibrary;
  final VoidCallback onEditImage;
  final VoidCallback onInpaint;
  final VoidCallback onGenerateVariations;
  final VoidCallback onDirectorTools;
  final VoidCallback onEnhance;
  final VoidCallback onUpscale;
  final VoidCallback onSendToKrita;
  final VoidCallback onOpenInExplorer;
  final void Function(Uint8List bytes, String? prompt) onSaveToLibrary;

  @override
  Widget build(BuildContext context) {
    final isFailedSnapshot = image.isFailedStreamSnapshot;
    return SelectableImageCard(
      key: ValueKey(image.id),
      imageBytes: image.bytes,
      sourceFilePath: image.filePath,
      index: index,
      showIndex: showIndex,
      isSelected: isSelected,
      isPreviewActive: isPreviewActive,
      imageIdentity: image.id,
      allowRepeatedModifierTaps: true,
      isFavorite: isFavorite,
      dragPreparationReady: dragPreparationReady,
      completionPreview: completionPreview,
      enableSelection: image.canBulkSelect,
      selectionMode: selectionMode,
      onSave: image.canSave ? onSave : null,
      onSaveAs: image.canSave ? onSaveAs : null,
      enableCopyAction: image.canSave,
      statusBadgeLabel: isFailedSnapshot
          ? context.l10n.generation_failedStreamSnapshot
          : null,
      statusBadgeTooltip: isFailedSnapshot
          ? context.l10n.generation_failedStreamSnapshotHint
          : null,
      onFavoriteToggle: image.canFavorite ? onFavoriteToggle : null,
      showHoverActionBar: false,
      pinnedHoverActions: pinnedHoverActions,
      onDelete: onDelete,
      onSelectionChanged: onSelectionChanged,
      onTap: onTap,
      onDoubleTap: clickBehavior == HistoryClickBehavior.selectPreview
          ? onDoubleTap
          : null,
      onLongPress: image.canBulkSelect ? onLongPress : onDoubleTap,
      onFullscreen: onFullscreen,
      enableContextMenu: true,
      hoverEffectsEnabled: hoverEffectsEnabled,
      shareWarmupEnabled: false,
      onReversePrompt: image.canUseAsGenerationInput ? onReversePrompt : null,
      onImageToImage: image.canUseAsGenerationInput ? onImageToImage : null,
      onVibeTransfer: image.canUseAsGenerationInput ? onVibeTransfer : null,
      onPreciseReference: image.canUseAsGenerationInput
          ? onPreciseReference
          : null,
      onSaveToPreciseRefLibrary: image.canUseAsGenerationInput
          ? onSaveToPreciseRefLibrary
          : null,
      onEditImage: image.canUseAsGenerationInput ? onEditImage : null,
      onInpaint: image.canUseAsGenerationInput ? onInpaint : null,
      onGenerateVariations: image.canUseAsGenerationInput
          ? onGenerateVariations
          : null,
      onDirectorTools: image.canUseAsGenerationInput ? onDirectorTools : null,
      onEnhance: image.canUseAsGenerationInput ? onEnhance : null,
      onUpscale: image.canUseAsGenerationInput ? onUpscale : null,
      // Krita 桥接只在桌面可用，移动端菜单里出现这一项点了只会提示未连接
      onSendToKrita:
          image.canUseAsGenerationInput &&
              PlatformCapabilities.current.supportsKritaBridge
          ? onSendToKrita
          : null,
      onOpenInExplorer:
          image.canSave && PlatformCapabilities.current.supportsOpenFolder
          ? onOpenInExplorer
          : null,
      onSaveToLibrary: image.canUseAsGenerationInput ? onSaveToLibrary : null,
    );
  }
}

typedef _HistoryStreamPreviewData = ({
  int currentImage,
  int totalImages,
  double progress,
  Uint8List? previewBytes,
  FocusedStreamPreviewPlacement? focusedPreviewPlacement,
});

class HistoryStreamPreviewCard extends ConsumerWidget {
  const HistoryStreamPreviewCard({
    super.key,
    required this.generationIndex,
    required this.imageWidth,
    required this.imageHeight,
  });

  final int generationIndex;
  final int imageWidth;
  final int imageHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(
      imageGenerationNotifierProvider.select(_selectPreview),
    );
    if (preview == null) return const SizedBox.shrink();

    return SelectableImageCard(
      isGenerating: true,
      currentImage: preview.currentImage,
      totalImages: preview.totalImages,
      progress: preview.progress,
      streamPreview: preview.previewBytes,
      focusedPreviewPlacement: preview.focusedPreviewPlacement,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      enableSelection: false,
      enableContextMenu: false,
    );
  }

  _HistoryStreamPreviewData? _selectPreview(ImageGenerationState state) {
    if (!state.isGenerating) return null;
    final previewSlots = visibleHistoryStreamPreviewSlots(state);
    if (previewSlots.isNotEmpty && generationIndex < previewSlots.length) {
      final slot = previewSlots[generationIndex];
      return (
        currentImage: slot.imageNumber,
        totalImages: slot.totalImages,
        progress: slot.progress,
        previewBytes: slot.previewBytes,
        focusedPreviewPlacement: slot.focusedPreviewPlacement,
      );
    }

    if (previewSlots.isEmpty && generationIndex == 0) {
      return (
        currentImage: state.currentImage,
        totalImages: state.totalImages,
        progress: state.progress,
        previewBytes: state.streamPreview,
        focusedPreviewPlacement: state.focusedPreviewPlacement,
      );
    }

    return null;
  }
}
