/// Small, pre-aggregated payload used by the statistics dashboard.
///
/// Keeping this model count-only prevents dashboard queries from materializing
/// image prompts and other large metadata fields.
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
  }) : resolutionCounts = Map.unmodifiable(resolutionCounts),
       modelCounts = Map.unmodifiable(modelCounts),
       samplerCounts = Map.unmodifiable(samplerCounts),
       sizeCounts = Map.unmodifiable(sizeCounts),
       tagCounts = Map.unmodifiable(tagCounts),
       dailyCounts = Map.unmodifiable(dailyCounts),
       hourlyCounts = Map.unmodifiable(hourlyCounts),
       weekdayCounts = Map.unmodifiable(weekdayCounts);
}
