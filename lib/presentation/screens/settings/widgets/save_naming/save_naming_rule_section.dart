import 'package:flutter/material.dart';

import '../../../../../core/save_naming/save_name_template.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../themes/design_tokens.dart';
import '../../../../widgets/common/horizontal_action_strip.dart';
import '../settings_card.dart';
import 'save_naming_messages.dart';

/// 一条预设：[key] 用于单选与测试定位。
class SaveNamingOption {
  const SaveNamingOption({
    required this.key,
    required this.label,
    required this.example,
  });

  final String key;
  final String label;
  final String example;
}

/// 子文件夹或文件名一条规则的编辑区：预设单选，选“自定义”时展开模板输入。
class SaveNamingRuleSection extends StatelessWidget {
  const SaveNamingRuleSection({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.icon,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    required this.customExample,
    required this.templateLabel,
    required this.templateHelper,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onTemplateChanged,
    required this.insertableTokens,
  });

  static const String customKey = 'custom';

  final String sectionKey;
  final String title;
  final IconData icon;
  final List<SaveNamingOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final String customExample;
  final String templateLabel;
  final String templateHelper;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String> onTemplateChanged;
  final List<SaveNameToken> insertableTokens;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCard(
      key: ValueKey('save-naming-$sectionKey'),
      title: title,
      icon: icon,
      child: RadioGroup<String>(
        groupValue: selectedKey,
        onChanged: (value) {
          if (value != null) onSelected(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options)
              _OptionTile(
                key: ValueKey('save-naming-$sectionKey-${option.key}'),
                value: option.key,
                label: option.label,
                example: option.example,
              ),
            _OptionTile(
              key: ValueKey('save-naming-$sectionKey-$customKey'),
              value: customKey,
              label: l10n.settings_saveNamingCustom,
              example: selectedKey == customKey ? customExample : null,
            ),
            if (selectedKey == customKey)
              _TemplateEditor(
                sectionKey: sectionKey,
                label: templateLabel,
                helper: templateHelper,
                controller: controller,
                focusNode: focusNode,
                errorText: errorText,
                onChanged: onTemplateChanged,
                insertableTokens: insertableTokens,
              ),
            const SizedBox(height: DesignTokens.spacingXs),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.value,
    required this.label,
    this.example,
  });

  final String value;
  final String label;
  final String? example;

  @override
  Widget build(BuildContext context) {
    final example = this.example;
    return RadioListTile<String>(
      value: value,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingXs,
      ),
      title: Text(label),
      subtitle: example == null || example.isEmpty
          ? null
          : Text(example, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _TemplateEditor extends StatelessWidget {
  const _TemplateEditor({
    required this.sectionKey,
    required this.label,
    required this.helper,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
    required this.insertableTokens,
  });

  final String sectionKey;
  final String label;
  final String helper;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final List<SaveNameToken> insertableTokens;

  void _insert(SaveNameToken token) {
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final inserted = '{${token.id}}';
    final text = value.text.replaceRange(
      selection.start,
      selection.end,
      inserted,
    );
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + inserted.length,
      ),
    );
    onChanged(text);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingMd,
        DesignTokens.spacingXs,
        DesignTokens.spacingMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('save-naming-$sectionKey-template'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            autocorrect: false,
            enableSuggestions: false,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 3,
              errorText: errorText,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXs),
          Text(
            l10n.settings_saveNamingInsertField,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXxs),
          HorizontalActionStrip(
            child: Row(
              children: [
                for (final token in insertableTokens)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: DesignTokens.spacingXxs,
                    ),
                    child: Tooltip(
                      message: l10n.saveNameTokenDescription(token),
                      child: ActionChip(
                        key: ValueKey(
                          'save-naming-$sectionKey-insert-${token.id}',
                        ),
                        label: Text(
                          '{${token.id}}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        onPressed: () => _insert(token),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
