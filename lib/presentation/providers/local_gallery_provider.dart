import 'dart:io';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/gallery/local_image_record.dart';
import '../../data/repositories/local_gallery_repository.dart';

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
    String? error,
  }) = _LocalGalleryState;
  
  const LocalGalleryState._();
  
  /// 总页数（基于过滤后的文件）
  int get totalPages => filteredFiles.isEmpty ? 0 : (filteredFiles.length / pageSize).ceil();
  
  /// 是否有过滤条件
  bool get hasFilters => searchQuery.isNotEmpty || dateStart != null || dateEnd != null;
  
  /// 过滤后的图片数量
  int get filteredCount => filteredFiles.length;
  
  /// 总图片数量
  int get totalCount => allFiles.length;
}

/// 本地画廊 Notifier
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  final _repository = LocalGalleryRepository.instance;
  
  /// 缓存：文件路径 -> LocalImageRecord（用于搜索 Prompt）
  final Map<String, LocalImageRecord> _recordCache = {};

  @override
  LocalGalleryState build() {
    return const LocalGalleryState();
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
       state = state.copyWith(currentImages: [], isPageLoading: false, currentPage: 0);
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
        _recordCache[record.path] = record;
      }
      
      state = state.copyWith(currentImages: records, isPageLoading: false);
    } catch (e) {
       state = state.copyWith(isPageLoading: false, error: e.toString());
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
      isPageLoading: true,
    );
    await _applyFilters();
  }
  
  /// 应用过滤条件
  Future<void> _applyFilters() async {
    final query = state.searchQuery.toLowerCase().trim();
    final dateStart = state.dateStart;
    final dateEnd = state.dateEnd;
    
    // 无过滤条件：直接使用全部文件
    if (query.isEmpty && dateStart == null && dateEnd == null) {
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
    
    // 如果没有搜索关键词，直接使用日期过滤结果
    if (query.isEmpty) {
      state = state.copyWith(
        filteredFiles: dateFiltered,
        currentPage: 0,
        isPageLoading: false,
      );
      await loadPage(0);
      return;
    }
    
    // 有搜索关键词：需要加载记录进行 Prompt 匹配
    // 先按文件名过滤，减少需要加载的记录数
    final fileNameMatched = <File>[];
    final needPromptCheck = <File>[];
    
    for (final file in dateFiltered) {
      final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
      if (fileName.contains(query)) {
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
        final cached = _recordCache[file.path];
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
            _recordCache[record.path] = record;
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
    final filtered = [...fileNameMatched, ...promptMatched];
    
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

  /// 刷新画廊
  Future<void> refresh() async {
    _recordCache.clear(); // 清除缓存
    state = const LocalGalleryState(); // Reset
    await initialize();
  }
}
