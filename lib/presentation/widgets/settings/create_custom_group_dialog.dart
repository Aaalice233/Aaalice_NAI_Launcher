import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_tag_group.dart';
import '../../screens/prompt_config/widgets/custom_tag_group_editor.dart';

/// 创建自定义词组对话框
///
/// 独立的对话框，用于创建新的自定义词组。
/// 包装 [CustomTagGroupEditor] 组件，提供保存和取消功能。
class CreateCustomGroupDialog extends ConsumerWidget {
  /// 初始词组（用于编辑模式）
  final RandomTagGroup? initialGroup;

  const CreateCustomGroupDialog({
    super.key,
    this.initialGroup,
  });

  /// 显示创建自定义词组对话框
  ///
  /// 返回创建的 [RandomTagGroup]，如果取消则返回 null
  static Future<RandomTagGroup?> show(
    BuildContext context, {
    RandomTagGroup? initialGroup,
  }) {
    return showDialog<RandomTagGroup>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateCustomGroupDialog(
        initialGroup: initialGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 460,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏（更紧凑）
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  initialGroup != null
                      ? l10n.customGroup_editEntry
                      : l10n.cache_createCustomGroup,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 编辑器内容
            Expanded(
              child: CustomTagGroupEditor(
                initialGroup: initialGroup,
                onSave: (group) {
                  Navigator.of(context).pop(group);
                },
                onCancel: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
