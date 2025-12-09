import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import 'character_editor_dialog.dart';

/// 角色摘要组件
///
/// 在主提示词区域显示角色配置的紧凑摘要。
/// 显示角色数量和名称列表，悬停时显示详细信息工具提示。
///
/// Requirements: 5.1, 5.2
class CharacterSummary extends ConsumerWidget {
  /// 是否可点击打开编辑器
  final bool clickable;

  /// 最大显示的角色名称数量
  final int maxDisplayNames;

  const CharacterSummary({
    super.key,
    this.clickable = true,
    this.maxDisplayNames = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(characterListProvider);

    if (characters.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 构建摘要文本
    final summaryText = _buildSummaryText(characters);
    final tooltipText = _buildTooltipText(characters);

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.primaryContainer.withOpacity(0.3),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              summaryText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );

    // 添加工具提示
    content = Tooltip(
      message: tooltipText,
      preferBelow: true,
      verticalOffset: 20,
      child: content,
    );

    // 如果可点击，添加点击处理
    if (clickable) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => CharacterEditorDialog.show(context),
          child: content,
        ),
      );
    }

    return content;
  }

  /// 构建摘要文本
  String _buildSummaryText(List<CharacterPrompt> characters) {
    final count = characters.length;
    final enabledCount = characters.where((c) => c.enabled).length;

    // 获取角色名称列表
    final names = characters
        .take(maxDisplayNames)
        .map((c) => c.name)
        .toList();

    final namesText = names.join(', ');
    final hasMore = count > maxDisplayNames;

    if (enabledCount < count) {
      // 有禁用的角色
      return '$namesText${hasMore ? '...' : ''} ($enabledCount/$count)';
    } else {
      return '$namesText${hasMore ? '...' : ''} ($count)';
    }
  }

  /// 构建工具提示文本
  String _buildTooltipText(List<CharacterPrompt> characters) {
    final buffer = StringBuffer();
    buffer.writeln('多人角色提示词');
    buffer.writeln('─────────────');

    for (int i = 0; i < characters.length; i++) {
      final char = characters[i];
      final genderIcon = _getGenderIcon(char.gender);
      final positionText = _getPositionText(char);
      final enabledText = char.enabled ? '' : ' [禁用]';

      buffer.writeln('${i + 1}. $genderIcon ${char.name}$enabledText');
      buffer.writeln('   位置: $positionText');

      if (char.prompt.isNotEmpty) {
        final promptPreview = char.prompt.length > 30
            ? '${char.prompt.substring(0, 30)}...'
            : char.prompt;
        buffer.writeln('   提示词: $promptPreview');
      }

      if (i < characters.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  String _getGenderIcon(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return '♀';
      case CharacterGender.male:
        return '♂';
      case CharacterGender.other:
        return '⚥';
    }
  }

  String _getPositionText(CharacterPrompt character) {
    if (character.positionMode == CharacterPositionMode.aiChoice) {
      return 'AI选择';
    }
    if (character.customPosition != null) {
      final pos = character.customPosition!;
      final col = String.fromCharCode('A'.codeUnitAt(0) + pos.column);
      final row = (pos.row + 1).toString();
      return '$col$row';
    }
    return 'AI选择';
  }
}

/// 紧凑版角色摘要（仅显示数量）
///
/// 用于空间非常受限的场景
class CompactCharacterSummary extends ConsumerWidget {
  final bool clickable;

  const CompactCharacterSummary({
    super.key,
    this.clickable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characterCount = ref.watch(characterCountProvider);
    final enabledCount = ref.watch(enabledCharacterCountProvider);

    if (characterCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayText = enabledCount < characterCount
        ? '$enabledCount/$characterCount 角色'
        : '$characterCount 角色';

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primaryContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            size: 14,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (clickable) {
      content = Tooltip(
        message: '点击编辑多人角色提示词',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => CharacterEditorDialog.show(context),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

/// 角色摘要行组件
///
/// 显示完整的角色摘要行，包含图标、摘要文本和编辑按钮
class CharacterSummaryRow extends ConsumerWidget {
  const CharacterSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(characterListProvider);

    if (characters.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CharacterNamesList(characters: characters),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => CharacterEditorDialog.show(context),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('编辑'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色名称列表组件
class _CharacterNamesList extends StatelessWidget {
  final List<CharacterPrompt> characters;

  const _CharacterNamesList({required this.characters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: characters.map((char) {
        final genderIcon = _getGenderIcon(char.gender);
        final isDisabled = !char.enabled;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isDisabled
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer.withOpacity(0.5),
          ),
          child: Text(
            '$genderIcon ${char.name}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDisabled
                  ? colorScheme.onSurface.withOpacity(0.5)
                  : colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getGenderIcon(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return '♀';
      case CharacterGender.male:
        return '♂';
      case CharacterGender.other:
        return '⚥';
    }
  }
}
