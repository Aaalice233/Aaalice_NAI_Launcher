import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/comfyui_api_service.dart';
import 'package:nai_launcher/core/comfyui/object_info_parser.dart';

void main() {
  group('extractChoiceListFromObjectInfoField', () {
    test('should parse nested choice arrays from object_info', () {
      expect(
        extractChoiceListFromObjectInfoField([
          ['seedvr2_a.safetensors', 'seedvr2_b.safetensors'],
          {'default': 'seedvr2_a.safetensors'},
        ]),
        ['seedvr2_a.safetensors', 'seedvr2_b.safetensors'],
      );
    });

    test('should parse COMBO sentinel with embedded choices', () {
      expect(
        extractChoiceListFromObjectInfoField([
          'COMBO',
          {
            'choices': ['seedvr2_a.safetensors', 'seedvr2_b.safetensors'],
            'default': 'seedvr2_a.safetensors',
          },
        ]),
        ['seedvr2_a.safetensors', 'seedvr2_b.safetensors'],
      );
    });

    test('should parse custom-node COMBO options from live object_info', () {
      expect(
        extractChoiceListFromObjectInfoField([
          'COMBO',
          {
            'options': [
              'seedvr2_ema_3b-Q4_K_M.gguf',
              'seedvr2_ema_7b_fp16.safetensors',
            ],
            'default': 'seedvr2_ema_3b-Q4_K_M.gguf',
          },
        ]),
        ['seedvr2_ema_3b-Q4_K_M.gguf', 'seedvr2_ema_7b_fp16.safetensors'],
      );
    });
  });

  group('extractHistoryImageRefs', () {
    test('should keep only configured output nodes', () {
      final refs = extractHistoryImageRefs(
        {
          'outputs': {
            '15': {
              'images': [
                {'filename': 'input_preview.png', 'type': 'temp'},
              ],
            },
            '17': {
              'images': [
                {'filename': 'upscaled.png', 'type': 'output'},
              ],
            },
          },
        },
        allowedNodeIds: {'17'},
      );

      expect(refs.map((ref) => ref.filename).toList(), ['upscaled.png']);
    });

    test('should fail loudly when configured output nodes have no images', () {
      expect(
        () => extractHistoryImageRefs(
          {
            'outputs': {
              '15': {
                'images': [
                  {'filename': 'input_preview.png', 'type': 'temp'},
                ],
              },
            },
          },
          allowedNodeIds: {'17'},
        ),
        throwsA(isA<ComfyUIApiException>()),
      );
    });
  });

  group('formatComfyUIErrorResponse', () {
    test('prefers actionable node validation errors', () {
      final detail = formatComfyUIErrorResponse({
        'error': {
          'type': 'prompt_outputs_failed_validation',
          'message': 'Prompt outputs failed validation',
          'details': '',
        },
        'node_errors': {
          '8': {
            'class_type': 'SeedVR2TilingUpscaler',
            'errors': [
              {
                'message': 'Required input is missing',
                'details': 'tile_batch_size',
              },
            ],
          },
        },
      });

      expect(detail, contains('节点 8 (SeedVR2TilingUpscaler)'));
      expect(detail, contains('Required input is missing: tile_batch_size'));
      expect(detail, isNot(contains('prompt_outputs_failed_validation')));
    });
  });
}
