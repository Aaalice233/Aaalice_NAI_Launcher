import 'package:flutter/widgets.dart';

/// 两个统计块并排；按字号折算后的宽度不足 [stackBelowWidth] 时上下排列
class StatPairLayout extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double spacing;

  const StatPairLayout({
    super.key,
    required this.first,
    required this.second,
    this.spacing = 12,
  });

  static const double stackBelowWidth = 360;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth / textScale.clamp(1.0, 3.0) <
            stackBelowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, SizedBox(height: spacing), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
