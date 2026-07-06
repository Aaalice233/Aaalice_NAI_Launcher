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
            'choices': [
              'seedvr2_a.safetensors',
              'seedvr2_b.safetensors',
            ],
            'default': 'seedvr2_a.safetensors',
          },
        ]),
        ['seedvr2_a.safetensors', 'seedvr2_b.safetensors'],
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
}
