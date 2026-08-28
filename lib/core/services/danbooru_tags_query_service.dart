import 'dart:async';

import '../../data/models/tag/local_tag.dart';
import '../database/datasources/danbooru_tag_data_source.dart';
import '../database/datasources/translation_data_source.dart';
import '../utils/tag_normalizer.dart';
import 'danbooru_tags_protocol.dart';

class DanbooruTagsQueryService {
  DanbooruTagsQueryService({
    required DanbooruTagDataSource tagDataSource,
    TranslationDataSource? translationDataSource,
  }) : _tagDataSource = tagDataSource,
       _translationDataSource = translationDataSource;

  static final _chinesePattern = RegExp(r'[\u4e00-\u9fa5]');
  static const _debounceDelay = Duration(milliseconds: 300);

  final DanbooruTagDataSource _tagDataSource;
  final TranslationDataSource? _translationDataSource;
  final Map<String, LocalTag> _hotDataCache = {};
  final Map<String, _PendingQuery<LocalTag?>> _pendingGets = {};
  final Map<String, _PendingQuery<List<LocalTag>>> _pendingSearches = {};

  Future<void> loadHotData() async {
    final records = await _tagDataSource.getByNames(danbooruHotKeys.toList());
    if (records.isEmpty) return;
    final translations = _translationDataSource == null
        ? <String, String>{}
        : await _translationDataSource.queryBatch(
            records.map((record) => record.tag).toList(),
          );
    for (final record in records) {
      final tag = _toLocalTag(
        record,
        translations[record.tag.toLowerCase().trim()],
      );
      _hotDataCache[tag.tag] = tag;
    }
  }

  Future<LocalTag?> get(String key) {
    final normalized = TagNormalizer.normalize(key);
    final cached = _hotDataCache[normalized];
    if (cached != null) return Future.value(cached);
    return _debounceShared(_pendingGets, normalized, () async {
      final record = await _tagDataSource.getByName(normalized);
      if (record == null) return null;
      final translation = await _translationDataSource?.query(normalized);
      return _toLocalTag(record, translation);
    });
  }

  Future<List<LocalTag>> search(String query, {int? category, int limit = 20}) {
    final key = '$query\u0000${category ?? -1}\u0000$limit';
    return _debounceShared(
      _pendingSearches,
      key,
      () => _chinesePattern.hasMatch(query)
          ? _searchByChinese(query, category: category, limit: limit)
          : _searchByName(query, category: category, limit: limit),
    );
  }

  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    final records = await _tagDataSource.getHotTags(
      limit: limit,
      category: category,
    );
    if (records.isEmpty) return [];
    final translations = _translationDataSource == null
        ? <String, String>{}
        : await _translationDataSource.queryBatch(
            records.map((record) => record.tag).toList(),
          );
    return records
        .map(
          (record) => _toLocalTag(
            record,
            translations[record.tag.toLowerCase().trim()],
          ),
        )
        .toList();
  }

  Future<List<LocalTag>> _searchByName(
    String query, {
    int? category,
    required int limit,
  }) async {
    final records = await _tagDataSource.search(
      query,
      limit: limit,
      category: category,
    );
    if (records.isEmpty) return [];
    final translations = _translationDataSource == null
        ? <String, String>{}
        : await _translationDataSource.queryBatch(
            records.map((record) => record.tag).toList(),
          );
    return records
        .map(
          (record) => _toLocalTag(
            record,
            translations[record.tag.toLowerCase().trim()],
          ),
        )
        .toList();
  }

  Future<List<LocalTag>> _searchByChinese(
    String query, {
    int? category,
    required int limit,
  }) async {
    final translations = _translationDataSource;
    if (translations == null) return [];
    final matches = await translations.search(
      query,
      limit: limit * 2,
      matchTag: false,
      matchTranslation: true,
    );
    final records = await _tagDataSource.getByNames(
      matches.map((match) => match.tag).toList(),
    );
    final byTag = {
      for (final record in records) record.tag.toLowerCase().trim(): record,
    };
    final seen = <String>{};
    final result = <LocalTag>[];
    for (final match in matches) {
      final normalized = match.tag.toLowerCase().trim();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      final record = byTag[normalized];
      final effectiveCategory = record?.category ?? match.category;
      if (category != null && effectiveCategory != category) continue;
      result.add(
        LocalTag(
          tag: record?.tag ?? normalized,
          category: effectiveCategory,
          count: record?.postCount ?? match.count,
          translation: match.translation,
        ),
      );
      if (result.length >= limit) break;
    }
    return result;
  }

  LocalTag _toLocalTag(DanbooruTagRecord record, String? translation) =>
      LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
        translation: translation,
      );

  Future<T> _debounceShared<T>(
    Map<String, _PendingQuery<T>> pendingQueries,
    String key,
    Future<T> Function() query,
  ) {
    final pending = pendingQueries.putIfAbsent(key, _PendingQuery<T>.new);
    final completer = Completer<T>();
    pending.completers.add(completer);
    pending.timer?.cancel();
    pending.timer = Timer(_debounceDelay, () async {
      final active = pendingQueries.remove(key);
      if (!identical(active, pending)) return;
      try {
        final result = await query();
        for (final waiter in pending.completers) {
          if (!waiter.isCompleted) waiter.complete(result);
        }
      } catch (error, stack) {
        for (final waiter in pending.completers) {
          if (!waiter.isCompleted) waiter.completeError(error, stack);
        }
      }
    });
    return completer.future;
  }

  void clear() {
    _hotDataCache.clear();
    for (final pending in _pendingGets.values) {
      pending.timer?.cancel();
      for (final completer in pending.completers) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }
    for (final pending in _pendingSearches.values) {
      pending.timer?.cancel();
      for (final completer in pending.completers) {
        if (!completer.isCompleted) completer.complete(<LocalTag>[]);
      }
    }
    _pendingGets.clear();
    _pendingSearches.clear();
  }
}

class _PendingQuery<T> {
  Timer? timer;
  final List<Completer<T>> completers = [];
}
