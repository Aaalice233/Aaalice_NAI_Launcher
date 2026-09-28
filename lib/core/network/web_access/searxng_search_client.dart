import 'package:dio/dio.dart';

import 'web_access_models.dart';
import 'web_access_utils.dart';

class SearxngSearchClient {
  SearxngSearchClient(this._dio);

  static const Duration _timeout = Duration(seconds: 30);

  final Dio _dio;

  Future<WebSearchResponse> search({
    required String baseUrl,
    required WebSearchRequest request,
    CancelToken? cancelToken,
  }) async {
    final endpoint = buildEndpoint(baseUrl, request);
    try {
      final response = await _dio.getUri<Object?>(
        endpoint,
        cancelToken: cancelToken,
        options: Options(
          headers: const {'Accept': 'application/json'},
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
          'SearXNG search failed (HTTP $status). Ensure JSON output is enabled.',
          backend: WebSearchBackend.searxng,
          statusCode: status,
        );
      }

      final data = decodeJsonObject(response.data, 'SearXNG');
      final rawResults = data['results'];
      if (rawResults is! List) {
        throw const WebAccessException(
          WebAccessErrorKind.invalidResponse,
          'SearXNG response is missing the results array.',
          backend: WebSearchBackend.searxng,
        );
      }

      final includeDomains = _normalizedDomains(request.includeDomains);
      final excludeDomains = _normalizedDomains(request.excludeDomains);
      final seenUrls = <String>{};
      final results = <WebSearchResult>[];
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final item = raw.cast<Object?, Object?>();
        final uri = parseHttpWebUri(item['url']);
        if (uri == null) continue;
        final url = uri.toString();
        if (!seenUrls.add(url)) continue;
        if (!matchesWebDomainFilters(
          uri.host,
          includeDomains,
          excludeDomains,
        )) {
          continue;
        }
        results.add(
          WebSearchResult(
            title: normalizeWebText(item['title'], maxCharacters: 240),
            url: url,
            snippet: normalizeWebText(item['content']),
            publishedAt: _optionalText(item['publishedDate']),
          ),
        );
        if (results.length >= request.resultCount) break;
      }

      return WebSearchResponse(
        query: request.query,
        backend: WebSearchBackend.searxng,
        results: results,
      );
    } on WebAccessException {
      rethrow;
    } on DioException catch (error) {
      throw mapWebDioException(
        error,
        WebSearchBackend.searxng,
        service: 'SearXNG',
      );
    } on FormatException catch (error) {
      throw WebAccessException(
        WebAccessErrorKind.invalidResponse,
        'SearXNG returned invalid JSON: ${error.message}',
        backend: WebSearchBackend.searxng,
      );
    }
  }

  static Uri buildEndpoint(String baseUrl, WebSearchRequest request) {
    final base = _normalizeBaseUrl(baseUrl);
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    final query = _buildSearchQuery(request);
    return base.replace(
      path: '$basePath/search',
      queryParameters: {
        'q': query,
        'format': 'json',
        if (request.recency != null) 'time_range': request.recency!.name,
      },
    );
  }

  static Uri _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'SearXNG Base URL must be an HTTP(S) origin without credentials, query, or fragment.',
        backend: WebSearchBackend.searxng,
      );
    }
    return uri;
  }

  static String _buildSearchQuery(WebSearchRequest request) {
    final parts = <String>[request.query.trim()];
    final included = _normalizedDomains(request.includeDomains);
    if (included.length == 1) {
      parts.add('site:${included.first}');
    } else if (included.length > 1) {
      parts.add('(${included.map((domain) => 'site:$domain').join(' OR ')})');
    }
    for (final domain in _normalizedDomains(request.excludeDomains)) {
      parts.add('-site:$domain');
    }
    return parts.join(' ');
  }

  static List<String> _normalizedDomains(List<String> values) => {
    for (final value in values)
      if (normalizeWebDomain(value) case final domain?) domain,
  }.toList(growable: false);

  static String? _optionalText(Object? value) {
    final text = normalizeWebText(value, maxCharacters: 120);
    return text.isEmpty ? null : text;
  }
}
