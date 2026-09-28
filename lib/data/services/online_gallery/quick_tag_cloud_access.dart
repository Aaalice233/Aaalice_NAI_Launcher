import '../../models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../models/online_gallery/quick_tag_cloud_codex.dart';

/// Upstream content indicators with a conservative NSFW category-path check.
class QuickTagCloudAccess {
  const QuickTagCloudAccess._();

  static const Set<String> galleryRatings = {'g', 'q', 'e'};
  static const Set<String> _nsfwRatings = {'restricted', 'r18', 'r18g', 'nsfw'};

  static bool allowsNsfw(Set<String> ratings) =>
      ratings.contains('q') || ratings.contains('e');

  static bool allowsR18g(Set<String> ratings) => ratings.contains('e');

  static bool isNsfwCodex(Object? codex) => switch (codex) {
    QuickTagCloudCodexMeta(:final nsfw) => nsfw,
    QuickTagCloudCodex(:final nsfw) => nsfw,
    _ => false,
  };

  static bool isLoadedCodexNsfw(QuickTagCloudCodex codex) => isNsfwCodex(codex);

  static String entryRating(QuickTagCloudEntry entry) =>
      entry.rating.toLowerCase();

  static bool isNsfwRating(String? rating) =>
      _nsfwRatings.contains((rating ?? '').toLowerCase());

  static bool isNsfwPathSegment(String? name) =>
      (name ?? '').toLowerCase() == 'nsfw';

  static bool isEntryNsfw(QuickTagCloudEntry entry) =>
      isNsfwRating(entryRating(entry)) || entry.path.any(isNsfwPathSegment);

  static bool isCodexLocked(Object? codex, {required bool allowNsfw}) =>
      isNsfwCodex(codex) && !allowNsfw;

  static bool isR18gName(String? name) {
    final value = (name ?? '').toLowerCase();
    return value.contains('r18g') || value.contains('重口');
  }

  static bool isR18gEntry(QuickTagCloudEntry entry) =>
      entryRating(entry) == 'r18g' || entry.path.any(isR18gName);

  static bool isR18gPath(List<String>? path) =>
      path != null && path.any(isR18gName);

  static String galleryRating(QuickTagCloudEntry entry, {Object? codex}) {
    if (isR18gEntry(entry)) return 'e';
    if (isNsfwCodex(codex) || isEntryNsfw(entry)) return 'q';
    return 'g';
  }

  static bool matchesGalleryRatings(
    QuickTagCloudEntry entry, {
    required Object? codex,
    required Set<String> selectedRatings,
  }) {
    final rating = galleryRating(entry, codex: codex);
    if (rating == 'g') {
      // Upstream does not distinguish general from sensitive content.
      return selectedRatings.contains('g') || selectedRatings.contains('s');
    }
    return selectedRatings.contains(rating);
  }

  static bool isR18gBlocked(
    QuickTagCloudEntry entry, {
    required bool allowR18g,
  }) => isR18gEntry(entry) && !allowR18g;

  static bool isEntryAccessBlocked(
    QuickTagCloudEntry entry, {
    required bool allowNsfw,
    required bool allowR18g,
  }) {
    if (isR18gBlocked(entry, allowR18g: allowR18g)) return true;
    return isEntryNsfw(entry) && !allowNsfw;
  }
}
