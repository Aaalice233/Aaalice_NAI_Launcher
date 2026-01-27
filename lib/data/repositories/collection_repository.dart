import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/image_collection.dart';

/// 收藏集合仓库
///
/// 负责管理图片集合的 CRUD 操作
class CollectionRepository {
  CollectionRepository._();

  /// 获取集合 Box
  Box get _collectionsBox => Hive.box(StorageKeys.collectionsBox);

  /// 创建新集合
  ///
  /// [name] 集合名称
  /// [description] 集合描述（可选）
  /// 返回创建的集合
  Future<ImageCollection> createCollection(
    String name, {
    String? description,
  }) async {
    final id = _generateId(name);
    final now = DateTime.now();

    final collection = ImageCollection(
      id: id,
      name: name,
      description: description,
      imagePaths: [],
      createdAt: now,
    );

    await _collectionsBox.put(id, collection.toJson());
    AppLogger.i(
      'Created collection: $name (${collection.imageCount} images)',
      'CollectionRepo',
    );

    return collection;
  }

  /// 获取指定集合
  ///
  /// [id] 集合ID
  /// 返回集合，不存在返回 null
  ImageCollection? getCollection(String id) {
    try {
      final data = _collectionsBox.get(id);
      if (data == null) return null;

      return ImageCollection.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      AppLogger.e(
        'Failed to get collection: $id',
        e,
        null,
        'CollectionRepo',
      );
      return null;
    }
  }

  /// 获取所有集合
  ///
  /// 返回按创建时间降序排列的集合列表（最新优先）
  List<ImageCollection> getAllCollections() {
    try {
      final collections = _collectionsBox.values.map((data) {
        return ImageCollection.fromJson(
          Map<String, dynamic>.from(data as Map),
        );
      }).toList()
        // 降序排序（最新优先）
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      AppLogger.d(
        'Retrieved ${collections.length} collections',
        'CollectionRepo',
      );

      return collections;
    } catch (e) {
      AppLogger.e(
        'Failed to get all collections',
        e,
        null,
        'CollectionRepo',
      );
      return [];
    }
  }

  /// 更新集合
  ///
  /// [collection] 要更新的集合
  /// 返回更新是否成功
  Future<bool> updateCollection(ImageCollection collection) async {
    try {
      await _collectionsBox.put(collection.id, collection.toJson());
      AppLogger.i(
        'Updated collection: ${collection.name}',
        'CollectionRepo',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Failed to update collection: ${collection.id}',
        e,
        null,
        'CollectionRepo',
      );
      return false;
    }
  }

  /// 删除集合
  ///
  /// [id] 集合ID
  /// 返回删除是否成功
  Future<bool> deleteCollection(String id) async {
    try {
      await _collectionsBox.delete(id);
      AppLogger.i(
        'Deleted collection: $id',
        'CollectionRepo',
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Failed to delete collection: $id',
        e,
        null,
        'CollectionRepo',
      );
      return false;
    }
  }

  /// 添加图片到集合
  ///
  /// [collectionId] 集合ID
  /// [imagePaths] 图片路径列表
  /// 返回添加的图片数量
  Future<int> addImagesToCollection(
    String collectionId,
    List<String> imagePaths,
  ) async {
    try {
      final collection = getCollection(collectionId);
      if (collection == null) {
        AppLogger.w(
          'Collection not found: $collectionId',
          'CollectionRepo',
        );
        return 0;
      }

      // 去重：只添加不存在的图片
      final existingPaths = Set.of(collection.imagePaths);
      final newPaths =
          imagePaths.where((path) => !existingPaths.contains(path));

      if (newPaths.isEmpty) {
        AppLogger.d(
          'No new images to add to collection: ${collection.name}',
          'CollectionRepo',
        );
        return 0;
      }

      final updatedPaths = [...collection.imagePaths, ...newPaths];
      final updatedCollection = collection.copyWith(
        imagePaths: updatedPaths,
      );

      await updateCollection(updatedCollection);

      AppLogger.i(
        'Added ${newPaths.length} images to collection: ${collection.name}',
        'CollectionRepo',
      );

      return newPaths.length;
    } catch (e) {
      AppLogger.e(
        'Failed to add images to collection: $collectionId',
        e,
        null,
        'CollectionRepo',
      );
      return 0;
    }
  }

  /// 从集合移除图片
  ///
  /// [collectionId] 集合ID
  /// [imagePaths] 要移除的图片路径列表
  /// 返回移除的图片数量
  Future<int> removeImagesFromCollection(
    String collectionId,
    List<String> imagePaths,
  ) async {
    try {
      final collection = getCollection(collectionId);
      if (collection == null) {
        AppLogger.w(
          'Collection not found: $collectionId',
          'CollectionRepo',
        );
        return 0;
      }

      final pathsToRemove = Set.of(imagePaths);
      final updatedPaths = collection.imagePaths
          .where((path) => !pathsToRemove.contains(path))
          .toList();

      if (updatedPaths.length == collection.imagePaths.length) {
        AppLogger.d(
          'No images to remove from collection: ${collection.name}',
          'CollectionRepo',
        );
        return 0;
      }

      final removedCount = collection.imagePaths.length - updatedPaths.length;
      final updatedCollection = collection.copyWith(
        imagePaths: updatedPaths,
      );

      await updateCollection(updatedCollection);

      AppLogger.i(
        'Removed $removedCount images from collection: ${collection.name}',
        'CollectionRepo',
      );

      return removedCount;
    } catch (e) {
      AppLogger.e(
        'Failed to remove images from collection: $collectionId',
        e,
        null,
        'CollectionRepo',
      );
      return 0;
    }
  }

  /// 检查图片是否在集合中
  ///
  /// [collectionId] 集合ID
  /// [imagePath] 图片路径
  /// 返回图片是否在集合中
  bool isImageInCollection(String collectionId, String imagePath) {
    final collection = getCollection(collectionId);
    if (collection == null) return false;

    return collection.imagePaths.contains(imagePath);
  }

  /// 获取集合中图片数量
  ///
  /// [collectionId] 集合ID
  /// 返回图片数量，集合不存在返回 0
  int getCollectionImageCount(String collectionId) {
    final collection = getCollection(collectionId);
    return collection?.imageCount ?? 0;
  }

  /// 清空所有集合
  ///
  /// 主要用于测试
  Future<void> clearAllCollections() async {
    await _collectionsBox.clear();
    AppLogger.i(
      'Cleared all collections',
      'CollectionRepo',
    );
  }

  /// 生成集合ID
  ///
  /// 基于名称和时间戳生成唯一ID
  String _generateId(String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode('$name-$timestamp');
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }

  /// 单例实例
  static final CollectionRepository instance = CollectionRepository._();
}
