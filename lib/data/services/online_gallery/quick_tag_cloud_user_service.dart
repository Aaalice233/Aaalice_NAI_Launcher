import 'dart:convert';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import 'quick_tag_cloud_parser.dart';

List<String> _savedStringList(Object? value) => value is List
    ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

class QuickTagCloudContentAccessSettings {
  const QuickTagCloudContentAccessSettings({
    this.allowNsfw = false,
    this.allowR18g = false,
  });

  final bool allowNsfw;
  final bool allowR18g;

  QuickTagCloudContentAccessSettings copyWith({
    bool? allowNsfw,
    bool? allowR18g,
  }) {
    final nextNsfw = allowNsfw ?? this.allowNsfw;
    return QuickTagCloudContentAccessSettings(
      allowNsfw: nextNsfw,
      allowR18g: nextNsfw ? allowR18g ?? this.allowR18g : false,
    );
  }

  Map<String, dynamic> toJson() => {
    'allowNsfw': allowNsfw,
    'allowR18g': allowR18g,
  };
}

class QuickTagCloudBrowsingFilters {
  const QuickTagCloudBrowsingFilters({
    this.codexId = 'suozhang',
    this.categoryPath = const [],
    this.updateFilterId = '',
    this.scope = 'catalog',
    this.mediaFilter = 'all',
  });

  final String codexId;
  final List<String> categoryPath;
  final String updateFilterId;
  final String scope;
  final String mediaFilter;

  factory QuickTagCloudBrowsingFilters.fromJson(Map<dynamic, dynamic> json) {
    final codexId = json['codexId']?.toString().trim() ?? '';
    return QuickTagCloudBrowsingFilters(
      codexId: codexId.isEmpty ? 'suozhang' : codexId,
      categoryPath: _savedStringList(json['categoryPath']),
      updateFilterId: json['updateFilterId']?.toString().trim() ?? '',
      scope: json['scope']?.toString() ?? 'catalog',
      mediaFilter: json['mediaFilter']?.toString() ?? 'all',
    );
  }

  Map<String, dynamic> toJson() => {
    'codexId': codexId,
    'categoryPath': categoryPath,
    'updateFilterId': updateFilterId,
    'scope': scope,
    'mediaFilter': mediaFilter,
  };
}

class QuickTagCloudSavedEntry {
  QuickTagCloudSavedEntry({
    required this.codexId,
    required this.codexType,
    required this.codexAliases,
    required this.codexTitle,
    required this.codexVersion,
    required this.codexAuthor,
    required this.codexNsfw,
    required this.assetBaseUrl,
    required this.assetPathMode,
    required this.sourceUrl,
    required this.hasOriginal,
    required this.media,
    required this.entry,
    required this.savedAt,
    List<QuickTagCloudContributor> contributors = const [],
    List<QuickTagCloudLink> links = const [],
    List<QuickTagCloudUpdateFilter> updateFilters = const [],
  }) : contributors = List.unmodifiable(contributors),
       links = List.unmodifiable(links),
       updateFilters = List.unmodifiable(updateFilters);

  final String codexId;
  final String codexType;
  final List<String> codexAliases;
  final String codexTitle;
  final String codexVersion;
  final String codexAuthor;
  final bool codexNsfw;
  final String assetBaseUrl;
  final String assetPathMode;
  final String sourceUrl;
  final bool hasOriginal;
  final QuickTagCloudMediaConfig media;
  final QuickTagCloudEntry entry;
  final DateTime savedAt;
  final List<QuickTagCloudContributor> contributors;
  final List<QuickTagCloudLink> links;
  final List<QuickTagCloudUpdateFilter> updateFilters;

  String get stableKey => quickTagCloudEntryWorkId(codexId, entry.id);

