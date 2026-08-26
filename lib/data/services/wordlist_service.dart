import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/prompt/official_wordlist.dart';
import '../models/prompt/wordlist_entry.dart';

part 'wordlist_service.g.dart';

enum WordlistType {
  v4('characterPrompts', 'wordlists_v4.csv'),
  legacy('legacyAnime', 'wordlists_legacy.csv'),
  furry('furryV3', 'wordlists_furry.csv');

  const WordlistType(this.generatorId, this.fileName);

  final String generatorId;
  final String fileName;

  @Deprecated('Use officialWordlistAssetPath')
  String get assetPath => officialWordlistAssetPath;
}

/// Loads the source-locked NovelAI random wordlists without normalizing,
/// deduplicating, or reordering their records.
class WordlistService {
  WordlistService({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final Map<WordlistType, OfficialWordlist> _officialCache = {};
  final Map<WordlistType, List<WordlistEntry>> _compatibilityCache = {};
  final Map<WordlistType, Map<String, List<WordlistEntry>>> _variableIndex = {};
  final Map<WordlistType, Map<String, List<WordlistEntry>>> _categoryIndex = {};

  OfficialWordlistData? _data;
  Future<OfficialWordlistData>? _loadingFuture;
  var _cacheEpoch = 0;

  bool get isInitialized => _data != null;
  OfficialWordlistData? get data => _data;

  Future<void> initialize({bool loadAll = false}) async {
    if (loadAll) {
      await loadAllWordlists();
    } else {
      await loadWordlist(WordlistType.v4);
    }
  }

  Future<void> loadAllWordlists() async {
    final data = await _loadData();
    for (final type in WordlistType.values) {
      _cacheType(type, data);
    }
  }

  Future<void> loadWordlist(WordlistType type) async {
    if (_officialCache.containsKey(type)) return;
    _cacheType(type, await _loadData());
  }

  Future<OfficialWordlist> getOfficialWordlist(WordlistType type) async {
    await loadWordlist(type);
    return _officialCache[type]!;
  }

  OfficialWordlist? getLoadedOfficialWordlist(WordlistType type) =>
      _officialCache[type];

  Future<OfficialWordlistData> _loadData() async {
    final cached = _data;
    if (cached != null) return cached;
    final epoch = _cacheEpoch;
    final future = _loadingFuture ??= _readAsset();
    try {
      final loaded = await future;
      if (epoch != _cacheEpoch) {
        throw StateError('Official wordlist load was invalidated');
      }
      _data = loaded;
      return loaded;
    } finally {
      if (identical(_loadingFuture, future)) _loadingFuture = null;
    }
  }

  Future<OfficialWordlistData> _readAsset() async {
    final content = await _assetBundle.loadString(officialWordlistAssetPath);
    return compute(_parseOfficialWordlist, content);
  }

  void _cacheType(WordlistType type, OfficialWordlistData data) {
    final official = data.generatorsById[type.generatorId];
    if (official == null) {
      throw FormatException(
        'Official wordlist generator is missing: ${type.generatorId}',
      );
    }
    _officialCache[type] = official;
    final compatibilityEntries = <WordlistEntry>[];
    final variableIndex = <String, List<WordlistEntry>>{};
    final categoryIndex = <String, List<WordlistEntry>>{};
    for (final group in official.groups) {
      final groupEntries = <WordlistEntry>[];
      for (final entry in group.entries) {
        final isCharacterPrompt = type == WordlistType.v4;
        final compatibilityEntry = WordlistEntry(
          variable: group.id,
          category: group.semantic,
          tag: entry.text,
          weight: entry.weight,
          require: entry.stringFieldValues(isCharacterPrompt ? 3 : 2),
          exclude: isCharacterPrompt ? entry.stringFieldValues(4) : const [],
          extra: isCharacterPrompt ? entry.stringFieldValues(2) : const [],
        );
        compatibilityEntries.add(compatibilityEntry);
        groupEntries.add(compatibilityEntry);
        categoryIndex
            .putIfAbsent(group.semantic, () => [])
            .add(compatibilityEntry);
      }
      variableIndex[group.id] = List.unmodifiable(groupEntries);
    }
    _compatibilityCache[type] = List.unmodifiable(compatibilityEntries);
    _variableIndex[type] = Map.unmodifiable(variableIndex);
    _categoryIndex[type] = {
      for (final entry in categoryIndex.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  List<WordlistEntry> getAllEntries(WordlistType type) =>
      _compatibilityCache[type] ?? const [];

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
  ) => getEntriesByVariable(
    type,
    variable,
  ).where((entry) => entry.category == category).toList(growable: false);

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
      _cacheEpoch++;
      _data = null;
      _loadingFuture = null;
      _officialCache.clear();
      _compatibilityCache.clear();
      _variableIndex.clear();
      _categoryIndex.clear();
      return;
    }
    _officialCache.remove(type);
    _compatibilityCache.remove(type);
    _variableIndex.remove(type);
    _categoryIndex.remove(type);
  }

  Future<void> refresh([WordlistType? type]) async {
    clearCache(type);
    if (type == null) {
      await loadAllWordlists();
    } else {
      await loadWordlist(type);
    }
  }
}

OfficialWordlistData _parseOfficialWordlist(String content) {
  return OfficialWordlistData.fromJson(
    jsonDecode(content) as Map<String, dynamic>,
  );
}

@Riverpod(keepAlive: true)
WordlistService wordlistService(Ref ref) => WordlistService();

final officialWordlistDataProvider = FutureProvider<OfficialWordlistData>((
  ref,
) async {
  final service = ref.watch(wordlistServiceProvider);
  await service.loadAllWordlists();
  return service.data!;
});
