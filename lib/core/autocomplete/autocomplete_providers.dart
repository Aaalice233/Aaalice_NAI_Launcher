import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/alias_resolver_service.dart';
import '../../presentation/prompt_assistant/services/prompt_assistant_service.dart';
import '../database/services/service_providers.dart';
import '../network/network_failure_diagnostics.dart';
import 'autocomplete_cache_database.dart';
import 'autocomplete_settings.dart';
import 'cooccurrence_completion_source.dart';
import 'completion_models.dart';
import 'completion_orchestrator.dart';
import 'danbooru_completion_source.dart';
import 'llm_translation_resolver.dart';
import 'tag_catalog_repository.dart';
import 'tag_library_completion_source.dart';
import 'zh_dictionary_service.dart';

final autocompleteCacheDatabaseProvider = Provider<AutocompleteCacheDatabase>((
  ref,
) {
  final cache = AutocompleteCacheDatabase();
  unawaited(cache.initialize().then((_) => cache.prune()));
  ref.onDispose(() => unawaited(cache.dispose()));
  return cache;
});

final autocompleteCacheStatisticsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
      return ref.watch(autocompleteCacheDatabaseProvider).statistics();
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
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://danbooru.donmai.us',
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 3),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Aaalice-NAI-Launcher/Autocomplete',
      },
    ),
  );
  addNetworkFailureDiagnostics(dio, scope: 'Danbooru autocomplete');
  ref.onDispose(dio.close);
  return DanbooruCompletionSource(
    dio: dio,
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
    this.tagLookupSources = const [],
    this.libraryAliases,
  });

  final List<CompletionSource> localSources;
  final List<CompletionSource> tagLookupSources;
  final TranslationResolver dictionaryTranslations;
  final TranslationResolver llmTranslations;
  final DanbooruCompletionSource danbooru;
  final CompletionSource? libraryAliases;

  CompletionOrchestrator createOrchestrator() => CompletionOrchestrator(
    localSources: localSources,
    tagLookupSources: tagLookupSources,
    dictionaryTranslations: dictionaryTranslations,
    llmTranslations: llmTranslations,
    danbooru: danbooru,
    libraryAliases: libraryAliases,
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

final tagLibraryCompletionSourceProvider = Provider<TagLibraryCompletionSource>(
  (ref) => TagLibraryCompletionSource(
    searchEntries: (query, limit) => ref
        .read(aliasResolverServiceProvider.notifier)
        .searchEntries(query, limit: limit)
        .map(
          (entry) => LibraryCompletionEntry(
            name: entry.name,
            contentPreview: entry.contentPreview,
            useCount: entry.useCount,
          ),
        )
        .toList(growable: false),
  ),
);

final autocompleteServicesProvider = Provider<AutocompleteServices>((ref) {
  final zhDictionary = ref.watch(zhDictionaryServiceProvider);
  final tagCatalog = ref.watch(tagCatalogRepositoryProvider);
  return AutocompleteServices(
    localSources: ref.watch(autocompleteLocalSourcesProvider),
    tagLookupSources: [tagCatalog, zhDictionary],
    dictionaryTranslations: zhDictionary,
    llmTranslations: ref.watch(llmTranslationResolverProvider),
    danbooru: ref.watch(danbooruCompletionSourceProvider),
    libraryAliases: ref.watch(tagLibraryCompletionSourceProvider),
  );
});
