import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';

import '../services/gallery/gallery_database_service.dart';
import '../services/gallery/gallery_file_watcher_service.dart';
import '../services/gallery/gallery_scan_service.dart';
import '../services/gallery/gallery_search_service.dart';

/// 分页查询结果
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages - 1;
}

/// 批量操作结果（保持兼容）
typedef BulkOperationResult = ({
  int success,
  int failed,
  List<String> errors,
});

/// 本地画廊仓库（简化版）
///
/// 架构原则：
/// 1. **SQLite是唯一数据源** - 无冗余缓存层
/// 2. **自动文件监听** - 通过 FileWatcherService 实时增量更新
/// 3. **预热阶段智能决策** - 根据待处理文件数量决定是否扫描
class LocalGalleryRepository {
  LocalGalleryRepository._();
  static final LocalGalleryRepository instance = LocalGalleryRepository._();

  final _db = GalleryDatabaseService.instance;
  final _scanService = GalleryScanService.instance;
  final _watcher = GalleryFileWatcherService.instance;
  final _searchService = GallerySearchService.instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 预热阶段最大处理文件数，超过则跳过预热扫描
  static const int _warmupMaxFiles = 1000;

  /// 获取收藏 Box（保持兼容）
  Box get _favoritesBox => Hive.box(StorageKeys.localFavoritesBox);
  Box get _tagsBox => Hive.box(StorageKeys.tagsBox);

  // ============================================================
  // 初始化（预热阶段）
  // ============================================================

  /// 初始化仓库（应用预热阶段调用）
  ///
  /// 优化策略：
  /// 1. 初始化数据库
  /// 2. 快速检测需要处理的文件数量
  /// 3. 【关键决策】如果 <=1000张，在预热阶段处理；如果 >1000张，跳过预热扫描
  /// 4. 启动文件监听
  /// 5. 【应用启动后】后台继续完整增量扫描（不阻塞）
  Future<void> initialize({ScanProgressCallback? onProgress}) async {
    if (_initialized) return;

    final stopwatch = Stopwatch()..start();
    AppLogger.i('Initializing LocalGalleryRepository...', 'LocalGalleryRepo');

    try {
      // 1. 初始化数据库
      await _db.init();
      _initialized = true;

      final dir = await getImageDirectory();
      if (!await dir.exists()) {
        AppLogger.w('Image directory does not exist', 'LocalGalleryRepo');
        return;
      }

      // 2. 快速检测需要处理的文件数量（最多2秒）
      AppLogger.i('Detecting files need processing...', 'LocalGalleryRepo');
      final (totalFiles, needProcessing) = await _detectWithTimeout(dir);

      AppLogger.i(
        'Detection result: $totalFiles total, $needProcessing need processing (threshold: $_warmupMaxFiles)',
        'LocalGalleryRepo',
      );

      // 3. 【关键决策】根据待处理文件数量决定策略
      if (needProcessing > 0 && needProcessing <= _warmupMaxFiles) {
        // 情况A: 有少量文件需要处理（<=1000），在预热阶段快速处理
        AppLogger.i(
          'Warmup scan: processing $needProcessing files...',
          'LocalGalleryRepo',
        );
        onProgress?.call(processed: 0, total: needProcessing, phase: 'indexing');

        final result = await _scanService.quickStartupScan(
          dir,
          maxFiles: _warmupMaxFiles,
          onProgress: onProgress,
        );

        AppLogger.i(
          'Warmup scan completed: ${result.filesAdded} added, ${result.filesUpdated} updated',
          'LocalGalleryRepo',
        );
      } else if (needProcessing > _warmupMaxFiles) {
        // 情况B: 有大量文件需要处理（>1000），跳过预热扫描，让用户快速进入
        AppLogger.i(
          'Too many files need processing ($needProcessing > $_warmupMaxFiles), skipping warmup scan',
          'LocalGalleryRepo',
        );
        // 通知UI有后台扫描待执行
        onProgress?.call(processed: 0, total: needProcessing, phase: 'pending');
      } else {
        // 情况C: 没有文件需要处理，数据库已是最新
        AppLogger.i('All files up to date, no scan needed', 'LocalGalleryRepo');
      }

      // 4. 启动文件监听（自动增量更新）
      await _watcher.watch(dir);

      stopwatch.stop();
      AppLogger.i(
        'LocalGalleryRepository initialized in ${stopwatch.elapsedMilliseconds}ms',
        'LocalGalleryRepo',
      );

      // 5. 【应用启动后】后台继续完整增量扫描（不阻塞）
      // 如果有剩余文件需要处理，在后台继续
      if (needProcessing > _warmupMaxFiles) {
        _startBackgroundScan(dir, onProgress: onProgress);
      }

    } catch (e, stack) {
      AppLogger.e('Failed to initialize', e, stack, 'LocalGalleryRepo');
      _initialized = true; // 即使出错也标记初始化完成，不阻塞应用
    }
  }

