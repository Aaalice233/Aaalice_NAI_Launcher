import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/database/services/service_providers.dart';
import '../../../core/services/smart_tag_recommendation_service.dart';
import '../../../core/utils/app_logger.dart';
import 'defined_agent_tool.dart';

/// 标签数据工具集：基于内置 tag_catalog.db 与可选下载的中文字典 /
/// 共现数据包，为提示词写作提供标签检索、中文翻译与共现推荐。
///
/// - `search_tags`：统一入口，mode = search（英文模糊搜标签）/ translate
///   （中文→danbooru 标签，需中文字典）/ suggest（共现推荐，需数据包）；
///   `queries` 批量查询，每项独立成组。
class TagToolbox {
  TagToolbox(this._ref);

  final Ref _ref;

  static const int _maxBatchQueries = 10;
  static const Set<String> _modes = {'auto', 'search', 'translate', 'suggest'};

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
            'for existing tags taken together as one context, requires the '
            'optional co-occurrence data pack. Requirements: pass either '
            '"query" (one term) or "queries" (up to $_maxBatchQueries terms '
            'resolved independently, each returned as its own group); '
            '"limit" 1-30 (default 10) caps every group. In search and '
            'translate a comma-separated term is split into independent '
            'lookups, so batch several tags in one call instead of guessing; '
            'in suggest the commas stay one context group. Results are '
            'evidence for verifying canonical spellings, aliases and category. '
            'For a named character, use this after researching its identity '
            'and before inspecting gallery tags. Do not guess canonical tags '
            'from model memory. Natural-language prompts remain supported.',
        parameters: const {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description':
                  'Single search term, merged with "queries" when both are '
                  'given. For suggest mode: comma-separated existing tags '
                  'used together as one context. For more than one term use '
                  'queries in a single call.',
            },
            'queries': {
              'type': 'array',
              'items': {'type': 'string'},
              'maxItems': _maxBatchQueries,
              'description':
                  'Batch form, up to $_maxBatchQueries terms. Each entry is '
                  'looked up independently and returned as its own group, so '
                  'prefer this over repeating the call per tag.',
            },
            'mode': {
              'type': 'string',
              'enum': ['auto', 'search', 'translate', 'suggest'],
              'description':
                  'auto (default) picks translate for Chinese '
                  'input, otherwise search, per term.',
            },
            'limit': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 30,
              'description': 'Max results per group, 1-30. Default 10.',
            },
          },
        },
        executeFn: (_, params) => _searchTags(params),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // search_tags
  // -------------------------------------------------------------------------

  Future<AgentToolResult> _searchTags(Map<String, dynamic> args) async {
    final mode = (args['mode'] as String?)?.trim() ?? 'auto';
    if (!_modes.contains(mode)) {
      return agentToolError(
        'invalid_mode',
        'Unknown mode "$mode". Use auto / search / translate / suggest.',
      );
    }
    final limit = ((args['limit'] as num?)?.toInt() ?? 10).clamp(1, 30);

    final rawQueries = args['queries'];
    final batched = rawQueries != null;
    // 两个参数同时给出时合并，避免静默丢弃其中一个。
    final terms = <String>[if (args['query'] case final String single) single];
    if (batched) {
      if (rawQueries is! List) {
        return agentToolError(
          'invalid_queries',
          'Parameter "queries" must be an array of search terms.',
        );
      }
      for (final entry in rawQueries) {
        if (entry is! String) {
          return agentToolError(
            'invalid_queries',
            'Parameter "queries" must contain only strings.',
          );
        }
        terms.add(entry);
      }
    }

    final requests = _expand(terms, mode);
    if (requests.isEmpty) {
      return agentToolError(
        'missing_query',
        batched
            ? 'Parameter "queries" needs at least one search term.'
            : 'Parameter "query" is required.',
      );
    }
    if (requests.length > _maxBatchQueries) {
      return agentToolError(
        'too_many_queries',
        'At most $_maxBatchQueries terms per call, got ${requests.length}. '
            'Split the remainder into another call.',
      );
    }

    // 串行执行：底层 catalog / 共现服务都是懒初始化，并发首调会重复 initialize。
    final outcomes = <_TagQueryOutcome>[];
    for (final request in requests) {
      outcomes.add(await _run(request, limit));
    }

    if (!batched && requests.length == 1) {
      final only = outcomes.single;
      if (only.errorCode != null) {
        return agentToolError(only.errorCode!, only.errorMessage!);
      }
      return agentToolJsonResult({
        'ok': true,
        'results': only.results,
        if (only.note != null) 'note': only.note,
      });
    }
    final unmatched = [
      for (var index = 0; index < requests.length; index++)
        if (outcomes[index].results.isEmpty) requests[index].term,
    ];
    return agentToolJsonResult({
      'ok': true,
      'groups': [
        for (var index = 0; index < requests.length; index++)
          {
            'query': requests[index].term,
            'mode': requests[index].mode,
            'results': outcomes[index].results,
            if (outcomes[index].note != null) 'note': outcomes[index].note,
            if (outcomes[index].errorCode != null) ...{
              'error': outcomes[index].errorCode,
              'message': outcomes[index].errorMessage,
            },
          },
      ],
      // 不叫 result_count：该名字在 web_search 等工具里表示分页总数。
      'returned_count': outcomes.fold<int>(
        0,
        (total, outcome) => total + outcome.results.length,
      ),
      // 空组只在组内可见，顶层汇总一次避免整体摘要看起来全部命中。
      if (unmatched.isNotEmpty)
        'note': 'No results for: ${unmatched.join(', ')}.',
    });
  }

  /// 展开成实际执行的查询：suggest 的逗号是一组上下文，其余模式按逗号拆分。
  static List<_TagQuery> _expand(List<String> terms, String mode) {
    final requests = <_TagQuery>[];
    for (final term in terms) {
      if (mode == 'suggest') {
        final trimmed = term.trim();
        if (trimmed.isNotEmpty) requests.add(_TagQuery(trimmed, 'suggest'));
        continue;
      }
      for (final part in term.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        requests.add(_TagQuery(trimmed, _resolveMode(mode, trimmed)));
      }
    }
    return requests;
  }

  static String _resolveMode(String requested, String term) =>
      requested == 'auto'
      ? (_chinesePattern.hasMatch(term) ? 'translate' : 'search')
      : requested;

  Future<_TagQueryOutcome> _run(_TagQuery request, int limit) =>
      switch (request.mode) {
        'translate' => _translate(request.term, limit),
        'suggest' => _suggest(request.term, limit),
        _ => _search(request.term, limit),
      };

  /// 内置词库模糊搜索（英文标签 + 别名，FTS5）。
  Future<_TagQueryOutcome> _search(String query, int limit) async {
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
        return _TagQueryOutcome(note: 'No catalog match for "$query".');
      }
      return _TagQueryOutcome(
        results: [
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
      );
    } catch (e) {
      AppLogger.w('search_tags(search) failed: $e', 'AgentChat');
      return _TagQueryOutcome(
        errorCode: 'tag_search_failed',
        errorMessage: 'Tag search failed: $e',
      );
    }
  }

  /// 中文（或英文）→ danbooru 标签，依赖可选下载的 ffdkj 中文字典。
  Future<_TagQueryOutcome> _translate(String query, int limit) async {
    try {
      final dataSource = await _ref.read(translationDataSourceProvider.future);
      final matches = await dataSource.search(query, limit: limit);
      if (matches.isEmpty) {
        return _TagQueryOutcome(
          note:
              'No translation match for "$query". If Chinese input '
              'keeps returning nothing, the Chinese dictionary may not be '
              'installed yet (download it in Settings).',
        );
      }
      return _TagQueryOutcome(
        results: [
          for (final match in matches)
            {
              'tag': match.tag,
              'chinese': match.translation,
              'category': match.category,
              'post_count': match.count,
            },
        ],
      );
    } catch (e) {
      AppLogger.w('search_tags(translate) failed: $e', 'AgentChat');
      return _TagQueryOutcome(
        errorCode: 'tag_translation_failed',
        errorMessage:
            'Tag translation failed: $e (the Chinese dictionary may not be '
            'installed)',
      );
    }
  }

  /// 共现推荐：基于一个或多个已有标签推荐统计上强相关的标签。
  Future<_TagQueryOutcome> _suggest(String query, int limit) async {
    try {
      final service = await _ref.read(
        smartTagRecommendationServiceProvider.future,
      );
      final inputTags = [
        for (final part in query.split(','))
          if (part.trim().isNotEmpty) part.trim().replaceAll(' ', '_'),
      ];
      if (inputTags.isEmpty) {
        return const _TagQueryOutcome(
          errorCode: 'invalid_query',
          errorMessage: 'Parameter "query" needs at least one tag.',
        );
      }
      final recommendations = await service.getRecommendations(
        inputTags: inputTags,
        limit: limit,
      );
      if (recommendations.isEmpty) {
        return const _TagQueryOutcome(
          note:
              'No suggestions. The co-occurrence data pack may not be '
              'installed (download it in Settings).',
        );
      }
      return _TagQueryOutcome(
        results: [
          for (final recommendation in recommendations)
            {
              'tag': recommendation.tag,
              if (recommendation.translation != null)
                'chinese': recommendation.translation,
              'score': double.parse(recommendation.score.toStringAsFixed(4)),
              'cooccurrence': recommendation.cooccurrence,
            },
        ],
      );
    } catch (e) {
      AppLogger.w('search_tags(suggest) failed: $e', 'AgentChat');
      return _TagQueryOutcome(
        errorCode: 'tag_suggestion_failed',
        errorMessage: 'Tag suggestion failed: $e',
      );
    }
  }
}

class _TagQuery {
  const _TagQuery(this.term, this.mode);

  final String term;
  final String mode;
}

/// errorCode 非空表示这一项失败，批量时其余项仍照常返回。
class _TagQueryOutcome {
  const _TagQueryOutcome({
    this.results = const [],
    this.note,
    this.errorCode,
    this.errorMessage,
  });

  final List<Map<String, dynamic>> results;
  final String? note;
  final String? errorCode;
  final String? errorMessage;
}
