import 'package:path/path.dart' as p;

import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import '../services/vibe_library_storage_service.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class VibeLibraryCloudSyncAdapter extends ValidatingCloudSyncDataAdapter
    implements CloudSyncConflictCopyAdapter {
  VibeLibraryCloudSyncAdapter(this._storage);

  final VibeLibraryStorageService _storage;

  @override
  String get id => 'vibe-library';

  @override
  Set<String> get allowedKinds => const {'category', 'entry'};

  @override
  PortableSyncRecord copyForConflict(
    PortableSyncRecord source, {
    required String newPortableId,
  }) {
    if (source.kind != 'entry' || source.resource == null) {
      final categoryId = newPortableId.startsWith('category:')
          ? newPortableId.substring('category:'.length)
          : newPortableId;
      return PortableSyncRecord(
        adapterId: id,
        id: 'category:$categoryId',
        kind: source.kind,
        data: {...source.data, 'categoryId': categoryId},
      );
    }
    final extension = p.extension(source.data['fileName']! as String);
    final entryId = newPortableId.startsWith('entry:')
        ? newPortableId.substring('entry:'.length)
        : newPortableId;
    return PortableSyncRecord(
      adapterId: id,
      id: 'entry:$entryId',
      kind: source.kind,
      data: {
        ...source.data,
        'entryId': entryId,
        'fileName': '$entryId$extension',
      },
      resource: PortableSyncResource(
        relativePath: 'vibe/$entryId/original$extension',
        length: source.resource!.length,
        mediaType: source.resource!.mediaType,
        openRead: source.resource!.openRead,
      ),
    );
  }

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    for (final category in await _storage.getAllCategories()) {
      yield PortableSyncRecord(
        adapterId: id,
        id: 'category:${category.id}',
        kind: 'category',
        data: {
          'categoryId': category.id,
          'name': category.name,
          'parentId': category.parentId,
          'sortOrder': category.sortOrder,
          'createdAt': category.createdAt.toUtc().toIso8601String(),
        },
      );
    }
    for (final entry in await _storage.getAllEntries()) {
      final path = entry.filePath;
      if (path == null || path.isEmpty) continue;
      final length = await _storage.portableFileLength(path);
      final extension = p.extension(path).toLowerCase();
      yield PortableSyncRecord(
        adapterId: id,
        id: 'entry:${entry.id}',
        kind: 'entry',
        data: {
          'entryId': entry.id,
          'name': entry.name,
          'categoryId': entry.categoryId,
          'tags': entry.tags,
          'isFavorite': entry.isFavorite,
          'usedCount': entry.usedCount,
          'lastUsedAt': entry.lastUsedAt?.toUtc().toIso8601String(),
          'createdAt': entry.createdAt.toUtc().toIso8601String(),
          'fileName': '${entry.id}$extension',
        },
        resource: PortableSyncResource(
          relativePath: 'vibe/${entry.id}/original$extension',
          length: length,
          mediaType: 'application/json',
          openRead: () => _storage.openPortableFile(path),
        ),
      );
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) return;
    final data = record.data;
    if (data['name'] is! String ||
        data['createdAt'] is! String ||
        DateTime.tryParse(data['createdAt']! as String) == null) {
      throw CloudSyncPreflightException('Invalid Vibe record ${record.id}');
    }
    if (record.kind == 'category') {
      if (data['categoryId'] is! String || data['sortOrder'] is! int) {
        throw const CloudSyncPreflightException('Invalid Vibe category');
      }
      return;
    }
    final fileName = data['fileName'];
    final extension = fileName is String
        ? p.extension(fileName).toLowerCase()
        : '';
    if (data['entryId'] is! String ||
        data['tags'] is! List ||
        !(data['tags']! as List).every((value) => value is String) ||
        data['isFavorite'] is! bool ||
        data['usedCount'] is! int ||
        record.resource == null ||
        !const {'.naiv4vibe', '.naiv4vibebundle'}.contains(extension) ||
        record.resource!.relativePath.toLowerCase().contains('thumbnail') ||
        record.resource!.relativePath.toLowerCase().contains('cache')) {
      throw const CloudSyncPreflightException('Invalid Vibe entry');
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records.where((value) => value.kind == 'category')) {
      final categoryId =
          (record.data['categoryId'] ?? record.id.split(':').last) as String;
      if (record.deleted) {
        await _storage.deleteCategory(categoryId);
      } else {
        await _storage.saveCategory(
          VibeLibraryCategory(
            id: categoryId,
            name: record.data['name']! as String,
            parentId: record.data['parentId'] as String?,
            sortOrder: record.data['sortOrder']! as int,
            createdAt: DateTime.parse(
              record.data['createdAt']! as String,
            ).toUtc(),
          ),
        );
      }
    }
    for (final record in records.where((value) => value.kind == 'entry')) {
      final entryId =
          (record.data['entryId'] ?? record.id.split(':').last) as String;
      if (record.deleted) {
        await _storage.deleteEntry(entryId);
        continue;
      }
      String? path;
      try {
        path = await _storage.importPortableFile(
          record.resource!.openRead(),
          fileName: record.data['fileName']! as String,
        );
        final references = p.extension(path).toLowerCase() == '.naiv4vibebundle'
            ? await _storage.extractPortableBundle(path)
            : [
                await _storage.loadPortableVibe(path),
              ].whereType<VibeReference>().toList();
        if (references.isEmpty) {
          throw const FormatException('Empty portable Vibe document');
        }
        final first = references.first.normalizedForLibraryStorage();
        var entry =
            VibeLibraryEntry.fromVibeReference(
              name: record.data['name']! as String,
              vibeData: first,
              categoryId: record.data['categoryId'] as String?,
              tags: (record.data['tags']! as List).cast<String>(),
              filePath: path,
              isFavorite: record.data['isFavorite']! as bool,
            ).copyWith(
              id: entryId,
              usedCount: record.data['usedCount']! as int,
              lastUsedAt: _date(record.data['lastUsedAt']),
              createdAt: DateTime.parse(
                record.data['createdAt']! as String,
              ).toUtc(),
            );
        if (references.length > 1) {
          entry = entry.copyWith(
            bundleId: p.basenameWithoutExtension(path),
            bundledVibeNames: references
                .map((value) => value.displayName)
                .toList(),
            bundledVibeEncodings: references
                .map((value) => value.vibeEncoding)
                .toList(),
            bundledVibeStrengths: references
                .map((value) => value.strength)
                .toList(),
            bundledVibeInfoExtracted: references
                .map((value) => value.infoExtracted)
                .toList(),
            bundledVibeEncodingModels: references
                .map((value) => value.encodingModel)
                .toList(),
          );
        }
        await _storage.commitPortableEntry(entry);
        path = null;
      } catch (_) {
        if (path != null) await _storage.discardPortableFile(path);
        rethrow;
      }
    }
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toUtc() : null;
}
