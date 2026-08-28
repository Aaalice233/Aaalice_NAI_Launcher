import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/model_capabilities.dart';
import '../../core/services/prompt_token_counter_service.dart';
import '../../core/utils/novelai_auto_text.dart';
import '../../core/utils/prompt_preset_resolution.dart';
import '../../core/utils/character_prompt_block_parser.dart';
import '../../core/utils/prompt_semantics_utils.dart';
import '../../data/models/character/character_prompt.dart' as ui_character;
import '../../data/models/image/image_params.dart';
import '../../data/models/prompt/prompt_preset_mode.dart';
import '../../data/services/alias_resolver_service.dart';
import 'character_prompt_provider.dart';
import 'fixed_tags_provider.dart';
import 'generation/generation_params_notifier.dart';
import 'quality_preset_provider.dart';
import 'uc_preset_provider.dart';

enum PromptTokenCountTarget { positive, negative }

class PromptTokenCountPayload {
  const PromptTokenCountPayload({
    required this.mainText,
    this.extraTexts = const [],
    this.breakdown = const [],
  });

  final String mainText;
  final List<String> extraTexts;
  final List<PromptTokenCountBreakdownGroup> breakdown;
}

class PromptTokenCountBreakdownGroup {
  const PromptTokenCountBreakdownGroup({
    required this.label,
    required this.texts,
  });

  final String label;
  final List<String> texts;
}

final promptTokenCounterServiceProvider =
    FutureProvider<PromptTokenCounterService>((ref) async {
      return PromptTokenCounterService.createDefault();
    });

final promptTokenUsageProvider =
    FutureProvider.family<PromptTokenUsage?, PromptTokenCountTarget>((
      ref,
      target,
    ) async {
      final promptState = ref.watch(
        generationParamsNotifierProvider.select(
          (params) => (
            prompt: params.prompt,
            negativePrompt: params.negativePrompt,
            model: params.model,
            isEnhanceRequest:
                target == PromptTokenCountTarget.positive &&
                params.shouldApplyEnhancePromptAddition,
            transparentBackground: params.transparentBackground,
            qualityTier: params.qualityTier,
          ),
        ),
      );
      final characterConfig = ref.watch(characterPromptNotifierProvider);
      final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
      final qualityPresetState = ref.watch(qualityPresetNotifierProvider);
      final ucPresetState = ref.watch(ucPresetNotifierProvider);
      final currentQualityEntry = ref.watch(currentQualityEntryProvider);
      final currentUcEntry = ref.watch(currentUcEntryProvider);
      final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
      final service = await ref.watch(promptTokenCounterServiceProvider.future);
      final qualityContent = switch (qualityPresetState.mode) {
        PromptPresetMode.naiDefault => QualityTags.getQualityTagsForTier(
          promptState.model,
          qualityPresetState.naiTierId,
        ),
        PromptPresetMode.custom => currentQualityEntry?.content,
        PromptPresetMode.none => null,
      };
      final ucPresetContent = ucPresetState.isCustom
          ? currentUcEntry?.content
          : UcPresets.getPresetContent(
              promptState.model,
              ucPresetState.presetType,
            );

      final payload = buildPromptTokenCountPayload(
        target: target,
        prompt: promptState.prompt,
        negativePrompt: promptState.negativePrompt,
        model: promptState.model,
        fixedTagsState: fixedTagsState,
        qualityToggle: qualityPresetState.mode == PromptPresetMode.naiDefault,
        ucPreset: UcPresets.toApiValue(ucPresetState.presetType),
        qualityMode: qualityPresetState.mode,
        qualityContent: qualityContent,
        ucPresetType: ucPresetState.presetType,
        ucPresetContent: ucPresetContent,
        useCustomUcPreset: ucPresetState.isCustom,
        isEnhanceRequest: promptState.isEnhanceRequest,
        transparentBackground: promptState.transparentBackground,
        qualityTier: promptState.qualityTier,
        characters: characterConfig.characters,
        useCoords: !characterConfig.globalAiChoice,
        resolveAliases: aliasResolver.resolveAliases,
      );

      final breakdown = <PromptTokenBreakdownEntry>[];
      for (final group in payload.breakdown) {
        final tokens = await service.countTokensForTexts(
          group.texts,
          model: promptState.model,
        );
        if (tokens <= 0) {
          continue;
        }
        breakdown.add(
          PromptTokenBreakdownEntry(label: group.label, tokens: tokens),
        );
      }
      final webAdjustment = PromptTokenCounterService.webAdjustmentForModel(
        promptState.model,
      );
      if (breakdown.isNotEmpty && webAdjustment > 0) {
        breakdown.add(
          PromptTokenBreakdownEntry(label: '网页端校准', tokens: webAdjustment),
        );
      }

      return service.countUsageFromTexts(
        model: promptState.model,
        mainText: payload.mainText,
        extraTexts: payload.extraTexts,
        breakdown: breakdown,
      );
    });

