import 'package:flutter/material.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/models/gallery/nai_metadata_prompt_projection.dart';
import '../../../../data/models/metadata/metadata_import_options.dart';
import '../../utils/fixed_tag_import_resolution.dart';
import '../../utils/metadata_import_applier.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../common/adaptive_dialog_frame.dart';
import '../common/translated_tag_text.dart';
import 'metadata_import_radio_group.dart';

/// 元数据导入对话框
///
/// 允许用户选择性地套用图片元数据中的参数
/// 新设计：按类型分组复选框，支持父子选项联动
class MetadataImportDialog extends StatefulWidget {
  final NaiImageMetadata metadata;
  final ScrollController? scrollController;
  final FixedTagImportResolution? fixedTagResolution;

  /// 初始类别开关；逐图条目总是按 [metadata] 全选。
  final MetadataImportOptions? initialOptions;

  const MetadataImportDialog({
    super.key,
    required this.metadata,
    this.scrollController,
    this.fixedTagResolution,
    this.initialOptions,
  });

  /// 显示对话框并返回用户选择的导入选项
  static Future<MetadataImportOptions?> show(
    BuildContext context, {
    required NaiImageMetadata metadata,
    FixedTagImportResolution? fixedTagResolution,
    MetadataImportOptions? initialOptions,
  }) {
    return AdaptivePresenter.showForm<MetadataImportOptions>(
      context: context,
      dialogWidth: 560,
      titleBuilder: (context) {
        final theme = Theme.of(context);
        return Row(
          children: [
            Icon(
              Icons.file_download_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.metadataImport_title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        );
      },
      builder: (context, scrollController) => MetadataImportDialog(
        metadata: metadata,
        fixedTagResolution: fixedTagResolution,
        initialOptions: initialOptions,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<MetadataImportDialog> createState() => _MetadataImportDialogState();
}

class _MetadataImportDialogState extends State<MetadataImportDialog> {
  late MetadataImportOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions ?? MetadataImportOptions.all();
    // 初始化选择列表
    _initializeSelections();
  }

  /// 初始化选择列表（默认全选）
  void _initializeSelections() {
    // 默认选择所有质量词
    final qualityTags = widget.metadata.qualityTags;
    // 默认选择所有角色
    final characterCount = widget.metadata.characterInfos.length;
    // 默认选择所有Vibe
    final vibeCount = widget.metadata.vibeReferences.length;
    // 默认选择所有精准参考
    final preciseReferenceCount = widget.metadata.preciseReferences.length;

    _options = _options.copyWith(
      selectedQualityTags: qualityTags.isNotEmpty ? List.from(qualityTags) : [],
      selectedCharacterIndices: characterCount > 0
          ? List.generate(characterCount, (i) => i)
          : [],
      selectedVibeIndices: vibeCount > 0
          ? List.generate(vibeCount, (i) => i)
          : [],
      selectedPreciseReferenceIndices: preciseReferenceCount > 0
          ? List.generate(preciseReferenceCount, (i) => i)
          : [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final selectedCount = _options.selectedCountFor(widget.metadata);

    return AdaptiveDialogFrame(
      key: const Key('metadata-import-dialog-frame'),
      maxWidth: 560,
      maxHeight: 700,
      reservedVerticalSpace: 0,
      horizontalMargin: 0,
      child: LayoutBuilder(
        builder: (context, frameConstraints) => Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('metadata-import-options-list'),
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                children: [
                  _buildQuickPresets(),
                  const SizedBox(height: 12),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  _buildPromptSection(),
                  if (_hasReferenceData()) ...[
                    const SizedBox(height: 16),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    _buildReferenceSection(),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  _buildGenerationSection(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.metadataImport_selectedCount(selectedCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: frameConstraints.maxHeight * 0.8,
              ),
              child: SingleChildScrollView(
                key: const Key('metadata-import-actions-scroll'),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stackActions =
                            constraints.maxWidth < 360 ||
                            MediaQuery.textScalerOf(context).scale(1) >= 2;
                        final cancel = TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.common_cancel),
                        );
                        final confirm = FilledButton(
                          onPressed: selectedCount == 0
                              ? null
                              : () => Navigator.of(context).pop(_options),
                          child: Text(l10n.common_confirm),
                        );
                        if (stackActions) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [confirm, cancel],
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [cancel, const SizedBox(width: 8), confirm],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建快速预设按钮区域
  Widget _buildQuickPresets() {
    final l10n = context.l10n;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.select_all, size: 18),
          label: Text(l10n.metadataImport_selectAll),
          onPressed: () => setState(() {
            _options = MetadataImportOptions.all();
            _initializeSelections();
          }),
        ),
        ActionChip(
          avatar: const Icon(Icons.text_fields, size: 18),
          label: Text(l10n.metadataImport_promptsOnly),
          onPressed: () => setState(() {
            _options = MetadataImportOptions.promptsOnly().copyWith(
              characterImportMode: _options.characterImportMode,
            );
            _initializeSelections();
          }),
        ),
        ActionChip(
          avatar: const Icon(Icons.tune, size: 18),
          label: Text(l10n.metadataImport_generationOnly),
          onPressed: () => setState(() {
            _options = MetadataImportOptions.generationOnly().copyWith(
              characterImportMode: _options.characterImportMode,
            );
            _initializeSelections();
          }),
        ),
        ActionChip(
          avatar: const Icon(Icons.deselect, size: 18),
          label: Text(l10n.metadataImport_clear),
          onPressed: () => setState(() {
            _options = MetadataImportOptions.none().copyWith(
              characterImportMode: _options.characterImportMode,
            );
          }),
        ),
      ],
    );
  }

  /// 构建提示词分组
  Widget _buildPromptSection() {
    final l10n = context.l10n;
    final metadata = widget.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          l10n.metadataImport_promptsSection,
          Icons.text_fields,
        ),
        const SizedBox(height: 8),
        // 主提示词
        _buildCheckboxTile(
          title: l10n.metadataImport_mainPrompt,
          subtitleWidget: TranslatedPromptText(
            metadata.mainPrompt,
            selectable: false,
            maxLines: 1,
          ),
          value: _options.importPrompt,
          hasData: metadata.prompt.isNotEmpty,
          onChanged: (v) =>
              setState(() => _options = _options.copyWith(importPrompt: v)),
        ),
        // 固定词（带子选项）
        if (metadata.hasSeparatedFields ||
            widget.fixedTagResolution != null) ...[
          _buildFixedTagGroup(),
          // 质量词（带子选项）
          if (metadata.qualityTags.isNotEmpty)
            _buildParentCheckboxTile(
              title: l10n.metadataImport_qualityTagsCount(
                metadata.qualityTags.length,
              ),
              value: _options.importQualityTags,
              hasData: true,
              onChanged: (v) => setState(
                () => _options = _options.copyWith(importQualityTags: v),
              ),
              children: metadata.qualityTags.asMap().entries.map((entry) {
                final tag = entry.value;
                return _buildChildCheckboxTile(
                  title: tag,
                  titleWidget: TranslatedTagText(tag),
                  value: _options.selectedQualityTags.contains(tag),
                  onChanged: _options.importQualityTags
                      ? (v) => setState(() {
                          final selected = List<String>.from(
                            _options.selectedQualityTags,
                          );
                          if (v) {
                            if (!selected.contains(tag)) selected.add(tag);
                          } else {
                            selected.remove(tag);
                          }
                          _options = _options.copyWith(
                            selectedQualityTags: selected,
                          );
                        })
                      : null,
                );
              }).toList(),
            ),
        ],
        if (metadata.characterInfos.isNotEmpty ||
            metadata.characterPrompts.isNotEmpty)
          _buildCharacterGroup(),
        // 预览与实际写入负面框的内容一致，随 UC 预设勾选变化
        _buildCheckboxTile(
          title: l10n.metadataImport_negativePrompt,
          subtitleWidget: TranslatedPromptText(
            MetadataImportApplier.resolveImportedNegativePrompt(
              metadata,
              importUcPreset: _options.importUcPreset,
            ),
            selectable: false,
            maxLines: 1,
          ),
          value: _options.importNegativePrompt,
          hasData: metadata.negativePrompt.isNotEmpty,
          onChanged: (v) => setState(
            () => _options = _options.copyWith(importNegativePrompt: v),
          ),
        ),
      ],
    );
  }

  Widget _buildFixedTagGroup() {
    final metadata = widget.metadata;
    final l10n = context.l10n;
    return _buildParentCheckboxTile(
      title: l10n.metadataImport_fixedTags,
      value: _options.importFixedTags,
      hasData:
          metadata.fixedPrefixTags.isNotEmpty ||
          metadata.fixedSuffixTags.isNotEmpty ||
          metadata.fixedNegativePrefixTags.isNotEmpty ||
          metadata.fixedNegativeSuffixTags.isNotEmpty ||
          metadata.hasExplicitFixedTagMetadata ||
          widget.fixedTagResolution?.isUnknown == true,
      onChanged: (v) =>
          setState(() => _options = _options.copyWith(importFixedTags: v)),
      children: [
        if (widget.fixedTagResolution != null)
          _buildFixedTagSource(widget.fixedTagResolution!),
        if (widget.fixedTagResolution?.isUnknown == true)
          _buildUnknownFixedTagPolicy(),
        if (metadata.fixedPrefixTags.isNotEmpty)
          _buildFixedTagCheckbox(
            metadata.fixedPrefixTags,
            l10n.metadataImport_fixedPrefix,
            _options.importFixedPrefix,
            (v) => _options.copyWith(importFixedPrefix: v),
          ),
        if (metadata.fixedSuffixTags.isNotEmpty)
          _buildFixedTagCheckbox(
            metadata.fixedSuffixTags,
            l10n.metadataImport_fixedSuffix,
            _options.importFixedSuffix,
            (v) => _options.copyWith(importFixedSuffix: v),
          ),
        if (metadata.fixedNegativePrefixTags.isNotEmpty)
          _buildFixedTagCheckbox(
            metadata.fixedNegativePrefixTags,
            l10n.metadataImport_negativeFixedPrefix,
            _options.importFixedNegativePrefix,
            (v) => _options.copyWith(importFixedNegativePrefix: v),
          ),
        if (metadata.fixedNegativeSuffixTags.isNotEmpty)
          _buildFixedTagCheckbox(
            metadata.fixedNegativeSuffixTags,
            l10n.metadataImport_negativeFixedSuffix,
            _options.importFixedNegativeSuffix,
            (v) => _options.copyWith(importFixedNegativeSuffix: v),
          ),
      ],
    );
  }

  Widget _buildFixedTagCheckbox(
    List<String> tags,
    String Function(String) label,
    bool value,
    MetadataImportOptions Function(bool) updatedOptions,
  ) {
    final prompt = tags.join(', ');
    final title = label(_truncateText(prompt, 40));
    return _buildChildCheckboxTile(
      title: title,
      titleWidget: TranslatedPromptText(
        prompt,
        originalText: title,
        selectable: false,
        maxLines: 1,
      ),
      value: value,
      onChanged: _options.importFixedTags
          ? (v) => setState(() => _options = updatedOptions(v))
          : null,
    );
  }

  Widget _buildCharacterGroup() {
    final l10n = context.l10n;
    final metadata = widget.metadata;
    final infos = metadata.characterInfos;
    final enabled = _options.importCharacterPrompts;
    return _buildParentCheckboxTile(
      title: l10n.metadataImport_characterPromptsCount(
        infos.isEmpty ? metadata.characterPrompts.length : infos.length,
      ),
      value: enabled,
      hasData: true,
      onChanged: (value) => setState(
        () => _options = _options.copyWith(importCharacterPrompts: value),
      ),
      persistentChild: MetadataImportRadioGroup<CharacterImportMode>(
        label: l10n.metadataImport_characterMode,
        value: _options.characterImportMode,
        choices: {
          CharacterImportMode.replace: l10n.metadataImport_characterReplace,
          CharacterImportMode.append: l10n.metadataImport_characterAppend,
        },
        onChanged: enabled
            ? (mode) => setState(
                () => _options = _options.copyWith(characterImportMode: mode),
              )
            : null,
      ),
      children: [
        for (var index = 0; index < infos.length; index++)
          _buildCharacterCheckbox(index),
      ],
    );
  }

  Widget _buildCharacterCheckbox(int index) {
    final prompt = NaiMetadataPromptProjection(
      widget.metadata,
    ).characterPositive(index);
    final title = context.l10n.metadataImport_characterIndex(
      index + 1,
      _truncateText(prompt, 35),
    );
    return _buildChildCheckboxTile(
      title: title,
      titleWidget: TranslatedPromptText(
        prompt,
        originalText: title,
        selectable: false,
        translationMaxLines: 1,
      ),
      value: _options.selectedCharacterIndices.contains(index),
      onChanged: (checked) => setState(() {
        final selected = _options.selectedCharacterIndices.toSet();
        if (checked) {
          selected.add(index);
        } else {
          selected.remove(index);
        }
        _options = _options.copyWith(
          selectedCharacterIndices: selected.toList(),
        );
      }),
    );
  }

  Widget _buildFixedTagSource(FixedTagImportResolution resolution) {
    final l10n = context.l10n;
    final text = switch (resolution.source) {
      FixedTagImportSource.structured =>
        l10n.metadataImport_fixedSourceStructured,
      FixedTagImportSource.legacyFields =>
        l10n.metadataImport_fixedSourceLegacy,
      FixedTagImportSource.currentLibrary =>
        l10n.metadataImport_fixedSourceLibrary,
      FixedTagImportSource.unknown => l10n.metadataImport_fixedSourceUnknown,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 8, bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildUnknownFixedTagPolicy() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: MetadataImportRadioGroup<UnknownFixedTagPolicy>(
        label: l10n.metadataImport_unknownFixedTagsHint,
        value: _options.unknownFixedTagPolicy,
        choices: {
          UnknownFixedTagPolicy.disableCurrent:
              l10n.metadataImport_disableCurrentFixedTags,
          UnknownFixedTagPolicy.keepCurrent:
              l10n.metadataImport_keepCurrentFixedTags,
        },
        onChanged: (policy) => setState(
          () => _options = _options.copyWith(unknownFixedTagPolicy: policy),
        ),
      ),
    );
  }

  bool _hasReferenceData() {
    final metadata = widget.metadata;
    return metadata.vibeReferences.isNotEmpty ||
        metadata.preciseReferences.isNotEmpty;
  }

  /// 构建参考图分组
  Widget _buildReferenceSection() {
    final l10n = context.l10n;
    final metadata = widget.metadata;
    final preciseReferences = metadata.preciseReferences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          l10n.metadataImport_referenceSection,
          Icons.auto_awesome,
        ),
        const SizedBox(height: 8),
        if (metadata.vibeReferences.isNotEmpty)
          _buildParentCheckboxTile(
            title:
                'Vibe Transfer (${l10n.metadataImport_countUnit(metadata.vibeReferences.length)})',
            value: _options.importVibeReferences,
            hasData: true,
            onChanged: (v) => setState(
              () => _options = _options.copyWith(importVibeReferences: v),
            ),
            children: metadata.vibeReferences.asMap().entries.map((entry) {
              final index = entry.key;
              final vibe = entry.value;
              return _buildChildCheckboxTile(
                title: l10n.metadataImport_vibeDetail(
                  vibe.displayName,
                  (vibe.strength * 100).toStringAsFixed(0),
                  (vibe.infoExtracted * 100).toStringAsFixed(0),
                ),
                value: _options.selectedVibeIndices.contains(index),
                onChanged: _options.importVibeReferences
                    ? (v) => setState(() {
                        final selected = List<int>.from(
                          _options.selectedVibeIndices,
                        );
                        if (v) {
                          if (!selected.contains(index)) selected.add(index);
                        } else {
                          selected.remove(index);
                        }
                        _options = _options.copyWith(
                          selectedVibeIndices: selected,
                        );
                      })
                    : null,
              );
            }).toList(),
          ),
        if (preciseReferences.isNotEmpty)
          _buildParentCheckboxTile(
            title: l10n.metadataImport_preciseReferenceCount(
              preciseReferences.length,
            ),
            value: _options.importPreciseReferences,
            hasData: true,
            onChanged: (v) => setState(
              () => _options = _options.copyWith(importPreciseReferences: v),
            ),
            children: preciseReferences.asMap().entries.map((entry) {
              final index = entry.key;
              final reference = entry.value;
              return _buildChildCheckboxTile(
                title: l10n.metadataImport_preciseReferenceDetail(
                  index + 1,
                  reference.type.toApiString(),
                  (reference.strength * 100).toStringAsFixed(0),
                  (reference.fidelity * 100).toStringAsFixed(0),
                ),
                value: _options.selectedPreciseReferenceIndices.contains(index),
                onChanged: _options.importPreciseReferences
                    ? (v) => setState(() {
                        final selected = List<int>.from(
                          _options.selectedPreciseReferenceIndices,
                        );
                        if (v) {
                          if (!selected.contains(index)) selected.add(index);
                        } else {
                          selected.remove(index);
                        }
                        _options = _options.copyWith(
                          selectedPreciseReferenceIndices: selected,
                        );
                      })
                    : null,
              );
            }).toList(),
          ),
      ],
    );
  }

  /// 构建生成参数分组
  Widget _buildGenerationSection() {
    final l10n = context.l10n;
    final options = _buildGenerationImportOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.metadataImport_generationSection, Icons.tune),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options
              .where((option) => option.hasData)
              .map(
                (option) => _buildCompactCheckbox(
                  label: option.label,
                  value: option.value,
                  hasData: option.hasData,
                  onChanged: option.onChanged,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  List<_GenerationImportOption> _buildGenerationImportOptions() {
    final l10n = context.l10n;
    final metadata = widget.metadata;

    return [
      _GenerationImportOption(
        label: l10n.generation_seed,
        value: _options.importSeed,
        hasData: metadata.seed != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importSeed: v)),
      ),
      _GenerationImportOption(
        label: _labelBeforeColon(l10n.generation_steps('')),
        value: _options.importSteps,
        hasData: metadata.steps != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importSteps: v)),
      ),
      _GenerationImportOption(
        label: _labelBeforeColon(l10n.generation_cfgScale('')),
        value: _options.importScale,
        hasData: metadata.scale != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importScale: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_imageSize,
        value: _options.importSize,
        hasData: metadata.width != null && metadata.height != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importSize: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_sampler,
        value: _options.importSampler,
        hasData: metadata.sampler != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importSampler: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_model,
        value: _options.importModel,
        hasData: metadata.effectiveModel != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importModel: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_smea,
        value: _options.importSmea,
        hasData: metadata.smea == true || metadata.smeaDyn == true,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importSmea: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_smeaDyn,
        value: _options.importSmeaDyn,
        hasData: metadata.smeaDyn == true,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importSmeaDyn: v)),
      ),
      _GenerationImportOption(
        label: 'Variety+',
        value: _options.importVarietyPlus,
        hasData: metadata.varietyPlus != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importVarietyPlus: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_noiseSchedule,
        value: _options.importNoiseSchedule,
        hasData: metadata.noiseSchedule != null,
        onChanged: (v) => setState(
          () => _options = _options.copyWith(importNoiseSchedule: v),
        ),
      ),
      _GenerationImportOption(
        label: _labelBeforeColon(l10n.generation_cfgRescale('')),
        value: _options.importCfgRescale,
        hasData: metadata.cfgRescale != null && metadata.cfgRescale! > 0,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importCfgRescale: v)),
      ),
      _GenerationImportOption(
        label: l10n.qualityTags_label,
        value: _options.importQualityToggle,
        hasData: metadata.qualityToggle != null,
        onChanged: (v) => setState(
          () => _options = _options.copyWith(importQualityToggle: v),
        ),
      ),
      _GenerationImportOption(
        label: l10n.ucPreset_label,
        value: _options.importUcPreset,
        hasData: metadata.ucPreset != null,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(importUcPreset: v)),
      ),
      _GenerationImportOption(
        label: l10n.generation_transparentBackground,
        value: _options.importTransparentBackground,
        hasData: metadata.transparentBackground != null,
        onChanged: (v) => setState(
          () => _options = _options.copyWith(importTransparentBackground: v),
        ),
      ),
    ];
  }

  /// 构建分组标题
  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建复选框列表项
  Widget _buildCheckboxTile({
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    required bool value,
    required bool hasData,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: hasData ? null : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitleWidget != null && hasData
          ? subtitleWidget
          : subtitle != null && hasData
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : !hasData
          ? Text(
              context.l10n.metadataImport_noData,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          : null,
      value: value && hasData,
      onChanged: hasData ? (v) => onChanged(v ?? false) : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  /// 构建父级复选框（带缩进子选项）
  Widget _buildParentCheckboxTile({
    required String title,
    required bool value,
    required bool hasData,
    required ValueChanged<bool> onChanged,
    required List<Widget> children,
    Widget? persistentChild,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasData ? null : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: value && hasData,
          onChanged: hasData ? (v) => onChanged(v ?? false) : null,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        // 子选项缩进显示
        if (persistentChild != null ||
            (value && hasData && children.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [?persistentChild, if (value && hasData) ...children],
            ),
          ),
      ],
    );
  }

  /// 构建子级复选框
  Widget _buildChildCheckboxTile({
    required String title,
    Widget? titleWidget,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      title:
          titleWidget ??
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: onChanged != null
                  ? null
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      value: value && onChanged != null,
      onChanged: onChanged != null ? (v) => onChanged(v ?? false) : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 构建紧凑复选框（用于生成参数）
  Widget _buildCompactCheckbox({
    required String label,
    required bool value,
    required bool hasData,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: hasData
              ? value
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: value && hasData,
      onSelected: hasData ? onChanged : null,
      showCheckmark: true,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primaryContainer,
      disabledColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 截断文本
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _labelBeforeColon(String text) {
    final colonIndex = text.indexOf(RegExp('[:：]'));
    if (colonIndex < 0) return text.trim();
    return text.substring(0, colonIndex).trim();
  }
}

class _GenerationImportOption {
  const _GenerationImportOption({
    required this.label,
    required this.value,
    required this.hasData,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool hasData;
  final ValueChanged<bool> onChanged;
}
