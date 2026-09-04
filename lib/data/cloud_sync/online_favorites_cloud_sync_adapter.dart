import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/online_gallery/online_gallery_favorite_record.dart';
import '../repositories/online_gallery_local_favorites_repository.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class OnlineFavoritesCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  OnlineFavoritesCloudSyncAdapter(this._repository);

  final OnlineGalleryLocalFavoritesRepository _repository;

  @override
  String get id => 'online-gallery-favorites';

  @override
  Set<String> get allowedKinds => const {'favorite'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    await _repository.ensureInitialized();
    final stableKeys = _repository.stableKeys.toList()..sort();
    for (final stableKey in stableKeys) {
      final favorite = _repository.getByStableKey(stableKey)!;
      final sanitized = _compact(favorite.toMap());
      yield PortableSyncRecord(
        adapterId: id,
        id: _portableId(favorite.stableKey),
        kind: 'favorite',
        data: {'record': sanitized, 'stableKey': favorite.stableKey},
      );
    }
  }

  @override
  Map<String, Object?> tombstoneData(PortableSyncRecord record) => {
    'stableKey': record.data['stableKey'],
  };

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) {
      final stableKey = record.data['stableKey'];
      if (stableKey is! String || record.id != _portableId(stableKey)) {
        throw const CloudSyncPreflightException('Invalid favorite tombstone');
      }
      return;
    }
    final raw = record.data['record'];
    if (raw is! Map || record.data['stableKey'] is! String) {
      throw const CloudSyncPreflightException('Invalid online favorite');
    }
    final favorite = OnlineGalleryFavoriteRecord.fromMap(raw);
    if (favorite.stableKey != record.data['stableKey'] ||
        record.id != _portableId(favorite.stableKey)) {
      throw const CloudSyncPreflightException('Favorite identity mismatch');
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records) {
      final stableKey = record.data['stableKey'] as String?;
      if (record.deleted) {
        if (stableKey == null) {
          throw const CloudSyncPreflightException(
            'Favorite tombstone lacks stable key',
          );
        }
        await _repository.remove(stableKey);
      } else {
        final favorite = OnlineGalleryFavoriteRecord.fromMap(
          record.data['record']! as Map,
        );
        await _repository.upsert(favorite.detail, savedAt: favorite.savedAt);
      }
    }
  }

  String _portableId(String value) {
    return 'favorite-${sha256.convert(utf8.encode(value))}';
  }

  Map<String, dynamic> _compact(Map<String, dynamic> source) {
    final detail = Map<String, dynamic>.from(source['detail']! as Map);
    final item = Map<String, dynamic>.from(detail['item']! as Map);
    final cover = Map<String, dynamic>.from(item['cover']! as Map);
    final compactCover = _pick(cover, const {
      'id',
      'previewUrl',
      'displayUrl',
      'downloadUrl',
      'width',
      'height',
      'extension',
      'mimeType',
      'mediaType',
    });
    return {
      'version': source['version'],
      'stableKey': source['stableKey'],
      'sourceId': source['sourceId'],
      'sourceWorkId': source['sourceWorkId'],
      'savedAt': source['savedAt'],
      'detail': {
        'item': {
          ..._pick(item, const {
            'id',
            'workId',
            'sourceId',
            'site',
            'title',
            'author',
            'description',
            'aiType',
            'createdAt',
            'rating',
            'imageWidth',
            'imageHeight',
            'tags',
            'fileExt',
            'previewFileUrl',
            'sampleUrl',
            'sampleWidth',
            'sampleHeight',
            'mediaCount',
          }),
          'cover': compactCover,
        },
        // The source work ID is the durable recovery pointer. One compact
        // cover is enough for offline recognition; the remote detail can be
        // fetched again instead of duplicating every media response here.
        'media': [compactCover],
        'prompt': detail['prompt'],
        'negativePrompt': detail['negativePrompt'],
        'categoryPath': detail['categoryPath'],
        'note': detail['note'],
        'rawTags': detail['rawTags'],
        'characterPrompts': const <Object>[],
        'contributors': const <Object>[],
      },
    };
  }

  Map<String, dynamic> _pick(Map<String, dynamic> source, Set<String> keys) => {
    for (final key in keys)
      if (source.containsKey(key)) key: _sanitizeValue(key, source[key]),
  };

  Map<String, dynamic> _sanitize(Map<dynamic, dynamic> source) {
    final output = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (_secretKey.hasMatch(key)) continue;
      output[key] = _sanitizeValue(key, entry.value);
    }
    return output;
  }

  Object? _sanitizeValue(String key, Object? value) {
    if (value is Map) return _sanitize(value);
    if (value is List) {
      return value.map((item) => _sanitizeValue(key, item)).toList();
    }
    if (value is String && key.toLowerCase().contains('url')) {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          uri.hasQuery &&
          uri.queryParameters.keys.any((name) => _secretKey.hasMatch(name))) {
        return uri.replace(query: '').toString();
      }
    }
    return value;
  }

  static final RegExp _secretKey = RegExp(
    r'(token|password|passwd|api.?key|access.?key|secret|credential|authorization|cookie)',
    caseSensitive: false,
  );
}
