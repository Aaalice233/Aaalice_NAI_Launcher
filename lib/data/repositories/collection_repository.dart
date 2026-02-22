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
  static final CollectionRepository instance = CollectionRepository._();

  Box get _box => Hive.box(StorageKeys.collectionsBox);

  /// 创建新集合
  Future<ImageCollection> createCollection(String name, {String? description}) async {
    final collection = ImageCollection(
      id: _generateId(name),
      name: name,
      description: description,
      imagePaths: const [],
      createdAt: DateTime.now(),
    );

    await _box.put(collection.id, collection.toJson());
    AppLogger.i('Created collection: $name (${collection.imageCount} images)', 'CollectionRepo');

    return collection;
  }

  /// 获取指定集合
  ImageCollection? getCollection(String id) {
    try {
      final data = _box.get(id);
      if (data == null) return null;
      return ImageCollection.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      AppLogger.e('Failed to get collection: $id', e, null, 'CollectionRepo');
      return null;
    }
  }

  /// 获取所有集合
  List<ImageCollection> getAllCollections() {
    try {
      final collections = _box.values
          .map((data) => ImageCollection.fromJson(Map<String, dynamic>.from(data as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      AppLogger.d('Retrieved ${collections.length} collections', 'CollectionRepo');
      return collections;
    } catch (e) {
      AppLogger.e('Failed to get all collections', e, null, 'CollectionRepo');
      return [];
    }
  }

  /// 更新集合
  Future<bool> updateCollection(ImageCollection collection) async {
    try {
      await _box.put(collection.id, collection.toJson());
      AppLogger.i('Updated collection: ${collection.name}', 'CollectionRepo');
      return true;
    } catch (e) {
      AppLogger.e('Failed to update collection: ${collection.id}', e, null, 'CollectionRepo');
      return false;
    }
  }

  /// 删除集合
  Future<bool> deleteCollection(String id) async {
    try {
      await _box.delete(id);
      AppLogger.i('Deleted collection: $id', 'CollectionRepo');
      return true;
    } catch (e) {
      AppLogger.e('Failed to delete collection: $id', e, null, 'CollectionRepo');
      return false;
    }
  }

  /// 添加图片到集合
  Future<int> addImagesToCollection(String collectionId, List<String> imagePaths) async {
    try {
      final collection = getCollection(collectionId);
      if (collection == null) {
        AppLogger.w('Collection not found: $collectionId', 'CollectionRepo');
        return 0;
      }

      final newPaths = imagePaths.where((p) => !collection.imagePaths.contains(p)).toList();
      if (newPaths.isEmpty) {
        AppLogger.d('No new images to add to collection: ${collection.name}', 'CollectionRepo');
        return 0;
      }

      await updateCollection(collection.copyWith(imagePaths: [...collection.imagePaths, ...newPaths]));
      AppLogger.i('Added ${newPaths.length} images to collection: ${collection.name}', 'CollectionRepo');

      return newPaths.length;
    } catch (e) {
      AppLogger.e('Failed to add images to collection: $collectionId', e, null, 'CollectionRepo');
      return 0;
    }
  }

  /// 从集合移除图片
  Future<int> removeImagesFromCollection(String collectionId, List<String> imagePaths) async {
    try {
      final collection = getCollection(collectionId);
      if (collection == null) {
        AppLogger.w('Collection not found: $collectionId', 'CollectionRepo');
        return 0;
      }

      final pathsToRemove = Set.of(imagePaths);
      final updatedPaths = collection.imagePaths.where((p) => !pathsToRemove.contains(p)).toList();

      if (updatedPaths.length == collection.imagePaths.length) {
        AppLogger.d('No images to remove from collection: ${collection.name}', 'CollectionRepo');
        return 0;
      }

      final removedCount = collection.imagePaths.length - updatedPaths.length;
      await updateCollection(collection.copyWith(imagePaths: updatedPaths));

      AppLogger.i('Removed $removedCount images from collection: ${collection.name}', 'CollectionRepo');
      return removedCount;
    } catch (e) {
      AppLogger.e('Failed to remove images from collection: $collectionId', e, null, 'CollectionRepo');
      return 0;
    }
  }

  /// 检查图片是否在集合中
  bool isImageInCollection(String collectionId, String imagePath) {
    final collection = getCollection(collectionId);
    return collection?.imagePaths.contains(imagePath) ?? false;
  }

  /// 获取集合中图片数量
  int getCollectionImageCount(String collectionId) {
    return getCollection(collectionId)?.imageCount ?? 0;
  }

  /// 清空所有集合
  Future<void> clearAllCollections() async {
    await _box.clear();
    AppLogger.i('Cleared all collections', 'CollectionRepo');
  }

  String _generateId(String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode('$name-$timestamp'));
    return hash.toString().substring(0, 16);
  }
}
