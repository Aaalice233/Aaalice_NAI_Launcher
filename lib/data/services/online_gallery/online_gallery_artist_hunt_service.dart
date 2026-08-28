import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../models/online_gallery/gallery_item.dart';
import 'artist_chain_parser.dart';

class OnlineGalleryArtistHuntDetailException implements Exception {
  const OnlineGalleryArtistHuntDetailException(this.failureCount);

  final int failureCount;

  @override
  String toString() => 'Failed to resolve $failureCount AI TAG works';
}

class OnlineGalleryArtistHuntResult {
  const OnlineGalleryArtistHuntResult({
    required this.items,
    required this.successfulCandidateKeys,
    required this.resolvedCount,
    required this.failureCount,
  });

  final List<GalleryItem> items;
  final Set<String> successfulCandidateKeys;
  final int resolvedCount;
  final int failureCount;
}

class OnlineGalleryArtistHuntService {
  const OnlineGalleryArtistHuntService();

  Set<String> deduplicationKeys(Iterable<GalleryItem> items) {
    final keys = <String>{};
    for (final item in items) {
      final extraction = item.artistChain;
      final prompt = item.cover.prompt;
      if (extraction == null || extraction.isEmpty || prompt == null) continue;
      keys.add(ArtistChainParser.deduplicationKey(prompt, extraction));
    }
    return keys;
  }

  Future<OnlineGalleryArtistHuntResult?> resolve({
    required List<GalleryItem> candidates,
    required OnlineGalleryDetailCoordinator details,
    required Set<String> deduplicationKeys,
    required bool Function() isCurrent,
    void Function(List<GalleryItem> items, int resolvedDelta, int failureDelta)?
    onProgress,
  }) async {
    final pending = candidates
        .map((candidate) async {
          try {
            return await details.request(
              candidate,
              priority: GalleryDetailPriority.visible,
            );
          } catch (_) {
            return null;
          }
        })
        .toList(growable: false);

    final allItems = <GalleryItem>[];
    final successfulKeys = <String>{};
    final progressItems = <GalleryItem>[];
    var resolvedCount = 0;
    var failureCount = 0;
    var pendingResolved = 0;
    var pendingFailures = 0;

    for (
      var candidateIndex = 0;
      candidateIndex < candidates.length;
      candidateIndex++
    ) {
      final detail = await pending[candidateIndex];
      if (!isCurrent()) return null;

      if (detail == null) {
        failureCount++;
        pendingFailures++;
      } else {
        resolvedCount++;
        pendingResolved++;
        final candidate = candidates[candidateIndex];
        successfulKeys.add(candidate.detailStableKey);
        for (
          var mediaIndex = 0;
          mediaIndex < detail.media.length;
          mediaIndex++
        ) {
          final focusedMedia = detail.media[mediaIndex];
          final prompt = focusedMedia.prompt;
          final extraction = ArtistChainParser.parse(prompt);
          if (extraction.isEmpty || prompt == null) continue;
          final deduplicationKey = ArtistChainParser.deduplicationKey(
            prompt,
            extraction,
          );
          if (!deduplicationKeys.add(deduplicationKey)) continue;
          final focusedItem = candidate.copyWith(
            cover: focusedMedia,
            focusedMediaId: focusedMedia.id,
            focusedMediaIndex: mediaIndex,
            artistChain: extraction,
          );
          allItems.add(focusedItem);
          progressItems.add(focusedItem);
          break;
        }
      }

      final flush =
          pendingResolved + pendingFailures >= 4 ||
          candidateIndex == candidates.length - 1;
      if (flush && onProgress != null) {
        onProgress(
          List.unmodifiable(progressItems),
          pendingResolved,
          pendingFailures,
        );
        progressItems.clear();
        pendingResolved = 0;
        pendingFailures = 0;
      }
    }

    return OnlineGalleryArtistHuntResult(
      items: List.unmodifiable(allItems),
      successfulCandidateKeys: Set.unmodifiable(successfulKeys),
      resolvedCount: resolvedCount,
      failureCount: failureCount,
    );
  }
}
