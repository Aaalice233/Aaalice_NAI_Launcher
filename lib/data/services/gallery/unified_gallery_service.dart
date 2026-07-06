import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/database/database.dart';
import '../../../core/exceptions/gallery_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../../repositories/gallery_folder_repository.dart';
import '../image_metadata_service.dart';
import 'gallery_filter_service.dart';
import 'gallery_stream_scanner.dart';
import 'scan_state_manager.dart';
import 'scan_config.dart' show ScanConfig;

part 'unified_gallery_service.g.dart';

String normalizeGalleryFilePath(String filePath) {
  final trimmed = filePath.trim();
  if (!Platform.isWindows) return trimmed;

  var normalized = trimmed.replaceAll('/', r'\');
  if (normalized.startsWith(r'\\?\UNC\')) {
    normalized = r'\\' + normalized.substring(r'\\?\UNC\'.length);
  } else if (normalized.startsWith(r'\\?\')) {
    normalized = normalized.substring(r'\\?\'.length);
  }
  return normalized;
}

String galleryFilePathKey(String filePath) {
  final normalized = normalizeGalleryFilePath(filePath);
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool galleryFilePathsEqual(String left, String right) =>
    galleryFilePathKey(left) == galleryFilePathKey(right);

enum GalleryStartupIndexAction { none, fullScan }

GalleryStartupIndexAction chooseStartupIndexAction({
  required int databaseImageCount,
  required int fileSystemImageCount,
}) {
  if (databaseImageCount > 0 && databaseImageCount == fileSystemImageCount) {
    return GalleryStartupIndexAction.none;
  }
  return GalleryStartupIndexAction.fullScan;
}

bool shouldRunRefreshIndexScan({
  required bool scanRequested,
  required bool isBackgroundScanning,
}) {
  return scanRequested && !isBackgroundScanning;
}

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

/// 画廊服务接口
///
/// 定义了本地画廊模块的核心操作，包括：
/// - 初始化和索引管理
/// - 分页数据获取
/// - 过滤和搜索
/// - 收藏管理
/// - 元数据操作
abstract class LocalGalleryService {
  /// 服务是否已初始化
  bool get isInitialized;

  /// 初始化画廊服务
  ///
  /// 执行以下操作：
  /// 1. 扫描图片文件夹获取文件列表
  /// 2. 建立数据库索引
  /// 3. 加载首页数据
  ///
  /// 返回初始化后的文件列表
  ///
  /// 可能抛出：
  /// - [GalleryPermissionDeniedException] 权限不足
  /// - [GalleryScanException] 扫描失败
  Future<List<File>> initialize();

  /// 获取指定页面的图片记录
  ///
  /// [page] 页码（从0开始）
  /// [pageSize] 每页大小
  ///
  /// 返回该页面的图片记录列表
  ///
  /// 可能抛出：
  /// - [GalleryNotInitializedException] 服务未初始化
  /// - [GalleryDatabaseException] 数据库错误
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize});

  /// 应用过滤条件
  ///
  /// [criteria] 过滤条件
  ///
  /// 可能抛出：
  /// - [GalleryFilterException] 过滤失败
  Future<void> applyFilter(FilterCriteria criteria);

  /// 切换图片收藏状态
  ///
  /// [filePath] 图片文件路径
  ///
  /// 返回切换后的收藏状态
  ///
  /// 可能抛出：
  /// - [GalleryNotInitializedException] 服务未初始化
  /// - [GalleryDatabaseException] 数据库错误
  Future<bool> toggleFavorite(String filePath);

  /// 检查图片是否已收藏
  ///
  /// [filePath] 图片文件路径
  Future<bool> isFavorite(String filePath);

  /// 获取当前画廊文件中的收藏图片数量
  Future<int> getFavoriteCount();

  /// 获取图片元数据
  ///
  /// [filePath] 图片文件路径
  ///
  /// 返回图片的 NAI 元数据，如果没有则返回 null
  ///
  /// 可能抛出：
  /// - [GalleryMetadataException] 元数据解析失败
  Future<NaiImageMetadata?> getMetadata(String filePath);

  /// 刷新画廊数据
  ///
  /// 执行增量扫描，更新文件列表和索引
  ///
  /// 可能抛出：
  /// - [GalleryScanException] 扫描失败
  Future<void> refresh({bool scan = true});

  /// 立即添加新图像到画廊（不触发全量扫描）
  ///
  /// 用于图像生成后即时显示新保存的图像，避免等待全量扫描
  ///
  /// [filePath] 新图像的文件路径
  /// [metadata] 可选的图像元数据
  ///
  /// 返回是否成功添加
  Future<bool> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  });

  /// 获取当前过滤后的文件总数
  int get filteredCount;

  /// 获取所有文件总数
  int get totalCount;

  /// 获取当前过滤条件
  FilterCriteria get currentFilter;

  /// 设置搜索关键词
  Future<void> setSearchQuery(String query);

  /// 设置日期范围过滤
  Future<void> setDateRange(DateTime? start, DateTime? end);

  /// 设置仅显示收藏
  Future<void> setShowFavoritesOnly(bool value);

  /// 设置分页大小
  Future<void> setPageSize(int size);

  /// 清除所有过滤条件
  Future<void> clearFilters();

  /// 关闭服务并释放资源
  Future<void> dispose();

  /// 根据路径列表获取图片记录
  ///
  /// [paths] 图片文件路径列表
  ///
  /// 返回对应的图片记录列表，如果某些路径不存在则跳过
  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths);

  /// 获取当前过滤结果中的所有图片路径。
  ///
  /// 未应用过滤时返回全部图片；应用搜索/筛选后返回筛选结果。
  Future<List<String>> getFilteredImagePaths();
}

/// 画廊服务实现
class LocalGalleryServiceImpl implements LocalGalleryService {
  // 依赖服务
  final GalleryDataSource _dataSource;
  final GalleryFilterService _filterService;

  // 状态
  bool _isInitialized = false;
  List<File> _allFiles = [];
  List<File> _filteredFiles = [];
  FilterCriteria _currentFilter = const FilterCriteria();
  int _filterGeneration = 0;
  String? _activeFilterOperationId;
  int _pageSize = 50;

  LocalGalleryServiceImpl({
    required GalleryDataSource dataSource,
    required GalleryFilterService filterService,
  }) : _dataSource = dataSource,
       _filterService = filterService;

  @override
  bool get isInitialized => _isInitialized;

  List<File> get _effectiveFiles =>
      _currentFilter.hasFilters ? _filteredFiles : _allFiles;

  @override
  int get filteredCount =>
      _currentFilter.hasFilters ? _filteredFiles.length : totalCount;

  @override
  int get totalCount => _allFiles.length;

  @override
  FilterCriteria get currentFilter => _currentFilter;

  String _resolveTrackedFilePath(String filePath) {
    final normalizedPath = normalizeGalleryFilePath(filePath);
    final targetKey = galleryFilePathKey(normalizedPath);
    for (final file in _allFiles) {
      if (galleryFilePathKey(file.path) == targetKey) {
        return file.path;
      }
    }
    return normalizedPath;
  }

  bool _isTrackedFilePath(String filePath) {
    final targetKey = galleryFilePathKey(filePath);
    return _allFiles.any((file) => galleryFilePathKey(file.path) == targetKey);
  }

  void _trackFileIfMissing(File file) {
    if (_isTrackedFilePath(file.path)) return;
    _allFiles.insert(0, file);
  }

  Future<void> _syncFileListsAfterFavoriteChange(File file) async {
    _trackFileIfMissing(file);
    if (_currentFilter.hasFilters) {
      await applyFilter(_currentFilter);
    } else {
      _filteredFiles = _allFiles;
    }
  }

  // ============================================================
  // 初始化
  // ============================================================

  bool _isInitializing = false;
  bool _isBackgroundScanning = false;

  @override
  Future<List<File>> initialize() async {
    // ✅ 防止并发初始化
    if (_isInitializing) {
      AppLogger.d(
        'Gallery initialization already in progress, waiting...',
        'LocalGalleryService',
      );
      // 等待初始化完成
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _allFiles;
    }

    if (_isInitialized && _allFiles.isNotEmpty) {
      return _allFiles;
    }

    _isInitializing = true;

    try {
      // 1. 从文件系统获取所有图片
      final files = await _getAllImageFiles();
      _allFiles = files;

      _filteredFiles = files;

      AppLogger.i(
        'Found ${files.length} image files in file system',
        'LocalGalleryService',
      );

      _isInitialized = true;

      // 2. 后台执行索引初始化（不阻塞）
      _initializeIndexInBackground();

      return files;
    } on GalleryException {
      rethrow;
    } catch (e) {
      throw GalleryScanException(
        message: 'Failed to initialize gallery',
        cause: e,
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// 从文件系统获取所有图片文件
  Future<List<File>> _getAllImageFiles() async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw GalleryPermissionDeniedException(
        path: rootPath,
        message: 'Gallery root path not set',
      );
    }

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      throw GalleryPermissionDeniedException(
        path: rootPath,
        message: 'Gallery folder does not exist: $rootPath',
      );
    }

    var files = <File>[];
    const supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

    // 使用 ScanConfig 的缩略图检测配置
    const scanConfig = ScanConfig();

    try {
      await for (final entity in rootDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          // 排除缩略图目录和文件
          if (scanConfig.isThumbnailPath(entity.path)) {
            continue;
          }

          // 使用 path 包正确提取扩展名，避免多层扩展名问题
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            files.add(entity);
          }
        }
      }

      // 按修改时间排序（最新的在前）
      final fileStats = await Future.wait(
        files.map((file) async {
          try {
            return (file: file, stat: await file.stat());
          } catch (_) {
            return null;
          }
        }),
      );

      final validStats = fileStats
          .whereType<({File file, FileStat stat})>()
          .toList();
      validStats.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));

      files = validStats.map((e) => e.file).toList();
    } catch (e) {
      AppLogger.e('Failed to get image files', e, null, 'LocalGalleryService');
      throw GalleryFileSystemException(
        path: rootPath,
        operation: FileSystemOperation.list,
        message: 'Failed to list image files',
        cause: e,
      );
    }

    return files;
  }

  /// 后台索引初始化
  Future<void> _initializeIndexInBackground() async {
    // ✅ 防止并发后台扫描
    if (_isBackgroundScanning) {
      AppLogger.d(
        'Background scan already in progress, skipping',
        'LocalGalleryService',
      );
      return;
    }

    _isBackgroundScanning = true;
    AppLogger.i(
      'Starting background index initialization',
      'LocalGalleryService',
    );

    try {
      // 检查是否需要完整扫描
      final existingCount = await _dataSource.countImages();
      AppLogger.i(
        'Database has $existingCount images, file system has ${_allFiles.length} images',
        'LocalGalleryService',
      );

      switch (chooseStartupIndexAction(
        databaseImageCount: existingCount,
        fileSystemImageCount: _allFiles.length,
      )) {
        case GalleryStartupIndexAction.none:
          AppLogger.i(
            'Skipping startup metadata scan: database and file system counts match',
            'LocalGalleryService',
          );
        case GalleryStartupIndexAction.fullScan:
          AppLogger.i(
            'Performing startup file index scan (${_allFiles.length} files)',
            'LocalGalleryService',
          );
          await _performFullScan();
      }

      AppLogger.i(
        'Background index initialization completed',
        'LocalGalleryService',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Background index initialization failed',
        e,
        stack,
        'LocalGalleryService',
      );
      // 打印更详细的错误信息
      AppLogger.e(
        'Error details: ${e.toString()}',
        null,
        null,
        'LocalGalleryService',
      );
      AppLogger.e(
        'Stack trace: ${stack.toString()}',
        null,
        null,
        'LocalGalleryService',
      );
      // 后台错误不影响主流程
    } finally {
      _isBackgroundScanning = false;
    }
  }

  /// 执行增量扫描（使用流式逐张处理）
  Future<void> _performIncrementalScan({
    bool retryMissingMetadata = false,
    bool retryFailedMetadata = false,
  }) async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null) {
      AppLogger.w(
        '[UGS] _performIncrementalScan: rootPath is null',
        'LocalGalleryService',
      );
      return;
    }

    // 检查是否已有扫描在进行中
    final scanManager = ScanStateManager.instance;
    AppLogger.i(
      '[UGS] _performIncrementalScan: isScanning=${scanManager.isScanning}, rootPath=$rootPath',
      'LocalGalleryService',
    );

    if (scanManager.isScanning) {
      AppLogger.w('[UGS] 增量扫描请求被忽略：已有扫描在进行中', 'LocalGalleryService');
      return;
    }

    final dir = Directory(rootPath);

    AppLogger.i('[UGS] 开始执行流式扫描', 'LocalGalleryService');

    // 使用新的流式扫描器：真正的单文件流水线
    final scanner = GalleryStreamScanner(dataSource: _dataSource);

    await scanner.startScanning(
      dir,
      retryMissingMetadata: retryMissingMetadata,
      retryFailedMetadata: retryFailedMetadata,
      // 【扫描时日志太频繁，禁用】
      // onFileProcessed: (result, stats) {
      //   // 每处理一个文件就更新状态
      //   AppLogger.d(
      //     '[UGS] File processed: ${result.path.split(Platform.pathSeparator).last}, '
      //     'stage: ${result.stage}, total: ${stats.totalDiscovered}',
      //     'LocalGalleryService',
      //   );
      // },
    );

    AppLogger.i('[UGS] 流式扫描完成', 'LocalGalleryService');
  }

  /// 执行完整扫描
  ///
  /// 使用统一的 GalleryStreamScanner，与增量扫描使用同一套逻辑
  Future<void> _performFullScan({
    bool retryMissingMetadata = false,
    bool retryFailedMetadata = false,
  }) async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null) {
      AppLogger.w(
        '[UGS] _performFullScan: rootPath is null',
        'LocalGalleryService',
      );
      return;
    }

    // 检查是否已有扫描在进行中
    final scanManager = ScanStateManager.instance;
    if (scanManager.isScanning) {
      AppLogger.w('[UGS] 全量扫描请求被忽略：已有扫描在进行中', 'LocalGalleryService');
      return;
    }

    final dir = Directory(rootPath);

    AppLogger.i('[UGS] 开始执行全量流式扫描', 'LocalGalleryService');

    // 使用新的流式扫描器：真正的单文件流水线
    final scanner = GalleryStreamScanner(dataSource: _dataSource);

    await scanner.startScanning(
      dir,
      retryMissingMetadata: retryMissingMetadata,
      retryFailedMetadata: retryFailedMetadata,
      // 【扫描时日志太频繁，禁用】
      // onFileProcessed: (result, stats) {
      //   // 每处理一个文件就更新状态
      //   AppLogger.d(
      //     '[UGS] File processed: ${result.path.split(Platform.pathSeparator).last}, '
      //     'stage: ${result.stage}, total: ${stats.totalDiscovered}',
      //     'LocalGalleryService',
      //   );
      // },
    );

    AppLogger.i('[UGS] 全量流式扫描完成', 'LocalGalleryService');
  }

  // ============================================================
  // 分页获取
  // ============================================================

  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async {
    _ensureInitialized();

    final effectivePageSize = pageSize ?? _pageSize;
    final totalPages = (_effectiveFiles.length / effectivePageSize).ceil();

    if (page < 0 || (totalPages > 0 && page >= totalPages)) {
      return [];
    }

    final start = page * effectivePageSize;
    final end = min(start + effectivePageSize, _effectiveFiles.length);
    final batch = _effectiveFiles.sublist(start, end);

    return _loadRecords(batch);
  }

  @override
  Future<List<String>> getFilteredImagePaths() async {
    _ensureInitialized();

    return _effectiveFiles.map((file) => file.path).toList(growable: false);
  }

  /// 加载图片记录列表
  Future<List<LocalImageRecord>> _loadRecords(List<File> files) async {
    if (files.isEmpty) return [];

    // 预加载元数据到缓存（后台）
    _preloadMetadataBatch(files);

    // 获取文件状态信息
    final fileStats = <File, FileStat>{};
    for (final file in files) {
      try {
        fileStats[file] = await file.stat();
      } catch (e) {
        AppLogger.w('Failed to stat file: ${file.path}', 'LocalGalleryService');
      }
    }

    // 批量获取数据库信息
    final paths = files.map((f) => f.path).toList();
    final pathToIdMap = await _dataSource.getImageIdsByPaths(paths);

    // 收集有效的图片ID
    final imageIds = pathToIdMap.values.whereType<int>().toList();

    // 并行获取收藏、标签、元数据
    final results = await Future.wait([
      if (imageIds.isNotEmpty)
        _dataSource.getFavoritesByImageIds(imageIds)
      else
        Future.value(<int, bool>{}),
      if (imageIds.isNotEmpty)
        _dataSource.getTagsByImageIds(imageIds)
      else
        Future.value(<int, List<String>>{}),
      if (imageIds.isNotEmpty)
        _dataSource.getMetadataByImageIds(imageIds)
      else
        Future.value(<int, GalleryMetadataRecord?>{}),
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
          isFavorite = favoritesMap[imageId] ?? false;
          tags = tagsMap[imageId] ?? [];

          final metadataRecord = metadataMap[imageId];
          if (metadataRecord != null) {
            metadata = _buildMetadataFromRecord(metadataRecord);
            metadataStatus = metadata.hasData
                ? MetadataStatus.success
                : MetadataStatus.none;
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
          'LocalGalleryService',
        );
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

  /// 批量预加载元数据
  void _preloadMetadataBatch(List<File> files) {
    final pngFiles = files
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList();
    if (pngFiles.isEmpty) return;

    Future.microtask(() {
      try {
        final images = pngFiles
            .map((f) => GeneratedImageInfo(id: f.path, filePath: f.path))
            .toList();
        ImageMetadataService().preloadBatch(images);
      } catch (e) {
        AppLogger.w(
          'Failed to preload metadata batch: $e',
          'LocalGalleryService',
        );
      }
    });
  }

  /// 从数据库记录构建元数据
  NaiImageMetadata _buildMetadataFromRecord(GalleryMetadataRecord record) {
    final metadata = NaiImageMetadata(
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
    return metadata.upgradeFromRawJsonIfNeeded();
  }

  @override
  Future<List<LocalImageRecord>> getRecordsByPaths(List<String> paths) async {
    _ensureInitialized();

    if (paths.isEmpty) return [];

    // 过滤出存在的文件
    final existingFiles = <File>[];
    for (final path in paths) {
      final file = File(_resolveTrackedFilePath(path));
      if (await file.exists()) {
        existingFiles.add(file);
      }
    }

    if (existingFiles.isEmpty) return [];

    // 获取文件状态信息
    final fileStats = <File, FileStat>{};
    for (final file in existingFiles) {
      try {
        fileStats[file] = await file.stat();
      } catch (e) {
        AppLogger.w('Failed to stat file: ${file.path}', 'LocalGalleryService');
      }
    }

    // 批量获取数据库信息
    final filePaths = existingFiles.map((f) => f.path).toList();
    final pathToIdMap = await _dataSource.getImageIdsByPaths(filePaths);

    // 收集有效的图片ID
    final imageIds = pathToIdMap.values.whereType<int>().toList();

    // 并行获取收藏、标签、元数据
    final results = await Future.wait([
      if (imageIds.isNotEmpty)
        _dataSource.getFavoritesByImageIds(imageIds)
      else
        Future.value(<int, bool>{}),
      if (imageIds.isNotEmpty)
        _dataSource.getTagsByImageIds(imageIds)
      else
        Future.value(<int, List<String>>{}),
      if (imageIds.isNotEmpty)
        _dataSource.getMetadataByImageIds(imageIds)
      else
        Future.value(<int, GalleryMetadataRecord?>{}),
    ]);

    final favoritesMap = results[0] as Map<int, bool>;
    final tagsMap = results[1] as Map<int, List<String>>;
    final metadataMap = results[2] as Map<int, GalleryMetadataRecord?>;

    // 构建记录列表
    final records = <LocalImageRecord>[];

    for (final file in existingFiles) {
      try {
        final stat = fileStats[file];
        if (stat == null) continue;

        final imageId = pathToIdMap[file.path];
        bool isFavorite = false;
        List<String> tags = [];
        NaiImageMetadata? metadata;
        MetadataStatus metadataStatus = MetadataStatus.none;

        if (imageId != null) {
          isFavorite = favoritesMap[imageId] ?? false;
          tags = tagsMap[imageId] ?? [];

          final metadataRecord = metadataMap[imageId];
          if (metadataRecord != null) {
            metadata = _buildMetadataFromRecord(metadataRecord);
            metadataStatus = metadata.hasData
                ? MetadataStatus.success
                : MetadataStatus.none;
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
          'LocalGalleryService',
        );
        // 跳过加载失败的记录
      }
    }

    return records;
  }

  // ============================================================
  // 过滤
  // ============================================================

  @override
  Future<void> applyFilter(FilterCriteria criteria) async {
    _ensureInitialized();

    final generation = ++_filterGeneration;
    final previousOperationId = _activeFilterOperationId;
    if (previousOperationId != null) {
      _filterService.cancelFilter(previousOperationId);
      _activeFilterOperationId = null;
    }

    _currentFilter = criteria;

    if (!criteria.hasFilters) {
      if (generation == _filterGeneration) {
        _filteredFiles = _allFiles;
      }
      return;
    }

    if (isFavoriteOnlyFastFilter(criteria)) {
      final favoriteRecords = await _dataSource.queryFavoriteImages(
        limit: max(1, _allFiles.length),
      );
      if (generation != _filterGeneration || _currentFilter != criteria) {
        return;
      }

      final pathToFile = {
        for (final file in _allFiles) galleryFilePathKey(file.path): file,
      };
      _filteredFiles = [
        for (final record in favoriteRecords)
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
      if (generation != _filterGeneration || _currentFilter != criteria) {
        return;
      }
      _filteredFiles = result.files;
    } on FilterCancelledException {
      if (generation == _filterGeneration) {
        rethrow;
      }
    } catch (e) {
      throw GalleryFilterException(
        filterCriteria: criteria.toString(),
        message: 'Failed to apply filter',
        cause: e,
      );
    } finally {
      if (_activeFilterOperationId == operationId) {
        _activeFilterOperationId = null;
      }
    }
  }

  @override
  Future<void> setSearchQuery(String query) async {
    await applyFilter(_currentFilter.copyWith(searchQuery: query));
  }

  @override
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    await applyFilter(_currentFilter.copyWith(dateStart: start, dateEnd: end));
  }

  @override
  Future<void> setShowFavoritesOnly(bool value) async {
    await applyFilter(_currentFilter.copyWith(showFavoritesOnly: value));
  }

  @override
  Future<void> setPageSize(int size) async {
    _pageSize = size;
  }

  @override
  Future<void> clearFilters() async {
    await applyFilter(const FilterCriteria());
  }

  // ============================================================
  // 收藏
  // ============================================================

  @override
  Future<bool> toggleFavorite(String filePath) async {
    _ensureInitialized();

    try {
      final resolvedPath = _resolveTrackedFilePath(filePath);
      final file = File(resolvedPath);
      final imageId = await _dataSource.getImageIdByPath(resolvedPath);

      if (imageId != null) {
        final isFavorite = await _dataSource.toggleFavorite(imageId);
        await _syncFileListsAfterFavoriteChange(file);
        return isFavorite;
      }

      // 图片不在数据库中，先按画廊可见路径索引，避免历史路径和扫描路径分裂。
      if (await file.exists()) {
        final stat = await file.stat();
        final fileName = p.basename(resolvedPath);
        final newId = await _dataSource.upsertImage(
          filePath: resolvedPath,
          fileName: fileName,
          fileSize: stat.size,
          createdAt: stat.changed,
          modifiedAt: stat.modified,
        );
        final isFavorite = await _dataSource.toggleFavorite(newId);
        await _syncFileListsAfterFavoriteChange(file);
        return isFavorite;
      }

      return false;
    } catch (e) {
      throw GalleryDatabaseException(
        operation: DatabaseOperation.update,
        message: 'Failed to toggle favorite for $filePath',
        cause: e,
      );
    }
  }

  @override
  Future<bool> isFavorite(String filePath) async {
    _ensureInitialized();

    try {
      final imageId = await _dataSource.getImageIdByPath(
        _resolveTrackedFilePath(filePath),
      );
      if (imageId != null) {
        return await _dataSource.isFavorite(imageId);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getFavoriteCount() async {
    _ensureInitialized();

    if (_allFiles.isEmpty) return 0;

    final totalFavorites = await _dataSource.getFavoriteCount();
    if (totalFavorites == 0) return 0;

    final favoriteRecords = await _dataSource.queryFavoriteImages(
      limit: totalFavorites,
    );
    final visiblePaths = {
      for (final file in _allFiles) galleryFilePathKey(file.path),
    };
    return favoriteRecords
        .where(
          (record) =>
              visiblePaths.contains(galleryFilePathKey(record.filePath)),
        )
        .length;
  }

  // ============================================================
  // 元数据
  // ============================================================

  @override
  Future<NaiImageMetadata?> getMetadata(String filePath) async {
    _ensureInitialized();

    try {
      return await ImageMetadataService().getMetadataImmediate(filePath);
    } catch (e) {
      throw GalleryMetadataException(
        imagePath: filePath,
        phase: MetadataErrorPhase.parsing,
        message: 'Failed to get metadata for $filePath',
        cause: e,
      );
    }
  }

  // ============================================================
  // 添加新图像（即时显示优化）
  // ============================================================

  /// 立即添加新图像到画廊（不触发全量扫描）
  ///
  /// 用于图像生成后即时显示新保存的图像，避免等待全量扫描
  ///
  /// [filePath] 新图像的文件路径
  /// [metadata] 可选的图像元数据
  ///
  /// 返回是否成功添加
  @override
  Future<bool> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) async {
    _ensureInitialized();

    try {
      final normalizedPath = normalizeGalleryFilePath(filePath);
      final file = File(normalizedPath);
      if (!await file.exists()) {
        AppLogger.w(
          '[AddNewImage] File does not exist: $filePath',
          'LocalGalleryService',
        );
        return false;
      }

      // 检查是否已存在
      final existingIndex = _allFiles.indexWhere(
        (f) => galleryFilePathsEqual(f.path, file.path),
      );
      if (existingIndex != -1) {
        AppLogger.d(
          '[AddNewImage] File already exists in gallery: $filePath',
          'LocalGalleryService',
        );
        return false;
      }

      final stat = await file.stat();
      final fileName = p.basename(file.path);

      // 1. 插入/更新数据库（使用 upsert）
      final metadataStatus = metadata != null && metadata.hasData
          ? MetadataStatus.success
          : MetadataStatus.none;

      final imageId = await _dataSource.upsertImage(
        filePath: file.path,
        fileName: fileName,
        fileSize: stat.size,
        width: metadata?.width,
        height: metadata?.height,
        aspectRatio: _calculateAspectRatio(metadata?.width, metadata?.height),
        createdAt: stat.modified,
        modifiedAt: stat.modified,
        resolutionKey: metadata?.width != null && metadata?.height != null
            ? '${metadata!.width}x${metadata.height}'
            : null,
        lastScannedAt: DateTime.now(),
        metadataStatus: metadataStatus,
      );

      // 2. 如果有元数据，保存到数据库
      if (metadata != null && metadata.hasData) {
        await _dataSource.upsertMetadata(imageId, metadata);
        ImageMetadataService().cacheMetadata(file.path, metadata);
      }

      // 3. 添加到 _allFiles 列表开头（因为是新文件，修改时间最新）
      _allFiles.insert(0, file);

      // 4. 重新应用过滤（如果有过滤条件）
      if (_currentFilter.hasFilters) {
        await applyFilter(_currentFilter);
      } else {
        _filteredFiles = _allFiles;
      }

      AppLogger.i(
        '[AddNewImage] Added new image immediately: $fileName (ID: $imageId)',
        'LocalGalleryService',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e(
        '[AddNewImage] Failed to add new image: $filePath',
        e,
        stack,
        'LocalGalleryService',
      );
      return false;
    }
  }

  // ============================================================
  // 刷新和重建
  // ============================================================

  @override
  Future<void> refresh({bool scan = true}) async {
    _ensureInitialized();

    try {
      final files = await _getAllImageFiles();

      final previousCount = _allFiles.length;
      final countChanged = files.length != previousCount;
      _allFiles = files;

      // 重新应用当前过滤
      await applyFilter(_currentFilter);

      if (!shouldRunRefreshIndexScan(
        scanRequested: scan,
        isBackgroundScanning: _isBackgroundScanning,
      )) {
        AppLogger.d(
          'Refresh updated file list without starting index scan: '
              'scanRequested=$scan, backgroundScanning=$_isBackgroundScanning',
          'LocalGalleryService',
        );
        return;
      }

      // ✅ 如果文件数量变化很大，执行完整扫描而非增量扫描
      if (countChanged && (files.length - previousCount).abs() > 100) {
        AppLogger.i(
          'File count changed significantly ($previousCount -> ${files.length}), performing full scan',
          'LocalGalleryService',
        );
        await _performFullScan();
      } else {
        // 后台扫描新文件（使用 await 确保扫描完成）
        await _performIncrementalScan();
      }
    } catch (e) {
      if (e is GalleryException) rethrow;
      throw GalleryScanException(
        message: 'Failed to refresh gallery',
        cause: e,
      );
    }
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /// 计算宽高比
  double? _calculateAspectRatio(int? width, int? height) {
    if (width != null && height != null && height > 0) {
      return width / height;
    }
    return null;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const GalleryNotInitializedException();
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _allFiles = [];
    _filteredFiles = [];
    _currentFilter = const FilterCriteria();
  }
}

// ============================================================
// Riverpod Provider
// ============================================================

/// 画廊服务 Provider
///
/// 提供 [LocalGalleryService] 的单例实例
/// 依赖于 [galleryDataSourceProvider] 和 [galleryFilterServiceProvider]
@Riverpod(keepAlive: true)
class GalleryService extends _$GalleryService {
  LocalGalleryService? _service;

  @override
  LocalGalleryService build() {
    // 初始化时创建服务实例
    _initializeService();

    ref.onDispose(() {
      _service?.dispose();
      _service = null;
    });

    // 返回一个未初始化的占位服务，直到异步初始化完成
    return _PlaceholderGalleryService();
  }

  Future<void> _initializeService() async {
    try {
      // 等待数据库准备就绪
      final dbManager = DatabaseManager.instance;
      final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');

      if (dataSource == null) {
        throw const GalleryDatabaseException(
          message: 'GalleryDataSource not available',
        );
      }

      final filterService = GalleryFilterService(dataSource);

      _service = LocalGalleryServiceImpl(
        dataSource: dataSource,
        filterService: filterService,
      );

      // 初始化服务
      await _service!.initialize();

      // 通知状态更新
      state = _service!;
    } on GalleryPermissionDeniedException catch (e) {
      AppLogger.e('Gallery permission denied', e, null, 'GalleryService');
      // 创建错误状态的服务
      state = ErrorGalleryService(error: '无法访问图片文件夹: ${e.message}');
    } on GalleryScanException catch (e) {
      AppLogger.e('Gallery scan failed', e, null, 'GalleryService');
      state = ErrorGalleryService(error: '扫描图片失败: ${e.message}');
    } catch (e) {
      AppLogger.e(
        'Failed to initialize gallery service',
        e,
        null,
        'GalleryService',
      );
      // 创建错误状态的服务，让调用方知道初始化失败
      state = ErrorGalleryService(error: '画廊初始化失败: $e');
    }
  }

  /// 重新初始化服务
  Future<void> reinitialize() async {
    await _service?.dispose();
    _service = null;
    await _initializeService();
  }
}

/// 错误状态服务实现
///
/// 当初始化失败时使用，所有操作都会抛出包含错误信息的异常
class ErrorGalleryService implements LocalGalleryService {
  final String error;

  const ErrorGalleryService({required this.error});

  @override
  bool get isInitialized => false;

  @override
  int get filteredCount => 0;

  @override
  int get totalCount => 0;

  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  dynamic _throwError() {
    throw GalleryDatabaseException(message: error);
  }

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

/// 占位服务实现
///
/// 在真实服务初始化完成前使用，所有操作都会抛出 [GalleryNotInitializedException]
class _PlaceholderGalleryService implements LocalGalleryService {
  @override
  bool get isInitialized => false;

  @override
  int get filteredCount => 0;

  @override
  int get totalCount => 0;

  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  dynamic _throwNotInitialized() {
    throw const GalleryNotInitializedException(
      message: 'Gallery service is initializing, please wait...',
    );
  }

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
