import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_image_display_cache.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late McpImageDisplayCache cache;
  final image = SanitizedShareImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'private-prompt-12345.png',
    mimeType: 'image/png',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mcp_display_cache_');
    cache = McpImageDisplayCache(directory: () async => directory);
  });

  tearDown(() async => directory.delete(recursive: true));

  test(
    'writes exact outgoing bytes under a neutral content-addressed name',
    () async {
      final file = await cache.prepare(image);
      expect(await file.readAsBytes(), image.bytes);
      expect(p.dirname(file.path), directory.path);
      expect(p.basename(file.path), matches(r'^image-[a-f0-9]{64}\.png$'));
      expect(file.path, isNot(contains('private-prompt')));
    },
  );

  test(
    'repeated and concurrent requests reuse one file without rewriting',
    () async {
      final files = await Future.wait(
        List.generate(3, (_) => cache.prepare(image)),
      );
      expect(files.map((file) => file.path).toSet(), hasLength(1));
      final stamp = DateTime.now().subtract(const Duration(hours: 1));
      await files.first.setLastModified(stamp);
      final before = await files.first.lastModified();
      final reused = await cache.prepare(image);
      expect(await reused.lastModified(), before);
      expect(await directory.list().length, 1);
    },
  );

  test('raw and sanitized bytes cannot share a cached file', () async {
    final raw = await cache.prepare(image);
    final clean = await cache.prepare(
      SanitizedShareImage(
        bytes: Uint8List.fromList([1, 2, 4]),
        fileName: image.fileName,
        mimeType: image.mimeType,
      ),
    );
    expect(raw.path, isNot(clean.path));
    expect(await raw.readAsBytes(), [1, 2, 3]);
    expect(await clean.readAsBytes(), [1, 2, 4]);
  });

  test('a modified cache file is repaired before exposing its path', () async {
    final file = await cache.prepare(image);
    await file.writeAsBytes([4, 5, 6]);
    final repaired = await cache.prepare(image);
    expect(await repaired.readAsBytes(), image.bytes);
  });

  test('cleanup only removes expired files owned by this cache', () async {
    final old = File(p.join(directory.path, 'image-${'a' * 64}.png'));
    final unrelated = File(p.join(directory.path, 'other.png'));
    for (final file in [old, unrelated]) {
      await file.writeAsBytes([1]);
      await file.setLastModified(
        DateTime.now().subtract(const Duration(days: 8)),
      );
    }
    await cache.prepare(image);
    expect(await old.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });
}
