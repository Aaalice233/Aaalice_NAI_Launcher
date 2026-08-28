import 'dart:math';

import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/online_gallery/gallery_item.dart';
import 'online_gallery_query.dart';

class OnlineGalleryBlacklistFilterService {
  const OnlineGalleryBlacklistFilterService(this._query);

  final OnlineGalleryQuery _query;

  Future<({List<GalleryItem> items, int detailFailures})> filter({
    required List<GalleryItem> items,
    required Set<String> blacklist,
    required OnlineGalleryDetailCoordinator details,
  }) async {
    if (blacklist.isEmpty) return (items: items, detailFailures: 0);
    final normalizedBlacklist = blacklist
        .map(_query.normalizePolicyTag)
        .whereType<String>()
        .toSet();
    final allowed = <String, bool>{};
    final incomplete = <GalleryItem>[];
    var detailFailures = 0;
    for (final item in items) {
      if (!item.tagsComplete) {
        incomplete.add(item);
      } else {
        allowed[item.stableKey] = !item.tags.any(
          (tag) => normalizedBlacklist.contains(_query.normalizePolicyTag(tag)),
        );
      }
    }
    const batchSize = 6;
    for (var offset = 0; offset < incomplete.length; offset += batchSize) {
      final batch = incomplete.sublist(
        offset,
        min(offset + batchSize, incomplete.length),
      );
      final resolved = await Future.wait(
        batch.map((item) async {
          try {
            return await details.request(
              item,
              priority: GalleryDetailPriority.visible,
            );
          } catch (error) {
            AppLogger.w(
              'Failed to complete gallery tags for blacklist filtering: '
                  '${item.stableKey}: $error',
              'OnlineGallery',
            );
            return null;
          }
        }),
      );
      for (var index = 0; index < resolved.length; index++) {
        final detail = resolved[index];
        if (detail == null || !detail.item.tagsComplete) {
          detailFailures++;
          allowed[batch[index].stableKey] = false;
          continue;
        }
        final policyTags = <String>{
          ...detail.item.tags,
          ...detail.rawTags,
          for (final prompt in <String?>[
            detail.prompt,
            ...detail.media.map((media) => media.prompt),
          ])
            if (prompt != null)
              ...prompt
                  .split(RegExp(r'[,，\n]+'))
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty),
        };
        allowed[batch[index].stableKey] = !policyTags.any(
          (tag) => normalizedBlacklist.contains(_query.normalizePolicyTag(tag)),
        );
      }
    }
    return (
      items: items
          .where((item) => allowed[item.stableKey] ?? false)
          .toList(growable: false),
      detailFailures: detailFailures,
    );
  }
}
