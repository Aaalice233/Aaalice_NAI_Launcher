import 'dart:async';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/gallery_cache_manager.dart';
import '../../core/exceptions/gallery_exceptions.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../core/database/datasources/gallery_data_source.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/gallery/gallery_filter_service.dart';
import '../../data/services/gallery/gallery_stream_scanner.dart';
import '../../data/services/gallery/scan_state_manager.dart';
import '../../data/services/gallery/unified_gallery_service.dart';

part 'local_gallery_provider.freezed.dart';
part 'local_gallery_provider.g.dart';

/// 本地画廊状态
@freezed
class LocalGalleryState with _$LocalGalleryState {
  const factory LocalGalleryState({
    /// 当前页显示的记录
    @Default([]) List<LocalImageRecord> currentImages,
    @Default(0) int currentPage,
    @Default(50) int pageSize,
    @Default(false) bool isLoading,
    @Default(false) bool isIndexing,
    @Default(false) bool isPageLoading,

    /// 过滤条件
    @Default(FilterCriteria()) FilterCriteria filterCriteria,

    /// 分组视图
    @Default(false) bool isGroupedView,
    @Default([]) List<LocalImageRecord> groupedImages,
    @Default(false) bool isGroupedLoading,

    /// 后台扫描进度（0-100，null表示未开始）
    double? backgroundScanProgress,

    /// 扫描阶段
    String? scanPhase,

    /// 当前扫描的文件
    String? scanningFile,

    /// 已扫描文件数
    @Default(0) int scannedCount,

    /// 总文件数
    @Default(0) int totalScanCount,

    /// 是否正在重建索引
    @Default(false) bool isRebuildingIndex,

    /// 错误信息
    String? error,

    /// 首次索引提示信息
    String? firstTimeIndexMessage,

    /// 过滤后的总数
    @Default(0) int filteredCount,

    /// 所有文件总数
    @Default(0) int totalCount,

    /// 总页数
    @Default(0) int totalPages,

    /// 是否已初始化
    @Default(false) bool isInitialized,
  }) = _LocalGalleryState;

  const LocalGalleryState._();

  /// 是否有过滤条件
  bool get hasFilters => filterCriteria.hasFilters;

  /// 是否可以加载更多
  bool get canLoadMore => currentPage < totalPages - 1;

  /// 所有文件列表（兼容旧代码）
  List<LocalImageRecord> get allFiles => currentImages;

  /// 过滤后的文件列表（兼容旧代码）
  List<LocalImageRecord> get filteredFiles => currentImages;

  /// 是否是第一页
  bool get isFirstPage => currentPage == 0;

  /// 是否是最后一页
  bool get isLastPage => currentPage >= totalPages - 1;
}

