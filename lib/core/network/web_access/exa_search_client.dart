import 'dart:convert';

import 'package:dio/dio.dart';

import 'web_access_models.dart';
import 'web_access_utils.dart';

class ExaSearchClient {
  ExaSearchClient(
    this._dio, {
    Uri? apiBaseUrl,
    Uri? mcpEndpoint,
    DateTime Function()? now,
  }) : _apiBaseUrl = apiBaseUrl ?? Uri.parse('https://api.exa.ai'),
       _mcpEndpoint = mcpEndpoint ?? Uri.parse('https://mcp.exa.ai/mcp'),
       _now = now ?? DateTime.now;

  static const Duration _timeout = Duration(seconds: 60);
  static const String _basicMcpTool = 'web_search_exa';
  static const String _advancedMcpTool = 'web_search_advanced_exa';

  final Dio _dio;
  final Uri _apiBaseUrl;
  final Uri _mcpEndpoint;
  final DateTime Function() _now;

  Future<WebSearchResponse> searchMcp(
    WebSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final hasFilters =
        request.recency != null ||
        request.includeDomains.isNotEmpty ||
        request.excludeDomains.isNotEmpty;
    if (hasFilters) {
      try {
        return await _searchMcpTool(
          _advancedMcpTool,
          _directSearchArguments(request)..addAll(const {
            'enableHighlights': true,
            'textMaxCharacters': 3000,
          }),
          request,
          cancelToken,
        );
      } on WebAccessException catch (error) {
        if (error.kind == WebAccessErrorKind.aborted ||
            error.kind == WebAccessErrorKind.rateLimited) {
          rethrow;
        }
        // Some public MCP deployments expose only the basic tool. Preserve
        // filters as query operators rather than dropping the search.
      }
    }

    return _searchMcpTool(
      _basicMcpTool,
      {'query': _buildMcpQuery(request), 'numResults': request.resultCount},
      request,
      cancelToken,
    );
  }

  Future<WebSearchResponse> searchApi(
    WebSearchRequest request, {
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'Exa API mode requires an API key.',
        backend: WebSearchBackend.exaApi,
      );
    }
    final endpoint = _apiBaseUrl.resolve('/search');
    try {
      final response = await _dio.postUri<Object?>(
        endpoint,
        data: {
          ..._directSearchArguments(request),
          'contents': const {'highlights': true},
        },
        cancelToken: cancelToken,
        options: Options(
          headers: {'x-api-key': key, 'Content-Type': 'application/json'},
          responseType: ResponseType.plain,
          followRedirects: false,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw WebAccessException(
          status == 401 || status == 403
              ? WebAccessErrorKind.authentication
              : status == 429
              ? WebAccessErrorKind.rateLimited
              : WebAccessErrorKind.network,
          status == 429
              ? 'Exa API rate limit reached (HTTP 429).'
              : 'Exa API search failed (HTTP $status).',
          backend: WebSearchBackend.exaApi,
          statusCode: status,
        );
      }
      final data = decodeJsonObject(response.data, 'Exa API');
      return WebSearchResponse(
        query: request.query,
        backend: WebSearchBackend.exaApi,
        results: _filterResults(
          _parseApiResults(data['results'], request.resultCount),
          request,
        ),
      );
    } on WebAccessException {
      rethrow;
    } on DioException catch (error) {
      throw mapWebDioException(
        error,
        WebSearchBackend.exaApi,
        service: 'Exa API',
      );
    } on FormatException catch (error) {
      throw WebAccessException(
        WebAccessErrorKind.invalidResponse,
        'Exa API returned invalid JSON: ${error.message}',
        backend: WebSearchBackend.exaApi,
      );
    }
  }

