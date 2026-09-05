import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/services/character_conversion_service.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/utils/nai_prompt_formatter.dart';
import 'package:nai_launcher/core/utils/prompt_edit_document.dart';
import 'package:nai_launcher/core/utils/prompt_effective_params.dart';
import 'package:nai_launcher/core/utils/prompt_regex_replacer.dart';
import 'package:nai_launcher/core/utils/sd_to_nai_converter.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart' as ui;
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/prompt/prompt_regex_rule.dart';

void main() {
  test(
    'formatting, SD conversion and regex rules never rewrite disabled payloads',
    () {
      const payload = r'cat sitting， (blue eyes:1.3), <alias> */ end\';
      final marker = PromptEditDocument.disable(payload);
      final source = 'cat sitting, $marker, (blue eyes:1.3)';
      final formatted = NaiPromptFormatter.format(source);
      final converted = SdToNaiConverter.convert(source);
      final replaced = PromptRegexReplacer.apply(source, [
        const PromptRegexRule(id: 'test', pattern: 'cat', replacement: 'dog'),
      ]).text;
      for (final result in [formatted, converted, replaced]) {
        expect(result, contains(marker));
        expect(PromptEditDocument.decodeDisabled(marker), payload);
      }
      expect(replaced, startsWith('dog sitting'));
    },
  );
  test('saved JSON keeps raw markers while effective snapshots omit them', () {
    const raw = ImageParams(
      prompt: 'cat, /*disabled:<random>*/',
      negativePrompt: '/*disabled:bad*/, blur',
    );
    final restored = ImageParams.fromJson(raw.toJson());
    final effective = effectivePromptParams(restored);
    expect(restored.prompt, raw.prompt);
    expect(restored.negativePrompt, raw.negativePrompt);
    expect(effective.prompt, 'cat');
    expect(effective.negativePrompt, 'blur');
  });
  test(
    'disabled character aliases and negative blocks never reach expansion',
    () {
      final visited = <String>[];
      const config = ui.CharacterPromptConfig(
        characters: [
          ui.CharacterPrompt(
            id: 'a',
            name: 'A',
            prompt: 'cat, /*disabled:<random>, negative(hidden)*/',
            negativePrompt: 'blur, /*disabled:<secret>*/',
          ),
        ],
      );
      final result = CharacterConversionService(
        aliasResolver: (source) {
          visited.add(source);
          return source;
        },
      ).convert(config);
      expect(visited, everyElement(isNot(contains('disabled'))));
      expect(visited, everyElement(isNot(contains('<random>'))));
      expect(result.characters.single.prompt, 'cat');
      expect(result.characters.single.negativePrompt, 'blur');
      expect(config.characters.single.prompt, contains('/*disabled:'));
    },
  );
  test(
    'token encoders only receive effective text for both tokenizer families',
    () async {
      for (final model in [
        ImageModels.animeDiffusionV45Full,
        ImageModels.v5StagingKey,
      ]) {
        final encoder = _Encoder();
        await PromptTokenCounterService(
          encoder: encoder,
          qwenEncoder: encoder,
        ).countTokensForTexts([
          'cat, /*disabled:many tokens*/',
          '/*disabled:all*/',
        ], model: model);
        expect(encoder.received, ['cat']);
      }
    },
  );
}

class _Encoder implements PromptTokenEncoder {
  final received = <String>[];
  @override
  Future<int> countTokens(String text) async {
    received.add(text);
    return 1;
  }
}
