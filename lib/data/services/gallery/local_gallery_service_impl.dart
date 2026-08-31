import 'dart:async';
import 'dart:io';

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/exceptions/gallery_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'gallery_filter_service.dart';
import 'gallery_path_utils.dart';
import 'gallery_scan_coordinator.dart';
import 'local_gallery_query.dart';
import 'local_gallery_repository.dart';
import 'local_gallery_service.dart';

class LocalGalleryServiceImpl implements LocalGalleryService {
  factory LocalGalleryServiceImpl({
    required GalleryDataSource dataSource,
    required GalleryFilterService filterService,
  }) {
    final repository = LocalGalleryRepository(dataSource: dataSource);
    return LocalGalleryServiceImpl._composed(
      repository: repository,
      query: LocalGalleryQuery(
        repository: repository,
        filterService: filterService,
      ),
      scanCoordinator: GalleryScanCoordinator(
        dataSource: dataSource,
        repository: repository,
      ),
    );
  }

  LocalGalleryServiceImpl._composed({
    required LocalGalleryRepository repository,
    required LocalGalleryQuery query,
    required GalleryScanCoordinator scanCoordinator,
  }) : _repository = repository,
       _query = query,
       _scanCoordinator = scanCoordinator;

  final LocalGalleryRepository _repository;
  final LocalGalleryQuery _query;
  final GalleryScanCoordinator _scanCoordinator;
  Future<List<File>>? _initializing;
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;
  @override
  int get filteredCount => _query.filteredCount;
  @override
  int get totalCount => _query.totalCount;
  @override
  FilterCriteria get currentFilter => _query.currentFilter;

  @override
  Future<List<File>> initialize() {
    final active = _initializing;
    if (active != null) return active;
    if (_isInitialized && _query.allFiles.isNotEmpty) {
      return Future.value(_query.allFiles);
    }

    final operation = _initialize();
    _initializing = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_initializing, operation)) _initializing = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_initializing, operation)) _initializing = null;
        },
      ),
    );
    return operation;
  }

  Future<List<File>> _initialize() async {
    try {
      final files = await _scanCoordinator.initialize();
      _query.replaceAll(files);
      _isInitialized = true;
      return files;
    } on GalleryException {
      rethrow;
    } catch (error) {
      throw GalleryScanException(
        message: 'Failed to initialize gallery',
        cause: error,
      );
    }
  }

  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) {
    _ensureInitialized();
    return _query.getPage(page, pageSize: pageSize);
  }

  @override
  Future<LocalGalleryQueryPage> queryPage({
    required int page,
    int pageSize = 50,
    String searchQuery = '',
  }) {
    _ensureInitialized();
    return _query.queryPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<int?> getImageIdByPath(String filePath) {
    _ensureInitialized();
    return _repository.getImageIdByPath(_query.resolveTrackedPath(filePath));
  }

  @override
  Future<List<String>> getFilteredImagePaths() async {
    _ensureInitialized();
    return _query.getFilteredImagePaths();
  }

  @override
  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths) {
    _ensureInitialized();
    return _query.getRecordsByPaths(paths);
  }

  @override
  Future<void> applyFilter(FilterCriteria criteria) {
    _ensureInitialized();
    return _query.applyFilter(criteria);
  }

  @override
  Future<void> setSearchQuery(String query) =>
      applyFilter(currentFilter.copyWith(searchQuery: query));

  @override
  Future<void> setDateRange(DateTime? start, DateTime? end) =>
      applyFilter(currentFilter.copyWith(dateStart: start, dateEnd: end));

  @override
  Future<void> setShowFavoritesOnly(bool value) =>
      applyFilter(currentFilter.copyWith(showFavoritesOnly: value));

  @override
  Future<void> setPageSize(int size) async => _query.setPageSize(size);

  @override
  Future<void> clearFilters() => applyFilter(const FilterCriteria());

  @override
  Future<bool> toggleFavorite(String filePath) async {
    _ensureInitialized();
    try {
      final resolvedPath = _query.resolveTrackedPath(filePath);
      final isFavorite = await _repository.toggleFavorite(resolvedPath);
      if (isFavorite || await File(resolvedPath).exists()) {
        await _query.syncAfterMutation(File(resolvedPath));
      }
      return isFavorite;
    } catch (error) {
      throw GalleryDatabaseException(
        operation: DatabaseOperation.update,
        message: 'Failed to toggle favorite for $filePath',
        cause: error,
      );
    }
  }

  @override
  Future<bool> isFavorite(String filePath) async {
    _ensureInitialized();
    try {
      return await _repository.isFavorite(_query.resolveTrackedPath(filePath));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> getFavoriteCount() async {
    _ensureInitialized();
    if (_query.allFiles.isEmpty) return 0;
    final totalFavorites = await _repository.getFavoriteCount();
    if (totalFavorites == 0) return 0;
    final favorites = await _repository.queryFavoriteImages(
      limit: totalFavorites,
    );
    final visiblePaths = {
      for (final file in _query.allFiles) galleryFilePathKey(file.path),
    };
    return favorites
        .where(
          (record) =>
              visiblePaths.contains(galleryFilePathKey(record.filePath)),
        )
        .length;
  }

  @override
  Future<NaiImageMetadata?> getMetadata(String filePath) async {
    _ensureInitialized();
    try {
      return await _repository.getMetadata(filePath);
    } catch (error) {
      throw GalleryMetadataException(
        imagePath: filePath,
        phase: MetadataErrorPhase.parsing,
        message: 'Failed to get metadata for $filePath',
        cause: error,
      );
    }
  }

  @override
  Future<bool> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) async {
    _ensureInitialized();
    try {
      final file = File(normalizeGalleryFilePath(filePath));
      if (!await file.exists()) {
        AppLogger.w(
          '[AddNewImage] File does not exist: $filePath',
          'LocalGalleryService',
        );
        return false;
      }
      if (_query.containsPath(file.path)) {
        AppLogger.d(
          '[AddNewImage] File already exists in gallery: $filePath',
          'LocalGalleryService',
        );
        return false;
      }
      await _repository.addImage(file, metadata: metadata);
      await _query.syncAfterMutation(file);
      return true;
    } catch (error, stackTrace) {
      AppLogger.e(
        '[AddNewImage] Failed to add new image: $filePath',
        error,
        stackTrace,
        'LocalGalleryService',
      );
      return false;
    }
  }

  @override
  Future<void> refresh({bool scan = true}) async {
    _ensureInitialized();
    try {
      await _scanCoordinator.refresh(
        scan: scan,
        previousCount: _query.totalCount,
        onFilesLoaded: (files) async {
          _query.replaceAll(files);
          await _query.applyFilter(_query.currentFilter);
        },
      );
    } catch (error) {
      if (error is GalleryException) rethrow;
      throw GalleryScanException(
        message: 'Failed to refresh gallery',
        cause: error,
      );
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) throw const GalleryNotInitializedException();
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _query.clear();
  }
}
