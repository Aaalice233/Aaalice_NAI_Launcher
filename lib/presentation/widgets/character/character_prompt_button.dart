import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/character_prompt_provider.dart';
import 'character_editor_dialog.dart';

/// 多人角色提示词触发按钮
///
/// 显示在提示词区域工具栏中，点击打开角色编辑对话框。
/// 当存在角色时，显示角色数量徽章。
///
/// Requirements: 1.1, 5.3
class CharacterPromptButton extends ConsumerWidget {
  const CharacterPromptButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characterCount = ref.watch(characterCountProvider);
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: hasCharacters
          ? '多人角色提示词 ($characterCount 个角色)'
          : '多人角色提示词',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => CharacterEditorDialog.show(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasCharacters
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
              color: hasCharacters
                  ? colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 18,
                  color: hasCharacters
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                if (hasCharacters) ...[
                  const SizedBox(width: 4),
                  _CharacterCountBadge(count: characterCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 角色数量徽章
class _CharacterCountBadge extends StatelessWidget {
  final int count;

  const _CharacterCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// 紧凑版角色提示词按钮（仅图标）
///
/// 用于空间受限的工具栏
class CharacterPromptIconButton extends ConsumerWidget {
  const CharacterPromptIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characterCount = ref.watch(characterCountProvider);
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => CharacterEditorDialog.show(context),
          icon: Icon(
            hasCharacters ? Icons.people : Icons.people_outline,
            color: hasCharacters
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          tooltip: hasCharacters
              ? '多人角色提示词 ($characterCount 个角色)'
              : '多人角色提示词',
        ),
        if (hasCharacters)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                characterCount.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
