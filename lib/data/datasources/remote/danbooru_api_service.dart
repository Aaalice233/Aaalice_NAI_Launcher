import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/danbooru/danbooru_pool.dart';
import '../../models/danbooru/danbooru_user.dart';
import '../../models/online_gallery/danbooru_post.dart';
import '../../models/tag/danbooru_tag.dart';
import '../../models/tag/tag_suggestion.dart';
import '../../services/danbooru_auth_service.dart';

part 'danbooru_api_service.g.dart';

/// 排行榜时间范围
enum PopularScale {
  day,
  week,
  month,
}

/// Danbooru API 服务
///
/// 提供 Danbooru 标签自动补全、排行榜、收藏夹等功能
/// API 文档: https://danbooru.donmai.us/wiki_pages/help:api
class DanbooruApiService {
  static const String _baseUrl = 'https://danbooru.donmai.us';

  // ==================== API 端点 ====================
  /// 标签自动补全
  static const String _autocompleteEndpoint = '/autocomplete.json';

  /// 标签搜索
  static const String _tagsEndpoint = '/tags.json';

  /// 帖子搜索
  static const String _postsEndpoint = '/posts.json';

  /// 帖子详情
  static const String _postDetailEndpoint = '/posts';

  /// 艺术家搜索
  static const String _artistsEndpoint = '/artists.json';

  /// 图池搜索
  static const String _poolsEndpoint = '/pools.json';

  /// 排行榜
  static const String _popularEndpoint = '/explore/posts/popular.json';

  /// 收藏夹
  static const String _favoritesEndpoint = '/favorites.json';

  /// 用户信息
  static const String _profileEndpoint = '/profile.json';

  /// 用户搜索
  static const String _usersEndpoint = '/users.json';

  // ==================== 配置 ====================
  static const Duration _timeout = Duration(seconds: 10);
  static const int _defaultLimit = 20;
  static const int _maxLimit = 200;

  final Dio _dio;
  String? _authHeader;

  DanbooruApiService(this._dio);

  /// 设置认证头
  void setAuthHeader(String? authHeader) {
    _authHeader = authHeader;
  }

