import 'package:dio/dio.dart';

import 'exa_search_client.dart';
import 'safe_web_reader.dart';
import 'searxng_search_client.dart';
import 'web_access_models.dart';

abstract interface class WebAccessGateway {
  Future<WebSearchResponse> search({
    required WebAccessConfig config,
    required WebSearchRequest request,
    CancelToken? cancelToken,
  });

  Future<WebPageContent> read({
    required WebAccessConfig config,
    required String url,
    required int maxCharacters,
    CancelToken? cancelToken,
  });

  Future<WebSearchResponse> testConnection(WebAccessConfig config);
}

class WebAccessService implements WebAccessGateway {
  WebAccessService({
    required SearxngSearchClient searxng,
    required ExaSearchClient exa,
    required SafeWebReader reader,
    required Future<String?> Function() loadExaApiKey,
  }) : _searxng = searxng,
       _exa = exa,
       _reader = reader,
       _loadExaApiKey = loadExaApiKey;

  final SearxngSearchClient _searxng;
  final ExaSearchClient _exa;
  final SafeWebReader _reader;
  final Future<String?> Function() _loadExaApiKey;

  @override
  Future<WebSearchResponse> search({
    required WebAccessConfig config,
    required WebSearchRequest request,
    CancelToken? cancelToken,
  }) async {
    if (!config.enabled) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'Agent web access is disabled in settings.',
      );
    }
    final normalized = _normalizeRequest(request);
    return switch (config.mode) {
      WebSearchMode.auto => _searchAuto(config, normalized, cancelToken),
      WebSearchMode.searxng => _searchSearxng(config, normalized, cancelToken),
      WebSearchMode.exaMcp => _exa.searchMcp(
        normalized,
        cancelToken: cancelToken,
      ),
      WebSearchMode.exaApi => _searchExaApi(normalized, cancelToken),
    };
  }

  @override
  Future<WebPageContent> read({
    required WebAccessConfig config,
    required String url,
    required int maxCharacters,
    CancelToken? cancelToken,
  }) {
    if (!config.enabled) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'Agent web access is disabled in settings.',
      );
    }
    // Page reads stay local for every search backend. This avoids silently
    // forwarding arbitrary URLs to Exa and keeps the network boundary clear.
    return _reader.read(
      url,
      maxCharacters: maxCharacters,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<WebSearchResponse> testConnection(WebAccessConfig config) {
    return search(
      config: config.copyWith(enabled: true),
      request: const WebSearchRequest(
        query: 'Exa SearXNG connectivity test',
        resultCount: 1,
      ),
    );
  }

  Future<WebSearchResponse> _searchAuto(
    WebAccessConfig config,
    WebSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    if (!config.hasSearxngEndpoint) {
      return _exa.searchMcp(request, cancelToken: cancelToken);
    }
    try {
      return await _searchSearxng(config, request, cancelToken);
    } on WebAccessException catch (error) {
      if (error.kind == WebAccessErrorKind.aborted ||
          error.kind == WebAccessErrorKind.configuration) {
        rethrow;
      }
      final fallback = await _exa.searchMcp(request, cancelToken: cancelToken);
      return fallback.withFallback(WebSearchBackend.searxng, error.kind);
    }
  }

  Future<WebSearchResponse> _searchSearxng(
    WebAccessConfig config,
    WebSearchRequest request,
    CancelToken? cancelToken,
  ) {
    if (!config.hasSearxngEndpoint) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'SearXNG mode requires a Base URL.',
        backend: WebSearchBackend.searxng,
      );
    }
    return _searxng.search(
      baseUrl: config.searxngBaseUrl,
      request: request,
      cancelToken: cancelToken,
    );
  }

  Future<WebSearchResponse> _searchExaApi(
    WebSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final apiKey = await _loadExaApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'Exa API mode requires an API key in settings.',
        backend: WebSearchBackend.exaApi,
      );
    }
    return _exa.searchApi(request, apiKey: apiKey, cancelToken: cancelToken);
  }

  static WebSearchRequest _normalizeRequest(WebSearchRequest request) {
    final query = request.query.trim();
    if (query.isEmpty) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'web_search requires a non-empty query.',
      );
    }
    return WebSearchRequest(
      query: query,
      resultCount: request.resultCount.clamp(
        WebAccessConfig.minResultCount,
        WebAccessConfig.maxResultCount,
      ),
      recency: request.recency,
      includeDomains: request.includeDomains.take(10).toList(growable: false),
      excludeDomains: request.excludeDomains.take(10).toList(growable: false),
    );
  }
}
