import '../../data/models/prompt/prompt_preset_mode.dart';
import '../constants/api_constants.dart';

class PromptPresetResolution {
  const PromptPresetResolution({
    required this.prompt,
    required this.negativePrompt,
    required this.qualityToggle,
    required this.ucPreset,
    required this.omitQualityTagHint,
    required this.omitUcPresetTagHint,
  });

  final String prompt;
  final String negativePrompt;
  final bool qualityToggle;
  final int ucPreset;
  final bool omitQualityTagHint;
  final bool omitUcPresetTagHint;
}

PromptPresetResolution resolvePromptPresetSettings({
  required String prompt,
  required String negativePrompt,
  required PromptPresetMode qualityMode,
  required String? qualityContent,
  required UcPresetType ucPresetType,
  required String? ucPresetContent,
  required bool useCustomUcPreset,
}) {
  final resolvedPrompt = switch (qualityMode) {
    PromptPresetMode.custom => _joinPromptParts([prompt, qualityContent]),
    PromptPresetMode.naiDefault || PromptPresetMode.none => prompt,
  };

  final resolvedNegativePrompt = useCustomUcPreset
      ? _joinPromptParts([ucPresetContent, negativePrompt])
      : negativePrompt;

  return PromptPresetResolution(
    prompt: resolvedPrompt,
    negativePrompt: resolvedNegativePrompt,
    qualityToggle: qualityMode == PromptPresetMode.naiDefault,
    ucPreset: useCustomUcPreset
        ? UcPresets.noneApiValue
        : UcPresets.toApiValue(ucPresetType),
    omitQualityTagHint: qualityMode == PromptPresetMode.custom,
    omitUcPresetTagHint: useCustomUcPreset,
  );
}

String _joinPromptParts(Iterable<String?> parts) {
  return parts
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(', ');
}
