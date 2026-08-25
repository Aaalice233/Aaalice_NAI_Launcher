import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/prompt_tag_utils.dart';
import '../models/online_gallery/gallery_item.dart';
import '../models/online_gallery/gallery_source.dart';
import '../models/online_gallery/online_gallery_favorite_record.dart';
import '../services/online_gallery/quick_tag_cloud_access.dart';
import '../services/online_gallery/quick_tag_cloud_media_resolver.dart';
import '../services/online_gallery/quick_tag_cloud_user_service.dart';

class OnlineGalleryFavoriteQuery {
  const OnlineGalleryFavoriteQuery({
    this.sourceId,
    this.searchText = '',
    this.ratings = const {},
    this.blacklistTags = const {},
    this.codexId,
    this.categoryPath = const [],
    this.mediaFilter = 'all',
    this.offset = 0,
    this.limit = 50,
  }) : assert(offset >= 0),
       assert(limit > 0);

  final GallerySourceId? sourceId;
  final String searchText;
  final Set<String> ratings;
  final Set<String> blacklistTags;
  final String? codexId;
  final List<String> categoryPath;
  final String mediaFilter;
  final int offset;
  final int limit;
}

class OnlineGalleryFavoritePage {
  const OnlineGalleryFavoritePage({
    required this.records,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<OnlineGalleryFavoriteRecord> records;
  final int total;
  final int offset;
  final int limit;

  List<GalleryDetail> get details =>
      records.map((record) => record.detail).toList(growable: false);
  List<GalleryItem> get items =>
      records.map((record) => record.item).toList(growable: false);
  bool get hasMore => offset + records.length < total;
  int? get nextOffset => hasMore ? offset + records.length : null;
}

/// Hive-backed source-neutral local favorites store.
///
/// Every favorite is persisted under its own stable key. The in-memory map is
/// only updated after Hive confirms the write, so failed writes never appear
/// successful to callers.
class OnlineGalleryLocalFavoritesRepository {
  OnlineGalleryLocalFavoritesRepository({
    required Box<dynamic> box,
    required LocalStorageService legacyStorage,
  }) : _box = box,
       _legacyStorage = legacyStorage;

  static const String quickTagCloudMigrationMarkerKey =
      '__migration_quick_tag_cloud_favorites_v1__';

  final Box<dynamic> _box;
  final LocalStorageService _legacyStorage;
  final Map<String, OnlineGalleryFavoriteRecord> _records = {};
  final List<String> _sortedKeys = [];
  final Map<GallerySourceId, List<String>> _sortedKeysBySource = {};
  Future<void>? _initialization;
  Future<void> _writeTail = Future<void>.value();

  bool get isInitialized => _initialization != null && _recordsLoaded;
  bool _recordsLoaded = false;
  int get count => _records.length;
  Set<String> get stableKeys => Set.unmodifiable(_records.keys);

  Future<void> ensureInitialized() =>
      _initialization ??= _initialize().catchError((Object error) {
        _initialization = null;
        throw error;
      });

  Future<void> _initialize() async {
    await _migrateQuickTagCloudFavorites();
    final loaded = <String, OnlineGalleryFavoriteRecord>{};
    for (final entry in _box.toMap().entries) {
      final key = entry.key.toString();
      if (key == quickTagCloudMigrationMarkerKey) continue;
      try {
        if (entry.value is! Map) {
          throw const FormatException('Favorite record is not a map');
        }
        final record = OnlineGalleryFavoriteRecord.fromMap(
          entry.value as Map<dynamic, dynamic>,
        );
        if (record.stableKey != key) {
          throw const FormatException('Hive key does not match stable key');
        }
        loaded[key] = record;
      } catch (error, stack) {
        AppLogger.w(
          'Ignored damaged online gallery favorite "$key": $error\n$stack',
          'OnlineGalleryFavorites',
        );
      }
    }
    _records
      ..clear()
      ..addAll(loaded);
    _rebuildIndexes();
    _recordsLoaded = true;
  }

  bool contains(String stableKey) => _records.containsKey(stableKey);

  OnlineGalleryFavoriteRecord? getByStableKey(String stableKey) =>
      _records[stableKey];

  OnlineGalleryFavoritePage query(OnlineGalleryFavoriteQuery query) {
    if (!_recordsLoaded) {
      throw StateError('Online gallery favorites are not initialized');
    }
    if (query.offset < 0) {
      throw RangeError.range(query.offset, 0, null, 'offset');
    }
    if (query.limit <= 0) {
      throw RangeError.range(query.limit, 1, null, 'limit');
    }
    final ratings = query.ratings.map((value) => value.toLowerCase()).toSet();
    final blacklist = query.blacklistTags
        .map(_normalizeTag)
        .where((value) => value.isNotEmpty)
        .toSet();
    final terms = query.searchText
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final candidateKeys = query.sourceId == null
        ? _sortedKeys
        : (_sortedKeysBySource[query.sourceId!] ?? const <String>[]);
    final matches = candidateKeys
        .map((key) => _records[key]!)
        .where((record) {
          if (query.sourceId != null && record.sourceId != query.sourceId) {
            return false;
          }
          if (query.codexId != null &&
              query.codexId != 'all' &&
              record.detail.rawSourceMetadata['codexId'] != query.codexId) {
            return false;
          }
          if (query.categoryPath.isNotEmpty) {
            final recordPath = record.detail.categoryPath;
            if (recordPath.length < query.categoryPath.length) return false;
            for (var index = 0; index < query.categoryPath.length; index++) {
              if (recordPath[index] != query.categoryPath[index]) {
                return false;
              }
            }
          }
          final hasMedia = record.detail.media.any(
            (media) =>
                media.previewUrl.isNotEmpty || media.displayUrl.isNotEmpty,
          );
          if (query.mediaFilter == 'withImages' && !hasMedia) return false;
          if (query.mediaFilter == 'withoutImages' && hasMedia) {
            return false;
          }
          final rating = record.item.rating?.toLowerCase() ?? '';
          if (ratings.isNotEmpty && !ratings.contains(rating)) return false;
          if (blacklist.isNotEmpty &&
              _recordTags(record).any(blacklist.contains)) {
            return false;
          }
          if (terms.isNotEmpty) {
            final haystack = _searchHaystack(record);
            if (!terms.every(haystack.contains)) return false;
          }
          return true;
        })
        .toList(growable: false);
    final start = query.offset.clamp(0, matches.length);
    final end = (start + query.limit).clamp(start, matches.length);
    return OnlineGalleryFavoritePage(
      records: List.unmodifiable(matches.sublist(start, end)),
      total: matches.length,
      offset: query.offset,
      limit: query.limit,
    );
  }

  Future<bool> toggle(GalleryDetail detail, {DateTime? savedAt}) async {
    await ensureInitialized();
    return _runSerialized(() async {
      final key = detail.item.stableKey;
      if (_records.containsKey(key)) {
        await _box.delete(key);
        _removeFromMemory(key);
        return false;
      }
      final record = OnlineGalleryFavoriteRecord.fromDetail(
        detail,
        savedAt: savedAt,
      );
      await _box.put(key, record.toMap());
      _upsertInMemory(record);
      return true;
    });
  }

  Future<void> upsert(GalleryDetail detail, {DateTime? savedAt}) async {
    await ensureInitialized();
    await _runSerialized(() async {
      final record = OnlineGalleryFavoriteRecord.fromDetail(
        detail,
        savedAt: savedAt,
      );
      await _box.put(record.stableKey, record.toMap());
      _upsertInMemory(record);
    });
  }

  Future<int> upsertAll(
    Iterable<GalleryDetail> details, {
    DateTime? savedAt,
  }) async {
    await ensureInitialized();
    return _runSerialized(() async {
      final records = <String, OnlineGalleryFavoriteRecord>{};
      var index = 0;
      final baseTime = (savedAt ?? DateTime.now()).toUtc();
      for (final detail in details) {
        final record = OnlineGalleryFavoriteRecord.fromDetail(
          detail,
          savedAt: baseTime.add(Duration(microseconds: index++)),
        );
        records[record.stableKey] = record;
      }
      if (records.isEmpty) return 0;
      await _box.putAll({
        for (final entry in records.entries) entry.key: entry.value.toMap(),
      });
      _records.addAll(records);
      _rebuildIndexes();
      return records.length;
    });
  }

  Future<bool> remove(String stableKey) async {
    await ensureInitialized();
    return _runSerialized(() async {
      if (!_records.containsKey(stableKey)) return false;
      await _box.delete(stableKey);
      _removeFromMemory(stableKey);
      return true;
    });
  }

  void _rebuildIndexes() {
    _sortedKeys
      ..clear()
      ..addAll(_records.keys)
      ..sort(_compareRecordKeys);
    _sortedKeysBySource.clear();
    for (final key in _sortedKeys) {
      final sourceId = _records[key]!.sourceId;
      (_sortedKeysBySource[sourceId] ??= <String>[]).add(key);
    }
  }

  void _upsertInMemory(OnlineGalleryFavoriteRecord record) {
    _removeFromMemory(record.stableKey);
    _records[record.stableKey] = record;
    _insertSorted(_sortedKeys, record.stableKey);
    _insertSorted(
      _sortedKeysBySource.putIfAbsent(record.sourceId, () => <String>[]),
      record.stableKey,
    );
  }

  void _removeFromMemory(String stableKey) {
    final previous = _records.remove(stableKey);
    if (previous == null) return;
    _sortedKeys.remove(stableKey);
    final sourceKeys = _sortedKeysBySource[previous.sourceId];
    sourceKeys?.remove(stableKey);
    if (sourceKeys?.isEmpty == true) {
      _sortedKeysBySource.remove(previous.sourceId);
    }
  }

  void _insertSorted(List<String> keys, String key) {
    var low = 0;
    var high = keys.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_compareRecordKeys(key, keys[middle]) < 0) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    keys.insert(low, key);
  }

  int _compareRecordKeys(String leftKey, String rightKey) {
    final left = _records[leftKey]!;
    final right = _records[rightKey]!;
    final savedOrder = right.savedAt.compareTo(left.savedAt);
    return savedOrder != 0 ? savedOrder : leftKey.compareTo(rightKey);
  }

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _migrateQuickTagCloudFavorites() async {
    if (_box.get(quickTagCloudMigrationMarkerKey) == true) {
      if (_legacyStorage.getSetting<String>(
            StorageKeys.quickTagCloudFavoritesV1,
          ) !=
          null) {
        await _legacyStorage.deleteSetting(
          StorageKeys.quickTagCloudFavoritesV1,
        );
      }
      return;
    }

    final encoded = _legacyStorage.getSetting<String>(
      StorageKeys.quickTagCloudFavoritesV1,
    );
    final migrated = <String, OnlineGalleryFavoriteRecord>{};
    var sourceIsValid = true;
    if (encoded != null && encoded.isNotEmpty) {
      Object? decoded;
      var decodedSuccessfully = true;
      try {
        decoded = jsonDecode(encoded);
      } catch (error, stack) {
        sourceIsValid = false;
        decodedSuccessfully = false;
        AppLogger.w(
          'Ignored damaged QuickTagCloud favorites migration source: '
              '$error\n$stack',
          'OnlineGalleryFavorites',
        );
      }
      if (decoded is! List) {
        sourceIsValid = false;
        if (decodedSuccessfully) {
          AppLogger.w(
            'Ignored QuickTagCloud favorites migration source that is not a '
                'list',
            'OnlineGalleryFavorites',
          );
        }
      } else {
        for (var index = 0; index < decoded.length; index++) {
          try {
            final value = decoded[index];
            if (value is! Map) {
              throw const FormatException('Legacy favorite is not a map');
            }
            final saved = QuickTagCloudSavedEntry.fromJson(
              Map<String, dynamic>.from(value),
            );
            final record = _quickTagCloudRecord(saved);
            // Round-trip validation prevents deleting the only legacy copy
            // when a newly added snapshot field cannot be restored.
            final validated = OnlineGalleryFavoriteRecord.fromMap(
              record.toMap(),
            );
            migrated[validated.stableKey] = validated;
          } catch (error, stack) {
            sourceIsValid = false;
            AppLogger.w(
              'Ignored damaged QuickTagCloud favorite at index $index: '
                  '$error\n$stack',
              'OnlineGalleryFavorites',
            );
          }
        }
      }
    }

    if (!sourceIsValid) return;

    final writes = <String, dynamic>{};
    for (final entry in migrated.entries) {
      final current = _box.get(entry.key);
      if (current is Map) {
        try {
          OnlineGalleryFavoriteRecord.fromMap(current);
          continue;
        } catch (_) {
          // A valid legacy snapshot is preferable to a damaged current entry.
        }
      }
      writes[entry.key] = entry.value.toMap();
    }
    if (writes.isNotEmpty) await _box.putAll(writes);
    for (final key in migrated.keys) {
      final stored = _box.get(key);
      if (stored is! Map ||
          OnlineGalleryFavoriteRecord.fromMap(stored).stableKey != key) {
        throw StateError(
          'QuickTagCloud favorite migration verification failed',
        );
      }
    }
    await _box.put(quickTagCloudMigrationMarkerKey, true);
    if (encoded != null) {
      await _legacyStorage.deleteSetting(StorageKeys.quickTagCloudFavoritesV1);
    }
  }
}

Set<String> _recordTags(OnlineGalleryFavoriteRecord record) {
  final item = record.item;
  final values = <String>{
    ...item.tags,
    ...item.generalTags,
    ...item.characterTags,
    ...item.copyrightTags,
    ...item.artistTags,
    ...item.metaTags,
    ...record.detail.rawTags,
  };
  return values.map(_normalizeTag).where((value) => value.isNotEmpty).toSet();
}

String _normalizeTag(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

String _searchHaystack(OnlineGalleryFavoriteRecord record) {
  final item = record.item;
  final detail = record.detail;
  return [
    item.title,
    item.author,
    item.description,
    item.aiType,
    item.source,
    item.rating,
    item.tags.join(' '),
    item.tagStringGeneral,
    item.tagStringCharacter,
    item.tagStringCopyright,
    item.tagStringArtist,
    item.tagStringMeta,
    detail.prompt,
    detail.negativePrompt,
    detail.description,
    detail.categoryPath.join(' '),
    detail.note,
    detail.rawTags.join(' '),
    detail.characterPrompts
        .map(
          (value) => '${value.label} ${value.prompt} ${value.negativePrompt}',
        )
        .join(' '),
    detail.contributors.map((value) => '${value.name} ${value.role}').join(' '),
  ].whereType<String>().join('\n').toLowerCase().replaceAll('_', ' ');
}

OnlineGalleryFavoriteRecord _quickTagCloudRecord(
  QuickTagCloudSavedEntry saved,
) {
  final codex = saved.codex;
  final entry = saved.entry;
  final workId = saved.stableKey;
  final resolver = QuickTagCloudMediaResolver(media: saved.media);
  final media = <GalleryMedia>[];
  for (var index = 0; index < entry.images.length; index++) {
    final image = entry.images[index];
    final preview = resolver.imageItemUrl(
      QuickTagCloudMediaKind.image,
      entry,
      image,
      codex,
    );
    final hasOriginal = codex.hasOriginal && image.hasOriginal;
    final download = hasOriginal
        ? resolver.imageItemUrl(
            QuickTagCloudMediaKind.original,
            entry,
            image,
            codex,
          )
        : preview;
    final dimensions = image.dimensions.isKnown
        ? image.dimensions
        : entry.dimensions;
    final extension = p
        .extension(Uri.tryParse(download)?.path ?? '')
        .replaceFirst('.', '')
        .toLowerCase();
    media.add(
      GalleryMedia(
        id: '$workId:$index',
        previewUrl: preview,
        displayUrl: preview,
        downloadUrl: download,
        width: dimensions.width,
        height: dimensions.height,
        extension: extension.isEmpty ? null : extension,
        rawMetadata: image.rawTag.isEmpty ? entry.rawTag : image.rawTag,
        prompt: entry.tags,
        negativePrompt: entry.negative,
        metadata: {...image.raw, 'hasOriginal': hasOriginal},
      ),
    );
  }
  final cover = media.isEmpty
      ? const GalleryMedia(id: 'no-image')
      : media.first;
  final attribution = <String>[];
  for (final value in [entry.credit, entry.author, codex.author]) {
    final normalized = value.trim();
    if (normalized.isNotEmpty && !attribution.contains(normalized)) {
      attribution.add(normalized);
    }
  }
  final sourceUrl =
      <String>[
        ...saved.links.map((link) => link.url),
        codex.source,
        codex.sourceDataUrl,
      ].firstWhere((value) {
        final uri = Uri.tryParse(value);
        return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
      }, orElse: () => '');
  final metadata = <String, dynamic>{
    'codexId': codex.id,
    'codexTitle': codex.title,
    'codexVersion': codex.version,
    'codexAuthor': codex.author,
    'codexNsfw': codex.nsfw,
    'entryId': entry.id,
    'entryAuthor': entry.author,
    'entryCredit': entry.credit,
    'prompt': entry.tags,
    'negativePrompt': entry.negative,
    'note': entry.note,
    'categoryPath': entry.path,
    'rawTag': entry.rawTag,
    'entry': entry.raw,
  };
  final item = GalleryItem(
    id: _stableNumericId(workId),
    workId: workId,
    sourceId: GallerySourceId.quickTagCloud,
    site: GallerySourceId.quickTagCloud.key,
    title: entry.title,
    author: attribution.join(' · '),
    description: entry.note,
    createdAt: codex.version,
    source: sourceUrl,
    rating: QuickTagCloudAccess.galleryRating(entry, codex: codex),
    imageWidth: cover.width,
    imageHeight: cover.height,
    tagString: entry.tags,
    tags: PromptTagUtils.splitForDisplay(entry.tags),
    fileExt: cover.extension,
    fileUrl: cover.downloadUrl.isEmpty ? null : cover.downloadUrl,
    largeFileUrl: cover.displayUrl.isEmpty ? null : cover.displayUrl,
    previewFileUrl: cover.previewUrl.isEmpty ? null : cover.previewUrl,
    cover: cover,
    mediaCount: media.length,
    rawSourceMetadata: metadata,
  );
  return OnlineGalleryFavoriteRecord.fromDetail(
    GalleryDetail(
      item: item,
      media: List.unmodifiable(media),
      prompt: entry.tags,
      negativePrompt: entry.negative,
      description: entry.note,
      categoryPath: entry.path,
      note: entry.note,
      rawTags: entry.rawTag.isEmpty ? const [] : [entry.rawTag],
      characterPrompts: [
        for (final character in entry.characterPrompts)
          GalleryCharacterPrompt(
            label: character.label,
            prompt: character.prompt,
            negativePrompt: character.negative,
          ),
      ],
      contributors: [
        for (final contributor in saved.contributors)
          GalleryContributor(name: contributor.name, role: contributor.role),
      ],
      sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
      rawSourceMetadata: metadata,
    ),
    savedAt: saved.savedAt,
  );
}

int _stableNumericId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
