import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/models/metadata/metadata_import_options.dart';

/// 元数据导入对话框
///
/// 允许用户选择性地套用图片元数据中的参数
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.metadataImport_title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 快速预设按钮
              _buildQuickPresets(),
              const SizedBox(height: 16),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),

              // 提示词相关
              _buildSectionTitle(l10n.metadataImport_promptsSection),
              _buildCheckbox(
                label: l10n.metadataImport_prompt,
                value: _options.importPrompt,
                hasData: widget.metadata.prompt.isNotEmpty,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importPrompt: value),
                ),
              ),
              _buildCheckbox(
                label: l10n.metadataImport_negativePrompt,
                value: _options.importNegativePrompt,
                hasData: widget.metadata.negativePrompt.isNotEmpty,
                onChanged: (value) => setState(
                  () =>
                      _options = _options.copyWith(importNegativePrompt: value),
                ),
              ),
              if (widget.metadata.characterPrompts.isNotEmpty)
                _buildCheckbox(
                  label: l10n.metadataImport_characterPrompts,
                  value: _options.importCharacterPrompts,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options =
                        _options.copyWith(importCharacterPrompts: value),
                  ),
                ),

              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),

              // 生成参数
              _buildSectionTitle(l10n.metadataImport_generationSection),
              _buildCheckbox(
                label: l10n.metadataImport_seed,
                value: _options.importSeed,
                hasData: widget.metadata.seed != null,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importSeed: value),
                ),
              ),
              _buildCheckbox(
                label: l10n.metadataImport_steps,
                value: _options.importSteps,
                hasData: widget.metadata.steps != null,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importSteps: value),
                ),
              ),
              _buildCheckbox(
                label: l10n.metadataImport_scale,
                value: _options.importScale,
                hasData: widget.metadata.scale != null,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importScale: value),
                ),
              ),
              _buildCheckbox(
                label: l10n.metadataImport_size,
                value: _options.importSize,
                hasData: widget.metadata.width != null &&
                    widget.metadata.height != null,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importSize: value),
                ),
              ),
              _buildCheckbox(
                label: l10n.metadataImport_sampler,
                value: _options.importSampler,
                hasData: widget.metadata.sampler != null,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importSampler: value),
                ),
              ),
              _buildCheckbox(
                label: l10n.metadataImport_model,
                value: _options.importModel,
                hasData: widget.metadata.model != null,
                onChanged: (value) => setState(
                  () => _options = _options.copyWith(importModel: value),
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),

              // 高级选项
              _buildSectionTitle(l10n.metadataImport_advancedSection),
              if (widget.metadata.smea != null)
                _buildCheckbox(
                  label: l10n.metadataImport_smea,
                  value: _options.importSmea,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options = _options.copyWith(importSmea: value),
                  ),
                ),
              if (widget.metadata.smeaDyn != null)
                _buildCheckbox(
                  label: l10n.metadataImport_smeaDyn,
                  value: _options.importSmeaDyn,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options = _options.copyWith(importSmeaDyn: value),
                  ),
                ),
              if (widget.metadata.noiseSchedule != null)
                _buildCheckbox(
                  label: l10n.metadataImport_noiseSchedule,
                  value: _options.importNoiseSchedule,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options =
                        _options.copyWith(importNoiseSchedule: value),
                  ),
                ),
              if (widget.metadata.cfgRescale != null)
                _buildCheckbox(
                  label: l10n.metadataImport_cfgRescale,
                  value: _options.importCfgRescale,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options = _options.copyWith(importCfgRescale: value),
                  ),
                ),
              if (widget.metadata.qualityToggle != null)
                _buildCheckbox(
                  label: l10n.metadataImport_qualityToggle,
                  value: _options.importQualityToggle,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options =
                        _options.copyWith(importQualityToggle: value),
                  ),
                ),
              if (widget.metadata.ucPreset != null)
                _buildCheckbox(
                  label: l10n.metadataImport_ucPreset,
                  value: _options.importUcPreset,
                  hasData: true,
                  onChanged: (value) => setState(
                    () => _options = _options.copyWith(importUcPreset: value),
                  ),
                ),

              const SizedBox(height: 16),
              // 显示已选择数量
              Center(
                child: Text(
                  l10n.metadataImport_selectedCount(_options.selectedCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          label: Text(l10n.metadataImport_selectAll),
          avatar: const Icon(Icons.select_all, size: 18),
          onPressed: () => setState(
            () => _options = MetadataImportOptions.all(),
          ),
          backgroundColor: theme.colorScheme.primaryContainer,
          side: BorderSide.none,
        ),
        ActionChip(
          label: Text(l10n.metadataImport_deselectAll),
          avatar: const Icon(Icons.deselect, size: 18),
          onPressed: () => setState(
            () => _options = MetadataImportOptions.none(),
          ),
        ),
        ActionChip(
          label: Text(l10n.metadataImport_promptsOnly),
          avatar: const Icon(Icons.text_fields, size: 18),
          onPressed: () => setState(
            () => _options = MetadataImportOptions.promptsOnly(),
          ),
        ),
        ActionChip(
          label: Text(l10n.metadataImport_generationOnly),
          avatar: const Icon(Icons.tune, size: 18),
          onPressed: () => setState(
            () => _options = MetadataImportOptions.generationOnly(),
          ),
        ),
      ],
    );
  }

  /// 构建分组标题
  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  /// 构建复选框项
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
      subtitle: hasData
          ? null
          : Text(
              context.l10n.metadataImport_noData,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
      value: value && hasData,
      onChanged: hasData ? (v) => onChanged(v ?? false) : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
