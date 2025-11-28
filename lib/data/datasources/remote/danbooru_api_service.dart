import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/tag/danbooru_tag.dart';
import '../../models/tag/tag_suggestion.dart';

part 'danbooru_api_service.g.dart';

/// Danbooru API 服务
///
/// 提供 Danbooru 标签自动补全功能
/// API 文档: https://danbooru.donmai.us/wiki_pages/help:api
class DanbooruApiService {
  static const String _baseUrl = 'https://danbooru.donmai.us';
  static const String _autocompleteEndpoint = '/tags/autocomplete.json';

  /// 请求超时时间
  static const Duration _timeout = Duration(seconds: 5);

  /// 默认返回数量
  static const int _defaultLimit = 20;

  /// 最大返回数量
  static const int _maxLimit = 200;

  final Dio _dio;

  DanbooruApiService(this._dio);

  /// 获取标签自动补全建议
  ///
  /// [query] 搜索词，至少需要 2 个字符
  /// [limit] 返回数量，默认 20，最大 200
  ///
  /// 返回 Danbooru 标签列表
  Future<List<DanbooruTag>> autocomplete(
    String query, {
    int limit = _defaultLimit,
  }) async {
    // 验证输入
    if (query.trim().length < 2) {
      return [];
    }

    // 限制返回数量
    final effectiveLimit = limit.clamp(1, _maxLimit);

    try {
      AppLogger.d('Danbooru autocomplete: "$query" (limit: $effectiveLimit)', 'Danbooru');

      final response = await _dio.get(
        '$_baseUrl$_autocompleteEndpoint',
        queryParameters: {
          'search[name_matches]': '${query.trim()}*',
          'limit': effectiveLimit,
        },
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          // Danbooru 不需要认证
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      AppLogger.d('Danbooru response status: ${response.statusCode}', 'Danbooru');

      // 解析响应
      if (response.data is List) {
        final tags = (response.data as List)
            .map((item) => DanbooruTag.fromJson(item as Map<String, dynamic>))
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
  ///
  /// 这是一个便捷方法，自动将 DanbooruTag 转换为 TagSuggestion
  Future<List<TagSuggestion>> suggestTags(
    String query, {
    int limit = _defaultLimit,
  }) async {
    final danbooruTags = await autocomplete(query, limit: limit);
    return danbooruTags.toTagSuggestions();
  }
}

/// DanbooruApiService Provider
///
/// 使用独立的 Dio 实例，不需要认证
@riverpod
DanbooruApiService danbooruApiService(DanbooruApiServiceRef ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
  ));

  // 添加日志拦截器（仅在调试模式）
  assert(() {
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => AppLogger.d(obj.toString(), 'Dio'),
    ));
    return true;
  }());

  return DanbooruApiService(dio);
}
