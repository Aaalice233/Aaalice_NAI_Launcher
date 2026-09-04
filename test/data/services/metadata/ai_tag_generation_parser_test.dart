import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/ai_tag_generation_info.dart';
import 'package:nai_launcher/data/services/metadata/ai_tag_generation_parser.dart';

void main() {
  group('AiTagGenerationParser', () {
    test('parses Stable Diffusion WebUI parameters', () {
      final raw = jsonEncode({
        'parameters':
            '1girl, blue hair\nNegative prompt: lowres, blurry\n'
            'Steps: 24, Sampler: Euler a, CFG scale: 6.5, Seed: 42, '
            'Size: 768x1152, Model: pony, Model hash: abc12345',
      });

      final info = AiTagGenerationParser.parse(
        rawAiJson: raw,
        promptText: null,
        imageType: 'SD',
      );

      expect(info.software, 'Stable Diffusion WebUI');
      expect(info.prompt, '1girl, blue hair');
      expect(info.negativePrompt, 'lowres, blurry');
      expect(info.steps, 24);
      expect(info.sampler, 'Euler a');
      expect(info.cfgScale, 6.5);
      expect(info.seed, 42);
      expect((info.width, info.height), (768, 1152));
      expect(info.model, 'pony');
      expect(info.modelHash, 'abc12345');
    });

    test('uses ComfyUI graph links to distinguish prompt polarity', () {
      final raw = jsonEncode({
        '1': {
          'class_type': 'CLIPTextEncode',
          'inputs': {'text': 'lowres'},
        },
        '2': {
          'class_type': 'CLIPTextEncode',
          'inputs': {'text': '1girl'},
        },
        '3': {
          'class_type': 'KSampler',
          'inputs': {
            'positive': ['2', 0],
            'negative': ['1', 0],
            'sampler_name': 'euler',
            'scheduler': 'normal',
            'steps': 20,
            'cfg': 7,
            'seed': 123,
          },
        },
      });

      final info = AiTagGenerationParser.parse(
        rawAiJson: raw,
        promptText: null,
        imageType: 'ComfyUI',
      );

      expect(info.software, 'ComfyUI');
      expect(info.prompt, '1girl');
      expect(info.negativePrompt, 'lowres');
      expect(info.steps, 20);
      expect(info.seed, 123);
    });

    test('parses NovelAI comment and preserves the source model label', () {
      final raw = jsonEncode({
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V5 DB276663',
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'lowres',
          'steps': 28,
          'sampler': 'k_euler_ancestral',
          'scale': 5,
          'cfg_rescale': 0.2,
          'seed': 7,
          'width': 832,
          'height': 1216,
          'noise_schedule': 'karras',
          'sm': true,
          'sm_dyn': false,
        }),
      });

      final info = AiTagGenerationParser.parse(
        rawAiJson: raw,
        promptText: null,
        imageType: 'NAI',
      );

      expect(info.software, 'NovelAI');
      expect(info.model, 'NovelAI Diffusion V5 DB276663');
      expect(info.modelHash, 'DB276663');
      expect(info.prompt, '1girl');
      expect(info.negativePrompt, 'lowres');
      expect(info.cfgRescale, 0.2);
      expect(info.scheduler, 'karras');
      expect(info.smea, isTrue);
      expect(info.smeaDyn, isFalse);
    });

    test('parses a generic direct-key payload', () {
      final raw = jsonEncode({
        'model_name': 'generic-model',
        'sampler_name': 'generic-sampler',
        'steps': '18',
        'guidance_scale': '4.5',
        'seed': '99',
        'width': 640,
        'height': 960,
        'positive_prompt': 'cat',
        'negative_prompt': 'dog',
      });

      final info = AiTagGenerationParser.parse(
        rawAiJson: raw,
        promptText: null,
        imageType: 'Custom',
      );

      expect(info.model, 'generic-model');
      expect(info.sampler, 'generic-sampler');
      expect(info.steps, 18);
      expect(info.cfgScale, 4.5);
      expect(info.seed, 99);
      expect((info.width, info.height), (640, 960));
      expect(info.prompt, 'cat');
      expect(info.negativePrompt, 'dog');
    });

    test('malformed metadata falls back without throwing', () {
      final info = AiTagGenerationParser.parse(
        rawAiJson: '{broken',
        promptText: 'fallback prompt',
        imageType: 'SDXL',
      );

      expect(info.software, 'Stable Diffusion XL');
      expect(info.prompt, 'fallback prompt');
      expect(info.rawJson, '{broken');
    });
  });

  test('AiTagGenerationInfo survives metadata serialization', () {
    const original = AiTagGenerationInfo(
      software: 'NovelAI',
      model: 'NovelAI Diffusion V5 DB276663',
      sampler: 'k_euler',
      steps: 28,
      cfgScale: 5,
      seed: 42,
      loras: ['style.safetensors'],
      loraStrengths: [0.75],
      extra: {'Model ID': 'nai-diffusion-5-full'},
      prettyJson: '{\n  "seed": 42\n}',
      rawJson: '{"seed":42}',
    );

    final restored = AiTagGenerationInfo.tryFromMediaMetadata({
      'aiTag': jsonEncode(original.toJson()),
    });

    expect(restored, isNotNull);
    expect(restored!.model, original.model);
    expect(restored.seed, original.seed);
    expect(restored.loras, original.loras);
    expect(restored.loraStrengths, original.loraStrengths);
    expect(restored.extra, original.extra);
    expect(restored.rawJson, original.rawJson);
  });

  test('AiTagGenerationInfo counts every displayed parameter', () {
    const variants = [
      AiTagGenerationInfo(clip: 'clip', prettyJson: '', rawJson: ''),
      AiTagGenerationInfo(height: 1024, prettyJson: '', rawJson: ''),
      AiTagGenerationInfo(shift: 2, prettyJson: '', rawJson: ''),
      AiTagGenerationInfo(denoise: 0.5, prettyJson: '', rawJson: ''),
    ];

    expect(variants.every((info) => info.hasAnyParam), isTrue);
  });
}
