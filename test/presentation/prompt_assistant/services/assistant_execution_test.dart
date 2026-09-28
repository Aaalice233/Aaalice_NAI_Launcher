import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/local_first_prompt_translation.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_execution_settings.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

import '../../../helpers/memory_local_storage.dart';

class _Secure extends Fake implements SecureStorageService {
  @override
  Future<String?> getPromptAssistantApiKey(String providerId) async => null;
}

class _Api extends Fake implements PromptAssistantApiClient {
  final requests = <PromptAssistantRequest>[];
  final replies = <Completer<String>>[];
  Completer<void>? started;
  int waitForCount = 0;

  @override
  void cancelCurrentRequest({String? sessionId}) {}

  @override
  Stream<StreamingChunk> complete({
    required PromptAssistantRequest request,
  }) async* {
    requests.add(request);
    final reply = Completer<String>();
    replies.add(reply);
    if (requests.length == waitForCount) started?.complete();
    final result = await Future.any([
      reply.future,
      request.cancelToken!.whenCancel.then<String>((error) => throw error),
    ]);
    yield StreamingChunk(delta: result);
    yield const StreamingChunk(delta: '', done: true);
  }

  void finish(int index) {
    final tags =
        (jsonDecode(
                  (requests[index].userParts.first as PromptAssistantTextPart)
                      .text,
                )
                as List)
            .cast<String>();
    replies[index].complete(jsonEncode({for (final tag in tags) tag: '译$tag'}));
  }
}

void main() {
  late MemoryLocalStorage storage;
  late ProviderContainer container;
  late _Api api;
  late PromptAssistantService service;

  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(_Secure()),
      promptAssistantServiceProvider.overrideWith(
        (ref) => PromptAssistantService(
          ref: ref,
          apiClient: api,
          localFirstTranslation: LocalFirstPromptTranslationPipeline(
            TagTranslationLookup.fromResolver((_) async => {}),
          ),
        ),
      ),
    ],
  );

  setUp(() async {
    api = _Api();
    storage = MemoryLocalStorage();
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
    container = createContainer();
    container.read(promptAssistantConfigProvider);
    await Future<void>.delayed(Duration.zero);
    service = container.read(promptAssistantServiceProvider);
  });
  tearDown(() => container.dispose());

  test(
    'all missing tags are batched concurrently and rendered in original order',
    () async {
      api.waitForCount = 3;
      api.started = Completer<void>();
      final tags = List.generate(19, (i) => 'tag_$i');
      final future = service
          .translatePrompt(tags.join(', '), sessionId: 'translation')
          .toList();
      await api.started!.future;
      expect(api.requests.length, 3);
      for (final request in api.requests) {
        expect(request.allowConcurrentInSession, isTrue);
        expect(request.reasoningRequest, isNull);
      }
      for (final index in [2, 0, 1]) {
        api.finish(index);
      }
      final chunks = await future;
      expect(
        chunks.map((chunk) => chunk.delta).join(),
        tags.map((tag) => '译$tag').join(', '),
      );
    },
  );

  test(
    'cancelling an operation stops every batch and a subsequent run succeeds',
    () async {
      api.waitForCount = 2;
      api.started = Completer<void>();
      final pending = service.translateTags(
        List.generate(16, (i) => 'tag_$i'),
        sessionId: 'same',
      );
      final assertion = expectLater(pending, throwsA(isA<DioException>()));
      await api.started!.future;
      await service.cancelCurrentTask(sessionId: 'same');
      await assertion;
      expect(
        api.requests.every((request) => request.cancelToken!.isCancelled),
        isTrue,
      );
      api.waitForCount = 3;
      api.started = Completer<void>();
      final next = service.translateTags(['new_tag'], sessionId: 'same');
      await api.started!.future;
      api.finish(2);
      expect((await next).translations, {'new_tag': '译new_tag'});
    },
  );

  test(
    'provider modes and per-task thinking survive notifier storage reload',
    () async {
      final notifier = container.read(promptAssistantConfigProvider.notifier);
      final existing = container
          .read(promptAssistantConfigProvider)
          .providers
          .first;
      expect(existing.concurrency.mode, AssistantConcurrencyMode.automatic);
      await notifier.upsertProvider(
        existing.copyWith(
          concurrency: const AssistantConcurrencySettings(
            mode: AssistantConcurrencyMode.manual,
            maxConcurrentRequests: 9,
          ),
        ),
      );
      await notifier.upsertProvider(
        ProviderPreset.gemini.createConfig(id: 'gemini'),
      );
      await notifier.setRouting(
        container
            .read(promptAssistantConfigProvider)
            .routing
            .copyWith(
              thinkingLevels: {
                AssistantTaskType.translate: AssistantThinkingLevel.high,
              },
            ),
      );
      container.dispose();
      container = createContainer();
      container.read(promptAssistantConfigProvider);
      await Future<void>.delayed(Duration.zero);
      final restored = container.read(promptAssistantConfigProvider);
      expect(
        restored.providers.first.concurrency.mode,
        AssistantConcurrencyMode.manual,
      );
      expect(restored.providers.first.concurrency.maxConcurrentRequests, 9);
      expect(
        restored.providers.last.concurrency.mode,
        AssistantConcurrencyMode.automatic,
      );
      expect(
        restored.routing.thinkingFor(AssistantTaskType.translate),
        AssistantThinkingLevel.high,
      );
      service = container.read(promptAssistantServiceProvider);
      api.waitForCount = 1;
      api.started = Completer<void>();
      final pending = service.translateTags(['tag'], sessionId: 'thinking');
      await api.started!.future;
      expect(api.requests.single.reasoningRequest?.enabled, isTrue);
      expect(api.requests.single.reasoningRequest?.effort, 'high');
      api.finish(0);
      await pending;
      expect(
        restored.routing
            .copyWithTask(
              taskType: AssistantTaskType.translate,
              providerId: 'gemini',
              model: 'gemini-2.5-flash',
            )
            .thinkingFor(AssistantTaskType.translate),
        AssistantThinkingLevel.automatic,
      );
    },
  );

  test(
    'one invalid batch fails the operation without leaking other requests',
    () async {
      api.waitForCount = 2;
      api.started = Completer<void>();
      final pending = service.translateTags(
        List.generate(16, (i) => 'tag_$i'),
        sessionId: 'invalid',
      );
      final assertion = expectLater(pending, throwsFormatException);
      await api.started!.future;
      api.replies.first.complete('{}');
      await assertion;
      expect(api.requests.last.cancelToken!.isCancelled, isTrue);
    },
  );
}
