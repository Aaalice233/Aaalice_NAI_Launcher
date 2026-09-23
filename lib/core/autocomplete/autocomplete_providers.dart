import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/services/service_providers.dart';
import '../network/network_failure_diagnostics.dart';
import 'autocomplete_cache_database.dart';
import 'cooccurrence_completion_source.dart';
import 'completion_models.dart';
import 'completion_orchestrator.dart';
import 'danbooru_completion_source.dart';
import 'fast_tag_service_provider.dart';

export 'fast_tag_service_provider.dart'
    show
        fastTagServiceProvider,
        tagCatalogRepositoryProvider,
        zhDictionaryServiceProvider;

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
    ref.watch(fastTagServiceProvider),
    ref.watch(cooccurrenceCompletionSourceProvider),
  ];
});
