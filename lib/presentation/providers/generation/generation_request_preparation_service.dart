import 'dart:ui';

import '../../../core/utils/prompt_preset_resolution.dart';
import '../../../data/models/image/image_params.dart';

class GenerationPromptPreparation {
  const GenerationPromptPreparation({
    required this.randomModeEnabled,
    required this.queueExecuting,
    required this.generateAndApplyRandomPrompt,
    required this.resolveAliases,
    required this.applyFixedPositiveTags,
    required this.applyFixedNegativeTags,
    required this.resolvePresets,
  });

  final bool randomModeEnabled;
  final bool queueExecuting;
  final Future<String> Function(String model) generateAndApplyRandomPrompt;
  final String Function(String prompt) resolveAliases;
  final String Function(String prompt) applyFixedPositiveTags;
  final String Function(String prompt) applyFixedNegativeTags;
  final PromptPresetResolution Function(ImageParams params) resolvePresets;

  bool get randomModeActive => randomModeEnabled && !queueExecuting;
}

class GenerationCharacterPreparation {
  const GenerationCharacterPreparation({required this.read});

  final CharacterPreparationSnapshot Function(String model) read;
}

class GenerationVibePreparation {
  const GenerationVibePreparation({required this.prepare});

  final Future<ImageParams> Function(ImageParams params) prepare;
}

class GenerationFocusedPreparation {
  const GenerationFocusedPreparation({required this.read});

  final GenerationFocusedSnapshot Function() read;
}

class GenerationPreparationDependencies {
  const GenerationPreparationDependencies({
    required this.prompt,
    required this.characters,
    required this.vibes,
    required this.focused,
  });

  final GenerationPromptPreparation prompt;
  final GenerationCharacterPreparation characters;
  final GenerationVibePreparation vibes;
  final GenerationFocusedPreparation focused;
}

class CharacterPreparationSnapshot {
  const CharacterPreparationSnapshot({
    required this.characters,
    required this.useCoords,
  });

  final List<CharacterPrompt> characters;
  final bool useCoords;
}

class GenerationFocusedSnapshot {
  const GenerationFocusedSnapshot({
    required this.enabled,
    required this.minimumContextMegaPixels,
    this.selectionRect,
  });

  final bool enabled;
  final double minimumContextMegaPixels;
  final Rect? selectionRect;
}

class GenerationPreparationResult {
  const GenerationPreparationResult({
    required this.params,
    required this.randomModeActive,
    required this.focusedSnapshot,
  });

  final ImageParams params;
  final bool randomModeActive;
  final GenerationFocusedSnapshot focusedSnapshot;
}

/// Produces request snapshots without reading Riverpod or writing UI state.
class GenerationRequestPreparationService {
  const GenerationRequestPreparationService(this.dependencies);

  final GenerationPreparationDependencies dependencies;

  Future<GenerationPreparationResult> prepareInitial(ImageParams params) async {
    final promptPreparation = dependencies.prompt;
    var effective = params;
    if (promptPreparation.randomModeActive) {
      final prompt = await promptPreparation.generateAndApplyRandomPrompt(
        params.model,
      );
      if (prompt.isNotEmpty) effective = effective.copyWith(prompt: prompt);
    }

    effective = effective.copyWith(
      prompt: promptPreparation.applyFixedPositiveTags(
        promptPreparation.resolveAliases(effective.prompt),
      ),
      negativePrompt: promptPreparation.applyFixedNegativeTags(
        promptPreparation.resolveAliases(effective.negativePrompt),
      ),
    );
    final presets = promptPreparation.resolvePresets(effective);
    final characters = dependencies.characters.read(effective.model);
    effective = effective.copyWith(
      prompt: presets.prompt,
      negativePrompt: presets.negativePrompt,
      qualityToggle: presets.qualityToggle,
      ucPreset: presets.ucPreset,
      omitQualityTagHint: presets.omitQualityTagHint,
      omitUcPresetTagHint: presets.omitUcPresetTagHint,
      characters: characters.characters,
      useCoords: characters.useCoords,
    );
    effective = await dependencies.vibes.prepare(effective);
    return GenerationPreparationResult(
      params: effective,
      randomModeActive: promptPreparation.randomModeActive,
      focusedSnapshot: dependencies.focused.read(),
    );
  }

  Future<ImageParams> prepareSubsequentBatch(ImageParams currentParams) async {
    final promptPreparation = dependencies.prompt;
    if (!promptPreparation.randomModeActive) return currentParams;
    final prompt = await promptPreparation.generateAndApplyRandomPrompt(
      currentParams.model,
    );
    if (prompt.isEmpty) return currentParams;

    var preparedPrompt = promptPreparation.applyFixedPositiveTags(
      promptPreparation.resolveAliases(prompt),
    );
    preparedPrompt = promptPreparation
        .resolvePresets(
          currentParams.copyWith(prompt: preparedPrompt, negativePrompt: ''),
        )
        .prompt;
    final characters = dependencies.characters.read(currentParams.model);
    return currentParams.copyWith(
      prompt: preparedPrompt,
      characters: characters.characters,
      useCoords: characters.useCoords,
    );
  }
}
