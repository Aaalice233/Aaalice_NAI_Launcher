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
import 'gallery_scan_service.dart';
import 'gallery_stream_scanner.dart';
import 'scan_state_manager.dart';
import 'scan_config.dart' show ScanPhase, ScanConfig, ScanType;

part 'unified_gallery_service.g.dart';

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
  Future<void> refresh();

  /// 重建完整索引
  ///
  /// 执行全量扫描，重建数据库索引
  /// 这是一个耗时操作，建议显示进度提示
  ///
  /// 返回扫描结果统计
  ///
  /// 可能抛出：
  /// - [GalleryCancelledException] 用户取消
  /// - [GalleryScanException] 扫描失败
  Future<ScanResult?> rebuildIndex();

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
  int _pageSize = 50;

  // 取消令牌
  bool _shouldCancelRebuild = false;

  LocalGalleryServiceImpl({
    required GalleryDataSource dataSource,
    required GalleryFilterService filterService,
  })  : _dataSource = dataSource,
        _filterService = filterService;

  @override
  bool get isInitialized => _isInitialized;

  List<File> get _effectiveFiles =>
      _filteredFiles.isEmpty ? _allFiles : _filteredFiles;

  @override
  int get filteredCount => 
      _currentFilter.hasFilters ? _filteredFiles.length : totalCount;

  int _dbImageCount = 0;

  @override
  int get totalCount => _dbImageCount > 0 ? _dbImageCount : _allFiles.length;

  @override
  FilterCriteria get currentFilter => _currentFilter;

  // ============================================================
  // 初始化
  // ============================================================

  bool _isInitializing = false;
  bool _isBackgroundScanning = false;

  @override
  Future<List<File>> initialize() async {
    // ✅ 防止并发初始化
    if (_isInitializing) {
      AppLogger.d('Gallery initialization already in progress, waiting...',
          'LocalGalleryService',);
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
      
      // 1.5 同时获取数据库计数（用于统一统计显示）
      _dbImageCount = await _dataSource.countImages();
      _filteredFiles = files;

      AppLogger.i('Found ${files.length} image files in file system',
          'LocalGalleryService',);

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
      await for (final entity
          in rootDir.list(recursive: true, followLinks: false)) {
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

      final validStats =
          fileStats.whereType<({File file, FileStat stat})>().toList();
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
      AppLogger.d('Background scan already in progress, skipping',
          'LocalGalleryService',);
      return;
    }

    _isBackgroundScanning = true;
    AppLogger.i(
        'Starting background index initialization', 'LocalGalleryService',);

    try {
      // 检查是否需要完整扫描
      final existingCount = await _dataSource.countImages();
      AppLogger.i(
          'Database has $existingCount images, file system has ${_allFiles.length} images',
          'LocalGalleryService',);

      if (existingCount > 0 && existingCount == _allFiles.length) {
        // 执行快速增量扫描
        AppLogger.i('Performing incremental scan', 'LocalGalleryService');
        await _performIncrementalScan();
      } else {
        // 执行完整扫描（分批处理）
        AppLogger.i('Performing full scan (${_allFiles.length} files)',
            'LocalGalleryService',);
        await _performFullScan();
      }

      AppLogger.i(
          'Background index initialization completed', 'LocalGalleryService',);
    } catch (e, stack) {
      AppLogger.e('Background index initialization failed', e, stack,
          'LocalGalleryService',);
      // 打印更详细的错误信息
      AppLogger.e(
          'Error details: ${e.toString()}', null, null, 'LocalGalleryService',);
      AppLogger.e('Stack trace: ${stack.toString()}', null, null,
          'LocalGalleryService',);
      // 后台错误不影响主流程
    } finally {
      _isBackgroundScanning = false;
    }
  }

  /// 执行增量扫描（使用流式逐张处理）
  Future<void> _performIncrementalScan() async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null) {
      AppLogger.w('[UGS] _performIncrementalScan: rootPath is null', 'LocalGalleryService');
      return;
    }

    // 检查是否已有扫描在进行中
    final scanManager = ScanStateManager.instance;
    AppLogger.i('[UGS] _performIncrementalScan: isScanning=${scanManager.isScanning}, rootPath=$rootPath', 'LocalGalleryService');
    
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
      onFileProcessed: (result, stats) {
        // 每处理一个文件就更新状态
        AppLogger.d(
          '[UGS] File processed: ${result.path.split(Platform.pathSeparator).last}, '
          'stage: ${result.stage}, total: ${stats.totalDiscovered}',
          'LocalGalleryService',
        );
      },
    );
    
    AppLogger.i('[UGS] 流式扫描完成', 'LocalGalleryService');
  }

  /// 执行完整扫描
  Future<void> _performFullScan() async {
    final scanService = GalleryScanService(dataSource: _dataSource);
    final filesToScan = _allFiles.map((f) => File(f.path)).toList();
    
    // 使用文件系统实际文件数作为总数（反映实际处理进度）
    final actualFileCount = filesToScan.length;
    
    // 获取数据库统计信息
    final existingCount = await _dataSource.countImages();
    
    // 启动扫描状态管理，设置总数量为实际文件数
    final scanManager = ScanStateManager.instance;
    final started = scanManager.startScan(
      type: ScanType.full,
      rootPath: (await GalleryFolderRepository.instance.getRootPath()) ?? '',
      total: actualFileCount,
      existingInDatabase: existingCount,
      metadataCacheCount: 0,
    );
    if (!started) {
      AppLogger.w('全量扫描已在进行中，跳过此次请求', 'LocalGalleryService');
      return;
    }
    scanManager.updateProgress(
      processed: 0,
      total: actualFileCount,
      phase: ScanPhase.scanning,
    );

    // 启动定时器定期更新元数据统计（每2秒）
    Timer? metadataUpdateTimer;
    metadataUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final statusCounts = await _dataSource.countImagesByMetadataStatus();
      final successCount = statusCounts['success'] ?? 0;
      AppLogger.d('[FullScan] Metadata status: $statusCounts', 'LocalGalleryService');
      scanManager.setMetadataCacheCount(successCount);
    });

    try {
      await scanService.processFiles(
        filesToScan,
        onProgress: (
          {required processed, required total, currentFile, required phase, filesSkipped, confirmed,}
        ) {
          // 更新扫描状态管理器的进度
          scanManager.updateProgress(
            processed: processed,
            total: actualFileCount,
            currentFile: currentFile,
            phase: _convertToScanPhase(phase),
          );
          
          // 每处理100个文件更新一次日志
          if (processed % 100 == 0) {
            AppLogger.d('Full scan progress: $processed/$actualFileCount ($phase)', 'LocalGalleryService');
          }
        },
      );
    } finally {
      // 停止定时器
      metadataUpdateTimer.cancel();
    }

    // 最后更新一次元数据统计
    final finalStatusCounts = await _dataSource.countImagesByMetadataStatus();
    scanManager.setMetadataCacheCount(finalStatusCounts['success'] ?? 0);

    scanManager.completeScan();
    AppLogger.i('Full scan complete: $actualFileCount files', 'LocalGalleryService');
  }
  
  /// 将字符串phase转换为ScanPhase
  ScanPhase _convertToScanPhase(String phase) {
    switch (phase) {
      case 'scanning':
        return ScanPhase.scanning;
      case 'indexing':
        return ScanPhase.indexing;
      case 'metadata':
        return ScanPhase.parsing;
      case 'completed':
        return ScanPhase.completed;
      default:
        return ScanPhase.idle;
    }
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
            'Failed to load record for ${file.path}', 'LocalGalleryService',);
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
    final pngFiles =
        files.where((f) => f.path.toLowerCase().endsWith('.png')).toList();
    if (pngFiles.isEmpty) return;

    Future.microtask(() {
      try {
        final images = pngFiles
            .map((f) => GeneratedImageInfo(id: f.path, filePath: f.path))
            .toList();
        ImageMetadataService().preloadBatch(images);
      } catch (e) {
        AppLogger.w(
            'Failed to preload metadata batch: $e', 'LocalGalleryService',);
      }
    });
  }

  /// 从数据库记录构建元数据
  NaiImageMetadata _buildMetadataFromRecord(GalleryMetadataRecord record) {
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

  // ============================================================
  // 过滤
  // ============================================================

  @override
  Future<void> applyFilter(FilterCriteria criteria) async {
    _ensureInitialized();

    _currentFilter = criteria;

    if (!criteria.hasFilters) {
      _filteredFiles = _allFiles;
      return;
    }

    try {
      final result = await _filterService.applyFilters(_allFiles, criteria);
      _filteredFiles = result.files;
    } catch (e) {
      throw GalleryFilterException(
        filterCriteria: criteria.toString(),
        message: 'Failed to apply filter',
        cause: e,
      );
    }
  }

  @override
  Future<void> setSearchQuery(String query) async {
    await applyFilter(_currentFilter.copyWith(searchQuery: query));
  }

  @override
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    await applyFilter(
      _currentFilter.copyWith(
        dateStart: start,
        dateEnd: end,
      ),
    );
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
      final imageId = await _dataSource.getImageIdByPath(filePath);

      if (imageId != null) {
        await _dataSource.toggleFavorite(imageId);
        return await _dataSource.isFavorite(imageId);
      } else {
        // 图片不在数据库中，先索引
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          final fileName = filePath.split(Platform.pathSeparator).last;
          final newId = await _dataSource.upsertImage(
            filePath: filePath,
            fileName: fileName,
            fileSize: stat.size,
            createdAt: stat.changed,
            modifiedAt: stat.modified,
          );
          await _dataSource.toggleFavorite(newId);
          return true;
        }
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
      final imageId = await _dataSource.getImageIdByPath(filePath);
      if (imageId != null) {
        return await _dataSource.isFavorite(imageId);
      }
      return false;
    } catch (e) {
      return false;
    }
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
  // 刷新和重建
  // ============================================================

  @override
  Future<void> refresh() async {
    _ensureInitialized();

    // ✅ 如果正在后台扫描，跳过刷新以避免重置 _allFiles
    if (_isBackgroundScanning) {
      AppLogger.d('Refresh skipped: background scanning in progress',
          'LocalGalleryService',);
      return;
    }

    try {
      final files = await _getAllImageFiles();
      
      // 更新数据库计数
      _dbImageCount = await _dataSource.countImages();

      // ✅ 检查文件数量是否变化（可能由于扩展名修复导致）
      final previousCount = _allFiles.length;
      final countChanged = files.length != previousCount;
      _allFiles = files;

      // 重新应用当前过滤
      await applyFilter(_currentFilter);

      // ✅ 如果文件数量变化很大，执行完整扫描而非增量扫描
      if (countChanged && (files.length - previousCount).abs() > 100) {
        AppLogger.i(
            'File count changed significantly ($previousCount -> ${files.length}), performing full scan',
            'LocalGalleryService',);
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

  @override
  Future<ScanResult?> rebuildIndex() async {
    _ensureInitialized();

    if (_shouldCancelRebuild) {
      _shouldCancelRebuild = false;
      return null;
    }

    final stopwatch = Stopwatch()..start();
    final total = _allFiles.length;
    var newFiles = 0;
    var updatedFiles = 0;
    final errors = <String>[];

    const batchSize = 100;
    for (var i = 0; i < total; i += batchSize) {
      if (_shouldCancelRebuild) {
        break;
      }

      final end = (i + batchSize < total) ? i + batchSize : total;
      final batch = _allFiles.sublist(i, end);

      for (final file in batch) {
        try {
          final stat = await file.stat();
          final fileName = file.path.split(Platform.pathSeparator).last;

          final existingId = await _dataSource.getImageIdByPath(file.path);

          await _dataSource.upsertImage(
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
          if (errors.length < 10) {
            errors.add('${file.path}: $e');
          }
        }
      }

      // 让出时间片
      await Future.delayed(Duration.zero);
    }

    stopwatch.stop();

    if (_shouldCancelRebuild) {
      _shouldCancelRebuild = false;
      throw const GalleryCancelledException(progress: null);
    }

    // 刷新文件列表
    await refresh();

    return ScanResult(
      filesScanned: total,
      filesAdded: newFiles,
      filesUpdated: updatedFiles,
      filesDeleted: 0,
      duration: stopwatch.elapsed,
      errors: errors,
    );
  }

  // ============================================================
  // 工具方法
  // ============================================================

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
          'Failed to initialize gallery service', e, null, 'GalleryService',);
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
    throw GalleryDatabaseException(
      message: error,
    );
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
  Future<NaiImageMetadata?> getMetadata(String filePath) => _throwError();

  @override
  Future<void> refresh() => _throwError();

  @override
  Future<ScanResult?> rebuildIndex() => _throwError();

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
  Future<NaiImageMetadata?> getMetadata(String filePath) =>
      _throwNotInitialized();

  @override
  Future<void> refresh() => _throwNotInitialized();

  @override
  Future<ScanResult?> rebuildIndex() => _throwNotInitialized();

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
}
