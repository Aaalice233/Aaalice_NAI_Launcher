import 'package:flutter/material.dart';

import '../../../../themes/core/layered_surface_style.dart';
import '../../../common/heading_semantics.dart';

/// 工具栏里的一组工具：组标题与所属按钮在同一块色面内
class EditorToolGroupSection extends StatelessWidget {
  const EditorToolGroupSection({
    super.key,
    required this.axis,
    required this.children,
    this.title,
  });

  final Axis axis;
  final List<Widget> children;

  /// 为空时只保留色面分段，不显示标题
  final String? title;

  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vertical = axis == Axis.vertical;
    final title = this.title;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sectionSurfaceColor(theme.colorScheme),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: _inset)
              : const EdgeInsets.symmetric(horizontal: _inset),
          child: Flex(
            direction: axis,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Padding(
                  padding: vertical
                      ? const EdgeInsets.fromLTRB(2, 2, 2, _inset)
                      : const EdgeInsets.symmetric(horizontal: _inset + 2),
                  child: HeadingSemantics(
                    level: 3,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
