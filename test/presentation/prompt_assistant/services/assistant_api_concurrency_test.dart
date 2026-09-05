import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_execution_settings.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

const _response = {
  'choices': [
    {
      'message': {'content': 'ok'},
    },
  ],
  'content': [
    {'type': 'text', 'text': 'ok'},
  ],
  'candidates': [
    {
      'content': {
        'parts': [
          {'thought': true, 'text': 'hidden thinking'},
          {'text': 'ok'},
        ],
      },
    },
  ],
  'output': [
    {
      'type': 'reasoning',
      'content': [
        {'type': 'reasoning_text', 'text': 'hidden reasoning'},
      ],
    },
    {
      'type': 'message',
      'content': [
        {'type': 'output_text', 'text': 'ok'},
      ],
    },
  ],
};

PromptAssistantRequest request(
  ProviderConfig provider, {
  String session = 'shared',
  String model = 'test',
  bool concurrent = true,
}) => PromptAssistantRequest(
  sessionId: session,
  provider: provider,
  model: model,
  systemPrompt: 'test',
  userParts: [PromptAssistantContentPart.text('test')],
  apiKey: null,
  allowConcurrentInSession: concurrent,
  reasoningRequest: AssistantModelCatalog.resolveProvider(
    provider: provider,
    model: model,
  ).resolveReasoningRequest('high'),
  maxOutputTokens: 4096,
  modelMaxOutputTokens: 32768,
);

void main() {
  test(
    'same-session batches coexist; cancellation also removes queued requests',
    () async {
      final dio = Dio();
      final started = Completer<void>();
      final pending = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            pending.add(options);
            if (pending.length == 2) started.complete();
            unawaited(
              options.cancelToken!.whenCancel.then(
                (error) => handler.reject(error),
              ),
            );
          },
        ),
      );
      final client = PromptAssistantApiClient(dio: dio);
      addTearDown(() {
        client.dispose();
        dio.close(force: true);
      });
      final provider = ProviderPreset.deepseek.createConfig().copyWith(
        concurrency: const AssistantConcurrencySettings(
          mode: AssistantConcurrencyMode.manual,
          maxConcurrentRequests: 2,
        ),
      );
      final assertions = [
        for (var i = 0; i < 5; i++)
          expectLater(
            client.complete(request: request(provider)).toList(),
            throwsStateError,
          ),
      ];
      await started.future;
      expect(pending.every((item) => !item.cancelToken!.isCancelled), isTrue);
      client.cancelCurrentRequest(sessionId: 'shared');
      await Future.wait(assertions);
      expect(pending.length, 2);
      expect(pending.every((item) => item.cancelToken!.isCancelled), isTrue);
    },
  );

  test(
    'a replacement request still cancels the previous single request',
    () async {
      final dio = Dio();
      final started = Completer<void>();
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            if (calls == 1) {
              started.complete();
              unawaited(
                options.cancelToken!.whenCancel.then(
                  (error) => handler.reject(error),
                ),
              );
            } else {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: _response,
                  statusCode: 200,
                ),
              );
            }
          },
        ),
      );
      final client = PromptAssistantApiClient(dio: dio);
      addTearDown(() {
        client.dispose();
        dio.close(force: true);
      });
      final provider = ProviderPreset.deepseek.createConfig();
      final first = expectLater(
        client.complete(request: request(provider, concurrent: false)).toList(),
        throwsStateError,
      );
      await started.future;
      final second = await client
          .complete(request: request(provider, concurrent: false))
          .toList();
      await first;
      expect(second.first.delta, 'ok');
    },
  );

  for (final (preset, model, field) in [
    (ProviderPreset.openaiChat, 'gpt-5', 'reasoning_effort'),
    (ProviderPreset.openaiResponses, 'gpt-5', 'reasoning'),
    (ProviderPreset.deepseek, 'deepseek-v4-flash', 'thinking'),
    (ProviderPreset.anthropic, 'claude-sonnet-4-5', 'thinking'),
    (ProviderPreset.gemini, 'gemini-2.5-flash', 'generationConfig'),
  ]) {
    test(
      'prompt assistant sends native thinking settings for ${preset.name}',
      () async {
        final dio = Dio();
        Map<String, dynamic>? payload;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              payload = Map<String, dynamic>.from(options.data as Map);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: _response,
                  statusCode: 200,
                ),
              );
            },
          ),
        );
        final client = PromptAssistantApiClient(dio: dio);
        addTearDown(() {
          client.dispose();
          dio.close(force: true);
        });
        final chunks = await client
            .complete(request: request(preset.createConfig(), model: model))
            .toList();
        expect(chunks.first.delta, 'ok');
        expect(payload, contains(field));
        if (preset == ProviderPreset.openaiChat) {
          expect(payload![field], 'high');
        }
        if (preset == ProviderPreset.openaiResponses) {
          expect(payload![field], {'effort': 'high'});
        }
        if (preset == ProviderPreset.deepseek) {
          expect(payload![field], {'type': 'enabled'});
          expect(payload!['reasoning_effort'], 'high');
        }
        if (preset == ProviderPreset.anthropic) {
          expect((payload![field] as Map)['type'], 'enabled');
          expect(
            payload!['max_tokens'] as int,
            greaterThan((payload![field] as Map)['budget_tokens'] as int),
          );
        }
        if (preset == ProviderPreset.gemini) {
          expect(payload![field], contains('thinkingConfig'));
        }
      },
    );
  }
}
