import 'dart:convert';

import '../../core/storage/local_storage_service.dart';
import '../services/tag_library_io_service.dart';
import '../services/tag_library_portable_thumbnail_store.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class UserTagLibraryCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  UserTagLibraryCloudSyncAdapter(this._storage, this._io);

  final LocalStorageService _storage;
  final TagLibraryIOService _io;

  @override
  String get id => 'user-tag-library';

  @override
  Set<String> get allowedKinds => const {'entry', 'category'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    for (final original in _decodeList(_storage.getTagLibraryEntriesJson())) {
      final entry = Map<String, dynamic>.from(original);
      entry.remove('thumbnail');
      yield PortableSyncRecord(
        adapterId: id,
        id: 'entry:${entry['id']}',
        kind: 'entry',
        data: {'entry': entry},
      );
    }
    for (final category in _decodeList(
      _storage.getTagLibraryCategoriesJson(),
    )) {
      yield PortableSyncRecord(
        adapterId: id,
        id: 'category:${category['id']}',
        kind: 'category',
        data: {'category': category},
      );
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) return;
    final object = record.data[record.kind];
    final stableId = record.id.substring(record.id.indexOf(':') + 1);
    if (object is! Map ||
        object['id'] is! String ||
        object['id'] != stableId ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,191}$').hasMatch(stableId)) {
      throw const CloudSyncPreflightException(
        'Invalid user tag library record',
      );
    }
    if (record.kind == 'entry' && object.containsKey('thumbnail')) {
      throw const CloudSyncPreflightException(
        'Local thumbnail path is not portable',
      );
    }
    final resource = record.resource;
    final extension = record.data['thumbnailExtension'];
    if (record.kind == 'category' && resource != null ||
        record.kind == 'entry' &&
            resource != null &&
            (extension is! String ||
                resource.relativePath !=
                    'tag-library/$stableId/thumbnail$extension')) {
      throw const CloudSyncPreflightException(
        'Invalid legacy tag thumbnail resource',
      );
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    final oldEntriesJson = _storage.getTagLibraryEntriesJson();
    final oldCategoriesJson = _storage.getTagLibraryCategoriesJson();
    final entries = {
      for (final item in _decodeList(oldEntriesJson))
        item['id'] as String: item,
    };
    final categories = {
      for (final item in _decodeList(oldCategoriesJson))
        item['id'] as String: item,
    };
    final mutations = <PortableThumbnailMutation>[];
    try {
      for (final record in records) {
        final target = record.kind == 'entry' ? entries : categories;
        final stableId = record.id.substring(record.id.indexOf(':') + 1);
        final existingThumbnail = record.kind == 'entry'
            ? (target[stableId]?['thumbnail'] as String?)
            : null;
        if (record.deleted) {
          if (record.kind == 'entry') {
            mutations.add(
              await _io.stagePortableThumbnail(
                stableId,
                extension: null,
                bytes: null,
                existingPath: existingThumbnail,
              ),
            );
          }
          target.remove(stableId);
          continue;
        }
        final value = Map<String, dynamic>.from(
          record.data[record.kind]! as Map,
        );
        if (record.kind == 'entry' && existingThumbnail != null) {
          value['thumbnail'] = existingThumbnail;
        }
        target[stableId] = value;
      }
      await _storage.setTagLibraryEntriesJson(
        jsonEncode(entries.values.toList()),
      );
      await _storage.setTagLibraryCategoriesJson(
        jsonEncode(categories.values.toList()),
      );
      for (final mutation in mutations) {
        await mutation.commit();
      }
    } catch (_) {
      try {
        await _restoreJson(oldEntriesJson, oldCategoriesJson);
      } finally {
        for (final mutation in mutations.reversed) {
          await mutation.rollback();
        }
      }
      rethrow;
    }
  }

  Future<void> _restoreJson(String? entries, String? categories) async {
    await _storage.setTagLibraryEntriesJson(entries ?? '[]');
    await _storage.setTagLibraryCategoriesJson(categories ?? '[]');
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Expected JSON list');
    return decoded
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }
}
