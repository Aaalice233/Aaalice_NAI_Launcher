import 'dart:convert';

enum WebSearchMode {
  auto,
  searxng,
  exaMcp,
  exaApi;

  static WebSearchMode fromName(String? value) => WebSearchMode.values
      .firstWhere((mode) => mode.name == value, orElse: () => auto);
}

enum WebSearchRecency {
  day,
  week,
  month,
  year;

  static WebSearchRecency? fromName(String? value) {
    if (value == null || value == 'any') return null;
    for (final recency in values) {
      if (recency.name == value) return recency;
    }
    return null;
  }
}

enum WebSearchBackend {
  searxng('searxng'),
  exaMcp('exa_mcp'),
  exaApi('exa_api'),
  localReader('local_reader');

  const WebSearchBackend(this.wireName);

  final String wireName;
}

enum WebAccessErrorKind {
  configuration,
  authentication,
  rateLimited,
  network,
  invalidResponse,
  unsupportedContent,
  blockedAddress,
  responseTooLarge,
  aborted,
}

class WebAccessException implements Exception {
  const WebAccessException(
    this.kind,
    this.message, {
    this.backend,
    this.statusCode,
  });

  final WebAccessErrorKind kind;
  final String message;
  final WebSearchBackend? backend;
  final int? statusCode;

  @override
  String toString() => message;
}

class WebAccessConfig {
  const WebAccessConfig({
    this.enabled = false,
    this.mode = WebSearchMode.auto,
    this.searxngBaseUrl = '',
    this.defaultResultCount = 5,
  });

  static const int minResultCount = 1;
  static const int maxResultCount = 10;

  final bool enabled;
  final WebSearchMode mode;
  final String searxngBaseUrl;
  final int defaultResultCount;

  bool get hasSearxngEndpoint => searxngBaseUrl.trim().isNotEmpty;

  WebAccessConfig copyWith({
    bool? enabled,
    WebSearchMode? mode,
    String? searxngBaseUrl,
    int? defaultResultCount,
  }) {
    return WebAccessConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      searxngBaseUrl: searxngBaseUrl ?? this.searxngBaseUrl,
      defaultResultCount: (defaultResultCount ?? this.defaultResultCount).clamp(
        minResultCount,
        maxResultCount,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'enabled': enabled,
    'mode': mode.name,
    'searxngBaseUrl': searxngBaseUrl,
    'defaultResultCount': defaultResultCount,
  };

  String encode() => jsonEncode(toJson());

  factory WebAccessConfig.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map) {
      throw const FormatException('Web access config must be a JSON object.');
    }
    final count = json['defaultResultCount'];
    return WebAccessConfig(
      enabled: json['enabled'] as bool? ?? false,
      mode: WebSearchMode.fromName(json['mode'] as String?),
      searxngBaseUrl: (json['searxngBaseUrl'] as String? ?? '').trim(),
      defaultResultCount: (count is num ? count.toInt() : 5).clamp(
        minResultCount,
        maxResultCount,
      ),
    );
  }
}

class WebSearchRequest {
  const WebSearchRequest({
    required this.query,
    required this.resultCount,
    this.recency,
    this.includeDomains = const [],
    this.excludeDomains = const [],
  });

  final String query;
  final int resultCount;
  final WebSearchRecency? recency;
  final List<String> includeDomains;
  final List<String> excludeDomains;
}

class WebSearchResult {
  const WebSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.publishedAt,
    this.author,
  });

  final String title;
  final String url;
  final String snippet;
  final String? publishedAt;
  final String? author;

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    if (snippet.isNotEmpty) 'snippet': snippet,
    if (publishedAt != null) 'published_at': publishedAt,
    if (author != null) 'author': author,
  };
}

class WebSearchResponse {
  const WebSearchResponse({
    required this.query,
    required this.backend,
    required this.results,
    this.fallbackFrom,
    this.fallbackReason,
  });

  final String query;
  final WebSearchBackend backend;
  final List<WebSearchResult> results;
  final WebSearchBackend? fallbackFrom;
  final WebAccessErrorKind? fallbackReason;

  WebSearchResponse withFallback(
    WebSearchBackend backend,
    WebAccessErrorKind reason,
  ) {
    return WebSearchResponse(
      query: query,
      backend: this.backend,
      results: results,
      fallbackFrom: backend,
      fallbackReason: reason,
    );
  }

  Map<String, dynamic> toJson() => {
    'ok': true,
    'query': query,
    'provider': backend.wireName,
    'result_count': results.length,
    'results': results.map((result) => result.toJson()).toList(),
    if (fallbackFrom != null)
      'fallback': {
        'from': fallbackFrom!.wireName,
        'reason': fallbackReason?.name,
      },
  };
}

class WebPageContent {
  const WebPageContent({
    required this.url,
    required this.title,
    required this.content,
    required this.contentType,
    required this.truncated,
  });

  final String url;
  final String title;
  final String content;
  final String contentType;
  final bool truncated;

  Map<String, dynamic> toJson() => {
    'ok': true,
    'provider': WebSearchBackend.localReader.wireName,
    'url': url,
    if (title.isNotEmpty) 'title': title,
    'content_type': contentType,
    'truncated': truncated,
    'content': content,
  };
}
