import 'dart:math';

import '../../models/online_gallery/chunked_gallery_items.dart';
import '../../models/online_gallery/gallery_item.dart';

class OnlineGalleryFavoritesService {
  const OnlineGalleryFavoritesService();

  ChunkedGalleryItems removeBranch(
    ChunkedGalleryItems posts, {
    required Set<String> branchKeys,
    required Set<String> retainedByOtherBranch,
  }) {
    if (branchKeys.isEmpty) return posts;
    final keysToRemove = branchKeys.difference(retainedByOtherBranch);
    return keysToRemove.isEmpty ? posts : posts.removeStableKeys(keysToRemove);
  }

  GalleryItem mergeItem(GalleryItem current, GalleryItem incoming) {
    final incomingIsRicher = _completeness(incoming) >= _completeness(current);
    final primary = incomingIsRicher ? incoming : current;
    final secondary = incomingIsRicher ? current : incoming;
    String fill(String value, String fallback) =>
        value.isNotEmpty ? value : fallback;
    String? fillNullable(String? value, String? fallback) =>
        value?.isNotEmpty == true ? value : fallback;
    final primaryCover = primary.cover;
    final secondaryCover = secondary.cover;
    return primary.copyWith(
      title: fillNullable(primary.title, secondary.title),
      author: fillNullable(primary.author, secondary.author),
      description: fillNullable(primary.description, secondary.description),
      aiType: fillNullable(primary.aiType, secondary.aiType),
      createdAt: fill(primary.createdAt, secondary.createdAt),
      uploaderId: primary.uploaderId != 0
          ? primary.uploaderId
          : secondary.uploaderId,
      score: primary.score ?? secondary.score,
      source: fill(primary.source, secondary.source),
      md5: fill(primary.md5, secondary.md5),
      rating: fillNullable(primary.rating, secondary.rating),
      imageWidth: primary.imageWidth > 0
          ? primary.imageWidth
          : secondary.imageWidth,
      imageHeight: primary.imageHeight > 0
          ? primary.imageHeight
          : secondary.imageHeight,
      tagString: fill(primary.tagString, secondary.tagString),
      tags: {...primary.tags, ...secondary.tags}.toList(growable: false),
      tagStringGeneral: fill(
        primary.tagStringGeneral,
        secondary.tagStringGeneral,
      ),
      tagStringCharacter: fill(
        primary.tagStringCharacter,
        secondary.tagStringCharacter,
      ),
      tagStringCopyright: fill(
        primary.tagStringCopyright,
        secondary.tagStringCopyright,
      ),
      tagStringArtist: fill(primary.tagStringArtist, secondary.tagStringArtist),
      tagStringMeta: fill(primary.tagStringMeta, secondary.tagStringMeta),
      fileExt: fillNullable(primary.fileExt, secondary.fileExt),
      fileSize: primary.fileSize ?? secondary.fileSize,
      fileUrl: fillNullable(primary.fileUrl, secondary.fileUrl),
      largeFileUrl: fillNullable(primary.largeFileUrl, secondary.largeFileUrl),
      previewFileUrl: fillNullable(
        primary.previewFileUrl,
        secondary.previewFileUrl,
      ),
      sampleUrl: fillNullable(primary.sampleUrl, secondary.sampleUrl),
      sampleWidth: primary.sampleWidth ?? secondary.sampleWidth,
      sampleHeight: primary.sampleHeight ?? secondary.sampleHeight,
      cover: GalleryMedia(
        id: fill(primaryCover.id, secondaryCover.id),
        previewUrl: fill(primaryCover.previewUrl, secondaryCover.previewUrl),
        displayUrl: fill(primaryCover.displayUrl, secondaryCover.displayUrl),
        downloadUrl: fill(primaryCover.downloadUrl, secondaryCover.downloadUrl),
        width: primaryCover.width > 0
            ? primaryCover.width
            : secondaryCover.width,
        height: primaryCover.height > 0
            ? primaryCover.height
            : secondaryCover.height,
        extension: fillNullable(
          primaryCover.extension,
          secondaryCover.extension,
        ),
        mimeType: fillNullable(primaryCover.mimeType, secondaryCover.mimeType),
        rawMetadata: fillNullable(
          primaryCover.rawMetadata,
          secondaryCover.rawMetadata,
        ),
        mediaType: fill(primaryCover.mediaType, secondaryCover.mediaType),
        prompt: fillNullable(primaryCover.prompt, secondaryCover.prompt),
        negativePrompt: fillNullable(
          primaryCover.negativePrompt,
          secondaryCover.negativePrompt,
        ),
        metadataFormat: fillNullable(
          primaryCover.metadataFormat,
          secondaryCover.metadataFormat,
        ),
        metadataError: fillNullable(
          primaryCover.metadataError,
          secondaryCover.metadataError,
        ),
        metadata: {...secondaryCover.metadata, ...primaryCover.metadata},
      ),
      mediaCount: max(primary.mediaCount, secondary.mediaCount),
      viewCount: primary.viewCount ?? secondary.viewCount,
      favoriteCount: primary.favoriteCount ?? secondary.favoriteCount,
      rank: primary.rank ?? secondary.rank,
      rankingName: fillNullable(primary.rankingName, secondary.rankingName),
      focusedMediaId: fillNullable(
        primary.focusedMediaId,
        secondary.focusedMediaId,
      ),
      focusedMediaIndex:
          primary.focusedMediaIndex ?? secondary.focusedMediaIndex,
      artistChain: primary.artistChain ?? secondary.artistChain,
      rawSourceMetadata: {
        ...secondary.rawSourceMetadata,
        ...primary.rawSourceMetadata,
      },
    );
  }

  int _completeness(GalleryItem item) {
    int textScore(String? value) {
      final length = value?.trim().length ?? 0;
      return length == 0 ? 0 : 1 + min(4, length ~/ 40);
    }

    final cover = item.cover;
    return (textScore(item.title) +
            textScore(item.author) +
            textScore(item.description) +
            textScore(item.tagString) +
            textScore(item.tagStringGeneral) +
            textScore(item.tagStringCharacter) +
            textScore(item.tagStringCopyright) +
            textScore(item.tagStringArtist) +
            textScore(item.tagStringMeta) +
            min(20, item.tags.length) +
            (item.imageWidth > 0 && item.imageHeight > 0 ? 3 : 0) +
            (item.fileUrl?.isNotEmpty == true ? 3 : 0) +
            (item.largeFileUrl?.isNotEmpty == true ? 2 : 0) +
            (item.previewFileUrl?.isNotEmpty == true ? 2 : 0) +
            (cover.displayUrl.isNotEmpty ? 2 : 0) +
            (cover.downloadUrl.isNotEmpty ? 2 : 0) +
            min(10, item.rawSourceMetadata.length) +
            min(10, cover.metadata.length))
        .toInt();
  }
}
