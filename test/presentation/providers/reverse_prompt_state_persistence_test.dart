import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_labels.dart';
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';

void main() {
  group('ReversePromptState tagger categories persistence', () {
    test('round-trips the selection in display order', () {
      const state = ReversePromptState(
        taggerCategories: {
          OnnxTaggerLabelCategory.meta,
          OnnxTaggerLabelCategory.artist,
          OnnxTaggerLabelCategory.general,
        },
      );

      final json = state.toPersistedJson();
      final restored = ReversePromptState.fromPersistedJson(json);

      expect(json['taggerCategories'], ['general', 'artist', 'meta']);
      expect(restored.taggerCategories, state.taggerCategories);
    });

    test('settings saved before categories existed use the defaults', () {
      final restored = ReversePromptState.fromPersistedJson({
        'useOnnxTagger': true,
        'taggerGeneralThreshold': 0.4,
      });

      expect(
        restored.taggerCategories,
        OnnxTaggerLabelCategory.defaultPromptCategories,
      );
      expect(restored.taggerGeneralThreshold, 0.4);
    });

    test('ignores unknown names and never restores an empty selection', () {
      for (final raw in [
        <Object?>[],
        ['rating', 'other', 'unknown'],
        'general',
      ]) {
        expect(
          ReversePromptState.fromPersistedJson({
            'taggerCategories': raw,
          }).taggerCategories,
          OnnxTaggerLabelCategory.defaultPromptCategories,
          reason: '$raw',
        );
      }
      expect(
        ReversePromptState.fromPersistedJson({
          'taggerCategories': ['copyright', 'rating'],
        }).taggerCategories,
        {OnnxTaggerLabelCategory.copyright},
      );
    });
  });
}
