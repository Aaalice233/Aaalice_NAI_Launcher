import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/image/image_stream_chunk.dart';
import 'image_card_actions.dart';
import 'image_card_context_menu.dart';
import 'image_card_controller.dart';
import 'image_card_generating.dart';
import 'image_card_models.dart';
import 'image_card_surface.dart';

export 'image_card_actions.dart'
    show ImageClipboardWriter, imageClipboardWriterProvider;

/// 可选择的图像卡片。构造契约保持兼容，内部状态与视图由专属组件协作。
class SelectableImageCard extends ConsumerStatefulWidget {
  const SelectableImageCard({
    super.key,
    this.imageBytes,
    this.index,
    this.isSelected = false,
    this.showIndex = true,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSelectionChanged,
    this.onFullscreen,
    this.isPreviewActive = false,
    this.imageIdentity,
    this.allowRepeatedModifierTaps = false,
    this.enableContextMenu = true,
    this.enableHoverScale = true,
    this.enableGlossEffect = false,
    this.hoverEffectsEnabled = true,
    this.shareWarmupEnabled = true,
    this.enableSaveAction = true,
    this.enableCopyAction = true,
    this.statusBadgeLabel,
    this.statusBadgeTooltip,
    this.dragPreparationReady = true,
    this.completionPlaceholderBytes,
    this.onCompletionPlaceholderSettled,
    this.enableSelection = true,
    this.onUpscale,
    this.onReversePrompt,
    this.onImageToImage,
    this.onVibeTransfer,
    this.onPreciseReference,
    this.onSaveToPreciseRefLibrary,
    this.onEditImage,
    this.onInpaint,
    this.onGenerateVariations,
    this.onDirectorTools,
    this.onEnhance,
    this.onSendToKrita,
    this.onShareToDiscord,
    this.onOpenInExplorer,
    this.sourceFilePath,
    this.onSaveToLibrary,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.underlay,
    this.imageContent,
    this.isGenerating = false,
    this.progress,
    this.currentImage,
    this.totalImages,
    this.streamPreview,
    this.focusedPreviewPlacement,
    this.imageWidth,
    this.imageHeight,
  }) : assert(
         !isGenerating || (imageWidth != null && imageHeight != null),
         'imageWidth and imageHeight are required when isGenerating is true',
       );

  final Uint8List? imageBytes;
  final int? index;
  final bool isSelected;
  final bool showIndex;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onFullscreen;
  final bool isPreviewActive;
  final Object? imageIdentity;
  final bool allowRepeatedModifierTaps;
  final bool enableContextMenu;
  final bool enableHoverScale;
  final bool enableGlossEffect;
  final bool hoverEffectsEnabled;
  final bool shareWarmupEnabled;
  final bool enableSaveAction;
  final bool enableCopyAction;
  final String? statusBadgeLabel;
  final String? statusBadgeTooltip;
  final bool dragPreparationReady;
  final Uint8List? completionPlaceholderBytes;
  final VoidCallback? onCompletionPlaceholderSettled;
  final bool enableSelection;
  final VoidCallback? onUpscale;
  final VoidCallback? onReversePrompt;
  final VoidCallback? onImageToImage;
  final VoidCallback? onVibeTransfer;
  final VoidCallback? onPreciseReference;
  final VoidCallback? onSaveToPreciseRefLibrary;
  final VoidCallback? onEditImage;
  final VoidCallback? onInpaint;
  final VoidCallback? onGenerateVariations;
  final VoidCallback? onDirectorTools;
  final VoidCallback? onEnhance;
  final VoidCallback? onSendToKrita;
  final VoidCallback? onShareToDiscord;
  final VoidCallback? onOpenInExplorer;
  final String? sourceFilePath;
  final void Function(Uint8List imageBytes, String prompt)? onSaveToLibrary;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Widget? underlay;
  final Widget? imageContent;
  final bool isGenerating;
  final double? progress;
  final int? currentImage;
  final int? totalImages;
  final Uint8List? streamPreview;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;
  final int? imageWidth;
  final int? imageHeight;

  @override
  ConsumerState<SelectableImageCard> createState() =>
      _SelectableImageCardState();
}

