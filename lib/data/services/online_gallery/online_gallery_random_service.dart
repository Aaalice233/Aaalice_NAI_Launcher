import '../../datasources/remote/danbooru_api_service.dart';
import '../../models/online_gallery/gallery_item.dart';
import '../../models/online_gallery/gallery_source.dart';

class OnlineGalleryRandomSelection {
  const OnlineGalleryRandomSelection({
    required this.items,
    required this.seenStableKeys,
  });

  final List<GalleryItem> items;
  final Set<String> seenStableKeys;
}

class OnlineGalleryRandomService {
  const OnlineGalleryRandomService({this.seenLimit = 20000});

  final int seenLimit;

  GalleryRankingKind rankingKind(PopularScale scale) => switch (scale) {
    PopularScale.day => GalleryRankingKind.day,
    PopularScale.week => GalleryRankingKind.week,
    PopularScale.month => GalleryRankingKind.month,
  };

  bool isExhausted(Set<String> seenStableKeys) =>
      seenStableKeys.length >= seenLimit;

  List<GalleryItem> unseenCandidates({
    required Iterable<GalleryItem> items,
    required bool artistHuntActive,
    required Set<String> seenStableKeys,
    required Set<String> seenCandidateStableKeys,
  }) {
    final result = <GalleryItem>[];
    for (final item in items) {
      final identity = artistHuntActive ? item.detailStableKey : item.stableKey;
      final alreadySeen = artistHuntActive
          ? seenCandidateStableKeys.contains(identity)
          : seenStableKeys.contains(identity);
      if (!alreadySeen && seenStableKeys.length < seenLimit) result.add(item);
    }
    return List.unmodifiable(result);
  }

  OnlineGalleryRandomSelection accept({
    required Iterable<GalleryItem> candidates,
    required Set<String> seenStableKeys,
  }) {
    final seen = Set<String>.of(seenStableKeys);
    final accepted = <GalleryItem>[];
    for (final item in candidates) {
      if (seen.length >= seenLimit || !seen.add(item.stableKey)) continue;
      accepted.add(item);
    }
    return OnlineGalleryRandomSelection(
      items: List.unmodifiable(accepted),
      seenStableKeys: Set.unmodifiable(seen),
    );
  }
}
