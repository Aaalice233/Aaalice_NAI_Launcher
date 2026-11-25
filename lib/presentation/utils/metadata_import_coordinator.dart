import '../../core/constants/model_capabilities.dart';
import '../../data/models/character/character_prompt.dart' as char;
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/gallery/nai_metadata_prompt_projection.dart';
import '../../data/models/metadata/metadata_import_options.dart';
import '../../l10n/app_localizations.dart';
import '../providers/character_prompt_provider.dart';
import '../providers/fixed_tags_provider.dart';
import '../providers/image_generation_provider.dart';
import '../providers/quality_preset_provider.dart';
import 'metadata_import_applier.dart';
import 'fixed_tag_import_resolution.dart';
import 'prompt_preset_import_utils.dart';

typedef CharacterAppendCounts = ({int added, int skipped, int limit});

class MetadataImportOutcome {
  const MetadataImportOutcome(this.appliedCount, {this.characterAppend})
    : characterConflictLimit = null,
      existingCharacterCount = null;

  const MetadataImportOutcome.characterConflict(
    int limit, {
    this.existingCharacterCount,
  }) : appliedCount = 0,
       characterAppend = null,
       characterConflictLimit = limit;

  final int appliedCount;
  final CharacterAppendCounts? characterAppend;
  final int? characterConflictLimit;
  final int? existingCharacterCount;
}

class MetadataImportCoordinator {
  const MetadataImportCoordinator._();

  static Future<MetadataImportOutcome> apply({
    required ProviderReader read,
    required NaiImageMetadata metadata,
    required MetadataImportOptions options,
    required AppLocalizations l10n,
    FixedTagImportResolution? fixedTagResolution,
  }) async {
    final resolution =
        fixedTagResolution ??
        resolveFixedTagImport(
          metadata: metadata,
          entries: read(fixedTagsNotifierProvider).entries,
        );
    final resolvedMetadata = resolution.metadata;
    final characterIndices = _selectedCharacterIndices(
      resolvedMetadata,
      options,
    );

    if (characterIndices.isNotEmpty) {
      final currentModel = read(generationParamsNotifierProvider).model;
      final importedModel = options.importModel
          ? MetadataImportApplier.resolveImportableModel(resolvedMetadata)
          : null;
      final targetModel = importedModel ?? currentModel;
      final limit = ModelCapabilityRegistry.of(targetModel).maxCharacters;
      if (limit == 0) {
        return const MetadataImportOutcome.characterConflict(0);
      }
      if (options.characterImportMode == CharacterImportMode.append &&
          targetModel != currentModel) {
        final count = read(characterPromptNotifierProvider).characters.length;
        if (count > limit) {
          return MetadataImportOutcome.characterConflict(
            limit,
            existingCharacterCount: count,
          );
        }
      }
    }

    var appliedCount = _applyGenerationParams(read, resolvedMetadata, options);
    CharacterAppendCounts? append;
    if (characterIndices.isNotEmpty) {
      append = _applyCharacterPrompts(
        read,
        resolvedMetadata,
        characterIndices,
        options.characterImportMode,
      );
      if (append == null || append.added > 0) appliedCount++;
    }
    appliedCount += _applyReferenceParams(read, resolvedMetadata, options);
    appliedCount += await _applyFixedTags(
      read,
      resolvedMetadata,
      options,
      l10n,
      resolution,
    );
    return MetadataImportOutcome(appliedCount, characterAppend: append);
  }

  static int _applyGenerationParams(
    ProviderReader read,
    NaiImageMetadata metadata,
    MetadataImportOptions options,
  ) {
    final notifier = read(generationParamsNotifierProvider.notifier);
    return MetadataImportApplier.applyPromptAndGenerationParams(
      metadata: metadata,
      options: options,
      target: MetadataImportTarget(
        updatePrompt: notifier.updatePrompt,
        updateNegativePrompt: notifier.updateNegativePrompt,
        updateSeed: notifier.updateSeed,
        updateSteps: notifier.updateSteps,
        updateScale: notifier.updateScale,
        updateSize: notifier.updateSize,
        updateSampler: notifier.updateSampler,
        updateModel: (value) =>
            notifier.updateModel(value, followDefaults: false),
        updateSmea: notifier.updateSmea,
        updateSmeaDyn: notifier.updateSmeaDyn,
        updateVarietyPlus: notifier.updateVarietyPlus,
        updateNoiseSchedule: notifier.updateNoiseSchedule,
        updateCfgRescale: notifier.updateCfgRescale,
        updateQualityToggle: (value) {
          notifier.updateQualityToggle(value);
          applyImportedQualityToggle(read, value);
        },
        updateQualityTier: (value) {
          read(qualityPresetNotifierProvider.notifier).setNaiTier(value);
        },
        updateUcPreset: (value) {
          notifier.updateUcPreset(value);
          applyImportedUcPreset(read, value);
        },
        updateTransparentBackground: notifier.updateTransparentBackground,
        updateModelMode: notifier.updateModelMode,
      ),
    );
  }

