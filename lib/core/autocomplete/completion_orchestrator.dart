import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'autocomplete_settings.dart';
import 'completion_models.dart';
import 'completion_ranker.dart';
import 'danbooru_completion_source.dart';

class CompletionOrchestrator extends ChangeNotifier {
  CompletionOrchestrator({
    required List<CompletionSource> localSources,
    required TranslationResolver dictionaryTranslations,
    required TranslationResolver llmTranslations,
    required DanbooruCompletionSource danbooru,
    List<CompletionSource> tagLookupSources = const [],
    CompletionSource? libraryAliases,
    Duration llmDebounceDuration = const Duration(milliseconds: 400),
  }) : _localSources = localSources,
       _tagLookupSources = tagLookupSources,
       _dictionaryTranslations = dictionaryTranslations,
       _llmTranslations = llmTranslations is ScopedTranslationResolver
           ? llmTranslations.createScope()
           : llmTranslations,
       _danbooru = danbooru,
       _libraryAliases = libraryAliases,
       _llmDebounceDuration = llmDebounceDuration;

  final List<CompletionSource> _localSources;
  final List<CompletionSource> _tagLookupSources;
  final TranslationResolver _dictionaryTranslations;
  final TranslationResolver _llmTranslations;
  final DanbooruCompletionSource _danbooru;
  final CompletionSource? _libraryAliases;
  final Duration _llmDebounceDuration;

  CompletionState _state = const CompletionState();
  CompletionState get state => _state;

  Timer? _remoteDebounce;
  Timer? _llmDebounce;
  int _sequence = 0;
  final Set<String> _llmRequested = {};
  bool _llmStartedForSequence = false;
  bool _disposed = false;

  /// Stops every in-flight completion branch and clears the visible snapshot.
  ///
  /// Closing a popup is an interaction decision, not merely a presentation
  /// change. Invalidating the sequence prevents a delayed local or remote result
  /// from reopening a popup that the user already dismissed.
  void cancel() {
    _sequence++;
    _cancelPendingLlmTranslation();
    _remoteDebounce?.cancel();
    _danbooru.cancelPending();
    _emit(const CompletionState());
  }

