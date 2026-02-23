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
import '../../data/services/gallery/gallery_filter_service.dart';
import '../../data/services/gallery/gallery_scan_service.dart';
import '../../data/services/image_metadata_service.dart';
import 'gallery_scan_progress_provider.dart';

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
    @Default(false) bool isIndexing, // 用于兼容旧代码
    @Default(false) bool isPageLoading, // 用于兼容旧代码
    /// 过滤条件
    @Default(FilterCriteria()) FilterCriteria filterCriteria,

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

  bool get hasFilters => filterCriteria.hasFilters;
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
/// - GalleryFilterService: 过滤逻辑
/// - SQLite (via Repository): 唯一数据源
/// - FileWatcherService (via Repository): 自动增量更新
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  /// 缓存的状态，用于在 Provider 重新评估时恢复状态
  LocalGalleryState? _cachedState;

  /// 过滤服务（懒加载）
  GalleryFilterService? _filterService;

  @override
  LocalGalleryState build() {
    // 尝试恢复缓存状态，避免 Provider 重建时重置
    if (_cachedState != null) {
      return _cachedState!;
    }
    return const LocalGalleryState();
  }

  /// 内部方法：更新状态并缓存
  void _setState(LocalGalleryState newState) {
    _cachedState = newState;
    state = newState;
  }

  /// 获取数据源
  ///
  /// 每次都从 provider 获取，确保连接有效
  Future<GalleryDataSource> _getDataSource() async {
    return await ref.read(galleryDataSourceNotifierProvider.future);
  }

  /// 获取过滤服务
  Future<GalleryFilterService> _getFilterService() async {
    if (_filterService == null) {
      final dataSource = await _getDataSource();
      _filterService = GalleryFilterService(dataSource);
    }
    return _filterService!;
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

    _setState(state.copyWith(
      isLoading: true,
      isIndexing: true,
      isPageLoading: true,
      backgroundScanProgress: 0.0,
    ),);

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

      _setState(state.copyWith(
        allFiles: files,
        filteredFiles: files,
        isLoading: false, // 文件列表已显示，可以交互了
        firstTimeIndexMessage: firstTimeMessage,
      ),);

      // 加载首页（显示图片）
      await loadPage(0);

      // 在后台初始化仓库（扫描索引）
      // 这不会阻塞UI，因为文件已经显示了
      unawaited(_initializeInBackground());
    } catch (e) {
      AppLogger.e('Failed to initialize', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        error: e.toString(),
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
        backgroundScanProgress: null,
      ),);
    }
  }

  /// 从文件系统获取所有图片文件
  Future<List<File>> _getAllImageFiles() async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null || rootPath.isEmpty) return [];

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return [];

    var files = <File>[];
    const supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

    try {
      await for (final entity
          in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          // 【修复】排除.thumbs目录中的文件，防止缩略图被当作源文件
          if (entity.path.contains('${Platform.pathSeparator}.thumbs${Platform.pathSeparator}') ||
              entity.path.contains('.thumb.')) {
            continue;
          }

          final ext = entity.path.split('.').last.toLowerCase();
          if (supportedExtensions.contains('.$ext')) {
            files.add(entity);
          }
        }
      }
      // 按修改时间排序（最新的在前）- 使用异步并发获取文件状态
      final fileStats = await Future.wait(
        files.map((file) async {
          try {
            return (file: file, stat: await file.stat());
          } catch (_) {
            return null;
          }
        }),
      );

      final validStats = fileStats.whereType<({File file, FileStat stat})>().toList();
      validStats.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));

      files = validStats.map((e) => e.file).toList();
    } catch (e) {
      AppLogger.e('Failed to get image files', e, null, 'LocalGalleryNotifier');
    }

    return files;
  }

  /// 后台初始化（扫描索引）
  ///
  /// 使用 GalleryScanService 进行流式批量处理，启用缓存机制提高性能
  /// 支持增量扫描：如果数据库已有记录且文件数量匹配，则跳过扫描
  Future<void> _initializeInBackground() async {
    try {
      final allFiles = state.allFiles;

      if (allFiles.isEmpty) {
        _setState(state.copyWith(
          isIndexing: false,
          isPageLoading: false,
          backgroundScanProgress: null,
          scanPhase: null,
        ),);
        return;
      }

      // 【增量扫描优化】检查是否需要完整扫描
      final dataSource = await _getDataSource();
      final existingCount = await dataSource.countImages();

      // 如果数据库已有记录且文件数量匹配，执行快速检查而非完整扫描
      if (existingCount > 0 && existingCount == allFiles.length) {
        AppLogger.i(
          'Database has $existingCount records matching ${allFiles.length} files, performing quick check',
          'LocalGalleryNotifier',
        );

        // 使用增量扫描检测是否有新文件或修改的文件
        final rootPath = await GalleryFolderRepository.instance.getRootPath();
        if (rootPath != null) {
          final scanService = GalleryScanService.instance;
          final dir = Directory(rootPath);

          // 执行增量扫描（只处理新增或修改的文件）
          final result = await scanService.incrementalScan(dir);

          if (result.filesAdded == 0 &&
              result.filesUpdated == 0 &&
              result.filesDeleted == 0) {
            AppLogger.i(
              'Database is up to date, skipping full scan',
              'LocalGalleryNotifier',
            );
            _setState(state.copyWith(
              isIndexing: false,
              isPageLoading: false,
              backgroundScanProgress: null,
              scanPhase: null,
            ),);
            // 静默刷新当前页
            await loadPage(state.currentPage, showLoading: false);
            return;
          }

          AppLogger.i(
            'Incremental scan complete: ${result.filesAdded} added, ${result.filesUpdated} updated, ${result.filesDeleted} deleted',
            'LocalGalleryNotifier',
          );
          _setState(state.copyWith(
            isIndexing: false,
            isPageLoading: false,
          ),);
          await loadPage(state.currentPage, showLoading: false);
          return;
        }
      }

      // 首次初始化或文件数量不匹配，执行完整扫描
      AppLogger.i(
        'Performing full scan: ${allFiles.length} files (existing: $existingCount)',
        'LocalGalleryNotifier',
      );

      // 使用 GalleryScanService 进行批量处理，启用缓存机制
      final scanService = GalleryScanService.instance;
      final filesToScan = allFiles.map((f) => File(f.path)).toList();

      await scanService.processFiles(filesToScan);

      // 完成
      _onScanProgress(
        processed: allFiles.length,
        total: allFiles.length,
        phase: 'completed',
      );

      // 扫描完成后，静默刷新当前页以显示元数据（不显示加载中）
      _setState(state.copyWith(
        isIndexing: false,
        isPageLoading: false,
      ),);
      // 后台刷新，不显示加载状态，避免干扰用户浏览
      await loadPage(state.currentPage, showLoading: false);

      // 延迟清理扫描状态（让用户看到 100% 完成）
      Future.delayed(const Duration(seconds: 2), () {
        if (state.scanPhase == 'completed') {
          _setState(state.copyWith(
            backgroundScanProgress: null,
            scanPhase: null,
            scanningFile: null,
          ),);
        }
      });
    } catch (e) {
      AppLogger.w(
        'Background initialization failed: $e',
        'LocalGalleryNotifier',
      );
      _setState(state.copyWith(
        isIndexing: false,
        isPageLoading: false,
        backgroundScanProgress: null,
        scanPhase: null,
      ),);
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
      _setState(state.copyWith(
        scanPhase: 'pending',
        totalScanCount: total,
        isIndexing: false, // 用户可立即交互
      ),);
      return;
    }

    final progress = total > 0 ? processed / total : 0.0;
    _setState(state.copyWith(
      backgroundScanProgress: progress,
      scanPhase: phase,
      scanningFile: currentFile,
      scannedCount: processed,
      totalScanCount: total,
    ),);

    // 扫描完成时清理状态
    if (phase == 'completed') {
      Future.delayed(const Duration(seconds: 2), () {
        _setState(state.copyWith(
          backgroundScanProgress: null,
          scanPhase: null,
          scanningFile: null,
        ),);
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
      _setState(state.copyWith(currentImages: [], currentPage: 0));
      return;
    }
    if (page < 0 || page >= state.totalPages) return;

    if (showLoading) {
      _setState(state.copyWith(isLoading: true, currentPage: page));
    }
    try {
      final start = page * state.pageSize;
      final end = min(start + state.pageSize, state.filteredFiles.length);
      final batch = state.filteredFiles.sublist(start, end);

      final records = await _loadRecords(batch);
      _setState(state.copyWith(currentImages: records, isLoading: false));
    } catch (e) {
      AppLogger.e('Failed to load page', e, null, 'LocalGalleryNotifier');
      _setState(state.copyWith(
        isLoading: false,
        isIndexing: false,
        isPageLoading: false,
      ),);
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
    _setState(state.copyWith(isLoading: true));
    try {
      final files = await _getAllImageFiles();
      _setState(state.copyWith(allFiles: files, isLoading: false));
      await _applyFilters();

      // 后台扫描新文件的元数据
      unawaited(_scanNewFilesForMetadata(files));
    } catch (e) {
      _setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  /// 后台扫描新文件的元数据
  Future<void> _scanNewFilesForMetadata(List<File> files) async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null) return;

      final scanService = GalleryScanService.instance;
      final progressNotifier = ref.read(galleryScanProgressProvider.notifier);

      // 创建进度回调
      final progressCallback = createScanProgressCallback(progressNotifier);

      await scanService.processFiles(
        files,
        onProgress: progressCallback,
      );

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
    _setState(state.copyWith(isRebuildingIndex: true, isLoading: true));

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
        _setState(state.copyWith(
          isLoading: false,
          isRebuildingIndex: false,
        ),);
        return null;
      }

      final files = await _getAllImageFiles();
      _setState(state.copyWith(
        allFiles: files,
        isLoading: false,
        isRebuildingIndex: false,
      ),);
      await _applyFilters();

      return ScanResult(
        totalFiles: total,
        newFiles: newFiles,
        updatedFiles: updatedFiles,
        failedFiles: failedFiles,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      _setState(state.copyWith(
        error: e.toString(),
        isLoading: false,
        isRebuildingIndex: false,
      ),);
      return null;
    }
  }

  // ============================================================
  // 搜索和过滤（使用 GalleryFilterService）
  // ============================================================

  Future<void> setSearchQuery(String query) async {
    final criteria = state.filterCriteria;
    if (criteria.searchQuery == query) return;
    _setState(state.copyWith(
      filterCriteria: criteria.copyWith(searchQuery: query),
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
    ),);
    await _applyFilters();
  }

  Future<void> setShowFavoritesOnly(bool value) async {
    final criteria = state.filterCriteria;
    if (criteria.showFavoritesOnly == value) return;
    _setState(state.copyWith(
      filterCriteria: criteria.copyWith(showFavoritesOnly: value),
    ),);
    await _applyFilters();
  }

  Future<void> setPageSize(int size) async {
    if (state.pageSize == size) return;
    _setState(state.copyWith(pageSize: size, currentPage: 0));
    await loadPage(0);
  }

  Future<void> setFilterModel(String? model) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterModel: model,
        clearFilterModel: model == null,
      ),
    ),);
    await _applyFilters();
  }

  Future<void> setFilterSampler(String? sampler) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterSampler: sampler,
        clearFilterSampler: sampler == null,
      ),
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
    ),);
    await _applyFilters();
  }

  Future<void> setFilterResolution(String? resolution) async {
    _setState(state.copyWith(
      filterCriteria: state.filterCriteria.copyWith(
        filterResolution: resolution,
        clearFilterResolution: resolution == null,
      ),
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
      final records = await _loadRecords(state.filteredFiles);
      _setState(state.copyWith(groupedImages: records, isGroupedLoading: false));
    } catch (e) {
      _setState(state.copyWith(isGroupedLoading: false));
    }
  }

  Future<void> clearAllFilters() async {
    _setState(state.copyWith(filterCriteria: const FilterCriteria()));
    await _applyFilters();
  }

  /// 应用过滤（使用 GalleryFilterService）
  Future<void> _applyFilters() async {
    final criteria = state.filterCriteria;

    // 无过滤
    if (!criteria.hasFilters) {
      _setState(state.copyWith(filteredFiles: state.allFiles, currentPage: 0));
      await loadPage(0);
      return;
    }

    // 使用过滤服务
    final filterService = await _getFilterService();
    final filtered = await filterService.applyFilters(
      state.allFiles,
      criteria,
    );

    _setState(state.copyWith(filteredFiles: filtered, currentPage: 0));

    // 如果在分组视图下，重新加载分组图片
    if (state.isGroupedView) {
      await _loadGroupedImages();
    } else {
      await loadPage(0);
    }
  }

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
      _setState(state.copyWith(currentImages: updatedCurrentImages));

      // 如果启用了收藏过滤，重新应用过滤以更新列表
      if (state.filterCriteria.showFavoritesOnly) {
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
