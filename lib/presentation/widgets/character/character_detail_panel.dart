import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../prompt/unified/unified.dart';
import 'position_grid_selector.dart';

/// 角色详情编辑面板组件
///
/// 用于编辑选中角色的所有属性，包括：
/// - 名称输入
/// - 启用开关
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

  void _onPositionSelected(CharacterPosition position) {
    _updateCharacter(
      widget.character.copyWith(
        customPosition: position,
        positionMode: CharacterPositionMode.custom,
      ),
    );
  }

  void _onEnabledChanged(bool value) {
    _updateCharacter(widget.character.copyWith(enabled: value));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称行（只读性别显示 + 启用开关）
          _NameRow(
            nameController: _nameController,
            gender: widget.character.gender,
            onNameChanged: _onNameChanged,
            enabled: widget.character.enabled,
            onEnabledChanged: _onEnabledChanged,
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

          // 负面提示词（使用紧凑模式，禁用视图切换）
          _PromptSection(
            label: 'Undesired Content',
            controller: _negativePromptController,
            onChanged: _onNegativePromptChanged,
            hintText: '输入角色的负面提示词...',
            maxLines: 3,
            compact: true,
          ),
          const SizedBox(height: 20),

          // 位置设置（仅当全局AI选择未启用时显示）
          if (!widget.globalAiChoice) ...[
            _PositionGridSection(
              customPosition: widget.character.customPosition,
              onPositionSelected: _onPositionSelected,
            ),
          ],
        ],
      ),
    );
  }
}

/// 名称行组件（带只读性别图标显示和启用开关）
class _NameRow extends StatelessWidget {
  final TextEditingController nameController;
  final CharacterGender gender;
  final ValueChanged<String> onNameChanged;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  const _NameRow({
    required this.nameController,
    required this.gender,
    required this.onNameChanged,
    required this.enabled,
    required this.onEnabledChanged,
  });

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

  Color get _genderColor {
    switch (gender) {
      case CharacterGender.female:
        return Colors.pink.shade300;
      case CharacterGender.male:
        return Colors.blue.shade300;
      case CharacterGender.other:
        return Colors.purple.shade300;
    }
  }

  String get _genderTooltip {
    switch (gender) {
      case CharacterGender.female:
        return '女性（添加时选择）';
      case CharacterGender.male:
        return '男性（添加时选择）';
      case CharacterGender.other:
        return '其他（添加时选择）';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
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
        Row(
          children: [
            // 性别图标（只读）
            Tooltip(
              message: _genderTooltip,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _genderColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  _genderIcon,
                  size: 20,
                  color: _genderColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 名称输入
            Expanded(
              child: TextField(
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
            ),
            const SizedBox(width: 12),
            // 启用开关
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '启用',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: enabled,
                    onChanged: onEnabledChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
///
/// 使用 [UnifiedPromptInput] 提供自动补全、标签视图切换、语法高亮等功能。
/// Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 5.1, 5.2
class _PromptSection extends ConsumerWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int maxLines;

  /// 是否使用紧凑模式（禁用视图切换）
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

    // 根据 compact 参数选择配置
    final config = compact
        ? UnifiedPromptConfig.compactMode.copyWith(
            hintText: hintText,
          )
        : UnifiedPromptConfig.characterEditor.copyWith(
            hintText: hintText,
          );

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
        UnifiedPromptInput(
          config: config,
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

/// 位置网格区域组件（简化版，仅显示网格选择器）
class _PositionGridSection extends StatelessWidget {
  final CharacterPosition? customPosition;
  final ValueChanged<CharacterPosition> onPositionSelected;

  const _PositionGridSection({
    this.customPosition,
    required this.onPositionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '位置',
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
