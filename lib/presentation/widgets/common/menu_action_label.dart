import 'package:flutter/material.dart';

/// 弹出菜单项的“前导图标 + 文案 + 尾部标记”内容，文案在菜单宽度内换行。
///
/// 只负责内容排版；value、enabled、onTap 仍由外层 [PopupMenuItem] 持有。
class MenuActionLabel extends StatelessWidget {
  const MenuActionLabel({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.destructive = false,
    this.color,
    this.iconColor,
    this.fontWeight,
    this.iconSize = 18,
    this.gap = 8,
  });

  final String label;

  /// 通常为 [Icon]，尺寸与颜色由 [iconSize]、[iconColor] 经 [IconTheme] 提供。
  final Widget? leading;

  /// 贴右显示，如选中勾选或排序方向。
  final Widget? trailing;

  /// 与外层菜单项一致；禁用时不再显示危险色。
  final bool enabled;

  /// 危险操作，图标与文案使用 [ColorScheme.error]。
  final bool destructive;

  /// 图标与文案共用的强调色，危险色优先。
  final Color? color;

  /// 仅作用于前导图标，[color] 与危险色优先。
  final Color? iconColor;

  /// 文案字重，用于区分当前选中项。
  final FontWeight? fontWeight;

  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive && enabled
        ? Theme.of(context).colorScheme.error
        : color;
    final leading = this.leading;

    return Row(
      children: [
        if (leading != null) ...[
          IconTheme.merge(
            data: IconThemeData(size: iconSize, color: foreground ?? iconColor),
            child: leading,
          ),
          SizedBox(width: gap),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: foreground, fontWeight: fontWeight),
          ),
        ),
        if (trailing case final trailing?) trailing,
      ],
    );
  }
}
