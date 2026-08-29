import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/nai_prompt_formatter.dart';
import '../../core/utils/sd_to_nai_converter.dart';
import '../providers/image_generation_provider.dart';
import '../providers/pending_prompt_provider.dart';

final generationPromptTransferServiceProvider =
    Provider<GenerationPromptTransferService>(
      (ref) => GenerationPromptTransferService(ref),
    );

/// Applies prompts sent from another page to the authoritative generation state.
class GenerationPromptTransferService {
  const GenerationPromptTransferService(this._ref);

  final Ref _ref;

  void replaceMainPrompt({required String prompt, String? negativePrompt}) {
    _ref.read(pendingPromptNotifierProvider.notifier).clear();
    final notifier = _ref.read(generationParamsNotifierProvider.notifier);
    final positive = prompt.trim();
    if (positive.isNotEmpty) {
      notifier.updatePrompt(_normalize(positive));
    }

    final negative = negativePrompt?.trim();
    if (negative != null && negative.isNotEmpty) {
      notifier.updateNegativePrompt(_normalize(negative));
    }
  }

  String _normalize(String prompt) =>
      NaiPromptFormatter.format(SdToNaiConverter.convert(prompt));
}
