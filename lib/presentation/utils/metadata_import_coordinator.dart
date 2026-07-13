import 'package:flutter/material.dart';

import '../../data/models/character/character_prompt.dart' as char;
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/metadata/metadata_import_options.dart';
import '../../l10n/app_localizations.dart';
import '../providers/character_prompt_provider.dart';
import '../providers/fixed_tags_provider.dart';
import '../providers/image_generation_provider.dart';
import 'metadata_import_applier.dart';
import 'prompt_preset_import_utils.dart';

class MetadataImportCoordinator {
  const MetadataImportCoordinator._();

  static Future<int> apply({
    required ProviderReader read,
    required NaiImageMetadata metadata,
    required MetadataImportOptions options,
  }) async {
    final notifier = read(generationParamsNotifierProvider.notifier);
    final characterPrompts = metadata.characterPrompts;

    if (options.importCharacterPrompts && characterPrompts.isNotEmpty) {
      read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    }

    final currentModel = read(generationParamsNotifierProvider).model;
    var appliedCount = MetadataImportApplier.applyPromptAndGenerationParams(
      metadata: metadata,
      options: options,
      currentModel: currentModel,
      target: MetadataImportTarget(
        updatePrompt: notifier.updatePrompt,
        updateNegativePrompt: notifier.updateNegativePrompt,
        updateSeed: notifier.updateSeed,
        updateSteps: notifier.updateSteps,
        updateScale: notifier.updateScale,
        updateSize: notifier.updateSize,
        updateSampler: notifier.updateSampler,
        updateModel: notifier.updateModel,
        updateSmea: notifier.updateSmea,
        updateSmeaDyn: notifier.updateSmeaDyn,
        updateVarietyPlus: notifier.updateVarietyPlus,
        updateNoiseSchedule: notifier.updateNoiseSchedule,
        updateCfgRescale: notifier.updateCfgRescale,
        updateQualityToggle: (value) {
          notifier.updateQualityToggle(value);
          applyImportedQualityToggle(read, value);
        },
        updateUcPreset: (value) {
          notifier.updateUcPreset(value);
          applyImportedUcPreset(read, value);
        },
      ),
    );

    if (options.importCharacterPrompts && characterPrompts.isNotEmpty) {
      _applyCharacterPrompts(read, metadata);
      appliedCount++;
    }

    appliedCount += _applyReferenceParams(read, metadata, options);
    appliedCount += await _applyFixedTags(read, metadata, options);

    return appliedCount;
  }

