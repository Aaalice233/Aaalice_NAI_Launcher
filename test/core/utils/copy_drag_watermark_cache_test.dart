import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';

void main() {
  late Directory directory;
  late File source;
  setUp(() async {
    await Directory('tool/.tmp').create(recursive: true);
    directory = await Directory('tool/.tmp').createTemp('watermark-transfer-');
    source = await File('${directory.path}/source.png').writeAsBytes([1, 2, 3]);
  });
  tearDown(() async => directory.delete(recursive: true));

  ShareImageTransform transform(
    String key,
    int marker, {
    Completer<void>? gate,
  }) => ShareImageTransform(
    cacheKey: key,
    apply: (image, {required stripMetadata}) async {
      if (gate != null) await gate.future;
      return SanitizedShareImage(
        bytes: Uint8List.fromList([...image.bytes, marker]),
        fileName: 'marked.png',
        mimeType: 'image/png',
      );
    },
  );

  Future<SanitizedShareImage> prepare(
    Uint8List bytes, {
    required String fileName,
    required bool stripMetadata,
  }) async => SanitizedShareImage(
    bytes: stripMetadata ? Uint8List.fromList([9]) : bytes,
    fileName: fileName,
    mimeType: 'image/png',
  );

  test(
    'transfer cache separates all policies and changed watermark defaults',
    () async {
      var writes = 0;
      final cache = ShareImageTransferCache(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'source.png',
        sourceFilePath: source.path,
        prepareImage: prepare,
        writeTempFile: (image) =>
            File('${directory.path}/${writes++}.png').writeAsBytes(image.bytes),
      );
      addTearDown(cache.dispose);
      final markA = transform('a', 4);
      final markB = transform('b', 5);
      expect((await cache.prepareFile(stripMetadata: false)).path, source.path);
      final marked = await cache.prepareFile(
        stripMetadata: false,
        transform: markA,
      );
      expect(marked.path, isNot(source.path));
      expect(await marked.readAsBytes(), [1, 2, 3, 4]);
      final stripped = await cache.prepareFile(stripMetadata: true);
      expect(await stripped.readAsBytes(), [9]);
      final both = await cache.prepareFile(
        stripMetadata: true,
        transform: markA,
      );
      expect(await both.readAsBytes(), [9, 4]);
      final changed = await cache.prepareFile(
        stripMetadata: true,
        transform: markB,
      );
      expect(await changed.readAsBytes(), [9, 5]);
      expect(changed.path, isNot(both.path));
      expect(
        await cache.prepareFile(stripMetadata: false, transform: markA),
        same(marked),
      );
      expect(writes, 4);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'history never uses raw or previous watermark while new variant prepares',
    () async {
      final service = ShareImagePreparationService(
        prepareImage: prepare,
        writePreparedFile: (key, image) =>
            File('${directory.path}/$key.png').writeAsBytes(image.bytes),
      );
      addTearDown(service.clearAll);
      void enqueue(ShareImageTransform? transform) => service.enqueue(
        imageId: 'history-1',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'source.png',
        sourceFilePath: source.path,
        stripMetadata: false,
        transform: transform,
      );
      enqueue(null);
      expect(
        (await service.waitUntilReady('history-1', stripMetadata: false))!.path,
        source.path,
      );
      final a = transform('a', 4);
      enqueue(a);
      final first = await service.waitUntilReady(
        'history-1',
        stripMetadata: false,
        transform: a,
      );
      expect(await first!.readAsBytes(), [1, 2, 3, 4]);

      final gate = Completer<void>();
      final b = transform('b', 5, gate: gate);
      enqueue(b);
      expect(
        service.readyFileFor('history-1', stripMetadata: false, transform: b),
        isNull,
      );
      expect(
        service
            .snapshotFor('history-1', stripMetadata: false, transform: b)
            .status,
        ShareImagePreparationStatus.preparing,
      );
      gate.complete();
      final second = await service.waitUntilReady(
        'history-1',
        stripMetadata: false,
        transform: b,
      );
      expect(second!.path, isNot(first.path));
      expect(await second.readAsBytes(), [1, 2, 3, 5]);
      await service.clearAll();
      expect(await first.exists(), isFalse);
      expect(await second.exists(), isFalse);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'watermark failure writes nothing and never falls back to a source file',
    () async {
      var writes = 0;
      final failing = ShareImageTransform(
        cacheKey: 'broken',
        apply: (image, {required stripMetadata}) async =>
            throw StateError('missing logo'),
      );
      final service = ShareImagePreparationService(
        prepareImage: prepare,
        writePreparedFile: (key, image) async {
          writes++;
          return source;
        },
      );
      addTearDown(service.clearAll);
      service.enqueue(
        imageId: 'history-1',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'source.png',
        sourceFilePath: source.path,
        stripMetadata: false,
        transform: failing,
      );
      expect(
        await service.waitUntilReady(
          'history-1',
          stripMetadata: false,
          transform: failing,
        ),
        isNull,
      );
      expect(
        service
            .snapshotFor('history-1', stripMetadata: false, transform: failing)
            .status,
        ShareImagePreparationStatus.failed,
      );
      final cache = ShareImageTransferCache(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'source.png',
        sourceFilePath: source.path,
        prepareImage: prepare,
        writeTempFile: (image) async {
          writes++;
          return source;
        },
      );
      addTearDown(cache.dispose);
      await expectLater(
        cache.prepareFile(stripMetadata: false, transform: failing),
        throwsStateError,
      );
      expect(writes, 0);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );
}
