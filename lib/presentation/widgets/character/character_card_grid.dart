import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import 'character_card.dart';

/// 角色卡片网格组件
///
/// 以网格形式展示所有角色卡片，支持：
/// - 响应式布局（根据屏幕宽度调整列数）
/// - 竖直ID卡片比例（0.72:1）
/// - 空状态展示
class CharacterCardGrid extends ConsumerWidget {
  final bool globalAiChoice;
  final ValueChanged<CharacterPrompt>? onCardTap;
  final ValueChanged<String>? onDelete;
  final EdgeInsetsGeometry? padding;

  const CharacterCardGrid({
    super.key,
    this.globalAiChoice = false,
    this.onCardTap,
    this.onDelete,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(characterListProvider);

    if (characters.isEmpty) {
      return const _EmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算卡片尺寸
        const cardWidth = 160.0;
        const spacing = 12.0;
        final maxColumns = ((constraints.maxWidth - 24) / (cardWidth + spacing))
            .floor()
            .clamp(1, 5);
        final actualCardWidth =
            (constraints.maxWidth - 24 - (maxColumns - 1) * spacing) /
                maxColumns;
        final cardHeight = actualCardWidth / 0.72;

        return SingleChildScrollView(
          padding: padding ?? const EdgeInsets.all(12),
          child: Center(
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: characters.map((character) {
                return SizedBox(
                  width: actualCardWidth,
                  height: cardHeight,
                  child: CharacterCard(
                    key: ValueKey(character.id),
                    character: character,
                    globalAiChoice: globalAiChoice,
                    onTap: () => onCardTap?.call(character),
                    onEnabledChanged: (value) {
                      ref
                          .read(characterPromptNotifierProvider.notifier)
                          .updateCharacter(character.copyWith(enabled: value));
                    },
                    onDelete: () => onDelete?.call(character.id),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.characterEditor_emptyTitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.characterEditor_emptyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
