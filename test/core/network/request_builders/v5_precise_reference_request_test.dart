import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/core/network/request_builders/precise_reference_limit_exception.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';

import '../../../helpers/browser_multipart_reader.dart';

void main() {
  final square = _png(1024, 1024);
  final original = _png(8, 4);
  final squareReferences = _references(square);
  final otherReferences = _references(original);
  const v5Models = [
    ImageModels.animeDiffusionV5Curated,
    ImageModels.animeDiffusionV5Full,
    ImageModels.animeDiffusionV5FullMedium,
  ];

  for (final model in v5Models) {
    test(
      '$model uses the official top-level precise reference parameters',
      () async {
        final result = await _build(
          ImageParams(
            model: model,
            normalizeVibeStrength: false,
            preciseReferences: squareReferences,
          ),
        );
        final parameters = result.requestParameters;
        expect(
          parameters['director_reference_images'],
          List.filled(6, base64Encode(square)),
        );
        expect(
          parameters['director_reference_descriptions'],
          _descriptions([
            'character',
            'style',
            'costume',
            'character&style',
            'character&style_anyoutfit',
            'character_mainoutfit',
          ]),
        );
        expect(
          parameters['director_reference_information_extracted'],
          List.filled(6, 1),
        );
        expect(parameters['director_reference_strength_values'], [
          0.75,
          -1.2,
          4.15,
          5.6,
          0,
          1,
        ]);
        expect(
          parameters['director_reference_secondary_strength_values'],
          List.filled(6, 0),
        );
        expect(parameters['normalize_reference_strength_multiple'], isTrue);
        expect(parameters, isNot(contains('director_reference_types')));
        expect(parameters, isNot(contains('extra_passthrough_testing')));
        expect(squareReferences[0].fidelity, 0.75);
      },
    );
  }

  test(
    'V5 delivers the bucketed image through the existing multipart cache',
    () async {
      final result = await _build(
        ImageParams(
          model: ImageModels.animeDiffusionV5Full,
          preciseReferences: [otherReferences.first],
        ),
        isStream: true,
      );
      final payload = result.requestParameters;
      final encoded =
          (payload['director_reference_images'] as List).single as String;
      final image = img.decodePng(base64Decode(encoded))!;
      expect((image.width, image.height), (1408, 704));
      final multipart = NaiGenerationTransport.buildGenerationMultipart(
        result.requestData,
      );
      final parts = parseBrowserMultipart(multipart.bytes, multipart.boundary);
      expect(parts.map((part) => part.name), ['director_ref_0', 'request']);
      expect(parts.first.bytes, base64Decode(encoded));
      final sent = jsonDecode(parts.last.text)['parameters'] as Map;
      expect(sent, isNot(contains('director_reference_images')));
      expect(sent['director_reference_images_cached'], [
        {
          'cache_secret_key': matches(r'^[0-9a-f]{64}$'),
          'data': 'director_ref_0',
        },
      ]);
      expect(
        sent['director_reference_descriptions'],
        _descriptions(['character']),
      );
      expect(sent, isNot(contains('extra_passthrough_testing')));
    },
  );

  test(
    'V4.5 drops costume and downgrades outfit captions without changing fidelity',
    () async {
      final result = await _build(
        ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          preciseReferences: otherReferences,
        ),
      );
      final parameters = result.requestParameters;
      expect(
        parameters['director_reference_descriptions'],
        _descriptions([
          'character',
          'style',
          'character&style',
          'character&style',
          'character',
        ]),
      );
      expect(
        parameters['director_reference_secondary_strength_values'],
        List.filled(5, 0.25),
      );
      expect(otherReferences[2].type, PreciseRefType.costume);
      expect(otherReferences[4].preferSameOutfit, isFalse);
    },
  );

  test('V5 Curated inpainting sends the V4.5 canvas and captions', () async {
    final result = await _build(
      _infill(ImageModels.animeDiffusionV5Curated, [
        otherReferences[2],
        otherReferences[5],
      ]),
    );
    expect(
      result.requestData['model'],
      ImageModels.animeDiffusionV45CuratedInpainting,
    );
    expect(result.requestParameters, contains('mask'));
    expect(
      result.requestParameters['director_reference_descriptions'],
      _descriptions(['character']),
    );
    expect(
      result.requestParameters['director_reference_secondary_strength_values'],
      [0.25],
    );
    final image =
        (result.requestParameters['director_reference_images'] as List).single
            as String;
    final png = img.decodePng(base64Decode(image))!;
    expect((png.width, png.height), (1536, 1024));
  });

  for (final (model, requestModel) in [
    (
      ImageModels.animeDiffusionV5Full,
      ImageModels.animeDiffusionV5FullInpainting,
    ),
    (
      ImageModels.animeDiffusionV5FullMedium,
      ImageModels.animeDiffusionV5FullMediumInpainting,
    ),
  ]) {
    test('$model inpainting skips even an over-limit list', () async {
      final result = await _build(
        _infill(model, List.filled(17, otherReferences[0])),
      );
      expect(result.requestData['model'], requestModel);
      expect(result.requestParameters, contains('mask'));
      expect(
        result.requestParameters.keys.where(
          (key) => key.startsWith('director_reference_'),
        ),
        isEmpty,
      );
    });
  }

  for (final model in [
    ImageModels.animeDiffusionV45Full,
    ImageModels.animeDiffusionV5Full,
  ]) {
    test('$model validates the limit after filtering', () async {
      final references = model == ImageModels.animeDiffusionV5Full
          ? squareReferences
          : otherReferences;
      final atLimit = ImageParams(
        model: model,
        preciseReferences: [
          ...List.filled(16, references.first),
          references.last,
          if (model == ImageModels.animeDiffusionV45Full) references[2],
        ],
      );
      final result = await _build(atLimit);
      expect(
        result.requestParameters['director_reference_images'],
        hasLength(16),
      );
      await expectLater(
        _build(
          atLimit.copyWith(
            preciseReferences: [
              ...atLimit.preciseReferences,
              references[model == ImageModels.animeDiffusionV5Full ? 2 : 1],
            ],
          ),
        ),
        throwsA(isA<PreciseReferenceLimitException>()),
      );
    });
  }
}

