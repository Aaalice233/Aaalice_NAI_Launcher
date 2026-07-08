import 'package:flutter/material.dart';

import 'resize_handle.dart';

/// 官网式布局左栏的上下分区骨架
///
/// 上分区放提示词区、下分区放设置区、footer 钉底。
/// 上下分区按 [ratio] 分配可用高度并各自独立约束，
/// 上分区内容再长也不会挤压下分区——这是官网式布局的核心承诺。
class WebPanelSplit extends StatelessWidget {
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final VoidCallback onRatioReset;
  final Widget topSection;
  final Widget bottomSection;
  final Widget footer;

  static const double minRatio = 0.2;
  static const double maxRatio = 0.8;

  const WebPanelSplit({
    super.key,
    required this.ratio,
    required this.onRatioChanged,
    required this.onRatioReset,
    required this.topSection,
    required this.bottomSection,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final effectiveRatio = ratio.clamp(minRatio, maxRatio).toDouble();

        return Column(
          children: [
            Expanded(
              flex: (effectiveRatio * 1000).round(),
              child: ClipRect(child: topSection),
            ),
            GestureDetector(
              onDoubleTap: onRatioReset,
              child: VerticalResizeHandle(
                onDrag: (dy) {
                  if (availableHeight <= 0) return;
                  final newRatio = (effectiveRatio + dy / availableHeight)
                      .clamp(minRatio, maxRatio)
                      .toDouble();
                  onRatioChanged(newRatio);
                },
              ),
            ),
            Expanded(
              flex: ((1 - effectiveRatio) * 1000).round(),
              child: ClipRect(child: bottomSection),
            ),
            footer,
          ],
        );
      },
    );
  }
}
