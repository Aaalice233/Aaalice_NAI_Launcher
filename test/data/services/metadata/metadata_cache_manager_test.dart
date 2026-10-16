import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/metadata/cache_manager.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_entry_codec.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_evictor.dart';

void main() {
  group('MetadataCacheEntryCodec', () {
    test('round-trips the metadata json with its write time', () {
      const json = '{"prompt":"a|b"}';

      final raw = MetadataCacheEntryCodec.encode(json, writtenAtMillis: 1234);

      expect(MetadataCacheEntryCodec.metadataJsonOf(raw), json);
      expect(MetadataCacheEntryCodec.writtenAtMillisOf(raw), 1234);
    });

    test('reads legacy json values as the oldest entries', () {
      const legacy = '{"prompt":"t1|x"}';

      expect(MetadataCacheEntryCodec.metadataJsonOf(legacy), legacy);
      expect(
        MetadataCacheEntryCodec.writtenAtMillisOf(legacy),
        MetadataCacheEntryCodec.legacyWrittenAtMillis,
      );
    });

    test('rejects values it cannot recognise', () {
      for (final raw in ['', 'garbage', 't1234', 'tabc|{}']) {
        expect(
          MetadataCacheEntryCodec.writtenAtMillisOf(raw),
          MetadataCacheEntryCodec.legacyWrittenAtMillis,
          reason: raw,
        );
      }
      expect(MetadataCacheEntryCodec.metadataJsonOf('garbage'), isNull);
      expect(MetadataCacheEntryCodec.metadataJsonOf('t1234'), isNull);
    });
  });

  group('MetadataCacheManager persistent values', () {
    final manager = MetadataCacheManager();
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('metadata-cache-');
      Hive.init(directory.path);
      await manager.initialize();
    });

    tearDown(() async {
      manager.clearMemory();
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('saved values carry the write time ahead of the json', () async {
      final hash = 'a' * 64;
      final before = DateTime.now().millisecondsSinceEpoch;

      await manager.save(hash, const NaiImageMetadata(prompt: 'fresh'));

      final raw = manager.box!.get(hash)!;
      expect(
        MetadataCacheEntryCodec.writtenAtMillisOf(raw),
        inInclusiveRange(before, DateTime.now().millisecondsSinceEpoch),
      );
      final json = jsonDecode(MetadataCacheEntryCodec.metadataJsonOf(raw)!);
      expect((json as Map<String, dynamic>)['prompt'], 'fresh');
    });

    test('legacy values from earlier versions are still served', () async {
      final hash = 'b' * 64;
      await manager.box!.put(
        hash,
        jsonEncode(const NaiImageMetadata(prompt: 'legacy').toJson()),
      );

      expect(manager.getFromPersistent(hash)?.prompt, 'legacy');
    });

    test('the box file size is measurable once entries are saved', () async {
      await manager.save('c' * 64, const NaiImageMetadata(prompt: 'sized'));

      final bytes = await MetadataCacheEvictor.fileBytes(manager.box!);

      expect(bytes, greaterThan(0));
      expect(bytes, File(manager.box!.path!).lengthSync());
    });

    test('memory estimate follows the entries actually held', () async {
      expect(manager.estimatedMemoryBytes, 0);
      final hash = 'd' * 64;

      await manager.save(hash, const NaiImageMetadata(prompt: 'estimated'));

      expect(manager.estimatedMemoryBytes, manager.box!.get(hash)!.length * 2);
    });

    test('memory pressure drops the memory layer but keeps the disk', () async {
      final hash = '2' * 64;
      await manager.save(hash, const NaiImageMetadata(prompt: 'survivor'));
      expect(manager.memorySize, 1);

      await GalleryCacheManager().clearL1MemoryCache();

      expect(manager.memorySize, 0);
      expect(manager.estimatedMemoryBytes, 0);
      expect(manager.persistentSize, 1);
      expect(manager.getFromPersistent(hash)?.prompt, 'survivor');
    });
  });
}
