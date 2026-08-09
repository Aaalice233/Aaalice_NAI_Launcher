import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/autocomplete/autocomplete_providers.dart';
import '../../core/autocomplete/autocomplete_settings.dart';
import '../../core/autocomplete/completion_models.dart';
import '../../core/autocomplete/completion_orchestrator.dart';
import '../../core/autocomplete/prompt_token_parser.dart';
import '../../data/models/tag/tag_suggestion.dart';

part 'danbooru_suggestion_provider.g.dart';

class TagSuggestionState {
  const TagSuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
    this.currentQuery = '',
    this.source = TagSuggestionSource.none,
  });

  final List<TagSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final String currentQuery;
  final TagSuggestionSource source;
}

enum TagSuggestionSource { none, memoryCache, storageCache, danbooru, novelai }

/// Compatibility facade for tag-library search surfaces.
///
/// Prompt inputs and auxiliary tag browsers now share the same local-first
/// orchestrator, cache, filtering, and translation pipeline.
@riverpod
class DanbooruSuggestionNotifier extends _$DanbooruSuggestionNotifier {
  static const _debounceDelay = Duration(milliseconds: 200);

  Timer? _debounce;
  late CompletionOrchestrator _orchestrator;
  var _activeQuery = '';

  @override
  TagSuggestionState build() {
    _orchestrator = ref
        .watch(autocompleteServicesProvider)
        .createOrchestrator();
    _orchestrator.addListener(_onCompletionStateChanged);
    ref.onDispose(() {
      _debounce?.cancel();
      _orchestrator
        ..removeListener(_onCompletionStateChanged)
        ..dispose();
    });
    return const TagSuggestionState();
  }

  void search(String query, {bool immediate = false}) {
    _debounce?.cancel();
    final normalized = query.trim();
    if (normalized.length < 2) {
      clear();
      return;
    }
    if (normalized == _activeQuery && state.suggestions.isNotEmpty) return;
    _activeQuery = normalized;
    state = TagSuggestionState(currentQuery: normalized, isLoading: true);
    if (immediate) {
      unawaited(_run(normalized));
    } else {
      _debounce = Timer(_debounceDelay, () => unawaited(_run(normalized)));
    }
  }

  Future<void> _run(String query) async {
    final locale = ref.read(autocompleteSettingsProvider).showTranslations
        ? 'zh-CN'
        : 'en';
    final completionQuery = PromptTokenParser.parse(
      text: query,
      cursorPosition: query.length,
      limit: ref.read(autocompleteSettingsProvider).resultLimit,
      locale: locale,
    );
    final settings = ref
        .read(autocompleteSettingsProvider)
        .copyWith(enabled: true);
    await _orchestrator.query(completionQuery, settings);
  }

  void _onCompletionStateChanged() {
    final completionState = _orchestrator.state;
    if (completionState.query?.token != _activeQuery) return;
    final candidates = completionState.candidates;
    final usesApi = candidates.any(
      (candidate) =>
          candidate.sources.contains(CompletionSourceKind.danbooruApi),
    );
    state = TagSuggestionState(
      suggestions: candidates.map(_toSuggestion).toList(growable: false),
      isLoading: completionState.isRemoteLoading,
      error: completionState.remoteError,
      currentQuery: _activeQuery,
      source: usesApi
          ? TagSuggestionSource.danbooru
          : TagSuggestionSource.storageCache,
    );
  }

  TagSuggestion _toSuggestion(CompletionCandidate candidate) => TagSuggestion(
    tag: candidate.canonicalTag,
    count: candidate.postCount,
    category: candidate.category.value,
    alias: candidate.matchedAlias,
    translation: candidate.translation,
  );

  void clear() {
    _debounce?.cancel();
    _activeQuery = '';
    state = const TagSuggestionState();
  }

  Map<String, dynamic> getCacheStats() => const {};

  Future<void> clearCache() async {
    await ref.read(autocompleteCacheDatabaseProvider).clearDanbooruCache();
  }
}

@riverpod
List<TagSuggestion> currentTagSuggestions(Ref ref) {
  return ref.watch(danbooruSuggestionNotifierProvider).suggestions;
}

@riverpod
bool isTagSuggestionLoading(Ref ref) {
  return ref.watch(danbooruSuggestionNotifierProvider).isLoading;
}