@visibleForTesting
PromptTokenCountPayload buildPromptTokenCountPayload({
  required PromptTokenCountTarget target,
  required String prompt,
  required String negativePrompt,
  required String model,
  required FixedTagsState fixedTagsState,
  required bool qualityToggle,
  required int ucPreset,
  PromptPresetMode? qualityMode,
  String? qualityContent,
  UcPresetType? ucPresetType,
  String? ucPresetContent,
  bool useCustomUcPreset = false,
  bool isEnhanceRequest = false,
  required List<ui_character.CharacterPrompt> characters,
  required String Function(String text) resolveAliases,
  bool transparentBackground = false,
  String qualityTier = QualityTags.standardTier,
  bool useCoords = false,
}) {
  return switch (target) {
    PromptTokenCountTarget.positive => _buildPositiveTokenCountPayload(
      prompt: prompt,
      negativePrompt: negativePrompt,
      model: model,
      fixedTagsState: fixedTagsState,
      qualityToggle: qualityToggle,
      ucPreset: ucPreset,
      qualityMode: qualityMode,
      qualityContent: qualityContent,
      ucPresetType: ucPresetType,
      ucPresetContent: ucPresetContent,
      useCustomUcPreset: useCustomUcPreset,
      isEnhanceRequest: isEnhanceRequest,
      transparentBackground: transparentBackground,
      qualityTier: qualityTier,
      characters: characters,
      useCoords: useCoords,
      resolveAliases: resolveAliases,
    ),
    PromptTokenCountTarget.negative => _buildNegativeTokenCountPayload(
      prompt: prompt,
      negativePrompt: negativePrompt,
      model: model,
      fixedTagsState: fixedTagsState,
      qualityToggle: qualityToggle,
      ucPreset: ucPreset,
      qualityMode: qualityMode,
      qualityContent: qualityContent,
      ucPresetType: ucPresetType,
      ucPresetContent: ucPresetContent,
      useCustomUcPreset: useCustomUcPreset,
      characters: characters,
      resolveAliases: resolveAliases,
    ),
  };
}

