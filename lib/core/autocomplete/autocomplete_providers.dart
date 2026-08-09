import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/prompt_assistant/services/prompt_assistant_service.dart';
import '../database/services/service_providers.dart';
import 'autocomplete_cache_database.dart';
import 'autocomplete_settings.dart';
import 'cooccurrence_completion_source.dart';
import 'completion_models.dart';
import 'completion_orchestrator.dart';
import 'danbooru_completion_source.dart';
import 'llm_translation_resolver.dart';
import 'tag_catalog_repository.dart';
import 'zh_dictionary_service.dart';

final autocompleteCacheDatabaseProvider = Provider<AutocompleteCacheDatabase>((
  ref,
) {
  final cache = AutocompleteCacheDatabase();
  unawaited(cache.initialize().then((_) => cache.prune()));
  ref.onDispose(() => unawaited(cache.dispose()));
  return cache;
});

final tagCatalogRepositoryProvider = Provider<TagCatalogRepository>((ref) {
  final repository = TagCatalogRepository();
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final zhDictionaryServiceProvider = ChangeNotifierProvider<ZhDictionaryService>(
  (ref) {
    final service = ZhDictionaryService();
    unawaited(() async {
      await service.initialize();
      if (service.state.isInstalled) {
        await service.checkForUpdate();
      }
    }());
    return service;
  },
);

final danbooruCompletionSourceProvider = Provider<DanbooruCompletionSource>((
  ref,
) {
  return DanbooruCompletionSource(
    cache: ref.watch(autocompleteCacheDatabaseProvider),
  );
});

final llmTranslationResolverProvider = Provider<LlmTranslationResolver>((ref) {
  return LlmTranslationResolver(
    service: ref.watch(promptAssistantServiceProvider),
    cache: ref.watch(autocompleteCacheDatabaseProvider),
    isEnabled: () =>
        ref.read(autocompleteSettingsProvider).llmTranslationEnabled,
  );
});

class AutocompleteServices {
  const AutocompleteServices({
    required this.localSources,
    required this.dictionaryTranslations,
    required this.llmTranslations,
    required this.danbooru,
  });

  final List<CompletionSource> localSources;
  final TranslationResolver dictionaryTranslations;
  final TranslationResolver llmTranslations;
  final DanbooruCompletionSource danbooru;

  CompletionOrchestrator createOrchestrator() => CompletionOrchestrator(
    localSources: localSources,
    dictionaryTranslations: dictionaryTranslations,
    llmTranslations: llmTranslations,
    danbooru: danbooru,
  );
}

final cooccurrenceCompletionSourceProvider =
    Provider<CooccurrenceCompletionSource>((ref) {
      final dataSource = ref.watch(cooccurrenceDataSourceProvider.future);
      return CooccurrenceCompletionSource.withLoader(
        () => dataSource,
        catalog: ref.watch(tagCatalogRepositoryProvider),
      );
    });

final autocompleteLocalSourcesProvider = Provider<List<CompletionSource>>((
  ref,
) {
  return <CompletionSource>[
    ref.watch(tagCatalogRepositoryProvider),
    ref.watch(zhDictionaryServiceProvider),
    ref.watch(cooccurrenceCompletionSourceProvider),
  ];
});

final autocompleteServicesProvider = Provider<AutocompleteServices>((ref) {
  final zhDictionary = ref.watch(zhDictionaryServiceProvider);
  return AutocompleteServices(
    localSources: ref.watch(autocompleteLocalSourcesProvider),
    dictionaryTranslations: zhDictionary,
    llmTranslations: ref.watch(llmTranslationResolverProvider),
    danbooru: ref.watch(danbooruCompletionSourceProvider),
  );
});
