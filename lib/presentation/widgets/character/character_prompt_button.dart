import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import 'character_editor_dialog.dart';
import 'character_tooltip_content.dart';

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
    final config = ref.watch(characterPromptNotifierProvider);
    final characterCount = config.characters.length;
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CharacterTooltipWrapper(
      config: config,
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
    final config = ref.watch(characterPromptNotifierProvider);
    final characterCount = config.characters.length;
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CharacterTooltipWrapper(
      config: config,
      child: Stack(
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
      ),
    );
  }
}

/// 自定义悬浮提示包装器
///
/// 提供详细的多角色配置信息悬浮提示
class _CharacterTooltipWrapper extends StatelessWidget {
  final CharacterPromptConfig config;
  final Widget child;

  const _CharacterTooltipWrapper({
    required this.config,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      richMessage: WidgetSpan(
        child: CharacterTooltipContent(config: config),
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      child: child,
    );
  }
}
