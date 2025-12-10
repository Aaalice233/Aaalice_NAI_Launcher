import 'package:flutter/material.dart';

import '../../../data/models/character/character_prompt.dart';

/// 角色列表项组件
///
/// 显示单个角色的摘要信息，包括性别图标、名称、位置指示器。
/// 支持选中状态高亮显示。
///
/// Requirements: 2.1, 5.1
class CharacterListItem extends StatelessWidget {
  /// 角色数据
  final CharacterPrompt character;

  /// 是否选中
  final bool isSelected;

  /// 是否全局AI选择位置
  final bool globalAiChoice;

  /// 点击回调
  final VoidCallback? onTap;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 上移回调
  final VoidCallback? onMoveUp;

  /// 下移回调
  final VoidCallback? onMoveDown;

  /// 是否可以上移
  final bool canMoveUp;

  /// 是否可以下移
  final bool canMoveDown;

  /// 是否显示操作按钮
  final bool showActions;

  const CharacterListItem({
    super.key,
    required this.character,
    this.isSelected = false,
    this.globalAiChoice = false,
    this.onTap,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.canMoveUp = true,
    this.canMoveDown = true,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.5)
                  : colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // 性别图标
              _GenderIcon(gender: character.gender),
              const SizedBox(width: 10),

              // 名称和位置信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 角色名称
                    Text(
                      character.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: character.enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withOpacity(0.5),
                        decoration: character.enabled
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // 位置信息
                    _PositionIndicator(
                      positionMode: character.positionMode,
                      customPosition: character.customPosition,
                      globalAiChoice: globalAiChoice,
                    ),
                  ],
                ),
              ),

              // 操作按钮（仅在showActions为true时显示）
              if (showActions)
                _ActionButtons(
                  onMoveUp: canMoveUp ? onMoveUp : null,
                  onMoveDown: canMoveDown ? onMoveDown : null,
                  onDelete: onDelete,
                ),

              // 禁用指示器
              if (!character.enabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.visibility_off,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// 性别图标组件
class _GenderIcon extends StatelessWidget {
  final CharacterGender gender;

  const _GenderIcon({required this.gender});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (gender) {
      case CharacterGender.female:
        icon = Icons.female;
        color = Colors.pink.shade300;
        break;
      case CharacterGender.male:
        icon = Icons.male;
        color = Colors.blue.shade300;
        break;
      case CharacterGender.other:
        icon = Icons.transgender;
        color = Colors.purple.shade300;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }
}

/// 位置指示器组件
class _PositionIndicator extends StatelessWidget {
  final CharacterPositionMode positionMode;
  final CharacterPosition? customPosition;
  final bool globalAiChoice;

  const _PositionIndicator({
    required this.positionMode,
    this.customPosition,
    this.globalAiChoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String text;
    IconData icon;

    // 全局AI选择开启时，显示AI
    if (globalAiChoice) {
      text = 'AI';
      icon = Icons.auto_awesome;
    } else if (customPosition != null) {
      // 全局关闭时，优先显示自定义位置
      text = customPosition!.toNaiString();
      icon = Icons.grid_on;
    } else if (positionMode == CharacterPositionMode.aiChoice) {
      // 没有自定义位置且模式是AI选择
      text = 'AI';
      icon = Icons.auto_awesome;
    } else {
      text = '--';
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮组件
class _ActionButtons extends StatelessWidget {
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;

  const _ActionButtons({
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上移按钮
        _SmallIconButton(
          icon: Icons.arrow_upward,
          onPressed: onMoveUp,
          tooltip: '上移',
        ),
        // 下移按钮
        _SmallIconButton(
          icon: Icons.arrow_downward,
          onPressed: onMoveDown,
          tooltip: '下移',
        ),
        const SizedBox(width: 4),
        // 删除按钮
        _SmallIconButton(
          icon: Icons.delete_outline,
          onPressed: onDelete,
          tooltip: '删除',
          color: theme.colorScheme.error,
        ),
      ],
    );
  }
}

/// 小型图标按钮
class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  const _SmallIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = color ?? colorScheme.onSurfaceVariant;

    final button = SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: onPressed != null
            ? effectiveColor
            : effectiveColor.withOpacity(0.3),
        splashRadius: 14,
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
