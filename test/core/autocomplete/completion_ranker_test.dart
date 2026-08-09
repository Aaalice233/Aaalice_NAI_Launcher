import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/completion_ranker.dart';

void main() {
  const query = CompletionQuery(
    fullText: 'blue',
    cursorPosition: 4,
    token: 'blue',
    replacementRange: TextReplacementRange(start: 0, end: 4),
    existingTags: {'blue_hair'},
    limit: 20,
    locale: 'zh-CN',
  );

  test(
    'deduplicates by canonical tag and keeps the base record authoritative',
    () {
      final results = CompletionRanker.mergeAndSort([
        const CompletionCandidate(
          canonicalTag: 'blue_eyes',
          category: TagCategory.general,
          postCount: 10,
          matchKind: CompletionMatchKind.fullText,
          sources: {CompletionSourceKind.danbooruApi},
        ),
        const CompletionCandidate(
          canonicalTag: 'blue_eyes',
          category: TagCategory.meta,
          postCount: 500000,
          aliases: ['aqua_eyes'],
          matchedAlias: 'aqua_eyes',
          matchKind: CompletionMatchKind.aliasPrefix,
          sources: {CompletionSourceKind.base},
        ),
        const CompletionCandidate(
          canonicalTag: 'blue_eyes',
          category: TagCategory.character,
          postCount: 1,
          translation: '蓝眼睛',
          matchKind: CompletionMatchKind.chineseExact,
          sources: {CompletionSourceKind.zhDictionary},
        ),
      ], query: query);

      expect(results, hasLength(1));
      expect(results.single.category, TagCategory.meta);
      expect(results.single.postCount, 500000);
      expect(results.single.translation, '蓝眼睛');
      expect(results.single.aliases, ['aqua_eyes']);
      expect(
        results.single.sources,
        containsAll([
          CompletionSourceKind.base,
          CompletionSourceKind.danbooruApi,
          CompletionSourceKind.zhDictionary,
        ]),
      );
    },
  );

  test(
    'uses fixed match priority then popularity and moves existing tags last',
    () {
      final results = CompletionRanker.mergeAndSort([
        _candidate('blue_hair', CompletionMatchKind.englishExact, 999999),
        _candidate('blue_eyes', CompletionMatchKind.englishPrefix, 100),
        _candidate('blue_archive', CompletionMatchKind.aliasExact, 900000),
        _candidate('azure_eyes', CompletionMatchKind.chineseExact, 999999),
        _candidate('blue_bow', CompletionMatchKind.englishPrefix, 500),
      ], query: query);

      expect(results.map((candidate) => candidate.canonicalTag), [
        'blue_bow',
        'blue_eyes',
        'blue_archive',
        'azure_eyes',
        'blue_hair',
      ]);
      expect(results.last.isExisting, isTrue);
    },
  );
}

CompletionCandidate _candidate(
  String tag,
  CompletionMatchKind kind,
  int count,
) => CompletionCandidate(
  canonicalTag: tag,
  category: TagCategory.general,
  postCount: count,
  matchKind: kind,
  sources: const {CompletionSourceKind.base},
);
