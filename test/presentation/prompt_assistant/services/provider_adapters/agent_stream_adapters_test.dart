import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/gemini_generate_content_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_chat_completions_adapter.dart';

void main() {
  test(
    'OpenAI chat stream does not emit finish after an error event',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _SseAdapter(
          'data: {"error":{"message":"upstream failed"}}\n\n'
          'data: [DONE]\n\n',
        );
      addTearDown(dio.close);

      final events = await const OpenAiChatCompletionsAdapter()
          .completeAgent(
            dio: dio,
            request: _request(ProviderProtocol.openaiChatCompletions),
            cancelToken: CancelToken(),
          )
          .toList();

      expect(events.whereType<AgentWireError>(), hasLength(1));
      expect(events.whereType<AgentWireFinish>(), isEmpty);
    },
  );

  test('Gemini function call finishes the turn with toolUse', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'data: {"candidates":[{"content":{"parts":['
        '{"functionCall":{"name":"read","args":{"path":"a.txt"}}}'
        ']},"finishReason":"STOP"}]}\n\n',
      );
    addTearDown(dio.close);

    final events = await const GeminiGenerateContentAdapter()
        .completeAgent(
          dio: dio,
          request: _request(ProviderProtocol.geminiGenerateContent),
          cancelToken: CancelToken(),
        )
        .toList();

    final call = events.whereType<AgentWireToolCallDone>().single;
    expect(call.name, 'read');
    expect(call.arguments, {'path': 'a.txt'});
    expect(
      events.whereType<AgentWireFinish>().single.stopReason,
      StopReason.toolUse,
    );
  });
}

AgentChatRequest _request(ProviderProtocol protocol) {
  return AgentChatRequest(
    sessionId: 'session',
    provider: ProviderConfig(
      id: 'provider',
      name: 'Provider',
      protocol: protocol,
      baseUrl: 'https://example.test',
    ),
    model: 'model',
    systemPrompt: 'system',
    messages: [UserMessage.text('hello')],
    tools: const [],
    apiKey: null,
  );
}

class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
