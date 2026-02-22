import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database_providers.dart';
import '../../core/database/datasources/gallery_data_source.dart'
    hide MetadataStatus;
import '../../core/database/providers/database_state_providers.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/gallery/gallery_scan_service.dart';
import '../../data/services/image_metadata_service.dart';

part 'local_gallery_provider.freezed.dart';
part 'local_gallery_provider.g.dart';

/// 扫描结果
class ScanResult {
  final int totalFiles;
  final int newFiles;
  final int updatedFiles;
  final int failedFiles;
  final Duration duration;

  const ScanResult({
    required this.totalFiles,
    required this.newFiles,
    required this.updatedFiles,
    required this.failedFiles,
    required this.duration,
  });
}

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
    @Default(false) bool isIndexing, // 用于兼容旧代码
    @Default(false) bool isPageLoading, // 用于兼容旧代码
    /// 搜索关键词
    @Default('') String searchQuery,

    /// 日期过滤
    DateTime? dateStart,
    DateTime? dateEnd,

    /// 收藏过滤
    @Default(false) bool showFavoritesOnly,

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

    /// 首次索引提示信息
    String? firstTimeIndexMessage,
  }) = _LocalGalleryState;

  const LocalGalleryState._();

  int get totalPages =>
      filteredFiles.isEmpty ? 0 : (filteredFiles.length / pageSize).ceil();

  /// 兼容旧代码的 getter
  int get filteredCount => filteredFiles.length;
  int get totalCount => allFiles.length;

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
}

/// GalleryDataSource Provider
///
/// 使用新的数据源架构，从 DatabaseManager 获取 GalleryDataSource
@Riverpod(keepAlive: true)
class GalleryDataSourceNotifier extends _$GalleryDataSourceNotifier {
  @override
  Future<GalleryDataSource> build() async {
    final dbManager = await ref.watch(databaseManagerProvider.future);
    final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');
    if (dataSource == null) {
      throw StateError('GalleryDataSource not found');
    }
    return dataSource;
  }
}

