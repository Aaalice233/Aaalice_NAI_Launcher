import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/thumbnail_cache_service.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/generation_record.dart';
import '../models/gallery/gallery_statistics.dart';
import '../services/gallery_migration_service.dart';

part 'gallery_repository.g.dart';

/// 画廊数据仓库
///
/// 管理生成记录的 CRUD 操作和持久化
class GalleryRepository {
  static const String _boxName = StorageKeys.galleryBox;
  static const int maxRecords = 5000;

  Box<GenerationRecord>? _box;
  Directory? _imageDir;
  final ThumbnailCacheService _thumbnailCacheService;

  /// 构造函数
  GalleryRepository({ThumbnailCacheService? thumbnailCacheService})
      : _thumbnailCacheService = thumbnailCacheService ?? ThumbnailCacheService();

  /// 初始化
  Future<void> init() async {
    try {
      // 初始化图像目录（优先使用用户设置的自定义路径）
      // 从 Hive 读取，与 LocalStorageService 保持一致
      final settingsBox = Hive.box(StorageKeys.settingsBox);
      final customPath = settingsBox.get(StorageKeys.imageSavePath) as String?;

      if (customPath != null && customPath.isNotEmpty) {
        // 使用用户设置的自定义路径
        _imageDir = Directory(customPath);
        AppLogger.i(
          'Using custom save path: ${_imageDir!.path}',
          'Gallery',
        );
      } else {
        // 使用默认路径：App 文档目录下的 nai_launcher/images
        final appDir = await getApplicationDocumentsDirectory();
        _imageDir = Directory('${appDir.path}/nai_launcher/images');
        AppLogger.i(
          'Using default save path: ${_imageDir!.path}',
          'Gallery',
        );
      }

      if (!await _imageDir!.exists()) {
        await _imageDir!.create(recursive: true);
      }

      _box = await Hive.openBox<GenerationRecord>(_boxName);

      // 执行数据迁移 (如果尚未迁移)
      final migrationService = GalleryMigrationService();
      final (success, count, error) = await migrationService.migrate();
      if (success) {
        AppLogger.i(
          'GalleryRepository initialized with $count migrated records',
          'Gallery',
        );
      } else {
        AppLogger.e('Migration failed: $error', null, null, 'Gallery');
      }
    } catch (e, stack) {
      AppLogger.e('Failed to init GalleryRepository: $e', e, stack, 'Gallery');
    }
  }

