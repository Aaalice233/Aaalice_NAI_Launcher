import 'package:flutter/material.dart';

import '../../themes/core/layered_surface_style.dart';

/// 生成工作区各主面板共享的紧凑标题栏。
class WorkspacePanelHeader extends StatelessWidget {
  const WorkspacePanelHeader({
    super.key,
    required this.icon,
    required this.title,
    this.leading,
    this.actions = const [],
    this.trailing,
  });

  static const double _edgePadding = 4;
  static const double _titleOnlyStartPadding = 12;
  static const double _leadingGap = 4;
  static const double _iconSize = 20;
  static const double _iconGap = 8;

  /// 标题栏自身占用的水平宽度（不含 leading、actions 与标题）。
  static double chromeWidth({required bool hasLeading}) =>
      (hasLeading ? _edgePadding + _leadingGap : _titleOnlyStartPadding) +
      _edgePadding +
      _iconSize +
      _iconGap;

  final IconData icon;
  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: sectionSurfaceColor(colors),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsets.only(
            left: leading == null ? _titleOnlyStartPadding : _edgePadding,
            right: _edgePadding,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: _leadingGap),
              ],
              Icon(icon, size: _iconSize, color: colors.primary),
              const SizedBox(width: _iconGap),
              Expanded(child: title),
              ...actions,
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
