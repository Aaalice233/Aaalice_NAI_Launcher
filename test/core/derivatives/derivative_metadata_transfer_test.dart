import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/derivatives/derivative_metadata_transfer.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../helpers/novelai_exif_fixture.dart';
import '../../helpers/novelai_jpeg_layout_fixture.dart';
import '../../helpers/stealth_png_fixture.dart';

void main() {
  final target = _plainPng();

  group('preserve', () {
    test('ordinary images do not gain fabricated generation metadata', () {
      final result = DerivativeMetadataTransfer.preserve(
        source: _plainPng(),
        targetPng: target,
      );

      expect(UnifiedMetadataParser.extractPngTextData(result.bytes), isEmpty);
      expect(result.preserved, isFalse);
    });

    test('copied text chunks win and only missing fields are filled', () {
      final source = _withText(_plainPng(), {
        'Comment': '{"prompt":"private prompt","seed":42}',
        'Software': 'Custom Tool',
      });

      final result = DerivativeMetadataTransfer.preserve(
        source: source,
        targetPng: target,
      );

      final text = UnifiedMetadataParser.extractPngTextData(result.bytes);
      expect(text['Comment'], '{"prompt":"private prompt","seed":42}');
      expect(text['Software'], 'Custom Tool');
      expect(text['Description'], 'private prompt');
      expect(result.preserved, isTrue);
    });

    test('envelope sources write the inner generation JSON as Comment', () {
      final source = novelAiLayoutJpeg(
        exifTiffs: [
          novelAiExif(
            userComment: asciiUserComment(
              novelAiEnvelopeJson(prompt: 'envelope prompt', seed: 21),
            ),
          ),
        ],
      );

      final result = DerivativeMetadataTransfer.preserve(
        source: source,
        targetPng: target,
      );

      final text = UnifiedMetadataParser.extractPngTextData(result.bytes);
      final comment = jsonDecode(text['Comment']!) as Map<String, dynamic>;
      expect(comment['prompt'], 'envelope prompt');
      expect(comment['seed'], 21);
      expect(comment, isNot(contains('Comment')));
      expect(text['Software'], 'NovelAI');
      expect(text['Source'], novelAiV45FullSource);
      expect(text['Description'], 'envelope prompt');
      expect(result.preserved, isTrue);
    });

    test('stealth-only metadata is written out as text chunks', () async {
      final source = await stealthOnlyNovelAiPng('stealth prompt');

      final result = DerivativeMetadataTransfer.preserve(
        source: source,
        targetPng: target,
      );

      final text = UnifiedMetadataParser.extractPngTextData(result.bytes);
      expect(text['Comment'], contains('stealth prompt'));
      expect(text['Description'], 'stealth prompt');
      expect(result.preserved, isTrue);
    });

    test('a comment without Source gets the fingerprint of its model', () {
      final source = _withText(_plainPng(), {
        'Comment': jsonEncode({
          'prompt': 'tool prompt',
          'model': 'nai-diffusion-4-5-full',
        }),
      });

      final result = DerivativeMetadataTransfer.preserve(
        source: source,
        targetPng: target,
      );

      final text = UnifiedMetadataParser.extractPngTextData(result.bytes);
      expect(text['Source'], 'NovelAI Diffusion V4.5 4BDE2A90');
      expect(text['Software'], 'NovelAI');
    });

    test('a damaged source comment fails instead of being dropped', () {
      final source = _withText(_plainPng(), {'Comment': '{"prompt":'});

      expect(
        () => DerivativeMetadataTransfer.preserve(
          source: source,
          targetPng: target,
        ),
        throwsA(
          isA<DerivativeMetadataException>()
              .having(
                (error) => error.message,
                'message',
                startsWith(
                  'The source metadata is damaged or cannot be parsed: ',
                ),
              )
              .having((error) => error.cause, 'cause', isNull),
        ),
      );
    });

    test('malformed EXIF fails instead of being silently skipped', () {
      final source = novelAiLayoutJpeg(exifTiffs: [List<int>.filled(10, 1)]);

      expect(
        () => DerivativeMetadataTransfer.preserve(
          source: source,
          targetPng: target,
        ),
        throwsA(
          isA<DerivativeMetadataException>()
              .having(
                (error) => error.message,
                'message',
                'The source metadata is damaged and cannot be preserved safely.',
              )
              .having((error) => error.cause, 'cause', isFormatException),
        ),
      );
    });
  });

  group('preserveInBackground', () {
    test('matches the synchronous transfer', () async {
      final source = _withText(_plainPng(), {
        'Comment': '{"prompt":"background prompt","seed":7}',
      });

      final background = await DerivativeMetadataTransfer.preserveInBackground(
        source: source,
        targetPng: target,
      );
      final direct = DerivativeMetadataTransfer.preserve(
        source: source,
        targetPng: target,
      );

      expect(background.bytes, orderedEquals(direct.bytes));
      expect(background.preserved, direct.preserved);
    });

    test('failures keep their type across the isolate boundary', () async {
      final source = _withText(_plainPng(), {'Comment': '{"prompt":'});

      await expectLater(
        DerivativeMetadataTransfer.preserveInBackground(
          source: source,
          targetPng: target,
        ),
        throwsA(
          isA<DerivativeMetadataException>().having(
            (error) => error.message,
            'message',
            startsWith('The source metadata is damaged or cannot be parsed: '),
          ),
        ),
      );
    });
  });
}

Uint8List _plainPng() => Uint8List.fromList(
  img.encodePng(
    img.Image(width: 16, height: 16, numChannels: 4)
      ..clear(img.ColorRgba8(40, 80, 120, 255)),
  ),
);

Uint8List _withText(Uint8List png, Map<String, String> chunks) {
  var output = png;
  for (final MapEntry(:key, :value) in chunks.entries) {
    output = UnifiedMetadataParser.embedTextChunkOnly(output, key, value);
  }
  return output;
}
