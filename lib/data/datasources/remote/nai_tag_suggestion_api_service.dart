import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/tag/tag_suggestion.dart';

part 'nai_tag_suggestion_api_service.g.dart';

/// NovelAI Tag Suggestion API 服务
///
/// 提供 NovelAI 标签建议功能
/// - 标签自动补全
/// - 基于提示词的标签建议
class NAITagSuggestionApiService {
  // ==================== 配置 ====================
  static const Duration _timeout = Duration(seconds: 5);

  final Dio _dio;

  NAITagSuggestionApiService(this._dio);

  // ==================== 标签建议 API ====================

  /// 获取标签建议
  ///
  /// [input] 输入的标签或提示词片段
  /// [model] 模型名称（可选，默认使用 NAI Diffusion 4 Full）
  ///
  /// 返回建议的标签列表
  Future<List<TagSuggestion>> suggestTags(
    String input, {
    String? model,
  }) async {
    if (input.trim().length < 2) {
      return [];
    }

    try {
      // 使用 GET 请求，参数放在 query string 中
      final queryParams = <String, dynamic>{
        'prompt': input.trim(),
      };
      if (model != null) {
        queryParams['model'] = model;
      }

      AppLogger.d('Fetching tag suggestions for: ${input.trim()}', 'NAITag');

      final response = await _dio.get(
        '${ApiConstants.imageBaseUrl}${ApiConstants.suggestTagsEndpoint}',
        queryParameters: queryParams,
        options: Options(
          // 标签建议使用更短的超时时间 (5秒)
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      AppLogger.d(
        'Tag suggestion response: ${response.statusCode}',
        'NAITag',
      );

      // 解析响应
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('tags')) {
        final tags = (data['tags'] as List)
            .map((t) => TagSuggestion.fromJson(t as Map<String, dynamic>))
            .toList();
        AppLogger.d('Found ${tags.length} tag suggestions', 'NAITag');
        return tags;
      }

      AppLogger.w(
        'Tag suggestion response has no tags field: $data',
        'NAITag',
      );
      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        AppLogger.w('Tag suggestion timed out', 'NAITag');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w(
          'Tag suggestion connection error: ${e.message}',
          'NAITag',
        );
      } else {
        AppLogger.e('Tag suggestion failed: ${e.message}', e, null, 'NAITag');
      }
      return [];
    } catch (e, stack) {
      AppLogger.e('Tag suggestion failed: $e', e, stack, 'NAITag');
      return [];
    }
  }

  /// 根据当前提示词获取下一个标签建议
  ///
  /// 这会解析提示词，提取最后一个不完整的标签，并返回建议
  ///
  /// [prompt] 当前提示词
  /// [model] 模型名称（可选）
  ///
  /// 返回建议的标签列表
  Future<List<TagSuggestion>> suggestNextTag(
    String prompt, {
    String? model,
  }) async {
    // 提取最后一个标签（逗号分隔）
    final parts = prompt.split(',');
    if (parts.isEmpty) return [];

    final lastPart = parts.last.trim();
    if (lastPart.length < 2) return [];

    return suggestTags(lastPart, model: model);
  }
}

/// NAITagSuggestionApiService Provider
@Riverpod(keepAlive: true)
NAITagSuggestionApiService naiTagSuggestionApiService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  // 添加日志拦截器（仅在调试模式）
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: false,
        logPrint: (obj) => AppLogger.d(obj.toString(), 'Dio'),
      ),
    );
    return true;
  }());

  return NAITagSuggestionApiService(dio);
}
