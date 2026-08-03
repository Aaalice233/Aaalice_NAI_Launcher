import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/utils/local_gallery_metadata_resolver.dart';

void main() {
  test('reads embedded metadata when the gallery record has none', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'local_gallery_metadata_resolver_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final image = img.Image(width: 2, height: 2);
    img.fill(image, color: img.ColorRgb8(12, 34, 56));
    var bytes = Uint8List.fromList(img.encodePng(image));
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      'Comment',
      '{"prompt":"fresh prompt","uc":"bad hands","seed":123,"width":2,"height":2}',
    );
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      'Description',
      'fresh prompt',
    );
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      'Software',
      'NovelAI',
    );

    final file = File('${tempDir.path}/with_metadata.png');
    await file.writeAsBytes(bytes);
    final stat = await file.stat();
    final record = LocalImageRecord(
      path: file.path,
      size: stat.size,
      modifiedAt: stat.modified,
    );

    final metadata = await resolveLocalGalleryMetadata(record);

    expect(metadata, isNotNull);
    expect(metadata!.prompt, 'fresh prompt');
    expect(metadata.seed, 123);
  });

  test('prefers freshly parsed metadata over the indexed snapshot', () async {
    final record = LocalImageRecord(
      path: 'G:/gallery/image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 29),
      metadata: const NaiImageMetadata(prompt: 'indexed prompt'),
    );

    final metadata = await resolveLocalGalleryMetadata(
      record,
      loadFromFile: (_) async =>
          const NaiImageMetadata(prompt: 'embedded prompt'),
    );

    expect(metadata?.prompt, 'embedded prompt');
  });

  test('falls back to indexed metadata when refreshing fails', () async {
    final record = LocalImageRecord(
      path: 'G:/gallery/image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 29),
      metadata: const NaiImageMetadata(prompt: 'indexed prompt'),
    );

    final metadata = await resolveLocalGalleryMetadata(
      record,
      loadFromFile: (_) async => null,
    );

    expect(metadata?.prompt, 'indexed prompt');
  });
}
