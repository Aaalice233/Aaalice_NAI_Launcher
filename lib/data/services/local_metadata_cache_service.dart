import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../models/gallery/nai_image_metadata.dart';

part 'local_metadata_cache_service.g.dart';

/// 本地图片元数据缓存服务
///
/// 使用 Hive 存储解析后的 NAI 元数据，避免重复解析文件
class LocalMetadataCacheService {
  /// 获取缓存 Box
  Box get _cacheBox => Hive.box(StorageKeys.localMetadataCacheBox);

  /// 获取缓存的元数据
  ///
  /// 返回 {'ts': DateTime, 'meta': NaiImageMetadata} 或 null（不存在时）
  Map<String, dynamic>? get(String filePath) {
    final jsonStr = _cacheBox.get(filePath) as String?;
    if (jsonStr == null) return null;

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'ts': DateTime.fromMillisecondsSinceEpoch(data['ts'] as int),
        'meta': NaiImageMetadata.fromJson(data['meta'] as Map<String, dynamic>),
      };
    } catch (e) {
      // 解析失败，返回 null
      return null;
    }
  }

  /// 存储元数据到缓存
  Future<void> put(
    String filePath,
    NaiImageMetadata metadata,
    DateTime timestamp,
  ) async {
    final jsonStr = jsonEncode({
      'ts': timestamp.millisecondsSinceEpoch,
      'meta': metadata.toJson(),
    });
    await _cacheBox.put(filePath, jsonStr);
  }

  /// 检查缓存是否存在
  bool contains(String filePath) {
    return _cacheBox.containsKey(filePath);
  }

  /// 删除指定文件的缓存
  Future<void> delete(String filePath) async {
    await _cacheBox.delete(filePath);
  }

  /// 清空所有缓存
  Future<void> clear() async {
    await _cacheBox.clear();
  }
}

/// LocalMetadataCacheService Provider
@Riverpod(keepAlive: true)
LocalMetadataCacheService localMetadataCacheService(Ref ref) {
  return LocalMetadataCacheService();
}