  Future<void> query(
    CompletionQuery query,
    AutocompleteSettings settings, {
    CompletionQuery? relatedFallbackQuery,
  }) async {
    final sequence = ++_sequence;
    _cancelPendingLlmTranslation();
    _remoteDebounce?.cancel();
    _danbooru.cancelPending();
    final requestedRelatedQuery =
        query.relatedTag != null && query.token.isEmpty;
    if (!settings.enabled ||
        (query.token.isEmpty &&
            query.relatedTag == null &&
            query.kind != CompletionQueryKind.libraryAlias) ||
        (requestedRelatedQuery && !settings.relatedTagsEnabled)) {
      _emit(CompletionState(query: query));
      return;
    }

    var effectiveQuery = query;
    if (requestedRelatedQuery &&
        relatedFallbackQuery != null &&
        _tagLookupSources.isNotEmpty) {
      final resolution = await _resolveRelatedTag(relatedFallbackQuery);
      if (!_isCurrent(sequence)) return;
      if (resolution != null) {
        effectiveQuery = resolution.isExact
            ? query.copyWith(relatedTag: resolution.canonicalTag)
            : relatedFallbackQuery;
      }
    }

    final isRelatedQuery =
        effectiveQuery.relatedTag != null && effectiveQuery.token.isEmpty;
    final isLibraryAlias =
        effectiveQuery.kind == CompletionQueryKind.libraryAlias;

    final canLoadRemote =
        !isLibraryAlias &&
        settings.danbooruEnabled &&
        (effectiveQuery.token.length >= 2 || isRelatedQuery);
    _emit(
      CompletionState(
        query: effectiveQuery,
        candidates: const [],
        isLocalLoading: true,
        isRemoteLoading: canLoadRemote,
      ),
    );

    final activeLocalSources = isLibraryAlias
        ? [_libraryAliases].whereType<CompletionSource>()
        : _localSources;
    final expandsRelatedResults =
        isRelatedQuery &&
        effectiveQuery.limit > CompletionResultLimits.initialRelatedTags;
    final initialQuery = expandsRelatedResults
        ? effectiveQuery.copyWith(
            limit: CompletionResultLimits.initialRelatedTags,
          )
        : effectiveQuery;
    final localResults = await Future.wait(
      activeLocalSources.map((source) async {
        try {
          return _LocalSourceResult(await source.search(initialQuery));
        } catch (error) {
          return _LocalSourceResult(
            const <CompletionCandidate>[],
            error: '${source.runtimeType}: $error',
          );
        }
      }),
    );
    final localBatches = localResults.map((result) => result.candidates);
    final localErrors = localResults
        .map((result) => result.error)
        .whereType<String>()
        .toList(growable: false);
    if (!_isCurrent(sequence)) return;
    var candidates = isLibraryAlias
        ? localBatches
              .expand((batch) => batch)
              .take(effectiveQuery.limit)
              .toList(growable: false)
        : CompletionRanker.mergeAndSort(
            localBatches.expand((batch) => batch),
            query: initialQuery,
          );
    if (isRelatedQuery) {
      candidates = candidates
          .where((candidate) => !candidate.isExisting)
          .toList(growable: false);
    }
    candidates = await _applyDictionaryTranslations(
      candidates,
      initialQuery,
      sequence,
      settings,
    );
    if (!_isCurrent(sequence)) return;
    _emit(
      _state.copyWith(
        candidates: candidates,
        isLocalLoading: expandsRelatedResults,
        localError: localErrors.isEmpty ? null : localErrors.join('\n'),
        clearLocalError: localErrors.isEmpty,
        isRemoteLoading: canLoadRemote,
      ),
    );
    _scheduleLlmTranslations(initialQuery, sequence, settings);
    if (expandsRelatedResults) {
      unawaited(_expandRelatedLocalResults(effectiveQuery, settings, sequence));
    }

    if (!canLoadRemote) {
      _emit(_state.copyWith(isRemoteLoading: false));
      return;
    }
    _remoteDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_loadRemote(effectiveQuery, sequence, settings));
    });
  }

  Future<_RelatedTagResolution?> _resolveRelatedTag(
    CompletionQuery fallbackQuery,
  ) async {
    // Prefix matches must stay in normal completion so an incomplete tag is
    // never guessed as the source of a related-tag query.
    final lookupQuery = fallbackQuery.copyWith(
      limit: math.min(fallbackQuery.limit, 20),
    );
    final results = await Future.wait(
      _tagLookupSources.map((source) async {
        try {
          return await source.search(lookupQuery);
        } catch (_) {
          return const <CompletionCandidate>[];
        }
      }),
    );
    final candidates = CompletionRanker.mergeAndSort(
      results.expand((batch) => batch),
      query: lookupQuery,
    );
    if (candidates.isEmpty) return null;

    final exact = candidates.where(_isExactTagMatch).firstOrNull;
    return _RelatedTagResolution(
      canonicalTag: (exact ?? candidates.first).canonicalTag,
      isExact: exact != null,
    );
  }

  static bool _isExactTagMatch(CompletionCandidate candidate) =>
      switch (candidate.matchKind) {
        CompletionMatchKind.englishExact ||
        CompletionMatchKind.aliasExact ||
        CompletionMatchKind.chineseExact => true,
        _ => false,
      };

  Future<void> _expandRelatedLocalResults(
    CompletionQuery query,
    AutocompleteSettings settings,
    int sequence,
  ) async {
    final localResults = await Future.wait(
      _localSources.map((source) async {
        try {
          return _LocalSourceResult(await source.search(query));
        } catch (error) {
          return _LocalSourceResult(
            const <CompletionCandidate>[],
            error: '${source.runtimeType}: $error',
          );
        }
      }),
    );
    if (!_isCurrent(sequence)) return;

    final localErrors = localResults
        .map((result) => result.error)
        .whereType<String>()
        .toList(growable: false);
    var expanded = CompletionRanker.mergeAndSort(
      localResults.expand((result) => result.candidates),
      query: query,
    ).where((candidate) => !candidate.isExisting).toList(growable: false);
    expanded = await _applyDictionaryTranslations(
      expanded,
      query,
      sequence,
      settings,
    );
    if (!_isCurrent(sequence)) return;

    final merged = CompletionRanker.mergeAndSort(
      [..._state.candidates, ...expanded],
      query: query,
    ).where((candidate) => !candidate.isExisting).toList(growable: false);
    _emit(
      _state.copyWith(
        candidates: merged,
        isLocalLoading: false,
        localError: localErrors.isEmpty ? null : localErrors.join('\n'),
        clearLocalError: localErrors.isEmpty,
      ),
    );
  }

  Future<List<CompletionCandidate>> _applyDictionaryTranslations(
    List<CompletionCandidate> candidates,
    CompletionQuery query,
    int sequence,
    AutocompleteSettings settings,
  ) async {
    if (query.kind == CompletionQueryKind.libraryAlias ||
        !settings.showTranslations ||
        candidates.isEmpty) {
      return candidates;
    }
    final missing = candidates
        .where((candidate) => candidate.translation?.isNotEmpty != true)
        .map((candidate) => candidate.canonicalTag)
        .toList();
    Map<String, String> translations;
    try {
      translations = await _dictionaryTranslations.resolve(
        missing,
        locale: query.locale,
      );
    } catch (_) {
      return candidates;
    }
    if (!_isCurrent(sequence) || translations.isEmpty) return candidates;
    return candidates
        .map(
          (candidate) => translations[candidate.canonicalTag] == null
              ? candidate
              : candidate.copyWith(
                  translation: translations[candidate.canonicalTag],
                  sources: {
                    ...candidate.sources,
                    CompletionSourceKind.zhDictionary,
                  },
                ),
        )
        .toList(growable: false);
  }

  Future<void> _loadRemote(
    CompletionQuery query,
    int sequence,
    AutocompleteSettings settings,
  ) async {
    List<CompletionCandidate> remote;
    try {
      remote = query.relatedTag != null && query.token.isEmpty
          ? await _danbooru.relatedTags(query.relatedTag!, limit: query.limit)
          : await _danbooru.search(query);
    } catch (error) {
      if (_isCurrent(sequence)) {
        _emit(
          _state.copyWith(
            isRemoteLoading: false,
            remoteError: error.toString(),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(sequence)) return;
    var merged = _mergeRemoteWithoutReordering(
      local: _state.candidates,
      remote: remote,
      query: query,
    );
    if (query.relatedTag != null) {
      merged = merged
          .where((candidate) => !candidate.isExisting)
          .toList(growable: false);
    }
    merged = await _applyDictionaryTranslations(
      merged,
      query,
      sequence,
      settings,
    );
    if (!_isCurrent(sequence)) return;
    final remoteError = _danbooru.lastError;
    _emit(
      _state.copyWith(
        candidates: merged,
        isRemoteLoading: false,
        remoteError: remoteError,
        clearRemoteError: remoteError == null,
      ),
    );
    _scheduleLlmTranslations(query, sequence, settings);
  }

  List<CompletionCandidate> _mergeRemoteWithoutReordering({
    required List<CompletionCandidate> local,
    required List<CompletionCandidate> remote,
    required CompletionQuery query,
  }) {
    final localIds = local.map((candidate) => candidate.stableId).toSet();
    final mergedPool = CompletionRanker.mergeAndSort(
      [...local, ...remote],
      query: query,
      limit: local.length + remote.length,
    );
    final byId = {
      for (final candidate in mergedPool) candidate.stableId: candidate,
    };
    final stableLocal = local
        .map((candidate) => byId[candidate.stableId] ?? candidate)
        .toList(growable: false);
    final onlineOnly = mergedPool
        .where((candidate) => !localIds.contains(candidate.stableId))
        .toList(growable: false);

    // Local rows stay in place while online-only tags are appended. Reserving
    // extra rows is the only way to expose new Danbooru tags without replacing
    // the already-visible local list or moving the keyboard selection.
    if (CompletionResultLimits.isAll(query.limit)) {
      return [...stableLocal, ...onlineOnly];
    }
    final baselineGap = math.max(0, query.limit - stableLocal.length);
    final supplementLimit = ((query.limit + 1) ~/ 2).clamp(1, 50);
    final remoteSlots = math.max(baselineGap, supplementLimit);
    return [...stableLocal, ...onlineOnly.take(remoteSlots)];
  }

  void _scheduleLlmTranslations(
    CompletionQuery query,
    int sequence,
    AutocompleteSettings settings,
  ) {
    if (_llmStartedForSequence) return;
    _llmDebounce?.cancel();
    _llmDebounce = null;
    if (query.kind == CompletionQueryKind.libraryAlias ||
        !settings.showTranslations ||
        !settings.llmTranslationEnabled ||
        !query.locale.toLowerCase().startsWith('zh')) {
      return;
    }
    _llmDebounce = Timer(_llmDebounceDuration, () {
      _llmDebounce = null;
      if (!_isCurrent(sequence) || _llmStartedForSequence) return;
      final missing = _state.candidates
          .where(
            (candidate) =>
                candidate.translation?.isNotEmpty != true &&
                !_llmRequested.contains(candidate.canonicalTag),
          )
          .take(8)
          .map((candidate) => candidate.canonicalTag)
          .toList();
      if (missing.isEmpty) return;
      _llmStartedForSequence = true;
      _llmRequested.addAll(missing);
      final missingSet = missing.toSet();
      _emit(
        _state.copyWith(
          candidates: _state.candidates
              .map(
                (candidate) => missingSet.contains(candidate.canonicalTag)
                    ? candidate.copyWith(isTranslating: true)
                    : candidate,
              )
              .toList(growable: false),
        ),
      );
      unawaited(_resolveLlm(missing, query, sequence));
    });
  }

  Future<void> _resolveLlm(
    List<String> missing,
    CompletionQuery query,
    int sequence,
  ) async {
    try {
      final translations = await _llmTranslations.resolve(
        missing,
        locale: query.locale,
      );
      if (!_isCurrent(sequence)) return;
      _emit(
        _state.copyWith(
          candidates: _state.candidates
              .map((candidate) {
                if (!missing.contains(candidate.canonicalTag)) return candidate;
                final translation = translations[candidate.canonicalTag];
                return candidate.copyWith(
                  translation: translation,
                  isTranslating: false,
                  sources: translation == null
                      ? candidate.sources
                      : {...candidate.sources, CompletionSourceKind.ai},
                );
              })
              .toList(growable: false),
          clearTranslationError: true,
        ),
      );
    } catch (error) {
      if (!_isCurrent(sequence)) return;
      _emit(
        _state.copyWith(
          candidates: _state.candidates
              .map(
                (candidate) => missing.contains(candidate.canonicalTag)
                    ? candidate.copyWith(isTranslating: false)
                    : candidate,
              )
              .toList(growable: false),
          translationError: error.toString(),
        ),
      );
    }
  }

  bool _isCurrent(int sequence) => !_disposed && sequence == _sequence;

  void _cancelPendingLlmTranslation() {
    _llmDebounce?.cancel();
    _llmDebounce = null;
    _llmRequested.clear();
    _llmStartedForSequence = false;
    final resolver = _llmTranslations;
    if (resolver is CancellableTranslationResolver) {
      resolver.cancelPending();
    }
  }

  void _emit(CompletionState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    _cancelPendingLlmTranslation();
    _remoteDebounce?.cancel();
    _danbooru.cancelPending();
    super.dispose();
  }
}

class _LocalSourceResult {
  const _LocalSourceResult(this.candidates, {this.error});

  final List<CompletionCandidate> candidates;
  final String? error;
}

class _RelatedTagResolution {
  const _RelatedTagResolution({
    required this.canonicalTag,
    required this.isExact,
  });

  final String canonicalTag;
  final bool isExact;
}
