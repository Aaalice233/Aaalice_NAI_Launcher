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
            left: leading == null ? 12 : 4,
            right: 4,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
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
