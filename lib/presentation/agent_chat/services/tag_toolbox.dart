import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/database/services/service_providers.dart';
import '../../../core/services/smart_tag_recommendation_service.dart';
import '../../../core/utils/app_logger.dart';
import 'prompt_toolbox.dart';

AgentToolResult _textResult(String text) {
  return AgentToolResult(
    content: [ToolResultTextContent(text)],
    details: const <String, dynamic>{},
  );
}

AgentToolResult _errorResult(String text) {
  return AgentToolResult(
    content: [ToolResultTextContent(text)],
    details: const <String, dynamic>{},
    isError: true,
  );
}

/// 标签数据工具集：基于内置 tag_catalog.db 与可选下载的中文字典 /
/// 共现数据包，为提示词写作提供标签检索、中文翻译与共现推荐。
///
/// - `search_tags`：统一入口，mode = search（英文模糊搜标签）/ translate
///   （中文→danbooru 标签，需中文字典）/ suggest（共现推荐，需数据包）。
class TagToolbox {
  TagToolbox(this._ref);

  final Ref _ref;

  static final RegExp _chinesePattern = RegExp(r'[\u3400-\u9fff]');

  List<AgentTool> tools() {
    return [
      DefinedAgentTool(
        name: 'search_tags',
        label: 'Search Tags',
        description:
            'Look up danbooru tags in the built-in databases as a '
            'reference. Modes: '
            '"search" (default for English input) fuzzy-matches canonical '
            'tags and aliases in the built-in catalog (always available); '
            '"translate" maps a Chinese (or English) concept to danbooru '
            'tags with Chinese meanings, requires the optional Chinese '
            'dictionary; "suggest" recommends statistically related tags '
            'for one or more existing tags (comma-separated query), '
            'requires the optional co-occurrence data pack. Requirements: '
            '"query" is required; "limit" 1-30 (default 10). Results are '
            'optional reference material — newer models also understand '
            'natural language, so use whatever fits the request best.',
        parameters: const {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description':
                  'Search term. For suggest mode: comma-separated '
                  'existing tags.',
            },
            'mode': {
              'type': 'string',
              'enum': ['auto', 'search', 'translate', 'suggest'],
              'description':
                  'auto (default) picks translate for Chinese '
                  'input, otherwise search.',
            },
            'limit': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 30,
              'description': 'Max results, 1-30. Default 10.',
            },
          },
          'required': ['query'],
        },
        executeFn: (_, params) => _searchTags(params),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // search_tags
  // -------------------------------------------------------------------------

  Future<AgentToolResult> _searchTags(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return _errorResult('Parameter "query" is required.');
    }
    final mode = (args['mode'] as String?)?.trim() ?? 'auto';
    final limit = ((args['limit'] as num?)?.toInt() ?? 10).clamp(1, 30);
    final resolved = mode == 'auto'
        ? (_chinesePattern.hasMatch(query) ? 'translate' : 'search')
        : mode;
    switch (resolved) {
      case 'translate':
        return _translate(query, limit);
      case 'suggest':
        return _suggest(query, limit);
      case 'search':
        return _search(query, limit);
      default:
        return _errorResult(
          'Unknown mode "$mode". Use auto / search / translate / suggest.',
        );
    }
  }

  /// 内置词库模糊搜索（英文标签 + 别名，FTS5）。
  Future<AgentToolResult> _search(String query, int limit) async {
    try {
      final repository = _ref.read(tagCatalogRepositoryProvider);
      final token = query.replaceAll(' ', '_').toLowerCase();
      final candidates = await repository.search(
        CompletionQuery(
          fullText: token,
          cursorPosition: token.length,
          token: token,
          replacementRange: const TextReplacementRange(start: 0, end: 0),
          existingTags: const {},
          limit: limit,
          locale: 'zh',
        ),
      );
      if (candidates.isEmpty) {
        return _textResult(
          jsonEncode({
            'ok': true,
            'results': const <Map<String, dynamic>>[],
            'note': 'No catalog match for "$query".',
          }),
        );
      }
      return _textResult(
        jsonEncode({
          'ok': true,
          'results': [
            for (final candidate in candidates)
              {
                'tag': candidate.canonicalTag,
                'category': candidate.category.name,
                'post_count': candidate.postCount,
                if (candidate.aliases.isNotEmpty) 'aliases': candidate.aliases,
                if (candidate.translation != null)
                  'chinese': candidate.translation,
              },
          ],
        }),
      );
    } catch (e) {
      AppLogger.w('search_tags(search) failed: $e', 'AgentChat');
      return _errorResult('Tag search failed: $e');
    }
  }

  /// 中文（或英文）→ danbooru 标签，依赖可选下载的 ffdkj 中文字典。
  Future<AgentToolResult> _translate(String query, int limit) async {
    try {
      final dataSource = await _ref.read(translationDataSourceProvider.future);
      final matches = await dataSource.search(query, limit: limit);
      if (matches.isEmpty) {
        return _textResult(
          jsonEncode({
            'ok': true,
            'results': const <Map<String, dynamic>>[],
            'note':
                'No translation match for "$query". If Chinese input '
                'keeps returning nothing, the Chinese dictionary may not be '
                'installed yet (download it in Settings).',
          }),
        );
      }
      return _textResult(
        jsonEncode({
          'ok': true,
          'results': [
            for (final match in matches)
              {
                'tag': match.tag,
                'chinese': match.translation,
                'category': match.category,
                'post_count': match.count,
              },
          ],
        }),
      );
    } catch (e) {
      AppLogger.w('search_tags(translate) failed: $e', 'AgentChat');
      return _errorResult(
        'Tag translation failed: $e (the Chinese dictionary may not be '
        'installed)',
      );
    }
  }

  /// 共现推荐：基于一个或多个已有标签推荐统计上强相关的标签。
  Future<AgentToolResult> _suggest(String query, int limit) async {
    try {
      final service = await _ref.read(
        smartTagRecommendationServiceProvider.future,
      );
      final inputTags = [
        for (final part in query.split(','))
          if (part.trim().isNotEmpty) part.trim().replaceAll(' ', '_'),
      ];
      if (inputTags.isEmpty) {
        return _errorResult('Parameter "query" needs at least one tag.');
      }
      final recommendations = await service.getRecommendations(
        inputTags: inputTags,
        limit: limit,
      );
      if (recommendations.isEmpty) {
        return _textResult(
          jsonEncode({
            'ok': true,
            'results': const <Map<String, dynamic>>[],
            'note':
                'No suggestions. The co-occurrence data pack may not be '
                'installed (download it in Settings).',
          }),
        );
      }
      return _textResult(
        jsonEncode({
          'ok': true,
          'results': [
            for (final recommendation in recommendations)
              {
                'tag': recommendation.tag,
                if (recommendation.translation != null)
                  'chinese': recommendation.translation,
                'score': double.parse(recommendation.score.toStringAsFixed(4)),
                'cooccurrence': recommendation.cooccurrence,
              },
          ],
        }),
      );
    } catch (e) {
      AppLogger.w('search_tags(suggest) failed: $e', 'AgentChat');
      return _errorResult('Tag suggestion failed: $e');
    }
  }
}
