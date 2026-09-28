import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/agent_wire_helpers.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_responses_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/reasoning_payload.dart';

const _provider = ProviderConfig(
  id: 'gateway',
  name: 'Gateway',
  baseUrl: 'https://example.invalid/v1',
  protocol: ProviderProtocol.openaiResponses,
);

void main() {
  for (final model in ['deepseek-v4-flash', 'glm-5']) {
    test('$model keeps catalog levels across protocol switches', () {
      final responses = AssistantModelCatalog.resolveProvider(
        provider: _provider,
        model: model,
      );
      final chat = AssistantModelCatalog.resolveProvider(
        provider: const ProviderConfig(
          id: 'gateway',
          name: 'Gateway',
          baseUrl: 'https://example.invalid/v1',
          protocol: ProviderProtocol.openaiChatCompletions,
        ),
        model: model,
      );
      expect(responses.thinkingLevels, chat.thinkingLevels);
      expect(responses.thinkingLevels, contains(ThinkingLevel.off));
      expect(
        responsesReasoningEffort(responses.resolveReasoningRequest(null), null),
        'none',
      );
      expect(
        responsesReasoningEffort(
          responses.resolveReasoningRequest('high'),
          null,
        ),
        'high',
      );
      expect(
        chatReasoningPayload(chat.resolveReasoningRequest(null)),
        isNotEmpty,
      );
    });
  }

  test('reasoner without off does not acquire an off option', () {
    final metadata = AssistantModelCatalog.resolveProvider(
      provider: const ProviderConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        preset: ProviderPreset.deepseek,
        baseUrl: 'https://example.invalid',
        protocol: ProviderProtocol.openaiResponses,
      ),
      model: 'deepseek-reasoner',
    );
    expect(
      metadata.selectableThinkingLevels,
      isNot(contains(ThinkingLevel.off)),
    );
    expect(
      responsesReasoningEffort(metadata.resolveReasoningRequest(null), null),
      isNull,
    );
  });

  test(
    'parallel multimodal outputs stay attached to calls after a failed turn',
    () async {
      final transport = _Transport(
        (options, attempt) async => ResponseBody.fromString(
          'event: response.completed\ndata: {"response":{}}\n\n',
          200,
        ),
      );
      final dio = Dio()..httpClientAdapter = transport;
      addTearDown(dio.close);
      final messages = <AgentMessage>[
        UserMessage.text('generate two previews'),
        AssistantMessage(
          content: const [
            ToolCallContent(id: 'first', name: 'preview', arguments: {}),
            ToolCallContent(id: 'second', name: 'preview', arguments: {}),
          ],
          stopReason: StopReason.toolUse,
        ),
        for (final id in ['first', 'second'])
          ToolResultMessage(
            toolCallId: id,
            toolName: 'preview',
            content: [
              ToolResultTextContent(id),
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
        AssistantMessage(content: const [], stopReason: StopReason.error),
        UserMessage.text('continue'),
      ];
      final metadata = AssistantModelCatalog.resolveProvider(
        provider: _provider,
        model: 'deepseek-v4-flash',
      );
      final events = await const OpenAiResponsesAdapter()
          .completeAgent(
            dio: dio,
            request: AgentChatRequest(
              sessionId: 'test',
              provider: _provider,
              model: 'deepseek-v4-flash',
              systemPrompt: '',
              messages: harnessConvertToLlm(messages),
              tools: const [],
              apiKey: null,
              reasoningRequest: metadata.resolveReasoningRequest(null),
            ),
            cancelToken: CancelToken(),
          )
          .toList();
      expect(events.whereType<AgentWireError>(), isEmpty);
      expect(events.whereType<AgentWireFinish>(), hasLength(1));
      final payload = transport.payload!;
      expect((payload['reasoning'] as Map)['effort'], 'none');
      final input = (payload['input'] as List).cast<Map>();
      expect(input.map((item) => item['type']), [
        'message',
        'function_call',
        'function_call',
        'function_call_output',
        'function_call_output',
        'message',
      ]);
      for (var i = 0; i < 2; i++) {
        expect(input[3 + i]['call_id'], input[1 + i]['call_id']);
        expect(input[3 + i]['output'], [
          {'type': 'input_text', 'text': i == 0 ? 'first' : 'second'},
          {
            'type': 'input_image',
            'image_url': 'data:image/png;base64,AA==',
            'detail': 'auto',
          },
        ]);
      }
    },
  );

  test('handshake termination retries then succeeds', () async {
    final transport = _Transport((options, attempt) async {
      if (attempt < 3) {
        throw const HandshakeException(
          'Connection terminated during handshake',
        );
      }
      return ResponseBody.fromString('ok', 200);
    });
    expect(await _read(transport), isNotEmpty);
    expect(transport.attempts, 3);
  });

  test('persistent connection failure stops after three attempts', () async {
    final transport = _Transport((options, attempt) async {
      throw const SocketException('reset');
    });
    await expectLater(_read(transport), throwsA(isA<DioException>()));
    expect(transport.attempts, 3);
  });

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$type retries before output', () async {
      final transport = _Transport((options, attempt) async {
        if (attempt == 1) {
          throw DioException(requestOptions: options, type: type);
        }
        return ResponseBody.fromString('ok', 200);
      });
      expect(await _read(transport), isNotEmpty);
      expect(transport.attempts, 2);
    });
  }

  test('stream failure before the first byte retries', () async {
    final transport = _Transport((options, attempt) async {
      if (attempt == 1) {
        return ResponseBody(
          Stream<Uint8List>.error(const SocketException('reset')),
          200,
        );
      }
      return ResponseBody.fromString('ok', 200);
    });
    expect(await _read(transport), isNotEmpty);
    expect(transport.attempts, 2);
  });

  test('an unknown programming error is not a network retry', () async {
    final transport = _Transport((options, attempt) async {
      throw StateError('invalid local state');
    });
    await expectLater(_read(transport), throwsA(isA<DioException>()));
    expect(transport.attempts, 1);
  });

  test('already cancelled request never reaches transport', () async {
    final transport = _Transport(
      (options, attempt) async => ResponseBody.fromString('ok', 200),
    );
    final cancel = CancelToken()..cancel();
    await expectLater(
      _read(transport, cancel: cancel),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(transport.attempts, 0);
  });

  test('HTTP 400 retains detail and is never retried', () async {
    final transport = _Transport(
      (options, attempt) async => ResponseBody.fromString(
        '{"error":{"message":"No tool output found for tool call second"}}',
        400,
      ),
    );
    await expectLater(
      _read(transport),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.data.toString(),
          'body',
          contains('tool call second'),
        ),
      ),
    );
    expect(transport.attempts, 1);
  });

  test('certificate rejection is never retried', () async {
    final transport = _Transport((options, attempt) async {
      throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
    });
    await expectLater(_read(transport), throwsA(isA<DioException>()));
    expect(transport.attempts, 1);
  });

  test(
    'network failure after even partial SSE bytes is not replayed',
    () async {
      final transport = _Transport(
        (options, attempt) async => ResponseBody(() async* {
          yield Uint8List.fromList([100]);
          throw const SocketException('reset');
        }(), 200),
      );
      await expectLater(_read(transport), throwsA(anything));
      expect(transport.attempts, 1);
    },
  );

  test('cancel during backoff prevents the next attempt', () async {
    final cancel = CancelToken();
    final failed = Completer<void>();
    final transport = _Transport((options, attempt) async {
      failed.complete();
      throw const SocketException('reset');
    });
    final result = _read(transport, cancel: cancel);
    final assertion = expectLater(
      result,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    await failed.future;
    await Future<void>.delayed(Duration.zero);
    cancel.cancel();
    await assertion;
    expect(transport.attempts, 1);
  });
}

Future<List<Uint8List>> _read(
  _Transport transport, {
  CancelToken? cancel,
}) async {
  final dio = Dio()..httpClientAdapter = transport;
  try {
    return await agentStreamPost(
      dio,
      endpoint: 'https://example.invalid',
      payload: const {},
      headers: const {},
      cancelToken: cancel ?? CancelToken(),
    ).toList();
  } finally {
    dio.close();
  }
}

class _Transport implements HttpClientAdapter {
  _Transport(this.respond);
  final Future<ResponseBody> Function(RequestOptions, int) respond;
  int attempts = 0;
  Map<String, dynamic>? payload;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.data is Map<String, dynamic>) {
      payload = options.data as Map<String, dynamic>;
    }
    return respond(options, ++attempts);
  }

  @override
  void close({bool force = false}) {}
}
