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
    String? error,
  }) = _LocalGalleryState;

  const LocalGalleryState._();

  /// 总页数（基于过滤后的文件）
  int get totalPages => filteredFiles.isEmpty ? 0 : (filteredFiles.length / pageSize).ceil();

  /// 是否有过滤条件
  bool get hasFilters =>
      searchQuery.isNotEmpty ||
      dateStart != null ||
      dateEnd != null ||
      showFavoritesOnly ||
      selectedTags.isNotEmpty;

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
      AppLogger.e('Failed to initialize search index service', e, null, 'LocalGalleryNotifier');
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

  /// 加载指定页面
  Future<void> loadPage(int page) async {
    // Handle empty list case (totalPages is 0)
    if (state.filteredFiles.isEmpty) {
      state = state
          .copyWith(currentImages: [], isPageLoading: false, currentPage: 0);
      return;
    }

    if (page < 0 || page >= state.totalPages) return;

    state = state.copyWith(isPageLoading: true, currentPage: page);
    try {
      final start = page * state.pageSize;
      final end = min(start + state.pageSize, state.filteredFiles.length);
      final batch = state.filteredFiles.sublist(start, end);

      final records = await _repository.loadRecords(batch);

      // 缓存记录用于搜索
      for (final record in records) {
        _recordCache.put(record.path, record);
        // 索引记录到搜索索引（异步，不阻塞UI）
        _indexRecordInBackground(record);
      }

      state = state.copyWith(currentImages: records, isPageLoading: false);
    } catch (e) {
      state = state.copyWith(isPageLoading: false, error: e.toString());
    }
  }

  /// 在后台索引记录到搜索索引
  Future<void> _indexRecordInBackground(LocalImageRecord record) async {
    try {
      // 只索引有元数据的记录
      if (record.metadata != null && record.metadataStatus != MetadataStatus.none) {
        await _searchIndex.indexDocument(record);
      }
    } catch (e) {
      // 索引失败不影响主流程，静默处理
      AppLogger.d('Failed to index record: ${record.path}', 'LocalGalleryNotifier');
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

    // 无过滤条件：直接使用全部文件
    if (query.isEmpty && dateStart == null && dateEnd == null && !showFavoritesOnly && selectedTags.isEmpty) {
      state = state.copyWith(
        filteredFiles: state.allFiles,
        currentPage: 0,
        isPageLoading: false,
      );
      await loadPage(0);
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
          if (dateEnd != null && modifiedAt.isAfter(dateEnd.add(const Duration(days: 1)))) return false;

          return true;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // 如果只需要收藏或标签过滤，直接应用
    if (query.isEmpty && !showFavoritesOnly && selectedTags.isEmpty) {
      state = state.copyWith(
        filteredFiles: dateFiltered,
        currentPage: 0,
        isPageLoading: false,
      );
      await loadPage(0);
      return;
    }

    // 有收藏过滤或搜索关键词：需要加载记录
    // 如果有搜索关键词：优先使用搜索索引
    if (query.isNotEmpty) {
      try {
        // 如果搜索索引不为空，使用索引进行快速搜索
        if (!_searchIndex.isEmpty) {
          final searchedRecords = await _searchIndex.search(query, limit: 10000);

          // 将搜索结果转换为 File 对象集合
          final searchedPaths = searchedRecords.map((r) => r.path).toSet();

          // 过滤出同时满足搜索结果和日期过滤的文件
          var filtered = dateFiltered.where((file) => searchedPaths.contains(file.path)).toList();

          // 如果需要收藏过滤，再应用收藏过滤
          if (showFavoritesOnly) {
            filtered = _applyFavoriteFilter(filtered);
          }

          // 如果需要标签过滤，再应用标签过滤
          if (selectedTags.isNotEmpty) {
            filtered = _applyTagFilter(filtered);
          }

          state = state.copyWith(
            filteredFiles: filtered,
            currentPage: 0,
            isPageLoading: false,
          );
          await loadPage(0);
          return;
        }
      } catch (e) {
        AppLogger.w('Search index query failed, falling back to manual search: $e', 'LocalGalleryNotifier');
        // 继续使用原有的手动搜索逻辑
      }
    }

    // 回退到手动搜索（搜索索引为空或查询失败时）
    // 先按文件名过滤，减少需要加载的记录数
    final fileNameMatched = <File>[];
    final needPromptCheck = <File>[];

    for (final file in dateFiltered) {
      final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
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

    state = state.copyWith(
      filteredFiles: filtered,
      currentPage: 0,
      isPageLoading: false,
    );
    await loadPage(0);
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

  /// 刷新画廊
  Future<void> refresh() async {
    _recordCache.clear(); // 清除缓存
    state = const LocalGalleryState(); // Reset
    await initialize();
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
      AppLogger.e('Failed to delete image: $imagePath', e, null,
          'LocalGalleryNotifier',);
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

      AppLogger.d('Toggled favorite: $imagePath -> $newFavoriteStatus', 'LocalGalleryNotifier');
      return newFavoriteStatus;
    } catch (e) {
      AppLogger.e('Failed to toggle favorite: $imagePath', e, null, 'LocalGalleryNotifier');
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
        _recordCache.put(imagePath, cached.copyWith(tags: [...cached.tags, trimmedTag]));
      }

      AppLogger.d('Added tag: $trimmedTag to $imagePath', 'LocalGalleryNotifier');
      return true;
    } catch (e) {
      AppLogger.e('Failed to add tag to $imagePath', e, null, 'LocalGalleryNotifier');
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
          return img.copyWith(tags: img.tags.where((t) => t != trimmedTag).toList());
        }
        return img;
      }).toList();

      state = state.copyWith(currentImages: updatedCurrentImages);

      // Update cache
      final cached = _recordCache.get(imagePath);
      if (cached != null) {
        _recordCache.put(imagePath, cached.copyWith(tags: cached.tags.where((t) => t != trimmedTag).toList()));
      }

      AppLogger.d('Removed tag: $trimmedTag from $imagePath', 'LocalGalleryNotifier');
      return true;
    } catch (e) {
      AppLogger.e('Failed to remove tag from $imagePath', e, null, 'LocalGalleryNotifier');
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
}
