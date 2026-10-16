import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/cache_manager.dart';
import 'package:nai_launcher/data/services/metadata/metadata_parse_executor.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../helpers/content_hash.dart';
import '../../helpers/fixed_tag_usage_fixture.dart';
import '../../helpers/image_metadata_service_sandbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final directory = useImageMetadataServiceSandbox();

  test(
    'overwriting a file in place drops the metadata of the old pixels',
    () async {
      final original = await novelAiPngBytes('prompt-A');
      final replacement = await novelAiPngBytes('prompt-B');
      expect(replacement.length, original.length);
      final file = File('${directory().path}/same-path.png');
      await file.writeAsBytes(original, flush: true);
      await file.setLastModified(DateTime(2026, 9, 1));

      final service = ImageMetadataService();
      expect((await service.getMetadata(file.path))?.prompt, 'prompt-A');
      expect(service.getCached(file.path)?.prompt, 'prompt-A');

      await file.writeAsBytes(replacement, flush: true);
      await file.setLastModified(DateTime(2026, 9, 2));

      expect(service.getCached(file.path), isNull);
      expect((await service.getMetadata(file.path))?.prompt, 'prompt-B');
      expect(service.getCached(file.path)?.prompt, 'prompt-B');
    },
  );

  test('the sync lookup answers only from memory', () async {
    final file = File('${directory().path}/memory-only.png');
    await file.writeAsBytes(await novelAiPngBytes('persisted'), flush: true);
    final service = ImageMetadataService();
    expect((await service.getMetadata(file.path))?.prompt, 'persisted');

    MetadataCacheManager().clearMemory();

    expect(service.getCached(file.path), isNull);
    expect((await service.getCachedAsync(file.path))?.prompt, 'persisted');
    expect(service.getCached(file.path)?.prompt, 'persisted');
  });

  test('a deleted file no longer answers from the sync cache', () async {
    final file = File('${directory().path}/deleted.png');
    await file.writeAsBytes(await novelAiPngBytes('gone'), flush: true);
    final service = ImageMetadataService();
    expect((await service.getMetadata(file.path))?.prompt, 'gone');

    await file.delete();

    expect(service.getCached(file.path), isNull);
  });

  final entryPoints = <String, Future<NaiImageMetadata?> Function(String)>{
    'getMetadata': (path) => ImageMetadataService().getMetadata(path),
    'getMetadataImmediate': (path) =>
        ImageMetadataService().getMetadataImmediate(path),
  };
  for (final MapEntry(key: name, value: read) in entryPoints.entries) {
    test('$name: a file replaced between hashing and parsing is not cached '
        'under the old hash', () async {
      final original = await novelAiPngBytes('prompt-A');
      final replacement = await novelAiPngBytes('prompt-B');
      final file = File('${directory().path}/raced.png');
      await file.writeAsBytes(original, flush: true);
      await file.setLastModified(DateTime(2026, 9, 1));
      final originalHash = contentHashOf(original);
      var replaced = false;
      ImageMetadataService().debugSetParseExecutorForTesting(
        _ReplaceBeforeParse((path) async {
          if (replaced) return;
          replaced = true;
          await File(path).writeAsBytes(replacement, flush: true);
          await File(path).setLastModified(DateTime(2026, 9, 2));
        }),
      );

      expect(await read(file.path), isNull);
      expect(MetadataCacheManager().getFromMemory(originalHash), isNull);
      expect(
        await MetadataCacheManager().getFromPersistent(originalHash),
        isNull,
      );

      // 同内容的另一份拷贝只能解析出它自己的元数据
      final copy = File('${directory().path}/copy.png');
      await copy.writeAsBytes(original, flush: true);
      expect((await read(copy.path))?.prompt, 'prompt-A');
      expect((await read(file.path))?.prompt, 'prompt-B');
    });
  }
}

// 在哈希与解析两次读盘之间替换文件
class _ReplaceBeforeParse extends MetadataParseExecutor {
  _ReplaceBeforeParse(this._replace);

  final Future<void> Function(String path) _replace;

  @override
  Future<MetadataParseResult> parseFile(String path) async {
    await _replace(path);
    return UnifiedMetadataParser.parseFromFile(path);
  }
}
