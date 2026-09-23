import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../helpers/fixed_tag_usage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metadata-fixed-usage-');
    Hive.init(directory.path);
    await ImageMetadataService().initialize();
  });

  tearDown(() async {
    await ImageMetadataService().clearCache();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'a recorded snapshot is mounted onto metadata parsed from bytes',
    () async {
      final bytes = await novelAiPngBytes('recorded from bytes');
      final hash = FileHashCalculator().calculateFromBytes(bytes);
      await FixedTagUsageRecordStore().record(
        contentHash: hash,
        snapshot: fixedTagUsageSnapshotOf('from-store'),
      );

      final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);

      expect(
        metadata?.fixedTagUsageSnapshot?.entries.single.fixedTagId,
        'from-store',
      );
      expect(
        UnifiedMetadataParser.parseFromPng(bytes).metadata!.fixedTagUsageData,
        isNull,
      );
    },
  );

  test(
    'a recorded snapshot is mounted onto metadata parsed from a file',
    () async {
      final bytes = await novelAiPngBytes('recorded from file');
      final file = File('${directory.path}/recorded.png');
      await file.writeAsBytes(bytes);
      await FixedTagUsageRecordStore().record(
        contentHash: FileHashCalculator().calculateFromBytes(bytes),
        snapshot: fixedTagUsageSnapshotOf('file-store'),
      );

      final metadata = await ImageMetadataService().getMetadata(file.path);

      expect(
        metadata?.fixedTagUsageSnapshot?.entries.single.fixedTagId,
        'file-store',
      );
    },
  );

  test('the parse result entry mounts the recorded snapshot too', () async {
    final bytes = await novelAiPngBytes('recorded for parse result');
    await FixedTagUsageRecordStore().record(
      contentHash: FileHashCalculator().calculateFromBytes(bytes),
      snapshot: fixedTagUsageSnapshotOf('parse-result'),
    );

    final result = await ImageMetadataService().getMetadataParseResultFromBytes(
      bytes,
    );

    expect(result.success, isTrue);
    expect(
      result.metadata?.fixedTagUsageSnapshot?.entries.single.fixedTagId,
      'parse-result',
    );
  });

  test('a snapshot embedded in the png wins over the record', () async {
    final bytes = embedFixedTagUsageSnapshot(
      await novelAiPngBytes('embedded wins'),
      fixedTagUsageSnapshotOf('from-png'),
    );
    await FixedTagUsageRecordStore().record(
      contentHash: FileHashCalculator().calculateFromBytes(bytes),
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );

    final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);

    expect(
      metadata?.fixedTagUsageSnapshot?.entries.single.fixedTagId,
      'from-png',
    );
  });

  test('mounting never leaks into the metadata cache', () async {
    final bytes = await novelAiPngBytes('cache stays clean');
    final hash = FileHashCalculator().calculateFromBytes(bytes);
    await FixedTagUsageRecordStore().record(
      contentHash: hash,
      snapshot: fixedTagUsageSnapshotOf('from-store'),
    );

    final mounted = await ImageMetadataService().getMetadataFromBytes(bytes);
    expect(mounted?.fixedTagUsageData, isNotNull);

    await FixedTagUsageRecordStore().removeUsage(hash);
    final cached = await ImageMetadataService().getMetadataFromBytes(bytes);

    expect(cached, isNotNull);
    expect(cached!.fixedTagUsageData, isNull);
  });
}
