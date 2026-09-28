import 'package:dio/dio.dart';

import '../../../../core/online_gallery/gallery_tag_query.dart';
import '../../../services/online_gallery/quick_tag_cloud_access.dart';
import '../../../services/online_gallery/quick_tag_cloud_user_service.dart';
import 'quick_tag_cloud_gallery_query.dart';
import 'quick_tag_cloud_gallery_repository.dart';

class QuickTagCloudQueryEngine {
  QuickTagCloudQueryEngine({
    required QuickTagCloudGalleryRepository repository,
    required QuickTagCloudUserService userService,
  }) : _repository = repository,
       _userService = userService;

  final QuickTagCloudGalleryRepository _repository;
  final QuickTagCloudUserService _userService;
  final Map<String, List<QuickTagCloudGalleryRecord>> _matchingRecordSets = {};
  final Map<String, String> _searchHaystacks = {};
  int _observedRepositoryRevision = -1;

  void clearCaches() {
    _matchingRecordSets.clear();
    _searchHaystacks.clear();
    _observedRepositoryRevision = _repository.cacheRevision;
  }

  Future<List<QuickTagCloudGalleryRecord>> matchingRecords(
    QuickTagCloudGalleryQuery query, {
    required String searchText,
    required Set<String> selectedRatings,
    CancelToken? cancelToken,
    bool sortByRelevance = true,
  }) async {
    _synchronizeRevision();
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    await _userService.ensureInitialized();
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    final saved = query.favoritesOnly
        ? _userService.favorites
        : query.scope == QuickTagCloudBrowseScope.recent
        ? _userService.recent
        : null;
    final List<QuickTagCloudGalleryRecord> records;
    if (saved == null) {
      records = await _repository.loadCatalogRecords(
        query,
        cancelToken: cancelToken,
      );
    } else {
      records = <QuickTagCloudGalleryRecord>[];
      for (var index = 0; index < saved.length; index++) {
        if (index > 0 && index % 256 == 0) {
          await Future<void>.delayed(Duration.zero);
          QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
        }
        final item = saved[index];
        records.add(
          QuickTagCloudGalleryRecord(
            item.meta,
            item.codex,
            item.entry,
            item.media,
          ),
        );
      }
    }
    _synchronizeRevision();
    final cacheRevision = _repository.cacheRevision;
    final normalizedSearch = searchText.trim().toLowerCase();
    final ratingsKey = (selectedRatings.toList()..sort()).join();
    final matchingCacheKey = saved == null
        ? '${_repository.currentCatalog?.release ?? ''}|${query.stableKey}|$ratingsKey|$normalizedSearch|sort:$sortByRelevance'
        : null;
    final cachedMatches = matchingCacheKey == null
        ? null
        : _matchingRecordSets[matchingCacheKey];
    if (cachedMatches != null) {
      QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
      return cachedMatches;
    }
    final localTagPlan = GalleryTagQueryPlanner.plan(
      GalleryTagQueryParser.parse(normalizedSearch),
      serverTagLimit: maxGallerySearchTags,
    );
    final terms = localTagPlan.query.ordinaryClauses
        .map((clause) => clause.value)
        .toList(growable: false);
    final filtered = <QuickTagCloudGalleryRecord>[];
    final cacheSearchHaystacks = records.length <= 5000;
    for (var index = 0; index < records.length; index++) {
      if (index % 256 == 0) {
        QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
        if (index > 0) await Future<void>.delayed(Duration.zero);
        QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
      }
      final record = records[index];
      if (!_isAccessible(record, query, selectedRatings)) continue;
      if (!_matchesCodex(record, query.codexId)) continue;
      if (!_matchesCategory(record.entry.path, query.categoryPath)) continue;
      if (query.scope == QuickTagCloudBrowseScope.latest &&
          !_matchesLatest(record)) {
        continue;
      }
      if (query.updateFilterId.isNotEmpty &&
          !_matchesUpdateFilter(record, query.updateFilterId)) {
        continue;
      }
      if (query.mediaFilter == QuickTagCloudMediaFilter.withImages &&
          !record.entry.hasImage) {
        continue;
      }
      if (query.mediaFilter == QuickTagCloudMediaFilter.withoutImages &&
          record.entry.hasImage) {
        continue;
      }
      if (terms.length == 1) {
        final haystack = _searchHaystack(record, cache: cacheSearchHaystacks);
        if (!haystack.contains(terms.single)) continue;
      } else if (terms.length > 1 &&
          !localTagPlan.matchesNormalizedTags(record.normalizedTags)) {
        continue;
      }
      filtered.add(record);
    }
    QuickTagCloudGalleryRepository.throwIfCancelled(cancelToken);
    if (sortByRelevance && terms.isNotEmpty) {
      filtered.sort((left, right) {
        final leftScore = _searchScore(left, normalizedSearch);
        final rightScore = _searchScore(right, normalizedSearch);
        return rightScore.compareTo(leftScore);
      });
    }
    final result = List<QuickTagCloudGalleryRecord>.unmodifiable(filtered);
    if (matchingCacheKey != null &&
        cacheRevision == _repository.cacheRevision) {
      _matchingRecordSets.remove(matchingCacheKey);
      _matchingRecordSets[matchingCacheKey] = result;
      while (_matchingRecordSets.length > 4) {
        _matchingRecordSets.remove(_matchingRecordSets.keys.first);
      }
    }
    return result;
  }

