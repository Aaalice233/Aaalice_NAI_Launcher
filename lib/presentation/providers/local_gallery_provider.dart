import 'dart:io';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/lru_cache_service.dart';
import '../../data/services/search_index_service.dart';

part 'local_gallery_provider.freezed.dart';
part 'local_gallery_provider.g.dart';

/// 本地画廊状态
@freezed
class LocalGalleryState with _$LocalGalleryState {
  const factory LocalGalleryState({
    /// 所有文件（原始列表）
    @Default([]) List<File> allFiles,

    /// 过滤后的文件列表
    @Default([]) List<File> filteredFiles,

    /// 当前页显示的图片记录
    @Default([]) List<LocalImageRecord> currentImages,
    @Default(0) int currentPage,
    @Default(50) int pageSize,
    @Default(false) bool isIndexing,
    @Default(false) bool isPageLoading,

    /// 搜索关键词（匹配文件名和 Prompt）
    @Default('') String searchQuery,

    /// 日期过滤：开始日期
    DateTime? dateStart,

    /// 日期过滤：结束日期
    DateTime? dateEnd,

    /// 仅显示收藏
    @Default(false) bool showFavoritesOnly,

    /// 标签过滤（选中的标签列表）
    @Default([]) List<String> selectedTags,

    /// 模型过滤
    String? filterModel,

    /// 采样器过滤
    String? filterSampler,

    /// 步数过滤：最小值
    int? filterMinSteps,

    /// 步数过滤：最大值
    int? filterMaxSteps,

    /// CFG 过滤：最小值
    double? filterMinCfg,

    /// CFG 过滤：最大值
    double? filterMaxCfg,

    /// 分辨率过滤（格式：宽度x高度，如 "1024x1024"）
    String? filterResolution,

    /// 是否启用分组视图
    @Default(false) bool isGroupedView,

    /// 分组视图的所有图片记录（用于分组显示）
    @Default([]) List<LocalImageRecord> groupedImages,

    /// 是否正在加载分组图片
    @Default(false) bool isGroupedLoading,
    String? error,
  }) = _LocalGalleryState;

  const LocalGalleryState._();

  /// 总页数（基于过滤后的文件）
  int get totalPages =>
      filteredFiles.isEmpty ? 0 : (filteredFiles.length / pageSize).ceil();

  /// 是否有过滤条件
  bool get hasFilters =>
      searchQuery.isNotEmpty ||
      dateStart != null ||
      dateEnd != null ||
      showFavoritesOnly ||
      selectedTags.isNotEmpty ||
      filterModel != null ||
      filterSampler != null ||
      filterMinSteps != null ||
      filterMaxSteps != null ||
      filterMinCfg != null ||
      filterMaxCfg != null ||
      filterResolution != null;

  /// 过滤后的图片数量
  int get filteredCount => filteredFiles.length;

  /// 总图片数量
  int get totalCount => allFiles.length;
}

