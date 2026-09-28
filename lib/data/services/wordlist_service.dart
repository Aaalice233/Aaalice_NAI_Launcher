import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/prompt/official_wordlist.dart';

part 'wordlist_service.g.dart';

enum WordlistType {
  v4('characterPrompts', 'wordlists_v4.csv'),
  legacy('legacyAnime', 'wordlists_legacy.csv'),
  furry('furryV3', 'wordlists_furry.csv');

  const WordlistType(this.generatorId, this.fileName);

  final String generatorId;
  final String fileName;
}

/// Loads the source-locked NovelAI random wordlists without normalizing,
/// deduplicating, or reordering their records.
class WordlistService {
  WordlistService({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final Map<WordlistType, OfficialWordlist> _officialCache = {};

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
  }

  void clearCache([WordlistType? type]) {
    if (type == null) {
      _cacheEpoch++;
      _data = null;
      _loadingFuture = null;
      _officialCache.clear();
      return;
    }
    _officialCache.remove(type);
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
