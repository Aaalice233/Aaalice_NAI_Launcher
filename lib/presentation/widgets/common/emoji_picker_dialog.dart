import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import 'adaptive_dialog_frame.dart';

/// Emoji 选择器对话框
///
/// 用于选择 emoji 图标，支持搜索和分类浏览
/// 点击 emoji 即选中并返回，无需二次确认
class EmojiPickerDialog extends StatelessWidget {
  const EmojiPickerDialog({super.key});

  /// 显示 emoji 选择器对话框
  ///
  /// 返回选中的 emoji 字符串，如果用户取消则返回 null
  static Future<String?> show(BuildContext context, {String? initialEmoji}) {
    return AdaptivePresenter.showForm<String>(
      context: context,
      title: context.l10n.category_selectEmoji,
      dialogWidth: 440,
      builder: (context, scrollController) => const EmojiPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final picker = AdaptiveDialogFrame(
      maxWidth: 400,
      maxHeight: 420,
      reservedVerticalSpace: 80,
      scaleReservedVerticalSpace: true,
      horizontalMargin: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 280 ? 5 : 8;
          return EmojiPicker(
            onEmojiSelected: (category, emoji) {
              // 选中即返回，无需二次确认
              Navigator.pop(context, emoji.emoji);
            },
            config: Config(
              height: constraints.maxHeight,
              checkPlatformCompatibility: true,
              emojiViewConfig: EmojiViewConfig(
                columns: columns,
                emojiSizeMax: 28,
                verticalSpacing: 0,
                horizontalSpacing: 0,
                gridPadding: EdgeInsets.zero,
                backgroundColor: theme.colorScheme.surface,
                noRecents: Text(
                  context.l10n.category_noRecentEmoji,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              categoryViewConfig: CategoryViewConfig(
                initCategory: Category.SMILEYS,
                backgroundColor: theme.colorScheme.surface,
                indicatorColor: theme.colorScheme.primary,
                iconColor: theme.colorScheme.onSurfaceVariant,
                iconColorSelected: theme.colorScheme.primary,
                categoryIcons: const CategoryIcons(),
              ),
              bottomActionBarConfig: const BottomActionBarConfig(
                enabled: false,
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: theme.colorScheme.surface,
                buttonIconColor: theme.colorScheme.primary,
                hintText: context.l10n.category_searchEmoji,
              ),
            ),
          );
        },
      ),
    );
    final cancel = TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(context.l10n.common_cancel),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Expanded(child: picker),
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: cancel,
            ),
          ),
        ],
      ),
    );
  }
}
