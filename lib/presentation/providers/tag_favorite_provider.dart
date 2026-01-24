import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/tag_favorite_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/prompt_tag.dart';
import '../../data/models/prompt/tag_favorite.dart';

part 'tag_favorite_provider.g.dart';

/// 标签收藏状态
class TagFavoriteState {
  final List<TagFavorite> favorites;
  final bool isLoading;
  final String? error;

  const TagFavoriteState({
    this.favorites = const [],
    this.isLoading = false,
    this.error,
  });

  TagFavoriteState copyWith({
    List<TagFavorite>? favorites,
    bool? isLoading,
    String? error,
  }) {
    return TagFavoriteState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 标签收藏 Provider
///
/// 管理标签收藏列表，支持添加、删除、切换收藏状态
/// 自动持久化到 Hive 存储
@riverpod
class TagFavoriteNotifier extends _$TagFavoriteNotifier {
  /// 存储服务
  late TagFavoriteStorage _storage;

  @override
  TagFavoriteState build() {
    _storage = ref.watch(tagFavoriteStorageProvider);

    // 加载收藏列表
    _loadFavorites();

    return const TagFavoriteState();
  }

  /// 从存储加载收藏列表
  void _loadFavorites() {
    try {
      final favorites = _storage.getFavorites();
      state = TagFavoriteState(favorites: favorites);
      AppLogger.d('Loaded ${favorites.length} favorites', 'TagFavoriteProvider');
    } catch (e, stack) {
      AppLogger.e('Failed to load favorites: $e', e, stack, 'TagFavoriteProvider');
      state = TagFavoriteState(
        favorites: [],
        error: e.toString(),
      );
    }
  }

  /// 根据标签查找收藏
  TagFavorite? _getFavoriteByTag(PromptTag tag) {
    try {
      for (final favorite in state.favorites) {
        if (favorite.tag.text == tag.text) {
          return favorite;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 添加收藏
  ///
  /// [tag] 要收藏的标签
  /// [notes] 可选备注
  /// [update] 如果已存在，是否更新（默认为 true）
  Future<void> addFavorite(
    PromptTag tag, {
    String? notes,
    bool update = true,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      // 检查是否已存在
      final existing = _getFavoriteByTag(tag);

      TagFavorite favorite;
      if (existing != null && update) {
        // 更新现有收藏
        favorite = existing.copyWith(
          tag: tag,
          notes: notes ?? existing.notes,
          createdAt: DateTime.now(),
        );
        AppLogger.d('Updating favorite: ${tag.text}', 'TagFavoriteProvider');
      } else if (existing == null) {
        // 创建新收藏
        favorite = TagFavorite.create(tag: tag, notes: notes);
        AppLogger.d('Adding favorite: ${tag.text}', 'TagFavoriteProvider');
      } else {
        // 已存在且不更新，直接返回
        state = state.copyWith(isLoading: false);
        return;
      }

      await _storage.addFavorite(favorite);
      _loadFavorites();
    } catch (e, stack) {
      AppLogger.e('Failed to add favorite: $e', e, stack, 'TagFavoriteProvider');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 删除收藏
  ///
  /// [favoriteId] 收藏 ID
  Future<void> removeFavorite(String favoriteId) async {
    try {
      state = state.copyWith(isLoading: true);

      await _storage.removeFavorite(favoriteId);
      AppLogger.d('Removed favorite: $favoriteId', 'TagFavoriteProvider');

      _loadFavorites();
    } catch (e, stack) {
      AppLogger.e('Failed to remove favorite: $e', e, stack, 'TagFavoriteProvider');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 根据标签删除收藏
  ///
  /// [tag] 要删除收藏的标签
  Future<void> removeFavoriteByTag(PromptTag tag) async {
    final existing = _getFavoriteByTag(tag);
    if (existing != null) {
      await removeFavorite(existing.id);
    }
  }

  /// 切换收藏状态
  ///
  /// [tag] 要切换收藏状态的标签
  /// [notes] 可选备注（仅添加时使用）
  Future<void> toggleFavorite(PromptTag tag, {String? notes}) async {
    final existing = _getFavoriteByTag(tag);
    if (existing != null) {
      await removeFavorite(existing.id);
    } else {
      await addFavorite(tag, notes: notes);
    }
  }

  /// 检查标签是否已收藏
  ///
  /// [tag] 要检查的标签
  /// [tagText] 标签文本（与 tag 二选一）
  bool isFavorite({PromptTag? tag, String? tagText}) {
    if (tag != null) {
      return _getFavoriteByTag(tag) != null;
    }
    if (tagText != null) {
      return state.favorites.any((f) => f.tag.text == tagText);
    }
    return false;
  }

  /// 清空所有收藏
  Future<void> clearFavorites() async {
    try {
      state = state.copyWith(isLoading: true);

      await _storage.clearFavorites();
      AppLogger.d('Cleared all favorites', 'TagFavoriteProvider');

      _loadFavorites();
    } catch (e, stack) {
      AppLogger.e('Failed to clear favorites: $e', e, stack, 'TagFavoriteProvider');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 重新加载收藏列表
  void refresh() {
    _loadFavorites();
  }

  /// 获取收藏数量
  int get favoritesCount => state.favorites.length;

  /// 清除错误状态
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

/// 便捷方法：获取当前收藏列表
@riverpod
List<TagFavorite> currentFavorites(Ref ref) {
  final state = ref.watch(tagFavoriteNotifierProvider);
  return state.favorites;
}

/// 便捷方法：检查是否正在加载
@riverpod
bool isFavoriteLoading(Ref ref) {
  final state = ref.watch(tagFavoriteNotifierProvider);
  return state.isLoading;
}

/// 便捷方法：获取收藏数量
@riverpod
int favoritesCount(Ref ref) {
  final state = ref.watch(tagFavoriteNotifierProvider);
  return state.favorites.length;
}