  factory QuickTagCloudSavedEntry.fromLive({
    required QuickTagCloudCodexMeta meta,
    required QuickTagCloudCodex codex,
    required QuickTagCloudEntry entry,
    required QuickTagCloudMediaConfig media,
    DateTime? savedAt,
  }) {
    return QuickTagCloudSavedEntry(
      codexId: codex.id,
      codexType: codex.type,
      codexAliases: List.unmodifiable(codex.aliases),
      codexTitle: codex.title,
      codexVersion: codex.version,
      codexAuthor: codex.author,
      codexNsfw: codex.nsfw,
      assetBaseUrl: codex.assetBaseUrl,
      assetPathMode: codex.assetPathMode,
      sourceUrl: codex.sourceDataUrl.isNotEmpty
          ? codex.sourceDataUrl
          : codex.source,
      hasOriginal: codex.hasOriginal,
      media: media,
      entry: entry,
      savedAt: savedAt ?? DateTime.now(),
      contributors: meta.contributors,
      links: meta.links,
      updateFilters: meta.updateFilters,
    );
  }

  QuickTagCloudCodexMeta get meta => QuickTagCloudCodexMeta(
    id: codexId,
    type: codexType,
    aliases: codexAliases,
    title: codexTitle,
    version: codexVersion,
    author: codexAuthor,
    nsfw: codexNsfw,
    assetBaseUrl: assetBaseUrl,
    assetPathMode: assetPathMode,
    source: sourceUrl,
    hasOriginal: hasOriginal,
    contributors: contributors,
    links: links,
    updateFilters: updateFilters,
  );

  QuickTagCloudCodex get codex => QuickTagCloudCodex(
    id: codexId,
    type: codexType,
    title: codexTitle,
    version: codexVersion,
    author: codexAuthor,
    nsfw: codexNsfw,
    assetBaseUrl: assetBaseUrl,
    assetPathMode: assetPathMode,
    dataUrl: '',
    sourceDataUrl: sourceUrl,
    fallbackDataUrl: '',
    source: sourceUrl,
    aliases: codexAliases,
    hasOriginal: hasOriginal,
    entries: [entry],
    entryCount: 1,
    imagedCount: entry.hasImage ? 1 : 0,
    tree: const [],
    loadSource: QuickTagCloudCodexLoadSource.canonical,
    metadata: meta,
    mediaOverride: media,
  );

