import 'package:flutter/material.dart';

/// 可复用的 GitHub 品牌图标。
class GitHubLogo extends StatelessWidget {
  const GitHubLogo({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GitHubLogoPainter(color: color),
    );
  }
}

class _GitHubLogoPainter extends CustomPainter {
  final Color color;

  _GitHubLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scale = size.width / 24;

    // GitHub Octocat 简化路径
    path.moveTo(12 * scale, 0.5 * scale);
    path.cubicTo(
      5.37 * scale,
      0.5 * scale,
      0 * scale,
      5.87 * scale,
      0 * scale,
      12.5 * scale,
    );
    path.cubicTo(
      0 * scale,
      17.83 * scale,
      3.44 * scale,
      22.31 * scale,
      8.21 * scale,
      23.75 * scale,
    );
    path.cubicTo(
      8.81 * scale,
      23.86 * scale,
      9.02 * scale,
      23.5 * scale,
      9.02 * scale,
      23.18 * scale,
    );
    path.cubicTo(
      9.02 * scale,
      22.9 * scale,
      9.01 * scale,
      22.21 * scale,
      9.01 * scale,
      21.29 * scale,
    );
    path.cubicTo(
      5.67 * scale,
      22.03 * scale,
      4.97 * scale,
      19.68 * scale,
      4.97 * scale,
      19.68 * scale,
    );
    path.cubicTo(
      4.42 * scale,
      18.42 * scale,
      3.63 * scale,
      18.05 * scale,
      3.63 * scale,
      18.05 * scale,
    );
    path.cubicTo(
      2.55 * scale,
      17.33 * scale,
      3.71 * scale,
      17.35 * scale,
      3.71 * scale,
      17.35 * scale,
    );
    path.cubicTo(
      4.91 * scale,
      17.43 * scale,
      5.54 * scale,
      18.55 * scale,
      5.54 * scale,
      18.55 * scale,
    );
    path.cubicTo(
      6.61 * scale,
      20.31 * scale,
      8.36 * scale,
      19.79 * scale,
      9.05 * scale,
      19.49 * scale,
    );
    path.cubicTo(
      9.16 * scale,
      18.77 * scale,
      9.46 * scale,
      18.25 * scale,
      9.79 * scale,
      17.96 * scale,
    );
    path.cubicTo(
      7.14 * scale,
      17.67 * scale,
      4.34 * scale,
      16.72 * scale,
      4.34 * scale,
      12.18 * scale,
    );
    path.cubicTo(
      4.34 * scale,
      10.99 * scale,
      4.78 * scale,
      10.02 * scale,
      5.56 * scale,
      9.25 * scale,
    );
    path.cubicTo(
      5.44 * scale,
      8.96 * scale,
      5.04 * scale,
      7.85 * scale,
      5.67 * scale,
      6.35 * scale,
    );
    path.cubicTo(
      5.67 * scale,
      6.35 * scale,
      6.68 * scale,
      6.04 * scale,
      8.99 * scale,
      7.44 * scale,
    );
    path.cubicTo(
      9.87 * scale,
      7.19 * scale,
      10.94 * scale,
      7.06 * scale,
      12 * scale,
      7.06 * scale,
    );
    path.cubicTo(
      13.06 * scale,
      7.06 * scale,
      14.13 * scale,
      7.19 * scale,
      15.01 * scale,
      7.44 * scale,
    );
    path.cubicTo(
      17.32 * scale,
      6.04 * scale,
      18.33 * scale,
      6.35 * scale,
      18.33 * scale,
      6.35 * scale,
    );
    path.cubicTo(
      18.96 * scale,
      7.85 * scale,
      18.56 * scale,
      8.96 * scale,
      18.44 * scale,
      9.25 * scale,
    );
    path.cubicTo(
      19.22 * scale,
      10.02 * scale,
      19.66 * scale,
      10.99 * scale,
      19.66 * scale,
      12.18 * scale,
    );
    path.cubicTo(
      19.66 * scale,
      16.73 * scale,
      16.86 * scale,
      17.67 * scale,
      14.21 * scale,
      17.96 * scale,
    );
    path.cubicTo(
      14.62 * scale,
      18.31 * scale,
      15 * scale,
      19 * scale,
      15 * scale,
      20.04 * scale,
    );
    path.cubicTo(
      15 * scale,
      21.51 * scale,
      14.99 * scale,
      22.7 * scale,
      14.99 * scale,
      23.18 * scale,
    );
    path.cubicTo(
      14.99 * scale,
      23.5 * scale,
      15.19 * scale,
      23.87 * scale,
      15.81 * scale,
      23.75 * scale,
    );
    path.cubicTo(
      20.57 * scale,
      22.31 * scale,
      24 * scale,
      17.83 * scale,
      24 * scale,
      12.5 * scale,
    );
    path.cubicTo(
      24 * scale,
      5.87 * scale,
      18.63 * scale,
      0.5 * scale,
      12 * scale,
      0.5 * scale,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GitHubLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
