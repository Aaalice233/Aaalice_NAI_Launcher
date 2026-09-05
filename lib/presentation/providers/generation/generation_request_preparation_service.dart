import 'dart:ui';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../core/utils/prompt_preset_resolution.dart';
import '../../../core/utils/prompt_edit_document.dart';
import '../../../core/utils/prompt_effective_params.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';

class GenerationPromptPreparation {
  const GenerationPromptPreparation({
    required this.randomModeEnabled,
    required this.queueExecuting,
    required this.generateAndApplyRandomPrompt,
    required this.resolveAliases,
    required this.applyFixedPositiveTags,
    required this.applyFixedNegativeTags,
    required this.resolvePresets,
    required this.fixedTagUsageSnapshot,
  });

  final bool randomModeEnabled;
  final bool queueExecuting;
  final Future<String> Function(String model) generateAndApplyRandomPrompt;
  final String Function(String prompt) resolveAliases;
  final String Function(String prompt) applyFixedPositiveTags;
  final String Function(String prompt) applyFixedNegativeTags;
  final PromptPresetResolution Function(ImageParams params) resolvePresets;
  final FixedTagUsageSnapshot fixedTagUsageSnapshot;

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
    required this.fixedTagUsageSnapshot,
  });

  final ImageParams params;
  final bool randomModeActive;
  final GenerationFocusedSnapshot focusedSnapshot;
  final FixedTagUsageSnapshot fixedTagUsageSnapshot;
}

/// Produces request snapshots without reading Riverpod or writing UI state.
class GenerationRequestPreparationService {
  const GenerationRequestPreparationService(
    this.dependencies, {
    this.preserveCharacterSnapshot = false,
  });

  final GenerationPreparationDependencies dependencies;

  /// Agent confirmation and durable queue snapshots already contain the exact
  /// normalized characters and layout mode. They must not be replaced from
  /// the mutable character editor during execution.
  final bool preserveCharacterSnapshot;

  Future<GenerationPreparationResult> prepareInitial(ImageParams params) async {
    final promptPreparation = dependencies.prompt;
    var effective = effectivePromptParams(params);
    if (promptPreparation.randomModeActive) {
      final prompt = await promptPreparation.generateAndApplyRandomPrompt(
        params.model,
      );
      if (prompt.isNotEmpty) {
        effective = effective.copyWith(
          prompt: PromptEditDocument.effectiveText(prompt),
        );
      }
    }

    final resolvedPrompt = CharacterPromptBlockParser.parse(
      PromptEditDocument.effectiveText(
        promptPreparation.resolveAliases(effective.prompt),
      ),
    ).positivePrompt;
    final promptWithFixedTags = promptPreparation.applyFixedPositiveTags(
      resolvedPrompt,
    );
    final negativePromptWithFixedTags = promptPreparation
        .applyFixedNegativeTags(
          promptPreparation.resolveAliases(effective.negativePrompt),
        );
    effective = effective.copyWith(
      prompt: promptWithFixedTags,
      negativePrompt: negativePromptWithFixedTags,
    );
    final presets = promptPreparation.resolvePresets(effective);
    effective = effective.copyWith(
      prompt: presets.prompt,
      negativePrompt: presets.negativePrompt,
      qualityToggle: presets.qualityToggle,
      ucPreset: presets.ucPreset,
      omitQualityTagHint: presets.omitQualityTagHint,
      omitUcPresetTagHint: presets.omitUcPresetTagHint,
    );
    if (!preserveCharacterSnapshot) {
      final characters = dependencies.characters.read(effective.model);
      effective = effective.copyWith(
        characters: characters.characters,
        useCoords: characters.useCoords,
      );
    }
    effective = await dependencies.vibes.prepare(
      effectivePromptParams(effective),
    );
    return GenerationPreparationResult(
      params: effective,
      randomModeActive: promptPreparation.randomModeActive,
      focusedSnapshot: dependencies.focused.read(),
      fixedTagUsageSnapshot: promptPreparation.fixedTagUsageSnapshot,
    );
  }

  Future<ImageParams> prepareSubsequentBatch(ImageParams currentParams) async {
    final promptPreparation = dependencies.prompt;
    if (!promptPreparation.randomModeActive) {
      return effectivePromptParams(currentParams);
    }
    final prompt = await promptPreparation.generateAndApplyRandomPrompt(
      currentParams.model,
    );
    if (prompt.isEmpty) return effectivePromptParams(currentParams);

    final resolvedPrompt = CharacterPromptBlockParser.parse(
      PromptEditDocument.effectiveText(
        promptPreparation.resolveAliases(
          PromptEditDocument.effectiveText(prompt),
        ),
      ),
    ).positivePrompt;
    var preparedPrompt = promptPreparation.applyFixedPositiveTags(
      resolvedPrompt,
    );
    preparedPrompt = promptPreparation
        .resolvePresets(
          currentParams.copyWith(prompt: preparedPrompt, negativePrompt: ''),
        )
        .prompt;
    if (preserveCharacterSnapshot) {
      return effectivePromptParams(
        currentParams.copyWith(prompt: preparedPrompt),
      );
    }
    final characters = dependencies.characters.read(currentParams.model);
    return effectivePromptParams(
      currentParams.copyWith(
        prompt: preparedPrompt,
        characters: characters.characters,
        useCoords: characters.useCoords,
      ),
    );
  }
}