  Map<String, dynamic> toJson() => {
    'codexId': codexId,
    'codexType': codexType,
    'codexAliases': codexAliases,
    'codexTitle': codexTitle,
    'codexVersion': codexVersion,
    'codexAuthor': codexAuthor,
    'codexNsfw': codexNsfw,
    'assetBaseUrl': assetBaseUrl,
    'assetPathMode': assetPathMode,
    'sourceUrl': sourceUrl,
    'hasOriginal': hasOriginal,
    'media': {
      'baseUrl': media.baseUrl,
      'bucket': media.bucket,
      'imagePrefix': media.imagePrefix,
      'originalPrefix': media.originalPrefix,
      'localFallback': media.localFallback,
    },
    'contributors': [
      for (final contributor in contributors)
        {'name': contributor.name, 'role': contributor.role},
    ],
    'links': [
      for (final link in links) {'label': link.label, 'url': link.url},
    ],
    'updateFilters': [
      for (final filter in updateFilters)
        {'id': filter.id, 'label': filter.label, 'latest': filter.latest},
    ],
    'entry': _entrySnapshotJson(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  Map<String, dynamic> _entrySnapshotJson() => {
    ...entry.raw,
    'id': entry.id,
    'title': entry.title,
    'path': entry.path,
    'tags': entry.tags,
    'negative': entry.negative,
    'note': entry.note,
    'author': entry.author,
    'credit': entry.credit,
    'rating': entry.rating,
    'isNew': entry.isNew,
    'updateBatches': entry.updateBatches,
    'characterPrompts': [
      for (final prompt in entry.characterPrompts)
        {
          'label': prompt.label,
          'prompt': prompt.prompt,
          'negative': prompt.negative,
        },
    ],
    'images': [
      for (final image in entry.images)
        {
          ...image.raw,
          'path': image.path,
          'original': image.original,
          '_hasOriginal': image.hasOriginal,
          'rawTag': image.rawTag,
          'width': image.dimensions.width,
          'height': image.dimensions.height,
        },
    ],
    'image': entry.image,
    'original': entry.images.isNotEmpty && entry.images.first.hasOriginal
        ? entry.original
        : '',
    'assetRev': entry.assetRev,
    'width': entry.dimensions.width,
    'height': entry.dimensions.height,
    'rawTag': entry.rawTag,
    'assetCodexId': entry.assetCodexId,
  };

  factory QuickTagCloudSavedEntry.fromJson(Map<String, dynamic> json) {
    final codexId = json['codexId']?.toString() ?? '';
    final rawEntry = json['entry'];
    if (codexId.isEmpty || rawEntry is! Map) {
      throw const FormatException('Invalid saved QuickTagCloud entry');
    }
    final entry = QuickTagCloudParser.normalizeEntry(rawEntry, codexId, 0);
    final rawContributors = json['contributors'];
    final rawLinks = json['links'];
    final rawUpdateFilters = json['updateFilters'];
    final rawMedia = json['media'];
    return QuickTagCloudSavedEntry(
      codexId: codexId,
      codexType: json['codexType']?.toString() ?? 'codex',
      codexAliases: _savedStringList(json['codexAliases']),
      codexTitle: json['codexTitle']?.toString() ?? codexId,
      codexVersion: json['codexVersion']?.toString() ?? '',
      codexAuthor: json['codexAuthor']?.toString() ?? '',
      codexNsfw: json['codexNsfw'] == true,
      assetBaseUrl: json['assetBaseUrl']?.toString() ?? '',
      assetPathMode: json['assetPathMode']?.toString() ?? 'codex',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      hasOriginal: json['hasOriginal'] == true,
      media: rawMedia is Map
          ? QuickTagCloudParser.parseMedia(rawMedia)
          : const QuickTagCloudMediaConfig(),
      entry: entry,
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      contributors: rawContributors is List
          ? rawContributors
                .whereType<Map>()
                .map(
                  (item) => QuickTagCloudContributor(
                    name: item['name']?.toString() ?? '',
                    role: item['role']?.toString() ?? '',
                  ),
                )
                .where((item) => item.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      links: rawLinks is List
          ? rawLinks
                .whereType<Map>()
                .map(
                  (item) => QuickTagCloudLink(
                    label: item['label']?.toString() ?? '',
                    url: item['url']?.toString() ?? '',
                  ),
                )
                .where((item) => item.url.isNotEmpty)
                .toList(growable: false)
          : const [],
      updateFilters: rawUpdateFilters is List
          ? rawUpdateFilters
                .whereType<Map>()
                .map(
                  (item) => QuickTagCloudUpdateFilter(
                    id: item['id']?.toString() ?? '',
                    label: item['label']?.toString() ?? '',
                    latest: item['latest'] == true,
                  ),
                )
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

/// Keeps user-owned data separate from the revocable upstream data cache.
class QuickTagCloudUserService {
  QuickTagCloudUserService(this._storage);

  static const int maxRecentEntries = 100;

  final LocalStorageService _storage;
  bool _initialized = false;
  final Map<String, QuickTagCloudSavedEntry> _favorites = {};
  final List<QuickTagCloudSavedEntry> _recent = [];
  Future<void> _writeTail = Future<void>.value();
  QuickTagCloudContentAccessSettings _contentAccess =
      const QuickTagCloudContentAccessSettings();
  QuickTagCloudBrowsingFilters _browsingFilters =
      const QuickTagCloudBrowsingFilters();

  Set<String> get favoriteKeys => Set.unmodifiable(_favorites.keys);
  List<QuickTagCloudSavedEntry> get favorites =>
      List.unmodifiable(_favorites.values.toList().reversed);
  List<QuickTagCloudSavedEntry> get recent => List.unmodifiable(_recent);
  QuickTagCloudContentAccessSettings get contentAccess => _contentAccess;
  QuickTagCloudBrowsingFilters get browsingFilters => _browsingFilters;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    _decodeSavedEntries(
      _storage.getSetting<String>(StorageKeys.quickTagCloudFavoritesV1),
      onEntry: (entry) => _favorites[entry.stableKey] = entry,
    );
    _decodeSavedEntries(
      _storage.getSetting<String>(StorageKeys.quickTagCloudRecentV1),
      onEntry: _recent.add,
    );
    final rawAccess = _storage.getSetting<String>(
      StorageKeys.quickTagCloudContentAccessV1,
    );
    if (rawAccess != null) {
      try {
        final decoded = jsonDecode(rawAccess);
        if (decoded is Map) {
          final allowNsfw = decoded['allowNsfw'] == true;
          _contentAccess = QuickTagCloudContentAccessSettings(
            allowNsfw: allowNsfw,
            allowR18g: allowNsfw && decoded['allowR18g'] == true,
          );
        }
      } catch (error) {
        AppLogger.w(
          'Ignored invalid QuickTagCloud content access settings: $error',
          'QuickTagCloud',
        );
      }
    }
    final rawFilters = _storage.getSetting<String>(
      StorageKeys.quickTagCloudBrowsingFiltersV1,
    );
    if (rawFilters != null) {
      try {
        final decoded = jsonDecode(rawFilters);
        if (decoded is Map) {
          _browsingFilters = QuickTagCloudBrowsingFilters.fromJson(decoded);
        }
      } catch (error) {
        AppLogger.w(
          'Ignored invalid QuickTagCloud browsing filters: $error',
          'QuickTagCloud',
        );
      }
    }
  }

  bool isFavorite(String stableKey) => _favorites.containsKey(stableKey);

  Future<bool> toggleFavorite(QuickTagCloudSavedEntry entry) async {
    await ensureInitialized();
    return _runSerialized(() async {
      final key = entry.stableKey;
      final next = Map<String, QuickTagCloudSavedEntry>.of(_favorites);
      final favorited = !next.containsKey(key);
      if (favorited) {
        next[key] = QuickTagCloudSavedEntry.fromLive(
          meta: entry.meta,
          codex: entry.codex,
          entry: entry.entry,
          media: entry.media,
        );
      } else {
        next.remove(key);
      }
      await _persistFavorites(next.values);
      _favorites
        ..clear()
        ..addAll(next);
      return favorited;
    });
  }

  Future<void> recordViewed(QuickTagCloudSavedEntry entry) async {
    await ensureInitialized();
    return _runSerialized(() async {
      final saved = QuickTagCloudSavedEntry.fromLive(
        meta: entry.meta,
        codex: entry.codex,
        entry: entry.entry,
        media: entry.media,
      );
      final next = [
        saved,
        ..._recent.where((item) => item.stableKey != entry.stableKey),
      ].take(maxRecentEntries).toList(growable: false);
      await _storage.setSetting(
        StorageKeys.quickTagCloudRecentV1,
        jsonEncode(next.map((item) => item.toJson()).toList()),
      );
      _recent
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> setBrowsingFilters(QuickTagCloudBrowsingFilters filters) async {
    await ensureInitialized();
    await _runSerialized(() async {
      await _storage.setSetting(
        StorageKeys.quickTagCloudBrowsingFiltersV1,
        jsonEncode(filters.toJson()),
      );
      _browsingFilters = filters;
    });
  }

  Future<void> setContentAccess(
    QuickTagCloudContentAccessSettings settings,
  ) async {
    await ensureInitialized();
    return _runSerialized(() async {
      final next = settings.allowNsfw
          ? settings
          : const QuickTagCloudContentAccessSettings();
      await _storage.setSetting(
        StorageKeys.quickTagCloudContentAccessV1,
        jsonEncode(next.toJson()),
      );
      _contentAccess = next;
    });
  }

  void _decodeSavedEntries(
    String? encoded, {
    required void Function(QuickTagCloudSavedEntry entry) onEntry,
  }) {
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;
      for (final raw in decoded) {
        if (raw is! Map) continue;
        try {
          onEntry(
            QuickTagCloudSavedEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        } catch (error) {
          AppLogger.w(
            'Ignored invalid saved QuickTagCloud entry: $error',
            'QuickTagCloud',
          );
        }
      }
    } catch (error) {
      AppLogger.w(
        'Ignored invalid QuickTagCloud saved data: $error',
        'QuickTagCloud',
      );
    }
  }

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    // The caller still receives [result]'s error; only the internal tail is
    // recovered so one failed disk write cannot block every later write.
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _persistFavorites(Iterable<QuickTagCloudSavedEntry> entries) =>
      _storage.setSetting(
        StorageKeys.quickTagCloudFavoritesV1,
        jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      );
}