/// 本地画廊 Notifier（使用统一服务层）
///
/// 职责：
/// 1. 管理 UI 状态
/// 2. 调用统一服务层执行业务逻辑
/// 3. 处理错误并转换为友好的错误消息
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  LocalGalleryState? _cachedState;
  LocalGalleryService? _service;

  @override
  LocalGalleryState build() {
    if (_cachedState != null) return _cachedState!;

    // 监听缓存清理事件
    GalleryCacheManager().registerOnCacheCleared(_resetState);
    ref.onDispose(() {
      GalleryCacheManager().unregisterOnCacheCleared(_resetState);
    });

    return const LocalGalleryState();
  }

  void _setState(LocalGalleryState newState) {
    _cachedState = newState;
    state = newState;
  }

  void _resetState() {
    _cachedState = null;
    _service = null;
    _setState(const LocalGalleryState());
  }

  /// 获取服务实例
  ///
  /// 延迟初始化，确保在调用时才获取
  Future<LocalGalleryService> _getService() async {
    if (_service == null) {
      // 等待服务初始化完成（最多10秒）
      var attempts = 0;
      const maxAttempts = 100; // 100 * 100ms = 10秒
      LocalGalleryService? lastService;
      while (attempts < maxAttempts) {
        final service = ref.read(galleryServiceProvider);
        lastService = service;

        // 【调试】记录服务类型变化
        if (attempts % 10 == 0) {
          AppLogger.d(
            'Waiting for gallery service: attempt=$attempts, type=${service.runtimeType}, isInitialized=${service.isInitialized}',
            'LocalGalleryNotifier',
          );
        }

        // 检查是否是错误状态的服务
        if (service is ErrorGalleryService) {
          throw GalleryDatabaseException(message: '画廊服务初始化失败: ${service.error}');
        }

        // 使用 isInitialized 检查服务是否已初始化
        if (service.isInitialized) {
          _service = service;
          AppLogger.d(
            'Gallery service ready after $attempts attempts, type=${service.runtimeType}',
            'LocalGalleryNotifier',
          );
          break;
        }
        // 等待后重试
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_service == null) {
        final typeInfo = lastService != null ? ' (last type: ${lastService.runtimeType})' : '';
        throw GalleryDatabaseException(message: '画廊服务初始化超时$typeInfo');
      }
    }
    return _service!;
  }

  // ============================================================
  // 初始化
  // ============================================================

  /// 初始化画廊
  ///
  /// 1. 初始化服务
  /// 2. 加载首页数据
  /// 3. 在后台执行索引扫描
  Future<void> initialize() async {
    // 检查是否需要初始化
    if (state.isInitialized && !state.error.notNullOrEmpty) {
      return;
    }

    _setState(state.copyWith(
      isLoading: true,
      isIndexing: true,
      isPageLoading: true,
      error: null,
    ),);

    try {
      final service = await _getService();

      // 检测是否为首次大量索引
      final totalCount = service.totalCount;
      final filteredCount = service.filteredCount;
      final isServiceInitialized = service.isInitialized;

      // 【调试日志】追踪计数问题
      AppLogger.d(
        'Gallery init: total=$totalCount, filtered=$filteredCount, '
        'isInitialized=$isServiceInitialized, serviceType=${service.runtimeType}',
        'LocalGalleryNotifier',
      );

      String? firstTimeMessage;
      if (totalCount > 10000) {
        firstTimeMessage = '检测到 $totalCount 张图片，首次索引可能需要几分钟，应用仍可正常使用';
      }

      _setState(state.copyWith(
        totalCount: totalCount,
        filteredCount: service.filteredCount,
        firstTimeIndexMessage: firstTimeMessage,
        isLoading: false,
        isInitialized: true,
      ),);

      // 加载首页
      await loadPage(0);

      // 后台扫描（通过服务层自动处理）
      _setState(state.copyWith(
        isIndexing: false,
        isPageLoading: false,
      ),);
    } on GalleryPermissionDeniedException catch (e) {
      AppLogger.e('Gallery permission denied', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '无法访问图片文件夹，请检查权限设置',
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
      ),);
    } on GalleryScanException catch (e) {
      AppLogger.e('Gallery scan failed', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '扫描图片失败: ${e.message}',
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
      ),);
    } catch (e) {
      AppLogger.e('Failed to initialize gallery', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '初始化失败: $e',
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
      ),);
    }
  }

  // ============================================================
  // 数据加载
  // ============================================================

  /// 加载指定页面
  ///
  /// [page] 页码（从0开始）
  /// [showLoading] 是否显示加载状态
  Future<void> loadPage(int page, {bool showLoading = true}) async {
    if (!state.isInitialized) {
      AppLogger.w('Gallery not initialized, cannot load page', 'LocalGalleryNotifier');
      return;
    }

    if (showLoading) {
      _setState(state.copyWith(isLoading: true, currentPage: page));
    }

    try {
      final service = await _getService();
      final records = await service.getPage(page, pageSize: state.pageSize);

      // 计算总页数
      final totalItems = state.filterCriteria.hasFilters
          ? service.filteredCount
          : service.totalCount;
      final totalPages = (totalItems / state.pageSize).ceil();

      _setState(state.copyWith(
        currentImages: records,
        currentPage: page,
        totalPages: totalPages,
        filteredCount: service.filteredCount,
        totalCount: service.totalCount,
        isLoading: false,
        isPageLoading: false,
      ),);
    } on GalleryNotInitializedException {
      _setState(state.copyWith(
        error: '画廊服务正在初始化，请稍后再试',
        isLoading: false,
        isPageLoading: false,
      ),);
    } on GalleryDatabaseException catch (e) {
      AppLogger.e('Database error loading page', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '数据库错误: ${e.message}',
        isLoading: false,
        isPageLoading: false,
      ),);
    } catch (e) {
      AppLogger.e('Failed to load page $page', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        isLoading: false,
        isPageLoading: false,
      ),);
    }
  }

  /// 加载下一页
  Future<void> loadNextPage() async {
    if (state.isLastPage || state.isLoading) return;
    await loadPage(state.currentPage + 1);
  }

  /// 加载上一页
  Future<void> loadPreviousPage() async {
    if (state.isFirstPage || state.isLoading) return;
    await loadPage(state.currentPage - 1);
  }

  /// 刷新画廊
  ///
  /// 执行增量扫描，更新文件列表和索引
  Future<void> refresh() async {
    if (!state.isInitialized) {
      await initialize();
      return;
    }

    _setState(state.copyWith(isLoading: true));

    try {
      final service = await _getService();
      await service.refresh();

      // 重新应用当前过滤
      await service.applyFilter(state.filterCriteria);

      _setState(state.copyWith(
        totalCount: service.totalCount,
        filteredCount: service.filteredCount,
        isLoading: false,
      ),);

      // 刷新当前页
      await loadPage(state.currentPage, showLoading: false);
    } on GalleryScanException catch (e) {
      _setState(state.copyWith(
        error: '刷新失败: ${e.message}',
        isLoading: false,
      ),);
    } catch (e) {
      _setState(state.copyWith(
        error: '刷新失败: $e',
        isLoading: false,
      ),);
    }
  }

  /// 添加新生成的图像到画廊（即时显示优化）
  ///
  /// 用于图像生成后即时显示新保存的图像，不触发全量扫描
  /// 
  /// [filePaths] 新图像的文件路径列表
  /// 
  /// 返回成功添加的图像数量
  Future<int> addNewlySavedImages(List<String> filePaths) async {
    if (!state.isInitialized || filePaths.isEmpty) {
      return 0;
    }

    var addedCount = 0;
    
    try {
      final service = await _getService();
      
      for (final filePath in filePaths) {
        // 尝试即时添加新图像（不等待扫描）
        final success = await service.addNewImageImmediately(filePath);
        if (success) {
          addedCount++;
        }
      }
      
      if (addedCount > 0) {
        AppLogger.i('[AddNewImages] Added $addedCount new images immediately', 'LocalGalleryNotifier');
        
        // 更新状态计数
        _setState(state.copyWith(
          totalCount: service.totalCount,
          filteredCount: service.filteredCount,
        ),);
        
        // 如果在第一页，刷新显示以包含新图像
        if (state.currentPage == 0) {
          await loadPage(0, showLoading: false);
        }
      }
    } catch (e) {
      AppLogger.e('[AddNewImages] Failed to add new images', e, null, 'LocalGalleryNotifier');
    }
    
    return addedCount;
  }

  // ============================================================
  // 过滤和搜索
  // ============================================================

  Future<void> setSearchQuery(String query) async {
    final criteria = state.filterCriteria;
    if (criteria.searchQuery == query) return;

    _setState(state.copyWith(
      filterCriteria: criteria.copyWith(searchQuery: query),
      currentPage: 0,
    ),);

    await _applyFilters();
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    final criteria = state.filterCriteria;
    if (criteria.dateStart == start && criteria.dateEnd == end) return;

    _setState(state.copyWith(
      filterCriteria: criteria.copyWith(
        dateStart: start,
        dateEnd: end,
      ),
      currentPage: 0,
    ),);

    await _applyFilters();
  }

  Future<void> setShowFavoritesOnly(bool value) async {
    final criteria = state.filterCriteria;
    if (criteria.showFavoritesOnly == value) return;

    _setState(state.copyWith(
      filterCriteria: criteria.copyWith(showFavoritesOnly: value),
      currentPage: 0,
    ),);

    await _applyFilters();
  }

  Future<void> setPageSize(int size) async {
    if (state.pageSize == size) return;

    _setState(state.copyWith(
      pageSize: size,
      currentPage: 0,
    ),);

    // 更新服务层的分页大小
    try {
      final service = await _getService();
      await service.setPageSize(size);
    } catch (_) {}

    await loadPage(0);
  }

  Future<void> setFilterModel(String? model) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterModel: model,
        clearFilterModel: model == null,
      ),
      currentPage: 0,
    ),);
    await _applyFilters();
  }

  Future<void> setFilterSampler(String? sampler) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterSampler: sampler,
        clearFilterSampler: sampler == null,
      ),
      currentPage: 0,
    ),);
    await _applyFilters();
  }

  Future<void> setFilterSteps(int? min, int? max) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterMinSteps: min,
        filterMaxSteps: max,
        clearFilterMinSteps: min == null,
        clearFilterMaxSteps: max == null,
      ),
      currentPage: 0,
    ),);
    await _applyFilters();
  }

  Future<void> setFilterCfg(double? min, double? max) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterMinCfg: min,
        filterMaxCfg: max,
        clearFilterMinCfg: min == null,
        clearFilterMaxCfg: max == null,
      ),
      currentPage: 0,
    ),);
    await _applyFilters();
  }

  Future<void> setFilterResolution(String? resolution) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterResolution: resolution,
        clearFilterResolution: resolution == null,
      ),
      currentPage: 0,
    ),);
    await _applyFilters();
  }

  /// 设置分组视图
  Future<void> setGroupedView(bool value) async {
    _setState(state.copyWith(isGroupedView: value));
    if (value) {
      await _loadGroupedImages();
    } else {
      await _applyFilters();
    }
  }

  Future<void> _loadGroupedImages() async {
    _setState(state.copyWith(isGroupedLoading: true));
    try {
      // 加载所有过滤后的图片用于分组
      final service = await _getService();
      final allRecords = <LocalImageRecord>[];

      // 分批加载所有图片
      const batchSize = 100;
      int page = 0;
      while (true) {
        final records = await service.getPage(page, pageSize: batchSize);
        if (records.isEmpty) break;
        allRecords.addAll(records);
        if (records.length < batchSize) break;
        page++;
      }

      _setState(state.copyWith(
        groupedImages: allRecords,
        isGroupedLoading: false,
      ),);
    } catch (e) {
      AppLogger.e('Failed to load grouped images', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(isGroupedLoading: false));
    }
  }

  Future<void> clearAllFilters() async {
    _setState(state.copyWith(
      filterCriteria: const FilterCriteria(),
      currentPage: 0,
    ),);
    await _applyFilters();
  }

  /// 应用过滤条件
  Future<void> _applyFilters() async {
    try {
      final service = await _getService();
      final criteria = state.filterCriteria;

      // 【调试】记录过滤条件详情
      AppLogger.d(
        'Applying filters: hasFilters=${criteria.hasFilters}, search="${criteria.searchQuery}", '
        'dateStart=${criteria.dateStart}, dateEnd=${criteria.dateEnd}, favOnly=${criteria.showFavoritesOnly}, '
        'tags=${criteria.selectedTags}, model=${criteria.filterModel}, sampler=${criteria.filterSampler}, '
        'steps=${criteria.filterMinSteps}-${criteria.filterMaxSteps}, cfg=${criteria.filterMinCfg}-${criteria.filterMaxCfg}, '
        'res=${criteria.filterResolution}, width=${criteria.minWidth}-${criteria.maxWidth}, '
        'height=${criteria.minHeight}-${criteria.maxHeight}, fileSize=${criteria.minFileSize}-${criteria.maxFileSize}, '
        'metaStatuses=${criteria.metadataStatuses}',
        'LocalGalleryNotifier',
      );

      await service.applyFilter(criteria);

      // 【调试】记录过滤结果
      AppLogger.d(
        'Filter result: total=${service.totalCount}, filtered=${service.filteredCount}, '
        'currentFilter=${service.currentFilter.hasFilters}',
        'LocalGalleryNotifier',
      );

      _setState(state.copyWith(
        filteredCount: service.filteredCount,
        totalCount: service.totalCount,
      ),);

      if (state.isGroupedView) {
        await _loadGroupedImages();
      } else {
        await loadPage(0);
      }
    } on GalleryFilterException catch (e) {
      AppLogger.e('Filter failed', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '过滤失败: ${e.message}',
      ),);
    } catch (e) {
      AppLogger.e('Failed to apply filters', e, null, 'LocalGalleryNotifier');
    }
  }

  // ============================================================
  // 收藏
  // ============================================================

  Future<void> toggleFavorite(String filePath) async {
    try {
      final service = await _getService();
      final isFav = await service.toggleFavorite(filePath);

      // 更新当前页显示
      final updatedImages = state.currentImages.map((record) {
        if (record.path == filePath) {
          return record.copyWith(isFavorite: isFav);
        }
        return record;
      }).toList();

      _setState(state.copyWith(currentImages: updatedImages));

      // 如果启用了收藏过滤，重新应用过滤
      if (state.filterCriteria.showFavoritesOnly && !isFav) {
        await _applyFilters();
      }
    } on GalleryDatabaseException catch (e) {
      AppLogger.e('Toggle favorite failed', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '切换收藏状态失败: ${e.message}',
      ),);
    } catch (e) {
      AppLogger.e('Toggle favorite failed', e, null, 'LocalGalleryNotifier');
    }
  }

  Future<bool> isFavorite(String filePath) async {
    try {
      final service = await _getService();
      return await service.isFavorite(filePath);
    } catch (e) {
      AppLogger.e('Check favorite failed', e, null, 'LocalGalleryNotifier');
      return false;
    }
  }

  Future<int> getTotalFavoriteCount() async {
    try {
      final service = await _getService();
      // 通过过滤收藏项统计
      const favCriteria = FilterCriteria(showFavoritesOnly: true);
      await service.applyFilter(favCriteria);
      final count = service.filteredCount;

      // 恢复原始过滤
      await service.applyFilter(state.filterCriteria);
      return count;
    } catch (e) {
      AppLogger.e('Get favorite count failed', e, null, 'LocalGalleryNotifier');
      return 0;
    }
  }

  // ============================================================
  // 元数据
  // ============================================================

  Future<NaiImageMetadata?> getMetadata(String filePath) async {
    try {
      final service = await _getService();
      return await service.getMetadata(filePath);
    } on GalleryMetadataException catch (e) {
      AppLogger.w('Get metadata failed: ${e.message}', 'LocalGalleryNotifier');
      return null;
    } catch (e) {
      AppLogger.e('Get metadata failed', e, null, 'LocalGalleryNotifier');
      return null;
    }
  }

  // ============================================================
  // 索引管理
  // ============================================================

  bool _shouldCancelRebuild = false;

  /// 重新扫描（全量扫描）
  /// 
  /// 使用统一的流式扫描逻辑：
  /// - 检查数据一致性（标记不存在的文件）
  /// - 查漏补缺（新文件、变更文件）
  /// - 提取元数据
  Future<void> performFullScan() async {
    if (state.isRebuildingIndex) {
      _shouldCancelRebuild = true;
      return;
    }

    // 检查是否已有扫描在进行中
    if (ScanStateManager.instance.isScanning) {
      AppLogger.w('[LocalGallery] Scan already in progress, skipping', 'LocalGalleryNotifier');
      return;
    }

    _shouldCancelRebuild = false;
    _setState(state.copyWith(
      isRebuildingIndex: true,
      isLoading: true,
    ),);

    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null) {
        throw const GalleryScanException(message: '未设置画廊目录');
      }

      final dir = Directory(rootPath);
      if (!dir.existsSync()) {
        throw const GalleryScanException(message: '画廊目录不存在');
      }

      // 使用统一的流式扫描器
      final dataSource = GalleryDataSource();
      final scanner = GalleryStreamScanner(dataSource: dataSource);

      await scanner.startScanning(
        dir,
        onFileProcessed: (result, stats) {
          AppLogger.d(
            '[FullScan] Processed: ${result.path.split(Platform.pathSeparator).last}, '
            'stage: ${result.stage}',
            'LocalGalleryNotifier',
          );
        },
      );

      if (_shouldCancelRebuild) {
        _shouldCancelRebuild = false;
        _setState(state.copyWith(
          isRebuildingIndex: false,
          isLoading: false,
        ),);
        return;
      }

      // 刷新服务状态
      final service = await _getService();

      // 刷新状态
      _setState(state.copyWith(
        totalCount: service.totalCount,
        filteredCount: service.filteredCount,
        isRebuildingIndex: false,
        isLoading: false,
      ),);

      // 刷新当前页
      await loadPage(0, showLoading: false);
    } on GalleryCancelledException {
      _setState(state.copyWith(
        isRebuildingIndex: false,
        isLoading: false,
      ),);
    } on GalleryScanException catch (e) {
      AppLogger.e('Full scan failed', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '扫描失败: ${e.message}',
        isRebuildingIndex: false,
        isLoading: false,
      ),);
    } catch (e) {
      AppLogger.e('Full scan failed', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: '扫描失败: $e',
        isRebuildingIndex: false,
        isLoading: false,
      ),);
    }
  }

  // ============================================================
  // 标签（保持向后兼容）
  // ============================================================

  Future<List<String>> getTags(String filePath) async {
    // 从当前加载的记录中查找
    final record = state.currentImages.firstWhere(
      (r) => r.path == filePath,
      orElse: () => LocalImageRecord(
        path: filePath,
        size: 0,
        modifiedAt: DateTime.now(),
      ),
    );
    return record.tags;
  }

  Future<void> setTags(String filePath, List<String> tags) async {
    // 标签操作通过数据源直接处理
    // 这里只更新本地状态
    final updatedImages = state.currentImages.map((record) {
      if (record.path == filePath) {
        return record.copyWith(tags: tags);
      }
      return record;
    }).toList();

    _setState(state.copyWith(currentImages: updatedImages));
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /// 清除错误状态
  void clearError() {
    _setState(state.copyWith(error: null));
  }
}

/// 扩展方法
extension StringExtension on String? {
  bool get notNullOrEmpty => this != null && this!.isNotEmpty;
}
