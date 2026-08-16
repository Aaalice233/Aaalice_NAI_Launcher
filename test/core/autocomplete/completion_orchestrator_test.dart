import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/completion_orchestrator.dart';
import 'package:nai_launcher/core/autocomplete/danbooru_completion_source.dart';

void main() {
  test(
    'emits local results before delayed API results and merges sources',
    () async {
      final remote = _FakeDanbooru();
      final orchestrator = CompletionOrchestrator(
        localSources: [
          _Source([_candidate('blue_eyes', CompletionSourceKind.base)]),
        ],
        dictionaryTranslations: _Translations({'blue_eyes': '蓝眼睛'}),
        llmTranslations: _Translations(const {}),
        danbooru: remote,
      );
      addTearDown(orchestrator.dispose);

      await orchestrator.query(_query('blue'), const AutocompleteSettings());

      expect(orchestrator.state.candidates.single.canonicalTag, 'blue_eyes');
      expect(orchestrator.state.candidates.single.translation, '蓝眼睛');
      expect(remote.searchCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 270));
      expect(remote.searchCount, 1);
      remote.complete([
        _candidate('blue_eyes', CompletionSourceKind.danbooruApi),
        _candidate('blue_hair', CompletionSourceKind.danbooruApi),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        orchestrator.state.candidates.map(
          (candidate) => candidate.canonicalTag,
        ),
        ['blue_eyes', 'blue_hair'],
      );
      expect(
        orchestrator.state.candidates.first.sources,
        containsAll([
          CompletionSourceKind.base,
          CompletionSourceKind.danbooruApi,
        ]),
      );
    },
  );

  test('keeps candidates that have no dictionary translation', () async {
    final orchestrator = CompletionOrchestrator(
      localSources: [
        _Source([
          _candidate('translated_tag', CompletionSourceKind.base),
          _candidate('untranslated_tag', CompletionSourceKind.base),
        ]),
      ],
      dictionaryTranslations: _Translations({'translated_tag': '已有汉化'}),
      llmTranslations: _Translations(const {}),
      danbooru: _FakeDanbooru(),
    );
    addTearDown(orchestrator.dispose);

    await orchestrator.query(
      _query('tag'),
      const AutocompleteSettings(danbooruEnabled: false),
    );

    expect(orchestrator.state.candidates, hasLength(2));
    expect(
      orchestrator.state.candidates
          .firstWhere((candidate) => candidate.canonicalTag == 'translated_tag')
          .translation,
      '已有汉化',
    );
    expect(
      orchestrator.state.candidates
          .firstWhere(
            (candidate) => candidate.canonicalTag == 'untranslated_tag',
          )
          .translation,
      isNull,
    );
  });

  test(
    'appends every online-only tag in exhaustive mode without moving local rows',
    () async {
      final remote = _FakeDanbooru();
      final localTags = [
        _candidate('blue_archive', CompletionSourceKind.base),
        _candidate('sensei_(blue_archive)', CompletionSourceKind.base),
        _candidate('yuuka_(blue_archive)', CompletionSourceKind.base),
        _candidate('asuna_(blue_archive)', CompletionSourceKind.base),
      ];
      final orchestrator = CompletionOrchestrator(
        localSources: [_Source(localTags)],
        dictionaryTranslations: _Translations(const {}),
        llmTranslations: _Translations(const {}),
        danbooru: remote,
      );
      addTearDown(orchestrator.dispose);

      await orchestrator.query(
        _query('blue_archive', limit: CompletionResultLimits.all),
        const AutocompleteSettings(),
      );
      final initialIds = orchestrator.state.candidates
          .map((candidate) => candidate.stableId)
          .toList(growable: false);
      expect(initialIds, hasLength(localTags.length));

      await Future<void>.delayed(const Duration(milliseconds: 270));
      remote.complete([
        _candidate('blue_archive', CompletionSourceKind.danbooruApi),
        _candidate(
          'doodle_sensei_(blue_archive)',
          CompletionSourceKind.danbooruApi,
        ),
        _candidate(
          'asuna_(bunny)_(blue_archive)',
          CompletionSourceKind.danbooruApi,
        ),
        _candidate(
          'toki_(bunny)_(blue_archive)',
          CompletionSourceKind.danbooruApi,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        orchestrator.state.candidates
            .take(localTags.length)
            .map((candidate) => candidate.stableId),
        initialIds,
      );
      expect(
        orchestrator.state.candidates
            .skip(initialIds.length)
            .map((candidate) => candidate.canonicalTag),
        [
          'asuna_(bunny)_(blue_archive)',
          'doodle_sensei_(blue_archive)',
          'toki_(bunny)_(blue_archive)',
        ],
      );
      expect(
        orchestrator.state.candidates
            .firstWhere((candidate) => candidate.canonicalTag == 'blue_archive')
            .sources,
        containsAll([
          CompletionSourceKind.base,
          CompletionSourceKind.danbooruApi,
        ]),
      );
    },
  );

  test('rejects late results from an older query', () async {
    final remote = _FakeDanbooru();
    final source = _QuerySource();
    final orchestrator = CompletionOrchestrator(
      localSources: [source],
      dictionaryTranslations: _Translations(const {}),
      llmTranslations: _Translations(const {}),
      danbooru: remote,
    );
    addTearDown(orchestrator.dispose);

    final oldQuery = orchestrator.query(
      _query('old'),
      const AutocompleteSettings(danbooruEnabled: false),
    );
    await Future<void>.delayed(Duration.zero);
    await orchestrator.query(
      _query('new'),
      const AutocompleteSettings(danbooruEnabled: false),
    );
    source.completeOld();
    await oldQuery;

    expect(orchestrator.state.query?.token, 'new');
    expect(orchestrator.state.candidates.single.canonicalTag, 'new_tag');
  });

  test('merges offline and online related tags after an empty token', () async {
    final remote = _FakeDanbooru();
    final orchestrator = CompletionOrchestrator(
      localSources: [
        _Source([_candidate('smile', CompletionSourceKind.cooccurrence)]),
      ],
      dictionaryTranslations: _Translations(const {}),
      llmTranslations: _Translations(const {}),
      danbooru: remote,
    );
    addTearDown(orchestrator.dispose);

    await orchestrator.query(
      _query('', fullText: 'blue_eyes, ', relatedTag: 'blue_eyes'),
      const AutocompleteSettings(),
    );
    expect(orchestrator.state.candidates.single.canonicalTag, 'smile');

    await Future<void>.delayed(const Duration(milliseconds: 350));
    remote.completeRelated([
      _candidate('grin', CompletionSourceKind.danbooruApi),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(
      orchestrator.state.candidates.map((value) => value.canonicalTag),
      containsAll(['smile', 'grin']),
    );
  });

  test(
    'does not query related sources when recommendations are disabled',
    () async {
      final relatedSource = _RecordingRelatedSource();
      final orchestrator = CompletionOrchestrator(
        localSources: [relatedSource],
        dictionaryTranslations: _Translations(const {}),
        llmTranslations: _Translations(const {}),
        danbooru: _FakeDanbooru(),
      );
      addTearDown(orchestrator.dispose);

      await orchestrator.query(
        _query('', fullText: 'blue_eyes, ', relatedTag: 'blue_eyes'),
        const AutocompleteSettings(relatedTagsEnabled: false),
      );

      expect(relatedSource.searchCount, 0);
      expect(orchestrator.state.candidates, isEmpty);
      expect(orchestrator.state.isRemoteLoading, isFalse);
    },
  );

  test('keeps healthy local results when another local source fails', () async {
    final orchestrator = CompletionOrchestrator(
      localSources: [
        _ThrowingSource(),
        _Source([_candidate('smile', CompletionSourceKind.cooccurrence)]),
      ],
      dictionaryTranslations: _Translations(const {}),
      llmTranslations: _Translations(const {}),
      danbooru: _FakeDanbooru(),
    );
    addTearDown(orchestrator.dispose);

    await orchestrator.query(
      _query('', fullText: 'blue_eyes, ', relatedTag: 'blue_eyes'),
      const AutocompleteSettings(danbooruEnabled: false),
    );

    expect(orchestrator.state.candidates.single.canonicalTag, 'smile');
    expect(orchestrator.state.localError, contains('_ThrowingSource'));
    expect(orchestrator.state.isLocalLoading, isFalse);
  });

  test(
    'routes library aliases exclusively and preserves library order',
    () async {
      final normalSource = _RecordingRelatedSource();
      final remote = _FakeDanbooru();
      final translations = _CountingTranslations();
      final orchestrator = CompletionOrchestrator(
        localSources: [normalSource],
        dictionaryTranslations: translations,
        llmTranslations: translations,
        danbooru: remote,
        libraryAliases: _Source([
          const CompletionCandidate(
            canonicalTag: 'favorite',
            category: TagCategory.library,
            postCount: 1,
            matchKind: CompletionMatchKind.fullText,
            sources: {CompletionSourceKind.library},
          ),
          const CompletionCandidate(
            canonicalTag: 'frequent',
            category: TagCategory.library,
            postCount: 999,
            matchKind: CompletionMatchKind.fullText,
            sources: {CompletionSourceKind.library},
          ),
        ]),
      );
      addTearDown(orchestrator.dispose);

      await orchestrator.query(
        _query('', kind: CompletionQueryKind.libraryAlias),
        const AutocompleteSettings(),
      );

      expect(normalSource.searchCount, 0);
      expect(remote.searchCount, 0);
      expect(translations.resolveCount, 0);
      expect(
        orchestrator.state.candidates.map(
          (candidate) => candidate.canonicalTag,
        ),
        ['favorite', 'frequent'],
      );
    },
  );

  test(
    'requests at most eight visible missing translations without reordering',
    () async {
      final llm = _RecordingTranslations();
      final tags = List.generate(
        12,
        (index) => _candidate('blue_tag_$index', CompletionSourceKind.base),
      );
      final orchestrator = CompletionOrchestrator(
        localSources: [_Source(tags)],
        dictionaryTranslations: _Translations(const {}),
        llmTranslations: llm,
        danbooru: _FakeDanbooru(),
      );
      addTearDown(orchestrator.dispose);

      await orchestrator.query(
        _query('blue', limit: 12),
        const AutocompleteSettings(
          danbooruEnabled: false,
          llmTranslationEnabled: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(llm.requested, hasLength(8));
      final before = orchestrator.state.candidates
          .map((candidate) => candidate.stableId)
          .toList();
      llm.complete({for (final tag in llm.requested) tag: '翻译'});
      await Future<void>.delayed(Duration.zero);
      final after = orchestrator.state.candidates
          .map((candidate) => candidate.stableId)
          .toList();
      expect(after, before);
      expect(
        orchestrator.state.candidates
            .take(8)
            .every(
              (candidate) =>
                  candidate.sources.contains(CompletionSourceKind.ai),
            ),
        isTrue,
      );
    },
  );
}

CompletionQuery _query(
  String token, {
  int limit = 20,
  String? fullText,
  String? relatedTag,
  CompletionQueryKind kind = CompletionQueryKind.tag,
}) => CompletionQuery(
  fullText: fullText ?? token,
  cursorPosition: (fullText ?? token).length,
  token: token,
  replacementRange: TextReplacementRange(start: 0, end: token.length),
  existingTags: const {},
  limit: limit,
  locale: 'zh-CN',
  relatedTag: relatedTag,
  kind: kind,
);

CompletionCandidate _candidate(String tag, CompletionSourceKind source) =>
    CompletionCandidate(
      canonicalTag: tag,
      category: TagCategory.general,
      postCount: source == CompletionSourceKind.base ? 100 : 50,
      matchKind: CompletionMatchKind.englishPrefix,
      sources: {source},
    );

class _Source implements CompletionSource {
  _Source(this.values);
  final List<CompletionCandidate> values;
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async =>
      values;
}

class _RecordingRelatedSource implements CompletionSource {
  int searchCount = 0;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    searchCount++;
    return [_candidate('smile', CompletionSourceKind.cooccurrence)];
  }
}

class _ThrowingSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    throw StateError('offline database unavailable');
  }
}

class _QuerySource implements CompletionSource {
  final Completer<List<CompletionCandidate>> _old = Completer();

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) {
    if (query.token == 'old') return _old.future;
    return Future.value([_candidate('new_tag', CompletionSourceKind.base)]);
  }

  void completeOld() =>
      _old.complete([_candidate('old_tag', CompletionSourceKind.base)]);
}

class _Translations implements TranslationResolver {
  _Translations(this.values);
  final Map<String, String> values;
  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async => {
    for (final tag in canonicalTags)
      if (values[tag] case final value?) tag: value,
  };
}

class _CountingTranslations implements TranslationResolver {
  int resolveCount = 0;

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async {
    resolveCount++;
    return const {};
  }
}

class _RecordingTranslations implements TranslationResolver {
  final Completer<Map<String, String>> _completer = Completer();
  List<String> requested = const [];

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) {
    requested = canonicalTags;
    return _completer.future;
  }

  void complete(Map<String, String> values) => _completer.complete(values);
}

class _FakeDanbooru extends DanbooruCompletionSource {
  _FakeDanbooru() : super(cache: AutocompleteCacheDatabase());

  Completer<List<CompletionCandidate>>? _completer;
  Completer<List<CompletionCandidate>>? _relatedCompleter;
  int searchCount = 0;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) {
    searchCount++;
    _completer = Completer<List<CompletionCandidate>>();
    return _completer!.future;
  }

  void complete(List<CompletionCandidate> values) =>
      _completer!.complete(values);

  @override
  Future<List<CompletionCandidate>> relatedTags(String tag, {int limit = 20}) {
    _relatedCompleter = Completer<List<CompletionCandidate>>();
    return _relatedCompleter!.future;
  }

  void completeRelated(List<CompletionCandidate> values) =>
      _relatedCompleter!.complete(values);

  @override
  void cancelPending() {}
}
