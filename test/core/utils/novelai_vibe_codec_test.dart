import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/novelai_vibe_codec.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  group('NovelAiVibeCodec', () {
    test('builds an official encoding-only V4.5 Vibe', () {
      final thumbnail = Uint8List.fromList(const [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
      final vibe = VibeReference(
        displayName: 'Encoding Vibe',
        vibeEncoding: 'official-encoding',
        thumbnail: thumbnail,
        strength: 0.42,
        infoExtracted: 0.73,
        encodingModel: ImageModels.animeDiffusionV45Full,
        sourceType: VibeSourceType.naiv4vibe,
      );

      final result = NovelAiVibeCodec.buildSingleMap(
        vibe,
        createdAt: DateTime.fromMillisecondsSinceEpoch(123),
      );

      expect(NovelAiVibeCodec.validateSingleMap(result), isTrue);
      expect(result['identifier'], NovelAiVibeCodec.singleIdentifier);
      expect(result['version'], 1);
      expect(result['type'], 'encoding');
      expect(result.containsKey('image'), isFalse);
      expect(result['id'], _sha256String('official-encoding'));
      expect(result['thumbnail'], startsWith('data:image/png;base64,'));
      expect(
        result['encodings']['v4-5full']['unknown']['encoding'],
        'official-encoding',
      );
      expect(result['importInfo']['model'], ImageModels.animeDiffusionV45Full);
      expect(result['createdAt'], 123);
    });

    test(
      'hashes image IDs and encoding parameter variants like the website',
      () {
        final rawImage = Uint8List.fromList(const [1, 2, 3, 4]);
        final imageBase64 = base64Encode(rawImage);
        final vibe = VibeReference(
          displayName: 'Image Vibe',
          vibeEncoding: 'image-encoding',
          rawImageData: rawImage,
          strength: -0.2,
          infoExtracted: 0.4,
          encodingModel: ImageModels.animeDiffusionV4Curated,
        );

        final result = NovelAiVibeCodec.buildSingleMap(vibe);
        final expectedParamsKey = _sha256String('information_extracted:0.4');

        expect(NovelAiVibeCodec.validateSingleMap(result), isTrue);
        expect(result['type'], 'image');
        expect(result['image'], imageBase64);
        expect(result['id'], _sha256String(imageBase64));
        expect(
          result['encodings']['v4curated'][expectedParamsKey]['encoding'],
          'image-encoding',
        );
        expect(result['encodings']['v4curated'][expectedParamsKey]['params'], {
          'information_extracted': 0.4,
        });
      },
    );

    test('builds bundles from complete single-Vibe objects', () {
      const vibes = [
        VibeReference(
          displayName: 'First',
          vibeEncoding: 'first-encoding',
          encodingModel: ImageModels.animeDiffusionV4Full,
        ),
        VibeReference(
          displayName: 'Second',
          vibeEncoding: 'second-encoding',
          encodingModel: ImageModels.animeDiffusionV45Curated,
        ),
      ];

      final result = NovelAiVibeCodec.buildBundleMap(vibes);
      final entries = result['vibes'] as List<dynamic>;

      expect(NovelAiVibeCodec.validateBundleMap(result), isTrue);
      expect(result['identifier'], NovelAiVibeCodec.bundleIdentifier);
      expect(entries, hasLength(2));
      for (final entry in entries.cast<Map<String, dynamic>>()) {
        expect(entry['identifier'], NovelAiVibeCodec.singleIdentifier);
        expect(entry['id'], matches(RegExp(r'^[\da-f]{64}$')));
        expect(entry['importInfo'], isA<Map<String, dynamic>>());
      }
    });

    test('rejects the legacy launcher shape rejected by the website', () {
      final legacy = <String, dynamic>{
        'identifier': NovelAiVibeCodec.singleIdentifier,
        'version': 1,
        'type': 'encoding',
        'id': 'short-id',
        'encodings': {
          ImageModels.animeDiffusionV4Full: {
            'vibe': {'encoding': 'legacy-encoding'},
          },
        },
        'thumbnail': base64Encode(const [1, 2, 3]),
        'importInfo': {
          'model': ImageModels.animeDiffusionV4Full,
          'information_extracted': 0.7,
          'strength': 0.6,
        },
      };

      expect(NovelAiVibeCodec.validateSingleMap(legacy), isFalse);
    });
  });
}

String _sha256String(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}
