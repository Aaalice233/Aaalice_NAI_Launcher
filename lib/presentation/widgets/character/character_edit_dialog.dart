import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../common/themed_switch.dart';
import '../common/themed_input.dart';
import '../prompt/toolbar/toolbar.dart';
import '../prompt/unified/unified.dart';
import 'position_grid_selector.dart';

/// 角色编辑弹窗
///
/// 用于编辑单个角色的详细信息，包括：
/// - 名称输入
/// - 启用开关
/// - 正向提示词编辑器
/// - 负向提示词编辑器
/// - 位置网格选择器
class CharacterEditDialog extends ConsumerStatefulWidget {
  final CharacterPrompt character;
  final bool globalAiChoice;

  const CharacterEditDialog({
    super.key,
    required this.character,
    this.globalAiChoice = false,
  });

  /// 显示编辑弹窗
  static Future<void> show(
    BuildContext context,
    CharacterPrompt character,
    bool globalAiChoice,
  ) {
    return showDialog(
      context: context,
      builder: (context) => CharacterEditDialog(
        character: character,
        globalAiChoice: globalAiChoice,
      ),
    );
  }

  @override
  ConsumerState<CharacterEditDialog> createState() =>
      _CharacterEditDialogState();
}

class _CharacterEditDialogState extends ConsumerState<CharacterEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _promptController;
  late TextEditingController _negativePromptController;
  late CharacterPrompt _editingCharacter;

  @override
  void initState() {
    super.initState();
    _editingCharacter = widget.character;
    _nameController = TextEditingController(text: widget.character.name);
    _promptController = TextEditingController(text: widget.character.prompt);
    _negativePromptController =
        TextEditingController(text: widget.character.negativePrompt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _negativePromptController.dispose();
    super.dispose();
  }

  void _updateCharacter(CharacterPrompt updated) {
    setState(() {
      _editingCharacter = updated;
    });
  }

  void _saveAndClose() {
    ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(_editingCharacter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final genderColor = _getGenderColor();

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            _buildHeader(theme, colorScheme, l10n, genderColor),
            // 内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称行
                    _NameRow(
                      nameController: _nameController,
                      gender: _editingCharacter.gender,
                      enabled: _editingCharacter.enabled,
                      onNameChanged: (value) {
                        final trimmed = value.trim();
                        if (trimmed.isNotEmpty) {
                          _updateCharacter(
                              _editingCharacter.copyWith(name: trimmed),);
                        }
                      },
                      onEnabledChanged: (value) {
                        _updateCharacter(
                            _editingCharacter.copyWith(enabled: value),);
                      },
                    ),
                    const SizedBox(height: 20),

                    // 正向提示词
                    _PromptSection(
                      label: l10n.prompt_positivePrompt,
                      controller: _promptController,
                      onChanged: (value) {
                        _updateCharacter(
                            _editingCharacter.copyWith(prompt: value),);
                      },
                      hintText: l10n.characterEditor_promptHint,
                    ),
                    const SizedBox(height: 16),

                    // 负向提示词
                    _PromptSection(
                      label: l10n.prompt_negativePrompt,
                      controller: _negativePromptController,
                      onChanged: (value) {
                        _updateCharacter(
                            _editingCharacter.copyWith(negativePrompt: value),);
                      },
                      hintText: l10n.characterEditor_negativePromptHint,
                      maxLines: 3,
                      compact: true,
                    ),
                    const SizedBox(height: 20),

                    // 位置网格（仅当全局AI选择未启用时显示）
                    if (!widget.globalAiChoice)
                      _PositionSection(
                        customPosition: _editingCharacter.customPosition,
                        onPositionSelected: (position) {
                          _updateCharacter(
                            _editingCharacter.copyWith(
                              customPosition: position,
                              positionMode: CharacterPositionMode.custom,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            // 底部按钮
            _buildFooter(theme, colorScheme, l10n),
          ],
        ),
      ),
    );
  }

  Color _getGenderColor() {
    switch (_editingCharacter.gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899);
      case CharacterGender.male:
        return const Color(0xFF3B82F6);
      case CharacterGender.other:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getGenderIcon() {
    switch (_editingCharacter.gender) {
      case CharacterGender.female:
        return Icons.female;
      case CharacterGender.male:
        return Icons.male;
      case CharacterGender.other:
        return Icons.transgender;
    }
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    Color genderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: genderColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getGenderIcon(),
              size: 20,
              color: genderColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.characterEditor_editCharacter,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: l10n.common_close,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _saveAndClose,
            child: Text(l10n.common_save),
          ),
        ],
      ),
    );
  }
}

/// 名称行组件
class _NameRow extends StatelessWidget {
  final TextEditingController nameController;
  final CharacterGender gender;
  final bool enabled;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<bool> onEnabledChanged;

  const _NameRow({
    required this.nameController,
    required this.gender,
    required this.enabled,
    required this.onNameChanged,
    required this.onEnabledChanged,
  });

  Color get _genderColor {
    switch (gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899);
      case CharacterGender.male:
        return const Color(0xFF3B82F6);
      case CharacterGender.other:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _genderIcon {
    switch (gender) {
      case CharacterGender.female:
        return Icons.female;
      case CharacterGender.male:
        return Icons.male;
      case CharacterGender.other:
        return Icons.transgender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.characterEditor_name,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // 性别图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _genderColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _genderIcon,
                size: 20,
                color: _genderColor,
              ),
            ),
            const SizedBox(width: 12),
            // 名称输入
            Expanded(
              child: ThemedInput(
                controller: nameController,
                onChanged: onNameChanged,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: l10n.characterEditor_nameHint,
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 启用开关
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.characterEditor_enabled,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                ThemedSwitch(
                  value: enabled,
                  onChanged: onEnabledChanged,
                  scale: 0.85,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 提示词编辑区域组件
class _PromptSection extends ConsumerWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int maxLines;
  final bool compact;

  const _PromptSection({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.maxLines = 5,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableHighlight = ref.watch(highlightEmphasisSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.watch(sdSyntaxAutoConvertSettingsProvider);

    final toolbarConfig = compact
        ? PromptEditorToolbarConfig.compactMode
        : PromptEditorToolbarConfig.characterEditor;

    final baseConfig = compact
        ? UnifiedPromptConfig.compactMode
        : UnifiedPromptConfig.characterEditor;

    final inputConfig = baseConfig.copyWith(
      hintText: hintText,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
      enableSyntaxHighlight: enableHighlight,
      enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            PromptEditorToolbar(
              config: toolbarConfig,
              onClearPressed: () => onChanged(''),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PromptEditorWithToolbar(
          toolbarConfig: toolbarConfig.copyWith(showClearButton: false),
          inputConfig: inputConfig,
          controller: controller,
          onChanged: onChanged,
          onCleared: () => onChanged(''),
          maxLines: maxLines,
          minLines: 3,
        ),
      ],
    );
  }
}

/// 位置网格区域组件
class _PositionSection extends StatelessWidget {
  final CharacterPosition? customPosition;
  final ValueChanged<CharacterPosition> onPositionSelected;

  const _PositionSection({
    this.customPosition,
    required this.onPositionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.characterEditor_position,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        LabeledPositionGridSelector(
          selectedPosition:
              customPosition ?? const CharacterPosition(row: 2, column: 2),
          onPositionSelected: onPositionSelected,
          enabled: true,
        ),
      ],
    );
  }
}