  /// 生成基于提示词的智能文件名（格式: NAI_[Date]_[PromptSnippet].png）
  String _generateFileName(String? prompt, {String prefix = 'nai'}) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);

    if (prompt == null || prompt.isEmpty) {
      return '${prefix}_$timestamp.png';
    }

    final snippet = prompt
        .substring(0, min(30, prompt.length))
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_')
        .replaceAll(',', '')
        .trim();

    return '${prefix}_${timestamp}_${snippet.isEmpty ? 'generated' : snippet}.png';
  }

  /// 获取所有记录
  List<GenerationRecord> getAllRecords() {
    try {
      if (_box == null || _box!.isEmpty) return [];

      final records = _box!.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return records;
    } catch (e, stack) {
      AppLogger.e('Failed to load records: $e', e, stack, 'Gallery');
      return [];
    }
  }

  /// 添加记录
  Future<GenerationRecord> addRecord({
    required Uint8List imageData,
    required GenerationParamsSnapshot params,
    bool saveToFile = true,
  }) async {
    String? filePath;
    String? thumbnailPath;

    // 保存图像到文件
    if (saveToFile && _imageDir != null) {
      try {
        final fileName = _generateFileName(params.prompt);
        final file = File('${_imageDir!.path}/$fileName');
        await file.writeAsBytes(imageData);
        filePath = file.path;
        AppLogger.d('Image saved to: $filePath', 'Gallery');

        // 异步生成缩略图
        try {
          thumbnailPath = await _thumbnailCacheService.generateThumbnail(filePath);
          if (thumbnailPath != null) {
            AppLogger.d('Thumbnail generated: $thumbnailPath', 'Gallery');
          }
        } catch (e, stack) {
          AppLogger.w('Failed to generate thumbnail: $e', 'Gallery');
        }
      } catch (e) {
        AppLogger.w('Failed to save image to file: $e', 'Gallery');
      }
    }

    // 创建记录
    final record = GenerationRecord.create(
      imageData: imageData,
      params: params,
      filePath: filePath,
    ).copyWith(thumbnailPath: thumbnailPath);

    // 检查是否超出最大数量限制
    if (_box != null && _box!.length >= maxRecords) {
      final oldestRecord = _box!.values.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b);
      await _deleteRecordInternal(oldestRecord);
    }

    await _box!.put(record.id, record);
    AppLogger.d('Record added: ${record.id}', 'Gallery');

    return record;
  }

  /// 内部删除方法 (供 addRecord 批量删除旧记录使用)
  Future<void> _deleteRecordInternal(GenerationRecord record) async {
    // 删除图像文件
    if (record.filePath != null) {
      try {
        final file = File(record.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        AppLogger.w('Failed to delete old image: $e', 'Gallery');
      }
    }

    // 从 Hive Box 删除
    await _box!.delete(record.id);
  }

  /// 更新记录
  Future<void> updateRecord(GenerationRecord record) async {
    if (_box == null) return;

    try {
      await _box!.put(record.id, record);
      AppLogger.d('Record updated: ${record.id}', 'Gallery');
    } catch (e, stack) {
      AppLogger.e('Failed to update record: $e', e, stack, 'Gallery');
    }
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    if (_box == null) return;

    try {
      final record = _box!.get(id);
      if (record == null) {
        AppLogger.w('Record not found: $id', 'Gallery');
        return;
      }

      await _deleteRecordInternal(record);
      AppLogger.d('Record deleted: $id', 'Gallery');
    } catch (e, stack) {
      AppLogger.e('Failed to delete record: $e', e, stack, 'Gallery');
    }
  }

  /// 批量删除记录
  Future<void> deleteRecords(List<String> ids) async {
    if (_box == null) return;

    try {
      for (final id in ids) {
        final record = _box!.get(id);
        if (record != null) await _deleteRecordInternal(record);
      }
      AppLogger.d('Deleted ${ids.length} records', 'Gallery');
    } catch (e, stack) {
      AppLogger.e('Failed to delete records: $e', e, stack, 'Gallery');
    }
  }

  /// 切换收藏状态
  Future<GenerationRecord> toggleFavorite(String id) async {
    if (_box == null) throw Exception('Repository not initialized');

    final record = _box!.get(id);
    if (record == null) throw Exception('Record not found');

    final updated = record.copyWith(isFavorite: !record.isFavorite);
    await _box!.put(id, updated);

    AppLogger.d('Toggled favorite: $id -> ${updated.isFavorite}', 'Gallery');
    return updated;
  }

  /// 获取记录图像数据
  Future<Uint8List?> getImageData(GenerationRecord record) async {
    // 优先从文件读取
    if (record.filePath != null) {
      try {
        final file = File(record.filePath!);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        AppLogger.w('Failed to read image from file: $e', 'Gallery');
      }
    }

    // 回退到 base64 数据
    return record.imageData;
  }

  /// 导出图像到指定路径
  Future<String?> exportImage(GenerationRecord record, String targetDir) async {
    try {
      final imageData = await getImageData(record);
      if (imageData == null) return null;

      final fileName =
          _generateFileName(record.params.prompt, prefix: 'nai_export');
      final file = File('$targetDir/$fileName');
      await file.writeAsBytes(imageData);

      AppLogger.d('Image exported to: ${file.path}', 'Gallery');
      return file.path;
    } catch (e, stack) {
      AppLogger.e('Failed to export image: $e', e, stack, 'Gallery');
      return null;
    }
  }

  /// 搜索记录
  List<GenerationRecord> searchRecords(String query) {
    if (_box == null || _box!.isEmpty) return [];

    final lowerQuery = query.toLowerCase();

    return _box!.values.where((r) {
      return r.params.prompt.toLowerCase().contains(lowerQuery) ||
          r.params.negativePrompt.toLowerCase().contains(lowerQuery) ||
          r.userTags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 应用筛选条件
  List<GenerationRecord> filterRecords(GalleryFilter filter) {
    var records = _box?.values.toList() ?? [];

    if (records.isEmpty) return [];

    // 搜索
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final query = filter.searchQuery!.toLowerCase();
      records = records.where((r) {
        return r.params.prompt.toLowerCase().contains(query) ||
            r.params.negativePrompt.toLowerCase().contains(query) ||
            r.userTags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // 只显示收藏
    if (filter.favoritesOnly) {
      records = records.where((r) => r.isFavorite).toList();
    }

    // 只显示 Vibe 图片
    if (filter.vibeOnly) {
      records = records.where((r) => r.hasVibeMetadata).toList();
    }

    // 模型筛选
    if (filter.modelFilter != null && filter.modelFilter!.isNotEmpty) {
      records =
          records.where((r) => r.params.model == filter.modelFilter).toList();
    }

    // 日期筛选
    if (filter.dateFrom != null) {
      records =
          records.where((r) => r.createdAt.isAfter(filter.dateFrom!)).toList();
    }
    if (filter.dateTo != null) {
      records =
          records.where((r) => r.createdAt.isBefore(filter.dateTo!)).toList();
    }

    // 标签筛选
    if (filter.tagFilter.isNotEmpty) {
      records = records.where((r) {
        return filter.tagFilter.every((tag) => r.userTags.contains(tag));
      }).toList();
    }

    // 排序
    switch (filter.sortOrder) {
      case GallerySortOrder.newestFirst:
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case GallerySortOrder.oldestFirst:
        records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case GallerySortOrder.favoritesFirst:
        records.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }

    return records;
  }

  /// 获取统计信息
  GalleryStatistics getStats() {
    if (_box == null || _box!.isEmpty) {
      return GalleryStatistics(
        totalImages: 0,
        totalSizeBytes: 0,
        averageFileSizeBytes: 0,
        favoriteCount: 0,
        taggedImageCount: 0,
        imagesWithMetadata: 0,
        resolutionDistribution: const [],
        modelDistribution: const [],
        samplerDistribution: const [],
        sizeDistribution: const [],
        calculatedAt: DateTime.now(),
      );
    }

    final records = _box!.values.toList();
    final totalImages = records.length;

    AppLogger.d('Calculating statistics for $totalImages images', 'Gallery');

    final totalSizeBytes = records.fold(0, (sum, r) => sum + r.fileSize);

    return GalleryStatistics(
      totalImages: totalImages,
      totalSizeBytes: totalSizeBytes,
      averageFileSizeBytes: totalImages > 0 ? totalSizeBytes / totalImages : 0.0,
      favoriteCount: records.where((r) => r.isFavorite).length,
      taggedImageCount: records.where((r) => r.userTags.isNotEmpty).length,
      imagesWithMetadata: records.where((r) => r.params.width > 0 && r.params.height > 0).length,
      resolutionDistribution: _calculateResolutionDistribution(records, totalImages),
      modelDistribution: _calculateModelDistribution(records, totalImages),
      samplerDistribution: _calculateSamplerDistribution(records, totalImages),
      sizeDistribution: _calculateSizeDistribution(records, totalImages),
      calculatedAt: DateTime.now(),
    );
  }

  /// 计算分布统计的通用方法
  List<T> _calculateDistribution<T>({
    required List<GenerationRecord> records,
    required int totalImages,
    required String? Function(GenerationRecord) getKey,
    required T Function(String key, int count, double percentage) createStat,
  }) {
    final counts = <String, int>{};

    for (final record in records) {
      final key = getKey(record);
      if (key != null && key.isNotEmpty) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .map(
          (entry) => createStat(
            entry.key,
            entry.value,
            totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
          ),
        )
        .toList();
  }

  /// 计算分辨率分布统计
  List<ResolutionStatistics> _calculateResolutionDistribution(
    List<GenerationRecord> records,
    int totalImages,
  ) {
    return _calculateDistribution<ResolutionStatistics>(
      records: records,
      totalImages: totalImages,
      getKey: (r) =>
          (r.params.width > 0 && r.params.height > 0) ? '${r.params.width}x${r.params.height}' : null,
      createStat: (key, count, pct) => ResolutionStatistics(
        label: key,
        count: count,
        percentage: pct,
      ),
    );
  }

  /// 计算模型分布统计
  List<ModelStatistics> _calculateModelDistribution(
    List<GenerationRecord> records,
    int totalImages,
  ) {
    return _calculateDistribution<ModelStatistics>(
      records: records,
      totalImages: totalImages,
      getKey: (r) => r.params.model.isNotEmpty ? r.params.model : null,
      createStat: (key, count, pct) => ModelStatistics(
        modelName: key,
        count: count,
        percentage: pct,
      ),
    );
  }

  /// 计算采样器分布统计
  List<SamplerStatistics> _calculateSamplerDistribution(
    List<GenerationRecord> records,
    int totalImages,
  ) {
    return _calculateDistribution<SamplerStatistics>(
      records: records,
      totalImages: totalImages,
      getKey: (r) => r.params.sampler.isNotEmpty ? _formatSamplerName(r.params.sampler) : null,
      createStat: (key, count, pct) => SamplerStatistics(
        samplerName: key,
        count: count,
        percentage: pct,
      ),
    );
  }

  /// 格式化采样器名称（k_euler_ancestral -> Euler Ancestral）
  String _formatSamplerName(String sampler) {
    return sampler
        .replaceAll('k_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// 计算文件大小分布统计
  List<SizeDistributionStatistics> _calculateSizeDistribution(
    List<GenerationRecord> records,
    int totalImages,
  ) {
    const mb = 1024 * 1024;
    final sizeRanges = <String, int>{'< 1 MB': 0, '1-2 MB': 0, '2-5 MB': 0, '5-10 MB': 0, '> 10 MB': 0};

    for (final record in records) {
      final sizeMB = record.fileSize / mb;
      final key = sizeMB < 1
          ? '< 1 MB'
          : sizeMB < 2
              ? '1-2 MB'
              : sizeMB < 5
                  ? '2-5 MB'
                  : sizeMB < 10
                      ? '5-10 MB'
                      : '> 10 MB';
      sizeRanges[key] = sizeRanges[key]! + 1;
    }

    return sizeRanges.entries
        .where((e) => e.value > 0)
        .map(
          (e) => SizeDistributionStatistics(
            label: e.key,
            count: e.value,
            percentage: totalImages > 0 ? (e.value / totalImages) * 100 : 0.0,
          ),
        )
        .toList();
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    if (_box == null) return;

    for (final record in _box!.values) {
      if (record.filePath != null) {
        try {
          final file = File(record.filePath!);
          if (await file.exists()) await file.delete();
        } catch (e) {
          AppLogger.w('Failed to delete image: $e', 'Gallery');
        }
      }
    }

    await _box!.clear();
    AppLogger.d('All records cleared', 'Gallery');
  }
}

/// GalleryRepository Provider
@riverpod
GalleryRepository galleryRepository(Ref ref) {
  final thumbnailCacheService = ref.watch(thumbnailCacheServiceProvider);
  final repo = GalleryRepository(thumbnailCacheService: thumbnailCacheService);
  // 初始化在应用启动时进行
  return repo;
}
