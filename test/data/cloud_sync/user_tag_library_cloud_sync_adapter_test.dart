import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/data/services/tag_library_io_service.dart';
import 'package:nai_launcher/data/services/tag_library_portable_thumbnail_store.dart';

void main() {
  test('exports tag entries without thumbnail image resources', () async {
    final storage = _FailingStorage(
      entries: jsonEncode([
        {'id': 'tag-1', 'name': 'Portrait', 'thumbnail': 'portrait.png'},
      ]),
      categories: '[]',
    );
    final io = _TrackingIo(_TrackingMutation());
    final records = await UserTagLibraryCloudSyncAdapter(
      storage,
      io,
    ).exportRecords().toList();

    expect(records, hasLength(1));
    expect(records.single.resource, isNull);
    expect(records.single.data, {
      'entry': {'id': 'tag-1', 'name': 'Portrait'},
    });
    expect(io.thumbnailReads, 0);
  });

  test('restoring tag metadata preserves the device-local thumbnail', () async {
    final storage = _FailingStorage(
      entries: jsonEncode([
        {'id': 'tag-1', 'name': 'Old', 'thumbnail': 'local.png'},
      ]),
      categories: '[]',
    )..failNextCategoryWrite = false;
    final io = _TrackingIo(_TrackingMutation());
    final adapter = UserTagLibraryCloudSyncAdapter(storage, io);

    await adapter.apply([
      PortableSyncRecord(
        adapterId: adapter.id,
        id: 'entry:tag-1',
        kind: 'entry',
        data: {
          'entry': {'id': 'tag-1', 'name': 'Updated'},
          'thumbnailExtension': '.png',
        },
        resource: PortableSyncResource(
          relativePath: 'tag-library/tag-1/thumbnail.png',
          length: 3,
          openRead: () => Stream.value([1, 2, 3]),
        ),
      ),
    ]);

    expect(jsonDecode(storage.entries), [
      {'id': 'tag-1', 'name': 'Updated', 'thumbnail': 'local.png'},
    ]);
    expect(io.stageCalls, 0);
  });

  test('metadata failure rolls back a tombstoned thumbnail', () async {
    final storage = _FailingStorage(
      entries: jsonEncode([
        {'id': 'old', 'name': 'Old', 'thumbnail': 'old.png'},
      ]),
      categories: '[]',
    );
    final mutation = _TrackingMutation();
    final io = _TrackingIo(mutation);
    final adapter = UserTagLibraryCloudSyncAdapter(storage, io);
    final tombstone = PortableSyncRecord(
      adapterId: adapter.id,
      id: 'entry:old',
      kind: 'entry',
      deleted: true,
    );

    await expectLater(adapter.apply([tombstone]), throwsStateError);

    expect(jsonDecode(storage.entries), hasLength(1));
    expect(mutation.rolledBack, isTrue);
    expect(mutation.committed, isFalse);
    expect(io.existingPath, 'old.png');
  });
}

class _FailingStorage extends LocalStorageService {
  _FailingStorage({required this.entries, required this.categories});

  String entries;
  String categories;
  bool failNextCategoryWrite = true;

  @override
  String? getTagLibraryEntriesJson() => entries;

  @override
  String? getTagLibraryCategoriesJson() => categories;

  @override
  Future<void> setTagLibraryEntriesJson(String json) async {
    entries = json;
  }

  @override
  Future<void> setTagLibraryCategoriesJson(String json) async {
    if (failNextCategoryWrite) {
      failNextCategoryWrite = false;
      throw StateError('injected JSON failure');
    }
    categories = json;
  }
}

class _TrackingIo extends TagLibraryIOService {
  _TrackingIo(this.mutation);

  final PortableThumbnailMutation mutation;
  String? existingPath;
  var stageCalls = 0;
  var thumbnailReads = 0;

  @override
  Future<int?> thumbnailLength(String? filePath) async {
    thumbnailReads++;
    return 3;
  }

  @override
  Future<PortableThumbnailMutation> stagePortableThumbnail(
    String entryId, {
    required String? extension,
    required Stream<List<int>>? bytes,
    String? existingPath,
  }) async {
    stageCalls++;
    this.existingPath = existingPath;
    return mutation;
  }
}

class _TrackingMutation extends PortableThumbnailMutation {
  _TrackingMutation() : super(null, null, {});

  bool committed = false;
  bool rolledBack = false;

  @override
  Future<void> commit() async {
    committed = true;
  }

  @override
  Future<void> rollback() async {
    rolledBack = true;
  }
}
