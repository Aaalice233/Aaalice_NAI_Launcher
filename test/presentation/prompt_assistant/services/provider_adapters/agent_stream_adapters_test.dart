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

  test('Mistral typed content emits thinking and visible text', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'data: {"choices":[{"delta":{"content":['
        '{"type":"thinking","thinking":[{"type":"text","text":"reason"}]},'
        '{"type":"text","text":"answer"}'
        ']},"finish_reason":"stop"}]}\n\n'
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

    expect(events.whereType<AgentWireThinkingDelta>().single.delta, 'reason');
    expect(events.whereType<AgentWireTextDelta>().single.delta, 'answer');
    expect(events.whereType<AgentWireFinish>(), hasLength(1));
  });

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

  test('DeepSeek replays reasoning content before tool results', () async {
    final capture = _CaptureAdapter();
    final dio = Dio()..httpClientAdapter = capture;
    addTearDown(dio.close);

    await const OpenAiChatCompletionsAdapter()
        .completeAgent(
          dio: dio,
          request: AgentChatRequest(
            sessionId: 'session',
            provider: const ProviderConfig(
              id: 'deepseek',
              name: 'DeepSeek',
              protocol: ProviderProtocol.openaiChatCompletions,
              preset: ProviderPreset.deepseek,
              baseUrl: 'https://example.test',
            ),
            model: 'deepseek-v4-pro',
            systemPrompt: 'system',
            messages: [
              UserMessage.text('show recent images'),
              AssistantMessage(
                content: const [
                  AssistantThinkingContent('I should inspect the gallery.'),
                  ToolCallContent(
                    id: 'call-1',
                    name: 'list_recent_images',
                    arguments: {},
                  ),
                ],
                stopReason: StopReason.toolUse,
              ),
              ToolResultMessage(
                toolCallId: 'call-1',
                toolName: 'list_recent_images',
                content: const [ToolResultTextContent('image.png')],
                isError: false,
              ),
            ],
            tools: const [],
            apiKey: null,
            reasoning: 'high',
          ),
          cancelToken: CancelToken(),
        )
        .toList();

    final messages =
        (capture.options!.data as Map<String, dynamic>)['messages'] as List;
    final assistant = messages.cast<Map>().firstWhere(
      (message) => message['role'] == 'assistant',
    );
    expect(assistant['reasoning_content'], 'I should inspect the gallery.');
    expect((messages.last as Map)['tool_call_id'], 'call-1');
    final payload = capture.options!.data as Map<String, dynamic>;
    expect(payload['model'], 'deepseek-v4-pro');
    expect(payload['thinking'], {'type': 'enabled'});
  });

  test('DeepSeek Agent uses the official chat completions endpoint', () async {
    final capture = _CaptureAdapter();
    final dio = Dio()..httpClientAdapter = capture;
    addTearDown(dio.close);
    final base = _request(ProviderProtocol.openaiChatCompletions);

    await const OpenAiChatCompletionsAdapter()
        .completeAgent(
          dio: dio,
          request: AgentChatRequest(
            sessionId: base.sessionId,
            provider: const ProviderConfig(
              id: 'deepseek',
              name: 'DeepSeek',
              protocol: ProviderProtocol.openaiChatCompletions,
              preset: ProviderPreset.deepseek,
              baseUrl: 'https://api.deepseek.com',
            ),
            model: 'deepseek-v4-flash',
            systemPrompt: base.systemPrompt,
            messages: base.messages,
            tools: base.tools,
            apiKey: null,
          ),
          cancelToken: CancelToken(),
        )
        .toList();

    expect(
      capture.options!.uri.toString(),
      'https://api.deepseek.com/chat/completions',
    );
    final payload = capture.options!.data as Map<String, dynamic>;
    expect(payload['model'], 'deepseek-v4-flash');
    expect(payload['thinking'], {'type': 'disabled'});
  });

  test(
    'DeepSeek tool replay keeps tool pairing without image_url payloads',
    () async {
      final capture = _CaptureAdapter();
      final dio = Dio()..httpClientAdapter = capture;
      addTearDown(dio.close);

      await const OpenAiChatCompletionsAdapter()
          .completeAgent(
            dio: dio,
            request: AgentChatRequest(
              sessionId: 'session',
              provider: ProviderPreset.deepseek.createConfig(id: 'deepseek'),
              model: 'deepseek-v4-flash',
              systemPrompt: 'system',
              messages: [
                UserMessage(
                  content: [
                    const UserTextContent('show recent images'),
                    const UserImageContent(
                      ImageContent(
                        source: ImageSource.base64(
                          mimeType: 'image/png',
                          base64Data: 'AA==',
                        ),
                      ),
                    ),
                  ],
                ),
                AssistantMessage(
                  content: const [
                    ToolCallContent(
                      id: 'recent-1',
                      name: 'get_recent_images',
                      arguments: {'limit': 1},
                    ),
                  ],
                  stopReason: StopReason.toolUse,
                ),
                ToolResultMessage(
                  toolCallId: 'recent-1',
                  toolName: 'get_recent_images',
                  content: [
                    const ToolResultTextContent(
                      '{"files":["recent.png"],"count":1}',
                    ),
                    const ToolResultImageContent(
                      ImageContent(
                        source: ImageSource.base64(
                          mimeType: 'image/png',
                          base64Data: 'AA==',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              tools: const [],
              apiKey: null,
            ),
            cancelToken: CancelToken(),
          )
          .toList();

      final payload = capture.options!.data as Map<String, dynamic>;
      final messages = (payload['messages'] as List).cast<Map>();
      expect(payload.toString(), isNot(contains('image_url')));
      expect(
        messages.where((message) => message['role'] == 'user'),
        hasLength(1),
      );
      expect(
        messages.firstWhere((message) => message['role'] == 'user')['content'],
        'show recent images',
      );
      final tool = messages.firstWhere((message) => message['role'] == 'tool');
      expect(tool['tool_call_id'], 'recent-1');
      expect(tool['content'], contains('recent.png'));
    },
  );

  test('image-capable OpenAI replay keeps image_url content', () async {
    final capture = _CaptureAdapter();
    final dio = Dio()..httpClientAdapter = capture;
    addTearDown(dio.close);

    await const OpenAiChatCompletionsAdapter()
        .completeAgent(
          dio: dio,
          request: AgentChatRequest(
            sessionId: 'session',
            provider: ProviderPreset.openaiChat.createConfig(id: 'openai'),
            model: 'gpt-4.1-mini',
            systemPrompt: 'system',
            messages: [
              UserMessage(
                content: const [
                  UserTextContent('inspect this'),
                  UserImageContent(
                    ImageContent(
                      source: ImageSource.base64(
                        mimeType: 'image/png',
                        base64Data: 'AA==',
                      ),
                    ),
                  ),
                ],
              ),
              AssistantMessage(
                content: const [
                  ToolCallContent(
                    id: 'preview-1',
                    name: 'preview_generated_image',
                    arguments: {},
                  ),
                ],
                stopReason: StopReason.toolUse,
              ),
              ToolResultMessage(
                toolCallId: 'preview-1',
                toolName: 'preview_generated_image',
                content: const [
                  ToolResultTextContent('preview ready'),
                  ToolResultImageContent(
                    ImageContent(
                      source: ImageSource.base64(
                        mimeType: 'image/png',
                        base64Data: 'AA==',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            tools: const [],
            apiKey: null,
          ),
          cancelToken: CancelToken(),
        )
        .toList();

    final payload = capture.options!.data as Map<String, dynamic>;
    final messages = (payload['messages'] as List).cast<Map>();
    final imageMessages = messages
        .where((message) => message['role'] == 'user')
        .where(
          (message) => (message['content'] as List).cast<Map>().any(
            (part) => part['type'] == 'image_url',
          ),
        );
    expect(imageMessages, hasLength(2));
    expect(messages.firstWhere((message) => message['role'] == 'tool'), {
      'role': 'tool',
      'tool_call_id': 'preview-1',
      'content': 'preview ready',
    });
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

  test('OpenAI Responses persists encrypted reasoning and replays it', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'event: response.output_item.added\n'
        'data: {"output_index":0,"item":{"type":"reasoning","id":"rs_1"}}\n\n'
        'event: response.reasoning_summary_text.delta\n'
        'data: {"output_index":0,"delta":"summary"}\n\n'
        'event: response.output_item.done\n'
        'data: {"output_index":0,"item":{"type":"reasoning","id":"rs_1","summary":[{"type":"summary_text","text":"summary"}]}}\n\n'
        'event: response.completed\n'
        'data: {"response":{"output":[{"type":"reasoning","id":"rs_1","encrypted_content":"secret"}],"usage":{"input_tokens":1,"output_tokens":2,"total_tokens":3}}}\n\n',
      );
    addTearDown(dio.close);

    final events = await const OpenAiResponsesAdapter()
        .completeAgent(
          dio: dio,
          request: _request(ProviderProtocol.openaiResponses),
          cancelToken: CancelToken(),
        )
        .toList();
    final signature = events
        .whereType<AgentWireThinkingSignature>()
        .last
        .signature;
    expect(signature, contains('"encrypted_content":"secret"'));

    final capture = _CaptureAdapter();
    final replayDio = Dio()..httpClientAdapter = capture;
    addTearDown(replayDio.close);
    final base = _request(ProviderProtocol.openaiResponses);
    await const OpenAiResponsesAdapter()
        .completeAgent(
          dio: replayDio,
          request: AgentChatRequest(
            sessionId: base.sessionId,
            provider: base.provider,
            model: base.model,
            systemPrompt: base.systemPrompt,
            messages: [
              AssistantMessage(
                content: [
                  AssistantThinkingContent('summary', signature: signature),
                ],
                stopReason: StopReason.stop,
                provider: base.provider.id,
                model: base.model,
              ),
            ],
            tools: const [],
            apiKey: null,
          ),
          cancelToken: CancelToken(),
        )
        .toList();

    final input =
        (capture.options!.data as Map<String, dynamic>)['input'] as List;
    expect(
      input.cast<Map<String, dynamic>>().singleWhere(
        (item) => item['type'] == 'reasoning',
      )['encrypted_content'],
      'secret',
    );
  });

  test(
    'OpenAI Responses keeps item_id on interleaved reasoning deltas',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _SseAdapter(
          'event: response.reasoning_summary_text.delta\n'
          'data: {"item_id":"reason-1","delta":"first"}\n\n'
          'event: response.reasoning_summary_text.delta\n'
          'data: {"item_id":"reason-2","delta":"second"}\n\n'
          'event: response.completed\n'
          'data: {"response":{"usage":{}}}\n\n',
        );
      addTearDown(dio.close);

      final events = await const OpenAiResponsesAdapter()
          .completeAgent(
            dio: dio,
            request: _request(ProviderProtocol.openaiResponses),
            cancelToken: CancelToken(),
          )
          .toList();

      expect(
        events.whereType<AgentWireThinkingDelta>().map((event) => event.itemId),
        ['reason-1', 'reason-2'],
      );
    },
  );

  test('Gemini persists and replays signatures on text and tool parts', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'data: {"candidates":[{"content":{"parts":['
        '{"text":"answer","thoughtSignature":"text-sig"},'
        '{"functionCall":{"name":"tool","args":{"x":1}},"thoughtSignature":"tool-sig"}'
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
    expect(
      events.whereType<AgentWireTextSignature>().single.signature,
      'text-sig',
    );
    expect(
      events.whereType<AgentWireToolCallDone>().single.thoughtSignature,
      'tool-sig',
    );

    final capture = _CaptureAdapter();
    final replayDio = Dio()..httpClientAdapter = capture;
    addTearDown(replayDio.close);
    final base = _request(ProviderProtocol.geminiGenerateContent);
    await const GeminiGenerateContentAdapter()
        .completeAgent(
          dio: replayDio,
          request: AgentChatRequest(
            sessionId: base.sessionId,
            provider: base.provider,
            model: base.model,
            systemPrompt: base.systemPrompt,
            messages: [
              AssistantMessage(
                content: const [
                  AssistantTextContent('answer', signature: 'text-sig'),
                  AssistantThinkingContent('thought', signature: 'think-sig'),
                  ToolCallContent(
                    id: 'call-1',
                    name: 'tool',
                    arguments: {'x': 1},
                    thoughtSignature: 'tool-sig',
                  ),
                ],
                stopReason: StopReason.toolUse,
                provider: base.provider.id,
                model: base.model,
              ),
            ],
            tools: const [],
            apiKey: null,
          ),
          cancelToken: CancelToken(),
        )
        .toList();

    final contents =
        (capture.options!.data as Map<String, dynamic>)['contents'] as List;
    final parts = ((contents.single as Map)['parts'] as List).cast<Map>();
    expect(parts[0]['thoughtSignature'], 'text-sig');
    expect(parts[1]['thoughtSignature'], 'think-sig');
    expect(parts[2]['thoughtSignature'], 'tool-sig');
  });

  test('Gemini preserves a signature-only part', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter(
        'data: {"candidates":[{"content":{"parts":['
        '{"thoughtSignature":"proof-only"}'
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

    expect(
      events.whereType<AgentWireTextSignature>().single.signature,
      'proof-only',
    );
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
