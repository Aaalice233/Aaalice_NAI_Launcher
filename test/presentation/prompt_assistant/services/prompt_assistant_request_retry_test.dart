import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

import '../../../helpers/memory_local_storage.dart';

class _Secure extends Fake implements SecureStorageService {
  @override
  Future<String?> getPromptAssistantApiKey(String providerId) async => null;
}

/// Answers every protocol's non-streaming completion shape with [text].
Map<String, dynamic> _completion(String text) => {
  'choices': [
    {
      'message': {'content': text},
    },
  ],
  'output_text': text,
  'content': [
    {'type': 'text', 'text': text},
  ],
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': text},
        ],
      },
    },
  ],
};

DioException _badGateway(RequestOptions options) => DioException(
  requestOptions: options,
  response: Response<dynamic>(requestOptions: options, statusCode: 502),
  type: DioExceptionType.badResponse,
);

/// Dio whose request number `i` is rejected with `failures[i]` when present.
Dio _flakyDio(
  Map<int, DioException Function(RequestOptions)> failures,
  List<RequestOptions> requests, {
  String Function(RequestOptions options)? reply,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final index = requests.length;
        requests.add(options);
        if (failures[index] case final failure?) {
          handler.reject(failure(options));
          return;
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: _completion(reply?.call(options) ?? 'ok'),
          ),
        );
      },
    ),
  );
  return dio;
}

PromptAssistantRequest _request(ProviderProtocol protocol) =>
    PromptAssistantRequest(
      sessionId: 'retry-test',
      provider: ProviderConfig(
        id: 'relay',
        name: 'Relay',
        protocol: protocol,
        baseUrl: 'https://relay.example.test/v1',
      ),
      model: 'test',
      systemPrompt: 'test',
      userParts: [PromptAssistantContentPart.text('test')],
      apiKey: null,
    );

void main() {
  final failures = <String, DioException Function(RequestOptions)>{
    'HTTP 502': _badGateway,
    'disconnect after sending': (options) => DioException.connectionError(
      requestOptions: options,
      reason: 'Connection closed before full header was received',
    ),
  };

  for (final protocol in ProviderProtocol.values) {
    for (final MapEntry(key: name, value: failure) in failures.entries) {
      test('$protocol retries a single $name', () {
        fakeAsync((time) {
          final requests = <RequestOptions>[];
          final dio = _flakyDio({0: failure}, requests);
          final client = PromptAssistantApiClient(dio: dio);
          List<StreamingChunk>? chunks;
          Object? caught;
          unawaited(
            client
                .complete(request: _request(protocol))
                .toList()
                .then<void>(
                  (value) => chunks = value,
                  onError: (Object error) => caught = error,
                ),
          );
          time.elapse(Duration.zero);
          expect(requests, hasLength(1));
          time.elapse(const Duration(seconds: 1));
          expect(requests, hasLength(2));
          expect(caught, isNull);
          expect(chunks?.first.delta, 'ok');
          client.dispose();
          dio.close(force: true);
          time.elapse(Duration.zero);
          expect(time.pendingTimers, isEmpty);
        });
      });
    }
  }

  test('a failed tag batch is retried instead of cancelling its siblings', () {
    fakeAsync((time) {
      final requests = <RequestOptions>[];
      final dio = _flakyDio(
        {1: _badGateway},
        requests,
        reply: (options) {
          final messages = (options.data as Map)['messages'] as List;
          final tags =
              (jsonDecode((messages.last as Map)['content'] as String) as List)
                  .cast<String>();
          return jsonEncode({for (final tag in tags) tag: '译$tag'});
        },
      );
      final storage = MemoryLocalStorage();
      final config = PromptAssistantConfigState.defaults();
      storage.values[StorageKeys.promptAssistantConfigJson] = config
          .copyWith(
            providers: [ProviderPreset.deepseek.createConfig(id: 'deepseek')],
            models: [
              const ModelConfig(
                providerId: 'deepseek',
                name: 'deepseek-v4-flash',
                displayName: 'DeepSeek',
                forTask: AssistantTaskType.translate,
              ),
            ],
            routing: config.routing.copyWithTask(
              taskType: AssistantTaskType.translate,
              providerId: 'deepseek',
              model: 'deepseek-v4-flash',
            ),
          )
          .encode();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(_Secure()),
          promptAssistantServiceProvider.overrideWith(
            (ref) => PromptAssistantService(
              ref: ref,
              apiClient: PromptAssistantApiClient(dio: dio),
            ),
          ),
        ],
      );
      container.read(promptAssistantConfigProvider);
      time.elapse(Duration.zero);
      final tags = List.generate(19, (i) => 'tag_$i');
      TagTranslationBatchResult? result;
      Object? caught;
      unawaited(
        container
            .read(promptAssistantServiceProvider)
            .translateTags(tags, sessionId: 'tags')
            .then<void>(
              (value) => result = value,
              onError: (Object error) => caught = error,
            ),
      );
      time.elapse(Duration.zero);
      expect(requests, hasLength(3));
      expect(requests.every((item) => !item.cancelToken!.isCancelled), isTrue);
      time.elapse(const Duration(seconds: 1));
      expect(requests, hasLength(4));
      expect(caught, isNull);
      expect(result?.translations, {for (final tag in tags) tag: '译$tag'});
      container.dispose();
      dio.close(force: true);
      time.elapse(Duration.zero);
      expect(time.pendingTimers, isEmpty);
    });
  });
}
