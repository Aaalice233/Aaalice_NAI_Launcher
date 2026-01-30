import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/character_prompt_provider.dart';
import '../common/themed_switch.dart';
import 'add_character_buttons.dart';
import 'character_card_grid.dart';
import 'character_edit_dialog.dart';

/// 角色编辑器对话框组件
///
/// 用于编辑多人角色的模态对话框，采用卡片网格布局：
/// - 顶部：添加按钮行（女/男/其他/词库）
/// - 中间：角色卡片网格
/// - 底部：全局AI选择开关 + 操作按钮
///
/// Requirements: 6.1, 6.2, 6.3, 6.4
class CharacterEditorDialog extends ConsumerWidget {
  const CharacterEditorDialog({super.key});

  /// 显示角色编辑器对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const CharacterEditorDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(characterPromptNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        width: isDesktop ? 680 : double.infinity,
        height: isDesktop ? 620 : MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // 头部
            _DialogHeader(onClose: () => Navigator.of(context).pop()),

            // 添加按钮行
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AddCharacterButtons(),
            ),

            // 卡片网格
            Expanded(
              child: CharacterCardGrid(
                globalAiChoice: config.globalAiChoice,
                onCardTap: (character) {
                  CharacterEditDialog.show(
                    context,
                    character,
                    config.globalAiChoice,
                  );
                },
                onDelete: (id) => _showDeleteConfirm(context, ref, id),
              ),
            ),

            // 底部
            _DialogFooter(
              hasCharacters: config.characters.isNotEmpty,
              globalAiChoice: config.globalAiChoice,
              onGlobalAiChoiceChanged: (value) {
                ref
                    .read(characterPromptNotifierProvider.notifier)
                    .setGlobalAiChoice(value);
              },
              onClearAll: () => _showClearAllConfirm(context, ref),
              onConfirm: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.characterEditor_deleteTitle),
        content: Text(l10n.characterEditor_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(characterPromptNotifierProvider.notifier).removeCharacter(id);
    }
  }

  Future<void> _showClearAllConfirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.characterEditor_clearAllTitle),
        content: Text(l10n.characterEditor_clearAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.common_clear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    }
  }
}

/// 对话框头部组件
class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
          Icon(
            Icons.people,
            size: 24,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.characterEditor_title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: l10n.characterEditor_close,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 对话框底部组件
class _DialogFooter extends StatelessWidget {
  final bool hasCharacters;
  final bool globalAiChoice;
  final ValueChanged<bool> onGlobalAiChoiceChanged;
  final VoidCallback onClearAll;
  final VoidCallback onConfirm;

  const _DialogFooter({
    required this.hasCharacters,
    required this.globalAiChoice,
    required this.onGlobalAiChoiceChanged,
    required this.onClearAll,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        children: [
          // 全局AI选择开关
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onGlobalAiChoiceChanged(!globalAiChoice),
                child: Text(
                  l10n.characterEditor_globalAiChoice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.characterEditor_globalAiChoiceHint,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              ThemedSwitch(
                value: globalAiChoice,
                onChanged: onGlobalAiChoiceChanged,
                scale: 0.85,
              ),
            ],
          ),

          const Spacer(),

          // 清空所有按钮
          if (hasCharacters)
            TextButton.icon(
              onPressed: onClearAll,
              icon: Icon(
                Icons.delete_sweep,
                size: 18,
                color: colorScheme.error,
              ),
              label: Text(
                l10n.characterEditor_clearAll,
                style: TextStyle(color: colorScheme.error),
              ),
            ),

          const SizedBox(width: 12),

          // 确定按钮
          FilledButton(
            onPressed: onConfirm,
            child: Text(l10n.characterEditor_confirm),
          ),
        ],
      ),
    );
  }
}
