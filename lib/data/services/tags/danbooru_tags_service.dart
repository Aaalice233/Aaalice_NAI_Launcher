import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../data/models/tag/danbooru_tag.dart';
import '../../../data/models/tag/local_tag.dart';

part 'danbooru_tags_service.g.dart';

/// Danbooru 标签服务
///
/// 提供纯业务逻辑的标签同步功能，不包含状态管理。
/// 支持常规标签和艺术家标签的获取，支持取消令牌进行任务取消。
class DanbooruTagsService {
  final DanbooruApiService _apiService;

  DanbooruTagsService(this._apiService);

  /// 获取常规标签
  ///
  /// [query] 搜索关键词（可选）
  /// [category] 标签分类过滤（可选）
  /// [limit] 每页数量限制
  /// [page] 页码
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 返回 DanbooruTag 列表
  Future<List<DanbooruTag>> fetchRegularTags({
    String? query,
    int? category,
    int limit = 100,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.d(
        'Fetching regular tags: query=$query, category=$category, page=$page',
        'DanbooruTagsService',
      );

      final searchQuery = query?.trim() ?? '';

      final tags = await _apiService.searchTags(
        searchQuery.isEmpty ? '*' : searchQuery,
        category: category,
        limit: limit.clamp(1, 200),
        order: 'count',
      );

      // 检查是否被取消
      if (cancelToken?.isCancelled ?? false) {
        throw CancellationException();
      }

      AppLogger.d(
        'Fetched ${tags.length} regular tags',
        'DanbooruTagsService',
      );

      return tags;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger.d('Regular tag fetch cancelled', 'DanbooruTagsService');
        throw CancellationException();
      }
      AppLogger.e(
        'Failed to fetch regular tags: ${e.message}',
        e,
        null,
        'DanbooruTagsService',
      );
      rethrow;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to fetch regular tags',
        e,
        stack,
        'DanbooruTagsService',
      );
      rethrow;
    }
  }

  /// 获取艺术家标签
  ///
  /// [query] 搜索关键词（可选）
  /// [limit] 每页数量限制
  /// [page] 页码
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 返回 DanbooruTag 列表（仅包含艺术家分类）
  Future<List<DanbooruTag>> fetchArtistTags({
    String? query,
    int limit = 100,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    try {
      AppLogger.d(
        'Fetching artist tags: query=$query, page=$page',
        'DanbooruTagsService',
      );

      // 艺术家分类值为 1
      const artistCategory = 1;

      final searchQuery = query?.trim() ?? '';

      final tags = await _apiService.searchTags(
        searchQuery.isEmpty ? '*' : searchQuery,
        category: artistCategory,
        limit: limit.clamp(1, 200),
        order: 'count',
      );

      // 检查是否被取消
      if (cancelToken?.isCancelled ?? false) {
        throw CancellationException();
      }

      // 二次过滤确保只有艺术家标签
      final artistTags = tags.where((t) => t.category == artistCategory).toList();

      AppLogger.d(
        'Fetched ${artistTags.length} artist tags',
        'DanbooruTagsService',
      );

      return artistTags;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger.d('Artist tag fetch cancelled', 'DanbooruTagsService');
        throw CancellationException();
      }
      AppLogger.e(
        'Failed to fetch artist tags: ${e.message}',
        e,
        null,
        'DanbooruTagsService',
      );
      rethrow;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to fetch artist tags',
        e,
        stack,
        'DanbooruTagsService',
      );
      rethrow;
    }
  }

  /// 批量获取标签的帖子数量
  ///
  /// [tagNames] 标签名列表
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 返回 Map<标签名, 帖子数量>
  Future<Map<String, int>> fetchTagPostCounts(
    List<String> tagNames, {
    CancelToken? cancelToken,
  }) async {
    if (tagNames.isEmpty) return {};

    try {
      AppLogger.d(
        'Fetching post counts for ${tagNames.length} tags',
        'DanbooruTagsService',
      );

      final results = await _apiService.batchGetTagPostCounts(tagNames);

      // 检查是否被取消
      if (cancelToken?.isCancelled ?? false) {
        throw CancellationException();
      }

      return results;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger.d('Post count fetch cancelled', 'DanbooruTagsService');
        throw CancellationException();
      }
      AppLogger.e(
        'Failed to fetch tag post counts: ${e.message}',
        e,
        null,
        'DanbooruTagsService',
      );
      rethrow;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to fetch tag post counts',
        e,
        stack,
        'DanbooruTagsService',
      );
      rethrow;
    }
  }

  /// 将 DanbooruTag 转换为 LocalTag
  ///
  /// [danbooruTag] Danbooru API 返回的标签
  /// [translation] 中文翻译（可选）
  LocalTag convertToLocalTag(DanbooruTag danbooruTag, {String? translation}) {
    // Danbooru 分类转应用内分类
    // Danbooru: 0=general, 1=artist, 3=copyright, 4=character, 5=meta
    // 应用内: 0=general, 1=character, 3=copyright, 4=artist, 5=meta
    int appCategory;
    switch (danbooruTag.category) {
      case 1: // artist
        appCategory = 4;
        break;
      case 4: // character
        appCategory = 1;
        break;
      default:
        appCategory = danbooruTag.category;
    }

    return LocalTag(
      tag: danbooruTag.name,
      category: appCategory,
      count: danbooruTag.postCount,
      alias: danbooruTag.antecedentName,
      translation: translation,
    );
  }

  /// 批量转换标签
  ///
  /// [danbooruTags] Danbooru 标签列表
  /// [translations] 翻译映射（可选）
  List<LocalTag> convertToLocalTags(
    List<DanbooruTag> danbooruTags, {
    Map<String, String>? translations,
  }) {
    return danbooruTags.map((tag) {
      final translation = translations?[tag.name.toLowerCase()];
      return convertToLocalTag(tag, translation: translation);
    }).toList();
  }

  /// 保存标签到本地存储
  ///
  /// [tags] 要保存的标签列表
  /// [tagType] 标签类型（'regular' 或 'artist'）
  Future<void> saveTags(List<LocalTag> tags, String tagType) async {
    try {
      final boxName = 'danbooru_tags_$tagType';
      final box = await Hive.openBox<LocalTag>(boxName);

      // 清除旧数据并保存新数据
      await box.clear();
      for (var i = 0; i < tags.length; i++) {
        await box.put(i, tags[i]);
      }

      AppLogger.d(
        'Saved ${tags.length} $tagType tags to local storage',
        'DanbooruTagsService',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save tags',
        e,
        stack,
        'DanbooruTagsService',
      );
      rethrow;
    }
  }

  /// 从本地存储加载标签
  ///
  /// [tagType] 标签类型（'regular' 或 'artist'）
  Future<List<LocalTag>> loadTags(String tagType) async {
    try {
      final boxName = 'danbooru_tags_$tagType';
      final box = await Hive.openBox<LocalTag>(boxName);
      final tags = box.values.toList();

      AppLogger.d(
        'Loaded ${tags.length} $tagType tags from local storage',
        'DanbooruTagsService',
      );
      return tags;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load tags',
        e,
        stack,
        'DanbooruTagsService',
      );
      return [];
    }
  }

  /// 清除本地存储的标签
  ///
  /// [tagType] 标签类型（'regular' 或 'artist'），如果为 null 则清除所有
  Future<void> clearTags([String? tagType]) async {
    try {
      if (tagType != null) {
        final boxName = 'danbooru_tags_$tagType';
        final box = await Hive.openBox<LocalTag>(boxName);
        await box.clear();
        AppLogger.d(
          'Cleared $tagType tags from local storage',
          'DanbooruTagsService',
        );
      } else {
        // 清除所有标签类型
        for (final type in ['regular', 'artist']) {
          final boxName = 'danbooru_tags_$type';
          final box = await Hive.openBox<LocalTag>(boxName);
          await box.clear();
        }
        AppLogger.d(
          'Cleared all tags from local storage',
          'DanbooruTagsService',
        );
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to clear tags',
        e,
        stack,
        'DanbooruTagsService',
      );
      rethrow;
    }
  }

  /// 获取本地存储的标签数量
  ///
  /// [tagType] 标签类型（'regular' 或 'artist'）
  Future<int> getLocalTagCount(String tagType) async {
    try {
      final boxName = 'danbooru_tags_$tagType';
      final box = await Hive.openBox<LocalTag>(boxName);
      return box.length;
    } catch (e) {
      return 0;
    }
  }

  /// 检查是否有本地存储的标签
  ///
  /// [tagType] 标签类型（'regular' 或 'artist'）
  Future<bool> hasLocalTags(String tagType) async {
    try {
      final count = await getLocalTagCount(tagType);
      return count > 0;
    } catch (e) {
      return false;
    }
  }
}

/// 取消异常
///
/// 当任务被取消时抛出
class CancellationException implements Exception {
  final String message;

  CancellationException([this.message = '任务已取消']);

  @override
  String toString() => 'CancellationException: $message';
}

/// DanbooruTagsService Provider
@Riverpod(keepAlive: true)
DanbooruTagsService danbooruTagsService(Ref ref) {
  final apiService = ref.watch(danbooruApiServiceProvider);
  return DanbooruTagsService(apiService);
}
