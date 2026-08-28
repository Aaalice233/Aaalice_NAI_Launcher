import '../../models/online_gallery/gallery_item.dart';
import '../../models/online_gallery/gallery_source.dart';

class OnlineGalleryQuery {
  const OnlineGalleryQuery();

  String buildSearchQuery(String query, {required bool fuzzyMatch}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';
    final tags = trimmed
        .split(RegExp(r'[,，\s]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty);
    return tags
        .map((tag) => !fuzzyMatch || isSpecialTag(tag) ? tag : '*$tag*')
        .join(' ');
  }

  bool isSpecialTag(String tag) =>
      tag.contains('*') || tag.contains(':') || tag.startsWith('-');

  String? normalizePolicyTag(String value) {
    var normalized = value.trim().toLowerCase();
    while (normalized.startsWith('-')) {
      normalized = normalized.substring(1).trimLeft();
    }
    normalized = normalized.replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? null : normalized;
  }

  String rawPageIdentity(List<GalleryItem> items) {
    final keys = items.map((item) => item.stableKey).toSet().toList()..sort();
    return keys.join('\u0000');
  }

  bool matchesFavoriteSearch(GalleryItem item, String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) return true;
    final haystack = [
      item.title,
      item.author,
      item.description,
      item.tagString,
      item.tagStringGeneral,
      item.tagStringCharacter,
      item.tagStringCopyright,
      item.tagStringArtist,
      item.tagStringMeta,
    ].whereType<String>().join(' ').toLowerCase().replaceAll('_', ' ');
    return terms.every(haystack.contains);
  }

  List<GalleryItem> filterLocal({
    required Iterable<GalleryItem> items,
    required Set<String> ratings,
    required Set<String> blacklist,
  }) {
    final normalizedBlacklist = blacklist
        .map(normalizePolicyTag)
        .whereType<String>()
        .toSet();
    return items
        .where((item) {
          final supportsRatings =
              gallerySourceCapabilities[item.sourceId]!.supportsRatings;
          if (supportsRatings &&
              ratings.length != 4 &&
              !ratings.contains(item.rating)) {
            return false;
          }
          return !item.tags.any(
            (tag) => normalizedBlacklist.contains(normalizePolicyTag(tag)),
          );
        })
        .toList(growable: false);
  }
}
