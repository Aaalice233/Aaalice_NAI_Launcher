import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/image_collection.dart';
import '../../data/repositories/collection_repository.dart';

part 'collection_provider.freezed.dart';
part 'collection_provider.g.dart';

/// Provider for CollectionRepository
@Riverpod(keepAlive: true)
CollectionRepository collectionRepository(Ref ref) {
  return CollectionRepository.instance;
}

/// 集合状态
@freezed
class CollectionState with _$CollectionState {
  const factory CollectionState({
    /// 所有集合
    @Default([]) List<ImageCollection> collections,

    /// 是否正在加载
    @Default(false) bool isLoading,

    /// 当前正在操作的集合ID
    String? activeCollectionId,

    /// 错误信息
    String? error,
  }) = _CollectionState;

  const CollectionState._();

  /// 集合数量
  int get collectionCount => collections.length;

  /// 是否有错误
  bool get hasError => error != null;

  /// 获取当前活动的集合
  ImageCollection? get activeCollection {
    if (activeCollectionId == null) return null;
    return collections.where((c) => c.id == activeCollectionId).firstOrNull;
  }
}

/// 集合 Notifier
@Riverpod(keepAlive: true)
class CollectionNotifier extends _$CollectionNotifier {
  @override
  CollectionState build() {
    _repository = ref.read(collectionRepositoryProvider);
    // Don't auto-load - wait for explicit initialize() call
    // This allows tests to override the repository before loading
    return const CollectionState();
  }

  late final CollectionRepository _repository;

  /// 加载所有集合
  Future<void> _loadCollections() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final collections = _repository.getAllCollections();
      state = state.copyWith(
        collections: collections,
        isLoading: false,
      );
      AppLogger.d(
        'Loaded ${collections.length} collections',
        'CollectionNotifier',
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      AppLogger.e(
        'Failed to load collections',
        e,
        null,
        'CollectionNotifier',
      );
    }
  }

  /// 初始化：加载所有集合
  Future<void> initialize() async {
    // Only load if not already loaded
    if (state.collections.isEmpty) {
      await _loadCollections();
    }
  }

  /// 刷新集合列表
  Future<void> refresh() async {
    await _loadCollections();
  }

  /// 创建新集合
  ///
  /// [name] 集合名称
  /// [description] 集合描述（可选）
  /// 返回创建的集合，失败返回 null
  Future<ImageCollection?> createCollection(
    String name, {
    String? description,
  }) async {
    try {
      // 清除之前的错误
      state = state.copyWith(error: null);

      final collection = await _repository.createCollection(
        name,
        description: description,
      );

      // 重新加载集合列表
      await _loadCollections();

      AppLogger.i(
        'Created collection: ${collection.name}',
        'CollectionNotifier',
      );

      return collection;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      AppLogger.e(
        'Failed to create collection: $name',
        e,
        null,
        'CollectionNotifier',
      );
      return null;
    }
  }

  /// 更新集合
  ///
  /// [collection] 要更新的集合
  /// 返回更新是否成功
  Future<bool> updateCollection(ImageCollection collection) async {
    try {
      state = state.copyWith(error: null);

      final success = await _repository.updateCollection(collection);

      if (success) {
        // 重新加载集合列表
        await _loadCollections();

        AppLogger.i(
          'Updated collection: ${collection.name}',
          'CollectionNotifier',
        );
      }

      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      AppLogger.e(
        'Failed to update collection: ${collection.id}',
        e,
        null,
        'CollectionNotifier',
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
      state = state.copyWith(error: null);

      final success = await _repository.deleteCollection(id);

      if (success) {
        // 如果删除的是当前活动集合，清除活动集合
        if (state.activeCollectionId == id) {
          state = state.copyWith(activeCollectionId: null);
        }

        // 重新加载集合列表
        await _loadCollections();

        AppLogger.i(
          'Deleted collection: $id',
          'CollectionNotifier',
        );
      }

      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      AppLogger.e(
        'Failed to delete collection: $id',
        e,
        null,
        'CollectionNotifier',
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
      state = state.copyWith(error: null);

      final addedCount =
          await _repository.addImagesToCollection(collectionId, imagePaths);

      // 重新加载集合列表以更新数据
      await _loadCollections();

      if (addedCount > 0) {
        AppLogger.i(
          'Added $addedCount images to collection: $collectionId',
          'CollectionNotifier',
        );
      }

      return addedCount;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      AppLogger.e(
        'Failed to add images to collection: $collectionId',
        e,
        null,
        'CollectionNotifier',
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
      state = state.copyWith(error: null);

      final removedCount = await _repository
          .removeImagesFromCollection(collectionId, imagePaths);

      // 重新加载集合列表以更新数据
      await _loadCollections();

      if (removedCount > 0) {
        AppLogger.i(
          'Removed $removedCount images from collection: $collectionId',
          'CollectionNotifier',
        );
      }

      return removedCount;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      AppLogger.e(
        'Failed to remove images from collection: $collectionId',
        e,
        null,
        'CollectionNotifier',
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
    return _repository.isImageInCollection(collectionId, imagePath);
  }

  /// 获取指定集合
  ///
  /// [id] 集合ID
  /// 返回集合，不存在返回 null
  ImageCollection? getCollection(String id) {
    return _repository.getCollection(id);
  }

  /// 设置当前活动的集合
  ///
  /// [id] 集合ID，null 表示清除活动集合
  void setActiveCollection(String? id) {
    state = state.copyWith(activeCollectionId: id);
    AppLogger.d(
      'Set active collection: ${id ?? "none"}',
      'CollectionNotifier',
    );
  }

  /// 清除错误状态
  void clearError() {
    state = state.copyWith(error: null);
  }
}
