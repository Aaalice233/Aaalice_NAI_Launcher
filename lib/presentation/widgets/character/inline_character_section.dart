import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import 'add_character_buttons.dart';
import 'character_position_canvas.dart';
import 'inline_character_card.dart';
import 'inline_character_editor.dart';

/// 内联角色区块（官网布局左栏用，竖排）
///
/// 位于主提示词正下方，与主提示词同屏对照编辑：
/// - 标题行：图标 + 数量徽章 + 清空菜单
/// - 角色卡竖排（内容常显，点击即编辑）
/// - 底部添加按钮行（女/男/其他/词库）
///
/// 仅 V4+ 模型显示（多角色为 V4 专属能力）。
class InlineCharacterSection extends ConsumerWidget {
  const InlineCharacterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isV4Model = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => ImageModels.isV4Model(params.model),
      ),
    );
    if (!isV4Model) {
      return const SizedBox.shrink();
    }

    final config = ref.watch(characterPromptNotifierProvider);
    final characters = config.characters;
    final hasCharacters = characters.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: hasCharacters
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.character_buttonLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: hasCharacters
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasCharacters) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${characters.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 位置模式常驻在角色模块头部（有角色时显示）
              if (hasCharacters) ...[
                const CharacterPositionModeSegments(),
                const SizedBox(width: 8),
              ],
              if (hasCharacters)
                Tooltip(
                  message: l10n.characterEditor_clearAll,
                  waitDuration: const Duration(milliseconds: 500),
                  child: InkWell(
                    onTap: () => confirmClearAllCharacters(context, ref),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_sweep,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var i = 0; i < characters.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InlineCharacterCard(
              key: ValueKey(characters[i].id),
              character: characters[i],
              index: i,
              total: characters.length,
            ),
          ),
        const AddCharacterButtons(),
      ],
    );
  }
}
