import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../common/elevated_card.dart';
import '../../common/themed_divider.dart';
import 'diy_panel_header.dart';

/// 编辑列表中选中的规则或分支：带关闭按钮的标题与字段
class DiyEditorCard extends StatelessWidget {
  const DiyEditorCard({
    super.key,
    required this.title,
    required this.accent,
    required this.accentContainer,
    required this.borderEnd,
    required this.onClose,
    required this.children,
  });

  final String title;
  final Color accent;
  final Color accentContainer;

  /// 渐变边框末端的颜色，起点取 [accent]
  final Color borderEnd;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedCard(
      elevation: CardElevation.level2,
      borderRadius: 12,
      gradientBorder: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.5),
          borderEnd.withValues(alpha: 0.3),
        ],
      ),
      gradientBorderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: Icons.edit_rounded,
            accent: accent,
            container: accentContainer,
            title: title,
            trailing: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: onClose,
              tooltip: context.l10n.common_close,
            ),
          ),
          const SizedBox(height: 12),
          const ThemedDivider(),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
