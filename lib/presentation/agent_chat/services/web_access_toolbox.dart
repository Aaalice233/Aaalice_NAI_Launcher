import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/network/web_access/safe_web_reader.dart';
import '../../../core/network/web_access/web_access_models.dart';
import '../../../core/network/web_access/web_access_service.dart';
import '../../../core/utils/app_logger.dart';
import 'prompt_toolbox.dart';

class WebAccessToolbox {
  WebAccessToolbox({
    required WebAccessConfig config,
    required WebAccessGateway gateway,
  }) : _config = config,
       _gateway = gateway;

  final WebAccessConfig _config;
  final WebAccessGateway _gateway;

  List<AgentTool> tools() {
    if (!_config.enabled) return const [];
    return [
      DefinedAgentTool(
        name: 'web_search',
        label: 'Web Search',
        description:
            'Search the current web using the user-configured backend. '
            'Returns a small structured list of titles, URLs, and snippets; '
            'it does not automatically read every result. Use count 1-10 '
            '(default from settings). Optional recency is day/week/month/year. '
            'Use include_domains and exclude_domains only when the user or '
            'task requires domain filtering.',
        parameters: const {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Specific web search query.',
            },
            'count': {
              'type': 'integer',
              'minimum': WebAccessConfig.minResultCount,
              'maximum': WebAccessConfig.maxResultCount,
              'description': 'Number of results, 1-10.',
            },
            'recency': {
              'type': 'string',
              'enum': ['any', 'day', 'week', 'month', 'year'],
              'description': 'Optional publication recency filter.',
            },
            'include_domains': {
              'type': 'array',
              'items': {'type': 'string'},
              'maxItems': 10,
              'description': 'Optional domains to include.',
            },
            'exclude_domains': {
              'type': 'array',
              'items': {'type': 'string'},
              'maxItems': 10,
              'description': 'Optional domains to exclude.',
            },
          },
          'required': ['query'],
        },
        executeWithControl: (_, params, signal, _) => _search(params, signal),
      ),
      DefinedAgentTool(
        name: 'web_read',
        label: 'Web Read',
        description:
            'Read one public HTTP(S) page after a search result needs deeper '
            'inspection. Extracts readable text locally and never sends the '
            'URL to Exa. Private, loopback, and link-local targets are blocked. '
            'Do not call this for every search result. max_chars is 500-30000 '
            '(default 12000).',
        parameters: const {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'One public HTTP(S) URL to read.',
            },
            'max_chars': {
              'type': 'integer',
              'minimum': SafeWebReader.minContentCharacters,
              'maximum': SafeWebReader.maxContentCharacters,
              'description': 'Maximum extracted characters, default 12000.',
            },
          },
          'required': ['url'],
        },
        executeWithControl: (_, params, signal, _) => _read(params, signal),
      ),
    ];
  }

  Future<AgentToolResult> _search(
    Map<String, dynamic> params,
    AbortSignal? signal,
  ) async {
    final query = (params['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _error('Parameter "query" is required.');
    final recencyName = (params['recency'] as String?)?.trim();
    if (recencyName != null &&
        recencyName.isNotEmpty &&
        !const ['any', 'day', 'week', 'month', 'year'].contains(recencyName)) {
      return _error('Unknown recency "$recencyName".');
    }
    final count =
        ((params['count'] as num?)?.toInt() ?? _config.defaultResultCount)
            .clamp(
              WebAccessConfig.minResultCount,
              WebAccessConfig.maxResultCount,
            );
    final cancel = _cancelTokenFor(signal);
    try {
      final response = await _gateway.search(
        config: _config,
        request: WebSearchRequest(
          query: query,
          resultCount: count,
          recency: WebSearchRecency.fromName(recencyName),
          includeDomains: _stringList(params['include_domains']),
          excludeDomains: _stringList(params['exclude_domains']),
        ),
        cancelToken: cancel.token,
      );
      return _json(response.toJson());
    } on WebAccessException catch (error) {
      return _error(error.message, kind: error.kind.name);
    } catch (error) {
      AppLogger.w('web_search failed: $error', 'AgentWebAccess');
      return _error('Web search failed.');
    } finally {
      cancel.dispose();
    }
  }

  Future<AgentToolResult> _read(
    Map<String, dynamic> params,
    AbortSignal? signal,
  ) async {
    final url = (params['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) return _error('Parameter "url" is required.');
    final maxCharacters = ((params['max_chars'] as num?)?.toInt() ?? 12000)
        .clamp(
          SafeWebReader.minContentCharacters,
          SafeWebReader.maxContentCharacters,
        );
    final cancel = _cancelTokenFor(signal);
    try {
      final page = await _gateway.read(
        config: _config,
        url: url,
        maxCharacters: maxCharacters,
        cancelToken: cancel.token,
      );
      return _json(page.toJson());
    } on WebAccessException catch (error) {
      return _error(error.message, kind: error.kind.name);
    } catch (error) {
      AppLogger.w('web_read failed: $error', 'AgentWebAccess');
      return _error('Web page read failed.');
    } finally {
      cancel.dispose();
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList(growable: false);
  }

  static AgentToolResult _json(Map<String, dynamic> value) {
    return AgentToolResult(
      content: [ToolResultTextContent(jsonEncode(value))],
      details: value,
    );
  }

  static AgentToolResult _error(String message, {String? kind}) {
    final details = <String, dynamic>{
      'ok': false,
      if (kind != null) 'error_kind': kind,
      'error': message,
    };
    return AgentToolResult(
      content: [ToolResultTextContent(jsonEncode(details))],
      details: details,
      isError: true,
    );
  }

  static _AbortCancelBridge _cancelTokenFor(AbortSignal? signal) {
    final token = CancelToken();
    void listener(String? reason) {
      if (!token.isCancelled) token.cancel(reason ?? 'Agent run aborted.');
    }

    signal?.addListener(listener);
    return _AbortCancelBridge(
      token: token,
      dispose: () => signal?.removeListener(listener),
    );
  }
}

class _AbortCancelBridge {
  const _AbortCancelBridge({required this.token, required this.dispose});

  final CancelToken token;
  final void Function() dispose;
}
