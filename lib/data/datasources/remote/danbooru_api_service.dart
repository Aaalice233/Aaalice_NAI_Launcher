import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/danbooru/danbooru_pool.dart';
import '../../models/danbooru/danbooru_user.dart';
import '../../models/online_gallery/danbooru_post.dart';
import '../../models/tag/danbooru_tag.dart';
import '../../models/tag/tag_suggestion.dart';
import '../../../core/utils/app_logger.dart';
import '../../services/danbooru_auth_service.dart';

part 'danbooru_api_service.g.dart';

/// 排行榜时间范围
enum PopularScale { day, week, month }

/// Danbooru API 服务
class DanbooruApiService {
  static const String _baseUrl = 'https://danbooru.donmai.us';
  static const Duration _timeout = Duration(seconds: 10);
  static const int _defaultLimit = 20;
  static const int _maxLimit = 200;

  // API 端点
  static const String _autocompleteEndpoint = '/autocomplete.json';
  static const String _tagsEndpoint = '/tags.json';
  static const String _postsEndpoint = '/posts.json';
  static const String _postDetailEndpoint = '/posts';
  static const String _artistsEndpoint = '/artists.json';
  static const String _poolsEndpoint = '/pools.json';
  static const String _popularEndpoint = '/explore/posts/popular.json';
  static const String _favoritesEndpoint = '/favorites.json';
  static const String _profileEndpoint = '/profile.json';
  static const String _usersEndpoint = '/users.json';
  static const String _wikiPagesEndpoint = '/wiki_pages.json';
  static const String _wikiPageDetailEndpoint = '/wiki_pages';

  final Dio _dio;
  String? _authHeader;

  DanbooruApiService(this._dio);

  void setAuthHeader(String? authHeader) {
    _authHeader = authHeader;
  }

  Map<String, String> _getHeaders() => {
    'Accept': 'application/json',
    'User-Agent': 'NAI-Launcher/1.0',
    if (_authHeader != null) 'Authorization': _authHeader!,
  };

  String _buildAuthHeader(DanbooruCredentials credentials) {
    final credentialsStr = '${credentials.username}:${credentials.apiKey}';
    return 'Basic ${base64Encode(utf8.encode(credentialsStr))}';
  }

  // ==================== 用户认证 ====================

