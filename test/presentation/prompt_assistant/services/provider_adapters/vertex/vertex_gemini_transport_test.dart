import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/data/models/prompt_assistant/vertex_target.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/gemini_generate_content_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/gemini_transport.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/provider_adapter_registry.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_access_tokens.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_gemini_transport.dart';

import 'vertex_test_support.dart';

const _sseReply =
    'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"hi"}]},'
    '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,'
    '"candidatesTokenCount":1,"totalTokenCount":4}}\n\n';

ProviderConfig _vertex({
  String projectId = '',
  String location = 'global',
  String baseUrl = '',
}) => ProviderPreset.googleVertex
    .createConfig(id: 'vertex')
    .copyWith(
      baseUrl: baseUrl,
      vertex: VertexTarget(projectId: projectId, location: location),
    );

AgentChatRequest _agentRequest(ProviderConfig provider, String credential) =>
    AgentChatRequest(
      sessionId: 'session',
      provider: provider,
      model: 'gemini-3.1-pro-preview',
      systemPrompt: 'system',
      messages: [UserMessage.text('hello')],
      tools: const [],
      apiKey: credential,
    );

void main() {
  late VertexAccessTokens tokens;
  late GeminiGenerateContentAdapter adapter;

  setUp(() {
    tokens = VertexAccessTokens(clock: () => DateTime.utc(2026, 11, 23));
    adapter = GeminiGenerateContentAdapter(
      transport: VertexGeminiTransport(tokens),
    );
  });

  Dio dioWith(FakeGoogleServer server) {
    final dio = Dio()..httpClientAdapter = server;
    addTearDown(dio.close);
    return dio;
  }

  FakeGoogleServer vertexServer({FakeResponse? api}) =>
      FakeGoogleServer(
        (request) => request.uri.path == '/token'
            ? tokenResponse(token: 'vertex-token')
            : api ?? const FakeResponse.sse(_sseReply),
      );

  Future<List<AgentWireEvent>> stream(
    FakeGoogleServer server,
    ProviderConfig provider,
    String credential,
  ) => adapter
      .completeAgent(
        dio: dioWith(server),
        request: _agentRequest(provider, credential),
        cancelToken: CancelToken(),
      )
      .toList();

  test('服务账号走 global 端点的项目路径并带 Bearer 令牌', () async {
    final server = vertexServer();
    final events = await stream(server, _vertex(), serviceAccountJson());

    expect(events.whereType<AgentWireTextDelta>().single.delta, 'hi');
    expect(events.last, isA<AgentWireFinish>());
    final api = server.apiRequests.single;
    expect(
      api.uri.toString(),
      'https://aiplatform.googleapis.com/v1/projects/sa-project/locations/'
      'global/publishers/google/models/gemini-3.1-pro-preview:'
      'streamGenerateContent?alt=sse',
    );
    expect(api.options.headers['Authorization'], 'Bearer vertex-token');
    expect(api.options.headers.containsKey('x-goog-user-project'), isFalse);
    expect(api.json['contents'], [
      {
        'role': 'user',
        'parts': [
          {'text': 'hello'},
        ],
      },
    ]);
  });

  test('区域端点与配置的项目 ID 优先于凭据项目', () async {
    final server = vertexServer();
    await stream(
      server,
      _vertex(projectId: 'configured', location: 'us-central1'),
      serviceAccountJson(),
    );
    expect(
      server.apiRequests.single.uri.toString(),
      startsWith(
        'https://us-central1-aiplatform.googleapis.com/v1/projects/'
        'configured/locations/us-central1/publishers/google/models/',
      ),
    );
  });

  test('gcloud 用户凭据带配额项目头', () async {
    final server = vertexServer();
    await stream(server, _vertex(), authorizedUserJson());
    final api = server.apiRequests.single;
    expect(api.uri.path, contains('/projects/quota-project/'));
    expect(api.options.headers['x-goog-user-project'], 'quota-project');
  });

  test('API Key 走 express 路径，不换令牌', () async {
    final server = vertexServer();
    await stream(server, _vertex(projectId: 'ignored'), 'AQ.express-key');
    expect(server.tokenRequests, isEmpty);
    final api = server.apiRequests.single;
    expect(
      api.uri.toString(),
      'https://aiplatform.googleapis.com/v1/publishers/google/models/'
      'gemini-3.1-pro-preview:streamGenerateContent?alt=sse',
    );
    expect(api.options.headers['x-goog-api-key'], 'AQ.express-key');
    expect(api.options.headers.containsKey('Authorization'), isFalse);
  });

  test('API Key 使用全球主机，OAuth 的 us 和 eu 使用对应多区域主机', () async {
    final oauth = serviceAccountJson(
      tokenUri: 'https://oauth2.example-cloud.eu/token',
      universeDomain: 'example-cloud.eu',
    );
    for (final (key, region, host) in [
      ('AQ.express-key', 'europe-west4', 'aiplatform.googleapis.com'),
      ('AQ.express-key', 'us', 'aiplatform.googleapis.com'),
      (oauth, 'us', 'aiplatform.us.rep.example-cloud.eu'),
      (oauth, 'eu', 'aiplatform.eu.rep.example-cloud.eu'),
    ]) {
      final server = vertexServer();
      await stream(server, _vertex(location: region), key);
      expect(server.apiRequests.single.uri.host, host);
    }
  });

  test('自定义 Base URL 只替换主机，版本按请求拼接', () async {
    final server = vertexServer();
    await stream(
      server,
      _vertex(baseUrl: 'https://vertex-proxy.internal/v1/'),
      serviceAccountJson(),
    );
    expect(
      server.apiRequests.single.uri.toString(),
      startsWith('https://vertex-proxy.internal/v1/projects/sa-project/'),
    );
  });

  test('缺少项目、凭据或区域非法时给出明确错误且不发请求', () async {
    final server = vertexServer();
    final noProject = await stream(
      server,
      _vertex(),
      serviceAccountJson(projectId: null),
    );
    expect(
      noProject.whereType<AgentWireError>().single.message,
      contains('Project ID is not configured'),
    );
    final noCredential = await stream(server, _vertex(), '');
    expect(
      noCredential.whereType<AgentWireError>().single.message,
      contains('Credential is not configured'),
    );
    final badLocation = await stream(
      server,
      _vertex(location: 'evil.example/x'),
      serviceAccountJson(),
    );
    expect(
      badLocation.whereType<AgentWireError>().single.message,
      contains('Invalid location'),
    );
    expect(server.apiRequests, isEmpty);
  });

  test('Vertex 返回 401 后丢弃缓存令牌，下次重新换取', () async {
    var issued = 0;
    var reject = true;
    final server = FakeGoogleServer((request) {
      if (request.uri.path == '/token') {
        return tokenResponse(token: 'token-${++issued}');
      }
      return reject
          ? FakeResponse.json({
              'error': {'code': 401, 'message': 'expired'},
            }, status: 401)
          : const FakeResponse.sse(_sseReply);
    });

    final failed = await stream(server, _vertex(), serviceAccountJson());
    expect(failed.whereType<AgentWireError>(), hasLength(1));
    reject = false;
    await stream(server, _vertex(), serviceAccountJson());

    expect(server.tokenRequests, hasLength(2));
    expect(
      server.apiRequests.last.options.headers['Authorization'],
      'Bearer token-2',
    );
  });

  test('单次补全走 generateContent', () async {
    final server = vertexServer(
      api: FakeResponse.json({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'thinking', 'thought': true},
                {'text': 'answer'},
              ],
            },
          },
        ],
      }),
    );
    final content = await adapter.complete(
      dio: dioWith(server),
      request: PromptAssistantRequest(
        sessionId: 's',
        provider: _vertex(),
        model: 'models/gemini-3.1-pro-preview',
        systemPrompt: 'system',
        userParts: [PromptAssistantContentPart.text('hello')],
        apiKey: serviceAccountJson(),
      ),
      cancelToken: CancelToken(),
    );
    expect(content, 'answer');
    expect(
      server.apiRequests.single.uri.path,
      '/v1/projects/sa-project/locations/global/publishers/google/models/'
      'gemini-3.1-pro-preview:generateContent',
    );
  });

  test('模型列表与生成在 OAuth 缺项目时返回相同错误且不发请求', () async {
    final server = vertexServer(api: FakeResponse.json({'publisherModels': []}));
    final dio = dioWith(server);
    final provider = _vertex();
    final missingProject = throwsA(
      isA<VertexConfigurationException>().having(
        (error) => error.message,
        'message',
        'Project ID is not configured and the credential has none',
      ),
    );
    for (final key in [
      serviceAccountJson(projectId: null),
      authorizedUserJson(quotaProjectId: null),
    ]) {
      await expectLater(
        adapter.transport.resolve(
          dio: dio,
          provider: provider,
          credential: key,
          model: 'gemini-2.5-flash',
          method: GeminiMethod.generateContent,
        ),
        missingProject,
      );
      await expectLater(
        adapter.fetchModels(dio: dio, provider: provider, apiKey: key),
        missingProject,
      );
    }
    await expectLater(
      adapter.fetchModels(
        dio: dio,
        provider: _vertex(
          baseUrl: 'https://vertex-proxy.internal',
          location: 'Bad.Region',
        ),
        apiKey: serviceAccountJson(),
      ),
      throwsA(
        isA<VertexConfigurationException>().having(
          (error) => error.message,
          'message',
          'Invalid location "Bad.Region"',
        ),
      ),
    );
    expect(server.requests, isEmpty);
    await adapter.fetchModels(
      dio: dio,
      provider: provider,
      apiKey: 'AQ.express-key',
    );
    expect(server.apiRequests, hasLength(1));
    expect(server.tokenRequests, isEmpty);
  });

  test('模型列表翻页并只保留 Gemini 对话模型', () async {
    final server = FakeGoogleServer((request) {
      if (request.uri.path == '/token') return tokenResponse();
      final page = request.uri.queryParameters['pageToken'];
      return FakeResponse.json(
        page == null
            ? {
                'publisherModels': [
                  {'name': 'publishers/google/models/gemini-3.1-pro-preview'},
                  {'name': 'publishers/google/models/imagen-4.0-generate'},
                ],
                'nextPageToken': 'p2',
              }
            : {
                'publisherModels': [
                  {'name': 'publishers/google/models/gemini-2.5-flash'},
                  {'name': 'publishers/google/models/gemini-embedding-001'},
                ],
              },
      );
    });

    final models = await adapter.fetchModels(
      dio: dioWith(server),
      provider: _vertex(),
      apiKey: serviceAccountJson(),
    );

    expect(models, ['gemini-2.5-flash', 'gemini-3.1-pro-preview']);
    expect(server.apiRequests, hasLength(2));
    expect(
      server.apiRequests.first.uri.path,
      '/v1beta1/publishers/google/models',
    );
  });

  test('按模型 ID 排除不能文本对话的发布方模型', () {
    // 取自真实 publishers/google/models 返回的命名。
    const chat = [
      'gemini-1.5-pro-002',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.5-pro-exp-03-25',
      'gemini-3-flash-preview',
      'gemini-3.1-pro-preview',
      'gemini-3.8-flash',
      'gemini-4-carbon',
      'gemini-omni-1.2-flash',
    ];
    const nonChat = [
      'gemini-embedding-2',
      'gemini-2.5-flash-tts',
      'gemini-3.8-flash-lite-tts',
      'gemini-3-pro-image',
      'gemini-3.1-flash-image-preview',
      'gemini-3.1-flash-lite-image',
      'gemini-3.5-transcribe',
      'gemini-3.5-transcribe-live-preview',
      'gemini-3.5-live-translate-preview',
      'gemini-live-2.5-flash-native-audio',
      'gemini-nano-banana-2.1',
      'imagen-4.0-generate',
      'text-embedding-005',
    ];
    for (final id in chat) {
      expect(isVertexChatModel(id), isTrue, reason: id);
    }
    for (final id in nonChat) {
      expect(isVertexChatModel(id), isFalse, reason: id);
    }
  });

  test('分发按预设选择 Vertex 或 AI Studio 传输层', () {
    final vertex = providerAdapterFor(_vertex());
    final gemini = providerAdapterFor(ProviderPreset.gemini.createConfig());
    expect(
      (vertex as GeminiGenerateContentAdapter).transport,
      isA<VertexGeminiTransport>(),
    );
    expect(
      (gemini as GeminiGenerateContentAdapter).transport,
      isA<GoogleAiStudioTransport>(),
    );
  });
}
