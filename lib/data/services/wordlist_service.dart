import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../datasources/local/random_tag_library_data_source.dart';
import '../models/prompt/wordlist_entry.dart';

part 'wordlist_service.g.dart';

/// Legacy model variants retained for persisted settings and external callers.
enum WordlistType {
  v4('wordlists_v4.csv'),
  legacy('wordlists_legacy.csv'),
  furry('wordlists_furry.csv');

  const WordlistType(this.fileName);

  final String fileName;

  @Deprecated('Bundled CSV wordlists were removed; use the catalog source')
  String get assetPath => 'assets/data/wordlists/$fileName';
}

/// Compatibility facade over the verified catalog-backed random library.
///
/// The former CSV assets are no longer distributed. Explicit legacy callers
/// still receive indexed [WordlistEntry] values without activating a parallel
/// data pipeline; model variants share data but retain their algorithm config.
class WordlistService {
  WordlistService(this._randomTagLibraryDataSource);

  final RandomTagLibraryDataSource _randomTagLibraryDataSource;
  final Map<WordlistType, List<WordlistEntry>> _cache = {};
  final Map<WordlistType, Map<String, List<WordlistEntry>>> _variableIndex = {};
  final Map<WordlistType, Map<String, List<WordlistEntry>>> _categoryIndex = {};
  final Map<WordlistType, Future<void>> _loading = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _loading.isNotEmpty;

  int getEntryCount(WordlistType type) => _cache[type]?.length ?? 0;

  Future<void> initialize({bool loadAll = false}) async {
    if (_isInitialized) return;
    await loadWordlist(WordlistType.v4);
    if (loadAll) {
      await Future.wait([
        loadWordlist(WordlistType.legacy),
        loadWordlist(WordlistType.furry),
      ]);
    }
    _isInitialized = true;
  }

  Future<void> loadWordlist(WordlistType type) {
    if (_cache.containsKey(type)) return Future.value();
    return _loading[type] ??= _load(type).whenComplete(() {
      _loading.remove(type);
    });
  }

  Future<void> _load(WordlistType type) async {
    final data = await _randomTagLibraryDataSource.loadData();
    final entries = <WordlistEntry>[
      for (final category in data.categories.entries)
        for (final tag in category.value)
          WordlistEntry(
            variable: _legacyVariableForCategory(category.key),
            category: category.key,
            tag: tag.tag,
            weight: tag.weight,
            require: tag.conditions ?? const [],
          ),
    ];
    final immutableEntries = List<WordlistEntry>.unmodifiable(entries);
    _cache[type] = immutableEntries;
    _buildIndices(type, immutableEntries);
  }

  String _legacyVariableForCategory(String category) {
    return switch (category) {
      'background' || 'scene' || 'style' || 'characterCount' => 'tk',
      _ => 'char',
    };
  }

  void _buildIndices(WordlistType type, List<WordlistEntry> entries) {
    final variableIndex = <String, List<WordlistEntry>>{};
    final categoryIndex = <String, List<WordlistEntry>>{};
    for (final entry in entries) {
      variableIndex.putIfAbsent(entry.variable, () => []).add(entry);
      categoryIndex.putIfAbsent(entry.category, () => []).add(entry);
    }
    _variableIndex[type] = {
      for (final entry in variableIndex.entries)
        entry.key: List.unmodifiable(entry.value),
    };
    _categoryIndex[type] = {
      for (final entry in categoryIndex.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  List<WordlistEntry> getAllEntries(WordlistType type) =>
      _cache[type] ?? const [];

  List<WordlistEntry> getEntriesByVariable(
    WordlistType type,
    String variable,
  ) => _variableIndex[type]?[variable] ?? const [];

  List<WordlistEntry> getEntriesByCategory(
    WordlistType type,
    String category,
  ) => _categoryIndex[type]?[category] ?? const [];

  List<String> getVariables(WordlistType type) =>
      _variableIndex[type]?.keys.toList(growable: false) ?? const [];

  List<String> getCategories(WordlistType type) =>
      _categoryIndex[type]?.keys.toList(growable: false) ?? const [];

  List<WordlistEntry> getEntriesByVariableAndCategory(
    WordlistType type,
    String variable,
    String category,
  ) {
    return getEntriesByVariable(
      type,
      variable,
    ).where((entry) => entry.category == category).toList(growable: false);
  }

  List<WordlistEntry> search(
    WordlistType type,
    String query, {
    int limit = 20,
  }) {
    if (query.trim().isEmpty || limit <= 0) return const [];
    final normalizedQuery = query.trim().toLowerCase();
    return getAllEntries(type)
        .where((entry) => entry.tag.toLowerCase().contains(normalizedQuery))
        .take(limit)
        .toList(growable: false);
  }

  WordlistEntry? weightedRandomSelect(
    List<WordlistEntry> entries,
    int Function() randomInt,
  ) {
    final eligible = entries.where((entry) => entry.weight > 0).toList();
    if (eligible.isEmpty) return null;
    final totalWeight = eligible.fold<int>(
      0,
      (total, entry) => total + entry.weight,
    );
    var target = randomInt().abs() % totalWeight;
    for (final entry in eligible) {
      if (target < entry.weight) return entry;
      target -= entry.weight;
    }
    throw StateError('Wordlist weighted selection exhausted unexpectedly');
  }

  void clearCache([WordlistType? type]) {
    if (type == null) {
      _cache.clear();
      _variableIndex.clear();
      _categoryIndex.clear();
      _isInitialized = false;
      return;
    }
    _cache.remove(type);
    _variableIndex.remove(type);
    _categoryIndex.remove(type);
  }

  Future<void> refresh([WordlistType? type]) async {
    clearCache(type);
    if (type == null) {
      await initialize(loadAll: true);
    } else {
      await loadWordlist(type);
    }
  }
}

@Riverpod(keepAlive: true)
WordlistService wordlistService(Ref ref) {
  return WordlistService(ref.watch(randomTagLibraryDataSourceProvider));
}