ImageParams _infill(String model, List<PreciseReference> references) =>
    ImageParams(
      model: model,
      action: ImageGenerationAction.infill,
      width: 128,
      height: 128,
      sourceImage: _png(128, 128),
      maskImage: _png(128, 128, value: 255),
      preciseReferences: references,
    );

Future<NAIImageRequestBuildResult> _build(
  ImageParams params, {
  bool isStream = false,
}) => NAIImageRequestBuilder(
  params: params,
  encodeVibe: (_, {required model, informationExtracted = 1}) =>
      throw StateError('Unexpected Vibe encoding'),
).build(sampler: params.sampler, isStream: isStream);

Uint8List _png(int width, int height, {int value = 32}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return img.encodePng(image, level: 1);
}

List<PreciseReference> _references(Uint8List image) => [
  for (final (type, outfit, strength, enabled) in [
    (PreciseRefType.character, false, 0.75, true),
    (PreciseRefType.style, null, -1.2, true),
    (PreciseRefType.costume, null, 4.15, true),
    (PreciseRefType.characterAndStyle, true, 5.6, true),
    (PreciseRefType.characterAndStyle, false, 0.0, true),
    (PreciseRefType.character, true, 1.0, true),
    (PreciseRefType.style, null, 1.0, false),
  ])
    PreciseReference(
      image: image,
      type: type,
      preferSameOutfit: outfit,
      strength: strength,
      fidelity: 0.75,
      enabled: enabled,
    ),
];

List<Map<String, Object>> _descriptions(List<String> types) => [
  for (final type in types)
    {
      'caption': {'base_caption': type, 'char_captions': []},
      'legacy_uc': false,
    },
];
