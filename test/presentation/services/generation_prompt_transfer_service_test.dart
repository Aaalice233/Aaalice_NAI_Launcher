import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/pending_prompt_provider.dart';
import 'package:nai_launcher/presentation/services/generation_prompt_transfer_service.dart';

void main() {
  test('cross-page prompt transfer updates generation state immediately', () {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(pendingPromptNotifierProvider.notifier)
        .set(prompt: 'stale prompt');
    container
        .read(generationPromptTransferServiceProvider)
        .replaceMainPrompt(
          prompt: 'blue_archive, 1girl',
          negativePrompt: 'lowres',
        );

    final params = container.read(generationParamsNotifierProvider);
    expect(params.prompt, 'blue_archive, 1girl');
    expect(params.negativePrompt, 'lowres');
    expect(container.read(pendingPromptNotifierProvider).prompt, isNull);
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
