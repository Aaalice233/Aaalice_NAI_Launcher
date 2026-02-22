import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import 'app_toast.dart';

/// 保存为预设对话框
///
/// 用于将图片元数据保存为快速预设
/// TODO: 需要接入 PromptPresetProvider 和 RandomPromptPreset 模型
class SaveAsPresetDialog extends StatefulWidget {
  /// 要保存的元数据
  final NaiImageMetadata metadata;

  const SaveAsPresetDialog({
    super.key,
    required this.metadata,
  });

  /// 显示对话框
  static Future<bool> show(
    BuildContext context, {
    required NaiImageMetadata metadata,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SaveAsPresetDialog(metadata: metadata),
    );
    return result ?? false;
  }

  @override
  State<SaveAsPresetDialog> createState() => _SaveAsPresetDialogState();
}

class _SaveAsPresetDialogState extends State<SaveAsPresetDialog> {
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

    // 默认全部选中
    _includePrompt = true;
    _includeFixedTags = widget.metadata.hasSeparatedFields;
    _includeQualityTags = widget.metadata.qualityTags.isNotEmpty;
    _includeNegativePrompt = widget.metadata.negativePrompt.isNotEmpty;
    _includeSeed = widget.metadata.seed != null;
    _includeSteps = widget.metadata.steps != null;
    _includeScale = widget.metadata.scale != null;
    _includeSize = widget.metadata.width != null && widget.metadata.height != null;
    _includeSampler = widget.metadata.sampler != null;
    _includeModel = widget.metadata.model != null;
    _includeSmea = widget.metadata.smea == true || widget.metadata.smeaDyn == true;
    _includeVibe = widget.metadata.vibeReferences.isNotEmpty;
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

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      AppToast.warning(context, '请输入预设名称');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // TODO: 需要接入 PromptPresetProvider 和 RandomPromptPreset 模型
      // 临时提示功能尚未实现
      await Future.delayed(const Duration(milliseconds: 500)); // 模拟保存

      if (mounted) {
        AppToast.info(context, '预设保存功能即将推出');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _selectAll() {
    setState(() {
      _includePrompt = true;
      _includeFixedTags = widget.metadata.hasSeparatedFields;
      _includeQualityTags = widget.metadata.qualityTags.isNotEmpty;
      _includeNegativePrompt = widget.metadata.negativePrompt.isNotEmpty;
      _includeSeed = widget.metadata.seed != null;
      _includeSteps = widget.metadata.steps != null;
      _includeScale = widget.metadata.scale != null;
      _includeSize = widget.metadata.width != null && widget.metadata.height != null;
      _includeSampler = widget.metadata.sampler != null;
      _includeModel = widget.metadata.model != null;
      _includeSmea = widget.metadata.smea == true || widget.metadata.smeaDyn == true;
      _includeVibe = widget.metadata.vibeReferences.isNotEmpty;
    });
  }

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

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bookmark_add, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('保存为预设'),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            // 预设名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '预设名称',
                hintText: '输入预设名称',
                prefixIcon: Icon(Icons.edit),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // 快速选择按钮
            Row(
              children: [
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('全选'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _deselectAll,
                  icon: const Icon(Icons.deselect, size: 18),
                  label: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 可滚动的选项列表
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 提示词分组
                    _buildSectionTitle('提示词', Icons.text_fields),
                    const SizedBox(height: 8),
                    _buildCheckbox(
                      label: '主提示词',
                      value: _includePrompt,
                      hasData: widget.metadata.prompt.isNotEmpty,
                      onChanged: (v) => setState(() => _includePrompt = v),
                    ),
                    if (widget.metadata.hasSeparatedFields) ...[
                      _buildCheckbox(
                        label: '固定词',
                        value: _includeFixedTags,
                        hasData: widget.metadata.fixedPrefixTags.isNotEmpty ||
                            widget.metadata.fixedSuffixTags.isNotEmpty,
                        onChanged: (v) => setState(() => _includeFixedTags = v),
                      ),
                      _buildCheckbox(
                        label: '质量词',
                        value: _includeQualityTags,
                        hasData: widget.metadata.qualityTags.isNotEmpty,
                        onChanged: (v) => setState(() => _includeQualityTags = v),
                      ),
                    ],
                    _buildCheckbox(
                      label: '负向提示词',
                      value: _includeNegativePrompt,
                      hasData: widget.metadata.negativePrompt.isNotEmpty,
                      onChanged: (v) => setState(() => _includeNegativePrompt = v),
                    ),

                    const SizedBox(height: 16),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),

                    // 生成参数分组
                    _buildSectionTitle('生成参数', Icons.tune),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildCompactCheckbox(
                          label: '种子',
                          value: _includeSeed,
                          hasData: widget.metadata.seed != null,
                          onChanged: (v) => setState(() => _includeSeed = v),
                        ),
                        _buildCompactCheckbox(
                          label: '步数',
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
                          label: '尺寸',
                          value: _includeSize,
                          hasData: widget.metadata.width != null && widget.metadata.height != null,
                          onChanged: (v) => setState(() => _includeSize = v),
                        ),
                        _buildCompactCheckbox(
                          label: '采样器',
                          value: _includeSampler,
                          hasData: widget.metadata.sampler != null,
                          onChanged: (v) => setState(() => _includeSampler = v),
                        ),
                        _buildCompactCheckbox(
                          label: '模型',
                          value: _includeModel,
                          hasData: widget.metadata.model != null,
                          onChanged: (v) => setState(() => _includeModel = v),
                        ),
                        _buildCompactCheckbox(
                          label: 'SMEA',
                          value: _includeSmea,
                          hasData: widget.metadata.smea == true || widget.metadata.smeaDyn == true,
                          onChanged: (v) => setState(() => _includeSmea = v),
                        ),
                      ],
                    ),

                    if (widget.metadata.vibeReferences.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      _buildCheckbox(
                        label: 'Vibe数据 (${widget.metadata.vibeReferences.length}个)',
                        value: _includeVibe,
                        hasData: true,
                        onChanged: (v) => setState(() => _includeVibe = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_isSaving ? '保存中...' : l10n.common_save),
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
      disabledColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
