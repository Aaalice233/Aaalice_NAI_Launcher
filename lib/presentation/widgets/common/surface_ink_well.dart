import 'package:flutter/material.dart';

import 'ink_host.dart';

/// 自带底色的可点击面。
///
/// 底色与阴影画在墨水之下，描边画在墨水之上且不参与布局，
/// 选中切换不改变内容尺寸，悬停、焦点与按压反馈始终可见。
class SurfaceInkWell extends StatelessWidget {
  const SurfaceInkWell({
    super.key,
    required this.borderRadius,
    required this.onTap,
    required this.child,
    this.color,
    this.gradient,
    this.shadows,
    this.side = BorderSide.none,
    this.clipBehavior = Clip.none,
    this.inkAboveChild = false,
    this.hoverColor,
    this.duration = Duration.zero,
    this.curve = Curves.linear,
  });

  final BorderRadiusGeometry borderRadius;
  final VoidCallback? onTap;
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final BorderSide side;
  final Clip clipBehavior;

  /// 图片等不透明内容会盖住墨水，开启后墨水层叠在内容之上；
  /// 此时由墨水层接管整块区域的点击，内容里不能再放可交互控件。
  final bool inkAboveChild;
  final Color? hoverColor;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final ink = InkWell(
      onTap: onTap,
      hoverColor: hoverColor,
      customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
      child: inkAboveChild ? null : child,
    );
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      curve: curve,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        boxShadow: shadows,
        borderRadius: borderRadius,
      ),
      // Container 只把 decoration 的边框宽度计入内边距，前景描边不占位
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
      ),
      child: inkAboveChild
          ? Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                Positioned.fill(child: InkHost(child: ink)),
              ],
            )
          : InkHost(child: ink),
    );
  }
}
