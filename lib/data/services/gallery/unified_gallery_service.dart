import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/database/database.dart';
import '../../../core/exceptions/gallery_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'gallery_filter_service.dart';
import 'local_gallery_service.dart';
import 'local_gallery_service_impl.dart';

export 'gallery_path_utils.dart';
export 'gallery_scan_coordinator.dart'
    show
        GalleryStartupIndexAction,
        chooseStartupIndexAction,
        shouldRunRefreshIndexScan;
export 'local_gallery_query.dart' show isFavoriteOnlyFastFilter;
export 'local_gallery_service.dart';
export 'local_gallery_service_impl.dart';

part 'unified_gallery_service.g.dart';

@Riverpod(keepAlive: true)
class GalleryService extends _$GalleryService {
  LocalGalleryService? _service;

  @override
  LocalGalleryService build() {
    _initializeService();
    ref.onDispose(() {
      _service?.dispose();
      _service = null;
    });
    return _PlaceholderGalleryService();
  }

  Future<void> _initializeService() async {
    try {
      final dataSource = DatabaseManager.instance
          .getDataSource<GalleryDataSource>('gallery');
      if (dataSource == null) {
        throw const GalleryDatabaseException(
          message: 'GalleryDataSource not available',
        );
      }

      _service = LocalGalleryServiceImpl(
        dataSource: dataSource,
        filterService: GalleryFilterService(dataSource),
      );
      await _service!.initialize();
      state = _service!;
    } on GalleryPermissionDeniedException catch (error) {
      AppLogger.e('Gallery permission denied', error, null, 'GalleryService');
      state = ErrorGalleryService(error: '无法访问图片文件夹: ${error.message}');
    } on GalleryScanException catch (error) {
      AppLogger.e('Gallery scan failed', error, null, 'GalleryService');
      state = ErrorGalleryService(error: '扫描图片失败: ${error.message}');
    } catch (error) {
      AppLogger.e(
        'Failed to initialize gallery service',
        error,
        null,
        'GalleryService',
      );
      state = ErrorGalleryService(error: '画廊初始化失败: $error');
    }
  }

  Future<void> reinitialize() async {
    await _service?.dispose();
    _service = null;
    await _initializeService();
  }
}

class ErrorGalleryService implements LocalGalleryService {
  const ErrorGalleryService({required this.error});

  final String error;

  @override
  bool get isInitialized => false;
  @override
  int get filteredCount => 0;
  @override
  int get totalCount => 0;
  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  Never _throwError() => throw GalleryDatabaseException(message: error);

  @override
  Future<List<File>> initialize() => _throwError();
  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) =>
      _throwError();
  @override
  Future<void> applyFilter(FilterCriteria criteria) => _throwError();
  @override
  Future<bool> toggleFavorite(String filePath) => _throwError();
  @override
  Future<bool> isFavorite(String filePath) => _throwError();
  @override
  Future<int> getFavoriteCount() => _throwError();
  @override
  Future<NaiImageMetadata?> getMetadata(String filePath) => _throwError();
  @override
  Future<void> refresh({bool scan = true}) => _throwError();
  @override
  Future<bool> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) => _throwError();
  @override
  Future<void> setSearchQuery(String query) => _throwError();
  @override
  Future<void> setDateRange(DateTime? start, DateTime? end) => _throwError();
  @override
  Future<void> setShowFavoritesOnly(bool value) => _throwError();
  @override
  Future<void> setPageSize(int size) => _throwError();
  @override
  Future<void> clearFilters() => _throwError();
  @override
  Future<void> dispose() async {}
  @override
  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths) =>
      _throwError();
  @override
  Future<List<String>> getFilteredImagePaths() => _throwError();
}

class _PlaceholderGalleryService implements LocalGalleryService {
  @override
  bool get isInitialized => false;
  @override
  int get filteredCount => 0;
  @override
  int get totalCount => 0;
  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  Never _throwNotInitialized() => throw const GalleryNotInitializedException(
    message: 'Gallery service is initializing, please wait...',
  );

  @override
  Future<List<File>> initialize() => _throwNotInitialized();
  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) =>
      _throwNotInitialized();
  @override
  Future<void> applyFilter(FilterCriteria criteria) => _throwNotInitialized();
  @override
  Future<bool> toggleFavorite(String filePath) => _throwNotInitialized();
  @override
  Future<bool> isFavorite(String filePath) => _throwNotInitialized();
  @override
  Future<int> getFavoriteCount() => _throwNotInitialized();
  @override
  Future<NaiImageMetadata?> getMetadata(String filePath) =>
      _throwNotInitialized();
  @override
  Future<void> refresh({bool scan = true}) => _throwNotInitialized();
  @override
  Future<bool> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) => _throwNotInitialized();
  @override
  Future<void> setSearchQuery(String query) => _throwNotInitialized();
  @override
  Future<void> setDateRange(DateTime? start, DateTime? end) =>
      _throwNotInitialized();
  @override
  Future<void> setShowFavoritesOnly(bool value) => _throwNotInitialized();
  @override
  Future<void> setPageSize(int size) => _throwNotInitialized();
  @override
  Future<void> clearFilters() => _throwNotInitialized();
  @override
  Future<void> dispose() async {}
  @override
  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths) =>
      _throwNotInitialized();
  @override
  Future<List<String>> getFilteredImagePaths() => _throwNotInitialized();
}
