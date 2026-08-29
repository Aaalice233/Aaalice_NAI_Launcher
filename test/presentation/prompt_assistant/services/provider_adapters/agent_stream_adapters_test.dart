import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/anthropic_messages_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/gemini_generate_content_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_chat_completions_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_responses_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

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

  test('OpenAI chat rejects a truncated stream', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
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
  });

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

  test('OpenAI Responses sends the selected reasoning effort', () async {
    final adapter = _SseAdapter(
      'data: {"type":"response.completed","response":{"usage":{}}}\n\n',
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await const OpenAiResponsesAdapter()
        .completeAgent(
          dio: dio,
          request: _request(
            ProviderProtocol.openaiResponses,
            reasoning: 'medium',
          ),
          cancelToken: CancelToken(),
        )
        .toList();

    expect((adapter.requestData as Map)['reasoning'], {
      'effort': 'medium',
      'summary': 'auto',
    });
  });

  test('OpenAI Responses rejects a truncated stream', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'data: {"type":"response.output_text.delta","delta":"partial"}\n\n',
      );
    addTearDown(dio.close);

    final events = await const OpenAiResponsesAdapter()
        .completeAgent(
          dio: dio,
          request: _request(ProviderProtocol.openaiResponses),
          cancelToken: CancelToken(),
        )
        .toList();

    expect(events.whereType<AgentWireError>(), hasLength(1));
    expect(events.whereType<AgentWireFinish>(), isEmpty);
  });

  test(
    'OpenAI Responses preserves text and function-call item order',
    () async {
      final adapter = _SseAdapter(
        'data: {"type":"response.completed","response":{"usage":{}}}\n\n',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final base = _request(ProviderProtocol.openaiResponses);

      await const OpenAiResponsesAdapter()
          .completeAgent(
            dio: dio,
            request: AgentChatRequest(
              sessionId: base.sessionId,
              provider: base.provider,
              model: base.model,
              systemPrompt: base.systemPrompt,
              messages: [
                AssistantMessage(
                  content: const [
                    AssistantTextContent('before'),
                    ToolCallContent(id: 'call-1', name: 'read', arguments: {}),
                    AssistantTextContent('after'),
                  ],
                  stopReason: StopReason.toolUse,
                ),
              ],
              tools: const [],
              apiKey: null,
            ),
            cancelToken: CancelToken(),
          )
          .toList();

      final input = (adapter.requestData as Map)['input'] as List;
      expect(input.map((item) => (item as Map)['type']), [
        'message',
        'function_call',
        'message',
      ]);
    },
  );

  test('Anthropic stream preserves its thinking signature', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'event: content_block_delta\n'
        'data: {"index":0,"delta":{"type":"thinking_delta","thinking":"reason"}}\n\n'
        'event: content_block_delta\n'
        'data: {"index":0,"delta":{"type":"signature_delta","signature":"signed-reason"}}\n\n'
        'event: message_delta\n'
        'data: {"delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":1}}\n\n'
        'event: message_stop\n'
        'data: {}\n\n',
      );
    addTearDown(dio.close);

    final events = await const AnthropicMessagesAdapter()
        .completeAgent(
          dio: dio,
          request: _request(ProviderProtocol.anthropicMessages),
          cancelToken: CancelToken(),
        )
        .toList();

    expect(events.whereType<AgentWireThinkingDelta>().single.delta, 'reason');
    expect(
      events.whereType<AgentWireThinkingSignature>().single.signature,
      'signed-reason',
    );
    expect(events.whereType<AgentWireFinish>(), hasLength(1));
  });

  test('Anthropic rejects a stream without message_stop', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'event: content_block_delta\n'
        'data: {"index":0,"delta":{"type":"text_delta","text":"partial"}}\n\n'
        'event: message_delta\n'
        'data: {"delta":{"stop_reason":"end_turn"}}\n\n',
      );
    addTearDown(dio.close);

    final events = await const AnthropicMessagesAdapter()
        .completeAgent(
          dio: dio,
          request: _request(ProviderProtocol.anthropicMessages),
          cancelToken: CancelToken(),
        )
        .toList();

    expect(events.whereType<AgentWireError>(), hasLength(1));
    expect(events.whereType<AgentWireFinish>(), isEmpty);
  });

  test('every Agent protocol sends the exact final system prompt', () async {
    final cases = <(ProviderProtocol, PromptAssistantProviderAdapter)>[
      (
        ProviderProtocol.openaiChatCompletions,
        const OpenAiChatCompletionsAdapter(),
      ),
      (ProviderProtocol.openaiResponses, const OpenAiResponsesAdapter()),
      (ProviderProtocol.anthropicMessages, const AnthropicMessagesAdapter()),
      (
        ProviderProtocol.geminiGenerateContent,
        const GeminiGenerateContentAdapter(),
      ),
      (
        ProviderProtocol.ollamaChatCompletions,
        const OpenAiChatCompletionsAdapter(ollamaTagsFallback: true),
      ),
    ];

    for (final (protocol, adapter) in cases) {
      final capture = _CaptureAdapter();
      final dio = Dio()..httpClientAdapter = capture;
      addTearDown(dio.close);

      await adapter
          .completeAgent(
            dio: dio,
            request: _request(
              protocol,
              systemPrompt: 'EXACT_OVERRIDE',
              includeTool: true,
            ),
            cancelToken: CancelToken(),
          )
          .toList();

      final payload = capture.options!.data as Map<String, dynamic>;
      final outboundPrompt = switch (protocol) {
        ProviderProtocol.openaiChatCompletions ||
        ProviderProtocol.ollamaChatCompletions =>
          ((payload['messages'] as List).first as Map)['content'],
        ProviderProtocol.openaiResponses => payload['instructions'],
        ProviderProtocol.anthropicMessages => payload['system'],
        ProviderProtocol.geminiGenerateContent =>
          ((((payload['system_instruction'] as Map)['parts'] as List).single
              as Map)['text']),
      };
      expect(outboundPrompt, 'EXACT_OVERRIDE', reason: protocol.name);
      expect(payload.toString(), isNot(contains('BUILT_IN')));
      expect(payload.toString(), contains('exact_tool'), reason: protocol.name);
    }
  });
}

AgentChatRequest _request(
  ProviderProtocol protocol, {
  String? reasoning,
  String systemPrompt = 'system',
  bool includeTool = false,
}) {
  return AgentChatRequest(
    sessionId: 'session',
    provider: ProviderConfig(
      id: 'provider',
      name: 'Provider',
      protocol: protocol,
      baseUrl: 'https://example.test',
    ),
    model: 'model',
    systemPrompt: systemPrompt,
    messages: [UserMessage.text('hello')],
    tools: includeTool
        ? const [
            Tool(
              name: 'exact_tool',
              description: 'Structured tool definition',
              parameters: {'type': 'object', 'properties': <String, dynamic>{}},
            ),
          ]
        : const [],
    apiKey: null,
    reasoning: reasoning,
  );
}

class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.body);

  final String body;
  Object? requestData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestData = options.data;
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

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      '',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
