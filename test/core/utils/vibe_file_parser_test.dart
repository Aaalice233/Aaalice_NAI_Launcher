import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/vibe_file_parser.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  test('.naiv4vibe 的 type=image 文件会按原图 Vibe 解析', () async {
    final rawImage = Uint8List.fromList([1, 2, 3, 4, 5]);
    final thumbnail = Uint8List.fromList([6, 7, 8, 9]);
    final json = jsonEncode({
      'name': 'Raw Only Vibe',
      'type': 'image',
      'importInfo': {'strength': 0.31, 'information_extracted': 0.62},
      'thumbnail': base64Encode(thumbnail),
      'image': base64Encode(rawImage),
    });

    final reference = await VibeFileParser.fromNaiV4Vibe(
      'raw_only.naiv4vibe',
      Uint8List.fromList(utf8.encode(json)),
    );

    expect(reference.displayName, 'Raw Only Vibe');
    expect(reference.vibeEncoding, isEmpty);
    expect(reference.strength, 0.31);
    expect(reference.infoExtracted, 0.62);
    expect(reference.sourceType, VibeSourceType.rawImage);
    expect(reference.rawImageData, rawImage);
    expect(reference.thumbnail, thumbnail);
    expect(reference.canReencodeFromRawSource, isTrue);
  });

  test('.naiv4vibe 解析会保留负强度、信息提取和原图数据', () async {
    final rawImage = Uint8List.fromList([1, 2, 3, 4]);
    final thumbnail = Uint8List.fromList([5, 6, 7, 8]);
    final json = jsonEncode({
      'name': 'Spring Breeze',
      'encodings': {
        'nai-diffusion-4-full': {
          'vibe': {'encoding': 'encoded-spring'},
        },
      },
      'importInfo': {'strength': -0.63, 'information_extracted': 0.25},
      'thumbnail': base64Encode(thumbnail),
      'image': base64Encode(rawImage),
    });

    final reference = await VibeFileParser.fromNaiV4Vibe(
      'spring.naiv4vibe',
      Uint8List.fromList(utf8.encode(json)),
    );

    expect(reference.displayName, 'Spring Breeze');
    expect(reference.vibeEncoding, 'encoded-spring');
    expect(reference.strength, -0.63);
    expect(reference.infoExtracted, 0.25);
    expect(reference.sourceType, VibeSourceType.naiv4vibe);
    expect(reference.rawImageData, rawImage);
    expect(reference.thumbnail, thumbnail);
  });

  test('官网 type=image Vibe 会同时保留编码、模型和 Data URI 缩略图', () async {
    final rawImage = Uint8List.fromList([1, 3, 5, 7]);
    final thumbnail = Uint8List.fromList([2, 4, 6, 8]);
    final json = jsonEncode({
      'identifier': 'novelai-vibe-transfer',
      'version': 1,
      'name': 'Official Image Vibe',
      'type': 'image',
      'image': base64Encode(rawImage),
      'thumbnail': 'data:image/png;base64,${base64Encode(thumbnail)}',
      'encodings': {
        'v4-5curated': {
          'parameter-hash': {
            'encoding': 'official-image-encoding',
            'params': {'information_extracted': 0.62},
          },
        },
      },
      'importInfo': {
        'model': ImageModels.animeDiffusionV45Curated,
        'strength': 0.31,
        'information_extracted': 0.62,
      },
    });

    final reference = await VibeFileParser.fromNaiV4Vibe(
      'official-image.naiv4vibe',
      Uint8List.fromList(utf8.encode(json)),
    );

    expect(reference.vibeEncoding, 'official-image-encoding');
    expect(reference.encodingModel, ImageModels.animeDiffusionV45Curated);
    expect(reference.sourceType, VibeSourceType.naiv4vibe);
    expect(reference.rawImageData, rawImage);
    expect(reference.thumbnail, thumbnail);
  });

  test('.naiv4vibebundle 解析会保留每个子 Vibe 的负强度和信息提取', () async {
    final rawImage = Uint8List.fromList([9, 8, 7, 6]);
    final bundleJson = jsonEncode({
      'identifier': 'novelai-vibe-transfer-bundle',
      'version': 1,
      'vibes': [
        {
          'name': 'Bundle Breeze',
          'encodings': {
            'nai-diffusion-4-full': {
              'vibe': {'encoding': 'bundle-encoded'},
            },
          },
          'importInfo': {'strength': -0.41, 'information_extracted': 0.6},
          'image': base64Encode(rawImage),
        },
      ],
    });

    final references = await VibeFileParser.fromBundle(
      'bundle.naiv4vibebundle',
      Uint8List.fromList(utf8.encode(bundleJson)),
    );

    expect(references, hasLength(1));
    expect(references.single.displayName, 'Bundle Breeze');
    expect(references.single.vibeEncoding, 'bundle-encoded');
    expect(references.single.strength, -0.41);
    expect(references.single.infoExtracted, 0.6);
    expect(references.single.sourceType, VibeSourceType.naiv4vibebundle);
    expect(references.single.rawImageData, rawImage);
  });

  test('.naiv4vibebundle 支持官网导出的未编码图片 Vibe', () async {
    final rawImage = Uint8List.fromList([4, 3, 2, 1]);
    final bundleJson = jsonEncode({
      'identifier': 'novelai-vibe-transfer-bundle',
      'version': 1,
      'vibes': [
        {
          'identifier': 'novelai-vibe-transfer',
          'version': 1,
          'name': 'Raw Bundle Vibe',
          'type': 'image',
          'image': base64Encode(rawImage),
          'encodings': <String, dynamic>{},
          'importInfo': {
            'model': ImageModels.animeDiffusionV45Full,
            'strength': 0.5,
            'information_extracted': 0.7,
          },
        },
      ],
    });

    final references = await VibeFileParser.fromBundle(
      'raw-bundle.naiv4vibebundle',
      Uint8List.fromList(utf8.encode(bundleJson)),
    );

    expect(references, hasLength(1));
    expect(references.single.vibeEncoding, isEmpty);
    expect(references.single.rawImageData, rawImage);
    expect(references.single.sourceType, VibeSourceType.rawImage);
    expect(references.single.encodingModel, ImageModels.animeDiffusionV45Full);
  });

  test('.naiv4vibebundle 的原图与相同缩略图只保留一份字节数据', () async {
    final image = Uint8List.fromList([7, 6, 5, 4]);
    final encodedImage = base64Encode(image);
    final bundleJson = jsonEncode({
      'vibes': [
        {
          'name': 'Shared image bytes',
          'type': 'image',
          'image': encodedImage,
          'thumbnail': encodedImage,
          'encodings': <String, dynamic>{},
        },
      ],
    });

    final references = await VibeFileParser.fromBundle(
      'shared-image.naiv4vibebundle',
      Uint8List.fromList(utf8.encode(bundleJson)),
    );

    expect(references, hasLength(1));
    expect(references.single.rawImageData, image);
    expect(
      identical(references.single.rawImageData, references.single.thumbnail),
      isTrue,
    );
  });

  test('大型 .naiv4vibebundle 会让出当前 isolate 再完成解析', () async {
    final bundleJson = jsonEncode({
      'padding': ''.padRight(2 * 1024 * 1024, 'x'),
      'vibes': [
        {
          'name': 'Background bundle',
          'encodings': {
            'v4full': {
              'variant': {'encoding': 'background-encoding'},
            },
          },
        },
      ],
    });
    var timerRan = false;
    Timer.run(() => timerRan = true);

    final references = await VibeFileParser.fromBundle(
      'background.naiv4vibebundle',
      Uint8List.fromList(utf8.encode(bundleJson)),
    );

    expect(timerRan, isTrue);
    expect(references.single.vibeEncoding, 'background-encoding');
  });
}
