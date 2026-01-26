import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';

/// 预设创建模式
enum PresetCreationMode {
  /// 完全空白
  blank,

  /// 基于默认预设
  template,
}

/// 新建预设对话框
///
/// 用于选择预设创建模式：
/// - 完全空白：从头开始创建
/// - 基于默认预设：复制默认预设作为起点
class NewPresetDialog extends StatefulWidget {
  final ValueChanged<PresetCreationMode> onModeSelected;

  const NewPresetDialog({
    super.key,
    required this.onModeSelected,
  });

  /// 显示对话框
  static Future<void> show({
    required BuildContext context,
    required ValueChanged<PresetCreationMode> onModeSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => NewPresetDialog(
        onModeSelected: onModeSelected,
      ),
    );
  }

  @override
  State<NewPresetDialog> createState() => _NewPresetDialogState();
}

class _NewPresetDialogState extends State<NewPresetDialog> {
  PresetCreationMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme, l10n),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // 完全空白选项
                    RadioListTile<PresetCreationMode>(
                      title: Text(l10n.newPresetDialog_blank),
                      subtitle: Text(l10n.newPresetDialog_blankDesc),
                      value: PresetCreationMode.blank,
                      groupValue: _selectedMode,
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value;
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),

                    // 基于默认预设选项
                    RadioListTile<PresetCreationMode>(
                      title: Text(l10n.newPresetDialog_template),
                      subtitle: Text(l10n.newPresetDialog_templateDesc),
                      value: PresetCreationMode.template,
                      groupValue: _selectedMode,
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value;
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 底部按钮
            _buildFooter(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.newPresetDialog_title,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _selectedMode != null
                ? () {
                    widget.onModeSelected(_selectedMode!);
                    Navigator.of(context).pop();
                  }
                : null,
            icon: const Icon(Icons.check, size: 18),
            label: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
  }
}
