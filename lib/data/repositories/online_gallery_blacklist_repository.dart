import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../models/online_gallery/gallery_blacklist.dart';

class OnlineGalleryBlacklistRepository {
  OnlineGalleryBlacklistRepository(this._storage);

  final LocalStorageService _storage;

  GalleryBlacklistStore load() {
    final current = _decodeStore(
      _storage.getSetting<Object?>(StorageKeys.onlineGalleryBlacklistV2),
    );
    if (current != null) return current;

    final rollbackShadow = _decodeStore(
      _storage.getSetting<Object?>(
        StorageKeys.onlineGalleryBlacklistRollbackShadow,
      ),
    );
    if (rollbackShadow != null) return rollbackShadow;

    final local = _legacyTags(StorageKeys.onlineGalleryBlacklistTags);
    final remote = _legacyTags(StorageKeys.onlineGalleryRemoteBlacklistTags);
    final lastSyncMilliseconds = _storage.getSetting<int>(
      StorageKeys.onlineGalleryBlacklistLastSyncAt,
    );
    return GalleryBlacklistStore(
      revision: local.isEmpty && remote.isEmpty ? 0 : 1,
      desiredTags: immutableTagSet({...local, ...remote}),
      // Legacy cloud cache had no account identity. Keep it as migration
      // evidence so background sync cannot publish it into the wrong account.
      legacyUnscopedRules: List.unmodifiable(remote.toList()..sort()),
      legacyUnscopedLastSyncAt: lastSyncMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSyncMilliseconds),
    );
  }

  Future<void> save(GalleryBlacklistStore store) async {
    final encoded = jsonEncode(store.toJson());
    // V2 and its rollback shadow must commit together or the next launch could
    // expose a mutation that this process correctly reported as failed.
    await _storage.setSettings({
      StorageKeys.onlineGalleryBlacklistV2: encoded,
      StorageKeys.onlineGalleryBlacklistRollbackShadow: encoded,
      StorageKeys.onlineGalleryBlacklistTags: store.desiredTags.toList()
        ..sort(),
      StorageKeys.onlineGalleryRemoteBlacklistTags: const <String>[],
    });

    final readBack = _storage.getSetting<String>(
      StorageKeys.onlineGalleryBlacklistV2,
    );
    final shadowReadBack = _storage.getSetting<String>(
      StorageKeys.onlineGalleryBlacklistRollbackShadow,
    );
    if (readBack != encoded || shadowReadBack != encoded) {
      throw const FormatException('Blacklist V2 persistence read-back failed');
    }
  }

  GalleryBlacklistStore? _decodeStore(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final object = Map<String, dynamic>.from(decoded);
      if (!_isValidV2(object)) return null;
      return GalleryBlacklistStore.fromJson(object);
    } catch (_) {
      return null;
    }
  }

  bool _isValidV2(Map<String, dynamic> json) {
    final rawSnapshots = json['remoteSnapshots'];
    if (json['schemaVersion'] != GalleryBlacklistStore.currentSchemaVersion ||
        json['revision'] is! int ||
        !_isStringList(json['desiredTags']) ||
        !_isStringList(json['tombstones']) ||
        !_isStringList(json['pendingRemoteDeletions']) ||
        !_isStringList(json['legacyUnscopedRules']) ||
        rawSnapshots is! Map ||
        (json['legacyUnscopedLastSyncAt'] != null &&
            json['legacyUnscopedLastSyncAt'] is! int)) {
      return false;
    }

    for (final entry in rawSnapshots.entries) {
      final value = entry.value;
      if (entry.key is! String || value is! Map) return false;
      final snapshot = Map<String, dynamic>.from(value);
      if (snapshot['accountKey'] != entry.key ||
          !_isStringList(snapshot['rules']) ||
          snapshot['lastSyncAt'] is! int ||
          (snapshot['lastError'] != null && snapshot['lastError'] is! String)) {
        return false;
      }
    }
    return true;
  }

  bool _isStringList(Object? value) =>
      value is List && value.every((item) => item is String);

  Set<String> _legacyTags(String key) {
    final raw = _storage.getSetting<List<dynamic>>(
      key,
      defaultValue: const <dynamic>[],
    );
    return GalleryBlacklistTagNormalizer.normalizeAll(
      (raw ?? const []).whereType<String>(),
    );
  }
}

final onlineGalleryBlacklistRepositoryProvider =
    Provider<OnlineGalleryBlacklistRepository>((ref) {
      return OnlineGalleryBlacklistRepository(
        ref.read(localStorageServiceProvider),
      );
    });
