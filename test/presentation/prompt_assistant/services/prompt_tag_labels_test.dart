import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_providers.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_mode_prompt_field.dart';

import '../../../helpers/memory_local_storage.dart';

class _Secure extends Fake implements SecureStorageService {
  @override
  Future<String?> getPromptAssistantApiKey(String providerId) async => null;
}

class _Dictionary extends ZhDictionaryService {
  @override
  ZhDictionaryState get state => const ZhDictionaryState(isInstalled: true);
  @override
  Future<void> initialize() async {}
}

class _Api extends Fake implements PromptAssistantApiClient {
  final batches = <List<String>>[];
  bool invalid = false;

  @override
  Stream<StreamingChunk> complete({
    required PromptAssistantRequest request,
  }) async* {
    final tags =
        (jsonDecode((request.userParts.first as PromptAssistantTextPart).text)
                as List)
            .cast<String>();
    batches.add(tags);
    expect(request.systemPrompt, contains('natural-language'));
    yield StreamingChunk(
      delta: invalid
          ? '{}'
          : jsonEncode({for (final tag in tags) tag: '译文 $tag'}),
    );
    yield const StreamingChunk(delta: '', done: true);
  }
}

void main() {
  late ProviderContainer container;
  late TagTranslationLookup lookup;
  late _Api api;
  setUp(() {
    api = _Api();
    lookup = TagTranslationLookup.fromResolver((_) async => {'cat': '猫'});
    final storage = MemoryLocalStorage();
    storage.values[StorageKeys.promptAssistantConfigJson] =
        PromptAssistantConfigState.defaults()
            .copyWith(
              providers: [
                const ProviderConfig(
                  id: 'test',
                  name: 'test',
                  baseUrl: 'https://example.invalid',
                ),
              ],
              models: [
                const ModelConfig(
                  providerId: 'test',
                  name: 'test-model',
                  displayName: 'test-model',
                  forTask: AssistantTaskType.translate,
                ),
              ],
            )
            .encode();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => storage),
        secureStorageServiceProvider.overrideWithValue(_Secure()),
        tagTranslationLookupProvider.overrideWithValue(lookup),
        zhDictionaryServiceProvider.overrideWith((ref) => _Dictionary()),
        promptAssistantServiceProvider.overrideWith(
          (ref) => PromptAssistantService(ref: ref, apiClient: api),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    lookup.dispose();
  });

  testWidgets(
    'assistant button refreshes mounted captions without editing source',
    (tester) async {
      const text = 'cat, a bird rests on a branch';
      final source = TextEditingController(text: text);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: TagModePromptField(
                      controller: source,
                      enableAutocomplete: false,
                      child: TextField(controller: source),
                    ),
                  ),
                  PromptAssistantOverlay(
                    sessionId: 'test',
                    controller: source,
                    supportsTagMode: true,
                    stripFixedTagsFromInput: false,
                    floatOverEditor: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      container
          .read(promptAssistantStateProvider.notifier)
          .setExpanded('test', true);
      await tester.pumpAndSettle();
      expect(find.text('猫'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(api.batches, [
        ['a_bird_rests_on_a_branch'],
      ]);
      expect(find.text('译文 a_bird_rests_on_a_branch'), findsOneWidget);
      expect(source.text, text);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'only missing captions are requested, including prose and more than eight tags',
    () async {
      const natural = "a bird's wings glow in the light";
      final source =
          '1.2::cat, {$natural}::, ${List.generate(9, (i) => 'unknown_$i').join(', ')}';
      final service = container.read(promptAssistantServiceProvider);
      final chunks = await service
          .translateTagLabels(source, sessionId: 'test')
          .toList();
      expect(chunks.every((chunk) => chunk.delta.isEmpty), isTrue);
      expect(api.batches.map((batch) => batch.length), [8, 2]);
      expect(api.batches.expand((batch) => batch), isNot(contains('cat')));
      expect(
        lookup.cachedTranslation(natural),
        '译文 ${TagTranslationLookup.normalizeTag(natural)}',
      );
      expect(lookup.cachedTranslation('cat'), '猫');
      await service.translateTagLabels(source, sessionId: 'test').toList();
      expect(api.batches, hasLength(2));
    },
  );

  test(
    'invalid assistant response fails instead of publishing a partial mapping',
    () async {
      api.invalid = true;
      final service = container.read(promptAssistantServiceProvider);
      await expectLater(
        service.translateTagLabels('unknown', sessionId: 'test').toList(),
        throwsFormatException,
      );
      expect(lookup.cachedTranslation('unknown'), isNull);
    },
  );
}
