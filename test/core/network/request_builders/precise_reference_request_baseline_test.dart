import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/network/js_compatible_json.dart';

import '../../../helpers/precise_reference_baseline.dart';

void main() {
  for (final infill in [false, true]) {
    test('V4.5 precise reference parameters baseline infill=$infill', () async {
      final result = await buildPreciseReferenceBaseline(infill: infill);
      final parameters = result.requestParameters;
      final images = parameters['director_reference_images'] as List;
      final hashes = images
          .map(
            (image) => sha256.convert(base64Decode(image as String)).toString(),
          )
          .toList();
      final hash = sha256
          .convert(utf8.encode(encodeJsCompatibleJson(parameters)))
          .toString();
      expect(
        hash,
        infill
            ? '89660a9c37e22e3c2025778327d2ba9fff35cc5f8bd8c6cbe7d6780364c84d14'
            : '765c664605cece81667fd3fefbe7f1af8572b22000942537b5e265790cf29e81',
      );
      expect(images, hasLength(2));
      expect(hashes, [
        '04e685dea5a5340d4f12759046de01e12a4bc7418244f6a608fe41a1de9593dd',
        '07c17823f91b9187421e6569c292e2c1f82684ca5a145a84852ed2df601a88c5',
      ]);
      expect(
        images.map((image) {
          final decoded = img.decodePng(base64Decode(image as String))!;
          return (decoded.width, decoded.height);
        }),
        [(1536, 1024), (1024, 1536)],
      );
      expect(parameters['director_reference_descriptions'], [
        {
          'caption': {'base_caption': 'character', 'char_captions': []},
          'legacy_uc': false,
        },
        {
          'caption': {'base_caption': 'style', 'char_captions': []},
          'legacy_uc': false,
        },
      ]);
      expect(parameters['director_reference_information_extracted'], [1, 1]);
      expect(parameters['director_reference_strength_values'], [0.6, 1.0]);
      expect(parameters['director_reference_secondary_strength_values'], [
        0.19999999999999996,
        0.65,
      ]);
      expect(parameters['normalize_reference_strength_multiple'], isTrue);
      expect(parameters.keys.toList(), [
        'params_version',
        'width',
        'height',
        'scale',
        'sampler',
        'steps',
        'seed',
        'n_samples',
        if (infill) ...['strength', 'noise'],
        'ucPresetId',
        'qualityPresetId',
        'autoSmea',
        'dynamic_thresholding',
        'controlnet_strength',
        'legacy',
        'add_original_image',
        'cfg_rescale',
        'noise_schedule',
        'legacy_v3_extend',
        'skip_cfg_above_sigma',
        'use_coords',
        'normalize_reference_strength_multiple',
        'inpaintImg2ImgStrength',
        'v4_prompt',
        'v4_negative_prompt',
        'legacy_uc',
        'characterPrompts',
        if (infill) ...['image', 'mask'],
        'tag_hint_qt',
        'tag_hint_uc_preset',
        if (infill) 'extra_noise_seed',
        'director_reference_images',
        'director_reference_descriptions',
        'director_reference_information_extracted',
        'director_reference_strength_values',
        'director_reference_secondary_strength_values',
        'negative_prompt',
        'deliberate_euler_ancestral_bug',
        'prefer_brownian',
        'image_format',
      ]);
    });
  }
}
