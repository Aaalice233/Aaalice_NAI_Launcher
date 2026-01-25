import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../core/constants/storage_keys.dart';

part 'favorites_storage_service.g.dart';

/// 收藏夹存储服务
///
/// 负责收藏图片的加载、保存、删除等操作
/// 使用 Hive 本地存储，支持收藏状态的持久化
class FavoritesStorageService {
  static const String _favoritesKey = 'favorites';

  Box? _box;
  Future<void>? _initFuture;

  /// 初始化
  Future<void> init() async {
    _box = await Hive.openBox(StorageKeys.favoritesBox);
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_box != null && _box!.isOpen) return;

    // 使用 Future 锁避免并发初始化
    _initFuture ??= init();
    await _initFuture;
  }

  /// 加载所有收藏图片路径
  Future<Set<String>> loadFavorites() async {
    await _ensureInit();
    try {
      final data = _box?.get(_favoritesKey);
      if (data != null) {
        if (data is String) {
          // JSON 格式: 数组字符串
          final List<dynamic> json = jsonDecode(data);
          return json.cast<String>().toSet();
        } else if (data is List) {
          // 直接的 List 格式
          return data.cast<String>().toSet();
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load favorites: $e', 'Favorites');
    }
    return <String>{};
  }

  /// 保存收藏列表
  Future<void> saveFavorites(Set<String> favorites) async {
    await _ensureInit();
    try {
      final json = jsonEncode(favorites.toList());
      await _box?.put(_favoritesKey, json);
      AppLogger.d('Saved ${favorites.length} favorites', 'Favorites');
    } catch (e) {
      AppLogger.e('Failed to save favorites: $e', 'Favorites');
      rethrow;
    }
  }

  /// 添加收藏
  Future<bool> addFavorite(String imagePath) async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      if (favorites.contains(imagePath)) {
        AppLogger.d('Image already in favorites: $imagePath', 'Favorites');
        return false;
      }

      favorites.add(imagePath);
      await saveFavorites(favorites);
      AppLogger.i('Added to favorites: $imagePath', 'Favorites');
      return true;
    } catch (e) {
      AppLogger.e('Failed to add favorite: $e', 'Favorites');
      rethrow;
    }
  }

  /// 移除收藏
  Future<bool> removeFavorite(String imagePath) async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      if (!favorites.contains(imagePath)) {
        AppLogger.d('Image not in favorites: $imagePath', 'Favorites');
        return false;
      }

      favorites.remove(imagePath);
      await saveFavorites(favorites);
      AppLogger.i('Removed from favorites: $imagePath', 'Favorites');
      return true;
    } catch (e) {
      AppLogger.e('Failed to remove favorite: $e', 'Favorites');
      rethrow;
    }
  }

  /// 切换收藏状态
  ///
  /// 如果图片已收藏则移除，否则添加
  /// 返回切换后的状态（true 表示已收藏，false 表示未收藏）
  Future<bool> toggleFavorite(String imagePath) async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      if (favorites.contains(imagePath)) {
        await removeFavorite(imagePath);
        return false;
      } else {
        await addFavorite(imagePath);
        return true;
      }
    } catch (e) {
      AppLogger.e('Failed to toggle favorite: $e', 'Favorites');
      rethrow;
    }
  }

  /// 检查图片是否已收藏
  Future<bool> isFavorite(String imagePath) async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      return favorites.contains(imagePath);
    } catch (e) {
      AppLogger.e('Failed to check favorite status: $e', 'Favorites');
      return false;
    }
  }

  /// 获取收藏数量
  Future<int> getFavoritesCount() async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      return favorites.length;
    } catch (e) {
      AppLogger.e('Failed to get favorites count: $e', 'Favorites');
      return 0;
    }
  }

  /// 清除所有收藏
  Future<void> clearAllFavorites() async {
    await _ensureInit();
    try {
      await _box?.delete(_favoritesKey);
      AppLogger.i('Cleared all favorites', 'Favorites');
    } catch (e) {
      AppLogger.e('Failed to clear favorites: $e', 'Favorites');
      rethrow;
    }
  }

  /// 批量添加收藏
  Future<int> addMultipleFavorites(List<String> imagePaths) async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      var addedCount = 0;

      for (final path in imagePaths) {
        if (!favorites.contains(path)) {
          favorites.add(path);
          addedCount++;
        }
      }

      if (addedCount > 0) {
        await saveFavorites(favorites);
        AppLogger.i('Added $addedCount images to favorites', 'Favorites');
      }

      return addedCount;
    } catch (e) {
      AppLogger.e('Failed to add multiple favorites: $e', 'Favorites');
      rethrow;
    }
  }

  /// 批量移除收藏
  Future<int> removeMultipleFavorites(List<String> imagePaths) async {
    await _ensureInit();
    try {
      final favorites = await loadFavorites();
      var removedCount = 0;

      for (final path in imagePaths) {
        if (favorites.remove(path)) {
          removedCount++;
        }
      }

      if (removedCount > 0) {
        await saveFavorites(favorites);
        AppLogger.i('Removed $removedCount images from favorites', 'Favorites');
      }

      return removedCount;
    } catch (e) {
      AppLogger.e('Failed to remove multiple favorites: $e', 'Favorites');
      rethrow;
    }
  }
}

/// Provider
@Riverpod(keepAlive: true)
FavoritesStorageService favoritesStorageService(Ref ref) {
  return FavoritesStorageService();
}
