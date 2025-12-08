import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../themes/theme_extension.dart';

class ThemedScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? endDrawer;
  final Widget? drawer;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const ThemedScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.endDrawer,
    this.drawer,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    final enableCrt = extension?.enableCrtEffect ?? false;
    final enableDotMatrix = extension?.enableDotMatrix ?? false;

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          // 主内容
          body,

          // 点阵背景效果
          if (enableDotMatrix)
            IgnorePointer(
              child: CustomPaint(
                painter: _DotMatrixPainter(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ),

          // CRT 扫描线效果 Overlay
          if (enableCrt)
            IgnorePointer(
              child: CustomPaint(
                painter: _ScanLinePainter(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ),

          // 简单的晕影效果 (Vignette)
          if (enableCrt)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      endDrawer: endDrawer,
      drawer: drawer,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: backgroundColor,
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final Color color;
  final double spacing = 10.0;

  _DotMatrixPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLinePainter extends CustomPainter {
  final Color color;

  _ScanLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double i = 0; i < size.height; i += 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
