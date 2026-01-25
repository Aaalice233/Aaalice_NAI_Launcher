import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/prompt/tag_favorite.dart';
import '../constants/storage_keys.dart';

part 'tag_favorite_storage.g.dart';

/// 标签收藏存储服务 - 使用 Hive 持久化标签收藏数据
class TagFavoriteStorage {
  /// 获取已打开的 tag_favorites box
  Box get _favoritesBox => Hive.box(StorageKeys.tagFavoritesBox);

  /// 初始化存储 (box 应在 main.dart 中预先打开)
  Future<void> init() async {
    // Box 已在 main.dart 中预先打开
  }

  /// 添加收藏
  /// 如果已存在相同标签（相同文本），则覆盖
  Future<void> addFavorite(TagFavorite favorite) async {
    try {
      await _favoritesBox.put(favorite.id, favorite.toJson());
    } catch (e) {
      // 处理存储配额超限等错误
      if (e is HiveError) {
        throw TagFavoriteStorageException('Storage quota exceeded or error: ${e.message}');
      }
      rethrow;
    }
  }

  /// 删除收藏
  Future<void> removeFavorite(String favoriteId) async {
    try {
      await _favoritesBox.delete(favoriteId);
    } catch (e) {
      if (e is HiveError) {
        throw TagFavoriteStorageException('Failed to remove favorite: ${e.message}');
      }
      rethrow;
    }
  }

  /// 获取所有收藏
  List<TagFavorite> getFavorites() {
    try {
      final favoritesJson = _favoritesBox.values.toList();
      return favoritesJson.map((json) {
        return TagFavorite.fromJson(Map<String, dynamic>.from(json));
      }).toList();
    } catch (e) {
      // 如果反序列化失败，返回空列表
      return [];
    }
  }

  /// 根据标签文本查找收藏
  TagFavorite? getFavoriteByText(String tagText) {
    try {
      final favorites = getFavorites();
      for (final favorite in favorites) {
        if (favorite.tag.text == tagText) {
          return favorite;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查标签是否已收藏
  bool isFavorite(String tagText) {
    return getFavoriteByText(tagText) != null;
  }

  /// 清空所有收藏
  Future<void> clearFavorites() async {
    try {
      await _favoritesBox.clear();
    } catch (e) {
      if (e is HiveError) {
        throw TagFavoriteStorageException('Failed to clear favorites: ${e.message}');
      }
      rethrow;
    }
  }

  /// 获取收藏数量
  int get favoritesCount => _favoritesBox.length;

  // ==================== Lifecycle ====================

  /// 关闭存储
  Future<void> close() async {
    await _favoritesBox.close();
  }
}

/// TagFavoriteStorage Provider
@riverpod
TagFavoriteStorage tagFavoriteStorage(Ref ref) {
  final service = TagFavoriteStorage();
  // 注意：需要在应用启动时调用 init()
  return service;
}

/// 标签收藏存储异常
class TagFavoriteStorageException implements Exception {
  final String message;

  TagFavoriteStorageException(this.message);

  @override
  String toString() => 'TagFavoriteStorageException: $message';
}