/// 本地画廊 Notifier
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  late final LocalGalleryRepository _repository;
  late final LruCacheService _recordCache;
  late final SearchIndexService _searchIndex;

  @override
  LocalGalleryState build() {
    _repository = LocalGalleryRepository.instance;
    _recordCache = ref.read(lruCacheServiceProvider);
    _searchIndex = ref.read(searchIndexServiceProvider);
    // Initialize search index service
    _initSearchIndex();
    return const LocalGalleryState();
  }

  /// 初始化搜索索引服务
  Future<void> _initSearchIndex() async {
    try {
      await _searchIndex.init();
    } catch (e) {
      AppLogger.e(
        'Failed to initialize search index service',
        e,
        null,
        'LocalGalleryNotifier',
      );
    }
  }

  /// 初始化：快速索引文件 + 加载首页
  Future<void> initialize() async {
    if (state.allFiles.isNotEmpty) return;
    state = state.copyWith(isIndexing: true, error: null);
    try {
      final files = await _repository.getAllImageFiles();
      state = state.copyWith(
        allFiles: files,
        filteredFiles: files, // 初始无过滤
        isIndexing: false,
      );
      await loadPage(0);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isIndexing: false);
    }
  }

  /// 获取总收藏数量
  int getTotalFavoriteCount() {
    return _repository.getTotalFavoriteCount();
  }

  /// 加载指定页面
  Future<void> loadPage(int page) async {
    // Handle empty list case (totalPages is 0)
    if (state.filteredFiles.isEmpty) {
      state = state
          .copyWith(currentImages: [], isPageLoading: false, currentPage: 0);
      return;
    }

    if (page < 0 || page >= state.totalPages) return;

    AppLogger.d(
      'loadPage: Starting page $page, filteredFiles: ${state.filteredFiles.length}, pageSize: ${state.pageSize}',
      'LocalGalleryNotifier',
    );

    state = state.copyWith(isPageLoading: true, currentPage: page);
    try {
      final start = page * state.pageSize;
      final end = min(start + state.pageSize, state.filteredFiles.length);
      final batch = state.filteredFiles.sublist(start, end);

      AppLogger.d(
        'loadPage: Loading batch [$start-$end], batch size: ${batch.length}',
        'LocalGalleryNotifier',
      );

      final records = await _repository.loadRecords(batch);

      AppLogger.d(
        'loadPage: Got ${records.length} records from ${batch.length} files',
        'LocalGalleryNotifier',
      );

      // 检查是否有文件被过滤掉（不存在）
      if (records.length < batch.length) {
        AppLogger.w(
          'loadPage: Detected ${batch.length - records.length} missing files, updating lists',
          'LocalGalleryNotifier',
        );

        // 同步更新 filteredFiles 和 allFiles，移除不存在的文件
        final updatedFilteredFiles =
            state.filteredFiles.where((f) => f.existsSync()).toList();
        final updatedAllFiles =
            state.allFiles.where((f) => f.existsSync()).toList();

        AppLogger.i(
          'loadPage: Updated filteredFiles: ${state.filteredFiles.length} -> ${updatedFilteredFiles.length}, '
              'allFiles: ${state.allFiles.length} -> ${updatedAllFiles.length}',
          'LocalGalleryNotifier',
        );

        // 清理 _recordCache 中的无效条目
        final validPaths = records.map((r) => r.path).toSet();
        for (final file in batch) {
          if (!validPaths.contains(file.path)) {
            _recordCache.remove(file.path);
          }
        }

        state = state.copyWith(
          filteredFiles: updatedFilteredFiles,
          allFiles: updatedAllFiles,
          isPageLoading: false,
        );

        // 重新加载当前页（因为文件列表已更新）
        // 使用 Future.microtask 避免递归调用
        final newPage =
            min(page, state.totalPages - 1).clamp(0, state.totalPages - 1);
        AppLogger.d(
          'loadPage: Scheduling reload of page $newPage (totalPages: ${state.totalPages})',
          'LocalGalleryNotifier',
        );
        Future.microtask(() => loadPage(newPage));
        return;
      }

      // 缓存记录用于搜索
      for (final record in records) {
        _recordCache.put(record.path, record);
        // 索引记录到搜索索引（异步，不阻塞UI）
        _indexRecordInBackground(record);
      }

      AppLogger.d(
        'loadPage: Setting currentImages to ${records.length} records',
        'LocalGalleryNotifier',
      );

      state = state.copyWith(currentImages: records, isPageLoading: false);
    } catch (e) {
      AppLogger.e(
        'loadPage: Error: $e',
        'LocalGalleryNotifier',
      );
      state = state.copyWith(isPageLoading: false, error: e.toString());
    }
  }

  /// 在后台索引记录到搜索索引
  Future<void> _indexRecordInBackground(LocalImageRecord record) async {
    try {
      // 只索引有元数据的记录
      if (record.metadata != null &&
          record.metadataStatus != MetadataStatus.none) {
        await _searchIndex.indexDocument(record);
      }
    } catch (e) {
      // 索引失败不影响主流程，静默处理
      AppLogger.d(
        'Failed to index record: ${record.path}',
        'LocalGalleryNotifier',
      );
    }
  }

  /// 设置搜索关键词
  Future<void> setSearchQuery(String query) async {
    if (state.searchQuery == query) return;

    state = state.copyWith(searchQuery: query, isPageLoading: true);
    await _applyFilters();
  }

  /// 设置日期范围过滤
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    if (state.dateStart == start && state.dateEnd == end) return;

    state = state.copyWith(dateStart: start, dateEnd: end, isPageLoading: true);
    await _applyFilters();
  }

  /// 清除日期过滤
  Future<void> clearDateFilter() async {
    await setDateRange(null, null);
  }

  /// 清除所有过滤条件
  Future<void> clearAllFilters() async {
    state = state.copyWith(
      searchQuery: '',
      dateStart: null,
      dateEnd: null,
      showFavoritesOnly: false,
      selectedTags: [],
      filterModel: null,
      filterSampler: null,
      filterMinSteps: null,
      filterMaxSteps: null,
      filterMinCfg: null,
      filterMaxCfg: null,
      filterResolution: null,
      isPageLoading: true,
    );
    await _applyFilters();
  }

  /// 应用过滤条件
  Future<void> _applyFilters() async {
    final query = state.searchQuery.toLowerCase().trim();
    final dateStart = state.dateStart;
    final dateEnd = state.dateEnd;
    final showFavoritesOnly = state.showFavoritesOnly;
    final selectedTags = state.selectedTags;
    final filterModel = state.filterModel;
    final filterSampler = state.filterSampler;
    final filterMinSteps = state.filterMinSteps;
    final filterMaxSteps = state.filterMaxSteps;
    final filterMinCfg = state.filterMinCfg;
    final filterMaxCfg = state.filterMaxCfg;
    final filterResolution = state.filterResolution;

    // 无过滤条件：直接使用全部文件
    if (query.isEmpty &&
        dateStart == null &&
        dateEnd == null &&
        !showFavoritesOnly &&
        selectedTags.isEmpty &&
        filterModel == null &&
        filterSampler == null &&
        filterMinSteps == null &&
        filterMaxSteps == null &&
        filterMinCfg == null &&
        filterMaxCfg == null &&
        filterResolution == null) {
      state = state.copyWith(
        filteredFiles: state.allFiles,
        currentPage: 0,
        isPageLoading: false,
      );

      if (state.isGroupedView) {
        await _loadGroupedImages();
      } else {
        await loadPage(0);
      }
      return;
    }

    // 有过滤条件：需要加载所有记录进行过滤
    // 为了性能，先用日期过滤（基于文件修改时间，无需加载元数据）
    List<File> dateFiltered = state.allFiles;

    if (dateStart != null || dateEnd != null) {
      dateFiltered = state.allFiles.where((file) {
        try {
          final stat = file.statSync();
          final modifiedAt = stat.modified;

          if (dateStart != null && modifiedAt.isBefore(dateStart)) return false;
          if (dateEnd != null &&
              modifiedAt.isAfter(dateEnd.add(const Duration(days: 1)))) {
            return false;
          }

          return true;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // 如果只需要收藏、标签或元数据过滤，直接应用
    if (query.isEmpty && !showFavoritesOnly && selectedTags.isEmpty) {
      var filtered = dateFiltered;

      // 应用元数据过滤
      if (_hasMetadataFilters) {
        filtered = await _applyMetadataFilter(filtered);
      }

      state = state.copyWith(
        filteredFiles: filtered,
        currentPage: 0,
        isPageLoading: false,
      );

      if (state.isGroupedView) {
        await _loadGroupedImages();
      } else {
        await loadPage(0);
      }
      return;
    }

    // 有收藏过滤或搜索关键词：需要加载记录
    // 如果有搜索关键词：优先使用搜索索引
    if (query.isNotEmpty) {
      try {
        // 如果搜索索引不为空，使用索引进行快速搜索
        if (!_searchIndex.isEmpty) {
          final searchedRecords =
              await _searchIndex.search(query, limit: 10000);

          // 将搜索结果转换为 File 对象集合
          final searchedPaths = searchedRecords.map((r) => r.path).toSet();

          // 过滤出同时满足搜索结果和日期过滤的文件
          var filtered = dateFiltered
              .where((file) => searchedPaths.contains(file.path))
              .toList();

          // 如果需要收藏过滤，再应用收藏过滤
          if (showFavoritesOnly) {
            filtered = _applyFavoriteFilter(filtered);
          }

          // 如果需要标签过滤，再应用标签过滤
          if (selectedTags.isNotEmpty) {
            filtered = _applyTagFilter(filtered);
          }

          // 如果需要元数据过滤，再应用元数据过滤
          if (_hasMetadataFilters) {
            filtered = await _applyMetadataFilter(filtered);
          }

          state = state.copyWith(
            filteredFiles: filtered,
            currentPage: 0,
            isPageLoading: false,
          );

          if (state.isGroupedView) {
            await _loadGroupedImages();
          } else {
            await loadPage(0);
          }
          return;
        }
      } catch (e) {
        AppLogger.w(
          'Search index query failed, falling back to manual search: $e',
          'LocalGalleryNotifier',
        );
        // 继续使用原有的手动搜索逻辑
      }
    }

    // 回退到手动搜索（搜索索引为空或查询失败时）
    // 先按文件名过滤，减少需要加载的记录数
    final fileNameMatched = <File>[];
    final needPromptCheck = <File>[];

    for (final file in dateFiltered) {
      final fileName =
          file.path.split(Platform.pathSeparator).last.toLowerCase();
      if (query.isEmpty || fileName.contains(query)) {
        fileNameMatched.add(file);
      } else {
        needPromptCheck.add(file);
      }
    }

    // 对需要检查 Prompt 的文件，批量加载记录
    final promptMatched = <File>[];

    // 分批加载，避免一次性加载太多
    const batchSize = 100;
    for (var i = 0; i < needPromptCheck.length; i += batchSize) {
      final end = min(i + batchSize, needPromptCheck.length);
      final batch = needPromptCheck.sublist(i, end);

      // 优先使用缓存
      final uncached = <File>[];
      for (final file in batch) {
        final cached = _recordCache.get(file.path);
        if (cached != null) {
          // 检查 Prompt
          if (_matchesPrompt(cached, query)) {
            promptMatched.add(file);
          }
        } else {
          uncached.add(file);
        }
      }

      // 加载未缓存的记录
      if (uncached.isNotEmpty) {
        try {
          final records = await _repository.loadRecords(uncached);
          for (final record in records) {
            _recordCache.put(record.path, record);
            if (_matchesPrompt(record, query)) {
              promptMatched.add(File(record.path));
            }
          }
        } catch (_) {
          // 忽略加载错误
        }
      }
    }

    // 合并结果
    var filtered = [...fileNameMatched, ...promptMatched];

    // 如果需要收藏过滤，应用收藏过滤
    if (showFavoritesOnly) {
      filtered = _applyFavoriteFilter(filtered);
    }

    // 如果需要标签过滤，应用标签过滤
    if (selectedTags.isNotEmpty) {
      filtered = _applyTagFilter(filtered);
    }

    // 如果需要元数据过滤，应用元数据过滤
    if (_hasMetadataFilters) {
      filtered = await _applyMetadataFilter(filtered);
    }

    state = state.copyWith(
      filteredFiles: filtered,
      currentPage: 0,
      isPageLoading: false,
    );

    // 如果启用分组视图，刷新分组图片
    if (state.isGroupedView) {
      await _loadGroupedImages();
    } else {
      await loadPage(0);
    }
  }

  /// 检查记录的 Prompt 是否匹配搜索词
  bool _matchesPrompt(LocalImageRecord record, String query) {
    final metadata = record.metadata;
    if (metadata == null) return false;

    // 检查正向 Prompt
    final prompt = metadata.prompt.toLowerCase();
    if (prompt.contains(query)) return true;

    // 检查负向 Prompt
    final negativePrompt = metadata.negativePrompt.toLowerCase();
    if (negativePrompt.contains(query)) return true;

    return false;
  }

  /// 应用收藏过滤
  List<File> _applyFavoriteFilter(List<File> files) {
    return files.where((file) => _repository.isFavorite(file.path)).toList();
  }

  /// 应用标签过滤
  List<File> _applyTagFilter(List<File> files) {
    final selectedTags = state.selectedTags;
    if (selectedTags.isEmpty) return files;

    return files.where((file) {
      final tags = _repository.getTags(file.path);
      // 检查是否包含所有选中的标签（AND 逻辑）
      return selectedTags.every((selectedTag) => tags.contains(selectedTag));
    }).toList();
  }

  /// 应用元数据过滤（模型、采样器、步数、CFG、分辨率）
  /// 这是一个异步方法，因为可能需要加载未缓存的记录
  Future<List<File>> _applyMetadataFilter(List<File> files) async {
    final filterModel = state.filterModel;
    final filterSampler = state.filterSampler;
    final filterMinSteps = state.filterMinSteps;
    final filterMaxSteps = state.filterMaxSteps;
    final filterMinCfg = state.filterMinCfg;
    final filterMaxCfg = state.filterMaxCfg;
    final filterResolution = state.filterResolution;

    // 如果没有元数据过滤条件，直接返回
    if (filterModel == null &&
        filterSampler == null &&
        filterMinSteps == null &&
        filterMaxSteps == null &&
        filterMinCfg == null &&
        filterMaxCfg == null &&
        filterResolution == null) {
      return files;
    }

    // 分离已缓存和未缓存的文件
    final cachedMatched = <File>[];
    final uncached = <File>[];

    for (final file in files) {
      final cached = _recordCache.get(file.path);
      if (cached != null && cached.metadata != null) {
        // 检查缓存的记录是否匹配
        if (_matchesMetadataFilters(cached.metadata!)) {
          cachedMatched.add(file);
        }
      } else {
        uncached.add(file);
      }
    }

    // 如果没有未缓存的文件，直接返回结果
    if (uncached.isEmpty) {
      return cachedMatched;
    }

    // 分批加载未缓存的记录
    const batchSize = 100;
    for (var i = 0; i < uncached.length; i += batchSize) {
      final end = min(i + batchSize, uncached.length);
      final batch = uncached.sublist(i, end);

      try {
        final records = await _repository.loadRecords(batch);
        for (final record in records) {
          // 缓存记录
          _recordCache.put(record.path, record);

          // 检查元数据是否匹配
          if (record.metadata != null &&
              _matchesMetadataFilters(record.metadata!)) {
            cachedMatched.add(File(record.path));
          }
        }
      } catch (e) {
        // 忽略加载错误，这些文件将被排除在过滤结果之外
        AppLogger.d(
          'Failed to load records for metadata filtering: $e',
          'LocalGalleryNotifier',
        );
      }
    }

    return cachedMatched;
  }

  /// 检查元数据是否匹配所有过滤器
  bool _matchesMetadataFilters(dynamic metadata) {
    final filterModel = state.filterModel;
    final filterSampler = state.filterSampler;
    final filterMinSteps = state.filterMinSteps;
    final filterMaxSteps = state.filterMaxSteps;
    final filterMinCfg = state.filterMinCfg;
    final filterMaxCfg = state.filterMaxCfg;
    final filterResolution = state.filterResolution;

    // 检查模型
    if (filterModel != null && metadata.model != filterModel) {
      return false;
    }

    // 检查采样器
    if (filterSampler != null && metadata.sampler != filterSampler) {
      return false;
    }

    // 检查步数范围
    if (filterMinSteps != null || filterMaxSteps != null) {
      final steps = metadata.steps;
      if (steps == null) return false;
      if (filterMinSteps != null && steps < filterMinSteps) return false;
      if (filterMaxSteps != null && steps > filterMaxSteps) return false;
    }

    // 检查 CFG 范围
    if (filterMinCfg != null || filterMaxCfg != null) {
      final cfg = metadata.scale;
      if (cfg == null) return false;
      if (filterMinCfg != null && cfg < filterMinCfg) return false;
      if (filterMaxCfg != null && cfg > filterMaxCfg) return false;
    }

    // 检查分辨率
    if (filterResolution != null) {
      final width = metadata.width;
      final height = metadata.height;
      if (width == null || height == null) return false;

      // 解析分辨率字符串（格式：宽度x高度，如 "1024x1024"）
      final parts = filterResolution.toLowerCase().split('x');
      if (parts.length != 2) return false;

      final filterWidth = int.tryParse(parts[0]);
      final filterHeight = int.tryParse(parts[1]);
      if (filterWidth == null || filterHeight == null) return false;

      if (width != filterWidth || height != filterHeight) return false;
    }

    return true;
  }

  /// 检查是否有元数据过滤条件
  bool get _hasMetadataFilters =>
      state.filterModel != null ||
      state.filterSampler != null ||
      state.filterMinSteps != null ||
      state.filterMaxSteps != null ||
      state.filterMinCfg != null ||
      state.filterMaxCfg != null ||
      state.filterResolution != null;

  /// 设置每页显示数量
  Future<void> setPageSize(int size) async {
    if (size <= 0 || size == state.pageSize) return;

    state = state.copyWith(pageSize: size, isPageLoading: true);

    // 重新计算当前页（确保不超过新的总页数）
    final newTotalPages = state.filteredFiles.isEmpty
        ? 0
        : (state.filteredFiles.length / size).ceil();
    final newCurrentPage =
        state.currentPage.clamp(0, newTotalPages > 0 ? newTotalPages - 1 : 0);

    if (state.isGroupedView) {
      state = state.copyWith(currentPage: newCurrentPage, isPageLoading: false);
    } else {
      await loadPage(newCurrentPage);
    }
  }

  /// 刷新画廊
  Future<void> refresh() async {
    _recordCache.clear(); // 清除缓存
    final wasGroupedView = state.isGroupedView;
    state = const LocalGalleryState(); // Reset

    await initialize();

    // 如果之前是分组视图模式，恢复它
    if (wasGroupedView) {
      await setGroupedView(true);
    }
  }

  /// 删除图片
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);

      // 检查文件是否存在
      if (!await file.exists()) {
        return false;
      }

      // 删除文件
      await file.delete();

      // 从缓存中移除
      _recordCache.remove(imagePath);

      // 从状态中移除文件
      final updatedAllFiles =
          state.allFiles.where((f) => f.path != imagePath).toList();
      final updatedFilteredFiles =
          state.filteredFiles.where((f) => f.path != imagePath).toList();
      final updatedCurrentImages =
          state.currentImages.where((img) => img.path != imagePath).toList();

      state = state.copyWith(
        allFiles: updatedAllFiles,
        filteredFiles: updatedFilteredFiles,
        currentImages: updatedCurrentImages,
      );

      return true;
    } catch (e) {
      AppLogger.e(
        'Failed to delete image: $imagePath',
        e,
        null,
        'LocalGalleryNotifier',
      );
      return false;
    }
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(String imagePath) async {
    try {
      final newFavoriteStatus = await _repository.toggleFavorite(imagePath);

      // 更新当前显示列表中的记录
      final updatedCurrentImages = state.currentImages.map((img) {
        if (img.path == imagePath) {
          return img.copyWith(isFavorite: newFavoriteStatus);
        }
        return img;
      }).toList();

      state = state.copyWith(currentImages: updatedCurrentImages);

      // 如果当前正在过滤收藏，需要重新应用过滤器
      if (state.showFavoritesOnly && !newFavoriteStatus) {
        await _applyFilters();
      }

      AppLogger.d(
        'Toggled favorite: $imagePath -> $newFavoriteStatus',
        'LocalGalleryNotifier',
      );
      return newFavoriteStatus;
    } catch (e) {
      AppLogger.e(
        'Failed to toggle favorite: $imagePath',
        e,
        null,
        'LocalGalleryNotifier',
      );
      return false;
    }
  }

  /// 设置仅显示收藏
  Future<void> setShowFavoritesOnly(bool showOnly) async {
    if (state.showFavoritesOnly == showOnly) return;

    state = state.copyWith(showFavoritesOnly: showOnly, isPageLoading: true);
    await _applyFilters();
  }

  /// 添加标签到图片
  Future<bool> addTag(String imagePath, String tag) async {
    try {
      // Trim and validate tag
      final trimmedTag = tag.trim();
      if (trimmedTag.isEmpty) return false;

      // Check if tag already exists
      final currentTags = _repository.getTags(imagePath);
      if (currentTags.contains(trimmedTag)) {
        return true; // Already has the tag
      }

      // Add tag via repository
      await _repository.addTag(imagePath, trimmedTag);

      // Update current images list if the image is visible
      final updatedCurrentImages = state.currentImages.map((img) {
        if (img.path == imagePath) {
          return img.copyWith(tags: [...img.tags, trimmedTag]);
        }
        return img;
      }).toList();

      state = state.copyWith(currentImages: updatedCurrentImages);

      // Update cache
      final cached = _recordCache.get(imagePath);
      if (cached != null) {
        _recordCache.put(
          imagePath,
          cached.copyWith(tags: [...cached.tags, trimmedTag]),
        );
      }

      AppLogger.d(
        'Added tag: $trimmedTag to $imagePath',
        'LocalGalleryNotifier',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Failed to add tag to $imagePath',
        e,
        null,
        'LocalGalleryNotifier',
      );
      return false;
    }
  }

  /// 从图片移除标签
  Future<bool> removeTag(String imagePath, String tag) async {
    try {
      // Trim and validate tag
      final trimmedTag = tag.trim();
      if (trimmedTag.isEmpty) return false;

      // Check if tag exists
      final currentTags = _repository.getTags(imagePath);
      if (!currentTags.contains(trimmedTag)) {
        return true; // Tag doesn't exist, nothing to remove
      }

      // Remove tag via repository
      await _repository.removeTag(imagePath, trimmedTag);

      // Update current images list if the image is visible
      final updatedCurrentImages = state.currentImages.map((img) {
        if (img.path == imagePath) {
          return img.copyWith(
            tags: img.tags.where((t) => t != trimmedTag).toList(),
          );
        }
        return img;
      }).toList();

      state = state.copyWith(currentImages: updatedCurrentImages);

      // Update cache
      final cached = _recordCache.get(imagePath);
      if (cached != null) {
        _recordCache.put(
          imagePath,
          cached.copyWith(
            tags: cached.tags.where((t) => t != trimmedTag).toList(),
          ),
        );
      }

      AppLogger.d(
        'Removed tag: $trimmedTag from $imagePath',
        'LocalGalleryNotifier',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Failed to remove tag from $imagePath',
        e,
        null,
        'LocalGalleryNotifier',
      );
      return false;
    }
  }

  /// 设置选中的标签（用于过滤）
  Future<void> setSelectedTags(List<String> tags) async {
    // Compare lists regardless of order
    final currentTags = state.selectedTags;
    final isSame = currentTags.length == tags.length &&
        currentTags.every((tag) => tags.contains(tag));

    if (isSame) return;

    state = state.copyWith(selectedTags: tags, isPageLoading: true);
    await _applyFilters();
  }

  /// 清除标签过滤
  Future<void> clearTagFilter() async {
    await setSelectedTags([]);
  }

  /// 设置模型过滤
  Future<void> setFilterModel(String? model) async {
    if (state.filterModel == model) return;

    state = state.copyWith(filterModel: model, isPageLoading: true);
    await _applyFilters();
  }

  /// 设置采样器过滤
  Future<void> setFilterSampler(String? sampler) async {
    if (state.filterSampler == sampler) return;

    state = state.copyWith(filterSampler: sampler, isPageLoading: true);
    await _applyFilters();
  }

  /// 设置步数过滤范围
  Future<void> setFilterSteps(int? min, int? max) async {
    if (state.filterMinSteps == min && state.filterMaxSteps == max) return;

    state = state.copyWith(
      filterMinSteps: min,
      filterMaxSteps: max,
      isPageLoading: true,
    );
    await _applyFilters();
  }

  /// 清除步数过滤
  Future<void> clearFilterSteps() async {
    await setFilterSteps(null, null);
  }

  /// 设置 CFG 过滤范围
  Future<void> setFilterCfg(double? min, double? max) async {
    if (state.filterMinCfg == min && state.filterMaxCfg == max) return;

    state = state.copyWith(
      filterMinCfg: min,
      filterMaxCfg: max,
      isPageLoading: true,
    );
    await _applyFilters();
  }

  /// 清除 CFG 过滤
  Future<void> clearFilterCfg() async {
    await setFilterCfg(null, null);
  }

  /// 设置分辨率过滤
  Future<void> setFilterResolution(String? resolution) async {
    if (state.filterResolution == resolution) return;

    state = state.copyWith(filterResolution: resolution, isPageLoading: true);
    await _applyFilters();
  }

  /// 清除分辨率过滤
  Future<void> clearFilterResolution() async {
    await setFilterResolution(null);
  }

  /// 切换分组视图模式
  Future<void> setGroupedView(bool enable) async {
    if (state.isGroupedView == enable) return;

    state = state.copyWith(isGroupedView: enable);

    if (enable) {
      // 启用分组视图：加载所有过滤后的图片
      await _loadGroupedImages();
    } else {
      // 禁用分组视图：清除分组图片，加载当前页
      state = state.copyWith(groupedImages: []);
      await loadPage(state.currentPage);
    }
  }

  /// 加载所有过滤后的图片（用于分组视图）
  Future<void> _loadGroupedImages() async {
    if (state.filteredFiles.isEmpty) {
      state = state.copyWith(groupedImages: [], isGroupedLoading: false);
      return;
    }

    state = state.copyWith(isGroupedLoading: true);

    try {
      // 分批加载所有图片，避免一次性加载过多
      const batchSize = 100;
      final allRecords = <LocalImageRecord>[];

      for (var i = 0; i < state.filteredFiles.length; i += batchSize) {
        final end = min(i + batchSize, state.filteredFiles.length);
        final batch = state.filteredFiles.sublist(i, end);

        final records = await _repository.loadRecords(batch);

        // 缓存记录
        for (final record in records) {
          _recordCache.put(record.path, record);
          // 索引记录到搜索索引（异步，不阻塞UI）
          _indexRecordInBackground(record);
        }

        allRecords.addAll(records);
      }

      // 按日期排序（最新的在前）
      allRecords.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

      state =
          state.copyWith(groupedImages: allRecords, isGroupedLoading: false);
    } catch (e) {
      state = state.copyWith(isGroupedLoading: false, error: e.toString());
    }
  }

  /// 刷新分组视图（当过滤条件改变时调用）
  Future<void> refreshGroupedView() async {
    if (!state.isGroupedView) return;

    await _loadGroupedImages();
  }

  /// 获取特定日期的图片列表
  List<LocalImageRecord> getImagesForDate(DateTime date) {
    if (!state.isGroupedView) return [];

    final targetDate = DateTime(date.year, date.month, date.day);

    return state.groupedImages.where((image) {
      final imageDate = DateTime(
        image.modifiedAt.year,
        image.modifiedAt.month,
        image.modifiedAt.day,
      );
      return imageDate == targetDate;
    }).toList();
  }

  /// 获取今天的图片
  List<LocalImageRecord> getTodayImages() {
    if (!state.isGroupedView) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return state.groupedImages.where((image) {
      final imageDate = DateTime(
        image.modifiedAt.year,
        image.modifiedAt.month,
        image.modifiedAt.day,
      );
      return imageDate == today;
    }).toList();
  }

  /// 获取昨天的图片
  List<LocalImageRecord> getYesterdayImages() {
    if (!state.isGroupedView) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return state.groupedImages.where((image) {
      final imageDate = DateTime(
        image.modifiedAt.year,
        image.modifiedAt.month,
        image.modifiedAt.day,
      );
      return imageDate == yesterday;
    }).toList();
  }

  /// 获取本周的图片（不包括今天和昨天）
  List<LocalImageRecord> getThisWeekImages() {
    if (!state.isGroupedView) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    return state.groupedImages.where((image) {
      final imageDate = DateTime(
        image.modifiedAt.year,
        image.modifiedAt.month,
        image.modifiedAt.day,
      );
      return imageDate.isAfter(thisWeekStart) && imageDate.isBefore(yesterday);
    }).toList();
  }

  /// 获取更早的图片
  List<LocalImageRecord> getEarlierImages() {
    if (!state.isGroupedView) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    return state.groupedImages.where((image) {
      final imageDate = DateTime(
        image.modifiedAt.year,
        image.modifiedAt.month,
        image.modifiedAt.day,
      );
      return imageDate.isBefore(thisWeekStart);
    }).toList();
  }

  /// 按文件夹路径过滤图片
  /// Filter images by folder path
  Future<void> filterByFolder(String? folderPath) async {
    if (folderPath == null) {
      // 显示全部图片
      state = state.copyWith(
        filteredFiles: state.allFiles,
        isPageLoading: true,
      );
    } else {
      // 过滤出指定文件夹下的图片
      final filtered = state.allFiles.where((file) {
        final fileFolderPath = file.parent.path;
        return fileFolderPath == folderPath ||
            fileFolderPath.startsWith('$folderPath${Platform.pathSeparator}');
      }).toList();

      state = state.copyWith(
        filteredFiles: filtered,
        isPageLoading: true,
      );
    }

    // 重新应用其他过滤条件并加载
    if (state.isGroupedView) {
      await _loadGroupedImages();
    } else {
      await loadPage(0);
    }
  }
}
