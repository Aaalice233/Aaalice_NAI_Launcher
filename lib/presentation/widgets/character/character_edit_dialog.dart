import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
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
/// - Tab切换式编辑器（正向提示词、负向提示词、位置）
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
  int _currentTabIndex = 0;

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
        borderRadius: BorderRadius.circular(6),
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
            Expanded(
              child: Padding(
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
                            _editingCharacter.copyWith(name: trimmed),
                          );
                        }
                      },
                      onEnabledChanged: (value) {
                        _updateCharacter(
                          _editingCharacter.copyWith(enabled: value),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Tab选项卡
                    _EditorTabs(
                      currentIndex: _currentTabIndex,
                      onTabChanged: (index) =>
                          setState(() => _currentTabIndex = index),
                      genderColor: genderColor,
                      showPositionTab: !widget.globalAiChoice,
                    ),
                    const SizedBox(height: 12),

                    // Tab内容区域
                    Expanded(
                      child: IndexedStack(
                        index: _currentTabIndex,
                        children: [
                          // Tab 0: 正向提示词
                          _PromptTabContent(
                            controller: _promptController,
                            onChanged: (value) {
                              _updateCharacter(
                                _editingCharacter.copyWith(prompt: value),
                              );
                            },
                            hintText: l10n.characterEditor_promptHint,
                          ),
                          // Tab 1: 负向提示词
                          _PromptTabContent(
                            controller: _negativePromptController,
                            onChanged: (value) {
                              _updateCharacter(
                                _editingCharacter.copyWith(
                                  negativePrompt: value,
                                ),
                              );
                            },
                            hintText: l10n.characterEditor_negativePromptHint,
                            compact: true,
                          ),
                          // Tab 2: 位置（仅当全局AI选择未启用时显示）
                          if (!widget.globalAiChoice)
                            _PositionTabContent(
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

/// 填充背景式Tab选项卡
class _EditorTabs extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final Color genderColor;
  final bool showPositionTab;

  const _EditorTabs({
    required this.currentIndex,
    required this.onTabChanged,
    required this.genderColor,
    this.showPositionTab = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final tabs = [
      _TabItem(
        label: l10n.prompt_positivePrompt,
        icon: Icons.add_circle_outline,
      ),
      _TabItem(
        label: l10n.prompt_negativePrompt,
        icon: Icons.remove_circle_outline,
      ),
      if (showPositionTab)
        _TabItem(
          label: l10n.characterEditor_position,
          icon: Icons.grid_on_rounded,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          return Expanded(
            child: _TabButton(
              label: tab.label,
              icon: tab.icon,
              isActive: currentIndex == index,
              genderColor: genderColor,
              onTap: () => onTabChanged(index),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;

  const _TabItem({required this.label, required this.icon});
}

/// Tab按钮组件
class _TabButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color genderColor;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.genderColor,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.genderColor
                : (_isHovered
                    ? colorScheme.surfaceContainerHighest
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.genderColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive
                    ? Colors.white
                    : (_isHovered
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: widget.isActive
                        ? Colors.white
                        : (_isHovered
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant),
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
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

/// 提示词Tab内容组件
class _PromptTabContent extends ConsumerWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final bool compact;

  const _PromptTabContent({
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      showClearButton: true,
      clearNeedsConfirm: true,
      onClearPressed: () => onChanged(''),
    );

    return PromptEditorWithToolbar(
      toolbarConfig: toolbarConfig.copyWith(showClearButton: false),
      inputConfig: inputConfig,
      controller: controller,
      onChanged: onChanged,
      onCleared: () => onChanged(''),
      maxLines: null,
      minLines: null,
      expands: true,
    );
  }
}

/// 位置Tab内容组件
class _PositionTabContent extends StatelessWidget {
  final CharacterPosition? customPosition;
  final ValueChanged<CharacterPosition> onPositionSelected;

  const _PositionTabContent({
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
          l10n.characterEditor_positionHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: LabeledPositionGridSelector(
              selectedPosition:
                  customPosition ?? const CharacterPosition(row: 2, column: 2),
              onPositionSelected: onPositionSelected,
              enabled: true,
            ),
          ),
        ),
      ],
    );
  }
}
