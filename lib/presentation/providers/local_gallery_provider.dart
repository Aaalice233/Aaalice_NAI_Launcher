import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/gallery/gallery_scan_service.dart';

part 'local_gallery_provider.freezed.dart';
part 'local_gallery_provider.g.dart';

/// 本地画廊状态
@freezed
class LocalGalleryState with _$LocalGalleryState {
  const factory LocalGalleryState({
    /// 所有文件
    @Default([]) List<File> allFiles,
    /// 过滤后的文件
    @Default([]) List<File> filteredFiles,
    /// 当前页显示的记录
    @Default([]) List<LocalImageRecord> currentImages,
    @Default(0) int currentPage,
    @Default(50) int pageSize,
    @Default(false) bool isLoading,
    @Default(false) bool isIndexing,      // 用于兼容旧代码
    @Default(false) bool isPageLoading,   // 用于兼容旧代码
    /// 搜索关键词
    @Default('') String searchQuery,
    /// 日期过滤
    DateTime? dateStart,
    DateTime? dateEnd,
    /// 收藏过滤
    @Default(false) bool showFavoritesOnly,
    /// Vibe过滤
    @Default(false) bool vibeOnly,
    /// 标签过滤
    @Default([]) List<String> selectedTags,
    /// 元数据过滤
    String? filterModel,
    String? filterSampler,
    int? filterMinSteps,
    int? filterMaxSteps,
    double? filterMinCfg,
    double? filterMaxCfg,
    String? filterResolution,
    /// 分组视图（兼容旧代码）
    @Default(false) bool isGroupedView,
    @Default([]) List<LocalImageRecord> groupedImages,
    @Default(false) bool isGroupedLoading,
    /// 后台扫描进度（0-100，null表示未开始）
    double? backgroundScanProgress,
    /// 扫描阶段：'checking' | 'indexing' | 'completed' | null
    String? scanPhase,
    /// 当前扫描的文件
    String? scanningFile,
    /// 已扫描文件数
    @Default(0) int scannedCount,
    /// 总文件数
    @Default(0) int totalScanCount,
    /// 是否正在重建索引（全量扫描）
    @Default(false) bool isRebuildingIndex,
    /// 错误信息
    String? error,
  }) = _LocalGalleryState;

  const LocalGalleryState._();

  int get totalPages => filteredFiles.isEmpty
      ? 0
      : (filteredFiles.length / pageSize).ceil();

  /// 兼容旧代码的 getter
  int get filteredCount => filteredFiles.length;
  int get totalCount => allFiles.length;

  bool get hasFilters =>
      searchQuery.isNotEmpty ||
      dateStart != null ||
      dateEnd != null ||
      showFavoritesOnly ||
      vibeOnly ||
      selectedTags.isNotEmpty ||
      filterModel != null ||
      filterSampler != null ||
      filterMinSteps != null ||
      filterMaxSteps != null ||
      filterMinCfg != null ||
      filterMaxCfg != null ||
      filterResolution != null;
}

