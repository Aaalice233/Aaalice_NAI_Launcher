import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  group('NAIImageRequestBuilder.build', () {
    test('should keep provided sampler and stream mode difference', () async {
      const params = ImageParams(model: 'nai-diffusion-4-full');
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final nonStreamResult = await builder.build(sampler: 'mapped_sampler');
      expect(nonStreamResult.requestParameters['sampler'], 'mapped_sampler');
      expect(nonStreamResult.requestParameters.containsKey('stream'), isFalse);

      final streamResult = await builder.build(
        sampler: 'raw_stream_sampler',
        isStream: true,
      );
      expect(streamResult.requestParameters['sampler'], 'raw_stream_sampler');
      expect(streamResult.requestParameters['stream'], 'msgpack');
    });

    test('should throw ArgumentError when sampler is empty', () async {
      const params = ImageParams();
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      expect(
        () => builder.build(sampler: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should return vibeEncodingMap only in non-stream mode', () async {
      final params = ImageParams(
        model: 'nai-diffusion-4-full',
        vibeReferencesV4: [
          VibeReference(
            displayName: 'raw',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([1, 2, 3]),
            sourceType: VibeSourceType.rawImage,
          ),
          const VibeReference(
            displayName: 'pre',
            vibeEncoding: 'pre-encoded',
            sourceType: VibeSourceType.png,
          ),
        ],
      );

      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final nonStreamResult = await builder.build(sampler: 'sampler_non_stream');
      expect(nonStreamResult.vibeEncodingMap, {
        0: 'encoded-vibe',
        1: 'pre-encoded',
      });

      final streamResult = await builder.build(
        sampler: 'sampler_stream',
        isStream: true,
      );
      expect(streamResult.vibeEncodingMap, isEmpty);
    });

    test('should ignore precise references for non-v4 model', () async {
      final params = ImageParams(
        model: 'nai-diffusion-3',
        preciseReferences: [
          PreciseReference(
            image: Uint8List.fromList([1, 2, 3]),
            type: PreciseRefType.character,
          ),
        ],
      );

      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'ddim_v3');
      expect(
        result.requestParameters.containsKey('director_reference_images'),
        isFalse,
      );
    });
  });
}

Future<String> _fakeEncodeVibe(
  Uint8List image, {
  required String model,
  double informationExtracted = 1.0,
}) async {
  return 'encoded-vibe';
}
