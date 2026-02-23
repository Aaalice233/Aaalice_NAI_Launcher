import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/models/metadata/metadata_import_options.dart';

/// 元数据导入对话框
///
/// 允许用户选择性地套用图片元数据中的参数
/// 新设计：按类型分组复选框，支持父子选项联动
class MetadataImportDialog extends StatefulWidget {
  final NaiImageMetadata metadata;

  const MetadataImportDialog({
    super.key,
    required this.metadata,
  });

  /// 显示对话框并返回用户选择的导入选项
  static Future<MetadataImportOptions?> show(
    BuildContext context, {
    required NaiImageMetadata metadata,
  }) {
    return showDialog<MetadataImportOptions>(
      context: context,
      builder: (context) => MetadataImportDialog(metadata: metadata),
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
    _options = MetadataImportOptions.all();
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

    _options = _options.copyWith(
      selectedQualityTags: qualityTags.isNotEmpty ? List.from(qualityTags) : [],
      selectedCharacterIndices:
          characterCount > 0 ? List.generate(characterCount, (i) => i) : [],
      selectedVibeIndices:
          vibeCount > 0 ? List.generate(vibeCount, (i) => i) : [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.metadataImport_title),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 600,
        child: Column(
          children: [
            // 快速预设按钮
            _buildQuickPresets(),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 8),
            // 可滚动的选项列表
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 提示词分组
                    _buildPromptSection(),
                    const SizedBox(height: 16),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    // 生成参数分组
                    _buildGenerationSection(),
                  ],
                ),
              ),
            ),
            // 底部统计
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '已选择 ${_options.selectedCount} 项',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _options.isNoneSelected
              ? null
              : () => Navigator.of(context).pop(_options),
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }

  /// 构建快速预设按钮区域
  Widget _buildQuickPresets() {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(Icons.select_all, size: 18, color: theme.colorScheme.onPrimaryContainer),
          label: const Text('全部'),
          onPressed: () => setState(() {
            _options = MetadataImportOptions.all();
            _initializeSelections();
          }),
          backgroundColor: theme.colorScheme.primaryContainer,
          side: BorderSide.none,
        ),
        ActionChip(
          avatar: const Icon(Icons.text_fields, size: 18),
          label: const Text('仅提示词'),
          onPressed: () => setState(() {
            _options = MetadataImportOptions.promptsOnly();
            _initializeSelections();
          }),
        ),
        ActionChip(
          avatar: const Icon(Icons.tune, size: 18),
          label: const Text('仅参数'),
          onPressed: () => setState(() => _options = MetadataImportOptions.generationOnly()),
        ),
        ActionChip(
          avatar: const Icon(Icons.deselect, size: 18),
          label: const Text('清空'),
          onPressed: () => setState(() => _options = MetadataImportOptions.none()),
        ),
      ],
    );
  }

  /// 构建提示词分组
  Widget _buildPromptSection() {
    final metadata = widget.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('提示词', Icons.text_fields),
        const SizedBox(height: 8),
        // 主提示词
        _buildCheckboxTile(
          title: '主提示词',
          subtitle: _truncateText(metadata.mainPrompt, 50),
          value: _options.importPrompt,
          hasData: metadata.prompt.isNotEmpty,
          onChanged: (v) => setState(() => _options = _options.copyWith(importPrompt: v)),
        ),
        // 固定词（带子选项）
        if (metadata.hasSeparatedFields) ...[
          _buildParentCheckboxTile(
            title: '固定词',
            value: _options.importFixedTags,
            hasData: metadata.fixedPrefixTags.isNotEmpty || metadata.fixedSuffixTags.isNotEmpty,
            onChanged: (v) => setState(() => _options = _options.copyWith(importFixedTags: v)),
            children: [
              if (metadata.fixedPrefixTags.isNotEmpty)
                _buildChildCheckboxTile(
                  title: '前缀: ${_truncateText(metadata.fixedPrefixTags.join(', '), 40)}',
                  value: _options.importFixedPrefix,
                  onChanged: _options.importFixedTags
                      ? (v) => setState(() => _options = _options.copyWith(importFixedPrefix: v))
                      : null,
                ),
              if (metadata.fixedSuffixTags.isNotEmpty)
                _buildChildCheckboxTile(
                  title: '后缀: ${_truncateText(metadata.fixedSuffixTags.join(', '), 40)}',
                  value: _options.importFixedSuffix,
                  onChanged: _options.importFixedTags
                      ? (v) => setState(() => _options = _options.copyWith(importFixedSuffix: v))
                      : null,
                ),
            ],
          ),
          // 质量词（带子选项）
          if (metadata.qualityTags.isNotEmpty)
            _buildParentCheckboxTile(
              title: '质量词 (${metadata.qualityTags.length}个)',
              value: _options.importQualityTags,
              hasData: true,
              onChanged: (v) => setState(() => _options = _options.copyWith(importQualityTags: v)),
              children: metadata.qualityTags.asMap().entries.map((entry) {
                final tag = entry.value;
                return _buildChildCheckboxTile(
                  title: tag,
                  value: _options.selectedQualityTags.contains(tag),
                  onChanged: _options.importQualityTags
                      ? (v) => setState(() {
                            final selected = List<String>.from(_options.selectedQualityTags);
                            if (v) {
                              if (!selected.contains(tag)) selected.add(tag);
                            } else {
                              selected.remove(tag);
                            }
                            _options = _options.copyWith(selectedQualityTags: selected);
                          })
                      : null,
                );
              }).toList(),
            ),
          // 角色提示词（带子选项）
          if (metadata.characterInfos.isNotEmpty)
            _buildParentCheckboxTile(
              title: '角色提示词 (${metadata.characterInfos.length}个)',
              value: _options.importCharacterPrompts,
              hasData: true,
              onChanged: (v) => setState(() => _options = _options.copyWith(importCharacterPrompts: v)),
              children: metadata.characterInfos.asMap().entries.map((entry) {
                final index = entry.key;
                final character = entry.value;
                return _buildChildCheckboxTile(
                  title: '角色${index + 1}: ${_truncateText(character.prompt, 35)}',
                  value: _options.selectedCharacterIndices.contains(index),
                  onChanged: _options.importCharacterPrompts
                      ? (v) => setState(() {
                            final selected = List<int>.from(_options.selectedCharacterIndices);
                            if (v) {
                              if (!selected.contains(index)) selected.add(index);
                            } else {
                              selected.remove(index);
                            }
                            _options = _options.copyWith(selectedCharacterIndices: selected);
                          })
                      : null,
                );
              }).toList(),
            ),
          // Vibe数据（带子选项）
          if (metadata.vibeReferences.isNotEmpty)
            _buildParentCheckboxTile(
              title: 'Vibe Transfer (${metadata.vibeReferences.length}个)',
              value: _options.importVibeReferences,
              hasData: true,
              onChanged: (v) => setState(() => _options = _options.copyWith(importVibeReferences: v)),
              children: metadata.vibeReferences.asMap().entries.map((entry) {
                final index = entry.key;
                final vibe = entry.value;
                return _buildChildCheckboxTile(
                  title: '${vibe.displayName} (strength: ${(vibe.strength * 100).toInt()}%)',
                  value: _options.selectedVibeIndices.contains(index),
                  onChanged: _options.importVibeReferences
                      ? (v) => setState(() {
                            final selected = List<int>.from(_options.selectedVibeIndices);
                            if (v) {
                              if (!selected.contains(index)) selected.add(index);
                            } else {
                              selected.remove(index);
                            }
                            _options = _options.copyWith(selectedVibeIndices: selected);
                          })
                      : null,
                );
              }).toList(),
            ),
        ] else ...[
          // 旧数据：只显示角色提示词总开关
          if (metadata.characterPrompts.isNotEmpty)
            _buildCheckboxTile(
              title: '角色提示词 (${metadata.characterPrompts.length}个)',
              value: _options.importCharacterPrompts,
              hasData: true,
              onChanged: (v) => setState(() => _options = _options.copyWith(importCharacterPrompts: v)),
            ),
        ],
        // 负向提示词
        _buildCheckboxTile(
          title: '负向提示词',
          subtitle: _truncateText(metadata.negativePrompt, 50),
          value: _options.importNegativePrompt,
          hasData: metadata.negativePrompt.isNotEmpty,
          onChanged: (v) => setState(() => _options = _options.copyWith(importNegativePrompt: v)),
        ),
      ],
    );
  }

  /// 构建生成参数分组
  Widget _buildGenerationSection() {
    final l10n = context.l10n;
    final metadata = widget.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('生成参数', Icons.tune),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // 基础参数
            _buildCompactCheckbox(
              label: l10n.metadataImport_seed,
              value: _options.importSeed,
              hasData: metadata.seed != null,
              onChanged: (v) => setState(() => _options = _options.copyWith(importSeed: v)),
            ),
            _buildCompactCheckbox(
              label: l10n.metadataImport_steps,
              value: _options.importSteps,
              hasData: metadata.steps != null,
              onChanged: (v) => setState(() => _options = _options.copyWith(importSteps: v)),
            ),
            _buildCompactCheckbox(
              label: l10n.metadataImport_scale,
              value: _options.importScale,
              hasData: metadata.scale != null,
              onChanged: (v) => setState(() => _options = _options.copyWith(importScale: v)),
            ),
            _buildCompactCheckbox(
              label: l10n.metadataImport_size,
              value: _options.importSize,
              hasData: metadata.width != null && metadata.height != null,
              onChanged: (v) => setState(() => _options = _options.copyWith(importSize: v)),
            ),
            _buildCompactCheckbox(
              label: l10n.metadataImport_sampler,
              value: _options.importSampler,
              hasData: metadata.sampler != null,
              onChanged: (v) => setState(() => _options = _options.copyWith(importSampler: v)),
            ),
            if (metadata.model != null)
              _buildCompactCheckbox(
                label: l10n.metadataImport_model,
                value: _options.importModel,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importModel: v)),
              ),
            // 高级参数
            if (metadata.smea == true || metadata.smeaDyn == true)
              _buildCompactCheckbox(
                label: 'SMEA',
                value: _options.importSmea,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importSmea: v)),
              ),
            if (metadata.smeaDyn == true)
              _buildCompactCheckbox(
                label: 'SMEA DYN',
                value: _options.importSmeaDyn,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importSmeaDyn: v)),
              ),
            if (metadata.noiseSchedule != null)
              _buildCompactCheckbox(
                label: l10n.metadataImport_noiseSchedule,
                value: _options.importNoiseSchedule,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importNoiseSchedule: v)),
              ),
            if (metadata.cfgRescale != null && metadata.cfgRescale! > 0)
              _buildCompactCheckbox(
                label: 'CFG Rescale',
                value: _options.importCfgRescale,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importCfgRescale: v)),
              ),
            if (metadata.qualityToggle != null)
              _buildCompactCheckbox(
                label: l10n.metadataImport_qualityToggle,
                value: _options.importQualityToggle,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importQualityToggle: v)),
              ),
            if (metadata.ucPreset != null)
              _buildCompactCheckbox(
                label: l10n.metadataImport_ucPreset,
                value: _options.importUcPreset,
                hasData: true,
                onChanged: (v) => setState(() => _options = _options.copyWith(importUcPreset: v)),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建分组标题
  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// 构建复选框列表项
  Widget _buildCheckboxTile({
    required String title,
    String? subtitle,
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
      subtitle: subtitle != null && hasData
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
                  '无数据',
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
        if (value && hasData && children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
      ],
    );
  }

  /// 构建子级复选框
  Widget _buildChildCheckboxTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      title: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: onChanged != null ? null : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
      disabledColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 截断文本
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