class _SelectableImageCardState extends ConsumerState<SelectableImageCard>
    with TickerProviderStateMixin {
  late final ImageCardController _controller;

  ImageCardViewData get _data => ImageCardViewData(
    imageBytes: widget.imageBytes,
    index: widget.index,
    isSelected: widget.isSelected,
    showIndex: widget.showIndex,
    isPreviewActive: widget.isPreviewActive,
    imageIdentity: widget.imageIdentity,
    statusBadgeLabel: widget.statusBadgeLabel,
    statusBadgeTooltip: widget.statusBadgeTooltip,
    dragPreparationReady: widget.dragPreparationReady,
    completionPlaceholderBytes: widget.completionPlaceholderBytes,
    isFavorite: widget.isFavorite,
    underlay: widget.underlay,
    imageContent: widget.imageContent,
    isGenerating: widget.isGenerating,
    progress: widget.progress,
    currentImage: widget.currentImage,
    totalImages: widget.totalImages,
    streamPreview: widget.streamPreview,
    focusedPreviewPlacement: widget.focusedPreviewPlacement,
    imageWidth: widget.imageWidth,
    imageHeight: widget.imageHeight,
    sourceFilePath: widget.sourceFilePath,
  );

  ImageCardCapabilities get _capabilities => ImageCardCapabilities(
    allowRepeatedModifierTaps: widget.allowRepeatedModifierTaps,
    enableContextMenu: widget.enableContextMenu,
    enableHoverScale: widget.enableHoverScale,
    enableGlossEffect: widget.enableGlossEffect,
    hoverEffectsEnabled: widget.hoverEffectsEnabled,
    shareWarmupEnabled: widget.shareWarmupEnabled,
    enableSaveAction: widget.enableSaveAction,
    enableCopyAction: widget.enableCopyAction,
    enableSelection: widget.enableSelection,
    onTap: widget.onTap,
    onDoubleTap: widget.onDoubleTap,
    onLongPress: widget.onLongPress,
    onSelectionChanged: widget.onSelectionChanged,
    onFullscreen: widget.onFullscreen,
    onUpscale: widget.onUpscale,
    onReversePrompt: widget.onReversePrompt,
    onImageToImage: widget.onImageToImage,
    onVibeTransfer: widget.onVibeTransfer,
    onPreciseReference: widget.onPreciseReference,
    onSaveToPreciseRefLibrary: widget.onSaveToPreciseRefLibrary,
    onEditImage: widget.onEditImage,
    onInpaint: widget.onInpaint,
    onGenerateVariations: widget.onGenerateVariations,
    onDirectorTools: widget.onDirectorTools,
    onEnhance: widget.onEnhance,
    onSendToKrita: widget.onSendToKrita,
    onShareToDiscord: widget.onShareToDiscord,
    onOpenInExplorer: widget.onOpenInExplorer,
    onSaveToLibrary: widget.onSaveToLibrary,
    onFavoriteToggle: widget.onFavoriteToggle,
    onCompletionPlaceholderSettled: widget.onCompletionPlaceholderSettled,
  );

  @override
  void initState() {
    super.initState();
    _controller = ImageCardController(
      vsync: this,
      data: _data,
      capabilities: _capabilities,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.scheduleCompletedImagePrecache(context);
  }

  @override
  void didUpdateWidget(covariant SelectableImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.update(
      vsync: this,
      data: _data,
      capabilities: _capabilities,
      context: context,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data.isGenerating) {
      return ImageCardGenerating(data: data, controller: _controller);
    }
    final capabilities = _capabilities;
    final coordinator = ImageCardActionCoordinator(
      context: context,
      ref: ref,
      controller: _controller,
    );
    final actions =
        capabilities.hoverEffectsEnabled || capabilities.enableContextMenu
        ? ImageCardActionCatalog.build(
            context: context,
            data: data,
            capabilities: capabilities,
            coordinator: coordinator,
          )
        : const <ImageCardAction>[];
    return ImageCardSurface(
      data: data,
      capabilities: capabilities,
      controller: _controller,
      actions: actions,
      onWarmShareCache: coordinator.warmShareTransferCache,
      onShowContextMenu: (position) => ImageCardContextMenu.show(
        context: context,
        position: position,
        actions: actions,
      ),
    );
  }
}
