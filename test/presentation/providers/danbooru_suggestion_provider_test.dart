import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/cache/tag_cache_service.dart';
import 'package:nai_launcher/core/services/danbooru_tags_lazy_service.dart';
import 'package:nai_launcher/core/services/translation/translation_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/models/tag/tag_suggestion.dart';
import 'package:nai_launcher/presentation/providers/danbooru_suggestion_provider.dart';

class _MockTagCacheService extends Mock implements TagCacheService {}

class _MockDanbooruApiService extends Mock implements DanbooruApiService {}

class _MockDanbooruTagsLazyService extends Mock
    implements DanbooruTagsLazyService {}

void main() {
  late TagCacheService cacheService;
  late DanbooruApiService apiService;
  late DanbooruTagsLazyService tagsService;
  late ProviderContainer container;
  late ProviderSubscription<TagSuggestionState> subscription;

  setUp(() {
    cacheService = _MockTagCacheService();
    apiService = _MockDanbooruApiService();
    tagsService = _MockDanbooruTagsLazyService();

    when(() => cacheService.init()).thenAnswer((_) async {});
    when(() => tagsService.isInitialized).thenReturn(false);

    container = ProviderContainer(
      overrides: [
        tagCacheServiceProvider.overrideWithValue(cacheService),
        danbooruApiServiceProvider.overrideWithValue(apiService),
        danbooruTagsLazyServiceProvider.overrideWith(
          (ref) async => tagsService,
        ),
        unifiedTranslationServiceProvider.overrideWith(
          (ref) async => UnifiedTranslationService(),
        ),
      ],
    );
    subscription = container.listen(
      danbooruSuggestionNotifierProvider,
      (previous, next) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  test('clears suggestions as soon as a different query starts', () async {
    when(() => cacheService.get('foot_focus')).thenReturn(null);
    when(() => cacheService.get('lo')).thenReturn(null);
    when(() => cacheService.set('foot_focus', any())).thenAnswer((_) async {});
    when(() => cacheService.set('lo', any())).thenAnswer((_) async {});
    when(() => apiService.suggestTags('foot_focus', limit: 20)).thenAnswer(
      (_) async => const [
        TagSuggestion(tag: 'foot_focus', translation: '足部焦点'),
      ],
    );
    final secondQuery = Completer<List<TagSuggestion>>();
    when(
      () => apiService.suggestTags('lo', limit: 20),
    ).thenAnswer((_) => secondQuery.future);

    final notifier = container.read(
      danbooruSuggestionNotifierProvider.notifier,
    );
    notifier.search('foot_focus', immediate: true);
    await _waitForState(
      container,
      (state) => state.suggestions.isNotEmpty && !state.isLoading,
    );

    notifier.search('lo', immediate: true);

    final loadingState = container.read(danbooruSuggestionNotifierProvider);
    expect(loadingState.currentQuery, 'lo');
    expect(loadingState.suggestions, isEmpty);
    expect(loadingState.isLoading, isTrue);

    secondQuery.complete(const []);
    await _waitForState(container, (state) => !state.isLoading);
  });

  test(
    'ignores an older request that finishes after the latest query',
    () async {
      when(() => cacheService.get('foot_focus')).thenReturn(null);
      when(() => cacheService.get('lo')).thenReturn(null);
      when(() => cacheService.set('lo', any())).thenAnswer((_) async {});

      final firstQuery = Completer<List<TagSuggestion>>();
      final secondQuery = Completer<List<TagSuggestion>>();
      when(
        () => apiService.suggestTags('foot_focus', limit: 20),
      ).thenAnswer((_) => firstQuery.future);
      when(
        () => apiService.suggestTags('lo', limit: 20),
      ).thenAnswer((_) => secondQuery.future);

      final notifier = container.read(
        danbooruSuggestionNotifierProvider.notifier,
      );
      notifier.search('foot_focus', immediate: true);
      notifier.search('lo', immediate: true);

      secondQuery.complete(const [
        TagSuggestion(tag: 'long_hair', translation: '长发'),
      ]);
      await _waitForState(
        container,
        (state) => state.suggestions.singleOrNull?.tag == 'long_hair',
      );

      firstQuery.complete(const [
        TagSuggestion(tag: 'foot_focus', translation: '足部焦点'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final finalState = container.read(danbooruSuggestionNotifierProvider);
      expect(finalState.currentQuery, 'lo');
      expect(finalState.suggestions.single.tag, 'long_hair');
    },
  );
}

Future<void> _waitForState(
  ProviderContainer container,
  bool Function(TagSuggestionState state) predicate,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final state = container.read(danbooruSuggestionNotifierProvider);
    if (predicate(state)) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for Danbooru suggestion state');
}