  Future<DanbooruUser?> verifyCredentials(DanbooruCredentials credentials) async {
    final authHeader = _buildAuthHeader(credentials);
    final response = await _dio.get(
      '$_baseUrl$_profileEndpoint',
      options: Options(
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        headers: {
          ..._getHeaders(),
          'Authorization': authHeader,
        },
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return DanbooruUser.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<(DanbooruUser?, bool)> verifyCredentialsWithErrorType(
    DanbooruCredentials credentials,
  ) async {
    try {
      final user = await verifyCredentials(credentials);
      return (user, false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return (null, false);
      return (null, true);
    } catch (_) {
      return (null, true);
    }
  }

  Future<DanbooruUser?> getCurrentUser() async {
    if (_authHeader == null) return null;

    final response = await _dio.get(
      '$_baseUrl$_profileEndpoint',
      options: Options(
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        headers: _getHeaders(),
      ),
    );

    if (response.statusCode == 401) return null;
    if (response.data is Map<String, dynamic>) {
      return DanbooruUser.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<DanbooruUser?> getUserByName(String username) async {
    final response = await _dio.get(
      '$_baseUrl$_usersEndpoint',
      queryParameters: {'search[name]': username, 'limit': 1},
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
  }

  // ==================== 排行榜 ====================

  Future<List<DanbooruPost>> getPopularPosts({
    PopularScale scale = PopularScale.day,
    String? date,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'scale': scale.name,
      'page': page,
      if (date != null) 'date': date,
    };

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
  }

  // ==================== 收藏夹 ====================

  Future<List<DanbooruPost>> getFavorites({
    int? userId,
    dynamic page = 1,
    int limit = 40,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit.clamp(1, 200),
      if (userId != null) 'search[user_id]': userId,
    };

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
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .where((fav) => fav['post'] != null)
          .map((fav) => DanbooruPost.fromJson(fav['post'] as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<bool> addFavorite(int postId) async {
    if (_authHeader == null) return false;

    try {
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
      return e.response?.statusCode == 422;
    }
  }

  Future<bool> removeFavorite(int postId) async {
    if (_authHeader == null) return false;

    try {
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
      return e.response?.statusCode == 404;
    }
  }

  Future<bool> isFavorited(int postId) async {
    if (_authHeader == null) return false;

    try {
      final response = await _dio.get(
        '$_baseUrl$_favoritesEndpoint',
        queryParameters: {'search[post_id]': postId, 'limit': 1},
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );
      return response.data is List && (response.data as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ==================== 标签自动补全 ====================

  Future<List<DanbooruTag>> autocomplete(String query, {int limit = _defaultLimit}) async {
    if (query.trim().length < 2) return [];

    final response = await _dio.get(
      '$_baseUrl$_autocompleteEndpoint',
      queryParameters: {
        'search[query]': query.trim(),
        'search[type]': 'tag_query',
        'limit': limit.clamp(1, _maxLimit),
      },
      options: Options(
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        headers: _getHeaders(),
      ),
    );

    if (response.data is List) {
      return (response.data as List)
          .map((item) => DanbooruTag.fromAutocomplete(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<TagSuggestion>> suggestTags(String query, {int limit = _defaultLimit}) async {
    final danbooruTags = await autocomplete(query, limit: limit);
    return danbooruTags.toTagSuggestions();
  }

  // ==================== 标签搜索 ====================

  Future<List<DanbooruTag>> searchTags(
    String query, {
    int? category,
    String order = 'count',
    int limit = _defaultLimit,
  }) async {
    final queryParams = <String, dynamic>{
      'search[name_matches]': '*${query.trim()}*',
      'search[order]': order,
      'limit': limit.clamp(1, _maxLimit),
      if (category != null) 'search[category]': category,
    };

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
  }

  // ==================== 帖子搜索 ====================

  Future<List<DanbooruPost>> searchPosts({
    String? tags,
    int limit = 40,
    dynamic page = 1,
    bool random = false,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit.clamp(1, 200),
      'page': page,
      if (tags != null && tags.isNotEmpty) 'tags': tags.replaceAll(' ', '_'),
      if (random) 'random': 'true',
    };

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
  }

  Future<DanbooruPost?> getPost(int postId) async {
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
  }

  // ==================== 艺术家搜索 ====================

  Future<List<Map<String, dynamic>>> searchArtists(String query, {int limit = 20}) async {
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

    return (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // ==================== 图池搜索 ====================

  Future<List<Map<String, dynamic>>> searchPools(String query, {int limit = 20}) async {
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

    return (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<List<DanbooruPool>> searchPoolsTyped(String query, {int limit = 20}) async {
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
  }

  Future<DanbooruPool?> getPool(int poolId) async {
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
  }

  Future<List<DanbooruPost>> getPoolPosts({
    required int poolId,
    int limit = 100,
    int page = 1,
  }) async {
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
  }

  // ==================== Wiki 页面 ====================

  Future<Map<String, dynamic>?> getWikiPage(String title) async {
    final encodedTitle = Uri.encodeComponent(title);

    try {
      final response = await _dio.get(
        '$_baseUrl$_wikiPageDetailEndpoint/$encodedTitle.json',
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: _getHeaders(),
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 410) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchWikiPages({
    String? titlePattern,
    int limit = 100,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit.clamp(1, 200),
      if (titlePattern != null && titlePattern.isNotEmpty)
        'search[title_normalize]': titlePattern,
    };

    final response = await _dio.get(
      '$_baseUrl$_wikiPagesEndpoint',
      queryParameters: queryParams,
      options: Options(
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        headers: _getHeaders(),
      ),
    );

    return (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map<String, int>> batchGetTagPostCounts(List<String> tagNames) async {
    if (tagNames.isEmpty) return {};

    final results = <String, int>{};
    const batchSize = 40;

    for (var i = 0; i < tagNames.length; i += batchSize) {
      final batch = tagNames.skip(i).take(batchSize).toList();

      try {
        final response = await _dio.get(
          '$_baseUrl$_tagsEndpoint',
          queryParameters: {
            'search[name_comma]': batch.join(','),
            'limit': batchSize,
          },
          options: Options(
            receiveTimeout: _timeout,
            sendTimeout: _timeout,
            headers: _getHeaders(),
          ),
        );

        if (response.data is List) {
          for (final item in response.data as List) {
            if (item is Map<String, dynamic>) {
              final name = item['name'] as String?;
              final count = item['post_count'] as int? ?? 0;
              if (name != null) results[name] = count;
            }
          }
        }
      } catch (e) {
        AppLogger.w('Failed to load tag batch', 'DanbooruApi');
      }

      if (i + batchSize < tagNames.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return results;
  }
}

/// DanbooruApiService Provider
@Riverpod(keepAlive: true)
DanbooruApiService danbooruApiService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  final service = DanbooruApiService(dio);

  // 监听认证状态变化并更新 auth header
  ref.watch(danbooruAuthProvider);
  service.setAuthHeader(ref.read(danbooruAuthProvider.notifier).getAuthHeader());

  return service;
}