  /// 获取通用请求头
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'NAI-Launcher/1.0',
    };
    if (_authHeader != null) {
      headers['Authorization'] = _authHeader!;
    }
    return headers;
  }

  // ==================== 用户认证 ====================

  /// 获取当前登录用户信息
  Future<DanbooruUser?> getCurrentUser() async {
    if (_authHeader == null) return null;

    try {
      AppLogger.d('Fetching current user profile', 'Danbooru');

      final response = await _dio.get(
        '$_baseUrl$_profileEndpoint',
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return DanbooruUser.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('Failed to get current user', e, stack, 'Danbooru');
      return null;
    }
  }

  /// 通过用户名获取用户信息
  Future<DanbooruUser?> getUserByName(String username) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_usersEndpoint',
        queryParameters: {
          'search[name]': username,
          'limit': 1,
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List && (response.data as List).isNotEmpty) {
        return DanbooruUser.fromJson(
          (response.data as List).first as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('Failed to get user by name', e, stack, 'Danbooru');
      return null;
    }
  }

  // ==================== 排行榜 ====================

  /// 获取排行榜帖子
  ///
  /// [scale] 时间范围：day, week, month
  /// [date] 日期（可选，格式：YYYY-MM-DD）
  /// [page] 页码
  Future<List<DanbooruPost>> getPopularPosts({
    PopularScale scale = PopularScale.day,
    String? date,
    int page = 1,
  }) async {
    try {
      AppLogger.d(
        'Fetching popular posts: ${scale.name}, date: $date',
        'Danbooru',
      );

      final queryParams = <String, dynamic>{
        'scale': scale.name,
        'page': page,
      };

      if (date != null) {
        queryParams['date'] = date;
      }

      final response = await _dio.get(
        '$_baseUrl$_popularEndpoint',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((item) => DanbooruPost.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Failed to get popular posts', e, stack, 'Danbooru');
      return [];
    }
  }

  // ==================== 收藏夹 ====================

  /// 获取用户收藏列表
  ///
  /// [userId] 用户 ID（可选，默认为当前用户）
  /// [page] 页码
  /// [limit] 每页数量
  Future<List<DanbooruPost>> getFavorites({
    int? userId,
    int page = 1,
    int limit = 40,
  }) async {
    try {
      AppLogger.d(
        'Fetching favorites, userId: $userId, page: $page',
        'Danbooru',
      );

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit.clamp(1, 200),
      };

      if (userId != null) {
        queryParams['search[user_id]'] = userId;
      }

      final response = await _dio.get(
        '$_baseUrl$_favoritesEndpoint',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        // Favorites API 返回 favorite 对象，需要提取 post
        final favorites = response.data as List;
        final posts = <DanbooruPost>[];

        for (final fav in favorites) {
          if (fav is Map<String, dynamic> && fav['post'] != null) {
            posts.add(
              DanbooruPost.fromJson(fav['post'] as Map<String, dynamic>),
            );
          }
        }
        return posts;
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Failed to get favorites', e, stack, 'Danbooru');
      return [];
    }
  }

  /// 添加收藏
  ///
  /// [postId] 帖子 ID
  /// 返回是否成功
  Future<bool> addFavorite(int postId) async {
    if (_authHeader == null) {
      AppLogger.w('Cannot add favorite: not logged in', 'Danbooru');
      return false;
    }

    try {
      AppLogger.d('Adding favorite: $postId', 'Danbooru');

      await _dio.post(
        '$_baseUrl$_favoritesEndpoint',
        queryParameters: {'post_id': postId},
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      return true;
    } on DioException catch (e) {
      // 422 表示已经收藏了
      if (e.response?.statusCode == 422) {
        AppLogger.d('Post already favorited: $postId', 'Danbooru');
        return true;
      }
      AppLogger.e('Failed to add favorite', e, null, 'Danbooru');
      return false;
    } catch (e, stack) {
      AppLogger.e('Failed to add favorite', e, stack, 'Danbooru');
      return false;
    }
  }

  /// 移除收藏
  ///
  /// [postId] 帖子 ID
  /// 返回是否成功
  Future<bool> removeFavorite(int postId) async {
    if (_authHeader == null) {
      AppLogger.w('Cannot remove favorite: not logged in', 'Danbooru');
      return false;
    }

    try {
      AppLogger.d('Removing favorite: $postId', 'Danbooru');

      await _dio.delete(
        '$_baseUrl$_favoritesEndpoint/$postId.json',
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      return true;
    } on DioException catch (e) {
      // 404 表示收藏不存在
      if (e.response?.statusCode == 404) {
        return true;
      }
      AppLogger.e('Failed to remove favorite', e, null, 'Danbooru');
      return false;
    } catch (e, stack) {
      AppLogger.e('Failed to remove favorite', e, stack, 'Danbooru');
      return false;
    }
  }

  /// 检查帖子是否已收藏
  Future<bool> isFavorited(int postId) async {
    if (_authHeader == null) return false;

    try {
      final response = await _dio.get(
        '$_baseUrl$_favoritesEndpoint',
        queryParameters: {
          'search[post_id]': postId,
          'limit': 1,
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List).isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==================== 标签自动补全 ====================

  /// 获取标签自动补全建议
  Future<List<DanbooruTag>> autocomplete(
    String query, {
    int limit = _defaultLimit,
  }) async {
    if (query.trim().length < 2) return [];

    final effectiveLimit = limit.clamp(1, _maxLimit);

    try {
      AppLogger.d('Danbooru autocomplete: "$query"', 'Danbooru');

      final response = await _dio.get(
        '$_baseUrl$_autocompleteEndpoint',
        queryParameters: {
          'search[query]': query.trim(),
          'search[type]': 'tag_query',
          'limit': effectiveLimit,
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      AppLogger.d(
        'Danbooru response status: ${response.statusCode}',
        'Danbooru',
      );

      if (response.data is List) {
        final tags = (response.data as List)
            .map(
              (item) =>
                  DanbooruTag.fromAutocomplete(item as Map<String, dynamic>),
            )
            .toList();
        AppLogger.d('Danbooru found ${tags.length} tags', 'Danbooru');
        return tags;
      }
      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Danbooru request timeout: ${e.message}', 'Danbooru');
      } else {
        AppLogger.e('Danbooru API error: ${e.message}', e, null, 'Danbooru');
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru unexpected error: $e', e, stack, 'Danbooru');
      return [];
    }
  }

  /// 获取标签建议（返回应用内 TagSuggestion 格式）
  Future<List<TagSuggestion>> suggestTags(
    String query, {
    int limit = _defaultLimit,
  }) async {
    final danbooruTags = await autocomplete(query, limit: limit);
    return danbooruTags.toTagSuggestions();
  }

  // ==================== 标签搜索 ====================

  /// 搜索标签详细信息
  Future<List<DanbooruTag>> searchTags(
    String query, {
    int? category,
    String order = 'count',
    int limit = _defaultLimit,
  }) async {
    try {
      AppLogger.d('Danbooru searchTags: "$query"', 'Danbooru');

      final queryParams = <String, dynamic>{
        'search[name_matches]': '*${query.trim()}*',
        'search[order]': order,
        'limit': limit.clamp(1, _maxLimit),
      };

      if (category != null) {
        queryParams['search[category]'] = category;
      }

      final response = await _dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((item) => DanbooruTag.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru searchTags error: $e', e, stack, 'Danbooru');
      return [];
    }
  }

  // ==================== 帖子搜索 ====================

  /// 搜索帖子
  Future<List<DanbooruPost>> searchPosts({
    String? tags,
    int limit = 40,
    int page = 1,
    bool random = false,
  }) async {
    try {
      AppLogger.d('Danbooru searchPosts: "$tags"', 'Danbooru');

      final queryParams = <String, dynamic>{
        'limit': limit.clamp(1, 200),
        'page': page,
      };

      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags;
      }

      if (random) {
        queryParams['random'] = 'true';
      }

      final response = await _dio.get(
        '$_baseUrl$_postsEndpoint',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((item) => DanbooruPost.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru searchPosts error: $e', e, stack, 'Danbooru');
      return [];
    }
  }

  /// 获取帖子详情
  Future<DanbooruPost?> getPost(int postId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_postDetailEndpoint/$postId.json',
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return DanbooruPost.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('Danbooru getPost error: $e', e, stack, 'Danbooru');
      return null;
    }
  }

  // ==================== 艺术家搜索 ====================

  /// 搜索艺术家
  Future<List<Map<String, dynamic>>> searchArtists(
    String query, {
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_artistsEndpoint',
        queryParameters: {
          'search[name_matches]': '*${query.trim()}*',
          'limit': limit.clamp(1, 100),
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru searchArtists error: $e', e, stack, 'Danbooru');
      return [];
    }
  }

  // ==================== 图池搜索 ====================

  /// 搜索图池
  Future<List<Map<String, dynamic>>> searchPools(
    String query, {
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_poolsEndpoint',
        queryParameters: {
          'search[name_matches]': '*${query.trim()}*',
          'limit': limit.clamp(1, 100),
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru searchPools error: $e', e, stack, 'Danbooru');
      return [];
    }
  }

  /// 搜索图池（类型化版本）
  ///
  /// 返回 [DanbooruPool] 对象列表
  Future<List<DanbooruPool>> searchPoolsTyped(
    String query, {
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_poolsEndpoint',
        queryParameters: {
          'search[name_matches]': '*${query.trim()}*',
          'limit': limit.clamp(1, 100),
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => DanbooruPool.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru searchPoolsTyped error: $e', e, stack, 'Danbooru');
      return [];
    }
  }

  /// 获取 Pool 详情
  ///
  /// [poolId] Pool ID
  Future<DanbooruPool?> getPool(int poolId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/pools/$poolId.json',
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return DanbooruPool.fromJson(response.data);
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('Danbooru getPool error: $e', e, stack, 'Danbooru');
      return null;
    }
  }

  /// 获取 Pool 内的帖子
  ///
  /// 使用 `pool:$poolId` 标签搜索获取 Pool 内的帖子
  /// [poolId] Pool ID
  /// [limit] 最大返回数量
  /// [page] 页码（从1开始）
  Future<List<DanbooruPost>> getPoolPosts({
    required int poolId,
    int limit = 100,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_postsEndpoint',
        queryParameters: {
          'tags': 'pool:$poolId',
          'limit': limit.clamp(1, 200),
          'page': page,
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => DanbooruPost.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Danbooru getPoolPosts error: $e', e, stack, 'Danbooru');
      return [];
    }
  }
}

/// DanbooruApiService Provider
@Riverpod(keepAlive: true)
DanbooruApiService danbooruApiService(DanbooruApiServiceRef ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  // 添加日志拦截器（仅在调试模式）
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => AppLogger.d(obj.toString(), 'Dio'),
      ),
    );
    return true;
  }());

  final service = DanbooruApiService(dio);

  // 监听认证状态变化
  ref.listen(danbooruAuthProvider, (previous, next) {
    service
        .setAuthHeader(ref.read(danbooruAuthProvider.notifier).getAuthHeader());
  });

  // 初始化时设置认证头
  service
      .setAuthHeader(ref.read(danbooruAuthProvider.notifier).getAuthHeader());

  return service;
}