  void _synchronizeRevision() {
    if (_observedRepositoryRevision == _repository.cacheRevision) return;
    _matchingRecordSets.clear();
    _searchHaystacks.clear();
    _observedRepositoryRevision = _repository.cacheRevision;
  }

  bool _isAccessible(
    QuickTagCloudGalleryRecord record,
    QuickTagCloudGalleryQuery query,
    Set<String> selectedRatings,
  ) {
    if (QuickTagCloudAccess.isCodexLocked(
      record.codex,
      allowNsfw: query.allowNsfw,
    )) {
      return false;
    }
    if (QuickTagCloudAccess.isEntryAccessBlocked(
      record.entry,
      allowNsfw: query.allowNsfw,
      allowR18g: query.allowR18g,
    )) {
      return false;
    }
    return QuickTagCloudAccess.matchesGalleryRatings(
      record.entry,
      codex: record.codex,
      selectedRatings: selectedRatings,
    );
  }

  bool _matchesCodex(QuickTagCloudGalleryRecord record, String selectedId) {
    if (selectedId == 'all' || record.codex.id == selectedId) return true;
    if (record.codex.aliases.contains(selectedId)) return true;
    final selected = _repository.currentCatalog?.findCodex(selectedId);
    if (selected == null) return false;
    final savedIdentities = {record.codex.id, ...record.codex.aliases};
    return selected.aliases.any(savedIdentities.contains);
  }

  bool _matchesCategory(List<String> path, List<String> selected) {
    if (selected.isEmpty) return true;
    if (path.length < selected.length) return false;
    for (var index = 0; index < selected.length; index++) {
      if (path[index] != selected[index]) return false;
    }
    return true;
  }

  bool _matchesLatest(QuickTagCloudGalleryRecord record) {
    if (record.entry.isNew) return true;
    final latestIds = record.meta.updateFilters
        .where((filter) => filter.latest)
        .map((filter) => filter.id)
        .toSet();
    return record.entry.updateBatches.any(latestIds.contains);
  }

  bool _matchesUpdateFilter(
    QuickTagCloudGalleryRecord record,
    String filterId,
  ) =>
      record.entry.updateBatches.contains(filterId) ||
      filterId == 'latest' && _matchesLatest(record);

  String _searchHaystack(
    QuickTagCloudGalleryRecord record, {
    required bool cache,
  }) {
    String build() => [
      record.entry.title,
      record.entry.tags,
      record.entry.negative,
      record.entry.note,
      record.entry.rating,
      record.entry.rawTag,
      record.entry.path.join(' '),
      record.entry.updateBatches.join(' '),
      record.entry.characterPrompts
          .map(
            (character) =>
                '${character.label} ${character.prompt} ${character.negative}',
          )
          .join(' '),
      record.entry.images
          .map(
            (image) => [
              image.rawTag,
              _rawSearchValue(image.raw, 'author'),
              _rawSearchValue(image.raw, 'credit'),
              _rawSearchValue(image.raw, 'rawTags'),
            ].join(' '),
          )
          .join(' '),
      _rawSearchValue(record.entry.raw, 'author'),
      _rawSearchValue(record.entry.raw, 'credit'),
      _rawSearchValue(record.entry.raw, 'rawTags'),
      _rawSearchValue(record.entry.raw, 'type'),
      record.codex.title,
      record.codex.author,
      record.codex.source,
      record.codex.type,
      record.codex.version,
      record.codex.aliases.join(' '),
      record.meta.contributors
          .map((item) => '${item.name} ${item.role}')
          .join(' '),
      record.meta.links.map((item) => '${item.label} ${item.url}').join(' '),
    ].join('\n').toLowerCase();

    return cache ? _searchHaystacks.putIfAbsent(record.workId, build) : build();
  }

  String _rawSearchValue(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value is Iterable) return value.join(' ');
    return value?.toString() ?? '';
  }

  int _searchScore(QuickTagCloudGalleryRecord record, String query) {
    final title = record.entry.title.toLowerCase();
    if (title == query) return 4;
    if (title.startsWith(query)) return 3;
    if (title.contains(query)) return 2;
    return 1;
  }
}