  static Future<int> _applyFixedTags(
    ProviderReader read,
    NaiImageMetadata metadata,
    MetadataImportOptions options,
    AppLocalizations l10n,
    FixedTagImportResolution resolution,
  ) async {
    if (!options.importFixedTags) {
      return 0;
    }

    final scopes = <FixedTagScope>{};
    void addSelectedScopes(FixedTagPromptType promptType) {
      final isPositive = promptType == FixedTagPromptType.positive;
      if (isPositive
          ? options.importFixedPrefix
          : options.importFixedNegativePrefix) {
        scopes.add(FixedTagScope(promptType, FixedTagPosition.prefix));
      }
      if (isPositive
          ? options.importFixedSuffix
          : options.importFixedNegativeSuffix) {
        scopes.add(FixedTagScope(promptType, FixedTagPosition.suffix));
      }
    }

    FixedTagUsageSnapshot snapshot;
    if (resolution.isUnknown) {
      if (options.unknownFixedTagPolicy == UnknownFixedTagPolicy.keepCurrent) {
        return 0;
      }
      if (options.importPrompt && metadata.prompt.isNotEmpty) {
        addSelectedScopes(FixedTagPromptType.positive);
      }
      if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
        addSelectedScopes(FixedTagPromptType.negative);
      }
      snapshot = const FixedTagUsageSnapshot();
    } else {
      addSelectedScopes(FixedTagPromptType.positive);
      addSelectedScopes(FixedTagPromptType.negative);
      snapshot = resolution.snapshot ?? const FixedTagUsageSnapshot();
    }
    if (scopes.isEmpty) return 0;

    await read(fixedTagsNotifierProvider.notifier).restoreUsageSnapshot(
      snapshot: snapshot,
      scopes: scopes,
      buildImageVersionName: l10n.metadataImport_imageVersionName,
    );
    return 1;
  }

  // 旧元数据没有逐角色信息，导入对话框只提供总开关，此时整体导入。
  static List<int> _selectedCharacterIndices(
    NaiImageMetadata metadata,
    MetadataImportOptions options,
  ) {
    if (!options.importCharacterPrompts) return const [];
    if (metadata.characterInfos.isEmpty) {
      return List<int>.generate(
        metadata.characterPrompts.length,
        (index) => index,
      );
    }
    final selected = options.selectedCharacterIndices.toSet();
    return [
      for (var index = 0; index < metadata.characterInfos.length; index++)
        if (selected.contains(index)) index,
    ];
  }

  static CharacterAppendCounts? _applyCharacterPrompts(
    ProviderReader read,
    NaiImageMetadata metadata,
    List<int> indices,
    CharacterImportMode mode,
  ) {
    final notifier = read(characterPromptNotifierProvider.notifier);
    final append = mode == CharacterImportMode.append;
    final offset = append
        ? read(characterPromptNotifierProvider).characters.length
        : 0;
    final incoming = indices.indexed.map(
      (entry) => _importCharacter(metadata, entry.$2, offset + entry.$1 + 1),
    );
    if (append) {
      final added = notifier.appendCharacters(incoming);
      return (
        added: added,
        skipped: indices.length - added,
        limit: notifier.characterLimit,
      );
    }
    final characters = incoming.toList();
    final useCoords =
        metadata.characterUseCoords ??
        characters.any((character) => character.customPosition != null);
    notifier.replaceCharacters(characters, globalAiChoice: !useCoords);
    return null;
  }

  static char.CharacterPrompt _importCharacter(
    NaiImageMetadata metadata,
    int i,
    int number,
  ) {
    final negativePrompts = metadata.characterNegativePrompts;
    final characterInfos = metadata.characterInfos;
    final info = i < characterInfos.length ? characterInfos[i] : null;
    final prompt = NaiMetadataPromptProjection(metadata).characterPositive(i);
    final negativePrompt =
        info?.negativePrompt ??
        (i < negativePrompts.length ? negativePrompts[i] : '');
    final centerX = info?.centerX;
    final centerY = info?.centerY;
    final hasCenter =
        centerX != null &&
        centerY != null &&
        centerX.isFinite &&
        centerY.isFinite;
    return char.CharacterPrompt.create(
      name: 'Character $number',
      gender: _inferGenderFromPrompt(prompt),
      prompt: prompt,
      negativePrompt: negativePrompt,
      positionMode: hasCenter
          ? char.CharacterPositionMode.custom
          : char.CharacterPositionMode.aiChoice,
      customPosition: hasCenter
          ? char.CharacterPosition(
              mode: char.CharacterPositionMode.custom,
              row: centerY.clamp(0.0, 1.0),
              column: centerX.clamp(0.0, 1.0),
            )
          : null,
    );
  }

  static char.CharacterGender _inferGenderFromPrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('1girl') ||
        lowerPrompt.contains('girl,') ||
        lowerPrompt.startsWith('girl')) {
      return char.CharacterGender.female;
    }
    if (lowerPrompt.contains('1boy') ||
        lowerPrompt.contains('boy,') ||
        lowerPrompt.startsWith('boy')) {
      return char.CharacterGender.male;
    }
    return char.CharacterGender.other;
  }

  static int _applyReferenceParams(
    ProviderReader read,
    NaiImageMetadata metadata,
    MetadataImportOptions options,
  ) {
    final notifier = read(generationParamsNotifierProvider.notifier);
    var count = 0;

    if (options.importVibeReferences && metadata.vibeReferences.isNotEmpty) {
      final selectedVibes = metadata.vibeReferences
          .asMap()
          .entries
          .where((entry) => options.selectedVibeIndices.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
      if (selectedVibes.isNotEmpty) {
        notifier.clearVibeReferences();
        notifier.addVibeReferences(selectedVibes, recordUsage: false);
        count++;
      }
    }

    final preciseReferences = metadata.preciseReferences;
    if (options.importPreciseReferences && preciseReferences.isNotEmpty) {
      final selectedReferences = preciseReferences
          .asMap()
          .entries
          .where(
            (entry) =>
                options.selectedPreciseReferenceIndices.contains(entry.key),
          )
          .map((entry) => entry.value)
          .toList();
      if (selectedReferences.isNotEmpty) {
        notifier.clearPreciseReferences();
        for (final reference in selectedReferences) {
          notifier.addPreciseReference(
            reference.image,
            type: reference.type,
            preferSameOutfit: reference.preferSameOutfit,
            strength: reference.strength,
            fidelity: reference.fidelity,
          );
        }
        count++;
      }
    }

    return count;
  }
}