  static Future<void> showAppliedDialog({
    required BuildContext context,
    required NaiImageMetadata metadata,
    required MetadataImportOptions options,
    required AppLocalizations l10n,
    required String currentModel,
  }) {
    final items = _buildMetadataItems(metadata, options, l10n, currentModel);

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(l10n.metadataImport_appliedTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.metadataImport_appliedDescription),
              const SizedBox(height: 12),
              ...items,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  static Future<int> _applyFixedTags(
    ProviderReader read,
    NaiImageMetadata metadata,
    MetadataImportOptions options,
  ) async {
    if (!options.importFixedTags) {
      return 0;
    }

    final fixedTagsNotifier = read(fixedTagsNotifierProvider.notifier);
    var added = 0;

    Future<void> addTags(
      List<String> tags, {
      required FixedTagPosition position,
      required FixedTagPromptType promptType,
      required String prefix,
    }) async {
      for (final tag in tags) {
        final content = tag.trim();
        if (content.isEmpty) {
          continue;
        }
        await fixedTagsNotifier.addEntry(
          name: '$prefix$content',
          content: content,
          position: position,
          promptType: promptType,
          enabled: true,
        );
        added++;
      }
    }

    if (options.importFixedPrefix) {
      await addTags(
        metadata.fixedPrefixTags,
        position: FixedTagPosition.prefix,
        promptType: FixedTagPromptType.positive,
        prefix: '导入前缀: ',
      );
      await addTags(
        metadata.fixedNegativePrefixTags,
        position: FixedTagPosition.prefix,
        promptType: FixedTagPromptType.negative,
        prefix: '导入负向前缀: ',
      );
    }

    if (options.importFixedSuffix) {
      await addTags(
        metadata.fixedSuffixTags,
        position: FixedTagPosition.suffix,
        promptType: FixedTagPromptType.positive,
        prefix: '导入后缀: ',
      );
      await addTags(
        metadata.fixedNegativeSuffixTags,
        position: FixedTagPosition.suffix,
        promptType: FixedTagPromptType.negative,
        prefix: '导入负向后缀: ',
      );
    }

    return added > 0 ? 1 : 0;
  }

  static void _applyCharacterPrompts(
    ProviderReader read,
    NaiImageMetadata metadata,
  ) {
    final characters = <char.CharacterPrompt>[];
    final negativePrompts = metadata.characterNegativePrompts;

    for (var i = 0; i < metadata.characterPrompts.length; i++) {
      final prompt = metadata.characterPrompts[i];
      final negativePrompt = i < negativePrompts.length
          ? negativePrompts[i]
          : '';

      characters.add(
        char.CharacterPrompt.create(
          name: 'Character ${i + 1}',
          gender: _inferGenderFromPrompt(prompt),
          prompt: prompt,
          negativePrompt: negativePrompt,
        ),
      );
    }

    read(characterPromptNotifierProvider.notifier).replaceAll(characters);
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
            strength: reference.strength,
            fidelity: reference.fidelity,
          );
        }
        count++;
      }
    }

    return count;
  }

  static List<Widget> _buildMetadataItems(
    NaiImageMetadata metadata,
    MetadataImportOptions options,
    AppLocalizations l10n,
    String currentModel,
  ) {
    final items = <Widget>[];
    final negativePrompt = MetadataImportApplier.resolveImportedNegativePrompt(
      metadata,
      importUcPreset: options.importUcPreset,
      currentModel: currentModel,
    );
    final importableModel = MetadataImportApplier.resolveImportableModel(
      metadata,
    );

    final itemConfigs = <(bool, String, String?, int)>[
      (
        options.importPrompt && metadata.prompt.isNotEmpty,
        l10n.metadataImport_prompt,
        metadata.prompt,
        3,
      ),
      (
        options.importNegativePrompt && negativePrompt.isNotEmpty,
        l10n.metadataImport_negativePrompt,
        negativePrompt,
        2,
      ),
      (
        options.importFixedTags &&
            (options.importFixedPrefix || options.importFixedSuffix) &&
            (metadata.fixedPrefixTags.isNotEmpty ||
                metadata.fixedSuffixTags.isNotEmpty ||
                metadata.fixedNegativePrefixTags.isNotEmpty ||
                metadata.fixedNegativeSuffixTags.isNotEmpty),
        l10n.metadataImport_fixedTags,
        [
          if (options.importFixedPrefix) ...metadata.fixedPrefixTags,
          if (options.importFixedSuffix) ...metadata.fixedSuffixTags,
          if (options.importFixedPrefix) ...metadata.fixedNegativePrefixTags,
          if (options.importFixedSuffix) ...metadata.fixedNegativeSuffixTags,
        ].join(', '),
        2,
      ),
      (
        options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty,
        l10n.metadataImport_characterPrompts,
        '${metadata.characterPrompts.length} '
            '${l10n.metadataImport_charactersCount}',
        1,
      ),
      (
        options.importVibeReferences && metadata.vibeReferences.isNotEmpty,
        l10n.vibe_title,
        l10n.metadataImport_countUnit(metadata.vibeReferences.length),
        1,
      ),
      (
        options.importPreciseReferences &&
            metadata.preciseReferences.isNotEmpty,
        l10n.preciseRef_title,
        l10n.metadataImport_countUnit(metadata.preciseReferences.length),
        1,
      ),
      (
        options.importSeed && metadata.seed != null,
        l10n.metadataImport_seed,
        metadata.seed?.toString(),
        1,
      ),
      (
        options.importSteps && metadata.steps != null,
        l10n.metadataImport_steps,
        metadata.steps?.toString(),
        1,
      ),
      (
        options.importScale && metadata.scale != null,
        l10n.metadataImport_scale,
        metadata.scale?.toString(),
        1,
      ),
      (
        options.importSize && metadata.width != null && metadata.height != null,
        l10n.metadataImport_size,
        '${metadata.width} x ${metadata.height}',
        1,
      ),
      (
        options.importSampler && metadata.sampler != null,
        l10n.metadataImport_sampler,
        metadata.displaySampler,
        1,
      ),
      (
        options.importModel && importableModel != null,
        l10n.metadataImport_model,
        importableModel,
        1,
      ),
      (
        options.importSmea && metadata.smea != null,
        l10n.metadataImport_smea,
        metadata.smea?.toString(),
        1,
      ),
      (
        options.importSmeaDyn && metadata.smeaDyn != null,
        l10n.metadataImport_smeaDyn,
        metadata.smeaDyn?.toString(),
        1,
      ),
      (
        options.importVarietyPlus && metadata.varietyPlus != null,
        'Variety+',
        metadata.varietyPlus?.toString(),
        1,
      ),
      (
        options.importNoiseSchedule && metadata.noiseSchedule != null,
        l10n.metadataImport_noiseSchedule,
        metadata.noiseSchedule?.toString(),
        1,
      ),
      (
        options.importCfgRescale && metadata.cfgRescale != null,
        l10n.metadataImport_cfgRescale,
        metadata.cfgRescale?.toString(),
        1,
      ),
      (
        options.importQualityToggle && metadata.qualityToggle != null,
        l10n.metadataImport_qualityToggle,
        metadata.qualityToggle?.toString(),
        1,
      ),
      (
        options.importUcPreset && metadata.ucPreset != null,
        l10n.metadataImport_ucPreset,
        metadata.ucPreset?.toString(),
        1,
      ),
    ];

    for (final (shouldShow, label, value, maxLines) in itemConfigs) {
      if (shouldShow && value != null) {
        items.add(_buildAppliedItem(label, value, maxLines: maxLines));
      }
    }

    return items;
  }

  static Widget _buildAppliedItem(
    String label,
    String value, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
