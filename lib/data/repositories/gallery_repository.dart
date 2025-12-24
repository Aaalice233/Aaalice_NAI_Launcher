import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/generation_record.dart';

part 'gallery_repository.g.dart';

/// 画廊数据仓库
///
/// 管理生成记录的 CRUD 操作和持久化
class GalleryRepository {
  /// Hive Box
  Box get _box => Hive.box(StorageKeys.galleryBox);

  /// 存储键
  static const String _recordsKey = 'generation_records';

  /// 最大历史记录数量
  static const int maxRecords = 500;

  /// 图像保存目录
  Directory? _imageDir;

  /// 初始化
  Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _imageDir = Directory('${appDir.path}/nai_launcher/images');
      if (!await _imageDir!.exists()) {
        await _imageDir!.create(recursive: true);
      }
      AppLogger.d('GalleryRepository initialized: ${_imageDir!.path}', 'Gallery');
    } catch (e, stack) {
      AppLogger.e('Failed to init GalleryRepository: $e', e, stack, 'Gallery');
    }
  }

  /// 获取所有记录
  List<GenerationRecord> getAllRecords() {
    try {
      final data = _box.get(_recordsKey);
      if (data == null) return [];

      final List<dynamic> jsonList = jsonDecode(data as String) as List<dynamic>;
      return jsonList
          .map((json) => GenerationRecord.fromJson(json as Map<String, dynamic>))
          .toList();
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
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'nai_$timestamp.png';
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

    // 保存到存储
    final records = getAllRecords();
    records.insert(0, record);

    // 限制记录数量
    if (records.length > maxRecords) {
      final removed = records.sublist(maxRecords);
      records.removeRange(maxRecords, records.length);

      // 清理被删除记录的图像文件
      for (final r in removed) {
        if (r.filePath != null) {
          try {
            final file = File(r.filePath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            AppLogger.w('Failed to delete old image: $e', 'Gallery');
          }
        }
      }
    }

    await _saveRecords(records);
    AppLogger.d('Record added: ${record.id}', 'Gallery');

    return record;
  }

  /// 更新记录
  Future<void> updateRecord(GenerationRecord record) async {
    final records = getAllRecords();
    final index = records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      records[index] = record;
      await _saveRecords(records);
      AppLogger.d('Record updated: ${record.id}', 'Gallery');
    }
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    final records = getAllRecords();
    final record = records.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Record not found'),
    );

    // 删除图像文件
    if (record.filePath != null) {
      try {
        final file = File(record.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        AppLogger.w('Failed to delete image file: $e', 'Gallery');
      }
    }

    records.removeWhere((r) => r.id == id);
    await _saveRecords(records);
    AppLogger.d('Record deleted: $id', 'Gallery');
  }

  /// 批量删除记录
  Future<void> deleteRecords(List<String> ids) async {
    final records = getAllRecords();

    for (final id in ids) {
      final record = records.firstWhere(
        (r) => r.id == id,
        orElse: () => throw Exception('Record not found'),
      );

      // 删除图像文件
      if (record.filePath != null) {
        try {
          final file = File(record.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          AppLogger.w('Failed to delete image file: $e', 'Gallery');
        }
      }
    }

    records.removeWhere((r) => ids.contains(r.id));
    await _saveRecords(records);
    AppLogger.d('Deleted ${ids.length} records', 'Gallery');
  }

  /// 切换收藏状态
  Future<GenerationRecord> toggleFavorite(String id) async {
    final records = getAllRecords();
    final index = records.indexWhere((r) => r.id == id);
    if (index == -1) throw Exception('Record not found');

    final record = records[index];
    final updated = record.copyWith(isFavorite: !record.isFavorite);
    records[index] = updated;

    await _saveRecords(records);
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

      final timestamp = record.createdAt.millisecondsSinceEpoch;
      final fileName = 'nai_export_$timestamp.png';
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
    final records = getAllRecords();
    final lowerQuery = query.toLowerCase();

    return records.where((r) {
      return r.params.prompt.toLowerCase().contains(lowerQuery) ||
          r.params.negativePrompt.toLowerCase().contains(lowerQuery) ||
          r.userTags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// 应用筛选条件
  List<GenerationRecord> filterRecords(GalleryFilter filter) {
    var records = getAllRecords();

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
    final records = getAllRecords();
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
    final records = getAllRecords();

    // 删除所有图像文件
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

    await _box.delete(_recordsKey);
    AppLogger.d('All records cleared', 'Gallery');
  }

  /// 保存记录到存储
  Future<void> _saveRecords(List<GenerationRecord> records) async {
    final jsonList = records.map((r) => r.toJson()).toList();
    await _box.put(_recordsKey, jsonEncode(jsonList));
  }
}

/// GalleryRepository Provider
@riverpod
GalleryRepository galleryRepository(Ref ref) {
  final repo = GalleryRepository();
  // 初始化在应用启动时进行
  return repo;
}
