import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import 'position_grid_selector.dart';

/// 角色详情编辑面板组件
///
/// 用于编辑选中角色的所有属性，包括：
/// - 名称输入
/// - 性别选择器
/// - 正向提示词编辑器
/// - 负面提示词编辑器
/// - 位置模式下拉框
/// - 位置网格选择器
/// - Token计数显示
///
/// Requirements: 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3
class CharacterDetailPanel extends ConsumerStatefulWidget {
  /// 要编辑的角色
  final CharacterPrompt character;

  /// 角色更新回调
  final ValueChanged<CharacterPrompt>? onCharacterUpdated;

  /// 是否全局AI选择位置
  final bool globalAiChoice;

  const CharacterDetailPanel({
    super.key,
    required this.character,
    this.onCharacterUpdated,
    this.globalAiChoice = false,
  });

  @override
  ConsumerState<CharacterDetailPanel> createState() =>
      _CharacterDetailPanelState();
}

class _CharacterDetailPanelState extends ConsumerState<CharacterDetailPanel> {
  late TextEditingController _nameController;
  late TextEditingController _promptController;
  late TextEditingController _negativePromptController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.character.name);
    _promptController = TextEditingController(text: widget.character.prompt);
    _negativePromptController =
        TextEditingController(text: widget.character.negativePrompt);
  }


  @override
  void didUpdateWidget(CharacterDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当角色ID变化时，更新控制器
    if (oldWidget.character.id != widget.character.id) {
      _nameController.text = widget.character.name;
      _promptController.text = widget.character.prompt;
      _negativePromptController.text = widget.character.negativePrompt;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _negativePromptController.dispose();
    super.dispose();
  }

  void _updateCharacter(CharacterPrompt updated) {
    widget.onCharacterUpdated?.call(updated);
  }

  void _onNameChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && trimmed != widget.character.name) {
      _updateCharacter(widget.character.copyWith(name: trimmed));
    }
  }

  void _onPromptChanged(String value) {
    if (value != widget.character.prompt) {
      _updateCharacter(widget.character.copyWith(prompt: value));
    }
  }

  void _onNegativePromptChanged(String value) {
    if (value != widget.character.negativePrompt) {
      _updateCharacter(widget.character.copyWith(negativePrompt: value));
    }
  }

  void _onGenderChanged(CharacterGender gender) {
    if (gender != widget.character.gender) {
      _updateCharacter(widget.character.copyWith(gender: gender));
    }
  }

  void _onPositionModeChanged(CharacterPositionMode mode) {
    if (mode != widget.character.positionMode) {
      _updateCharacter(
        widget.character.copyWith(
          positionMode: mode,
          // 切换到自定义模式时，如果没有位置则设置默认位置
          customPosition: mode == CharacterPositionMode.custom &&
                  widget.character.customPosition == null
              ? const CharacterPosition(row: 2, column: 2)
              : widget.character.customPosition,
        ),
      );
    }
  }

  void _onPositionSelected(CharacterPosition position) {
    _updateCharacter(widget.character.copyWith(customPosition: position));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称和性别行
          _NameAndGenderRow(
            nameController: _nameController,
            gender: widget.character.gender,
            onNameChanged: _onNameChanged,
            onGenderChanged: _onGenderChanged,
          ),
          const SizedBox(height: 20),

          // 正向提示词
          _PromptSection(
            label: 'Prompt',
            controller: _promptController,
            onChanged: _onPromptChanged,
            hintText: '输入角色的正向提示词...',
          ),
          const SizedBox(height: 16),

          // 负面提示词
          _PromptSection(
            label: 'Undesired Content',
            controller: _negativePromptController,
            onChanged: _onNegativePromptChanged,
            hintText: '输入角色的负面提示词...',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // 位置设置
          _PositionSection(
            positionMode: widget.character.positionMode,
            customPosition: widget.character.customPosition,
            globalAiChoice: widget.globalAiChoice,
            onPositionModeChanged: _onPositionModeChanged,
            onPositionSelected: _onPositionSelected,
          ),
          const SizedBox(height: 16),

          // Token计数
          _TokenCountDisplay(prompt: widget.character.prompt),
        ],
      ),
    );
  }
}


/// 名称和性别行组件
class _NameAndGenderRow extends StatelessWidget {
  final TextEditingController nameController;
  final CharacterGender gender;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<CharacterGender> onGenderChanged;

