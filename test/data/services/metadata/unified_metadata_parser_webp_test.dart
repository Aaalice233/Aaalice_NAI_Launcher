import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/webp_metadata_fixture.dart';

void main() {
  const novelAiComment = <String, dynamic>{
    'prompt': '1girl, webp metadata',
    'uc': 'lowres',
    'width': 832,
    'height': 1216,
    'seed': 123456789,
    'steps': 28,
    'scale': 5.0,
    'sampler': 'k_euler',
  };

  test('format-dispatch entry preserves PNG metadata parsing', () {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    final withMetadata = UnifiedMetadataParser.embedTextChunkOnly(
      png,
      'Comment',
      jsonEncode(novelAiComment),
    );

    final result = UnifiedMetadataParser.parseFromImage(withMetadata);

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.metadata?.prompt, '1girl, webp metadata');
  });

  group('UnifiedMetadataParser WebP', () {
    test('extracts NovelAI JSON from EXIF UserComment in a real RIFF WebP', () {
      final bytes = buildNovelAiWebpFixture(comment: novelAiComment);

      // Guard the fixture itself: it includes a decodable lossless WebP image
      // payload in addition to VP8X, unknown and EXIF chunks.
      expect(img.decodeWebP(bytes), isNotNull);

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.sourceFormat, 'NovelAI WebP EXIF');
      expect(result.metadata?.prompt, '1girl, webp metadata');
      expect(result.metadata?.negativePrompt, 'lowres');
      expect(result.metadata?.seed, 123456789);
      expect(result.metadata?.width, 832);
      expect(result.metadata?.height, 1216);
      expect(result.metadata?.source, 'NovelAI Diffusion V4.5');
      expect(result.triedParsers, contains('WebP EXIF'));
    });

    test('reports a valid WebP without EXIF metadata as unrecognized', () {
      final bytes = buildNovelAiWebpFixture();

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.errorMessage, contains('No EXIF UserComment'));
    });

    test('reports truncated WebP container without pretending success', () {
      final complete = buildNovelAiWebpFixture(comment: novelAiComment);
      final truncated = complete.sublist(0, complete.length - 5);

      final result = UnifiedMetadataParser.parseFromImage(truncated);

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.errorMessage, contains('Truncated WebP RIFF container'));
    });

    test('rejects non-ASCII EXIF UserComment encoding with diagnostics', () {
      final bytes = buildNovelAiWebpFixture(
        comment: novelAiComment,
        invalidUserCommentPrefix: true,
      );

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.errorMessage, contains('expected ASCII prefix'));
    });

    test('file parsing accepts an uppercase WebP extension', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_webp_metadata_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}sample.WEBP');
      await file.writeAsBytes(buildNovelAiWebpFixture(comment: novelAiComment));

      final result = UnifiedMetadataParser.parseFromFile(
        file.path,
        useGradualRead: false,
        useCache: false,
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.metadata?.prompt, '1girl, webp metadata');
    });
  });
}
