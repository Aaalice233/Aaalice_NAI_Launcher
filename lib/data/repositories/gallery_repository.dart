import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/generation_record.dart';
import '../services/gallery_migration_service.dart';

part 'gallery_repository.g.dart';

/// 画廊数据仓库
///
/// 管理生成记录的 CRUD 操作和持久化
/// 使用 O(1) 单条 Hive 对象操作替代 O(N) JSON 序列化
class GalleryRepository {
  /// 新 Hive Box 名称 (迁移后的版本)
  static const String _newBoxName = '${StorageKeys.galleryBox}_v2';

  /// 新 Box 实例
  Box<GenerationRecord>? _newBox;

  /// 最大记录数量 (移除 500 限制，使用更大值)
  static const int maxRecords = 5000;

  /// 图像保存目录
  Directory? _imageDir;

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

      // 打开新的 Hive Box
      _newBox = await Hive.openBox<GenerationRecord>(_newBoxName);

      // 执行数据迁移 (如果尚未迁移)
      final migrationService = GalleryMigrationService();
      final (success, count, error) = await migrationService.migrate();
      if (success) {
        AppLogger.i('GalleryRepository initialized with $count migrated records', 'Gallery');
      } else {
        AppLogger.e('Migration failed: $error', null, null, 'Gallery');
      }
    } catch (e, stack) {
      AppLogger.e('Failed to init GalleryRepository: $e', e, stack, 'Gallery');
    }
  }

  /// 生成基于提示词的智能文件名
  ///
  /// 格式: NAI_[Date]_[PromptSnippet].png
  /// - 日期时间戳避免文件名冲突
  /// - 提示词片段：前30个字符，移除特殊字符
  String _generateFileName(String? prompt, {String prefix = 'nai'}) {
    // 生成时间戳（ISO 8601 格式，移除冒号以兼容文件系统）
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);

    // 如果没有提示词，使用纯时间戳格式
    if (prompt == null || prompt.isEmpty) {
      return '${prefix}_$timestamp.png';
    }

    // 截取提示词片段，移除特殊字符
    String snippet = prompt
        .substring(0, min(30, prompt.length))
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // 移除 Windows 文件系统非法字符
        .replaceAll(' ', '_') // 空格替换为下划线
        .replaceAll(',', '') // 移除逗号
        .trim();

    // 如果处理后为空，使用默认名称
    if (snippet.isEmpty) snippet = 'generated';

    return '${prefix}_${timestamp}_$snippet.png';
  }

  /// 获取所有记录
  List<GenerationRecord> getAllRecords() {
    try {
      if (_newBox == null || _newBox!.isEmpty) {
        return [];
      }

      // 从新 Box 读取所有记录
      final records = _newBox!.values.toList();

      // 按创建时间倒序排列
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

    // 保存图像到文件
    if (saveToFile && _imageDir != null) {
      try {
        final fileName = _generateFileName(params.prompt);
        final file = File('${_imageDir!.path}/$fileName');
        await file.writeAsBytes(imageData);
        filePath = file.path;
        AppLogger.d('Image saved to: $filePath', 'Gallery');
      } catch (e) {
        AppLogger.w('Failed to save image to file: $e', 'Gallery');
      }
    }

    // 创建记录
    final record = GenerationRecord.create(
      imageData: imageData,
      params: params,
      filePath: filePath,
    );

    // 检查是否超出最大数量限制
    if (_newBox != null && _newBox!.length >= maxRecords) {
      // 删除最旧的记录
      final oldestRecord = _newBox!.values
          .reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b);
      await _deleteRecordInternal(oldestRecord);
    }

    // 直接写入新 Box (O(1))
    await _newBox!.put(record.id, record);
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
    await _newBox!.delete(record.id);
  }

  /// 更新记录
  Future<void> updateRecord(GenerationRecord record) async {
    if (_newBox == null) return;

    try {
      await _newBox!.put(record.id, record);
      AppLogger.d('Record updated: ${record.id}', 'Gallery');
    } catch (e, stack) {
      AppLogger.e('Failed to update record: $e', e, stack, 'Gallery');
    }
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    if (_newBox == null) return;

    try {
      final record = _newBox!.get(id);
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
    if (_newBox == null) return;

    try {
      for (final id in ids) {
        final record = _newBox!.get(id);
        if (record != null) {
          await _deleteRecordInternal(record);
        }
      }
      AppLogger.d('Deleted ${ids.length} records', 'Gallery');
    } catch (e, stack) {
      AppLogger.e('Failed to delete records: $e', e, stack, 'Gallery');
    }
  }

  /// 切换收藏状态
  Future<GenerationRecord> toggleFavorite(String id) async {
    if (_newBox == null) throw Exception('Repository not initialized');

    final record = _newBox!.get(id);
    if (record == null) throw Exception('Record not found');

    final updated = record.copyWith(isFavorite: !record.isFavorite);
    await _newBox!.put(id, updated);

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

      final fileName = _generateFileName(record.params.prompt, prefix: 'nai_export');
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
    if (_newBox == null || _newBox!.isEmpty) return [];

    final lowerQuery = query.toLowerCase();

    return _newBox!.values.where((r) {
      return r.params.prompt.toLowerCase().contains(lowerQuery) ||
          r.params.negativePrompt.toLowerCase().contains(lowerQuery) ||
          r.userTags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 应用筛选条件
  List<GenerationRecord> filterRecords(GalleryFilter filter) {
    var records = _newBox?.values.toList() ?? [];

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

    // 模型筛选
    if (filter.modelFilter != null && filter.modelFilter!.isNotEmpty) {
      records = records.where((r) => r.params.model == filter.modelFilter).toList();
    }

    // 日期筛选
    if (filter.dateFrom != null) {
      records = records.where((r) => r.createdAt.isAfter(filter.dateFrom!)).toList();
    }
    if (filter.dateTo != null) {
      records = records.where((r) => r.createdAt.isBefore(filter.dateTo!)).toList();
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
        break;
      case GallerySortOrder.oldestFirst:
        records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case GallerySortOrder.favoritesFirst:
        records.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return records;
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    if (_newBox == null) {
      return {'totalCount': 0, 'favoritesCount': 0, 'totalSize': 0, 'maxRecords': maxRecords};
    }

    final records = _newBox!.values.toList();
    final favorites = records.where((r) => r.isFavorite).length;
    final totalSize = records.fold<int>(0, (sum, r) => sum + r.fileSize);

    return {
      'totalCount': records.length,
      'favoritesCount': favorites,
      'totalSize': totalSize,
      'maxRecords': maxRecords,
    };
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    if (_newBox == null) return;

    // 获取所有记录以删除图像文件
    final records = _newBox!.values.toList();
    for (final record in records) {
      if (record.filePath != null) {
        try {
          final file = File(record.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          AppLogger.w('Failed to delete image: $e', 'Gallery');
        }
      }
    }

    // 清空 Box
    await _newBox!.clear();
    AppLogger.d('All records cleared', 'Gallery');
  }
}

/// GalleryRepository Provider
@riverpod
GalleryRepository galleryRepository(Ref ref) {
  final repo = GalleryRepository();
  // 初始化在应用启动时进行
  return repo;
}
