import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/services/generation_prompt_transfer_service.dart';

/// 定制回归（偏离上游）：上游 `replaceMainPrompt` 无条件做
/// `NaiPromptFormatter.format(SdToNaiConverter.convert(...))`。AI TAG 的提示词
/// 直接来自 NovelAI 元数据、本身就是 NAI 原生语法，再转一次会把自然语言描述
/// 压成下划线串。raw:true 必须让主提示词与负面提示词原样落地。
void main() {
  const naturalLanguage =
      'a girl standing in the rain, [blurry background], looking at viewer';
  const naturalNegative = 'worst quality, [text on the wall]';

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('raw transfer keeps the NAI-native prompt untouched', () {
    final container = buildContainer();

    container
        .read(generationPromptTransferServiceProvider)
        .replaceMainPrompt(
          prompt: naturalLanguage,
          negativePrompt: naturalNegative,
          raw: true,
        );

    final params = container.read(generationParamsNotifierProvider);
    expect(params.prompt, naturalLanguage);
    expect(params.negativePrompt, naturalNegative);
  });

  test('default transfer still normalizes like upstream', () {
    final container = buildContainer();

    container
        .read(generationPromptTransferServiceProvider)
        .replaceMainPrompt(
          prompt: naturalLanguage,
          negativePrompt: naturalNegative,
        );

    final params = container.read(generationParamsNotifierProvider);
    expect(params.prompt, contains('a_girl_standing_in_the_rain'));
    expect(params.negativePrompt, contains('worst_quality'));
  });
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();

  @override
  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  @override
  void updateNegativePrompt(String prompt) {
    state = state.copyWith(negativePrompt: prompt);
  }
}
