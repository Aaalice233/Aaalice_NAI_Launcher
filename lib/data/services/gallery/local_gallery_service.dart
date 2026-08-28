import 'dart:io';

import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'gallery_filter_service.dart';

abstract class LocalGalleryService {
  bool get isInitialized;
  Future<List<File>> initialize();
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize});
  Future<void> applyFilter(FilterCriteria criteria);
  Future<bool> toggleFavorite(String filePath);
  Future<bool> isFavorite(String filePath);
  Future<int> getFavoriteCount();
  Future<NaiImageMetadata?> getMetadata(String filePath);
  Future<void> refresh({bool scan = true});
  Future<bool> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  });
  int get filteredCount;
  int get totalCount;
  FilterCriteria get currentFilter;
  Future<void> setSearchQuery(String query);
  Future<void> setDateRange(DateTime? start, DateTime? end);
  Future<void> setShowFavoritesOnly(bool value);
  Future<void> setPageSize(int size);
  Future<void> clearFilters();
  Future<void> dispose();
  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths);
  Future<List<String>> getFilteredImagePaths();
}
