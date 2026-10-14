import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/presentation/utils/card_image_drag_factory.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_resource.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File source;
  late File prepared;
  final watermark = ShareImageTransform(
    cacheKey: 'mark',
    apply: (image, {required stripMetadata}) async => image,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('card_image_drag_test_');
    source = await File(p.join(root.path, 'a.png')).writeAsBytes([1]);
    prepared = await File(p.join(root.path, 'b.png')).writeAsBytes([2]);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File?> readyFile({
    String? filePath,
    File? preparedFile,
    String fileName = 'a.png',
    bool stripMetadata = false,
    ShareImageTransform? transform,
  }) => imageCardDragResource(
    id: 'a',
    fileName: fileName,
    filePath: filePath,
    preparedFile: preparedFile,
    bytes: Uint8List.fromList([1]),
    stripMetadata: stripMetadata,
    transform: transform,
  ).readyFile!();

  test('an untouched source file is handed out as is', () async {
    expect((await readyFile(filePath: source.path))?.path, source.path);
  });

  test('processing settings force a freshly exported file', () async {
    expect(await readyFile(filePath: source.path, stripMetadata: true), isNull);
    expect(
      await readyFile(filePath: source.path, transform: watermark),
      isNull,
    );
    expect(await readyFile(filePath: source.path, fileName: 'a.avif'), isNull);
  });

  test('a missing source falls back to exporting', () async {
    await source.delete();
    expect(await readyFile(filePath: source.path), isNull);
    expect(await readyFile(), isNull);
  });

  test('a prepared file wins even when settings need processing', () async {
    expect(
      (await readyFile(
        filePath: source.path,
        preparedFile: prepared,
        stripMetadata: true,
      ))?.path,
      prepared.path,
    );
    await prepared.delete();
    expect(
      await readyFile(
        filePath: source.path,
        preparedFile: prepared,
        stripMetadata: true,
      ),
      isNull,
    );
  });

  test('card drag payloads are recognized by their marker only', () {
    final payload = imageCardDragResource(
      id: 'a',
      fileName: 'a.png',
      stripMetadata: false,
      localData: {'source': 'gallery_internal', 'path': source.path},
    ).payload;
    expect(CardDragResource.isPayload(payload), isTrue);
    expect(CardDragResource.isPayload({'source': 'gallery_internal'}), isFalse);
    expect(CardDragResource.isPayload(null), isFalse);
  });
}
