import 'package:flutter/material.dart';

/// 透明图片的预览底色（对齐官网结果区的 transparencyBackground 设置）
///
/// 存储值与官网保持一致：三档棋盘格、`none`、六个具名纯色，以及
/// `#RRGGBB` 形式的自定义颜色。这样以后官网新增档位时可直接对齐。
class TransparencyBackgrounds {
  const TransparencyBackgrounds._();

  /// 跟随主题的棋盘格（默认值）
  static const String checker = 'checker';
  static const String checkerLight = 'checkerLight';
  static const String checkerDark = 'checkerDark';

  /// 不铺底色，透明区直接透出面板背景
  static const String none = 'none';

  static const String defaultStyle = checker;

  /// 官网提供的具名纯色
  static const Map<String, Color> solidColors = {
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'gray': Color(0xFF808080),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF00FF00),
    'blue': Color(0xFF0000FF),
  };

  /// 棋盘格档位的固定配色（`checker` 跟随主题，不在此表内）
  static const Map<String, (Color, Color)> _checkerColors = {
    checkerLight: (Color(0xFFCCCCCC), Color(0xFFFFFFFF)),
    checkerDark: (Color(0xFF494949), Color(0xFF2A2A2A)),
  };

  static bool isChecker(String style) =>
      style == checker || _checkerColors.containsKey(style);

  static bool isCustomColor(String style) => style.startsWith('#');

  /// 解析自定义颜色，格式非法时回退到 `null`
  static Color? parseCustomColor(String style) {
    if (!isCustomColor(style)) return null;
    final hex = style.substring(1);
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  static String encodeCustomColor(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  /// 归一化存储值，未知值回退到默认棋盘格
  static String normalize(String? style) {
    if (style == null || style.isEmpty) return defaultStyle;
    if (style == checker || style == none) return style;
    if (_checkerColors.containsKey(style)) return style;
    if (solidColors.containsKey(style)) return style;
    if (parseCustomColor(style) != null) return style.toLowerCase();
    return defaultStyle;
  }

  /// 取棋盘格的（格子色，底色）；非棋盘格档位返回 `null`
  static (Color, Color)? checkerColorsOf(String style, ThemeData theme) {
    if (style == checker) {
      // 官网用 bg1 打底、bg2 混出格子色，这里对应到主题的表面层级
      final base = theme.colorScheme.surface;
      final cell = Color.lerp(
        base,
        theme.colorScheme.surfaceContainerHighest,
        0.8,
      )!;
      return (cell, base);
    }
    return _checkerColors[style];
  }

  /// 取纯色档位（含自定义颜色）的填充色；棋盘格与 `none` 返回 `null`
  static Color? solidColorOf(String style) {
    return solidColors[style] ?? parseCustomColor(style);
  }
}

/// 透明区底色图层：垫在图片下方，透明像素处透出这里画的内容
class TransparencyBackgroundLayer extends StatelessWidget {
  /// 存储值，见 [TransparencyBackgrounds]
  final String style;

  final BorderRadius? borderRadius;

  const TransparencyBackgroundLayer({
    super.key,
    required this.style,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = TransparencyBackgrounds.normalize(style);
    if (normalized == TransparencyBackgrounds.none) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final checkerColors = TransparencyBackgrounds.checkerColorsOf(
      normalized,
      theme,
    );

    Widget layer;
    if (checkerColors != null) {
      layer = CustomPaint(
        painter: _CheckerPainter(
          cellColor: checkerColors.$1,
          baseColor: checkerColors.$2,
        ),
      );
    } else {
      final solid = TransparencyBackgrounds.solidColorOf(normalized);
      if (solid == null) return const SizedBox.shrink();
      layer = ColoredBox(color: solid);
    }

    if (borderRadius != null) {
      layer = ClipRRect(borderRadius: borderRadius!, child: layer);
    }
    return RepaintBoundary(child: layer);
  }
}

/// 棋盘格绘制：格子边长与官网一致（12px 背景平铺 → 6px 方格）
class _CheckerPainter extends CustomPainter {
  static const double _cell = 6.0;

  final Color cellColor;
  final Color baseColor;

  const _CheckerPainter({required this.cellColor, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    // 所有格子合成一条 Path 后一次绘制，避免逐格 drawRect 的调用开销
    final path = Path();
    final columns = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil();
    for (var row = 0; row < rows; row++) {
      for (var column = row.isEven ? 0 : 1; column < columns; column += 2) {
        path.addRect(
          Rect.fromLTWH(column * _cell, row * _cell, _cell, _cell),
        );
      }
    }
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, Paint()..color = cellColor);
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) {
    return oldDelegate.cellColor != cellColor ||
        oldDelegate.baseColor != baseColor;
  }
}
