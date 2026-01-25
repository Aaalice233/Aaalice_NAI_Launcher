import 'package:flutter/material.dart';

/// 柔和分割线 - 使用凹槽效果替代刺眼的白线
///
/// 设计原理：使用阴影线+高光线模拟物理凹槽，
/// 比纯色线条柔和得多，且具有质感。
class SoftDivider extends StatelessWidget {
  /// 分割线区域的总高度（包含上下留白）
  final double height;

  /// 左侧缩进
  final double indent;

  /// 右侧缩进
  final double endIndent;

  /// 是否为垂直分割线
  final bool vertical;

  const SoftDivider({
    super.key,
    this.height = 16.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 阴影色：模拟凹槽的深处
    final shadowColor =
        isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05);

    // 高光色：模拟凹槽下边缘的反光
    final highlightColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.white;

    return SizedBox(
      width: vertical ? height : null,
      height: vertical ? null : height,
      child: Center(
        child: Container(
          width: vertical ? 1.0 : null,
          height: vertical ? null : 1.0,
          margin: EdgeInsetsDirectional.only(
            start: indent,
            end: endIndent,
            top: vertical ? indent : 0,
            bottom: vertical ? endIndent : 0,
          ),
          decoration: BoxDecoration(
            // 渐变让两端柔和消失
            gradient: LinearGradient(
              begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: [
                Colors.transparent,
                shadowColor,
                shadowColor,
                Colors.transparent,
              ],
              stops: const [0.0, 0.15, 0.85, 1.0],
            ),
            // 高光偏移制造凹槽边缘感
            boxShadow: [
              BoxShadow(
                color: highlightColor,
                offset: vertical ? const Offset(1, 0) : const Offset(0, 1),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