  Future<WebSearchResponse> _searchMcpTool(
    String toolName,
    Map<String, dynamic> arguments,
    WebSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final endpoint = _mcpEndpoint.replace(
      queryParameters: {..._mcpEndpoint.queryParameters, 'tools': toolName},
    );
    try {
      final response = await _dio.postUri<Object?>(
        endpoint,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {'name': toolName, 'arguments': arguments},
        },
        cancelToken: cancelToken,
        options: Options(
          headers: const {
            'Accept': 'application/json, text/event-stream',
            'Content-Type': 'application/json',
            'x-exa-source': 'aaalice-nai-launcher',
          },
          responseType: ResponseType.plain,
          followRedirects: false,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw WebAccessException(
          status == 429
              ? WebAccessErrorKind.rateLimited
              : WebAccessErrorKind.network,
          status == 429
              ? 'Exa MCP free-plan rate limit reached (HTTP 429).'
              : 'Exa MCP search failed (HTTP $status).',
          backend: WebSearchBackend.exaMcp,
          statusCode: status,
        );
      }

      final rpc = _parseRpcEnvelope(response.data?.toString() ?? '');
      final rpcError = rpc['error'];
      if (rpcError is Map) {
        throw WebAccessException(
          WebAccessErrorKind.invalidResponse,
          'Exa MCP error: ${normalizeWebText(rpcError['message'])}',
          backend: WebSearchBackend.exaMcp,
        );
      }
      final result = rpc['result'];
      if (result is! Map) {
        throw const WebAccessException(
          WebAccessErrorKind.invalidResponse,
          'Exa MCP response is missing the result object.',
          backend: WebSearchBackend.exaMcp,
        );
      }
      if (result['isError'] == true) {
        throw _mcpToolError(
          _firstMcpText(result['content']) ?? 'Exa MCP returned an error.',
        );
      }
      final text = _firstMcpText(result['content']);
      if (text == null || text.trim().isEmpty) {
        throw const WebAccessException(
          WebAccessErrorKind.invalidResponse,
          'Exa MCP returned empty search content.',
          backend: WebSearchBackend.exaMcp,
        );
      }
      final results = _filterResults(
        _parseMcpResults(text, request.resultCount),
        request,
      );
      if (results.isEmpty) {
        throw const WebAccessException(
          WebAccessErrorKind.invalidResponse,
          'Exa MCP search content did not contain any source URLs.',
          backend: WebSearchBackend.exaMcp,
        );
      }
      return WebSearchResponse(
        query: request.query,
        backend: WebSearchBackend.exaMcp,
        results: results,
      );
    } on WebAccessException {
      rethrow;
    } on DioException catch (error) {
      throw mapWebDioException(
        error,
        WebSearchBackend.exaMcp,
        service: 'Exa MCP',
      );
    } on FormatException catch (error) {
      throw WebAccessException(
        WebAccessErrorKind.invalidResponse,
        'Exa MCP returned invalid JSON: ${error.message}',
        backend: WebSearchBackend.exaMcp,
      );
    }
  }

  Map<String, dynamic> _directSearchArguments(WebSearchRequest request) {
    return {
      'query': request.query,
      'type': 'auto',
      'numResults': request.resultCount,
      if (_normalizedDomains(request.includeDomains).isNotEmpty)
        'includeDomains': _normalizedDomains(request.includeDomains),
      if (_normalizedDomains(request.excludeDomains).isNotEmpty)
        'excludeDomains': _normalizedDomains(request.excludeDomains),
      if (request.recency != null)
        'startPublishedDate': _recencyStartDate(request.recency!),
    };
  }

  String _recencyStartDate(WebSearchRecency recency) {
    final days = switch (recency) {
      WebSearchRecency.day => 1,
      WebSearchRecency.week => 7,
      WebSearchRecency.month => 30,
      WebSearchRecency.year => 365,
    };
    return _now().toUtc().subtract(Duration(days: days)).toIso8601String();
  }

  static List<String> _normalizedDomains(List<String> values) => {
    for (final value in values)
      if (normalizeWebDomain(value) case final domain?) domain,
  }.toList(growable: false);

  String _buildMcpQuery(WebSearchRequest request) {
    final parts = <String>[request.query.trim()];
    for (final domain in _normalizedDomains(request.includeDomains)) {
      parts.add('site:$domain');
    }
    for (final domain in _normalizedDomains(request.excludeDomains)) {
      parts.add('-site:$domain');
    }
    if (request.recency != null) {
      parts.add('published after ${_recencyStartDate(request.recency!)}');
    }
    return parts.join(' ');
  }

