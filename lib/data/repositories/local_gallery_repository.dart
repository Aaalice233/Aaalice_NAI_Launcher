import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/nai_metadata_parser.dart';
import '../models/gallery/local_image_record.dart';
import '../models/gallery/nai_image_metadata.dart';
import '../services/gallery/gallery_services.dart';
import '../services/local_metadata_cache_service.dart';

/// 顶级函数：在 Isolate 中解析 NAI 隐写元数据 (用于 compute)
///
/// 避免主线程阻塞，提升 UI 流畅度
Future<NaiImageMetadata?> parseNaiMetadataInIsolate(
  Map<String, dynamic> data,
) async {
  try {
    final bytes = data['bytes'] as Uint8List;
    return await NaiMetadataParser.extractFromBytes(bytes);
  } catch (e) {
    return null; // 解析失败返回 null
  }
}

/// Progress callback for bulk operations
///
/// [current] 当前处理的索引（从 0 开始）
/// [total] 总数
/// [currentItem] 当前正在处理的文件路径
/// [isComplete] 是否完成
typedef BulkProgressCallback = void Function(
  int current,
  int total,
  String currentItem,
  bool isComplete,
);

/// Bulk operation result
///
/// [success] 成功的数量
/// [failed] 失败的数量
/// [errors] 失败的文件路径及错误信息
typedef BulkOperationResult = ({
  int success,
  int failed,
  List<String> errors,
});

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

/// 排序方式
enum GallerySortOrder {
  dateDesc,
  dateAsc,
  sizeDesc,
  sizeAsc,
  nameAsc,
  nameDesc,
}

/// 本地画廊仓库（重构版）
///
/// 协调SQLite数据库、扫描服务、缓存服务和搜索服务
/// 提供统一的数据访问接口
class LocalGalleryRepository {
  LocalGalleryRepository._();

  /// 单例实例
  static final LocalGalleryRepository instance = LocalGalleryRepository._();

  /// SQLite数据库服务
  final _db = GalleryDatabaseService.instance;

  /// 扫描服务
  final _scanService = GalleryScanService.instance;

  /// 缓存服务
  final _cacheService = GalleryCacheService.instance;

  /// 搜索服务
  final _searchService = GallerySearchService.instance;

  /// 迁移服务
  final _migrationService = GalleryMigrationService.instance;

  /// 旧版元数据缓存服务（向后兼容）
  final _legacyCacheService = LocalMetadataCacheService();

  /// 是否已初始化
  bool _initialized = false;

  /// 获取收藏 Box（向后兼容）
  Box get _favoritesBox => Hive.box(StorageKeys.localFavoritesBox);

  /// 获取标签 Box（向后兼容）
  Box get _tagsBox => Hive.box(StorageKeys.tagsBox);

  // ============================================================
  // 初始化
  // ============================================================

