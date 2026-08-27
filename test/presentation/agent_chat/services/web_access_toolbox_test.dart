import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/web_access/web_access_models.dart';
import 'package:nai_launcher/core/network/web_access/web_access_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/web_access_toolbox.dart';

void main() {
  test('does not expose web tools while web access is disabled', () {
    final tools = WebAccessToolbox(
      config: const WebAccessConfig(),
      loadGateway: _FakeWebAccessGateway.new,
    ).tools();

    expect(tools, isEmpty);
  });

  test(
    'web_search applies configured defaults and returns structured JSON',
    () async {
      final gateway = _FakeWebAccessGateway();
      final tools = WebAccessToolbox(
        config: const WebAccessConfig(enabled: true, defaultResultCount: 8),
        loadGateway: () => gateway,
      ).tools();
      final search = tools.singleWhere((tool) => tool.name == 'web_search');

      final result = await search.execute('call', {
        'query': 'Flutter web tools',
        'recency': 'week',
      });

      expect(result.isError, isFalse);
      expect(gateway.lastSearch?.resultCount, 8);
      expect(gateway.lastSearch?.recency, WebSearchRecency.week);
      expect((result.details as Map)['provider'], 'exa_mcp');
    },
  );

  test('web_read uses an explicit bounded max_chars value', () async {
    final gateway = _FakeWebAccessGateway();
    final tools = WebAccessToolbox(
      config: const WebAccessConfig(enabled: true),
      loadGateway: () => gateway,
    ).tools();
    final read = tools.singleWhere((tool) => tool.name == 'web_read');

    final result = await read.execute('call', {
      'url': 'https://example.com',
      'max_chars': 900,
    });

    expect(result.isError, isFalse);
    expect(gateway.lastReadMaxCharacters, 900);
    expect((result.details as Map)['content'], 'Page content');
  });

  test('resolves the current gateway for each tool invocation', () async {
    final first = _FakeWebAccessGateway();
    final second = _FakeWebAccessGateway();
    var current = first;
    final search = WebAccessToolbox(
      config: const WebAccessConfig(enabled: true),
      loadGateway: () => current,
    ).tools().singleWhere((tool) => tool.name == 'web_search');

    await search.execute('first', {'query': 'before proxy change'});
    current = second;
    await search.execute('second', {'query': 'after proxy change'});

    expect(first.searchCalls, 1);
    expect(second.searchCalls, 1);
    expect(second.lastSearch?.query, 'after proxy change');
  });
}

class _FakeWebAccessGateway implements WebAccessGateway {
  WebSearchRequest? lastSearch;
  int? lastReadMaxCharacters;
  int searchCalls = 0;

  @override
  Future<WebSearchResponse> search({
    required WebAccessConfig config,
    required WebSearchRequest request,
    CancelToken? cancelToken,
  }) async {
    searchCalls++;
    lastSearch = request;
    return WebSearchResponse(
      query: request.query,
      backend: WebSearchBackend.exaMcp,
      results: const [
        WebSearchResult(
          title: 'Result',
          url: 'https://example.com/result',
          snippet: 'Snippet',
        ),
      ],
    );
  }

  @override
  Future<WebPageContent> read({
    required WebAccessConfig config,
    required String url,
    required int maxCharacters,
    CancelToken? cancelToken,
  }) async {
    lastReadMaxCharacters = maxCharacters;
    return WebPageContent(
      url: url,
      title: 'Page',
      content: 'Page content',
      contentType: 'text/html',
      truncated: false,
    );
  }

  @override
  Future<WebSearchResponse> testConnection(WebAccessConfig config) => search(
    config: config,
    request: const WebSearchRequest(query: 'test', resultCount: 1),
  );
}
