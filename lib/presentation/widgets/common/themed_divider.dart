import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';

/// 低对比结构分隔线。
///
/// 只用于真实的区域分组，不承担卡片描边职责。
class ThemedDivider extends StatelessWidget {
  const ThemedDivider({
    super.key,
    this.height = 16,
    this.indent = 0,
    this.endIndent = 0,
    this.vertical = false,
  });

  final double height;
  final double indent;
  final double endIndent;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final extension = Theme.of(context).appTheme;
    if (!extension.useDivider) return const SizedBox.shrink();

    if (vertical) {
      return VerticalDivider(
        width: height,
        thickness: extension.dividerThickness,
        indent: indent,
        endIndent: endIndent,
        color: extension.dividerColor,
      );
    }
    return Divider(
      height: height,
      thickness: extension.dividerThickness,
      indent: indent,
      endIndent: endIndent,
      color: extension.dividerColor,
    );
  }
}
