import 'dart:io';
import 'dart:math';

import '../../../core/exceptions/gallery_exceptions.dart';
import '../../models/gallery/local_image_record.dart';
import 'gallery_filter_service.dart';
import 'gallery_path_utils.dart';
import 'local_gallery_repository.dart';

bool isFavoriteOnlyFastFilter(FilterCriteria criteria) {
  return criteria.showFavoritesOnly &&
      criteria.searchQuery.trim().isEmpty &&
      criteria.dateStart == null &&
      criteria.dateEnd == null &&
      criteria.selectedTags.isEmpty &&
      criteria.filterModel == null &&
      criteria.filterSampler == null &&
      criteria.filterMinSteps == null &&
      criteria.filterMaxSteps == null &&
      criteria.filterMinCfg == null &&
      criteria.filterMaxCfg == null &&
      criteria.filterResolution == null &&
      criteria.minWidth == null &&
      criteria.minHeight == null &&
      criteria.maxWidth == null &&
      criteria.maxHeight == null &&
      criteria.minFileSize == null &&
      criteria.maxFileSize == null &&
      criteria.metadataStatuses.isEmpty &&
      criteria.categoryId == null &&
      criteria.categoryFolderPath == null;
}

/// Owns the authoritative in-memory file ordering and derived query results.
class LocalGalleryQuery {
  LocalGalleryQuery({
    required LocalGalleryRepository repository,
    required GalleryFilterService filterService,
  }) : _repository = repository,
       _filterService = filterService;

  final LocalGalleryRepository _repository;
  final GalleryFilterService _filterService;

  List<File> _allFiles = [];
  List<File> _filteredFiles = [];
  FilterCriteria _currentFilter = const FilterCriteria();
  int _filterGeneration = 0;
  String? _activeFilterOperationId;
  int _pageSize = 50;

  List<File> get allFiles => _allFiles;
  List<File> get effectiveFiles =>
      _currentFilter.hasFilters ? _filteredFiles : _allFiles;
  int get totalCount => _allFiles.length;
  int get filteredCount =>
      _currentFilter.hasFilters ? _filteredFiles.length : totalCount;
  FilterCriteria get currentFilter => _currentFilter;

  void replaceAll(List<File> files) {
    _allFiles = files;
    if (!_currentFilter.hasFilters) _filteredFiles = files;
  }

  String resolveTrackedPath(String filePath) {
    final normalized = normalizeGalleryFilePath(filePath);
    final key = galleryFilePathKey(normalized);
    for (final file in _allFiles) {
      if (galleryFilePathKey(file.path) == key) return file.path;
    }
    return normalized;
  }

  bool containsPath(String filePath) {
    final key = galleryFilePathKey(filePath);
    return _allFiles.any((file) => galleryFilePathKey(file.path) == key);
  }

  void addFirst(File file) {
    if (!containsPath(file.path)) _allFiles.insert(0, file);
  }

  Future<void> syncAfterMutation(File file) async {
    addFirst(file);
    if (_currentFilter.hasFilters) {
      await applyFilter(_currentFilter);
    } else {
      _filteredFiles = _allFiles;
    }
  }

  Future<void> applyFilter(FilterCriteria criteria) async {
    final generation = ++_filterGeneration;
    final previousOperationId = _activeFilterOperationId;
    if (previousOperationId != null) {
      _filterService.cancelFilter(previousOperationId);
      _activeFilterOperationId = null;
    }
    _currentFilter = criteria;

    if (!criteria.hasFilters) {
      if (generation == _filterGeneration) _filteredFiles = _allFiles;
      return;
    }

    if (isFavoriteOnlyFastFilter(criteria)) {
      final records = await _repository.queryFavoriteImages(
        limit: max(1, _allFiles.length),
      );
      if (generation != _filterGeneration || _currentFilter != criteria) return;
      final pathToFile = {
        for (final file in _allFiles) galleryFilePathKey(file.path): file,
      };
      _filteredFiles = [
        for (final record in records)
          if (pathToFile[galleryFilePathKey(record.filePath)] != null)
            pathToFile[galleryFilePathKey(record.filePath)]!,
      ];
      return;
    }

    final operationId = 'local_gallery_filter_$generation';
    _activeFilterOperationId = operationId;
    try {
      final result = await _filterService.applyFilters(
        _allFiles,
        criteria,
        operationId: operationId,
      );
      if (generation != _filterGeneration || _currentFilter != criteria) return;
      _filteredFiles = result.files;
    } on FilterCancelledException {
      if (generation == _filterGeneration) rethrow;
    } catch (error) {
      throw GalleryFilterException(
        filterCriteria: criteria.toString(),
        message: 'Failed to apply filter',
        cause: error,
      );
    } finally {
      if (_activeFilterOperationId == operationId) {
        _activeFilterOperationId = null;
      }
    }
  }

  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async {
    final effectivePageSize = pageSize ?? _pageSize;
    final totalPages = (effectiveFiles.length / effectivePageSize).ceil();
    if (page < 0 || (totalPages > 0 && page >= totalPages)) return [];
    final start = page * effectivePageSize;
    final end = min(start + effectivePageSize, effectiveFiles.length);
    return _repository.loadRecords(effectiveFiles.sublist(start, end));
  }

  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths) async {
    if (paths.isEmpty) return [];
    final existing = <File>[];
    for (final path in paths) {
      final file = File(resolveTrackedPath(path));
      if (await file.exists()) existing.add(file);
    }
    return _repository.loadRecords(existing, includeErrorPlaceholders: false);
  }

  List<String> getFilteredImagePaths() =>
      effectiveFiles.map((file) => file.path).toList(growable: false);

  void setPageSize(int size) => _pageSize = size;

  void clear() {
    _filterGeneration++;
    final operationId = _activeFilterOperationId;
    if (operationId != null) _filterService.cancelFilter(operationId);
    _activeFilterOperationId = null;
    _allFiles = [];
    _filteredFiles = [];
    _currentFilter = const FilterCriteria();
  }
}
