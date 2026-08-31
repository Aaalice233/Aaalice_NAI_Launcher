import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import '../../../data/models/online_gallery/gallery_item.dart';

/// All user-facing copy used by GalleryDetailDialog.
@immutable
class GalleryDetailDialogLabels {
  const GalleryDetailDialogLabels({
    required this.sourceName,
    required this.untitled,
    required this.codex,
    required this.category,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.characterPrompts,
    required this.note,
    required this.rawTags,
    required this.artists,
    required this.characters,
    required this.copyrights,
    required this.general,
    required this.metadata,
    required this.tagContextMenuTooltip,
    required this.outputFilteredTagTooltip,
    required this.author,
    required this.imageFile,
    required this.originalFile,
    required this.declaredSource,
    required this.contributors,
    required this.noImage,
    required this.noImageDescription,
    required this.imageLoadFailed,
    required this.retry,
    required this.zoomHint,
    required this.copyPrompt,
    required this.addFavorite,
    required this.removeFavorite,
    required this.openSource,
    required this.sendToGenerate,
    required this.addToQueue,
    required this.downloadOriginal,
    required this.previousImage,
    required this.nextImage,
    required this.close,
    required this.emptyValue,
    required this.imageCounter,
    required this.multipleImages,
    required this.views,
    required this.favoriteCount,
    required this.rating,
    required this.score,
    required this.downloadAll,
    required this.sendToReverse,
  });

  final String sourceName;
  final String untitled;
  final String codex;
  final String category;
  final String positivePrompt;
  final String negativePrompt;
  final String characterPrompts;
  final String note;
  final String rawTags;
  final String artists;
  final String characters;
  final String copyrights;
  final String general;
  final String metadata;
  final String tagContextMenuTooltip;
  final String outputFilteredTagTooltip;
  final String author;
  final String imageFile;
  final String originalFile;
  final String declaredSource;
  final String contributors;
  final String noImage;
  final String noImageDescription;
  final String imageLoadFailed;
  final String retry;
  final String zoomHint;
  final String copyPrompt;
  final String addFavorite;
  final String removeFavorite;
  final String openSource;
  final String sendToGenerate;
  final String addToQueue;
  final String downloadOriginal;
  final String previousImage;
  final String nextImage;
  final String close;
  final String emptyValue;
  final String Function(int current, int total) imageCounter;
  final String Function(int count) multipleImages;
  final String views;
  final String favoriteCount;
  final String rating;
  final String score;
  final String downloadAll;
  final String sendToReverse;
}

@immutable
class GalleryDetailViewModel {
  const GalleryDetailViewModel({
    required this.item,
    required this.detail,
    required this.labels,
    required this.mediaIndex,
    required this.imageRevision,
    required this.isFavorited,
    required this.favoriteLoading,
    required this.favoriteActionPending,
    required this.canUseGenerationActions,
    required this.queueActionPending,
    required this.downloadActionPending,
    required this.reverseActionPending,
    required this.canToggleFavorite,
    required this.isOutputFiltered,
  });

  final GalleryItem item;
  final GalleryDetail detail;
  final GalleryDetailDialogLabels labels;
  final int mediaIndex;
  final int imageRevision;
  final bool isFavorited;
  final bool favoriteLoading;
  final bool favoriteActionPending;
  final bool canUseGenerationActions;
  final bool queueActionPending;
  final bool downloadActionPending;
  final bool reverseActionPending;
  final bool canToggleFavorite;
  final bool Function(String tag) isOutputFiltered;

  List<GalleryMedia> get media => detail.media;
  GalleryMedia? get currentMedia =>
      media.isEmpty ? null : media[mediaIndex.clamp(0, media.length - 1)];
  bool get hasPrompt => detail.prompt?.trim().isNotEmpty == true;
  bool get hasNegativePrompt =>
      detail.negativePrompt?.trim().isNotEmpty == true;
  List<GalleryCharacterPrompt> get displayCharacterPrompts => detail
      .characterPrompts
      .where(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      )
      .toList(growable: false);
  bool get hasCopyableContent =>
      hasPrompt || hasNegativePrompt || displayCharacterPrompts.isNotEmpty;
  List<String> get currentRawTags {
    final mediaRawTags = currentMedia?.rawMetadata?.trim() ?? '';
    return mediaRawTags.isEmpty ? detail.rawTags : [mediaRawTags];
  }

  bool get hasSourceUrl =>
      detail.sourceUrl?.trim().isNotEmpty == true ||
      item.postUrl.trim().isNotEmpty;
}

@immutable
class GalleryDetailActions {
  const GalleryDetailActions({
    required this.close,
    required this.moveToMedia,
    required this.mediaPageChanged,
    required this.retryMedia,
    required this.toggleFavorite,
    required this.openSource,
    required this.copyPrompt,
    required this.sendToGenerate,
    required this.addToQueue,
    required this.downloadCurrentOriginal,
    required this.searchTag,
    required this.showTagMenu,
    this.downloadAll,
    this.sendToReverse,
  });

  final VoidCallback close;
  final ValueChanged<int> moveToMedia;
  final ValueChanged<int> mediaPageChanged;
  final Future<void> Function(GalleryMedia media) retryMedia;
  final Future<void> Function() toggleFavorite;
  final VoidCallback openSource;
  final void Function(GalleryMedia? media) copyPrompt;
  final void Function(GalleryMedia? media) sendToGenerate;
  final Future<void> Function(GalleryMedia? media) addToQueue;
  final Future<void> Function(GalleryMedia media) downloadCurrentOriginal;
  final ValueChanged<String> searchTag;
  final void Function(String tag, TapDownDetails details) showTagMenu;
  final Future<void> Function(List<GalleryMedia> media)? downloadAll;
  final Future<void> Function(GalleryMedia media)? sendToReverse;
}

bool galleryMediaHasOriginal(GalleryMedia media) {
  final value = media.metadata['hasOriginal'];
  if (value is bool) return value;
  return media.downloadUrl.isNotEmpty;
}

String galleryMediaDisplayUrl(GalleryMedia media) {
  final capability = media.capability;
  return capability.isVideo ? capability.videoUrl : capability.imageDisplayUrl;
}

String galleryMediaPreviewUrl(GalleryMedia media) =>
    media.capability.canPrefetchPreview ? media.capability.previewUrl : '';

String galleryMediaDownloadUrl(GalleryMedia media) =>
    media.capability.downloadUrl.isNotEmpty
    ? media.capability.downloadUrl
    : media.capability.displayUrl;