  static Map<String, dynamic> _parseRpcEnvelope(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const WebAccessException(
        WebAccessErrorKind.invalidResponse,
        'Exa MCP returned an empty response.',
        backend: WebSearchBackend.exaMcp,
      );
    }
    if (trimmed.startsWith('{')) {
      return decodeJsonObject(trimmed, 'Exa MCP');
    }
    for (final line in const LineSplitter().convert(body)) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final candidate = decodeJsonObject(payload, 'Exa MCP');
        if (candidate.containsKey('result') || candidate.containsKey('error')) {
          return candidate;
        }
      } on FormatException {
        continue;
      } on WebAccessException {
        continue;
      }
    }
    throw const WebAccessException(
      WebAccessErrorKind.invalidResponse,
      'Exa MCP returned no JSON-RPC result event.',
      backend: WebSearchBackend.exaMcp,
    );
  }

  static String? _firstMcpText(Object? content) {
    if (content is! List) return null;
    for (final item in content) {
      if (item is! Map || item['type'] != 'text') continue;
      final text = item['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return null;
  }

  static WebAccessException _mcpToolError(String message) {
    final normalized = message.toLowerCase();
    final rateLimited =
        normalized.contains('429') || normalized.contains('rate limit');
    return WebAccessException(
      rateLimited
          ? WebAccessErrorKind.rateLimited
          : WebAccessErrorKind.invalidResponse,
      rateLimited ? 'Exa MCP free-plan rate limit reached.' : message,
      backend: WebSearchBackend.exaMcp,
      statusCode: rateLimited ? 429 : null,
    );
  }

  static List<WebSearchResult> _parseMcpResults(String text, int limit) {
    try {
      final json = jsonDecode(text);
      if (json is Map) {
        final parsed = _parseApiResults(json['results'], limit);
        if (parsed.isNotEmpty) return parsed;
      }
    } on FormatException {
      // The basic MCP tool returns a human-readable Title/URL/Text format.
    }

    final blockPattern = RegExp(
      r'(?:^|\n)Title:\s*(.*?)\r?\nURL:\s*(\S+)(.*?)(?=\r?\nTitle:|$)',
      multiLine: true,
      dotAll: true,
    );
    final results = <WebSearchResult>[];
    final seen = <String>{};
    for (final match in blockPattern.allMatches(text)) {
      final uri = parseHttpWebUri(match.group(2));
      if (uri == null) continue;
      final url = uri.toString();
      if (!seen.add(url)) continue;
      var body = match.group(3) ?? '';
      final marker = RegExp(r'\r?\n(?:Text|Highlights):\s*\r?\n?');
      final markerMatch = marker.firstMatch(body);
      if (markerMatch != null) body = body.substring(markerMatch.end);
      body = body.replaceFirst(RegExp(r'\r?\n---\s*$'), '');
      results.add(
        WebSearchResult(
          title: normalizeWebText(match.group(1), maxCharacters: 240),
          url: url,
          snippet: normalizeWebText(body),
        ),
      );
      if (results.length >= limit) break;
    }
    return results;
  }

  static List<WebSearchResult> _parseApiResults(Object? raw, int limit) {
    if (raw is! List) return const [];
    final results = <WebSearchResult>[];
    final seen = <String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final uri = parseHttpWebUri(entry['url']);
      if (uri == null) continue;
      final url = uri.toString();
      if (!seen.add(url)) continue;
      final highlights = entry['highlights'];
      final highlightText = highlights is List
          ? highlights.whereType<String>().join(' ')
          : '';
      results.add(
        WebSearchResult(
          title: normalizeWebText(entry['title'], maxCharacters: 240),
          url: url,
          snippet: normalizeWebText(
            highlightText.isNotEmpty ? highlightText : entry['text'],
          ),
          publishedAt: _optionalText(entry['publishedDate']),
          author: _optionalText(entry['author']),
        ),
      );
      if (results.length >= limit) break;
    }
    return results;
  }

  static List<WebSearchResult> _filterResults(
    List<WebSearchResult> results,
    WebSearchRequest request,
  ) {
    final included = _normalizedDomains(request.includeDomains);
    final excluded = _normalizedDomains(request.excludeDomains);
    return results
        .where((result) {
          final uri = parseHttpWebUri(result.url);
          return uri != null &&
              matchesWebDomainFilters(uri.host, included, excluded);
        })
        .take(request.resultCount)
        .toList(growable: false);
  }

  static String? _optionalText(Object? value) {
    final text = normalizeWebText(value, maxCharacters: 160);
    return text.isEmpty ? null : text;
  }
}
