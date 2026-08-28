import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../data/models/image/image_stream_chunk.dart';

@immutable
class ImageCardViewData {
  const ImageCardViewData({
    required this.imageBytes,
    required this.index,
    required this.isSelected,
    required this.showIndex,
    required this.isPreviewActive,
    required this.imageIdentity,
    required this.statusBadgeLabel,
    required this.statusBadgeTooltip,
    required this.dragPreparationReady,
    required this.completionPlaceholderBytes,
    required this.isFavorite,
    required this.underlay,
    required this.isGenerating,
    required this.progress,
    required this.currentImage,
    required this.totalImages,
    required this.streamPreview,
    required this.focusedPreviewPlacement,
    required this.imageWidth,
    required this.imageHeight,
    required this.sourceFilePath,
  });

  final Uint8List? imageBytes;
  final int? index;
  final bool isSelected;
  final bool showIndex;
  final bool isPreviewActive;
  final Object? imageIdentity;
  final String? statusBadgeLabel;
  final String? statusBadgeTooltip;
  final bool dragPreparationReady;
  final Uint8List? completionPlaceholderBytes;
  final bool isFavorite;
  final Widget? underlay;
  final bool isGenerating;
  final double? progress;
  final int? currentImage;
  final int? totalImages;
  final Uint8List? streamPreview;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;
  final int? imageWidth;
  final int? imageHeight;
  final String? sourceFilePath;
}

@immutable
class ImageCardCapabilities {
  const ImageCardCapabilities({
    required this.allowRepeatedModifierTaps,
    required this.enableContextMenu,
    required this.enableHoverScale,
    required this.enableGlossEffect,
    required this.hoverEffectsEnabled,
    required this.shareWarmupEnabled,
    required this.enableSaveAction,
    required this.enableCopyAction,
    required this.enableSelection,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.onFullscreen,
    required this.onUpscale,
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
    required this.onSendToKrita,
    required this.onShareToDiscord,
    required this.onOpenInExplorer,
    required this.onSaveToLibrary,
    required this.onFavoriteToggle,
    required this.onCompletionPlaceholderSettled,
  });

  final bool allowRepeatedModifierTaps;
  final bool enableContextMenu;
  final bool enableHoverScale;
  final bool enableGlossEffect;
  final bool hoverEffectsEnabled;
  final bool shareWarmupEnabled;
  final bool enableSaveAction;
  final bool enableCopyAction;
  final bool enableSelection;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onFullscreen;
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
  final void Function(Uint8List imageBytes, String prompt)? onSaveToLibrary;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCompletionPlaceholderSettled;
}