  /// 快速检测文件（带2秒超时）
  Future<(int total, int needProcessing)> _detectWithTimeout(Directory dir) async {
    try {
      return await _scanService.detectFilesNeedProcessing(dir).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          AppLogger.w('File detection timeout, assuming many files', 'LocalGalleryRepo');
          return (0, _warmupMaxFiles + 1); // 超时则假设有大量文件，跳过预热
        },
      );
    } catch (e) {
      AppLogger.w('File detection failed: $e', 'LocalGalleryRepo');
      return (0, 0); // 检测失败，假设没有文件需要处理
    }
  }

  /// 启动后台扫描（应用启动后执行，不阻塞UI）
  void _startBackgroundScan(
    Directory dir, {
    ScanProgressCallback? onProgress,
  }) {
    // 使用 Timer 延迟执行，确保UI先完成渲染
    Timer(const Duration(milliseconds: 100), () async {
      AppLogger.i('Starting background complete scan...', 'LocalGalleryRepo');

      try {
        final result = await _scanService.incrementalScan(
          dir,
          onProgress: onProgress,
        );

        AppLogger.i(
          'Background scan completed: ${result.filesAdded} added, ${result.filesUpdated} updated, ${result.filesSkipped} cached',
          'LocalGalleryRepo',
        );

        // 通知扫描完成
        onProgress?.call(processed: result.filesScanned, total: result.filesScanned, phase: 'completed');
      } catch (e) {
        AppLogger.w('Background scan failed: $e', 'LocalGalleryRepo');
      }
    });
  }

  // ============================================================
  // 文件列表
  // ============================================================

  /// 获取图片保存目录
  Future<Directory> getImageDirectory() async {
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    final customPath = settingsBox.get(StorageKeys.imageSavePath) as String?;

    if (customPath != null && customPath.isNotEmpty) {
      return Directory(customPath);
    }

    final appDir = await getApplicationDocumentsDirectory();
    final newPath = '${appDir.path}/NAI_Launcher/images';

    // 检查是否需要从旧路径迁移
    await _migrateImagesIfNeeded(appDir.path, newPath);

    return Directory(newPath);
  }

  /// 从旧位置迁移图片（如果需要）
  ///
  /// 旧位置：{appDir}/nai_launcher/images/
  /// 新位置：{appDir}/NAI_Launcher/images/
  Future<void> _migrateImagesIfNeeded(String appDirPath, String newPath) async {
    try {
      // 如果新路径已存在且有文件，不需要迁移
      final newDir = Directory(newPath);
      if (await newDir.exists()) {
        final files = await newDir.list().toList();
        if (files.isNotEmpty) {
          return; // 新位置已有数据，不迁移
        }
      }

      // 检查旧位置是否存在
      final oldPath = '$appDirPath/nai_launcher/images';
      final oldDir = Directory(oldPath);
      if (!await oldDir.exists()) {
        return; // 没有旧数据需要迁移
      }

      // 检查旧位置是否有文件
      final oldFiles = await oldDir.list().toList();
      if (oldFiles.isEmpty) {
        return; // 旧位置为空，不需要迁移
      }

      AppLogger.i('发现旧版本图片数据，开始迁移...', 'LocalGallery');
      AppLogger.i('从: $oldPath', 'LocalGallery');
      AppLogger.i('到: $newPath', 'LocalGallery');

      // 确保新目录存在
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }

      // 迁移文件
      var migratedCount = 0;
      for (final entity in oldFiles) {
        try {
          final fileName = p.basename(entity.path);
          final newFilePath = '$newPath/$fileName';

          if (entity is File) {
            await entity.copy(newFilePath);
            migratedCount++;
          }
        } catch (e) {
          AppLogger.e('迁移失败 ${entity.path}: $e', 'LocalGallery');
        }
      }

      if (migratedCount > 0) {
        AppLogger.i('图片数据迁移完成: $migratedCount 个文件', 'LocalGallery');
        AppLogger.i('旧数据保留在: $oldPath（可手动删除）', 'LocalGallery');
      }
    } catch (e, stackTrace) {
      AppLogger.e('图片迁移过程出错: $e', 'LocalGallery', stackTrace);
    }
  }

  /// 获取所有图片文件（从文件系统，用于UI展示）
  ///
  /// 注意：这只是获取文件列表，不涉及元数据解析，不依赖扫描
  Future<List<File>> getAllImageFiles() async {
    final dir = await getImageDirectory();
    if (!dir.existsSync()) return [];

    final stopwatch = Stopwatch()..start();
    final files = dir
        .listSync(recursive: false)
        .whereType<File>()
        .where((f) {
          final ext = f.path.toLowerCase();
          return ext.endsWith('.png') || ext.endsWith('.jpg') || 
                 ext.endsWith('.jpeg') || ext.endsWith('.webp');
        })
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    stopwatch.stop();
    AppLogger.d(
      'Listed ${files.length} files in ${stopwatch.elapsedMilliseconds}ms',
      'LocalGalleryRepo',
    );
    return files;
  }

  // ============================================================
  // 记录加载
  // ============================================================

  /// 加载文件记录（从数据库或实时解析）
  ///
  /// 优先级：
  /// 1. 数据库（已索引）- 最快
  /// 2. 实时解析（未索引）- 解析并存入数据库
  Future<List<LocalImageRecord>> loadRecords(List<File> files) async {
    final stopwatch = Stopwatch()..start();
    final records = <LocalImageRecord>[];

    // 并行处理
    final futures = files.map((file) => _loadSingleRecord(file));
    final results = await Future.wait(futures, eagerError: false);

    for (final record in results) {
      if (record != null) records.add(record);
    }

    stopwatch.stop();
    AppLogger.d(
      'Loaded ${records.length} records in ${stopwatch.elapsedMilliseconds}ms',
      'LocalGalleryRepo',
    );
    return records;
  }

  /// 加载单个记录
  Future<LocalImageRecord?> _loadSingleRecord(File file) async {
    try {
      if (!await file.exists()) return null;

      final filePath = file.path;
      final modified = await file.lastModified();

      // 1. 尝试从数据库获取（已索引）
      if (_initialized) {
        final imageId = await _db.getImageIdByPath(filePath);
        if (imageId != null) {
          final row = await _db.getImageById(imageId);
          if (row != null) {
            return _db.mapToLocalImageRecord(row);
          }
        }
      }

      // 2. 实时解析（未索引）- 只返回基本信息，不阻塞
      return await _parseBasicInfo(file, modified);

    } catch (e) {
      AppLogger.w('Failed to load: ${file.path}', 'LocalGalleryRepo');
      return null;
    }
  }

  /// 解析基本信息（快速，不读取完整元数据）
  Future<LocalImageRecord> _parseBasicInfo(File file, DateTime modified) async {
    final stat = await file.stat();

    return LocalImageRecord(
      path: file.path,
      size: stat.size,
      modifiedAt: modified,
      isFavorite: isFavorite(file.path),
      tags: getTags(file.path),
    );
  }

  // ============================================================
  // 搜索
  // ============================================================

  /// 搜索图片（FTS5全文搜索）
  Future<List<LocalImageRecord>> searchImages(
    String query, {
    int limit = 1000,
  }) async {
    if (!_initialized) return [];

    final result = await _searchService.search(query, limit: limit);
    
    // 获取完整记录
    final records = <LocalImageRecord>[];
    for (final id in result.imageIds) {
      final row = await _db.getImageById(id);
      if (row != null) {
        records.add(_db.mapToLocalImageRecord(row));
      }
    }
    return records;
  }

  /// 高级搜索
  Future<List<LocalImageRecord>> advancedSearch({
    String? textQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool favoritesOnly = false,
    int limit = 1000,
  }) async {
    if (!_initialized) return [];

    final results = await _searchService.advancedSearch(
      textQuery: textQuery,
      dateStart: dateStart,
      dateEnd: dateEnd,
      favoritesOnly: favoritesOnly,
      limit: limit,
    );

    return results.map((row) => _db.mapToLocalImageRecord(row)).toList();
  }

  // ============================================================
  // 收藏
  // ============================================================

  bool isFavorite(String filePath) {
    return _favoritesBox.get(filePath, defaultValue: false) as bool;
  }

  Future<void> setFavorite(String filePath, bool isFavorite) async {
    await _favoritesBox.put(filePath, isFavorite);

    // 同步到数据库
    if (_initialized) {
      final imageId = await _db.getImageIdByPath(filePath);
      if (imageId != null) {
        final currentlyFav = await _db.isFavorite(imageId);
        if (isFavorite != currentlyFav) {
          await _db.toggleFavorite(imageId);
        }
      }
    }
  }

  Future<bool> toggleFavorite(String filePath) async {
    final newState = !isFavorite(filePath);
    await setFavorite(filePath, newState);
    return newState;
  }

  int getTotalFavoriteCount() {
    return _favoritesBox.values.where((v) => v == true).length;
  }

  // ============================================================
  // 标签
  // ============================================================

  List<String> getTags(String filePath) {
    final tags = _tagsBox.get(filePath, defaultValue: <String>[]);
    return List<String>.from(tags as List);
  }

  Future<void> setTags(String filePath, List<String> tags) async {
    await _tagsBox.put(filePath, tags);

    // 同步到数据库
    if (_initialized) {
      final imageId = await _db.getImageIdByPath(filePath);
      if (imageId != null) {
        final existingTags = await _db.getImageTags(imageId);
        for (final tag in existingTags) {
          if (!tags.contains(tag)) await _db.removeTag(imageId, tag);
        }
        for (final tag in tags) {
          if (!existingTags.contains(tag)) await _db.addTag(imageId, tag);
        }
      }
    }
  }

  // ============================================================
  // 扫描操作
  // ============================================================

  /// 手动触发全量扫描
  Future<ScanResult> performFullScan({ScanProgressCallback? onProgress}) async {
    _ensureInitialized();
    final dir = await getImageDirectory();
    return await _scanService.fullScan(dir, onProgress: onProgress);
  }

  /// 手动触发增量扫描
  Future<ScanResult> performIncrementalScan() async {
    _ensureInitialized();
    final dir = await getImageDirectory();
    return await _scanService.incrementalScan(dir);
  }

  // ============================================================
  // 工具方法
  // ============================================================

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('LocalGalleryRepository not initialized');
    }
  }
}
