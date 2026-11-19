import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_api_client.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_stream_bridge.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_chat_completions_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

const _id = 'gemini-carbon';

class _Server implements HttpClientAdapter {
  final bodies = <Map<String, dynamic>>[];
  final paths = <String>[];
  ResponseBody? Function()? reply;
  int status = 200;
  Map<String, dynamic> error = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(options.data as Map<String, dynamic>);
    paths.add(options.uri.path);
    if (reply?.call() case final response?) return response;
    final stream = options.responseType == ResponseType.stream && status == 200;
    final body = bodies.last;
    final finished = body.containsKey('contents')
        ? 'data: {"candidates":[{"finishReason":"STOP"}]}\n\n'
        : body.containsKey('input')
        ? 'event: response.completed\ndata: {"response":{}}\n\n'
        : body.containsKey('system')
        ? 'event: message_stop\ndata: {}\n\n'
        : 'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n';
    return ResponseBody.fromString(
      stream
          ? finished
          : jsonEncode(
              status != 200
                  ? error
                  : {
                      'choices': [
                        {
                          'message': {'content': 'ok'},
                        },
                      ],
                      'output_text': 'ok',
                      'content': [
                        {'type': 'text', 'text': 'ok'},
                      ],
                      'candidates': [
                        {
                          'content': {
                            'parts': [
                              {'text': 'ok'},
                            ],
                          },
                        },
                      ],
                    },
            ),
      status,
      headers: {
        Headers.contentTypeHeader: [
          stream ? 'text/event-stream' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<String?> _complete(
  Dio dio,
  ProviderConfig provider,
  String? level, {
  required bool agent,
  String model = _id,
}) async {
  final metadata = AssistantModelCatalog.resolveProvider(
    provider: provider,
    model: model,
  );
  final resolved = level == null
      ? null
      : metadata.resolveReasoningRequest(level == 'off' ? null : level);
  if (agent) {
    final events =
        await AgentApiClient(dio, reasoningRejectionHint: () => '切回模型默认重试')
            .complete(
              AgentChatRequest(
                sessionId: 'chat',
                provider: provider,
                model: model,
                systemPrompt: 'system',
                messages: [UserMessage.text('hello')],
                tools: const [],
                apiKey: null,
                reasoning: resolved?.enabled == true ? level : null,
                reasoningRequest: resolved,
              ),
            )
            .toList();
    return events.whereType<AgentWireError>().firstOrNull?.message;
  }
  try {
    await PromptAssistantApiClient(
          dio: dio,
          reasoningRejectionHint: () => '切回模型默认重试',
        )
        .complete(
          request: PromptAssistantRequest(
            sessionId: 'task',
            provider: provider,
            model: model,
            systemPrompt: 'system',
            userParts: [PromptAssistantContentPart.text('hello')],
            apiKey: null,
            reasoningRequest: resolved,
          ),
        )
        .toList();
    return null;
  } on StateError catch (error) {
    return error.message;
  }
}

Map<String, dynamic> _reasoningFields(Map<String, dynamic> body) => {
  for (final key in [
    'reasoning_effort',
    'reasoning',
    'include',
    'thinking',
    'output_config',
    'enable_thinking',
  ])
    if (body.containsKey(key)) key: body[key],
  if (body['generationConfig'] case {'thinkingConfig': final config})
    'thinkingConfig': config,
};

ResponseBody _reply(
  String body, {
  bool stream = false,
  int status = 200,
  String? contentType,
}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [
      contentType ?? (stream ? 'text/event-stream' : 'application/json'),
    ],
  },
);

PromptAssistantRequest _structuredChatRequest(
  ProviderConfig provider,
  String model,
) {
  final metadata = AssistantModelCatalog.resolveProvider(
    provider: provider,
    model: model,
  );
  return PromptAssistantRequest(
    sessionId: 'task',
    provider: provider,
    model: model,
    systemPrompt: 'system',
    userParts: [PromptAssistantContentPart.text('hello')],
    apiKey: null,
    responseFormat: PromptAssistantResponseFormat.jsonObject,
    maxOutputTokens: 100,
    reasoningRequest: metadata.resolveReasoningRequest('high'),
  );
}

void main() {
  late Dio dio;
  late _Server server;
  setUp(() {
    server = _Server();
    dio = Dio()..httpClientAdapter = server;
  });
  tearDown(() => dio.close(force: true));

  test(
    'DeepSeek retries only an endpoint rejection with identical explicit fields',
    () async {
      final relay = ProviderPreset.deepseek.createConfig().copyWith(
        baseUrl: 'https://relay.example/v1',
      );
      server.reply = () => server.paths.length == 1
          ? _reply(
              '{"error":{"message":"Invalid request URL /v1/chat/completions"}}',
              status: 400,
            )
          : null;
      expect(
        await const OpenAiChatCompletionsAdapter().complete(
          dio: dio,
          request: _structuredChatRequest(relay, 'deepseek-v4-pro'),
          cancelToken: CancelToken(),
        ),
        'ok',
      );
      expect(server.paths, ['/v1/chat/completions', '/chat/completions']);
      expect(server.bodies[1], server.bodies[0]);
      expect(server.bodies.last['reasoning_effort'], 'high');

      const rejection = 'Unsupported at this endpoint';
      server.reply = () => _reply(
        jsonEncode({
          'error': {'param': 'reasoning_effort', 'message': rejection},
        }),
        status: 400,
      );
      final message = await _complete(
        dio,
        relay,
        'high',
        agent: false,
        model: 'deepseek-v4-pro',
      );
      expect(server.paths, [
        '/v1/chat/completions',
        '/chat/completions',
        '/v1/chat/completions',
      ]);
      expect(message, contains(rejection));
    },
  );

  test(
    'explicit Chat Completions effort survives the response_format fallback',
    () async {
      final relay = ProviderPreset.openaiCompatibleChat.createConfig();
      server.reply = () => server.bodies.last.containsKey('response_format')
          ? _reply(
              '{"error":{"param":"response_format","message":"Unsupported response_format"}}',
              status: 400,
            )
          : null;
      expect(
        await const OpenAiChatCompletionsAdapter().complete(
          dio: dio,
          request: _structuredChatRequest(relay, 'gpt-5.2'),
          cancelToken: CancelToken(),
        ),
        'ok',
      );
      expect(server.paths, ['/v1/chat/completions', '/v1/chat/completions']);
      expect(server.bodies.first['response_format'], {'type': 'json_object'});
      expect(server.bodies.first['max_completion_tokens'], 100);
      expect(server.bodies.last, {
        'model': 'gpt-5.2',
        'stream': false,
        'messages': server.bodies.first['messages'],
        'reasoning_effort': 'high',
      });
    },
  );

  test(
    'Chat Completions reports the error from the compatibility request',
    () async {
      final relay = ProviderPreset.deepseek.createConfig().copyWith(
        baseUrl: 'https://relay.example/v1',
      );
      server.reply = () => server.bodies.length == 1
          ? _reply('{"error":{"message":"Invalid request"}}', status: 400)
          : _reply(
              '{"error":{"message":"Second request was rejected"}}',
              status: 422,
            );
      final error = await _complete(
        dio,
        relay,
        'high',
        agent: false,
        model: 'deepseek-v4-pro',
      );
      expect(error, contains('HTTP 422'));
      expect(error, contains('Second request was rejected'));
      expect(server.paths, ['/v1/chat/completions', '/v1/chat/completions']);
    },
  );

  for (final (name, body, contentType) in [
    ('empty 404', '', 'text/plain'),
    (
      'HTML 404',
      '<!DOCTYPE html><html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1></body></html>',
      'text/html',
    ),
  ]) {
    test(
      'DeepSeek retries $name on the other endpoint with the same body',
      () async {
        final relay = ProviderPreset.deepseek.createConfig().copyWith(
          baseUrl: 'https://relay.example/v1',
        );
        server.reply = () => server.paths.length == 1
            ? _reply(body, status: 404, contentType: contentType)
            : null;
        expect(
          await const OpenAiChatCompletionsAdapter().complete(
            dio: dio,
            request: _structuredChatRequest(relay, 'deepseek-v4-pro'),
            cancelToken: CancelToken(),
          ),
          'ok',
        );
        expect(server.paths, ['/v1/chat/completions', '/chat/completions']);
        expect(server.bodies[1], server.bodies[0]);
        expect(server.bodies.last['reasoning_effort'], 'high');
      },
    );
  }

  test('DeepSeek does not switch endpoints for model or field errors', () async {
    final relay = ProviderPreset.deepseek.createConfig().copyWith(
      baseUrl: 'https://relay.example/v1',
    );
    for (final error in [
      {
        'code': 'model_not_found',
        'message': 'Model deepseek-v4-pro does not exist',
      },
      {
        'param': 'reasoning_effort',
        'message': 'Unsupported parameter reasoning_effort',
      },
    ]) {
      server.reply = () => _reply(jsonEncode({'error': error}), status: 404);
      final before = server.bodies.length;
      final message = await _complete(
        dio,
        relay,
        'high',
        agent: false,
        model: 'deepseek-v4-pro',
      );
      expect(server.bodies.length, before + 1);
      expect(server.paths.last, '/v1/chat/completions');
      expect(message, contains(error['message']));
    }
    final before = server.bodies.length;
    server.reply = () => _reply(
      '<html><head><title>404 Not Found</title></head><body>Model deepseek-v4-pro not found</body></html>',
      status: 404,
      contentType: 'text/html',
    );
    expect(
      await _complete(
        dio,
        relay,
        'high',
        agent: false,
        model: 'deepseek-v4-pro',
      ),
      contains('Model deepseek-v4-pro not found'),
    );
    expect(server.bodies.length, before + 1);
  });

  test(
    'Responses failure uses the top-level error when the inner error is empty',
    () async {
      final relay = ProviderPreset.openaiCompatibleResponses.createConfig();
      for (final (innerError, expected) in [
        (null, 'Upstream timeout'),
        (<String, String>{}, 'Upstream timeout'),
        ({'message': 'Inner failure'}, 'Inner failure'),
      ]) {
        final json = jsonEncode({
          'response': {'status': 'failed', 'error': innerError},
          'error': {'message': 'Upstream timeout'},
        });
        server.reply = () =>
            _reply('event: response.failed\ndata: $json\n\n', stream: true);
        expect(
          await _complete(dio, relay, null, agent: true),
          endsWith(': $expected'),
        );
      }
    },
  );

  for (final toolTurn in [false, true]) {
    test(
      'stateless Responses retains replayable history only, toolTurn=$toolTurn',
      () async {
        final relay = ProviderPreset.openaiCompatibleResponses
            .createConfig()
            .copyWith(
              modelReasoningFormats: {
                _id: ModelReasoningFormat.responsesEffort,
              },
            );
        final reasoning = AssistantModelCatalog.resolveProvider(
          provider: relay,
          model: _id,
        ).resolveReasoningRequest('high');
        final client = AgentApiClient(dio);
        final tools = [
          if (toolTurn)
            const Tool(name: 'lookup', description: 'Lookup', parameters: {}),
        ];
        AgentChatRequest request(List<Message> messages) => AgentChatRequest(
          sessionId: 'chat',
          provider: relay,
          model: _id,
          systemPrompt: 'system',
          messages: messages,
          tools: tools,
          apiKey: null,
          reasoning: 'high',
          reasoningRequest: reasoning,
        );
        final items = [
          {'type': 'reasoning', 'id': 'id-only'},
          {
            'type': 'reasoning',
            'id': 'summary-only',
            'summary': [
              {'type': 'summary_text', 'text': 'shown in chat'},
            ],
          },
          {
            'type': 'reasoning',
            'id': 'sealed',
            'encrypted_content': 'ciphertext',
          },
          {
            'type': 'reasoning',
            'id': 'full',
            'content': [
              {'type': 'reasoning_text', 'text': 'actual content'},
            ],
          },
        ];
        final call = {
          'type': 'function_call',
          'call_id': 'call-1',
          'name': 'lookup',
          'arguments': '{}',
        };
        String itemEvent(Map item) =>
            'event: response.output_item.done\ndata: ${jsonEncode({'item': item})}\n\n';
        server.reply = () => _reply(
          [
            ...items.map(itemEvent),
            'event: response.output_text.delta\ndata: {"delta":"hello"}\n\n',
            if (toolTurn) itemEvent(call),
            'event: response.completed\ndata: {"response":{}}\n\n',
          ].join(),
          stream: true,
        );
        final first = UserMessage.text('question');
        final assistant = await agentWireEventStream(
          client.complete(request([first])),
          provider: relay.id,
          model: _id,
        ).result();
        expect(
          assistant.stopReason,
          toolTurn ? StopReason.toolUse : StopReason.stop,
        );
        expect(
          assistant.content.whereType<AssistantThinkingContent>(),
          hasLength(4),
        );
        server.reply = null;
        final events = await client
            .complete(
              request([
                first,
                assistant,
                if (toolTurn)
                  ToolResultMessage(
                    toolCallId: 'call-1',
                    toolName: 'lookup',
                    content: const [ToolResultTextContent('found')],
                  )
                else
                  UserMessage.text('follow up'),
              ]),
            )
            .toList();
        expect(events.whereType<AgentWireError>(), isEmpty);
        expect(server.bodies, hasLength(2));
        Map userInput(String text) => {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': text},
          ],
        };
        expect(server.bodies.last, {
          'model': _id,
          'stream': true,
          'store': false,
          'instructions': 'system',
          'reasoning': {'effort': 'high'},
          if (toolTurn)
            'tools': [
              {
                'type': 'function',
                'name': 'lookup',
                'description': 'Lookup',
                'parameters': {},
              },
            ],
          'input': [
            userInput('question'),
            ...items.skip(2),
            {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': 'hello'},
              ],
            },
            if (toolTurn) ...[
              call,
              {
                'type': 'function_call_output',
                'call_id': 'call-1',
                'output': 'found',
              },
            ] else
              userInput('follow up'),
          ],
        });
      },
    );
  }

  for (final agent in [false, true]) {
    test(
      '422 validation loc and msg identify the rejected field, agent=$agent',
      () async {
        final relay = ProviderPreset.openaiCompatibleChat
            .createConfig()
            .copyWith(
              modelReasoningFormats: {_id: ModelReasoningFormat.chatEffort},
            );
        server.status = 422;
        server.error = {
          'detail': [
            {
              'loc': ['body', 'reasoning_effort'],
              'msg': "Input should be 'low' or 'medium'",
            },
          ],
        };
        final error = await _complete(dio, relay, 'high', agent: agent);
        expect(error, contains("Input should be 'low' or 'medium'"));
        expect(error, contains('reasoning_effort · 切回模型默认重试'));
        expect(server.bodies, hasLength(1));
      },
    );
    test(
      'unknown model reasoning-demo does not report a rejected field, agent=$agent',
      () async {
        const model = 'reasoning-demo';
        final relay = ProviderPreset.openaiCompatibleResponses
            .createConfig()
            .copyWith(
              modelReasoningFormats: {
                model: ModelReasoningFormat.responsesEffort,
              },
            );
        server.status = 400;
        server.error = {
          'error': {'message': "Unknown model 'reasoning-demo'"},
        };
        final error = await _complete(
          dio,
          relay,
          'high',
          model: model,
          agent: agent,
        );
        expect(error, contains("Unknown model 'reasoning-demo'"));
        expect(error, isNot(contains('切回模型默认重试')));
      },
    );
    test(
      'explicit off is diagnosed and model default omits Responses fields, agent=$agent',
      () async {
        final relay = ProviderPreset.openaiCompatibleResponses.createConfig();
        server.status = 400;
        server.error = {
          'error': {
            'param': 'reasoning.effort',
            'message': 'None is unavailable',
          },
        };
        final error = await _complete(
          dio,
          relay,
          'off',
          model: 'gpt-5.2',
          agent: agent,
        );
        expect(server.bodies.single['reasoning']['effort'], 'none');
        expect(error, contains('reasoning.effort · 切回模型默认重试'));
        expect(error, contains('None is unavailable'));
        server.status = 200;
        expect(
          await _complete(dio, relay, null, model: 'gpt-5.2', agent: agent),
          isNull,
        );
        expect(_reasoningFields(server.bodies.last), isEmpty);
      },
    );
    for (final (preset, format, field) in [
      (
        ProviderPreset.openaiCompatibleChat,
        ModelReasoningFormat.chatEffort,
        'reasoning_effort',
      ),
      (
        ProviderPreset.openaiCompatibleResponses,
        ModelReasoningFormat.responsesEffort,
        'reasoning.effort',
      ),
      (
        ProviderPreset.anthropic,
        ModelReasoningFormat.anthropicAdaptive,
        'output_config.effort',
      ),
      (
        ProviderPreset.gemini,
        ModelReasoningFormat.geminiLevel,
        'generationConfig.thinkingConfig.thinkingLevel',
      ),
    ]) {
      test(
        'HTTP 200 embedded rejection keeps route and detail for ${preset.name}, agent=$agent',
        () async {
          final relay = preset.createConfig().copyWith(
            name: 'Embedded relay',
            modelReasoningFormats: {_id: format},
          );
          final body = {
            'error': {'param': field, 'message': 'Choose a lower value'},
          };
          final event = switch (preset) {
            ProviderPreset.openaiCompatibleResponses =>
              'event: response.failed\ndata: ${jsonEncode({'response': body})}',
            ProviderPreset.anthropic =>
              'event: error\ndata: ${jsonEncode(body)}',
            _ => 'data: ${jsonEncode(body)}',
          };
          server.reply = () => agent
              ? _reply('$event\n\n', stream: true)
              : _reply(jsonEncode(body));
          final message = await _complete(dio, relay, 'high', agent: agent);
          expect(server.bodies, hasLength(1));
          for (final part in [
            'Embedded relay',
            _id,
            'Choose a lower value',
            '$field · 切回模型默认重试',
          ]) {
            expect(message, contains(part));
          }
        },
      );
    }
    for (final (preset, format, expected) in [
      (
        ProviderPreset.openaiCompatibleChat,
        ModelReasoningFormat.chatEffort,
        {'reasoning_effort': 'high'},
      ),
      (
        ProviderPreset.openaiCompatibleResponses,
        ModelReasoningFormat.responsesEffort,
        {
          'reasoning': {'effort': 'high'},
        },
      ),
      (
        ProviderPreset.gemini,
        ModelReasoningFormat.geminiLevel,
        {
          'thinkingConfig': {'includeThoughts': true, 'thinkingLevel': 'HIGH'},
        },
      ),
      (
        ProviderPreset.gemini,
        ModelReasoningFormat.geminiBudget,
        {
          'thinkingConfig': {'includeThoughts': true, 'thinkingBudget': -1},
        },
      ),
      (
        ProviderPreset.anthropic,
        ModelReasoningFormat.anthropicAdaptive,
        {
          'thinking': {'type': 'adaptive', 'display': 'summarized'},
          'output_config': {'effort': 'high'},
        },
      ),
      (
        ProviderPreset.anthropic,
        ModelReasoningFormat.anthropicBudget,
        {
          'thinking': {
            'type': 'enabled',
            'budget_tokens': 3072,
            'display': 'summarized',
          },
        },
      ),
      (
        ProviderPreset.deepseek,
        ModelReasoningFormat.chatEffort,
        {'reasoning_effort': 'high'},
      ),
    ]) {
      test(
        '${preset.name}/${format.name} explicit fields and defaults, agent=$agent',
        () async {
          final provider = preset.createConfig();
          final declared = provider.copyWith(
            modelReasoningFormats: {_id: format},
          );
          for (final (route, level) in [
            (provider, 'high'),
            (declared, null),
            (declared, 'high'),
          ]) {
            expect(await _complete(dio, route, level, agent: agent), isNull);
          }
          expect(server.bodies.map(_reasoningFields), [{}, {}, expected]);
        },
      );
    }

    for (final (status, field, reason, rejected) in [
      (400, 'reasoning_effort', 'Supported values are low and medium', true),
      (422, null, 'Unsupported reasoning_effort value high', true),
      (400, null, 'The reasoning level high is not supported', true),
      (400, 'max_tokens', 'Invalid max_tokens for this reasoning model', false),
      (401, 'reasoning_effort', 'Invalid API key', false),
      (429, 'reasoning_effort', 'Daily quota exceeded', false),
    ]) {
      test('HTTP $status: $reason, agent=$agent', () async {
        server.status = status;
        server.error = {
          'error': {'message': reason, if (field != null) 'param': field},
        };
        final provider = ProviderPreset.openaiCompatibleChat
            .createConfig()
            .copyWith(
              name: 'Test relay',
              modelReasoningFormats: const {
                _id: ModelReasoningFormat.chatEffort,
              },
            );
        final message = await _complete(dio, provider, 'high', agent: agent);
        final attempts = !agent && status == 400 && !rejected ? 2 : 1;
        expect(server.bodies, hasLength(attempts));
        expect(
          server.bodies.map((body) => body['reasoning_effort']),
          everyElement('high'),
        );
        expect(message, contains(reason));
        expect(message, contains('Test relay'));
        if (rejected) {
          expect(message, contains(_id));
          expect(message, contains('reasoning_effort'));
        }
        expect(message!.contains('切回模型默认重试'), rejected);
      });
    }
    for (final (preset, format, field, reason) in [
      (
        ProviderPreset.openaiCompatibleResponses,
        ModelReasoningFormat.responsesEffort,
        'reasoning.effort',
        'Unsupported reasoning.effort',
      ),
      (
        ProviderPreset.gemini,
        ModelReasoningFormat.geminiLevel,
        'generationConfig.thinkingConfig.thinkingLevel',
        'Unknown name "thinking_level"',
      ),
      (
        ProviderPreset.gemini,
        ModelReasoningFormat.geminiLevel,
        'generationConfig.thinkingConfig.thinkingLevel',
        'Thinking level HIGH is not supported for this model',
      ),
      (
        ProviderPreset.anthropic,
        ModelReasoningFormat.anthropicBudget,
        'thinking.budget_tokens',
        'Invalid thinking.budget_tokens',
      ),
    ]) {
      test(
        '$reason reports the field sent by ${preset.name}, agent=$agent',
        () async {
          server.status = 422;
          server.error = {
            'error': {'message': reason},
          };
          final provider = preset.createConfig().copyWith(
            modelReasoningFormats: {_id: format},
          );
          final message = await _complete(dio, provider, 'high', agent: agent);
          expect(server.bodies, hasLength(1));
          expect(message, contains(reason));
          expect(message, contains('$field · 切回模型默认重试'));
        },
      );
    }
  }
}
