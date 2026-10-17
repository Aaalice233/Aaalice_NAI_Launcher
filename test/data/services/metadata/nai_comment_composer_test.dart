import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/metadata/nai_comment_composer.dart';

import '../../../helpers/novelai_exif_fixture.dart';

void main() {
  group('NaiCommentComposer.comment', () {
    test('unwraps the official envelope to its inner Comment', () {
      final envelope = novelAiEnvelopeJson(prompt: 'wrapped', seed: 5);

      expect(
        NaiCommentComposer.comment(NaiImageMetadata(rawJson: envelope)),
        (jsonDecode(envelope) as Map<String, dynamic>)['Comment'],
      );
    });

    test('keeps a recorded generation JSON byte for byte', () {
      const raw = '{"prompt": "plain", "seed": 1, "scale": 5.0}';

      expect(
        NaiCommentComposer.comment(const NaiImageMetadata(rawJson: raw)),
        raw,
      );
    });

    test('never writes non-NovelAI text as the Comment', () {
      const metadata = NaiImageMetadata(
        prompt: 'a1111 prompt',
        seed: 7,
        rawJson: 'a1111 prompt\nSteps: 20, Sampler: Euler a, Seed: 7',
      );

      expect(jsonDecode(NaiCommentComposer.comment(metadata)), {
        'prompt': 'a1111 prompt',
        'seed': 7,
      });
    });

    test('a recorded JSON without a prompt falls back to the fields', () {
      const metadata = NaiImageMetadata(
        prompt: 'fields prompt',
        rawJson: '{"seed": 9}',
      );

      expect(jsonDecode(NaiCommentComposer.comment(metadata)), {
        'prompt': 'fields prompt',
      });
    });

    test('projects only the fields the metadata knows', () {
      const metadata = NaiImageMetadata(
        prompt: 'fields prompt',
        negativePrompt: 'lowres',
        seed: 3,
        steps: 28,
        width: 64,
        height: 96,
        scale: 5.0,
        cfgRescale: 0.2,
        sampler: 'k_euler',
        noiseSchedule: 'karras',
        smea: true,
        smeaDyn: false,
        model: ImageModels.animeDiffusionV45Full,
        rawJson: '  ',
      );

      expect(jsonDecode(NaiCommentComposer.comment(metadata)), {
        'prompt': 'fields prompt',
        'uc': 'lowres',
        'seed': 3,
        'steps': 28,
        'width': 64,
        'height': 96,
        'scale': 5.0,
        'cfg_rescale': 0.2,
        'sampler': 'k_euler',
        'noise_schedule': 'karras',
        'sm': true,
        'sm_dyn': false,
        'model': ImageModels.animeDiffusionV45Full,
      });
      expect(
        jsonDecode(
          NaiCommentComposer.comment(
            const NaiImageMetadata(prompt: 'only prompt'),
          ),
        ),
        {'prompt': 'only prompt'},
      );
    });

    test('missing size comes from the pixels, recorded size wins', () {
      expect(
        jsonDecode(
          NaiCommentComposer.comment(
            const NaiImageMetadata(prompt: 'p'),
            pixelWidth: 640,
            pixelHeight: 480,
          ),
        ),
        {'prompt': 'p', 'width': 640, 'height': 480},
      );
      expect(
        jsonDecode(
          NaiCommentComposer.comment(
            const NaiImageMetadata(prompt: 'p', width: 832, height: 1216),
            pixelWidth: 640,
            pixelHeight: 480,
          ),
        ),
        {'prompt': 'p', 'width': 832, 'height': 1216},
      );
    });

    test('keeps encoded vibes and skips ones without an encoding', () {
      const metadata = NaiImageMetadata(
        prompt: 'p',
        vibeReferences: [
          VibeReference(
            displayName: 'a',
            vibeEncoding: 'encoded-a',
            strength: 0.4,
            infoExtracted: 0.9,
          ),
          VibeReference(displayName: 'raw only', vibeEncoding: ''),
        ],
      );

      final comment =
          jsonDecode(NaiCommentComposer.comment(metadata))
              as Map<String, dynamic>;
      expect(comment['reference_image_multiple'], ['encoded-a']);
      expect(comment['reference_strength_multiple'], [0.4]);
      expect(comment['reference_information_extracted_multiple'], [0.9]);
    });
  });

  group('NaiCommentComposer text fields', () {
    test('Software defaults to NovelAI and keeps a recorded value', () {
      expect(NaiCommentComposer.software(const NaiImageMetadata()), 'NovelAI');
      expect(
        NaiCommentComposer.software(
          const NaiImageMetadata(software: 'Custom Tool'),
        ),
        'Custom Tool',
      );
    });

    test('Source keeps the recorded value, else names the model', () {
      expect(
        NaiCommentComposer.source(
          const NaiImageMetadata(source: 'Stable Diffusion XL C1E1DE52'),
        ),
        'Stable Diffusion XL C1E1DE52',
      );
      expect(
        NaiCommentComposer.source(
          const NaiImageMetadata(model: ImageModels.animeDiffusionV45Full),
        ),
        'NovelAI Diffusion V4.5 4BDE2A90',
      );
      expect(NaiCommentComposer.source(const NaiImageMetadata()), isNull);
    });

    test('Description is the prompt, absent when there is none', () {
      expect(
        NaiCommentComposer.description(const NaiImageMetadata(prompt: 'p')),
        'p',
      );
      expect(NaiCommentComposer.description(const NaiImageMetadata()), isNull);
    });
  });
}