  const _NameAndGenderRow({
    required this.nameController,
    required this.gender,
    required this.onNameChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 名称输入
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '名称',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                onChanged: onNameChanged,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: '输入角色名称',
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // 性别选择器
        _GenderSelector(
          selectedGender: gender,
          onGenderChanged: onGenderChanged,
        ),
      ],
    );
  }
}

/// 性别选择器组件
class _GenderSelector extends StatelessWidget {
  final CharacterGender selectedGender;
  final ValueChanged<CharacterGender> onGenderChanged;

  const _GenderSelector({
    required this.selectedGender,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性别',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: CharacterGender.values.map((gender) {
              final isSelected = gender == selectedGender;
              return _GenderButton(
                gender: gender,
                isSelected: isSelected,
                onTap: () => onGenderChanged(gender),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 性别按钮组件
class _GenderButton extends StatelessWidget {
  final CharacterGender gender;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.gender,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (gender) {
      case CharacterGender.female:
        return Icons.female;
      case CharacterGender.male:
        return Icons.male;
      case CharacterGender.other:
        return Icons.transgender;
    }
  }

  Color get _color {
    switch (gender) {
      case CharacterGender.female:
        return Colors.pink.shade300;
      case CharacterGender.male:
        return Colors.blue.shade300;
      case CharacterGender.other:
        return Colors.purple.shade300;
    }
  }

  String get _tooltip {
    switch (gender) {
      case CharacterGender.female:
        return '女性';
      case CharacterGender.male:
        return '男性';
      case CharacterGender.other:
        return '其他';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: _tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? _color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _icon,
              size: 20,
              color: isSelected ? _color : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}


/// 提示词编辑区域组件
class _PromptSection extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int maxLines;

  const _PromptSection({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.maxLines = 5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 位置设置区域组件
class _PositionSection extends StatelessWidget {
  final CharacterPositionMode positionMode;
  final CharacterPosition? customPosition;
  final bool globalAiChoice;
  final ValueChanged<CharacterPositionMode> onPositionModeChanged;
  final ValueChanged<CharacterPosition> onPositionSelected;

  const _PositionSection({
    required this.positionMode,
    this.customPosition,
    required this.globalAiChoice,
    required this.onPositionModeChanged,
    required this.onPositionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 如果全局AI选择启用，显示提示信息
    final isOverridden = globalAiChoice;
    final effectiveMode =
        isOverridden ? CharacterPositionMode.aiChoice : positionMode;
    final showGrid = effectiveMode == CharacterPositionMode.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '位置',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isOverridden) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '全局AI选择已启用',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // 位置模式下拉框
        Row(
          children: [
            Expanded(
              child: _PositionModeDropdown(
                value: positionMode,
                enabled: !isOverridden,
                onChanged: onPositionModeChanged,
              ),
            ),
            const SizedBox(width: 16),

            // 位置网格（仅在自定义模式下显示）
            if (showGrid)
              LabeledPositionGridSelector(
                selectedPosition: customPosition,
                onPositionSelected: onPositionSelected,
                enabled: !isOverridden,
              ),
          ],
        ),
      ],
    );
  }
}

/// 位置模式下拉框组件
class _PositionModeDropdown extends StatelessWidget {
  final CharacterPositionMode value;
  final bool enabled;
  final ValueChanged<CharacterPositionMode> onChanged;

  const _PositionModeDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DropdownButtonFormField<CharacterPositionMode>(
      value: value,
      onChanged: enabled ? (v) => v != null ? onChanged(v) : null : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.15),
          ),
        ),
      ),
      items: [
        DropdownMenuItem(
          value: CharacterPositionMode.aiChoice,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text("AI's Choice"),
            ],
          ),
        ),
        DropdownMenuItem(
          value: CharacterPositionMode.custom,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_on,
                size: 16,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              const Text('Custom'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Token计数显示组件
class _TokenCountDisplay extends StatelessWidget {
  final String prompt;

  const _TokenCountDisplay({required this.prompt});

  /// 估算token数量
  int _estimateTokenCount(String text) {
    if (text.trim().isEmpty) return 0;
    final tags = text.split(',').where((t) => t.trim().isNotEmpty);
    return tags.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tokenCount = _estimateTokenCount(prompt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.token,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Token: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$tokenCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