/// 本地画廊 Notifier（使用新数据源架构）
///
/// 依赖关系：
/// - GalleryDataSource: 新的数据源（收藏、标签操作）
/// - GalleryFolderRepository: 文件系统操作
/// - SQLite (via Repository): 唯一数据源
/// - FileWatcherService (via Repository): 自动增量更新
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  @override
  LocalGalleryState build() {
    return const LocalGalleryState();
  }

  /// 获取数据源
  ///
  /// 每次都从 provider 获取，确保连接有效
  Future<GalleryDataSource> _getDataSource() async {
    return await ref.read(galleryDataSourceNotifierProvider.future);
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
      final files = await _getAllImageFiles();

      // 检测是否为首次大量索引
      String? firstTimeMessage;
      if (files.length > 10000) {
        firstTimeMessage = '检测到 ${files.length} 张图片，首次索引可能需要几分钟，应用仍可正常使用';
        AppLogger.i(firstTimeMessage, 'LocalGalleryNotifier');
      }

      state = state.copyWith(
        allFiles: files,
        filteredFiles: files,
        isLoading: false, // 文件列表已显示，可以交互了
        firstTimeIndexMessage: firstTimeMessage,
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

  /// 从文件系统获取所有图片文件
  Future<List<File>> _getAllImageFiles() async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null || rootPath.isEmpty) return [];

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return [];

    final files = <File>[];
    const supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

    try {
      await for (final entity
          in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (supportedExtensions.contains('.$ext')) {
            files.add(entity);
          }
        }
      }
      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        try {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        } catch (_) {
          return 0;
        }
      });
    } catch (e) {
      AppLogger.e('Failed to get image files', e, null, 'LocalGalleryNotifier');
    }

    return files;
  }

  /// 后台初始化（扫描索引）
  Future<void> _initializeInBackground() async {
    try {
      final allFiles = state.allFiles;

      if (allFiles.isEmpty) {
        state = state.copyWith(
          isIndexing: false,
          isPageLoading: false,
          backgroundScanProgress: null,
          scanPhase: null,
        );
        return;
      }

      // 模拟进度更新
      const batchSize = 100;
      final total = allFiles.length;
      var processed = 0;

      for (var i = 0; i < total; i += batchSize) {
        final end = (i + batchSize < total) ? i + batchSize : total;
        final batch = allFiles.sublist(i, end);

        // 每批处理前重新获取数据源，确保连接有效
        final batchDataSource = await _getDataSource();

        // 处理每个文件
        for (final file in batch) {
          try {
            final stat = await file.stat();
            final fileName = file.path.split(Platform.pathSeparator).last;

            // 插入或更新图片记录
            await batchDataSource.upsertImage(
              filePath: file.path,
              fileName: fileName,
              fileSize: stat.size,
              createdAt: stat.changed,
              modifiedAt: stat.modified,
            );
          } catch (e) {
            AppLogger.w(
              'Failed to index file: ${file.path}',
              'LocalGalleryNotifier',
            );
          }
        }

        processed += batch.length;
        _onScanProgress(
          processed: processed,
          total: total,
          currentFile: batch.last.path.split(Platform.pathSeparator).last,
          phase: 'indexing',
        );

        // 让出时间片，避免阻塞UI
        await Future.delayed(Duration.zero);
      }

      // 完成
      _onScanProgress(
        processed: total,
        total: total,
        phase: 'completed',
      );

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
      AppLogger.w(
        'Background initialization failed: $e',
        'LocalGalleryNotifier',
      );
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

      final records = await _loadRecords(batch);
      state = state.copyWith(currentImages: records, isLoading: false);
    } catch (e) {
      AppLogger.e('Failed to load page', e, null, 'LocalGalleryNotifier');
      state = state.copyWith(
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
      );
    }
  }

  /// 从文件列表加载记录
  ///
  /// 使用批量查询方法，将每页的查询次数从 200+ 减少到 ~4 次：
  /// 1. 批量获取图片ID（通过文件路径）
  /// 2. 批量获取收藏状态
  /// 3. 批量获取标签
  /// 4. 批量获取元数据
  Future<List<LocalImageRecord>> _loadRecords(List<File> files) async {
    final dataSource = await _getDataSource();

    // 预加载所有图片的元数据到缓存（后台执行，不阻塞）
    _preloadMetadataBatch(files);

    // 获取文件状态信息
    final fileStats = <File, FileStat>{};
    for (final file in files) {
      try {
        fileStats[file] = await file.stat();
      } catch (e) {
        AppLogger.w(
          'Failed to stat file: ${file.path}',
          'LocalGalleryNotifier',
        );
      }
    }

    // 1. 批量获取图片ID（1次查询）
    final paths = files.map((f) => f.path).toList();
    final pathToIdMap = await dataSource.getImageIdsByPaths(paths);

    // 收集有效的图片ID
    final imageIds = <int>[];
    for (final entry in pathToIdMap.entries) {
      final id = entry.value;
      if (id != null) {
        imageIds.add(id);
      }
    }

    // 2-4. 批量获取收藏状态、标签和元数据（并行执行，共3次查询）
    final results = await Future.wait([
      dataSource.getFavoritesByImageIds(imageIds),
      dataSource.getTagsByImageIds(imageIds),
      dataSource.getMetadataByImageIds(imageIds),
    ]);
    final favoritesMap = results[0] as Map<int, bool>;
    final tagsMap = results[1] as Map<int, List<String>>;
    final metadataMap = results[2] as Map<int, GalleryMetadataRecord?>;

    // 构建记录列表
    final records = <LocalImageRecord>[];

    for (final file in files) {
      try {
        final stat = fileStats[file];
        if (stat == null) continue;

        final imageId = pathToIdMap[file.path];

        bool isFavorite = false;
        List<String> tags = [];
        NaiImageMetadata? metadata;
        MetadataStatus metadataStatus = MetadataStatus.none;

        if (imageId != null) {
          // 从批量查询结果中获取数据
          isFavorite = favoritesMap[imageId] ?? false;
          tags = tagsMap[imageId] ?? [];

          // 处理元数据
          final metadataRecord = metadataMap[imageId];
          if (metadataRecord != null) {
            // 如果有 rawJson，从中重新解析完整的元数据（包含新字段）
            if (metadataRecord.rawJson != null &&
                metadataRecord.rawJson!.isNotEmpty) {
              try {
                final json =
                    jsonDecode(metadataRecord.rawJson!) as Map<String, dynamic>;
                metadata = NaiImageMetadata.fromNaiComment(
                  json,
                  rawJson: metadataRecord.rawJson,
                );
              } catch (e) {
                AppLogger.w(
                  'Failed to parse rawJson for $imageId, using basic metadata',
                  'LocalGalleryNotifier',
                );
                // 回退到基本元数据
                metadata = _buildBasicMetadata(metadataRecord);
              }
            } else {
              // 没有 rawJson，使用基本元数据
              metadata = _buildBasicMetadata(metadataRecord);
            }
            metadataStatus =
                metadata.hasData ? MetadataStatus.success : MetadataStatus.none;
          }
        }

        records.add(
          LocalImageRecord(
            path: file.path,
            size: stat.size,
            modifiedAt: stat.modified,
            isFavorite: isFavorite,
            tags: tags,
            metadata: metadata,
            metadataStatus: metadataStatus,
          ),
        );
      } catch (e) {
        AppLogger.w(
          'Failed to load record for ${file.path}',
          'LocalGalleryNotifier',
        );
        // 使用基本信息创建记录
        records.add(
          LocalImageRecord(
            path: file.path,
            size: 0,
            modifiedAt: DateTime.now(),
          ),
        );
      }
    }

    return records;
  }

  /// 批量预加载元数据到缓存（后台执行，不阻塞UI）
  void _preloadMetadataBatch(List<File> files) {
    // 筛选出PNG文件
    final pngFiles =
        files.where((f) => f.path.toLowerCase().endsWith('.png')).toList();
    if (pngFiles.isEmpty) return;

    // 后台预加载，不等待结果
    Future.microtask(() {
      try {
        final images = pngFiles
            .map((f) => GeneratedImageInfo(id: f.path, filePath: f.path))
            .toList();
        ImageMetadataService().preloadBatch(images);
      } catch (e) {
        AppLogger.w(
          'Failed to preload metadata batch: $e',
          'LocalGalleryNotifier',
        );
      }
    });
  }

  /// 从 GalleryMetadataRecord 构建基本元数据（不包含新字段）
  NaiImageMetadata _buildBasicMetadata(GalleryMetadataRecord record) {
    return NaiImageMetadata(
      prompt: record.prompt,
      negativePrompt: record.negativePrompt,
      seed: record.seed,
      sampler: record.sampler,
      steps: record.steps,
      scale: record.scale,
      width: record.width,
      height: record.height,
      model: record.model,
      smea: record.smea,
      smeaDyn: record.smeaDyn,
      noiseSchedule: record.noiseSchedule,
      cfgRescale: record.cfgRescale,
      ucPreset: record.ucPreset,
      qualityToggle: record.qualityToggle,
      isImg2Img: record.isImg2Img,
      strength: record.strength,
      noise: record.noise,
      software: record.software,
      source: record.source,
      version: record.version,
      rawJson: record.rawJson,
    );
  }

  /// 刷新（增量扫描）
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final files = await _getAllImageFiles();
      state = state.copyWith(allFiles: files, isLoading: false);
      await _applyFilters();

      // 后台扫描新文件的元数据
      unawaited(_scanNewFilesForMetadata(files));
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// 后台扫描新文件的元数据
  Future<void> _scanNewFilesForMetadata(List<File> files) async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null) return;

      final scanService = GalleryScanService.instance;
      await scanService.processFiles(files);

      // 扫描完成后刷新当前页以显示元数据
      await loadPage(state.currentPage, showLoading: false);
    } catch (e) {
      AppLogger.w(
        'Failed to scan new files for metadata: $e',
        'LocalGalleryNotifier',
      );
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
      final dataSource = await _getDataSource();
      final allFiles = state.allFiles;
      final total = allFiles.length;
      var processed = 0;
      var newFiles = 0;
      var updatedFiles = 0;
      var failedFiles = 0;
      final stopwatch = Stopwatch()..start();

      const batchSize = 100;
      for (var i = 0; i < total; i += batchSize) {
        if (_shouldCancelRebuild) {
          break;
        }

        final end = (i + batchSize < total) ? i + batchSize : total;
        final batch = allFiles.sublist(i, end);

        for (final file in batch) {
          try {
            final stat = await file.stat();
            final fileName = file.path.split(Platform.pathSeparator).last;

            // 检查是否已存在
            final existingId = await dataSource.getImageIdByPath(file.path);

            await dataSource.upsertImage(
              filePath: file.path,
              fileName: fileName,
              fileSize: stat.size,
              createdAt: stat.changed,
              modifiedAt: stat.modified,
            );

            if (existingId == null) {
              newFiles++;
            } else {
              updatedFiles++;
            }
          } catch (e) {
            failedFiles++;
          }
        }

        processed += batch.length;
        _onScanProgress(
          processed: processed,
          total: total,
          currentFile: batch.last.path.split(Platform.pathSeparator).last,
          phase: 'indexing',
        );

        // 让出时间片
        await Future.delayed(Duration.zero);
      }

      stopwatch.stop();

      if (_shouldCancelRebuild) {
        AppLogger.i('Rebuild index cancelled by user', 'LocalGalleryNotifier');
        state = state.copyWith(
          isLoading: false,
          isRebuildingIndex: false,
        );
        return null;
      }

      final files = await _getAllImageFiles();
      state = state.copyWith(
        allFiles: files,
        isLoading: false,
        isRebuildingIndex: false,
      );
      await _applyFilters();

      return ScanResult(
        totalFiles: total,
        newFiles: newFiles,
        updatedFiles: updatedFiles,
        failedFiles: failedFiles,
        duration: stopwatch.elapsed,
      );
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
      // 退出分组视图时，重新应用过滤以确保视图正确刷新
      await _applyFilters();
    }
  }

  Future<void> _loadGroupedImages() async {
    state = state.copyWith(isGroupedLoading: true);
    try {
      final records = await _loadRecords(state.filteredFiles);
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
        final dataSource = await _getDataSource();
        final imageIds = await dataSource.advancedSearch(
          textQuery: query,
          favoritesOnly: state.showFavoritesOnly,
          dateStart: state.dateStart,
          dateEnd: state.dateEnd,
          limit: 10000,
        );
        // 获取图片记录并转换为文件列表
        final images = await dataSource.getImagesByIds(imageIds);
        final files = images.map((img) => File(img.filePath)).toList();
        state = state.copyWith(filteredFiles: files, currentPage: 0);
        await loadPage(0);
        return;
      } catch (e) {
        AppLogger.w('Search failed: $e', 'LocalGalleryNotifier');
      }
    }

    // 回退到本地过滤
    var filtered = state.allFiles.where((file) {
      if (query.isNotEmpty) {
        final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
        if (!name.contains(query)) return false;
      }
      if (state.dateStart != null || state.dateEnd != null) {
        try {
          final modified = file.statSync().modified;
          if (state.dateStart != null && modified.isBefore(state.dateStart!)) {
            return false;
          }
          if (state.dateEnd != null &&
              modified.isAfter(state.dateEnd!.add(const Duration(days: 1)))) {
            return false;
          }
        } catch (_) {
          return false;
        }
      }
      return true;
    }).toList();

    // 收藏过滤 - 使用数据库查询获取收藏的图片路径（使用批量方法）
    if (state.showFavoritesOnly) {
      try {
        final dataSource = await _getDataSource();
        final favoriteImageIds = await dataSource.getFavoriteImageIds();
        // 使用批量查询获取所有收藏图片的路径
        final favoriteImages =
            await dataSource.getImagesByIds(favoriteImageIds);
        final favoritePaths = favoriteImages.map((img) => img.filePath).toSet();
        filtered = filtered
            .where((file) => favoritePaths.contains(file.path))
            .toList();
      } catch (e) {
        AppLogger.w('Failed to filter favorites: $e', 'LocalGalleryNotifier');
      }
    }

    state = state.copyWith(filteredFiles: filtered, currentPage: 0);

    // 如果在分组视图下，重新加载分组图片
    if (state.isGroupedView) {
      await _loadGroupedImages();
    } else {
      await loadPage(0);
    }
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
  // 收藏（使用新数据源）
  // ============================================================

  Future<void> toggleFavorite(String filePath) async {
    try {
      final dataSource = await _getDataSource();
      final imageId = await dataSource.getImageIdByPath(filePath);

      if (imageId != null) {
        // 使用新数据源切换收藏状态
        await dataSource.toggleFavorite(imageId);
        AppLogger.d(
          'Toggled favorite for image $imageId via GalleryDataSource',
          'LocalGalleryNotifier',
        );
      } else {
        // 如果图片不在数据库中，先索引它
        AppLogger.w(
          'Image not found in database, indexing first: $filePath',
          'LocalGalleryNotifier',
        );
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          final fileName = filePath.split(Platform.pathSeparator).last;
          final newId = await dataSource.upsertImage(
            filePath: filePath,
            fileName: fileName,
            fileSize: stat.size,
            createdAt: stat.changed,
            modifiedAt: stat.modified,
          );
          await dataSource.toggleFavorite(newId);
        }
      }

      // 更新当前页显示的记录的收藏状态
      final updatedCurrentImages = state.currentImages.map((record) {
        if (record.path == filePath) {
          return record.copyWith(isFavorite: !record.isFavorite);
        }
        return record;
      }).toList();

      // 更新当前页显示
      state = state.copyWith(currentImages: updatedCurrentImages);

      // 如果启用了收藏过滤，重新应用过滤以更新列表
      if (state.showFavoritesOnly) {
        await _applyFilters();
      }
    } catch (e) {
      AppLogger.e('Toggle favorite failed', e, null, 'LocalGalleryNotifier');
    }
  }

  Future<bool> isFavorite(String filePath) async {
    try {
      final dataSource = await _getDataSource();
      final imageId = await dataSource.getImageIdByPath(filePath);

      if (imageId != null) {
        return await dataSource.isFavorite(imageId);
      }

      return false;
    } catch (e) {
      AppLogger.e('Check favorite failed', e, null, 'LocalGalleryNotifier');
      return false;
    }
  }

  Future<int> getTotalFavoriteCount() async {
    // 检查数据库是否正在恢复
    final stateMachine = ref.read(databaseStateMachineProvider);
    if (stateMachine.isTransitioning) {
      AppLogger.d(
        'Database is transitioning, returning cached favorite count (0)',
        'LocalGalleryNotifier',
      );
      return 0;
    }

    try {
      final dataSource = await _getDataSource();
      return await dataSource.getFavoriteCount();
    } catch (e) {
      AppLogger.e('Get favorite count failed', e, null, 'LocalGalleryNotifier');
      return 0;
    }
  }

  // ============================================================
  // 标签（使用新数据源）
  // ============================================================

  Future<List<String>> getTags(String filePath) async {
    try {
      final dataSource = await _getDataSource();
      final imageId = await dataSource.getImageIdByPath(filePath);

      if (imageId != null) {
        // 使用新数据源获取标签
        return await dataSource.getImageTags(imageId);
      }

      return [];
    } catch (e) {
      AppLogger.e('Get tags failed', e, null, 'LocalGalleryNotifier');
      return [];
    }
  }

  Future<void> setTags(String filePath, List<String> tags) async {
    try {
      final dataSource = await _getDataSource();
      var imageId = await dataSource.getImageIdByPath(filePath);

      if (imageId != null) {
        // 使用新数据源设置标签
        await dataSource.setImageTags(imageId, tags);
        AppLogger.d(
          'Set tags for image $imageId via GalleryDataSource',
          'LocalGalleryNotifier',
        );
      } else {
        // 如果图片不在数据库中，先索引它
        AppLogger.w(
          'Image not found in database, indexing first: $filePath',
          'LocalGalleryNotifier',
        );
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          final fileName = filePath.split(Platform.pathSeparator).last;
          imageId = await dataSource.upsertImage(
            filePath: filePath,
            fileName: fileName,
            fileSize: stat.size,
            createdAt: stat.changed,
            modifiedAt: stat.modified,
          );
          await dataSource.setImageTags(imageId, tags);
        }
      }

      await loadPage(state.currentPage);
    } catch (e) {
      AppLogger.e('Set tags failed', e, null, 'LocalGalleryNotifier');
    }
  }
}
