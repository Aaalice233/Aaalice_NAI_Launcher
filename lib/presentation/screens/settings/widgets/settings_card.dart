import 'package:flutter/material.dart';

/// 设置卡片组件
/// 
/// 统一设置板块的卡片样式，支持标题、图标、右侧操作按钮和内容区。
class SettingsCard extends StatelessWidget {
  /// 标题文字
  final String title;

  /// 可选图标
  final IconData? icon;

  /// 可选右侧操作按钮
  final Widget? trailing;

  /// 内容区
  final Widget child;

  /// 是否显示底部分隔线（默认 true）
  final bool showDivider;

  const SettingsCard({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // 内容区域
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: child,
          ),
          // 分隔线
          if (showDivider)
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
        ],
      ),
    );
  }
}
