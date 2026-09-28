import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/gallery/nai_prompt_export_codec.dart';

void main() {
  group('NaiPromptExportCodec', () {
    test(
      'exports ordinary positive and negative prompts as two labeled lines',
      () {
        const metadata = NaiImageMetadata(
          prompt: '1girl, blue hair, {{{blue eyes}}}',
          negativePrompt: 'lowres, [bad anatomy]',
        );

        expect(
          NaiPromptExportCodec.encode(metadata),
          'positive: 1girl, blue hair, {{{blue eyes}}}\n'
          'negative: lowres, [bad anatomy]',
        );
      },
    );

    test(
      'keeps multi-character scopes, negatives, fixed tags and coordinates',
      () {
        const metadata = NaiImageMetadata(
          prompt: 'fixed positive, global, 1.2::cinematic lighting::',
          negativePrompt: 'fixed bad, global bad',
          fixedPrefixTags: ['fixed positive'],
          fixedNegativePrefixTags: ['fixed bad'],
          characterPrompts: ['alice, {blue eyes}', 'bob, [red hair]'],
          characterNegativePrompts: ['glasses', 'hat'],
          characterInfos: [
            CharacterPromptInfo(
              prompt: 'alice, {blue eyes}',
              negativePrompt: 'glasses',
              centerX: 0.2,
              centerY: 0.7,
            ),
            CharacterPromptInfo(
              prompt: 'bob, [red hair]',
              negativePrompt: 'hat',
              centerX: 0.8,
              centerY: 0.3,
            ),
          ],
          characterUseCoords: true,
        );

        final encoded = NaiPromptExportCodec.encode(metadata);
        expect(
          encoded,
          startsWith(
            'positive: fixed positive, global, 1.2::cinematic lighting:: | '
            'alice, {blue eyes} | bob, [red hair]\n'
            'negative: fixed bad, global bad | glasses | hat\nmetadata: ',
          ),
        );
        final decoded = NaiPromptExportCodec.tryDecode(encoded)!;
        expect(decoded.prompt, metadata.prompt);
        expect(decoded.negativePrompt, metadata.negativePrompt);
        expect(decoded.fixedPrefixTags, metadata.fixedPrefixTags);
        expect(
          decoded.fixedNegativePrefixTags,
          metadata.fixedNegativePrefixTags,
        );
        expect(decoded.characterPrompts, metadata.characterPrompts);
        expect(
          decoded.characterNegativePrompts,
          metadata.characterNegativePrompts,
        );
        expect(decoded.characterInfos[0].centerX, 0.2);
        expect(decoded.characterInfos[1].centerY, 0.3);
        expect(decoded.characterUseCoords, isTrue);
      },
    );

    test(
      'custom selection retains role boundaries without mixing negatives',
      () {
        const metadata = NaiImageMetadata(
          prompt: 'main positive',
          negativePrompt: 'main negative',
          fixedNegativePrefixTags: ['fixed negative'],
          characterPrompts: ['alice', 'bob'],
          characterNegativePrompts: ['not alice', 'not bob'],
        );
        const selection = NaiPromptCopySelection(
          characterPositiveIndices: {1},
          characterNegativeIndices: {0},
          fixedNegative: true,
        );

        final encoded = NaiPromptExportCodec.encode(
          metadata,
          selection: selection,
        );
        expect(
          encoded,
          startsWith(
            'positive: | bob\n'
            'negative: fixed negative | not alice\nmetadata: ',
          ),
        );
        final decoded = NaiPromptExportCodec.tryDecode(encoded)!;
        expect(decoded.characterPrompts, ['', 'bob']);
        expect(decoded.characterNegativePrompts, ['not alice', '']);
        expect(decoded.negativePrompt, 'fixed negative');
        expect(decoded.fixedNegativePrefixTags, ['fixed negative']);
      },
    );

    test('does not truncate source data that contains more than six roles', () {
      final prompts = List.generate(8, (index) => 'character_$index');
      final encoded = NaiPromptExportCodec.encode(
        NaiImageMetadata(prompt: 'global', characterPrompts: prompts),
      );

      for (final prompt in prompts) {
        expect(encoded, contains(prompt));
      }
    });

    test('empty metadata and empty selection never serialize as braces', () {
      const metadata = NaiImageMetadata();
      expect(NaiPromptExportCodec.encode(metadata), isEmpty);
      expect(
        NaiPromptExportCodec.encode(
          const NaiImageMetadata(prompt: 'tag'),
          selection: const NaiPromptCopySelection(),
        ),
        isEmpty,
      );
    });
  });
}