PromptTokenCountPayload _buildPositiveTokenCountPayload({
  required String prompt,
  required String negativePrompt,
  required String model,
  required FixedTagsState fixedTagsState,
  required bool qualityToggle,
  required int ucPreset,
  required PromptPresetMode? qualityMode,
  required String? qualityContent,
  required UcPresetType? ucPresetType,
  required String? ucPresetContent,
  required bool useCustomUcPreset,
  required bool isEnhanceRequest,
  required List<ui_character.CharacterPrompt> characters,
  required String Function(String text) resolveAliases,
  bool transparentBackground = false,
  String qualityTier = QualityTags.standardTier,
  bool useCoords = false,
}) {
  final resolvedPrompt = CharacterPromptBlockParser.parse(
    resolveAliases(prompt),
  ).positivePrompt.trim();
  final resolvedNegativePrompt = resolveAliases(negativePrompt).trim();
  final promptWithFixedTags = fixedTagsState
      .applyToPrompt(resolvedPrompt)
      .trim();
  final resolvedQualityMode =
      qualityMode ??
      (qualityToggle ? PromptPresetMode.naiDefault : PromptPresetMode.none);
  final resolvedUcPresetType =
      ucPresetType ?? UcPresets.getPresetTypeFromInt(ucPreset);
  final resolvedQualityContent =
      qualityContent ?? _qualityPresetContent(model, resolvedQualityMode);
  final resolvedUcPresetContent =
      ucPresetContent ??
      UcPresets.getPresetContent(model, resolvedUcPresetType);
  final presetResolution = resolvePromptPresetSettings(
    prompt: promptWithFixedTags,
    negativePrompt: resolvedNegativePrompt,
    qualityMode: resolvedQualityMode,
    qualityContent: resolvedQualityContent,
    ucPresetType: resolvedUcPresetType,
    ucPresetContent: resolvedUcPresetContent,
    useCustomUcPreset: useCustomUcPreset,
  );
  final enabledCharacters = characters
      .where(
        (character) =>
            character.enabled &&
            (character.prompt.isNotEmpty ||
                character.negativePrompt.isNotEmpty),
      )
      .toList(growable: false);
  final resolvedCharacters = <NovelAiAutoTextCharacter>[];
  final extraTexts = <String>[];
  for (var index = 0; index < enabledCharacters.length; index++) {
    final character = enabledCharacters[index];
    final resolvedPrompt = CharacterPromptBlockParser.parse(
      resolveAliases(character.prompt),
    ).positivePrompt.trim();
    final customPosition = character.customPosition;
    final position =
        character.positionMode == ui_character.CharacterPositionMode.custom &&
            customPosition != null
        ? ui_character.CharacterPositionLayout.clampPosition(customPosition)
        : ui_character.CharacterPositionLayout.positionForIndex(
            index,
            enabledCharacters.length,
          );
    resolvedCharacters.add(
      NovelAiAutoTextCharacter(
        prompt: resolvedPrompt,
        centerX: position.column,
        centerY: position.row,
      ),
    );
    if (resolvedPrompt.isNotEmpty) extraTexts.add(resolvedPrompt);
  }

  final promptSemantics = buildPromptSemanticsSnapshot(
    prompt: presetResolution.prompt,
    negativePrompt: presetResolution.negativePrompt,
    model: model,
    qualityToggle: presetResolution.qualityToggle,
    ucPreset: presetResolution.ucPreset,
    isEnhanceRequest: isEnhanceRequest,
    transparentBackground: transparentBackground,
    qualityTier: qualityTier,
    characters: resolvedCharacters,
    useCoords: useCoords,
  );
  final fixedTagTexts = [
    ...fixedTagsState.enabledPrefixes
        .map((entry) => entry.weightedContent.trim())
        .where((text) => text.isNotEmpty),
    ...fixedTagsState.enabledSuffixes
        .map((entry) => entry.weightedContent.trim())
        .where((text) => text.isNotEmpty),
  ];
  final qualityTags = _qualityPresetContent(
    model,
    resolvedQualityMode,
    resolvedQualityContent,
  );
  // 透明背景会真的进正向提示词，明细里跟质量词算在一起，否则分项加不回总数。
  final transparencyApplies =
      transparentBackground &&
      ModelCapabilityRegistry.of(model).supportsTransparentBackground;
  final qualityBreakdownText = transparencyApplies
      ? [
          QualityTags.transparentBackgroundTag,
          qualityTags,
        ].where((text) => text.isNotEmpty).join(', ')
      : qualityTags;

  return PromptTokenCountPayload(
    mainText: promptSemantics.effectivePrompt,
    extraTexts: extraTexts,
    breakdown: [
      PromptTokenCountBreakdownGroup(label: '提示词', texts: [resolvedPrompt]),
      PromptTokenCountBreakdownGroup(label: '固定词', texts: fixedTagTexts),
      PromptTokenCountBreakdownGroup(
        label: '质量预设',
        texts: [qualityBreakdownText],
      ),
      if (promptSemantics.autoTextBlock != null)
        PromptTokenCountBreakdownGroup(
          label: '文字转录',
          texts: [promptSemantics.autoTextBlock!],
        ),
      PromptTokenCountBreakdownGroup(label: '角色', texts: extraTexts),
    ],
  );
}

