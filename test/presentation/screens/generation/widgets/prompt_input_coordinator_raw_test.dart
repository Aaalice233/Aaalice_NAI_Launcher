import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/pending_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_coordinator.dart';

const hostKey = ValueKey('prompt-input-coordinator-host');

/// 定制回归（偏离上游）：上游 `consumePendingPrompt` 无条件把待填充提示词
/// 过一遍 `NaiPromptFormatter.format(SdToNaiConverter.convert(...))`。
/// `PendingPromptState.raw` 为真时，主提示词与负面提示词必须原样落地，
/// 否则 AI TAG 的自然语言描述会被压成下划线串。
void main() {
  const naturalLanguage =
      'a girl standing in the rain, [blurry background], looking at viewer';
  const naturalNegative = 'worst quality, [text on the wall]';

  Future<PromptInputController> pumpCoordinatorHost(
    WidgetTester tester, {
    required bool raw,
  }) async {
    final controller = PromptInputController(prompt: '', negativePrompt: '');
    addTearDown(controller.dispose);

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          generationParamsNotifierProvider.overrideWith(
            _TestGenerationParamsNotifier.new,
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink(key: hostKey);
            },
          ),
        ),
      ),
    );

    final host = tester.element(find.byKey(hostKey));
    ProviderScope.containerOf(host)
        .read(pendingPromptNotifierProvider.notifier)
        .set(
          prompt: naturalLanguage,
          negativePrompt: naturalNegative,
          raw: raw,
        );

    PromptInputCoordinator(
      ref: capturedRef,
      controller: controller,
      context: () => host,
      mounted: () => true,
    ).consumePendingPrompt();
    await tester.pump();

    return controller;
  }

  testWidgets('raw pending prompt lands verbatim', (tester) async {
    final controller = await pumpCoordinatorHost(tester, raw: true);

    expect(controller.promptController.text, naturalLanguage);
    expect(controller.negativeController.text, naturalNegative);
  });

  testWidgets('non-raw pending prompt still normalizes like upstream', (
    tester,
  ) async {
    final controller = await pumpCoordinatorHost(tester, raw: false);

    expect(
      controller.promptController.text,
      contains('a_girl_standing_in_the_rain'),
    );
    expect(controller.negativeController.text, contains('worst_quality'));
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
