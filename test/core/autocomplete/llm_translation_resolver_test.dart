import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/llm_translation_resolver.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';

void main() {
  test('cancelPending cancels the active Prompt Assistant session', () async {
    final service = _MockPromptAssistantService();
    final cache = _FakeAutocompleteCacheDatabase();
    final response = Completer<TagTranslationBatchResult>();
    final requestStarted = Completer<void>();
    late String sessionId;
    when(service.translateRouteFingerprint).thenReturn('test-route');
    when(
      () => service.translateTags(any(), sessionId: any(named: 'sessionId')),
    ).thenAnswer((invocation) {
      sessionId = invocation.namedArguments[#sessionId] as String;
      requestStarted.complete();
      return response.future;
    });
    when(
      () => service.cancelCurrentTask(sessionId: any(named: 'sessionId')),
    ).thenAnswer((_) async {});
    final resolver = LlmTranslationResolver(
      service: service,
      cache: cache,
      isEnabled: () => true,
    );

    final result = resolver.resolve(['blue_eyes'], locale: 'zh-CN');
    await requestStarted.future;
    resolver.cancelPending();

    verify(() => service.cancelCurrentTask(sessionId: sessionId)).called(1);
    response.complete(
      const TagTranslationBatchResult(
        translations: {'blue_eyes': '蓝眼睛'},
        routeFingerprint: 'test-route',
      ),
    );
    expect(await result, isEmpty);
    expect(cache.writes, isEmpty);
  });
}

class _MockPromptAssistantService extends Mock
    implements PromptAssistantService {}

class _FakeAutocompleteCacheDatabase extends AutocompleteCacheDatabase {
  final List<Map<String, String>> writes = [];

  @override
  Future<Map<String, String>> getAiTranslations({
    required List<String> tags,
    required String locale,
    required String routeFingerprint,
    required int promptVersion,
  }) async => const {};

  @override
  Future<void> putAiTranslations({
    required Map<String, String> translations,
    required String locale,
    required String routeFingerprint,
    required int promptVersion,
  }) async {
    writes.add(translations);
  }
}
