import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/llm_translation_resolver.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_port.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('resolveCached reads every cached tag without calling AI', () async {
    final service = _MockTagTranslationPort();
    final cache = _FakeAutocompleteCacheDatabase({
      for (var index = 0; index < 10; index++)
        'cached_tag_$index': '缓存翻译 $index',
    });
    when(service.routeFingerprint).thenReturn('test-route');
    when(() => service.promptVersion).thenReturn(1);
    final resolver = LlmTranslationResolver(
      service: service,
      cache: cache,
      isEnabled: () => true,
    );
    final tags = List.generate(12, (index) => 'cached_tag_$index');

    final result = await resolver.resolveCached(tags, locale: 'zh-CN');

    expect(cache.reads.single, tags);
    expect(result, hasLength(10));
    verifyNever(
      () => service.translateTags(any(), sessionId: any(named: 'sessionId')),
    );
  });

  test('cancelPending cancels the active translation session', () async {
    final service = _MockTagTranslationPort();
    final cache = _FakeAutocompleteCacheDatabase();
    final response = Completer<Map<String, String>>();
    final requestStarted = Completer<void>();
    late String sessionId;
    when(service.routeFingerprint).thenReturn('test-route');
    when(() => service.promptVersion).thenReturn(1);
    when(
      () => service.translateTags(any(), sessionId: any(named: 'sessionId')),
    ).thenAnswer((invocation) {
      sessionId = invocation.namedArguments[#sessionId] as String;
      requestStarted.complete();
      return response.future;
    });
    when(
      () => service.cancelTask(sessionId: any(named: 'sessionId')),
    ).thenAnswer((_) async {});
    final resolver = LlmTranslationResolver(
      service: service,
      cache: cache,
      isEnabled: () => true,
    );

    final result = resolver.resolve(['blue_eyes'], locale: 'zh-CN');
    await requestStarted.future;
    resolver.cancelPending();

    verify(() => service.cancelTask(sessionId: sessionId)).called(1);
    response.complete(const {'blue_eyes': '蓝眼睛'});
    expect(await result, isEmpty);
    expect(cache.writes, isEmpty);
  });

  group('clearing the AI translation cache', () {
    late Directory supportDirectory;
    late PathProviderPlatform originalPathProvider;
    late AutocompleteCacheDatabase cache;
    late _MockTagTranslationPort service;

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      supportDirectory = await Directory.systemTemp.createTemp(
        'llm_translation_clear_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _SupportPathProvider(
        supportDirectory.path,
      );
      cache = AutocompleteCacheDatabase();
      service = _MockTagTranslationPort();
      when(service.routeFingerprint).thenReturn('test-route');
      when(() => service.promptVersion).thenReturn(1);
    });

    tearDown(() async {
      await cache.dispose();
      PathProviderPlatform.instance = originalPathProvider;
      await supportDirectory.delete(recursive: true);
    });

    test(
      'a translation in flight across the clear is never written back',
      () async {
        final response = Completer<Map<String, String>>();
        final requestStarted = Completer<void>();
        when(
          () =>
              service.translateTags(any(), sessionId: any(named: 'sessionId')),
        ).thenAnswer((_) {
          requestStarted.complete();
          return response.future;
        });
        final scope = LlmTranslationResolver(
          service: service,
          cache: cache,
          isEnabled: () => true,
        ).createScope();

        final result = scope.resolve(['blue_eyes'], locale: 'zh-CN');
        await requestStarted.future;
        await cache.clearAiTranslationCache();
        response.complete(const {'blue_eyes': '蓝眼睛'});

        expect(await result, const {'blue_eyes': '蓝眼睛'});
        expect(await cache.aiTranslationCount(), 0);
      },
    );

    test('a translation started after the clear is cached again', () async {
      when(
        () => service.translateTags(any(), sessionId: any(named: 'sessionId')),
      ).thenAnswer((_) async => const {'blue_eyes': '蓝眼睛'});
      final resolver = LlmTranslationResolver(
        service: service,
        cache: cache,
        isEnabled: () => true,
      );

      await cache.clearAiTranslationCache();
      await resolver.resolve(['blue_eyes'], locale: 'zh-CN');

      expect(await cache.aiTranslationCount(), 1);
    });
  });
}

class _MockTagTranslationPort extends Mock
    implements TagTranslationPort {}

class _SupportPathProvider extends PathProviderPlatform {
  _SupportPathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

class _FakeAutocompleteCacheDatabase extends AutocompleteCacheDatabase {
  _FakeAutocompleteCacheDatabase([this.cached = const {}]);

  final Map<String, String> cached;
  final List<List<String>> reads = [];
  final List<Map<String, String>> writes = [];

  @override
  Future<Map<String, String>> getAiTranslations({
    required List<String> tags,
    required String locale,
    required String routeFingerprint,
    required int promptVersion,
  }) async {
    reads.add(List.unmodifiable(tags));
    return {
      for (final tag in tags)
        if (cached[tag] case final value?) tag: value,
    };
  }

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
