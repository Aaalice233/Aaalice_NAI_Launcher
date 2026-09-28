import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/services/generation_history_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late Box<dynamic> historyBox;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'generation-history-storage-test-',
    );
    Hive.init(hiveDirectory.path);
    historyBox = await Hive.openBox<dynamic>(StorageKeys.historyBox);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

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
      historyBox.get('generation_history_v1_record_comparison') as Map,
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

  test('drops invalid and orphaned records while loading', () async {
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
    expect(historyBox.get('generation_history_v1_order'), ['valid']);
    expect(
      historyBox.containsKey('generation_history_v1_record_invalid'),
      isFalse,
    );
    expect(
      historyBox.containsKey('generation_history_v1_record_orphan'),
      isFalse,
    );
  });

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
}