  /// 初始化Repository
  ///
  /// 必须在使用其他方法之前调用
  Future<void> initialize() async {
    if (_initialized) return;

    final stopwatch = Stopwatch()..start();
    AppLogger.i('Initializing LocalGalleryRepository...', 'LocalGalleryRepo');

    try {
      // 1. 初始化SQLite数据库
      await _db.init();

      // 2. 初始化缓存服务
      await _cacheService.init();

      // 3. 执行数据迁移（如果需要）
      final migrationResult = await _migrationService.migrate();
      if (!migrationResult.alreadyMigrated) {
        AppLogger.i(
            'Migration completed: $migrationResult', 'LocalGalleryRepo');
      }

      // 4. 检查是否需要首次扫描
      final stats = await _db.getStatistics();
      if (stats['total_images'] == 0) {
        AppLogger.i('No images in database, starting initial scan...',
            'LocalGalleryRepo');
        final dir = await getImageDirectory();
        if (await dir.exists()) {
          await _scanService.fullScan(dir);
        }
      }

      _initialized = true;
      stopwatch.stop();
      AppLogger.i(
        'LocalGalleryRepository initialized in ${stopwatch.elapsedMilliseconds}ms',
        'LocalGalleryRepo',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to initialize LocalGalleryRepository', e, stack,
          'LocalGalleryRepo');
      rethrow;
    }
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'LocalGalleryRepository not initialized. Call initialize() first.');
    }
  }

  // ============================================================
  // 扫描操作
  // ============================================================

  /// 执行增量扫描
  Future<ScanResult> incrementalScan() async {
    _ensureInitialized();
    final dir = await getImageDirectory();
    return await _scanService.incrementalScan(dir);
  }

  /// 执行全量扫描
  Future<ScanResult> fullScan() async {
    _ensureInitialized();
    final dir = await getImageDirectory();
    return await _scanService.fullScan(dir);
  }

  // ============================================================
  // 查询操作（新API）
  // ============================================================

  /// 分页查询图片
  Future<PagedResult<LocalImageRecord>> getImages({
    int page = 0,
    int pageSize = 50,
    GallerySortOrder sortOrder = GallerySortOrder.dateDesc,
    bool favoritesOnly = false,
    List<String>? tags,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? model,
    String? sampler,
    int? minSteps,
    int? maxSteps,
    double? minCfg,
    double? maxCfg,
    String? resolution,
  }) async {
    _ensureInitialized();

    final orderBy = _getSortOrderSql(sortOrder);
    final offset = page * pageSize;

    final results = await _db.queryImages(
      limit: pageSize,
      offset: offset,
      orderBy: orderBy,
      favoritesOnly: favoritesOnly,
      tags: tags,
      dateStart: dateStart,
      dateEnd: dateEnd,
      model: model,
      sampler: sampler,
      minSteps: minSteps,
      maxSteps: maxSteps,
      minCfg: minCfg,
      maxCfg: maxCfg,
      resolution: resolution,
    );

    final records =
        results.map((row) => _db.mapToLocalImageRecord(row)).toList();

    // 获取总数
    final totalCount = await _db.countImages();
    final totalPages = (totalCount / pageSize).ceil();

    return PagedResult(
      items: records,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
    );
  }

  /// 搜索图片
  Future<List<LocalImageRecord>> searchImages(String query,
      {int limit = 100}) async {
    _ensureInitialized();

    final searchResult = await _searchService.search(query, limit: limit);
    if (searchResult.imageIds.isEmpty) return [];

    // 批量获取记录
    final records = <LocalImageRecord>[];
    for (final id in searchResult.imageIds) {
      // 尝试从缓存获取
      var record = await _cacheService.get(id);
      if (record == null) {
        // 从数据库获取
        final results = await _db.queryImages(
          limit: 1,
          offset: 0,
        );
        if (results.isNotEmpty) {
          record = _db.mapToLocalImageRecord(results.first);
          await _cacheService.put(id, record);
        }
      }
      if (record != null) {
        records.add(record);
      }
    }

    return records;
  }

  /// 高级搜索
  Future<List<LocalImageRecord>> advancedSearch({
    String? textQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? model,
    String? sampler,
    int? minSteps,
    int? maxSteps,
    double? minCfg,
    double? maxCfg,
    String? resolution,
    bool favoritesOnly = false,
    List<String>? tags,
    int limit = 50,
    int offset = 0,
    GallerySortOrder sortOrder = GallerySortOrder.dateDesc,
  }) async {
    _ensureInitialized();

    final results = await _searchService.advancedSearch(
      textQuery: textQuery,
      dateStart: dateStart,
      dateEnd: dateEnd,
      model: model,
      sampler: sampler,
      minSteps: minSteps,
      maxSteps: maxSteps,
      minCfg: minCfg,
      maxCfg: maxCfg,
      resolution: resolution,
      favoritesOnly: favoritesOnly,
      tags: tags,
      limit: limit,
      offset: offset,
      orderBy: _getSortOrderSql(sortOrder),
    );

    return results.map((row) => _db.mapToLocalImageRecord(row)).toList();
  }

  // ============================================================
  // 向后兼容API
  // ============================================================

  /// 获取图片保存目录
  Future<Directory> getImageDirectory() async {
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    final customPath = settingsBox.get(StorageKeys.imageSavePath) as String?;

    final Directory imageDir;
    if (customPath != null && customPath.isNotEmpty) {
      imageDir = Directory(customPath);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      imageDir = Directory('${appDir.path}/nai_launcher/images');
    }

    return imageDir;
  }

  /// 快速路径：获取所有文件路径而不解析元数据
  ///
  /// 返回按修改时间降序排列的文件列表（最新优先）
  Future<List<File>> getAllImageFiles() async {
    final stopwatch = Stopwatch()..start();
    final dir = await getImageDirectory();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync(recursive: false)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    stopwatch.stop();
    AppLogger.i(
      'Indexing completed: ${files.length} files in ${stopwatch.elapsedMilliseconds}ms',
      'LocalGalleryRepo',
    );
    return files;
  }

  /// 加载文件记录（批量解析元数据，带缓存）
  Future<List<LocalImageRecord>> loadRecords(List<File> files) async {
    final stopwatch = Stopwatch()..start();
    int cacheHits = 0;
    int cacheMisses = 0;

    final records = await Future.wait(
      files.map((file) async {
        if (!file.existsSync()) {
          return LocalImageRecord(
            path: file.path,
            size: 0,
            modifiedAt: DateTime.now(),
            metadataStatus: MetadataStatus.none,
            isFavorite: isFavorite(file.path),
            tags: getTags(file.path),
          );
        }

        final filePath = file.path;
        final fileModified = file.lastModifiedSync();

        // 尝试从SQLite获取
        if (_initialized) {
          final imageId = await _db.getImageIdByPath(filePath);
          if (imageId != null) {
            final cached = await _cacheService.get(imageId);
            if (cached != null) {
              cacheHits++;
              return cached;
            }
          }
        }

        // 尝试从旧版缓存获取
        final cached = _legacyCacheService.get(filePath);
        if (cached != null) {
          final cachedTs = cached['ts'] as DateTime;
          if (cachedTs.millisecondsSinceEpoch ==
              fileModified.millisecondsSinceEpoch) {
            cacheHits++;
            final meta = cached['meta'] as NaiImageMetadata;
            return LocalImageRecord(
              path: filePath,
              size: file.lengthSync(),
              modifiedAt: fileModified,
              metadata: meta,
              metadataStatus:
                  meta.hasData ? MetadataStatus.success : MetadataStatus.none,
              isFavorite: isFavorite(filePath),
              tags: getTags(filePath),
            );
          }
        }

        // 缓存未命中，解析文件
        cacheMisses++;
        try {
          final bytes = await file.readAsBytes();
          final meta =
              await compute(parseNaiMetadataInIsolate, {'bytes': bytes});

          // 写入缓存
          if (meta != null) {
            await _legacyCacheService.put(filePath, meta, fileModified);
          }

          return LocalImageRecord(
            path: filePath,
            size: bytes.length,
            modifiedAt: fileModified,
            metadata: meta,
            metadataStatus: meta != null && meta.hasData
                ? MetadataStatus.success
                : MetadataStatus.none,
            isFavorite: isFavorite(filePath),
            tags: getTags(filePath),
          );
        } catch (e) {
          AppLogger.w(
              'Failed to parse metadata for $filePath: $e', 'LocalGalleryRepo');
          return LocalImageRecord(
            path: filePath,
            size: 0,
            modifiedAt: fileModified,
            metadataStatus: MetadataStatus.failed,
            isFavorite: isFavorite(filePath),
            tags: getTags(filePath),
          );
        }
      }),
    );

    stopwatch.stop();
    final successCount =
        records.where((r) => r.metadataStatus == MetadataStatus.success).length;
    AppLogger.i(
      'Page load completed: ${records.length} records ($successCount with metadata) '
          'in ${stopwatch.elapsedMilliseconds}ms [cache: $cacheHits hits, $cacheMisses misses]',
      'LocalGalleryRepo',
    );
    return records;
  }

  /// 从单个文件解析元数据
  Future<NaiImageMetadata?> parseMetadataFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await NaiMetadataParser.extractFromBytes(bytes);
    } catch (e) {
      AppLogger.e('Failed to parse metadata from file: ${file.path}', e, null,
          'LocalGalleryRepo');
      return null;
    }
  }

  /// 从字节数据解析元数据
  Future<NaiImageMetadata?> parseMetadataFromBytes(Uint8List bytes) async {
    try {
      return await NaiMetadataParser.extractFromBytes(bytes);
    } catch (e) {
      AppLogger.e(
          'Failed to parse metadata from bytes', e, null, 'LocalGalleryRepo');
      return null;
    }
  }

  // ============================================================
  // 收藏操作
  // ============================================================

  /// 获取图片的收藏状态
  bool isFavorite(String filePath) {
    return _favoritesBox.get(filePath, defaultValue: false) as bool;
  }

  /// 设置图片的收藏状态
  Future<void> setFavorite(String filePath, bool isFavorite) async {
    await _favoritesBox.put(filePath, isFavorite);

    // 同步到SQLite
    if (_initialized) {
      final imageId = await _db.getImageIdByPath(filePath);
      if (imageId != null) {
        if (isFavorite) {
          final alreadyFav = await _db.isFavorite(imageId);
          if (!alreadyFav) await _db.toggleFavorite(imageId);
        } else {
          final alreadyFav = await _db.isFavorite(imageId);
          if (alreadyFav) await _db.toggleFavorite(imageId);
        }
        await _cacheService.invalidate(imageId);
      }
    }

    AppLogger.d('Set favorite: $filePath -> $isFavorite', 'LocalGalleryRepo');
  }

  /// 切换图片的收藏状态
  Future<bool> toggleFavorite(String filePath) async {
    final current = isFavorite(filePath);
    final newState = !current;
    await setFavorite(filePath, newState);
    return newState;
  }

  /// 获取总收藏数量
  int getTotalFavoriteCount() {
    int count = 0;
    for (final key in _favoritesBox.keys) {
      if (_favoritesBox.get(key, defaultValue: false) == true) {
        count++;
      }
    }
    return count;
  }

  // ============================================================
  // 标签操作
  // ============================================================

  /// 获取图片的标签列表
  List<String> getTags(String filePath) {
    final tags = _tagsBox.get(filePath, defaultValue: <String>[]);
    return List<String>.from(tags as List);
  }

  /// 设置图片的标签列表
  Future<void> setTags(String filePath, List<String> tags) async {
    await _tagsBox.put(filePath, tags);

    // 同步到SQLite
    if (_initialized) {
      final imageId = await _db.getImageIdByPath(filePath);
      if (imageId != null) {
        // 获取现有标签
        final existingTags = await _db.getImageTags(imageId);

        // 移除不在新列表中的标签
        for (final tag in existingTags) {
          if (!tags.contains(tag)) {
            await _db.removeTag(imageId, tag);
          }
        }

        // 添加新标签
        for (final tag in tags) {
          if (!existingTags.contains(tag)) {
            await _db.addTag(imageId, tag);
          }
        }

        await _cacheService.invalidate(imageId);
      }
    }

    AppLogger.d('Set tags: $filePath -> $tags', 'LocalGalleryRepo');
  }

  /// 添加标签到图片
  Future<void> addTag(String filePath, String tag) async {
    final currentTags = getTags(filePath);
    if (!currentTags.contains(tag)) {
      final newTags = [...currentTags, tag];
      await setTags(filePath, newTags);
    }
  }

  /// 从图片移除标签
  Future<void> removeTag(String filePath, String tag) async {
    final currentTags = getTags(filePath);
    if (currentTags.contains(tag)) {
      final newTags = currentTags.where((t) => t != tag).toList();
      await setTags(filePath, newTags);
    }
  }

  // ============================================================
  // 统计数据
  // ============================================================

  /// 获取统计数据
  Future<Map<String, dynamic>> getStatistics() async {
    _ensureInitialized();
    return await _db.getStatistics();
  }

  /// 获取模型分布
  Future<List<Map<String, dynamic>>> getModelDistribution() async {
    _ensureInitialized();
    return await _db.getModelDistribution();
  }

  /// 获取采样器分布
  Future<List<Map<String, dynamic>>> getSamplerDistribution() async {
    _ensureInitialized();
    return await _db.getSamplerDistribution();
  }

  /// 获取分辨率分布
  Future<List<Map<String, dynamic>>> getResolutionDistribution() async {
    _ensureInitialized();
    return await _db.getResolutionDistribution();
  }

  // ============================================================
  // 批量操作
  // ============================================================

  /// 批量删除图片
  Future<BulkOperationResult> bulkDeleteImages(
    List<String> imagePaths, {
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    int successCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    AppLogger.i('Starting bulk delete: ${imagePaths.length} images',
        'LocalGalleryRepo');

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(i, imagePaths.length, imagePath, false);

      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();

          // 清理Hive数据
          await _favoritesBox.delete(imagePath);
          await _tagsBox.delete(imagePath);

          // 标记SQLite中为已删除
          if (_initialized) {
            await _db.markAsDeleted(imagePath);
          }

          successCount++;
        } else {
          failedCount++;
          errors.add('File not found: $imagePath');
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to delete $imagePath: $e');
      }
    }

    onProgress?.call(imagePaths.length, imagePaths.length, '', true);
    stopwatch.stop();
    AppLogger.i(
      'Bulk delete completed: $successCount succeeded, $failedCount failed '
          'in ${stopwatch.elapsedMilliseconds}ms',
      'LocalGalleryRepo',
    );

    return (success: successCount, failed: failedCount, errors: errors);
  }

  /// 批量编辑标签
  Future<BulkOperationResult> bulkEditTags(
    List<String> imagePaths, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    int successCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      return (success: 0, failed: 0, errors: <String>[]);
    }

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(i, imagePaths.length, imagePath, false);

      try {
        final currentTags = getTags(imagePath);
        final updatedTags = List<String>.from(currentTags);

        for (final tag in tagsToAdd) {
          if (!updatedTags.contains(tag)) {
            updatedTags.add(tag);
          }
        }

        for (final tag in tagsToRemove) {
          updatedTags.remove(tag);
        }

        await setTags(imagePath, updatedTags);
        successCount++;
      } catch (e) {
        failedCount++;
        errors.add('Failed to edit tags for $imagePath: $e');
      }
    }

    onProgress?.call(imagePaths.length, imagePaths.length, '', true);
    stopwatch.stop();

    return (success: successCount, failed: failedCount, errors: errors);
  }

  /// 批量导出元数据到 JSON 文件
  Future<File?> exportMetadataToJson(List<LocalImageRecord> records) async {
    try {
      final exportData = records.map((record) {
        final map = <String, dynamic>{
          'path': record.path,
          'fileName': record.path.split(Platform.pathSeparator).last,
          'size': record.size,
          'modifiedAt': record.modifiedAt.toIso8601String(),
          'isFavorite': record.isFavorite,
          'tags': record.tags,
          'metadataStatus': record.metadataStatus.name,
        };

        if (record.metadata != null && record.metadata!.hasData) {
          final meta = record.metadata!;
          map['metadata'] = {
            'prompt': meta.prompt,
            'negativePrompt': meta.negativePrompt,
            'seed': meta.seed,
            'sampler': meta.sampler,
            'steps': meta.steps,
            'scale': meta.scale,
            'width': meta.width,
            'height': meta.height,
            'model': meta.model,
            'smea': meta.smea,
            'smeaDyn': meta.smeaDyn,
            'noiseSchedule': meta.noiseSchedule,
            'cfgRescale': meta.cfgRescale,
            'characterPrompts': meta.characterPrompts,
            'characterNegativePrompts': meta.characterNegativePrompts,
          };
        }

        return map;
      }).toList();

      final jsonData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'totalImages': records.length,
        'images': exportData,
      };

      Directory? exportDir;
      try {
        exportDir = await getDownloadsDirectory();
      } catch (e) {
        exportDir = Directory.systemTemp;
      }
      exportDir ??= Directory.systemTemp;

      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'nai_metadata_export_$timestamp.json';
      final filePath = '${exportDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(jsonData));

      AppLogger.i(
          'Exported ${records.length} images to $fileName', 'LocalGalleryRepo');
      return file;
    } catch (e) {
      AppLogger.e('Failed to export metadata', e, null, 'LocalGalleryRepo');
      return null;
    }
  }

  /// 批量导出元数据
  Future<File?> bulkExportMetadata(
    List<File> files, {
    BulkProgressCallback? onProgress,
  }) async {
    try {
      final records = await loadRecords(files);
      for (var i = 0; i < records.length; i++) {
        onProgress?.call(i, records.length, records[i].path, false);
      }
      onProgress?.call(records.length, records.length, '', true);
      return await exportMetadataToJson(records);
    } catch (e) {
      AppLogger.e('Bulk export failed', e, null, 'LocalGalleryRepo');
      return null;
    }
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /// 转换排序方式为SQL
  String _getSortOrderSql(GallerySortOrder order) {
    switch (order) {
      case GallerySortOrder.dateDesc:
        return 'modified_at DESC';
      case GallerySortOrder.dateAsc:
        return 'modified_at ASC';
      case GallerySortOrder.sizeDesc:
        return 'file_size DESC';
      case GallerySortOrder.sizeAsc:
        return 'file_size ASC';
      case GallerySortOrder.nameAsc:
        return 'file_name ASC';
      case GallerySortOrder.nameDesc:
        return 'file_name DESC';
    }
  }
}
