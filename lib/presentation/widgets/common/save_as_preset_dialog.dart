import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import 'package:uuid/uuid.dart';

import '../../../../data/models/gallery/nai_image_metadata.dart';

import '../../../../data/models/prompt/algorithm_config.dart';
import '../../../../data/models/prompt/character_count_config.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../../../presentation/providers/random_preset_provider.dart'
    show randomPresetNotifierProvider;
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/content_sized_adaptive_form.dart';
import 'app_toast.dart';

/// 保存为预设对话框
///
/// 用于将图片元数据保存为快速预设
class SaveAsPresetDialog extends ConsumerStatefulWidget {
  /// 要保存的元数据
  final NaiImageMetadata metadata;
  final ScrollController? scrollController;

  const SaveAsPresetDialog({
    super.key,
    required this.metadata,
    this.scrollController,
  });

  /// 显示对话框
  static Future<bool> show(
    BuildContext context, {
    required NaiImageMetadata metadata,
  }) async {
    final result = await AdaptivePresenter.showForm<bool>(
      context: context,
      dialogWidth: 460,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.bookmark_add,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              panelContext.l10n.savePreset_title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(panelContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: (_, scrollController) => SaveAsPresetDialog(
        metadata: metadata,
        scrollController: scrollController,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SaveAsPresetDialog> createState() => _SaveAsPresetDialogState();
}

class _SaveAsPresetDialogState extends ConsumerState<SaveAsPresetDialog> {
  late final TextEditingController _nameController;

  // 选项状态
  late bool _includePrompt;
  late bool _includeFixedTags;
  late bool _includeQualityTags;
  late bool _includeNegativePrompt;
  late bool _includeSeed;
  late bool _includeSteps;
  late bool _includeScale;
  late bool _includeSize;
  late bool _includeSampler;
  late bool _includeModel;
  late bool _includeSmea;
  late bool _includeVibe;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 生成默认名称（使用提示词前几个词 + 种子）
    _nameController = TextEditingController(
      text: _generateDefaultName(widget.metadata),
    );

    _resetSelection();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 生成默认名称
  String _generateDefaultName(NaiImageMetadata metadata) {
    final promptPart = metadata.mainPrompt.split(',').first.trim();
    final seedPart = metadata.seed != null ? '_${metadata.seed}' : '';
    if (promptPart.length > 15) {
      return '${promptPart.substring(0, 15)}...$seedPart';
    }
    return '$promptPart$seedPart';
  }

  List<RandomCategory> _buildCategories(NaiImageMetadata metadata) {
    final l10n = context.l10n;
    final categories = <RandomCategory>[];

    void addCategory(String name, List<String> tags) {
      if (tags.isEmpty) return;
      final id = const Uuid().v4();
      final key = name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      categories.add(
        RandomCategory(
          id: id,
          name: name,
          key: key.isEmpty ? 'legacy_category' : 'legacy_$key',
          groupSelectionMode: SelectionMode.all,
          shuffle: false,
          groups: [
            RandomTagGroup(
              id: 'legacy_${id.replaceAll('-', '_')}',
              name: name,
              sourceType: TagGroupSourceType.custom,
              selectionMode: SelectionMode.all,
              shuffle: false,
              tags: tags
                  .map((tag) => WeightedTag.simple(tag, 10, TagSource.custom))
                  .toList(),
            ),
          ],
        ),
      );
    }

    if (_includePrompt) {
      addCategory(
        l10n.metadataImport_mainPrompt,
        _extractTags(metadata.mainPrompt),
      );
    }
    if (_includeQualityTags) {
      addCategory(
        l10n.qualityTags_label,
        _extractTags(metadata.qualityTags.join(', ')),
      );
    }
    if (_includeFixedTags && metadata.hasSeparatedFields) {
      addCategory(l10n.metadataImport_fixedTags, [
        ...metadata.fixedPrefixTags,
        ...metadata.fixedSuffixTags,
        ...metadata.fixedNegativePrefixTags,
        ...metadata.fixedNegativeSuffixTags,
      ]);
    }
    if (_includeNegativePrompt) {
      addCategory(
        l10n.prompt_negativePrompt,
        _extractTags(metadata.displayNegativePrompt),
      );
    }
    return categories;
  }

  /// 从提示词文本中提取标签列表
  List<String> _extractTags(String prompt) {
    if (prompt.isEmpty) return [];

    // 移除权重括号，分割逗号分隔的标签
    final cleanPrompt = prompt
        .replaceAll(RegExp(r'[\[\]\(\)\{\}]'), '') // 移除括号
        .replaceAll(RegExp(r':\d+\.?\d*'), ''); // 移除权重值

    return cleanPrompt
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      AppToast.warning(context, context.l10n.toast_presetNameRequired);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(randomPresetNotifierProvider.notifier);

      final categories = _buildCategories(widget.metadata);

      if (categories.isEmpty) {
        AppToast.warning(context, context.l10n.toast_selectPresetContent);
        return;
      }

      final preset = RandomPreset.create(
        name: name,
        description: context.l10n.savePreset_metadataDescription,
        categories: categories,
        algorithmConfig: AlgorithmConfig(
          characterCountConfig: CharacterCountConfig.naiDefault,
        ),
      );

      await notifier.addPreset(preset);

      if (mounted) {
        AppToast.success(context, context.l10n.toast_presetSaved);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetSelection() {
    _includePrompt = true;
    _includeFixedTags = widget.metadata.hasSeparatedFields;
    _includeQualityTags = widget.metadata.qualityTags.isNotEmpty;
    _includeNegativePrompt = widget.metadata.negativePrompt.isNotEmpty;
    _includeSeed = widget.metadata.seed != null;
    _includeSteps = widget.metadata.steps != null;
    _includeScale = widget.metadata.scale != null;
    _includeSize =
        widget.metadata.width != null && widget.metadata.height != null;
    _includeSampler = widget.metadata.sampler != null;
    _includeModel = widget.metadata.model != null;
    _includeSmea =
        widget.metadata.smea == true || widget.metadata.smeaDyn == true;
    _includeVibe = widget.metadata.vibeReferences.isNotEmpty;
  }

  void _selectAll() => setState(_resetSelection);

  void _deselectAll() {
    setState(() {
      _includePrompt = false;
      _includeFixedTags = false;
      _includeQualityTags = false;
      _includeNegativePrompt = false;
      _includeSeed = false;
      _includeSteps = false;
      _includeScale = false;
      _includeSize = false;
      _includeSampler = false;
      _includeModel = false;
      _includeSmea = false;
      _includeVibe = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ContentSizedAdaptiveForm(
      scrollController: widget.scrollController,
      content: [
        // 预设名称
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.preset_presetName,
            hintText: l10n.savePreset_nameHint,
            prefixIcon: const Icon(Icons.edit),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        const SizedBox(height: 12),

        // 可滚动的选项列表
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: Text(l10n.common_selectAll),
                ),
                TextButton.icon(
                  onPressed: _deselectAll,
                  icon: const Icon(Icons.deselect, size: 18),
                  label: Text(l10n.common_clear),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 提示词分组
            _buildSectionTitle(
              l10n.metadataImport_promptsSection,
              Icons.text_fields,
            ),
            const SizedBox(height: 8),
            _buildCheckbox(
              label: l10n.metadataImport_mainPrompt,
              value: _includePrompt,
              hasData: widget.metadata.prompt.isNotEmpty,
              onChanged: (v) => setState(() => _includePrompt = v),
            ),
            if (widget.metadata.hasSeparatedFields) ...[
              _buildCheckbox(
                label: l10n.metadataImport_fixedTags,
                value: _includeFixedTags,
                hasData:
                    widget.metadata.fixedPrefixTags.isNotEmpty ||
                    widget.metadata.fixedSuffixTags.isNotEmpty ||
                    widget.metadata.fixedNegativePrefixTags.isNotEmpty ||
                    widget.metadata.fixedNegativeSuffixTags.isNotEmpty,
                onChanged: (v) => setState(() => _includeFixedTags = v),
              ),
              _buildCheckbox(
                label: l10n.qualityTags_label,
                value: _includeQualityTags,
                hasData: widget.metadata.qualityTags.isNotEmpty,
                onChanged: (v) => setState(() => _includeQualityTags = v),
              ),
            ],
            _buildCheckbox(
              label: l10n.prompt_negativePrompt,
              value: _includeNegativePrompt,
              hasData: widget.metadata.negativePrompt.isNotEmpty,
              onChanged: (v) => setState(() => _includeNegativePrompt = v),
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 8),

            // 生成参数分组
            _buildSectionTitle(
              l10n.metadataImport_generationSection,
              Icons.tune,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildCompactCheckbox(
                  label: l10n.generation_seed,
                  value: _includeSeed,
                  hasData: widget.metadata.seed != null,
                  onChanged: (v) => setState(() => _includeSeed = v),
                ),
                _buildCompactCheckbox(
                  label: l10n.gallery_metaSteps,
                  value: _includeSteps,
                  hasData: widget.metadata.steps != null,
                  onChanged: (v) => setState(() => _includeSteps = v),
                ),
                _buildCompactCheckbox(
                  label: 'CFG',
                  value: _includeScale,
                  hasData: widget.metadata.scale != null,
                  onChanged: (v) => setState(() => _includeScale = v),
                ),
                _buildCompactCheckbox(
                  label: l10n.queue_size,
                  value: _includeSize,
                  hasData:
                      widget.metadata.width != null &&
                      widget.metadata.height != null,
                  onChanged: (v) => setState(() => _includeSize = v),
                ),
                _buildCompactCheckbox(
                  label: l10n.generation_sampler,
                  value: _includeSampler,
                  hasData: widget.metadata.sampler != null,
                  onChanged: (v) => setState(() => _includeSampler = v),
                ),
                _buildCompactCheckbox(
                  label: l10n.generation_model,
                  value: _includeModel,
                  hasData: widget.metadata.model != null,
                  onChanged: (v) => setState(() => _includeModel = v),
                ),
                _buildCompactCheckbox(
                  label: 'SMEA',
                  value: _includeSmea,
                  hasData:
                      widget.metadata.smea == true ||
                      widget.metadata.smeaDyn == true,
                  onChanged: (v) => setState(() => _includeSmea = v),
                ),
              ],
            ),

            if (widget.metadata.vibeReferences.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: colorScheme.outlineVariant),
              const SizedBox(height: 8),
              _buildCheckbox(
                label: l10n.savePreset_vibeData(
                  widget.metadata.vibeReferences.length,
                ),
                value: _includeVibe,
                hasData: true,
                onChanged: (v) => setState(() => _includeVibe = v),
              ),
            ],
          ],
        ),

        const Divider(),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(l10n.common_cancel),
            ),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.72
                            : null,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? l10n.common_saving : l10n.common_save),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required bool hasData,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: hasData ? null : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: value && hasData,
      onChanged: hasData ? (v) => onChanged(v ?? false) : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildCompactCheckbox({
    required String label,
    required bool value,
    required bool hasData,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: hasData
              ? value
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        ),
      ),
      selected: value && hasData,
      onSelected: hasData ? onChanged : null,
      showCheckmark: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      disabledColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
