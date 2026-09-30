import 'gallery_parameter.dart';

/// Small, pre-aggregated payload used by the statistics dashboard.
///
/// Counts and the recent-image rows carry only light columns, so dashboard
/// queries never materialize image prompts or other large metadata fields.
class GalleryDashboardSnapshot {
  final int totalImages;
  final int totalSizeBytes;
  final int favoriteCount;
  final int taggedImageCount;
  final int imagesWithMetadata;
  final Map<String, int> resolutionCounts;
  final Map<String, int> modelCounts;
  final Map<String, int> samplerCounts;
  final Map<String, int> sizeCounts;
  final Map<String, int> tagCounts;
  final Map<int, int> dailyCounts;
  final Map<int, int> hourlyCounts;
  final Map<int, int> weekdayCounts;
  final Map<GalleryParameter, Map<String, int>> parameterCounts;
  final List<GalleryRecentImage> recentImages;

  GalleryDashboardSnapshot({
    required this.totalImages,
    required this.totalSizeBytes,
    required this.favoriteCount,
    required this.taggedImageCount,
    required this.imagesWithMetadata,
    required Map<String, int> resolutionCounts,
    required Map<String, int> modelCounts,
    required Map<String, int> samplerCounts,
    required Map<String, int> sizeCounts,
    required Map<String, int> tagCounts,
    required Map<int, int> dailyCounts,
    required Map<int, int> hourlyCounts,
    required Map<int, int> weekdayCounts,
    Map<GalleryParameter, Map<String, int>> parameterCounts = const {},
    List<GalleryRecentImage> recentImages = const [],
  }) : resolutionCounts = Map.unmodifiable(resolutionCounts),
       modelCounts = Map.unmodifiable(modelCounts),
       samplerCounts = Map.unmodifiable(samplerCounts),
       sizeCounts = Map.unmodifiable(sizeCounts),
       tagCounts = Map.unmodifiable(tagCounts),
       dailyCounts = Map.unmodifiable(dailyCounts),
       hourlyCounts = Map.unmodifiable(hourlyCounts),
       weekdayCounts = Map.unmodifiable(weekdayCounts),
       parameterCounts = Map.unmodifiable({
         for (final entry in parameterCounts.entries)
           entry.key: Map<String, int>.unmodifiable(entry.value),
       }),
       recentImages = List.unmodifiable(recentImages);
}

/// One image in recent activity, limited to light columns (no prompts).
class GalleryRecentImage {
  const GalleryRecentImage({
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.isFavorite,
    required this.tags,
    required this.hasMetadata,
    this.width,
    this.height,
    this.model,
    this.sampler,
    this.steps,
    this.scale,
  });

  final String path;
  final int size;
  final DateTime modifiedAt;
  final bool isFavorite;
  final List<String> tags;
  final bool hasMetadata;
  final int? width;
  final int? height;
  final String? model;
  final String? sampler;
  final int? steps;
  final double? scale;
}
