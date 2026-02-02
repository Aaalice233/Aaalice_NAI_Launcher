import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../presentation/providers/pending_prompt_provider.dart';

/// 发送到主页选项对话框
///
/// 显示三个选项供用户选择：
/// 1. 发送到主提示词
/// 2. 替换角色提示词（清空后添加）
/// 3. 追加角色提示词（保留现有）
class SendToHomeDialog extends StatelessWidget {
  final TagLibraryEntry entry;

  const SendToHomeDialog({
    super.key,
    required this.entry,
  });

  /// 显示对话框并返回用户选择的目标类型
  static Future<SendTargetType?> show(
    BuildContext context, {
    required TagLibraryEntry entry,
  }) {
    return showDialog<SendTargetType>(
      context: context,
      builder: (context) => SendToHomeDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.send_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.sendToHome_dialogTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 条目信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.contentPreview,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 选项列表
              _OptionButton(
                icon: Icons.auto_awesome,
                iconColor: theme.colorScheme.primary,
                title: context.l10n.sendToHome_mainPrompt,
                subtitle: context.l10n.sendToHome_mainPromptSubtitle,
                onTap: () => Navigator.of(context).pop(SendTargetType.mainPrompt),
              ),

              const SizedBox(height: 8),

              _OptionButton(
                icon: Icons.swap_horiz,
                iconColor: theme.colorScheme.secondary,
                title: context.l10n.sendToHome_replaceCharacter,
                subtitle: context.l10n.sendToHome_replaceCharacterSubtitle,
                onTap: () =>
                    Navigator.of(context).pop(SendTargetType.replaceCharacter),
              ),

              const SizedBox(height: 8),

              _OptionButton(
                icon: Icons.person_add,
                iconColor: theme.colorScheme.tertiary,
                title: context.l10n.sendToHome_appendCharacter,
                subtitle: context.l10n.sendToHome_appendCharacterSubtitle,
                onTap: () =>
                    Navigator.of(context).pop(SendTargetType.appendCharacter),
              ),

              const SizedBox(height: 8),

              // 取消按钮
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.common_cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 选项按钮
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
