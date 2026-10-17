import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

const _inner = {'prompt': '1girl, envelope', 'uc': '', 'seed': 9, 'steps': 28};
const _source = 'NovelAI Diffusion V4.5 4BDE2A90';

void main() {
  group('NovelAI envelope attribution', () {
    test('envelope Software and Source win over side-channel fields', () {
      for (final comment in <Object>[jsonEncode(_inner), _inner]) {
        final result = UnifiedMetadataParser.parseFromTextData({
          'Comment': jsonEncode({
            'Software': 'NovelAI',
            'Source': _source,
            'Comment': comment,
          }),
          'Software': 'Other',
          'Source': 'NovelAI',
        });

        expect(result.success, isTrue, reason: result.errorMessage);
        expect(result.metadata?.source, _source);
        expect(result.metadata?.software, 'NovelAI');
        expect(result.metadata?.model, ImageModels.animeDiffusionV45Full);
      }
    });

    test('a stealth-only envelope keeps its own attribution', () {
      final result = UnifiedMetadataParser.parseFromTextData({
        'Comment': jsonEncode({
          'Software': 'NovelAI',
          'Source': _source,
          'Comment': jsonEncode(_inner),
        }),
      });

      expect(result.metadata?.source, _source);
      expect(result.metadata?.software, 'NovelAI');
    });

    test('side-channel fields fill in what the envelope lacks', () {
      final result = UnifiedMetadataParser.parseFromTextData({
        'Comment': jsonEncode({'Source': '', 'Comment': jsonEncode(_inner)}),
        'Software': 'NovelAI',
        'Source': _source,
      });

      expect(result.metadata?.source, _source);
      expect(result.metadata?.software, 'NovelAI');
    });

    test('direct comments keep the side-channel attribution', () {
      final result = UnifiedMetadataParser.parseFromTextData({
        'Comment': jsonEncode(_inner),
        'Software': 'NovelAI',
        'Source': _source,
      });

      expect(result.metadata?.source, _source);
      expect(result.metadata?.software, 'NovelAI');
    });
  });
}
