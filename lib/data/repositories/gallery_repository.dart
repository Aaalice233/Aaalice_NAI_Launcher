import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database_providers.dart';
import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/gallery_statistics.dart';
import '../models/gallery/generation_record.dart';

part 'gallery_repository.g.dart';

/// 画廊仓库 Provider
///
/// 提供对 GalleryDataSource 的访问
@Riverpod(keepAlive: true)
Future<GalleryDataSource> galleryRepository(Ref ref) async {
  final dbManager = await ref.watch(databaseManagerProvider.future);
  final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');
  if (dataSource == null) {
    throw StateError('GalleryDataSource not found');
  }
  return dataSource;
}

/// 画廊仓库（兼容层）
///
/// 这是一个简化的兼容层，用于支持尚未完全迁移到 V2 架构的代码。
class GalleryRepository {
  final List<GenerationRecord> _records = [];
  bool _initialized = false;

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;
    AppLogger.w('GalleryRepository.init() called - this is a compatibility stub', 'GalleryRepository');
    _initialized = true;
  }

  /// 获取所有记录
  Future<List<GenerationRecord>> getAllRecords() async {
    return List.unmodifiable(_records);
  }

  /// 获取记录
  Future<GenerationRecord?> getRecord(String id) async {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 添加记录（兼容方法）
  Future<GenerationRecord?> addRecord({
    required Uint8List imageData,
    required GenerationParamsSnapshot params,
    bool saveToFile = true,
  }) async {
    final record = GenerationRecord.create(
      imageData: imageData,
      params: params,
    );
    _records.add(record);
    return record;
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
  }

  /// 批量删除记录
  Future<void> deleteRecords(List<String> ids) async {
    _records.removeWhere((r) => ids.contains(r.id));
  }

  /// 更新记录
  Future<void> updateRecord(GenerationRecord record) async {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
    }
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String id) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      final record = _records[index];
      _records[index] = record.copyWith(isFavorite: !record.isFavorite);
    }
  }

  /// 获取缩略图
  Future<Uint8List?> getThumbnail(String id) async {
    return null;
  }

  /// 过滤记录
  List<GenerationRecord> filterRecords(GalleryFilter filter) {
    return _records.where((record) {
      if (filter.favoritesOnly && !record.isFavorite) return false;
      if (filter.vibeOnly && !record.hasVibeMetadata) return false;
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        if (!record.params.prompt.toLowerCase().contains(query)) return false;
      }
      return true;
    }).toList();
  }

  /// 获取图像数据
  Future<Uint8List?> getImageData(GenerationRecord record) async {
    if (record.filePath != null) {
      try {
        final file = File(record.filePath!);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        AppLogger.w('Failed to read image file: $e', 'GalleryRepository');
      }
    }
    return record.imageData;
  }

  /// 导出图像
  Future<String?> exportImage(GenerationRecord record, String targetDir) async {
    try {
      final data = await getImageData(record);
      if (data == null) return null;

      final fileName = '${record.id}.png';
      final targetFile = File('$targetDir/$fileName');
      await targetFile.writeAsBytes(data);
      return targetFile.path;
    } catch (e) {
      AppLogger.e('Failed to export image', e, null, 'GalleryRepository');
      return null;
    }
  }

  /// 获取统计信息
  GalleryStatistics getStats() {
    return GalleryStatistics(
      totalImages: _records.length,
      totalSizeBytes: _records.fold(0, (sum, r) => sum + r.fileSize),
      averageFileSizeBytes: _records.isEmpty
          ? 0
          : _records.fold(0, (sum, r) => sum + r.fileSize) / _records.length,
      favoriteCount: _records.where((r) => r.isFavorite).length,
      taggedImageCount: _records.where((r) => r.userTags.isNotEmpty).length,
      imagesWithMetadata: _records.where((r) => r.hasImage).length,
      calculatedAt: DateTime.now(),
    );
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    _records.clear();
  }

  /// 关闭
  Future<void> dispose() async {}
}
