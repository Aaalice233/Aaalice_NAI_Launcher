import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/novelai_vibe_codec.dart';
import 'package:nai_launcher/core/utils/vibe_file_parser.dart';
import 'package:path/path.dart' as p;
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

import '../../helpers/shared_compute_gate.dart';

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

  test('大型 .naiv4vibebundle 的后台解析经过共享计算闸门排队', () async {
    final bundleBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'padding': ''.padRight(2 * 1024 * 1024, 'x'),
          'vibes': [
            {
              'name': 'Gated bundle',
              'encodings': {
                'v4full': {
                  'variant': {'encoding': 'gated-encoding'},
                },
              },
            },
          ],
        }),
      ),
    );

    final references = await expectQueuedBehindSharedComputeGate(
      () => VibeFileParser.fromBundle('gated.naiv4vibebundle', bundleBytes),
    );

    expect(references.single.displayName, 'Gated bundle');
    expect(references.single.vibeEncoding, 'gated-encoding');
  });

  test('PNG 内嵌 Vibe 的解析经过共享计算闸门排队且不退回原图', () async {
    Uint8List pngWithText(String keyword, String value) {
      final image = img.Image(width: 2, height: 2)..textData = {keyword: value};
      return Uint8List.fromList(img.encodePng(image));
    }

    final encodingPng = pngWithText(
      'NovelAI_Vibe_Encoding_Base64',
      'gated-png-encoding',
    );
    final bundlePng = pngWithText(
      'naidata',
      base64Encode(
        utf8.encode(
          jsonEncode({
            'vibes': [
              {
                'name': 'Gated bundle vibe',
                'encodings': {
                  'v4full': {
                    'variant': {'encoding': 'gated-bundle-encoding'},
                  },
                },
              },
            ],
          }),
        ),
      ),
    );

    final parsed = await expectQueuedBehindSharedComputeGate(
      () => VibeFileParser.fromPng('gated.png', encodingPng),
    );
    final bundle = await expectQueuedBehindSharedComputeGate(
      () => VibeFileParser.extractBundleFromPng(bundlePng),
    );

    expect(parsed.sourceType, VibeSourceType.png);
    expect(parsed.vibeEncoding, 'gated-png-encoding');
    expect(bundle.single.displayName, 'Gated bundle vibe');
    expect(bundle.single.vibeEncoding, 'gated-bundle-encoding');
  });

  group('JSON 中的原图与缩略图', () {
    final image = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

    Uint8List document(Map<String, dynamic> json) =>
        Uint8List.fromList(utf8.encode(jsonEncode(json)));

    test('Data URI 缩略图与原图载荷相同时共用同一份字节', () async {
      final reference = await VibeFileParser.fromNaiV4Vibe(
        'same.naiv4vibe',
        document({
          'name': 'Same image',
          'type': 'image',
          'image': base64Encode(image),
          'thumbnail': 'data:image/png;base64,${base64Encode(image)}',
        }),
      );

      expect(reference.rawImageData, image);
      expect(identical(reference.thumbnail, reference.rawImageData), isTrue);
    });

    test('缺少 thumbnail 时缩略图复用原图字节', () async {
      final reference = await VibeFileParser.fromNaiV4Vibe(
        'image-only.naiv4vibe',
        document({
          'name': 'Image only',
          'type': 'image',
          'image': base64Encode(image),
        }),
      );

      expect(reference.rawImageData, image);
      expect(identical(reference.thumbnail, reference.rawImageData), isTrue);
    });

    test('载荷等长但内容不同的缩略图仍单独解码', () async {
      final thumbnail = Uint8List.fromList([6, 5, 4, 3, 2, 1]);
      final reference = await VibeFileParser.fromNaiV4Vibe(
        'distinct.naiv4vibe',
        document({
          'name': 'Distinct thumbnail',
          'type': 'image',
          'image': base64Encode(image),
          'thumbnail': 'data:image/png;base64,${base64Encode(thumbnail)}',
        }),
      );

      expect(reference.rawImageData, image);
      expect(reference.thumbnail, thumbnail);
      expect(identical(reference.thumbnail, reference.rawImageData), isFalse);
    });

    test('.naiv4vibebundle 子项的 Data URI 缩略图与原图共用字节', () async {
      final references = await VibeFileParser.fromBundle(
        'data-uri.naiv4vibebundle',
        document({
          'vibes': [
            {
              'name': 'Data URI child',
              'type': 'image',
              'image': base64Encode(image),
              'thumbnail': 'data:image/png;base64,${base64Encode(image)}',
              'encodings': <String, dynamic>{},
            },
          ],
        }),
      );

      expect(references.single.rawImageData, image);
      expect(
        identical(references.single.thumbnail, references.single.rawImageData),
        isTrue,
      );
    });

    test('PNG 内嵌 bundle 子项的缩略图与原图共用字节', () async {
      final png = img.Image(width: 2, height: 2)
        ..textData = {
          'naidata': base64Encode(
            utf8.encode(
              jsonEncode({
                'vibes': [
                  {
                    'name': 'Embedded child',
                    'image': base64Encode(image),
                    'thumbnail': 'data:image/png;base64,${base64Encode(image)}',
                    'encodings': {
                      'v4full': {
                        'variant': {'encoding': 'embedded-encoding'},
                      },
                    },
                  },
                ],
              }),
            ),
          ),
        };

      final references = await VibeFileParser.extractBundleFromPng(
        Uint8List.fromList(img.encodePng(png)),
      );

      expect(references.single.rawImageData, image);
      expect(
        identical(references.single.thumbnail, references.single.rawImageData),
        isTrue,
      );
    });
  });

  group('大型 .naiv4vibe 在后台 isolate 解析', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vibe_file_parser_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    VibeReference largeImageVibe() {
      final image = Uint8List(1200 * 1024);
      for (var i = 0; i < image.length; i++) {
        image[i] = i & 0xff;
      }
      return VibeReference(
        displayName: 'Large image vibe',
        vibeEncoding: 'large-encoding',
        thumbnail: image,
        rawImageData: image,
        strength: 0.4,
        infoExtracted: 0.6,
        encodingModel: ImageModels.animeDiffusionV45Full,
        sourceType: VibeSourceType.naiv4vibe,
      );
    }

    File writeDocument(String name, Map<String, dynamic> json) {
      final file = File(p.join(tempDir.path, name))
        ..writeAsStringSync(jsonEncode(json));
      expect(file.lengthSync(), greaterThan(1024 * 1024));
      return file;
    }

    test('读文件与解析一起经过共享计算闸门，原图与缩略图共用字节', () async {
      final vibe = largeImageVibe();
      final file = writeDocument(
        'official.naiv4vibe',
        NovelAiVibeCodec.buildSingleMap(vibe),
      );

      final parsed = await expectQueuedBehindSharedComputeGate(
        () => VibeFileParser.fromNaiV4VibeFile(
          file.path,
          fileName: 'official.naiv4vibe',
        ),
      );

      expect(parsed.matchesSchema, isTrue);
      expect(parsed.reference.displayName, 'Large image vibe');
      expect(parsed.reference.vibeEncoding, 'large-encoding');
      expect(parsed.reference.rawImageData, vibe.rawImageData);
      expect(
        identical(parsed.reference.thumbnail, parsed.reference.rawImageData),
        isTrue,
      );
    });

    test('结构校验不核对内容哈希，但仍识别非官方结构', () async {
      final official = NovelAiVibeCodec.buildSingleMap(largeImageVibe());
      final mismatchedId = writeDocument('mismatched-id.naiv4vibe', {
        ...official,
        'id': 'f' * 64,
      });
      final legacy = writeDocument(
        'legacy.naiv4vibe',
        Map.of(official)..remove('identifier'),
      );

      final parsedMismatchedId = await VibeFileParser.fromNaiV4VibeFile(
        mismatchedId.path,
        fileName: 'mismatched-id.naiv4vibe',
      );
      final parsedLegacy = await VibeFileParser.fromNaiV4VibeFile(
        legacy.path,
        fileName: 'legacy.naiv4vibe',
      );

      expect(parsedMismatchedId.matchesSchema, isTrue);
      expect(parsedLegacy.matchesSchema, isFalse);
      expect(parsedLegacy.reference.vibeEncoding, 'large-encoding');
    });

    test('内存中的大文档经过共享计算闸门并保留原有异常类型', () async {
      final official = NovelAiVibeCodec.buildSingleMap(largeImageVibe());
      final valid = Uint8List.fromList(utf8.encode(jsonEncode(official)));
      final missingImage = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'name': 'Broken image vibe',
            'type': 'image',
            'padding': ''.padRight(2 * 1024 * 1024, 'x'),
          }),
        ),
      );

      final parsed = await expectQueuedBehindSharedComputeGate(
        () => VibeFileParser.fromNaiV4Vibe('valid.naiv4vibe', valid),
      );

      expect(parsed.vibeEncoding, 'large-encoding');
      await expectLater(
        VibeFileParser.fromNaiV4Vibe('broken.naiv4vibe', missingImage),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
