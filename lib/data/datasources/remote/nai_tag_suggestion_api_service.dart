import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../models/tag/tag_suggestion.dart';

part 'nai_tag_suggestion_api_service.g.dart';

/// NovelAI Tag Suggestion API 服务
class NAITagSuggestionApiService {
  static const Duration _timeout = Duration(seconds: 5);

  final Dio _dio;

  NAITagSuggestionApiService(this._dio);

  /// 获取标签建议
  Future<List<TagSuggestion>> suggestTags(
    String input, {
    String? model,
  }) async {
    if (input.trim().length < 2) return [];

    final queryParams = <String, dynamic>{
      'prompt': input.trim(),
      if (model != null) 'model': model,
    };

    final response = await _dio.get(
      '${ApiConstants.imageBaseUrl}${ApiConstants.suggestTagsEndpoint}',
      queryParameters: queryParams,
      options: Options(
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
      ),
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('tags')) {
      return (data['tags'] as List)
          .map((t) => TagSuggestion.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// 根据当前提示词获取下一个标签建议
  Future<List<TagSuggestion>> suggestNextTag(
    String prompt, {
    String? model,
  }) async {
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

  return NAITagSuggestionApiService(dio);
}