PromptTokenCountPayload _buildNegativeTokenCountPayload({
  required String prompt,
  required String negativePrompt,
  required String model,
  required FixedTagsState fixedTagsState,
  required bool qualityToggle,
  required int ucPreset,
  required PromptPresetMode? qualityMode,
  required String? qualityContent,
  required UcPresetType? ucPresetType,
  required String? ucPresetContent,
  required bool useCustomUcPreset,
  required List<ui_character.CharacterPrompt> characters,
  required String Function(String text) resolveAliases,
}) {
  final resolvedPrompt = resolveAliases(prompt).trim();
  final resolvedNegativePrompt = resolveAliases(negativePrompt).trim();
  final promptWithFixedTags = fixedTagsState
      .applyToPrompt(resolvedPrompt)
      .trim();
  final negativePromptWithFixedTags = fixedTagsState
      .applyToNegativePrompt(resolvedNegativePrompt)
      .trim();
  final resolvedQualityMode =
      qualityMode ??
      (qualityToggle ? PromptPresetMode.naiDefault : PromptPresetMode.none);
  final resolvedUcPresetType =
      ucPresetType ?? UcPresets.getPresetTypeFromInt(ucPreset);
  final resolvedQualityContent =
      qualityContent ?? _qualityPresetContent(model, resolvedQualityMode);
  final resolvedUcPresetContent =
      ucPresetContent ??
      UcPresets.getPresetContent(model, resolvedUcPresetType);
  final presetResolution = resolvePromptPresetSettings(
    prompt: promptWithFixedTags,
    negativePrompt: negativePromptWithFixedTags,
    qualityMode: resolvedQualityMode,
    qualityContent: resolvedQualityContent,
    ucPresetType: resolvedUcPresetType,
    ucPresetContent: resolvedUcPresetContent,
    useCustomUcPreset: useCustomUcPreset,
  );
  final promptSemantics = buildPromptSemanticsSnapshot(
    prompt: presetResolution.prompt,
    negativePrompt: presetResolution.negativePrompt,
    model: model,
    qualityToggle: presetResolution.qualityToggle,
    ucPreset: presetResolution.ucPreset,
  );

  final extraTexts = characters
      .where((character) => character.enabled)
      .map((character) {
        final parsedPrompt = CharacterPromptBlockParser.parse(
          resolveAliases(character.prompt),
        );
        return parsedPrompt.mergeNegativePrompt(
          resolveAliases(character.negativePrompt),
        );
      })
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
  final negativeFixedTagTexts = [
    ...fixedTagsState.negativeEnabledPrefixes
        .map((entry) => entry.weightedContent.trim())
        .where((text) => text.isNotEmpty),
    ...fixedTagsState.negativeEnabledSuffixes
        .map((entry) => entry.weightedContent.trim())
        .where((text) => text.isNotEmpty),
  ];

  return PromptTokenCountPayload(
    mainText: promptSemantics.effectiveNegativePrompt,
    extraTexts: extraTexts,
    breakdown: [
      PromptTokenCountBreakdownGroup(
        label: '负面提示词',
        texts: [resolvedNegativePrompt],
      ),
      PromptTokenCountBreakdownGroup(
        label: '负面固定词',
        texts: negativeFixedTagTexts,
      ),
      PromptTokenCountBreakdownGroup(
        label: '负面预设',
        texts: [resolvedUcPresetContent.trim()],
      ),
      PromptTokenCountBreakdownGroup(label: '角色负面', texts: extraTexts),
    ],
  );
}

String _qualityPresetContent(
  String model,
  PromptPresetMode qualityMode, [
  String? qualityContent,
]) {
  return switch (qualityMode) {
    PromptPresetMode.none => '',
    PromptPresetMode.naiDefault =>
      qualityContent?.trim().isNotEmpty == true
          ? qualityContent!.trim()
          : (QualityTags.getQualityTags(model)?.trim() ?? ''),
    PromptPresetMode.custom => qualityContent?.trim() ?? '',
  };
}