/// 本地画廊 Notifier（简化版）
///
/// 依赖关系：
/// - LocalGalleryRepository: 数据操作
/// - SQLite (via Repository): 唯一数据源
/// - FileWatcherService (via Repository): 自动增量更新
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  late final LocalGalleryRepository _repo;

  @override
  LocalGalleryState build() {
    _repo = LocalGalleryRepository.instance;
    return const LocalGalleryState();
  }

  // ============================================================
  // 初始化
  // ============================================================

  /// 初始化画廊（优化启动速度）
  ///
  /// 1. 立即显示文件列表（从文件系统读取）
  /// 2. 后台扫描索引文件
  /// 3. 后台继续扫描剩余文件
  Future<void> initialize() async {
    if (state.allFiles.isNotEmpty) return;

    state = state.copyWith(
      isLoading: true,
      isIndexing: true,
      isPageLoading: true,
      backgroundScanProgress: 0.0,
    );

    try {
      // 【关键】先加载文件列表，让用户立即看到图片
      // 这一步不依赖数据库，直接从文件系统读取
      final files = await _repo.getAllImageFiles();
      state = state.copyWith(
        allFiles: files,
        filteredFiles: files,
        isLoading: false,  // 文件列表已显示，可以交互了
      );

      // 加载首页（显示图片）
      await loadPage(0);

      // 在后台初始化仓库（扫描索引）
      // 这不会阻塞UI，因为文件已经显示了
      unawaited(_initializeInBackground());

    } catch (e) {
      AppLogger.e('Failed to initialize', e, null, 'LocalGalleryNotifier');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
        backgroundScanProgress: null,
      );
    }
  }

  /// 后台初始化（扫描索引）
  Future<void> _initializeInBackground() async {
    try {
      // 初始化仓库（快速扫描 + 后台完整扫描）
      await _repo.initialize(onProgress: _onScanProgress);

      // 扫描完成后，静默刷新当前页以显示元数据（不显示加载中）
      state = state.copyWith(
        isIndexing: false,
        isPageLoading: false,
      );
      // 后台刷新，不显示加载状态，避免干扰用户浏览
      await loadPage(state.currentPage, showLoading: false);
      
      // 延迟清理扫描状态（让用户看到 100% 完成）
      Future.delayed(const Duration(seconds: 2), () {
        if (state.scanPhase == 'completed') {
          state = state.copyWith(
            backgroundScanProgress: null,
            scanPhase: null,
            scanningFile: null,
          );
        }
      });
    } catch (e) {
      AppLogger.w('Background initialization failed: $e', 'LocalGalleryNotifier');
      state = state.copyWith(
        isIndexing: false,
        isPageLoading: false,
        backgroundScanProgress: null,
        scanPhase: null,
      );
    }
  }

  /// 处理扫描进度回调
  void _onScanProgress({
    required int processed,
    required int total,
    String? currentFile,
    required String phase,
  }) {
    // 如果是 'pending' 阶段，表示有大量文件待处理，跳过预热阶段
    if (phase == 'pending') {
      state = state.copyWith(
        scanPhase: 'pending',
        totalScanCount: total,
        isIndexing: false, // 用户可立即交互
      );
      return;
    }

    final progress = total > 0 ? processed / total : 0.0;
    state = state.copyWith(
      backgroundScanProgress: progress,
      scanPhase: phase,
      scanningFile: currentFile,
      scannedCount: processed,
      totalScanCount: total,
    );

    // 扫描完成时清理状态
    if (phase == 'completed') {
      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(
          backgroundScanProgress: null,
          scanPhase: null,
          scanningFile: null,
        );
      });
    }
  }

  // ============================================================
  // 数据加载
  // ============================================================

  /// 加载指定页面
  /// 
  /// [showLoading] - 是否显示加载状态。后台刷新时应为 false，避免干扰用户浏览
  Future<void> loadPage(int page, {bool showLoading = true}) async {
    if (state.filteredFiles.isEmpty) {
      state = state.copyWith(currentImages: [], currentPage: 0);
      return;
    }
    if (page < 0 || page >= state.totalPages) return;

    if (showLoading) {
      state = state.copyWith(isLoading: true, currentPage: page);
    }
    try {
      final start = page * state.pageSize;
      final end = min(start + state.pageSize, state.filteredFiles.length);
      final batch = state.filteredFiles.sublist(start, end);

      final records = await _repo.loadRecords(batch);
      state = state.copyWith(currentImages: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, isIndexing: false, isPageLoading: false);
    }
  }

  /// 刷新（增量扫描）
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.performIncrementalScan();
      final files = await _repo.getAllImageFiles();
      state = state.copyWith(allFiles: files, isLoading: false);
      await _applyFilters();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// 取消令牌，用于取消重建索引
  bool _shouldCancelRebuild = false;

  /// 重建索引（全量扫描）
  /// 返回扫描结果，调用方应根据结果显示 Toast
  Future<ScanResult?> performFullScan() async {
    if (state.isRebuildingIndex) {
      // 如果已经在重建中，则取消
      _shouldCancelRebuild = true;
      return null;
    }

    _shouldCancelRebuild = false;
    state = state.copyWith(isRebuildingIndex: true, isLoading: true);
    
    try {
      final result = await _repo.performFullScan(
        onProgress: ({required processed, required total, currentFile, required phase}) {
          // 检查是否被取消
          if (_shouldCancelRebuild) {
            return; // 忽略进度更新
          }
          _onScanProgress(
            processed: processed,
            total: total,
            currentFile: currentFile,
            phase: phase,
          );
        },
      );
      
      if (_shouldCancelRebuild) {
        AppLogger.i('Rebuild index cancelled by user', 'LocalGalleryNotifier');
        state = state.copyWith(
          isLoading: false,
          isRebuildingIndex: false,
        );
        return null;
      }
      
      final files = await _repo.getAllImageFiles();
      state = state.copyWith(
        allFiles: files,
        isLoading: false,
        isRebuildingIndex: false,
      );
      await _applyFilters();
      return result;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isRebuildingIndex: false,
      );
      return null;
    }
  }

  // ============================================================
  // 搜索和过滤
  // ============================================================

  Future<void> setSearchQuery(String query) async {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    await _applyFilters();
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    if (state.dateStart == start && state.dateEnd == end) return;
    state = state.copyWith(dateStart: start, dateEnd: end);
    await _applyFilters();
  }

  Future<void> setShowFavoritesOnly(bool value) async {
    if (state.showFavoritesOnly == value) return;
    state = state.copyWith(showFavoritesOnly: value);
    await _applyFilters();
  }

  Future<void> toggleVibeOnly() async {
    state = state.copyWith(vibeOnly: !state.vibeOnly);
    await _applyFilters();
  }

  Future<void> setPageSize(int size) async {
    if (state.pageSize == size) return;
    state = state.copyWith(pageSize: size, currentPage: 0);
    await loadPage(0);
  }

  Future<void> setFilterModel(String? model) async {
    state = state.copyWith(filterModel: model);
    await _applyFilters();
  }

  Future<void> setFilterSampler(String? sampler) async {
    state = state.copyWith(filterSampler: sampler);
    await _applyFilters();
  }

  Future<void> setFilterSteps(int? min, int? max) async {
    state = state.copyWith(filterMinSteps: min, filterMaxSteps: max);
    await _applyFilters();
  }

  Future<void> setFilterCfg(double? min, double? max) async {
    state = state.copyWith(filterMinCfg: min, filterMaxCfg: max);
    await _applyFilters();
  }

  Future<void> setFilterResolution(String? resolution) async {
    state = state.copyWith(filterResolution: resolution);
    await _applyFilters();
  }

  /// 设置分组视图
  Future<void> setGroupedView(bool value) async {
    state = state.copyWith(isGroupedView: value);
    if (value) {
      await _loadGroupedImages();
    } else {
      await loadPage(state.currentPage);
    }
  }

  Future<void> _loadGroupedImages() async {
    state = state.copyWith(isGroupedLoading: true);
    try {
      final records = await _repo.loadRecords(state.filteredFiles);
      state = state.copyWith(groupedImages: records, isGroupedLoading: false);
    } catch (e) {
      state = state.copyWith(isGroupedLoading: false);
    }
  }

  Future<void> clearAllFilters() async {
    state = state.copyWith(
      searchQuery: '',
      dateStart: null,
      dateEnd: null,
      showFavoritesOnly: false,
      vibeOnly: false,
      selectedTags: [],
      filterModel: null,
      filterSampler: null,
      filterMinSteps: null,
      filterMaxSteps: null,
      filterMinCfg: null,
      filterMaxCfg: null,
      filterResolution: null,
    );
    await _applyFilters();
  }

  /// 应用过滤
  Future<void> _applyFilters() async {
    final query = state.searchQuery.toLowerCase().trim();

    // 无过滤
    if (query.isEmpty &&
        state.dateStart == null &&
        state.dateEnd == null &&
        !state.showFavoritesOnly &&
        state.selectedTags.isEmpty &&
        !_hasMetadataFilters) {
      state = state.copyWith(filteredFiles: state.allFiles, currentPage: 0);
      await loadPage(0);
      return;
    }

    // 有搜索关键词：使用数据库搜索
    if (query.isNotEmpty) {
      try {
        final records = await _repo.advancedSearch(
          textQuery: query,
          favoritesOnly: state.showFavoritesOnly,
          dateStart: state.dateStart,
          dateEnd: state.dateEnd,
          limit: 10000,
        );
        final files = records.map((r) => File(r.path)).toList();
        state = state.copyWith(filteredFiles: files, currentPage: 0);
        await loadPage(0);
        return;
      } catch (e) {
        AppLogger.w('Search failed: $e', 'LocalGalleryNotifier');
      }
    }

    // 回退到本地过滤
    final filtered = state.allFiles.where((file) {
      if (query.isNotEmpty) {
        final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
        if (!name.contains(query)) return false;
      }
      if (state.dateStart != null || state.dateEnd != null) {
        try {
          final modified = file.statSync().modified;
          if (state.dateStart != null && modified.isBefore(state.dateStart!)) return false;
          if (state.dateEnd != null && modified.isAfter(state.dateEnd!.add(const Duration(days: 1)))) return false;
        } catch (_) {
          return false;
        }
      }
      return true;
    }).toList();

    state = state.copyWith(filteredFiles: filtered, currentPage: 0);
    await loadPage(0);
  }

  bool get _hasMetadataFilters =>
      state.filterModel != null ||
      state.filterSampler != null ||
      state.filterMinSteps != null ||
      state.filterMaxSteps != null ||
      state.filterMinCfg != null ||
      state.filterMaxCfg != null ||
      state.filterResolution != null;

  // ============================================================
  // 收藏
  // ============================================================

  Future<void> toggleFavorite(String filePath) async {
    try {
      await _repo.toggleFavorite(filePath);
      await loadPage(state.currentPage);
    } catch (e) {
      AppLogger.e('Toggle favorite failed', e, null, 'LocalGalleryNotifier');
    }
  }

  int getTotalFavoriteCount() => _repo.getTotalFavoriteCount();

  // ============================================================
  // 标签
  // ============================================================

  List<String> getTags(String filePath) => _repo.getTags(filePath);

  Future<void> setTags(String filePath, List<String> tags) async {
    await _repo.setTags(filePath, tags);
    await loadPage(state.currentPage);
  }
}
