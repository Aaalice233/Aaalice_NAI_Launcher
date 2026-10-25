import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/generation_history_box_storage.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/services/generation_history_storage_service.dart';

import '../../helpers/log_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late LazyBox<dynamic> historyBox;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'generation-history-storage-test-',
    );
    Hive.init(hiveDirectory.path);
    historyBox = await Hive.openLazyBox<dynamic>(StorageKeys.historyBox);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  Future<void> reopenLazily() async {
    await Hive.close();
    historyBox = await Hive.openLazyBox<dynamic>(StorageKeys.historyBox);
  }

  const orderKey = 'generation_history_v1_order';
  String recordKey(String id) => 'generation_history_v1_record_$id';

  Map<String, dynamic> rawRecord(int byte) => <String, dynamic>{
    'bytes': Uint8List.fromList([byte, byte + 1, byte + 2]),
    'width': 32,
    'height': 48,
    'createdAt': DateTime.utc(2026, 8, 26, 12, byte).toIso8601String(),
    'kind': GeneratedImageKind.completed.name,
    'metadata': null,
    'fixedTagUsageSnapshot': null,
    'preserveOriginalBytesOnSave': false,
    'filePath': '/images/$byte.png',
  };

  Future<List<String>> storedOrder() async =>
      ((await historyBox.get(orderKey)) as List).cast<String>();

  GeneratedImage image(String id, {int byte = 1}) {
    return GeneratedImage(
      id: id,
      bytes: Uint8List.fromList([byte, byte + 1, byte + 2]),
      width: 64,
      height: 96,
      createdAt: DateTime.utc(2026, 8, 26, 12, byte),
      filePath: '/images/$id.png',
      preserveOriginalBytesOnSave: true,
      fixedTagUsageSnapshot: const FixedTagUsageSnapshot(
        entries: [
          FixedTagUsageEntry(
            fixedTagId: 'fixed-a',
            name: 'A',
            content: 'masterpiece',
            weight: 1,
            renderedContent: 'masterpiece',
            position: FixedTagPosition.prefix,
            promptType: FixedTagPromptType.positive,
            order: 0,
          ),
        ],
      ),
    );
  }

  test(
    'persists records independently and restores their requested order',
    () async {
      final service = GenerationHistoryStorageService();
      final first = image('first', byte: 3);
      final second = image('second', byte: 7);

      await service.persistImages(
        changedImages: [first, second],
        order: [second.id, first.id],
      );
      await service.flush();

      final restored = await service.load();
      expect(restored.map((item) => item.id), ['second', 'first']);
      expect(restored.first.bytes, second.bytes);
      expect(restored.first.width, second.width);
      expect(restored.first.height, second.height);
      expect(restored.first.createdAt, second.createdAt);
      expect(restored.first.filePath, second.filePath);
      expect(restored.first.preserveOriginalBytesOnSave, isTrue);
      expect(
        restored.first.fixedTagUsageSnapshot?.entries.single.fixedTagId,
        'fixed-a',
      );
    },
  );

  test(
    'restores the file name suffix and defaults it for older records',
    () async {
      final service = GenerationHistoryStorageService();
      final source = image('masked');
      final suffixed = GeneratedImage(
        id: source.id,
        bytes: source.bytes,
        width: source.width,
        height: source.height,
        createdAt: source.createdAt,
        fileNameSuffix: '_masked',
      );
      await service.persistImages(changedImages: [suffixed], order: ['masked']);
      await service.flush();
      expect((await service.load()).single.fileNameSuffix, '_masked');

      final key = recordKey(suffixed.id);
      final record = Map<dynamic, dynamic>.from(
        await historyBox.get(key) as Map,
      )..remove('fileNameSuffix');
      await historyBox.put(key, record);
      expect((await service.load()).single.fileNameSuffix, isEmpty);
    },
  );

  test('comparison source is not persisted or restored with history', () async {
    final sourceBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 48)),
    );
    final comparisonSource = ImageComparisonSource.fromBytes(sourceBytes);
    final persisted = GeneratedImage(
      id: 'comparison',
      bytes: Uint8List.fromList([1, 2, 3]),
      width: 64,
      height: 96,
      comparisonSource: comparisonSource,
    );
    final service = GenerationHistoryStorageService();

    await service.persistImages(
      changedImages: [persisted],
      order: [persisted.id],
    );
    await service.flush();

    final raw = Map<dynamic, dynamic>.from(
      await historyBox.get('generation_history_v1_record_comparison') as Map,
    );
    expect(raw, isNot(contains('comparisonSource')));
    expect(raw, isNot(contains('comparisonSourceBytes')));

    final restored = await GenerationHistoryStorageService().load();
    expect(restored, hasLength(1));
    expect(restored.single.comparisonSource, isNull);
  });

  test('serializes overlapping writes and removes evicted records', () async {
    final service = GenerationHistoryStorageService();
    final first = image('first', byte: 1);
    final second = image('second', byte: 5);

    final initialWrite = service.persistImages(
      changedImages: [first],
      order: [first.id],
    );
    final replacementWrite = service.persistImages(
      changedImages: [second],
      order: [second.id],
    );
    await Future.wait([initialWrite, replacementWrite]);

    expect((await service.load()).map((item) => item.id), ['second']);
    expect(
      historyBox.keys.whereType<String>(),
      isNot(contains('generation_history_v1_record_first')),
    );
  });

  test(
    'load removes only orphaned keys, keeping unreadable indexed records',
    () async {
      await historyBox.put('generation_history_v1_order', [
        'valid',
        'missing',
        'invalid',
      ]);
      await historyBox.put('generation_history_v1_record_valid', {
        'bytes': Uint8List.fromList([1, 2, 3]),
        'width': 32,
        'height': 48,
        'createdAt': DateTime.utc(2026, 8, 26).toIso8601String(),
        'kind': GeneratedImageKind.completed.name,
      });
      await historyBox.put('generation_history_v1_record_invalid', {
        'bytes': Uint8List(0),
        'width': 0,
        'height': 0,
      });
      await historyBox.put('generation_history_v1_record_orphan', {
        'bytes': Uint8List.fromList([9]),
        'width': 1,
        'height': 1,
      });

      final restored = await GenerationHistoryStorageService().load();

      expect(restored.map((item) => item.id), ['valid']);
      expect(await storedOrder(), ['valid', 'missing', 'invalid']);
      expect(
        historyBox.containsKey('generation_history_v1_record_invalid'),
        isTrue,
      );
      expect(
        historyBox.containsKey('generation_history_v1_record_orphan'),
        isFalse,
      );
    },
  );

  for (final (field, payload, description) in [
    ('metadata', '{"prompt":"secret lighthouse keeper",', 'truncated metadata'),
    (
      'metadata',
      '{"prompt":["secret lighthouse keeper"]}',
      'mistyped metadata',
    ),
    (
      'metadata',
      '{"vibeReferences":[{"displayName":"secret lighthouse keeper",'
          '"vibeEncoding":"encoded","sourceType":"unknown"}]}',
      'an unknown Vibe source type in optional metadata',
    ),
    (
      'fixedTagUsageSnapshot',
      '{"entries":["secret lighthouse keeper",',
      'truncated fixed tags',
    ),
  ]) {
    test(
      'restores image with $description and preserves the disk record',
      () async {
        final record = rawRecord(1)..[field] = payload;
        const order = ['first', 'broken', 'last'];
        await historyBox.putAll({
          orderKey: order,
          recordKey('first'): rawRecord(2),
          recordKey('broken'): record,
          recordKey('last'): rawRecord(3),
        });

        late List<GeneratedImage> restored;
        final logs = await captureLogs(() async {
          restored = await GenerationHistoryStorageService().load();
        });

        expect(restored.map((image) => image.id), order);
        final image = restored[1];
        expect(image.bytes, record['bytes']);
        expect(image.width, record['width']);
        expect(image.height, record['height']);
        expect(image.metadata, isNull);
        expect(image.fixedTagUsageSnapshot, isNull);
        expect(
          logs.where(
            (line) =>
                line.contains('Invalid optional generation history field'),
          ),
          hasLength(1),
        );
        expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
        expect(await storedOrder(), order);
        expect(historyBox.keys.toSet(), {orderKey, ...order.map(recordKey)});
        expect(await historyBox.get(recordKey('broken')), record);
      },
    );
  }

  for (final (description, order) in <(String, Object?)>[
    ('missing', null),
    ('wrong type', 'private history content'),
    ('unreadable', const _Opaque()),
  ]) {
    test(
      'a $description order index is rebuilt and history can be saved again',
      () async {
        if (order is _Opaque) Hive.registerAdapter(_OpaqueAdapter());
        if (order != null) await historyBox.put(orderKey, order);
        final records = {
          recordKey('a-older'): rawRecord(1),
          recordKey('b-undated'): rawRecord(3)..['createdAt'] = 'invalid date',
          recordKey('c-newer'): rawRecord(2),
        };
        await historyBox.putAll(records);
        if (order is _Opaque) {
          await Hive.close();
          Hive.resetAdapters();
          await reopenLazily();
        }
        final service = GenerationHistoryStorageService();
        const rebuiltOrder = ['c-newer', 'a-older', 'b-undated'];

        final logs = await captureLogs(() async {
          expect((await service.load()).map((image) => image.id), rebuiltOrder);
        });

        expect(
          logs.where(
            (line) =>
                line.contains('Invalid persisted generation history order'),
          ),
          hasLength(1),
        );
        expect(
          logs.where((line) => line.contains('private history content')),
          isEmpty,
        );
        expect(await storedOrder(), rebuiltOrder);
        expect(historyBox.keys.toSet(), {orderKey, ...records.keys});
        for (final record in records.entries) {
          expect(await historyBox.get(record.key), record.value);
        }

        const updatedOrder = ['new', ...rebuiltOrder];
        await service.persistImages(
          changedImages: [image('new', byte: 4)],
          order: updatedOrder,
        );
        await reopenLazily();

        expect(await storedOrder(), updatedOrder);
        expect(historyBox.keys.toSet(), {
          orderKey,
          recordKey('new'),
          ...records.keys,
        });
        expect(
          (await GenerationHistoryStorageService().load()).map(
            (image) => image.id,
          ),
          updatedOrder,
        );
      },
    );
  }

  test(
    'a mixed order index keeps its string IDs in the original order',
    () async {
      const order = ['older', 42, 'newer'];
      await historyBox.putAll({
        orderKey: order,
        recordKey('older'): rawRecord(1),
        recordKey('newer'): rawRecord(2),
      });

      final restored = await GenerationHistoryStorageService().load();

      expect(restored.map((item) => item.id), ['older', 'newer']);
      expect(await historyBox.get(orderKey), order);
    },
  );

  test('disabled storage remains a no-op', () async {
    final service = GenerationHistoryStorageService(enabled: false);

    await service.persistImages(
      changedImages: [image('ignored')],
      order: const ['ignored'],
    );
    await service.clear();

    expect(await service.load(), isEmpty);
    expect(historyBox.keys, isEmpty);
  });

  group('format compatibility', () {
    test(
      'restores records an older build wrote through a regular box',
      () async {
        await Hive.close();
        final legacy = await Hive.openBox<dynamic>(StorageKeys.historyBox);
        await legacy.put(orderKey, ['old']);
        await legacy.put(recordKey('old'), rawRecord(1));
        await legacy.put(recordKey('gone'), rawRecord(2));
        await legacy.delete(recordKey('gone'));
        await legacy.put(recordKey('new'), rawRecord(3));
        await legacy.put(orderKey, ['new', 'old']);
        await legacy.close();
        await reopenLazily();

        final restored = await GenerationHistoryStorageService().load();

        expect(restored.map((item) => item.id), ['new', 'old']);
        expect(restored.first.bytes, [3, 4, 5]);
        expect(restored.last.filePath, '/images/1.png');
        expect(historyBox.keys.whereType<String>().toSet(), {
          orderKey,
          recordKey('new'),
          recordKey('old'),
        });
      },
    );

    test('records stay readable by an older build after a downgrade', () async {
      final service = GenerationHistoryStorageService();
      await service.persistImages(
        changedImages: [image('a', byte: 3), image('b', byte: 7)],
        order: const ['b', 'a'],
      );
      await service.flush();
      await Hive.close();

      final legacy = await Hive.openBox<dynamic>(StorageKeys.historyBox);
      expect(legacy.get(orderKey), ['b', 'a']);
      for (final (id, byte) in [('a', 3), ('b', 7)]) {
        final raw = legacy.get(recordKey(id)) as Map;
        // Older builds delete a record whose bytes or size fail to decode.
        expect(raw['bytes'], isA<Uint8List>());
        expect(raw['bytes'], [byte, byte + 1, byte + 2]);
        expect(raw['width'], 64);
        expect(raw['height'], 96);
        expect(DateTime.tryParse(raw['createdAt'] as String), isNotNull);
        expect(raw['kind'], GeneratedImageKind.completed.name);
      }
    });
  });

  group('concurrency and failed restores', () {
    test(
      'an interrupted clear leaves an empty order for the next load',
      () async {
        final service = GenerationHistoryStorageService(
          boxStorage: _InterruptedRecordDeleteStorage(),
        );
        await service.persistImages(
          changedImages: [image('old')],
          order: const ['old'],
        );

        await expectLater(service.clear(), throwsA(isA<FileSystemException>()));
        expect(await storedOrder(), isEmpty);
        expect(historyBox.keys.toSet(), {orderKey, recordKey('old')});
        await reopenLazily();

        expect(await GenerationHistoryStorageService().load(), isEmpty);
        expect(await storedOrder(), isEmpty);
        expect(historyBox.keys.toSet(), {orderKey});
      },
    );

    test('saving after a failed clear keeps only the new image', () async {
      await historyBox.putAll({
        orderKey: ['old'],
        recordKey('old'): rawRecord(1),
      });
      final service = GenerationHistoryStorageService(
        boxStorage: _InterruptedOrderWriteStorage(),
      );
      expect((await service.load()).single.id, 'old');

      await expectLater(service.clear(), throwsA(isA<FileSystemException>()));
      expect(await storedOrder(), ['old']);
      await service.persistImages(
        changedImages: [image('new')],
        order: const ['new'],
      );

      expect(await storedOrder(), ['new']);
      expect(historyBox.keys.toSet(), {orderKey, recordKey('new')});
    });

    test(
      'restores the first record if its order write was interrupted',
      () async {
        final first = image('first');
        final service = GenerationHistoryStorageService(
          boxStorage: _InterruptedOrderWriteStorage(),
        );

        await expectLater(
          service.persistImages(changedImages: [first], order: [first.id]),
          throwsA(isA<FileSystemException>()),
        );
        expect(historyBox.keys.toSet(), {recordKey(first.id)});
        await reopenLazily();

        final restored =
            (await GenerationHistoryStorageService().load()).single;
        expect(restored.id, first.id);
        expect(restored.bytes, first.bytes);
        expect(await storedOrder(), [first.id]);
        expect(historyBox.keys.toSet(), {orderKey, recordKey(first.id)});
      },
    );

    test(
      'a persist submitted before load returns keeps unseen history',
      () async {
        await historyBox.put(orderKey, ['old-a', 'old-b']);
        await historyBox.put(recordKey('old-a'), rawRecord(1));
        await historyBox.put(recordKey('old-b'), rawRecord(2));
        final service = GenerationHistoryStorageService();

        final loading = service.load();
        final persisting = service.persistImages(
          changedImages: [image('new')],
          order: const ['new'],
        );
        final restored = await loading;
        await persisting;

        expect(restored.map((image) => image.id), ['old-a', 'old-b']);
        expect(await storedOrder(), ['new', 'old-a', 'old-b']);
        expect(historyBox.containsKey(recordKey('old-a')), isTrue);
        expect(historyBox.containsKey(recordKey('old-b')), isTrue);
      },
    );

    test('a persist issued during load keeps the image it stores', () async {
      await historyBox.put(orderKey, ['broken', 'kept']);
      await historyBox.put(recordKey('broken'), {
        'bytes': Uint8List(0),
        'width': 0,
        'height': 0,
      });
      await historyBox.put(recordKey('kept'), rawRecord(1));
      final service = GenerationHistoryStorageService();

      final loading = service.load();
      final persisting = service.persistImages(
        changedImages: [image('fresh')],
        order: const ['fresh', 'kept'],
      );
      final restored = await loading;
      await persisting;

      expect(restored.map((item) => item.id), ['kept']);
      expect(await storedOrder(), ['fresh', 'kept', 'broken']);
      expect(historyBox.containsKey(recordKey('broken')), isTrue);
      expect(
        (await GenerationHistoryStorageService().load()).map((item) => item.id),
        ['fresh', 'kept'],
      );
    });

    test(
      'a persist that rebuilds the order keeps history the caller never received',
      () async {
        Hive.registerAdapter(_OpaqueAdapter());
        await historyBox.put(orderKey, const _Opaque());
        await historyBox.put(recordKey('old-a'), rawRecord(2));
        await historyBox.put(recordKey('old-b'), rawRecord(1));
        await Hive.close();
        Hive.resetAdapters();
        await reopenLazily();
        final service = GenerationHistoryStorageService();

        await service.persistImages(
          changedImages: [image('new')],
          order: const ['new'],
        );
        await service.flush();

        expect(await storedOrder(), ['new', 'old-a', 'old-b']);
        expect(
          (await GenerationHistoryStorageService().load()).map(
            (item) => item.id,
          ),
          ['new', 'old-a', 'old-b'],
        );
      },
    );

    test(
      'rebuilding preserves older records until a save applies the cap',
      () async {
        final oldIds = [
          for (var i = 0; i <= GenerationHistoryStorageService.maxEntries; i++)
            'old-$i',
        ];
        await historyBox.putAll({
          for (final (index, id) in oldIds.indexed)
            recordKey(id): rawRecord(index),
        });
        final rebuiltOrder = oldIds.reversed.toList();
        final restored = await GenerationHistoryStorageService().load();
        expect(restored.map((image) => image.id), rebuiltOrder.take(50));
        expect(await storedOrder(), rebuiltOrder);
        expect(historyBox.keys.toSet(), {orderKey, ...oldIds.map(recordKey)});

        final service = GenerationHistoryStorageService();

        await service.persistImages(
          changedImages: [image('new', byte: 51)],
          order: const ['new'],
        );
        await service.flush();

        final order = await storedOrder();
        expect(order, hasLength(GenerationHistoryStorageService.maxEntries));
        expect(order.first, 'new');
        expect(order.last, 'old-2');
        expect(historyBox.containsKey(recordKey('old-1')), isFalse);
        expect(historyBox.containsKey(recordKey('old-0')), isFalse);
      },
    );

    test(
      'removals made after a successful restore are still evicted',
      () async {
        await historyBox.put(orderKey, ['old-a', 'old-b']);
        await historyBox.put(recordKey('old-a'), rawRecord(1));
        await historyBox.put(recordKey('old-b'), rawRecord(2));
        final service = GenerationHistoryStorageService();
        await service.load();

        await service.persistImages(
          changedImages: const [],
          order: const ['old-b'],
        );
        await service.flush();

        expect(await storedOrder(), ['old-b']);
        expect(historyBox.containsKey(recordKey('old-a')), isFalse);
      },
    );

    test(
      'load and order rebuild skip an unreadable record and keep its key',
      () async {
        Hive.registerAdapter(_OpaqueAdapter());
        const order = ['newer', 'opaque', 'older'];
        await historyBox.putAll({
          orderKey: order,
          recordKey('older'): rawRecord(1),
          recordKey('opaque'): const _Opaque(),
          recordKey('newer'): rawRecord(2),
        });
        await reopenLazily();
        final service = GenerationHistoryStorageService();
        const readableIds = ['newer', 'older'];

        expect((await service.load()).map((image) => image.id), readableIds);
        expect(await storedOrder(), order);
        expect(historyBox.keys.toSet(), {orderKey, ...order.map(recordKey)});

        await historyBox.put(orderKey, 'invalid index');
        expect((await service.load()).map((image) => image.id), readableIds);
        const rebuiltOrder = [...readableIds, 'opaque'];
        expect(await storedOrder(), rebuiltOrder);

        await Hive.close();
        // Drops the adapter so the stored frame can no longer be decoded.
        Hive.resetAdapters();
        await reopenLazily();
        expect((await service.load()).map((image) => image.id), readableIds);
        await service.persistImages(
          changedImages: [image('new')],
          order: const ['new', ...readableIds],
        );
        await service.flush();
        expect(await storedOrder(), ['new', ...rebuiltOrder]);
        expect(historyBox.containsKey(recordKey('opaque')), isTrue);
      },
    );
  });
}

class _InterruptedOrderWriteStorage extends GenerationHistoryBoxStorage {
  bool _failNextPut = true;

  @override
  Future<void> put(String key, Object? value) async {
    if (_failNextPut) {
      _failNextPut = false;
      throw const FileSystemException('Interrupted order write');
    }
    await super.put(key, value);
  }
}

class _InterruptedRecordDeleteStorage extends GenerationHistoryBoxStorage {
  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    throw const FileSystemException('Interrupted record deletion');
  }
}

class _Opaque {
  const _Opaque();
}

class _OpaqueAdapter extends TypeAdapter<_Opaque> {
  @override
  final int typeId = 222;

  @override
  _Opaque read(BinaryReader reader) {
    VibeReference.fromJson({
      'displayName': 'opaque',
      'vibeEncoding': 'encoded',
      'sourceType': reader.read(),
    });
    return const _Opaque();
  }

  @override
  void write(BinaryWriter writer, _Opaque obj) => writer.write('unknown');
}
