import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/autocomplete_providers.dart';
import '../../core/autocomplete/autocomplete_settings.dart';
import '../../core/autocomplete/llm_translation_resolver.dart';
import '../../core/autocomplete/tag_library_completion_source.dart';
import 'alias_resolver_service.dart';
import '../prompt_assistant/services/prompt_assistant_service.dart';
import '../prompt_assistant/services/prompt_assistant_tag_translation.dart';

final llmTranslationResolverProvider = Provider<LlmTranslationResolver>((ref) {
  return LlmTranslationResolver(
    service: PromptAssistantTagTranslation(
      ref.watch(promptAssistantServiceProvider),
    ),
    cache: ref.watch(autocompleteCacheDatabaseProvider),
    isEnabled: () =>
        ref.read(autocompleteSettingsProvider).llmTranslationEnabled,
  );
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
  final fastTags = ref.watch(fastTagServiceProvider);
  return AutocompleteServices(
    localSources: ref.watch(autocompleteLocalSourcesProvider),
    tagLookupSources: [fastTags],
    dictionaryTranslations: fastTags,
    llmTranslations: ref.watch(llmTranslationResolverProvider),
    danbooru: ref.watch(danbooruCompletionSourceProvider),
    libraryAliases: ref.watch(tagLibraryCompletionSourceProvider),
  );
});
